param (
    [string]$Username = $(throw "-Username is required."),  
    [string]$Password = $(throw "-Password is required."), 
    [string]$ArmEndpoint = $(throw "-ArmEndpoint is required."),
    [string]$TempFilesPath = "C:\TempASR\",
    [string]$ExtractionPath = "Extracted",
    [string]$MySQLRootPassword = $(throw "-MySQLRootPassword is required."),
    [string]$MySQLUserPassword = $(throw "-MySQLUserPassword is required."),
    [string]$VNetName = "SiteRecoveryVNet",
    [string]$AzureStorageAccount = $(throw "-AzureStorageAccount is required."),
    [string]$SubnetRange = "192.168.1.0/24",
    [string]$VNetRange = "192.168.0.0/16",
    [string]$AzureLocation = "UK West",
    [string]$ReplicationPolicyName = "ReplicationPolicy",
    [string]$AzureResourceGroup = "SiteRecoveryTestRG",
    [string]$VaultName = "AzureStackVault",
    [string]$ConfigServerUsername = $(throw "-ConfigServerUsername is required."), 
    [string]$ConfigServerPassword = $(throw "-ConfigServerPassword is required."),
    [string]$EncryptionKey = $(throw "-EncryptionKey is required."),
    [string]$WindowsUsername =  $(throw "-WindowsUsername is required."),
    [string]$WindowsPassword =  $(throw "-WindowsPassword is required."),
    [string]$LinuxRootPassword =  $(throw "-LinuxRootPassword is required."),
    [string]$StackResourceGroup = $(throw "-StackResourceGroup is required.")
)
    
## Declare MySQL function
Function Invoke-MySQLQuery {
    Param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "",
            ValueFromPipeline = $true)]
            [string]$Query,
            [string]$MySQLAdminPassword
        )
            
    $MySQLAdminUserName = "root"
    $MySQLDatabase = "svsdb1"
    $MySQLHost = "localhost"
    $ConnectionString = "server=" + $MySQLHost + ";port=3306;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database=" + $MySQLDatabase
    
    Try {
        [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
        $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
        $Connection.ConnectionString = $ConnectionString
        $Connection.Open()
        $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
        $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
        $DataSet = New-Object System.Data.DataSet
        $RecordCount = $dataAdapter.Fill($dataSet, "data")
        $DataSet.Tables[0]
    }
    Catch {
        Write-Host "ERROR : Unable to run query '$query' `n$($Error[0])" -ForegroundColor Red
    }
    Finally {
        $Connection.Close()
    }
}
# Install Modules
Write-Host "Installing Nuget, Azure modules and Choco"
Install-PackageProvider -Name Nuget -Force -Confirm:$false
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name AzureRm.BootStrapper -Force -Confirm:$false
Use-AzureRmProfile -Profile 2018-03-01-hybrid -Force -Confirm:$false
Install-Module -Name AzureStack -RequiredVersion 1.5.0 -Force -Confirm:$false
Install-Module -Name AzureRM.RecoveryServices -Force -Confirm:$false
Install-Module -Name AzureRM.RecoveryServices.SiteRecovery -Force -Confirm:$false
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).path)\..\.."
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
# Install SysInternals
$CheckSysinternalsInstall = $false
$retry = 0
while (!$CheckSysinternalsInstall -and $retry -lt 10) {
    choco install -y sysinternals
    Start-Sleep 10
    $CheckSysinternalsInstall = choco list -lo | where {$_ -like "*sysinternals*"}
    $retry ++
}
refreshenv
Get-Module -Name "Azure*" | Remove-Module -Force

# Format Disks
Write-Host "Formatting Disks"
Get-Disk -Number 2 | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize `
    | Format-Volume -FileSystem NTFS -NewFileSystemLabel "ProcessServerCache" -Confirm:$false

Get-Disk -Number 3 | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize `
    | Format-Volume -FileSystem NTFS -NewFileSystemLabel "RetentionDisk" -Confirm:$false

# Create Folders
New-item -ItemType Directory -Path "$($TempFilesPath)$($ExtractionPath)" -Force

# Define Install Path
$InstallPath = "F:\ASR"

# Download Installer file
Write-Host "Downloading setup file"
$url = "http://aka.ms/unifiedinstaller_uks"
$output = "$($TempFilesPath)MicrosoftAzureSiteRecoveryUnifiedSetup.exe"
(New-Object System.Net.WebClient).DownloadFile($url, $output)

# Create MySQL credentials file
Write-Host "Creating MySQL credentials file"
$SQLCredPath = "$($TempFilesPath)MySQLCredentialsfile.txt" 
$OutStuff = @"
[MySQLCredentials]
MySQLRootPassword = "$MySQLRootPassword"
MySQLUserPassword = "$MySQLUserPassword"
"@
$OutStuff | Out-File $SQLCredPath -Force -Encoding ascii

# Extract setup file
Write-Host "Extracting setup file"
& "$($TempFilesPath)MicrosoftAzureSiteRecoveryUnifiedSetup.exe" /q /x:"$($TempFilesPath)$($ExtractionPath)"
Write-Host $("`rExtracting.") -NoNewline
while (get-process -Name MicrosoftAzureSiteRecoveryUnifiedSetup -ErrorAction SilentlyContinue) {
    Write-Host $("`r.") -NoNewline
    Start-Sleep -Seconds 2
}

## Login to public azure
Write-Host "Logging into public Azure"
$CredPass = ConvertTo-SecureString $Password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($Username, $CredPass) 
Connect-AzureRmAccount -Credential $Credentials

## Create and configure a vault, then retrieve settings
# Declare variables
Write-Host "Setting up vault and retrieving settings"
# Create resource group
Write-Host "Creating resource group in public Azure"
$SRRG = New-AzureRmResourceGroup -Name $AzureResourceGroup -Location $AzureLocation
# Create the Vault
Write-Host "Creating Site Recovery vault"
$SRVault = New-AzureRmRecoveryServicesVault -Name $VaultName -ResourceGroupName $SRRG.ResourceGroupName -Location $SRRG.Location
Set-AzureRmRecoveryServicesBackupProperties -Vault $SRVault -BackupStorageRedundancy LocallyRedundant
# Set Vault Context
Set-AzureRmRecoveryServicesAsrVaultContext -Vault $SRVault
$ScriptPath = "C:\TempASR\script.ps1" 
$ScriptFile = @"
`$CredPass = ConvertTo-SecureString `$args[1] -AsPlainText -Force
`$cred = New-Object System.Management.Automation.PSCredential (`$args[0], `$CredPass) 
Connect-AzureRmAccount -Credential `$cred
# Download Vault Settings
Write-Host 'Downloading vault settings'
`$retry = 0
while (!`$VaultCredPath -and `$retry -lt 20) {
    # Get Vault
    `$SRVaultGet = Get-AzureRmRecoveryServicesVault -Name $VaultName -ResourceGroupName $AzureResourceGroup
    `$VaultCredPath = Get-AzureRmRecoveryServicesVaultSettingsFile -Vault `$SRVaultGet -Path $TempFilesPath
    `$VaultCredPath.FilePath | Out-File $($TempFilesPath)VaultCredential.txt -Encoding ascii -Force
    Start-Sleep -Seconds 5
    `$retry ++
    if (`$retry -eq 19) {
        write-host 'Still broken'
        break
    }
}
"@
$ScriptFile | Out-File $ScriptPath -Force -Encoding ascii

Powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $ScriptPath $Username $Password
$VaultCredPath = Get-Content -path "$($TempFilesPath)VaultCredential.txt"
# Create a new storage account
Write-Host "Creating storage account and virtual network on public Azure"
$StorageAccount = New-AzureRmStorageAccount -Location $SRRG.Location -ResourceGroupName $SRRG.ResourceGroupName -Type "Standard_LRS" -Name ($AzureStorageAccount.ToLower())
# Create a virtual network
$SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name "default" -AddressPrefix $SubnetRange
$VirtualNetwork = New-AzureRmVirtualNetwork -ResourceGroupName $SRRG.ResourceGroupName -Location $SRRG.Location -Name $VNetName -AddressPrefix $VNetRange -Subnet $SubnetConfig
# Create Replication Policies
Write-Host "Creating replication and failback policies"
$ReplicationPolicy = New-AzureRmRecoveryServicesAsrPolicy -VMwareToAzure -Name $ReplicationPolicyName -RecoveryPointRetentionInHours 24 -ApplicationConsistentSnapshotFrequencyInHours 4 -RPOWarningThresholdInMinutes 60
$FailbackReplicationPolicy = New-AzureRmRecoveryServicesAsrPolicy -AzureToVMware -Name "$($ReplicationPolicyName)-Failback" -RecoveryPointRetentionInHours 24 -ApplicationConsistentSnapshotFrequencyInHours 4 -RPOWarningThresholdInMinutes 60

# Run setup
Write-Host "Installing Azure Site Recovery Configuration Server"
$ScriptPath2 = "$($TempFilesPath)script2.ps1" 
"& `"$($TempFilesPath)$($ExtractionPath)\UNIFIEDSETUP.EXE`" /AcceptThirdpartyEULA /ServerMode `"CS`" /InstallLocation $InstallPath /MySQLCredsFilePath $SQLCredPath /VaultCredsFilePath $VaultCredPath /EnvType NonVMWare" | Out-File $ScriptPath2 -Force -Encoding ascii

 
psexec -h -u $ConfigServerUsername -p $ConfigServerPassword cmd /c "Powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $ScriptPath2"
#Powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $ScriptPath2
#https://stackoverflow.com/questions/41550616/customscriptextension-cannot-run-start-process-access-is-denied

# Create Encryption Key
$EncryptionKey | Out-File -FilePath "C:\ProgramData\Microsoft Azure Site Recovery\private\encryption.key" -Force -NoNewline -Encoding ascii

# Install .Net Framework 3.5
Write-Host "Installing .Net Framework 3.5"
Install-WindowsFeature Net-Framework-Core

# Download and install MySQL .Net connector
Write-Host "Downloading MySQL .Net connector"
$CheckMySQLInstall = $false
$retry = 0
while (!$CheckMySQLInstall -and $retry -lt 10) {
    choco install mysql-connector -y --force
    Start-Sleep 15
    $CheckMySQLInstall = choco list -lo | where {$_ -like "*mysql-connector*"}
    $retry ++
}

Write-Host "Successfully installed MySQL .Net connector"

# Declare Variables
Write-Host "Adding VM accounts to SQL database"
$FriendlyNameWin = "WindowsAccount"
$FriendlyNameLinux = "LinuxAccount"
$UserNameLinux = "root"
# Retrieve Key
$Key = Get-Content -path "C:\ProgramData\Microsoft Azure Site Recovery\private\encryption.key"
# Assemble Queries
$QueryWin = "INSERT INTO accounts (accountName, userName, password, domain, accountType) VALUES ('$($FriendlyNameWin)', HEX(AES_ENCRYPT('$($WindowsUsername)','$($Key)')), HEX(AES_ENCRYPT('$($WindowsPassword)','$($Key)')), '', '');"
$QueryLinux = "INSERT INTO accounts (accountName, userName, password, domain, accountType) VALUES ('$($FriendlyNameLinux)', HEX(AES_ENCRYPT('$($UserNameLinux)','$($Key)')), HEX(AES_ENCRYPT('$($LinuxRootPassword)','$($Key)')), '', '');"
# Run Queries
Invoke-MySQLQuery -Query $QueryWin -MySQLAdminPassword $MySQLRootPassword
Invoke-MySQLQuery -Query $QueryLinux -MySQLAdminPassword $MySQLRootPassword


# Set Vault Context
Set-AzureRmRecoveryServicesAsrVaultContext -Vault $SRVault
# Get Configuration Server
$RetryASRFabric = 0
Write-Host "Getting configuration server information"
while (!$ASRFabrics -and $RetryASRFabric -lt 20) {
    $ASRFabrics = Get-AzureRmRecoveryServicesAsrFabric
    Start-Sleep -Seconds 5
    $RetryASRFabric ++
}

$ProtectionContainer = Get-AzureRmRecoveryServicesAsrProtectionContainer -Fabric $ASRFabrics[0]
# Assign policies to configuration server
Write-Host "Assigning policies to configuration server"
$ReplicationPolicy = Get-AzureRmRecoveryServicesAsrPolicy -Name $ReplicationPolicyName
$FailbackReplicationPolicy = Get-AzureRmRecoveryServicesAsrPolicy -Name "$($ReplicationPolicyName)-Failback"
$Job_AssociatePolicy = New-AzureRmRecoveryServicesAsrProtectionContainerMapping -Name "ReplicationPolicyAssociation" -PrimaryProtectionContainer $ProtectionContainer -Policy $ReplicationPolicy
$Job_AssociateFailbackPolicy = New-AzureRmRecoveryServicesAsrProtectionContainerMapping -Name "FailbackPolicyAssociation" -PrimaryProtectionContainer $ProtectionContainer -RecoveryProtectionContainer $ProtectionContainer -Policy $FailbackReplicationPolicy

# Login to Azure Stack
Write-Host "Logging into Azure Stack"
$StackEnvironment = Add-AzureRMEnvironment -Name "AzureStack" -ArmEndpoint $ArmEndpoint
Login-AzureRmAccount -EnvironmentName "AzureStack" -Credential $Credentials

# Get info for protected items
Write-Host "Retrieving VM info from resource group"
$StackLocation = $StackEnvironment.GalleryURL.split(".")[1]
$ServerIP = (Get-NetIPAddress | Where-Object {$_.InterfaceAlias -like "*Ethernet*" -and $_.AddressFamily -like "IPv4"}).IPAddress
$ProtectedRG = Get-AzureRmResourceGroup -Location $StackLocation -Name $StackResourceGroup
$ProtectedVMs = Get-AzureRmVM -ResourceGroupName $ProtectedRG.ResourceGroupName
$VMInfo = @()
foreach ($VM in $ProtectedVMs) {
    $VMNIC = Get-AzureRmNetworkInterface -ResourceGroupName $ProtectedRG.ResourceGroupName -Name $VM.NetworkProfile.NetworkInterfaces.Id.split("/")[8]
    if ($VMNIC.IpConfigurations.PrivateIpAddress -ne $ServerIP) {
        $VMObj = New-Object -TypeName System.Object
        $VMObj | Add-Member -Name FriendlyName -MemberType NoteProperty -Value $VM.Name
        $VMObj | Add-Member -Name IPAddress -MemberType NoteProperty -Value $VMNIC.IpConfigurations.PrivateIpAddress
        if ($VM.OSProfile.LinuxConfiguration) {
            $VMObj | Add-Member -Name OSType -MemberType NoteProperty -Value Linux
        }
        if ($VM.OSProfile.WindowsConfiguration) {
            $VMObj | Add-Member -Name OSType -MemberType NoteProperty -Value Windows
        }
        $VMInfo += $VMObj
    }
}
Write-Host "Found the following VMs:"
$VMInfo

# Login to public Azure
Write-Host "Logging into public Azure"
Connect-AzureRmAccount -Credential $Credentials

# Add protected items to vault
Write-Host "Adding VMs to public Azure as protectable items"
Set-AzureRmRecoveryServicesAsrVaultContext -Vault $SRVault
ForEach ($VM in $VMInfo) {
    New-AzureRmRecoveryServicesAsrProtectableItem -ProtectionContainer $ProtectionContainer -FriendlyName $VM.FriendlyName -IPAddress $VM.IPAddress -OSType $VM.OSType
}

$RetryProtectedItems = 0
While ($ProtectedItems.count -ne $VMInfo.Count -and $RetryProtectedItems -lt 60) {
    $ProtectedItems = Get-AzureRmRecoveryServicesAsrProtectableItem -ProtectionContainer $ProtectionContainer
    Start-Sleep -Seconds 5
    $RetryProtectedItems ++
}

$retryresourcegroup = 0
while (!$SRRG.ResourceId -and $retryresourcegroup -lt 10) {
    $SRRG = Get-AzureRmResourceGroup -Name $ProtectedItems[0].ID.split("/")[4]
    Start-Sleep -Seconds 20
    $retryresourcegroup ++
}

$retrystorageaccount = 0
while (!$StorageAccount.Id -and $retrystorageaccount -lt 10) {
    $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $SRRG.ResourceGroupName
    Start-Sleep -Seconds 20
    $retrystorageaccount ++
}

$retryvirtualnetwork = 0
while (!$VirtualNetwork.Id -and $retryvirtualnetwork -lt 10) {
    $VirtualNetwork = Get-AzureRmVirtualNetwork -ResourceGroupName $SRRG.ResourceGroupName
    Start-Sleep -Seconds 20
    $retryvirtualnetwork ++
}

if ($retryresourcegroup -eq 10) {
    Write-Host "Can't retrieve resource group"
}

if ($retrystorageaccount -eq 10) {
    Write-Host "Can't retrieve storage account"
}

if ($retryvirtualnetwork -eq 10) {
    Write-Host "Can't retrieve virtual network"
}

# Update Fabric Object
$ASRFabrics = Get-AzureRmRecoveryServicesAsrFabric
# Create Accounts Object
Write-Host "Waiting for Protected Item accounts to be populated in public Azure"
$RetryASRAccounts = 0
while (!$ASRFabrics[0].FabricSpecificDetails.RunAsAccounts -and $RetryASRAccounts -lt 20) {
    $ASRFabrics = Get-AzureRmRecoveryServicesAsrFabric
    Start-Sleep -Seconds 60
    $RetryASRAccounts ++
}
$ProcessServer = $ASRFabrics[0].FabricSpecificDetails.ProcessServers[0]
$RunAsAccounts = $ASRFabrics[0].FabricSpecificDetails.RunAsAccounts

# Set replicated items
Write-Host "Setting VMs to be protected"
$ContainerMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $ProtectionContainer | Where-Object PolicyFriendlyName -eq $ReplicationPolicyName
ForEach ($Item in $ProtectedItems) {
    # Remove Azure Stack Temporary Disk
    [string[]]$Disks = @()
    $DiskNum = 0
    ForEach ($DiskName in $Item.Disks) {
        if ($DiskNum -ne 1) {
            $Disks += $($DiskName.Id)
        }
        $DiskNum ++
    }
    if ($Item.OS -like "*LINUX*") {
        $LinuxAccount = $RunAsAccounts | Where-Object {$_.accountName -like "LinuxAccount"}
        if ($Item.Disks) {
            $Job_EnableReplicationLinux = New-AzureRmRecoveryServicesAsrReplicationProtectedItem -VMwareToAzure -ProtectableItem $Item -Name $Item.FriendlyName -RecoveryVmName $Item.FriendlyName -ProtectionContainerMapping $ContainerMapping -IncludeDiskId $Disks -RecoveryAzureStorageAccountId $StorageAccount.Id -ProcessServer $ProcessServer -Account $LinuxAccount -RecoveryResourceGroupId $SRRG.ResourceId -RecoveryAzureNetworkId $VirtualNetwork.Id -RecoveryAzureSubnetName "default"
        }
        else {
            $Job_EnableReplicationLinux = New-AzureRmRecoveryServicesAsrReplicationProtectedItem -VMwareToAzure -ProtectableItem $Item -Name $Item.FriendlyName -RecoveryVmName $Item.FriendlyName -ProtectionContainerMapping $ContainerMapping -RecoveryAzureStorageAccountId $StorageAccount.Id -ProcessServer $ProcessServer -Account $LinuxAccount -RecoveryResourceGroupId $SRRG.ResourceId -RecoveryAzureNetworkId $VirtualNetwork.Id -RecoveryAzureSubnetName "default"    
        }
    }
    elseif ($Item.OS -like "*WINDOWS*") {
        $WindowsAccount = $RunAsAccounts | Where-Object {$_.accountName -like "WindowsAccount"}
        if ($Item.Disks) {
            $Job_EnableReplicationWin = New-AzureRmRecoveryServicesAsrReplicationProtectedItem -VMwareToAzure -ProtectableItem $Item -Name $Item.FriendlyName -RecoveryVmName $Item.FriendlyName -ProtectionContainerMapping $ContainerMapping -IncludeDiskId $Disks -RecoveryAzureStorageAccountId $StorageAccount.Id -ProcessServer $ProcessServer -Account $WindowsAccount -RecoveryResourceGroupId $SRRG.ResourceId -RecoveryAzureNetworkId $VirtualNetwork.Id -RecoveryAzureSubnetName "default"
        }
        else {
            $Job_EnableReplicationWin = New-AzureRmRecoveryServicesAsrReplicationProtectedItem -VMwareToAzure -ProtectableItem $Item -Name $Item.FriendlyName -RecoveryVmName $Item.FriendlyName -ProtectionContainerMapping $ContainerMapping -RecoveryAzureStorageAccountId $StorageAccount.Id -ProcessServer $ProcessServer -Account $WindowsAccount -RecoveryResourceGroupId $SRRG.ResourceId -RecoveryAzureNetworkId $VirtualNetwork.Id -RecoveryAzureSubnetName "default"
        }
    }
}