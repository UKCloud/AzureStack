<#
    .SYNOPSIS
        Installs and configures the MARS agent for file and folder backup.

    .DESCRIPTION
        Installs and configures the Microsoft Azure Recovery Services agent for backing up files and folders to Microsoft Azure Recovery Services vaults.

    .PARAMETER ClientId
        The application ID of a service principal with contributor permissions on Azure. Example: "00000000-0000-0000-0000-000000000000"

    .PARAMETER ClientSecret
        A password of the service principal specified in the ClientId parameter. Example: 'ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]='

    .PARAMETER TenantId
        The Tenant/Directory ID of your AAD domain. Example: "31537af4-6d77-4bb9-a681-d2394888ea26"

    .PARAMETER AzureResourceGroup
        The name of the resource group to be created in public Azure. Defaults to: "AzureStackBackupRG"

    .PARAMETER VaultName
        The name of the Recovery Services vault to be created in public Azure. Example: "AzureStackVault"

    .PARAMETER AzureLocation
        The location of the Recovery Services vault in public Azure. Defaults to: "UK West"

    .PARAMETER ExistingRG
        Switch used to specify that the resource group already exists in public Azure.

    .PARAMETER ExistingVault
        Switch used to specify that the vault already exists in public Azure.

    .PARAMETER TempFilesPath
        Location on the server where setup files will be stored. Defaults to: "C:\temp"

    .PARAMETER EncryptionKey
        The encryption key to encrypt the backups with. Example: "ExampleEncryptionKey"

    .PARAMETER BackupDays
        A comma separated list of the days to backup on. Example: "Wednesday, Sunday"

    .PARAMETER BackupTimes
        A comma separated list of the times to backup at on the backup days. Example: "16:00, 20:00"

    .PARAMETER RetentionLength
        The number of days to keep each backup for. Defaults to: 7

    .PARAMETER FoldersToBackup
        A comma separated list of folders to backup. By default backs up all drives excluding temporary storage. Example: "C:\Users, C:\Important"

    .PARAMETER BackupNow
        Switch used to specify that the server should backup once the MARS agent is installed.

    .PARAMETER NoSchedule
        Switch used to specify that the schedule configuration step can be skipped.

    .EXAMPLE
        AzureBackupConfig.ps1 -ClientID "00000000-0000-0000-0000-000000000000" -ClientSecret "3Hj2y5pI5ctu73ffmHdcwr4M8dQ6PlLj2tgLhs9cjj4=" -TenantID "31537af4-6d77-4bb9-a681-d2394888ea26" `
            -VaultName "AzureStackVault" -EncryptionKey "Password123!Password123!" -BackupDays "Saturday" -BackupTimes "16:00"

    .EXAMPLE
        AzureBackupConfig.ps1 -ClientID "00000000-0000-0000-0000-000000000000" -ClientSecret "3Hj2y5pI5ctu73ffmHdcwr4M8dQ6PlLj2tgLhs9cjj4=" -TenantID "31537af4-6d77-4bb9-a681-d2394888ea26" `
            -AzureResourceGroup "AzureStackBackupRG" -VaultName "AzureStackVault" -ExistingRG -ExistingVault -EncryptionKey "Password123!Password123!" -BackupDays "Saturday" -BackupTimes "16:00"

    .EXAMPLE
        AzureBackupConfig.ps1 -ClientID "00000000-0000-0000-0000-000000000000" -ClientSecret "3Hj2y5pI5ctu73ffmHdcwr4M8dQ6PlLj2tgLhs9cjj4=" -TenantID "31537af4-6d77-4bb9-a681-d2394888ea26" `
            -VaultName "AzureStackVault" -EncryptionKey "Password123!Password123!" -NoSchedule

    .EXAMPLE
        AzureBackupConfig.ps1 -ClientID "00000000-0000-0000-0000-000000000000" -ClientSecret "3Hj2y5pI5ctu73ffmHdcwr4M8dQ6PlLj2tgLhs9cjj4=" -TenantID "31537af4-6d77-4bb9-a681-d2394888ea26" `
            -AzureResourceGroup "AzureStackBackupRG" -VaultName "AzureStackVault" -AzureLocation "UK West" -ExistingRG -ExistingVault -TempFilesPath "C:\temp" -EncryptionKey "Password123!Password123!" `
            -BackupDays "Monday, Friday" -BackupTimes "16:00, 20:00" -RetentionLength 7 -FoldersToBackup "C:\Users, C:\Users\TestUser\Documents" -BackupNow

    .LINK
        https://docs.microsoft.com/en-us/azure/backup/backup-client-automation

    .LINK
        https://docs.microsoft.com/en-us/azure/backup/backup-configure-vault

    .NOTES
        System state backups can be configured by manually enabling it via the GUI. Currently there is no way to enable this via PowerShell.
#>


[CmdletBinding(DefaultParameterSetName = "Configure")]
param (
    # Login parameters
    [Parameter(Mandatory = $true)]
    [Alias("AppId")]
    [String]
    $ClientId,

    [Parameter(Mandatory = $true)]
    [Alias("SecretKey")]
    [String]
    $ClientSecret,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')] # RegEx to enforce that domain name is passed as a parameter
    [String]
    $TenantId,

    # Azure parameters
    [Parameter(Mandatory = $false)]
    [String]
    $AzureResourceGroup = "AzureStackBackupRG",

    [Parameter(Mandatory = $true)]
    [String]
    $VaultName,

    [Parameter(Mandatory = $false)]
    [String]
    $AzureLocation = "UK West",

    [Parameter(Mandatory = $false)]
    [Switch]
    $ExistingRG,

    [Parameter(Mandatory = $false)]
    [Switch]
    $ExistingVault,

    # Server config parameters
    [Parameter(Mandatory = $false)]
    [String]
    $TempFilesPath = "C:\temp",

    [Parameter(Mandatory = $true)]
    [ValidateLength(16, 40)]
    [String]
    $EncryptionKey,

    # Backup schedule config parameters
    [Parameter(Mandatory = $true, ParameterSetName = "Configure")]
    [ValidateCount(1, 7)]
    [String[]]
    $BackupDays,

    [Parameter(Mandatory = $true, ParameterSetName = "Configure")]
    [String[]]
    $BackupTimes,

    [Parameter(Mandatory = $false, ParameterSetName = "Configure")]
    [Int]
    $RetentionLength = 7,

    [Parameter(Mandatory = $false, ParameterSetName = "Configure")]
    [ValidateScript( { $_ -split "," | ForEach-Object { Test-Path -Path $_ } })]
    [String[]]
    $FoldersToBackup,

    [Parameter(Mandatory = $false, ParameterSetName = "Configure")]
    [Switch]
    $BackupNow,

    [Parameter(Mandatory = $true, ParameterSetName = "NoConfigure")]
    [Switch]
    $NoSchedule
)

begin {
    # Change the object type to Array and remove spaces
    $BackupTimes = ($BackupTimes -split ",") -replace " ", ""
    $BackupDays = ($BackupDays -split ",") -replace " ", ""
    $FoldersToBackupArray = ($FoldersToBackup -split ",") -replace " ", ""

    # You can schedule only three daily backups per day so we want to make sure users will NOT run the whole script and then fail, hence we are checking it here
    if ($BackupTimes.Length -gt 3) {
        Write-Error -Message "You can schedule up to three daily backups per day!`nMake sure you only put three objects into the array." -ErrorAction "Stop"
        break
    }
}

process {
    # Initialise TempFilesPath folder
    if (-not (Test-Path -Path $TempFilesPath)) {
        New-Item -ItemType Directory -Path $TempFilesPath -Force | Out-Null
        Write-Output -InputObject "Created directory: $TempFilesPath"
    }

    # Install Modules
    Write-Output -InputObject "Installing Nuget and AzureRM PowerShell modules."
    Install-PackageProvider -Name "NuGet" -Confirm:$false -Force | Out-Null
    Install-Module -Name "AzureRM" -RequiredVersion 2.4.0 -Confirm:$false -Force
    Install-Module -Name "AzureRM.RecoveryServices" -Confirm:$false -Force
    Install-Module -Name "AzureRM.RecoveryServices.SiteRecovery" -Confirm:$false -Force

    # Download the MARS agent
    Write-Output -InputObject "Downloading MARS agent."
    $OutPath = Join-Path -Path $TempFilesPath -ChildPath "MARSAgentInstaller.exe"
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("https://aka.ms/azurebackup_agent", $OutPath)

    # Install the MARS agent
    Write-Output -InputObject "Installing MARS agent"
    & $OutPath /q

    if (-not $ExistingVault) {
        # Create and configure a vault, then retrieve settings
        ## Login to public azure
        Write-Output -InputObject "Logging into public Azure with tenant ID: $TenantId"
        $CredPass = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential ($ClientId, $CredPass)
        Connect-AzureRmAccount -Credential $Credentials -ServicePrincipal -Tenant $TenantId

        if (-not $ExistingRG) {
            # Create resource group
            Write-Output -InputObject "Creating resource group: $AzureResourceGroup in public Azure."
            New-AzureRmResourceGroup -Name $AzureResourceGroup -Location $AzureLocation | Out-Null
        }

        # Create the vault
        Write-Output -InputObject "Creating backup vault: $BackupVault in resource group: $AzureResourceGroup in public Azure."
        $BackupVault = New-AzureRmRecoveryServicesVault -Name $VaultName -ResourceGroupName $AzureResourceGroup -Location $AzureLocation
        Set-AzureRmRecoveryServicesBackupProperties -Vault $BackupVault -BackupStorageRedundancy LocallyRedundant
    }

    # Retrieve vault credentials file
    $ScriptPath = Join-Path -Path $TempFilesPath -ChildPath "script.ps1"
    @"
`$CredPass = ConvertTo-SecureString -String `$args[1] -AsPlainText -Force
`$Cred = New-Object System.Management.Automation.PSCredential (`$args[0], `$CredPass)
Connect-AzureRmAccount -Credential `$Cred -ServicePrincipal -Tenant $TenantId
# Download Vault Settings
Write-Output -InputObject "Downloading vault settings."
`$Retry = 0
while (!`$VaultCredPath -and `$Retry -lt 20) {
    # Get Vault
    `$BackupVaultGet = Get-AzureRmRecoveryServicesVault -Name $VaultName -ResourceGroupName $AzureResourceGroup
    `$VaultCredPath = Get-AzureRmRecoveryServicesVaultSettingsFile -Vault `$BackupVaultGet -Path $TempFilesPath -Backup
    `$VaultCredPath.FilePath | Out-File (Join-Path -Path $TempFilesPath -ChildPath "VaultCredential.txt") -Encoding ascii -Force
    Start-Sleep -Seconds 5
    `$Retry ++
    if (`$Retry -eq 20) {
        Write-Output -InputObject "Unable to retrieve Vault Credentials file"
        break
    }
}
"@ | Out-File $ScriptPath -Force -Encoding ascii

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $ScriptPath $ClientId $ClientSecret
    $VaultCredPath = Get-Content -Path (Join-Path -Path $TempFilesPath -ChildPath "VaultCredential.txt")

    # Import MS Online Backup module
    Import-Module -Name "C:\Program Files\Microsoft Azure Recovery Services Agent\bin\Modules\MSOnlineBackup"

    # Register MARS agent to Recovery Services vault
    Write-Output -InputObject "Registering MARS agent to Recovery Services vault."
    Start-OBRegistration -VaultCredentials $VaultCredPath -Confirm:$false

    # Set encryption key for MARS agent
    ConvertTo-SecureString -String $EncryptionKey -AsPlainText -Force | Set-OBMachineSetting

    if (-not $NoSchedule) {
        # Configure backup settings
        Write-Output -InputObject "Configuring backup settings"

        ## Create blank backup policy
        $BackupPolicy = New-OBPolicy
        ## Set backup schedule
        $BackupSchedule = New-OBSchedule -DaysOfWeek $BackupDays -TimesOfDay $BackupTimes
        Set-OBSchedule -Policy $BackupPolicy -Schedule $BackupSchedule
        ## Set retention policy
        $RetentionPolicy = New-OBRetentionPolicy -RetentionDays $RetentionLength
        Set-OBRetentionPolicy -Policy $BackupPolicy -RetentionPolicy $RetentionPolicy

        ## Set drives to be backed up, excluding the temporary storage
        if (-not $FoldersToBackupArray) {
            $Drives = Get-PSDrive -PSProvider "Microsoft.PowerShell.Core\FileSystem" | Where-Object -FilterScript { $_.Used -gt 0 -and $_.Description -notlike "Temporary Storage" } | Select-Object -ExpandProperty Root
            $FileInclusions = New-OBFileSpec -FileSpec @($Drives)
        }
        else {
            $FileInclusions = New-OBFileSpec -FileSpec @($FoldersToBackupArray)
        }

        $FileExclusions = New-OBFileSpec -FileSpec @($TempFilesPath) -Exclude
        Add-OBFileSpec -Policy $BackupPolicy -FileSpec $FileInclusions
        Add-OBFileSpec -Policy $BackupPolicy -FileSpec $FileExclusions

        # Remove the (possibly) existing policy
        try {
            Get-OBPolicy | Remove-OBPolicy -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Output -InputObject "No existing policy to remove."
        }

        # Apply the new policy
        Set-OBPolicy -Policy $BackupPolicy -Confirm:$false
    }

    # Start a backup if required
    if ($BackupNow) {
        Get-OBPolicy | Start-OBBackup
    }

    # Clean-up temp resources
    Remove-Item -Path $VaultCredPath -Force -Confirm:$false
    Remove-Item -Path $ScriptPath -Force -Confirm:$false
    Remove-Item -Path $OutPath -Force -Confirm:$false
}
