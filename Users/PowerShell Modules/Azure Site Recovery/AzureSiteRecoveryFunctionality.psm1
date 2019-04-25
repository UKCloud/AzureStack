#Requires -Module AzureStack, AzureRM, AzureRM.RecoveryServices, AzureRM.RecoveryServices.SiteRecovery

function Test-AzureSiteRecoveryFailOver {
    <#
    .SYNOPSIS
        Performs a test failover of your protected VMs to Azure.

    .DESCRIPTION
        Performs a test failover of all protected VMs in a single vault to Azure. Will test failover protected VMs asynchronously, then
        perform clean-up asynchronously.

    .PARAMETER VaultName
        The name of the site recovery vault in public Azure. Example: "AzureStackRecoveryVault"

    .PARAMETER Confirmation
        Switch to specify whether to prompt the user to continue if the failover doesn't complete successfully

    .EXAMPLE
        Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault"

    .EXAMPLE
        Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault" -Confirmation

    .NOTES
        As this cmdlet performs a test failover, no production VMs will be affected.
        This cmdlet requires you to be logged into public Azure to run successfully.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$VaultName,
        [Parameter(Mandatory = $false)]
        [Switch]$Confirmation
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into Azure Stack. Please login to public azure to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Retrieve the vault information
        try {
            $VaultVar = Get-AzureRmRecoveryServicesVault -Name $VaultName
            Set-AzureRmRecoveryServicesAsrVaultContext -Vault $VaultVar | Out-Null
            # Needs a sleep here as sometimes it takes a couple of seconds to actually set the context
            Start-Sleep -Seconds 2
            $FabricVar = Get-AzureRmRecoveryServicesAsrFabric
            $ContainerVar = Get-AzureRmRecoveryServicesAsrProtectionContainer -Fabric $FabricVar
            $ProtectedVMs = Get-AzureRmRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ContainerVar
        }
        catch {
            Write-Error -Message "$($_)"
            Write-Error -Message "Retrieving vault settings failed"
            break
        }

        Write-Host -Object "VMs to test failover: $($ProtectedVMs.Name)" -ForegroundColor Green

        # Start test failover
        $FailoverJobs = @()
        foreach ($VM in $ProtectedVMs) {
            $FailoverJob = Start-AzureRmRecoveryServicesAsrTestFailoverJob -Direction PrimaryToRecovery -ReplicationProtectedItem $VM -AzureVMNetworkId $VM.SelectedRecoveryAzureNetworkId
            $FailoverJobs += $FailoverJob
        }

        # Check test failover status
        $FailureTest = $false
        $NumJobsComplete = 0
        while ($FailoverJobs.Count -ne $NumJobsComplete) {
            $NumJobsComplete = 0
            $FailoverStatii = @()
            foreach ($Job in $FailoverJobs) {
                $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
                $FailoverStatus = New-Object -TypeName System.Object
                $FailoverStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                $FailoverStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                $FailoverStatii += $FailoverStatus
            }

            Write-Host -Object "Status at: $(Get-Date -UFormat '%H:%M:%S - %d/%m/%Y')"
            Write-Host ($FailoverStatii | Format-Table | Out-String).Split("`n")[1]
            Write-Host ($FailoverStatii | Format-Table | Out-String).Split("`n")[2]
            $FailoverStatii | Out-String -Stream | ForEach-Object {
                if ($_ -clike "* Succeeded*") {
                    Write-Host -Object "$($_)" -ForegroundColor Green
                    $NumJobsComplete += 1
                }
                elseif ($_ -clike "* Failed*") {
                    Write-Host -Object "$($_)" -ForegroundColor Red
                    $NumJobsComplete += 1
                    $FailureTest = $true
                }
                elseif ($_ -clike "* InProgress*") {
                    Write-Host -Object "$($_)"
                }
            }
            Write-Host -Object ""

            if ($FailoverJobs.Count -ne $NumJobsComplete) {
                Start-Sleep -Seconds 30
            }
        }

        # Start test failover clean-up
        Write-Host -Object "Starting test failover clean-up"
        $CleanupJobs = @()
        foreach ($VM in $ProtectedVMs) {
            $CleanupJob = Start-AzureRmRecoveryServicesAsrTestFailoverCleanupJob -ReplicationProtectedItem $VM
            $CleanupJobs += $CleanupJob
        }

        # Check status of clean-up jobs
        $CleanupFailureTest = $false
        $NumJobsComplete = 0
        while ($CleanupJobs.Count -ne $NumJobsComplete) {
            $NumJobsComplete = 0
            $CleanupStatii = @()
            foreach ($Job in $CleanupJobs) {
                $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
                $CleanupStatus = New-Object -TypeName System.Object
                $CleanupStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                $CleanupStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                $CleanupStatii += $CleanupStatus
            }

            Write-Host -Object "Status at: $(Get-Date -UFormat '%H:%M:%S - %d/%m/%Y')"
            Write-Host ($CleanupStatii | Format-Table | Out-String).Split("`n")[1]
            Write-Host ($CleanupStatii | Format-Table | Out-String).Split("`n")[2]
            $CleanupStatii | Out-String -Stream | ForEach-Object {
                if ($_ -clike "* Succeeded*") {
                    Write-Host -Object "$($_)" -ForegroundColor Green
                    $NumJobsComplete += 1
                }
                elseif ($_ -clike "* Failed*") {
                    Write-Host -Object "$($_)" -ForegroundColor Red
                    $NumJobsComplete += 1
                    $CleanupFailureTest = $true
                }
                elseif ($_ -clike "* InProgress*") {
                    Write-Host -Object "$($_)"
                }
            }
            Write-Host -Object ""

            if ($CleanupJobs.Count -ne $NumJobsComplete) {
                Start-Sleep -Seconds 30
            }
        }
        if ($Confirmation -eq $true) {
            # Ask user if they want to continue if one or more test failover jobs fail
            $Valid = $false
            while ($Valid -eq $false -and $FailureTest -eq $true) {
                $YesNo = Read-Host -Prompt "One or more of the VMs failed during test failover. Are you sure you want to proceed? (y/n)"
                if ($YesNo -like "*n*") {
                    Write-Host -Object "Exiting..."
                    return $false
                }
                elseif ($YesNo -notlike "*y*") {
                    Write-Host -Object ""
                    Write-Host -Object "Please enter a valid option (E.G. y or n)"
                }
                else {
                    Write-Host -Object "Proceeding..."
                    $Valid = $true
                }
            }

            # Ask user if they want to continue if one or more cleanup jobs fail
            $Valid = $false
            while ($Valid -eq $false -and $CleanupFailureTest -eq $true) {
                $YesNo = Read-Host -Prompt "One or more of the VMs failed during test failover clean-up. Are you sure you want to proceed? (y/n)"
                if ($YesNo -like "*n*") {
                    Write-Host -Object "Exiting..."
                    return $false
                }
                elseif ($YesNo -notlike "*y*") {
                    Write-Host -Object ""
                    Write-Host -Object "Please enter a valid option (E.G. y or n)"
                }
                else {
                    Write-Host -Object "Proceeding..."
                    $Valid = $true
                }
            }
            $Valid = $true
        }
        else {
            $Valid = $true
            if ($FailureTest -eq $true) {
                Write-Host -Object "One or more of the VMs failed during test failover." -ForegroundColor Red
                $Valid = $false
            }
            if ($CleanupFailureTest -eq $true) {
                Write-Host -Object "One or more of the VMs failed during test failover clean-up." -ForegroundColor Red
                $Valid = $false
            }
        }
        return $Valid
    }
}


function Start-AzureSiteRecoveryFailOver {
    <#
    .SYNOPSIS
        Performs a failover of your protected VMs to Azure.

    .DESCRIPTION
        Performs a failover of all protected VMs in a single vault to Azure. Will failover protected VMs asynchronously, then
        commit them to public Azure.

    .PARAMETER VaultName
        The name of the site recovery vault in public Azure. Example: "AzureStackRecoveryVault"

    .PARAMETER SkipTest
        Switch parameter used to skip the test failover stage

    .EXAMPLE
        Start-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault"

    .NOTES
        This cmdlet performs a full failover of your production VMs. As part of this process your VMs may be shut down. Proceed at your own risk.
        This cmdlet requires you to be logged into public Azure to run successfully.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$VaultName,
        [Parameter(Mandatory = $false)]
        [Switch]$SkipTest
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into Azure Stack. Please login to public azure to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        if (-not $SkipTest) {
            $TestSuccessful = Test-AzureSiteRecoveryFailover -VaultName $VaultName -Confirmation
            if ($TestSuccessful -eq $false) {
                break
            }
        }
        try {
            $VaultVar = Get-AzureRmRecoveryServicesVault -Name $VaultName
            Set-AzureRmRecoveryServicesAsrVaultContext -Vault $VaultVar
            # Needs a sleep here as sometimes it takes a couple of seconds to actually set the context
            Start-Sleep -Seconds 2
            $FabricVar = Get-AzureRmRecoveryServicesAsrFabric
            $ContainerVar = Get-AzureRmRecoveryServicesAsrProtectionContainer -Fabric $FabricVar
            $ProtectedVMs = Get-AzureRmRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ContainerVar
        }
        catch {
            Write-Error -Message "$($_)"
            Write-Error -Message "Retrieving vault settings failed"
            break
        }

        Write-Host -Object "VMs to failover: $($ProtectedVMs.Name)" -ForegroundColor Green

        # Start actual failover
        Write-Host -Object "Starting failover..."
        $FailoverJobs = @()
        foreach ($VM in $ProtectedVMs) {
            $FailoverJob = Start-AzureRmRecoveryServicesAsrUnplannedFailoverJob -Direction PrimaryToRecovery -ReplicationProtectedItem $VM
            $FailoverJobs += $FailoverJob
        }

        # Checking failover status
        $Failure = $false
        $FailoverErrors = @()
        $NumJobsComplete = 0
        while ($FailoverJobs.Count -ne $NumJobsComplete) {
            $NumJobsComplete = 0
            $FailoverStatii = @()
            foreach ($Job in $FailoverJobs) {
                $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
                $FailoverStatus = New-Object -TypeName System.Object
                $FailoverStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                $FailoverStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                $FailoverStatii += $FailoverStatus
                if ($JobStatus.State -like "Failed") {
                    $FailoverError = New-Object -TypeName System.Object
                    $FailoverError | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                    $FailoverError | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                    $FailoverError | Add-Member -Name Errors -MemberType NoteProperty -Value $JobStatus.Errors
                    $FailoverErrors += $FailoverError
                }
            }

            Write-Host -Object "Status at: $(Get-Date -UFormat '%H:%M:%S - %d/%m/%Y')"
            Write-Host ($FailoverStatii | Format-Table | Out-String).Split("`n")[1]
            Write-Host ($FailoverStatii | Format-Table | Out-String).Split("`n")[2]
            $FailoverStatii | Out-String -Stream | ForEach-Object {
                if ($_ -clike "* Succeeded*") {
                    Write-Host -Object "$($_)" -ForegroundColor Green
                    $NumJobsComplete += 1
                }
                elseif ($_ -clike "* Failed*") {
                    Write-Host -Object "$($_)" -ForegroundColor Red
                    $NumJobsComplete += 1
                    $Failure = $true
                }
                elseif ($_ -clike "* InProgress*") {
                    Write-Host -Object "$($_)"
                }
            }
            Write-Host -Object ""

            if ($FailoverJobs.Count -ne $NumJobsComplete) {
                Start-Sleep -Seconds 30
            }
        }

        if ($Failure -eq $true) {
            Write-Host -Object "One or more VMs failed to failover:"
            $FailoverErrors | Format-Table
        }
        else {
            Write-Host -Object "Committing replicated VMs..."
            $CommitJobs = @()
            foreach ($VM in $ProtectedVMs) {
                $CommitJob = Start-AzureRmRecoveryServicesAsrCommitFailoverJob -ReplicationProtectedItem $VM
                $CommitJobs += $CommitJob
            }
        }

        # Check Commit status
        $CommitFailure = $false
        $NumJobsComplete = 0
        $CommitErrors = @()
        while ($CommitJobs.Count -ne $NumJobsComplete) {
            $NumJobsComplete = 0
            $CommitStatii = @()
            foreach ($Job in $CommitJobs) {
                $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
                $CommitStatus = New-Object -TypeName System.Object
                $CommitStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                $CommitStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                $CommitStatii += $CommitStatus
                if ($JobStatus.State -like "Failed") {
                    $CommitError = New-Object -TypeName System.Object
                    $CommitError | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                    $CommitError | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                    $CommitError | Add-Member -Name Errors -MemberType NoteProperty -Value $JobStatus.Errors
                    $CommitErrors += $CommitError
                }
            }

            Write-Host -Object "Status at: $(Get-Date -UFormat '%H:%M:%S - %d/%m/%Y')"
            Write-Host ($CommitStatii | Format-Table | Out-String).Split("`n")[1]
            Write-Host ($CommitStatii | Format-Table | Out-String).Split("`n")[2]
            $CommitStatii | Out-String -Stream | ForEach-Object {
                if ($_ -clike "* Succeeded*") {
                    Write-Host -Object "$($_)" -ForegroundColor Green
                    $NumJobsComplete += 1
                }
                elseif ($_ -clike "* Failed*") {
                    Write-Host -Object "$($_)" -ForegroundColor Red
                    $NumJobsComplete += 1
                    $CommitFailure = $true
                }
                elseif ($_ -clike "* InProgress*") {
                    Write-Host -Object "$($_)"
                }
            }
            Write-Host -Object ""

            if ($CommitJobs.Count -ne $NumJobsComplete) {
                Start-Sleep -Seconds 30
            }
        }

        if ($CommitFailure -eq $true) {
            Write-Host -Object "One or more VMs failed to commit:"
            $CommitErrors | Format-Table
        }
        else {
            Write-Host -Object "Failover completed successfully" -ForegroundColor Green
        }
    }
}


function Start-AzureSiteRecoveryFailBack {
    <#
    .SYNOPSIS
        Performs a fail back of all VMs in an Azure resource group to Azure Stack.

    .DESCRIPTION
        Performs a failover of all protected VMs in a single vault to Azure. Will failover protected VMs asynchronously, then
        commit them to public Azure.

    .PARAMETER AzureResourceGroup
        The name of the resource group in public Azure. Example: "SiteRecovery-RG"

    .PARAMETER ClientId
        The application ID of a service principal with contributor permissions on Azure Stack. Example: "00000000-0000-0000-0000-000000000000"

    .PARAMETER ClientSecret
        A secret of the service principal specified in the ServicePrincipal parameter. Example: "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]="

    .PARAMETER ArmEndpoint
        The ARM endpoint for the Azure Stack endpoint you are failing back to. Defaults to: "https://management.frn00006.azure.ukcloud.com"

    .PARAMETER StackResourceGroup
        The name of the resource group to be created in Azure Stack that the VMs will be failed back to. Example: "FailBack-RG"

    .PARAMETER StackStorageAccount
        The name of the storage account to be created in Azure Stack that the VMs will be failed back to.
        Valid names must be alphanumeric and lower case. Example "failbacksa"

    .PARAMETER StackStorageContainer
        The name of the storage container to be created in the created storage account.
        Valid names must be alphanumeric and lower case.
        Example "failbackcontainer"

    .PARAMETER VNetName
        The name of the virtual network to place the VMs on after being failed back. Defaults to: "myVNetwork"

    .PARAMETER SubnetName
        The name of the subnet to be created in the created virtual network. Defaults to: "default"

    .PARAMETER VNetRange
        The range of the created virtual network in CIDR notation. Defaults to: "192.168.0.0/16"

    .PARAMETER SubnetRange
        The range of the created subnet in CIDR notation. Defaults to: "192.168.1.0/24"

    .PARAMETER NSGName
        The name of the network security group to place the VMs on after being failed back. Defaults to: "myNSG"

    .PARAMETER UseStorageAccount
        If declared the failed-back VMs will use a storage account instead of managed disks.

    .EXAMPLE
        Start-AzureSiteRecoveryFailBack -AzureResourceGroup "SiteRecovery-RG" -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -StackResourceGroup "FailBack-RG" -StackStorageAccount "failbacksa" `
            -StackStorageContainer "failbackcontainer"

    .EXAMPLE
        Start-AzureSiteRecoveryFailBack -AzureResourceGroup "SiteRecovery-RG" -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -ArmEndpoint "https://management.frn00006.azure.ukcloud.com" `
            -StackResourceGroup "FailBack-RG" -StackStorageAccount "failbacksa" -StackStorageContainer "failbackcontainer" -VNetName "myVNetwork" -SubnetName "default" -VNetRange "192.168.0.0/16" `
            -SubnetRange "192.168.1.0/24" -NSGName "myNSG"

    .NOTES
        This cmdlet shuts down the VMs running on public Azure to copy the disks. Please ensure that running workloads are saved before executing this command. Proceed at your own risk.
        This cmdlet does not remove the VMs from public Azure. Once you have confirmed that the fail back process has completed successfully, these can be removed with "Remove-AzureRmResourceGroup -Name $AzureResourceGroup".
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$AzureResourceGroup,
        [Parameter(Mandatory = $true)]
        [Alias("ServicePrincipal")]
        [String]$ClientId,
        [Parameter(Mandatory = $true)]
        [String]$ClientSecret,
        [Parameter(Mandatory = $false)]
        [String]$ArmEndpoint = "https://management.frn00006.azure.ukcloud.com",
        [Parameter(Mandatory = $true)]
        [String]$StackResourceGroup,
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^[a-z0-9]+$", Options = "None")]
        [String]$StackStorageAccount,
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^[a-z0-9]+$", Options = "None")]
        [String]$StackStorageContainer,
        [Parameter(Mandatory = $false)]
        [String]$VNetName = "myVNetwork",
        [Parameter(Mandatory = $false)]
        [String]$SubnetName = "default",
        [Parameter(Mandatory = $false)]
        [String]$VNetRange = "192.168.0.0/16",
        [Parameter(Mandatory = $false)]
        [String]$SubnetRange = "192.168.1.0/24",
        [Parameter(Mandatory = $false)]
        [String]$NSGName = "myNSG",
        [Parameter(Mandatory = $false)]
        [Switch]$UseStorageAccount
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into Azure Stack. Please login to public azure to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        $TenantId = (Get-AzureRmContext).Tenant.Id
        $RGName = Get-AzureRmResourceGroup -Name $AzureResourceGroup
        Write-Verbose -Message "Retrieving VMs from $($RGName.ResourceGroupName) resource group"
        $VMsinRG = Get-AzureRmVM -ResourceGroupName $($RGName.ResourceGroupName)
        $VMNames = @()
        foreach ($VM in $VMsinRG) {
            $VMNames += $($VM.Name)
        }

        Write-Host -Object "VMs to failback:"
        $VMNames
        Write-Host -Object ""

        # Declare Arrays
        $AzureDisks = @()
        $FailbackVMs = @()

        ### Get disk URIs
        Write-Host -Object "Retrieving Disk URIs"
        foreach ($VMName in $VMNames) {
            $VMObj = Get-AzureRmVM -ResourceGroupName $($RGName.ResourceGroupName) -Name $VMName
            $FailbackVMs += $VMObj
            Write-Host -Object "Stopping virtual machine: $($VMObj.Name)"
            Stop-AzureRmVM -Name $VMObj.Name -ResourceGroupName $VMObj.ResourceGroupName -Confirm:$false -Force
            Write-Host -Object "Retrieving disk URIs for VM: $($VMObj.Name)"
            if ($VMObj.StorageProfile.OsDisk.Vhd.Uri) {
                $VHDUri = $VMObj.StorageProfile.OsDisk.Vhd.Uri
            }
            elseif ($VMObj.StorageProfile.OsDisk.ManagedDisk) {
                $ManagedDisk = Get-AzureRmDisk -ResourceGroupName $($RGName.ResourceGroupName) -DiskName $($VMObj.StorageProfile.OsDisk.Name)
                $VHDUri = ($ManagedDisk | Grant-AzureRmDiskAccess -DurationInSecond 14400 -Access Read).AccessSAS
            }
            $AzureDisk = New-Object -TypeName System.Object
            $AzureDisk | Add-Member -Name VMName -MemberType NoteProperty -Value $VMObj.Name
            $AzureDisk | Add-Member -Name DiskType -MemberType NoteProperty -Value $VMObj.StorageProfile.OsDisk.OsType
            $AzureDisk | Add-Member -Name DiskName -MemberType NoteProperty -Value $VMObj.StorageProfile.OsDisk.Name
            $AzureDisk | Add-Member -Name DiskURI -MemberType NoteProperty -Value $VHDUri
            $AzureDisks += $AzureDisk
            if ($VMObj.StorageProfile.DataDisks) {
                foreach ($Disk in $VMObj.StorageProfile.DataDisks) {
                    if ($Disk.ManagedDisk) {
                        $ManagedDisk = Get-AzureRmDisk -ResourceGroupName $($RGName.ResourceGroupName) -DiskName $($Disk.Name)
                        $VHDUri = ($ManagedDisk | Grant-AzureRmDiskAccess -DurationInSecond 14400 -Access Read).AccessSAS
                    }
                    elseif ($Disk.Vhd) {
                        $VHDUri = $Disk.Vhd.Uri
                    }

                    $AzureDisk = New-Object -TypeName System.Object
                    $AzureDisk | Add-Member -Name VMName -MemberType NoteProperty -Value $VMObj.Name
                    $AzureDisk | Add-Member -Name DiskType -MemberType NoteProperty -Value "DataDisk"
                    $AzureDisk | Add-Member -Name DiskName -MemberType NoteProperty -Value $Disk.Name
                    $AzureDisk | Add-Member -Name DiskURI -MemberType NoteProperty -Value $VHDUri
                    $AzureDisks += $AzureDisk
                }
            }
        }

        # Login Azure Stack
        try {
            $CredentialPass = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential ($ClientID, $CredentialPass)
            $StackEnvironment = Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint
            Connect-AzureRmAccount -EnvironmentName "AzureStackUser" -Credential $Credentials -ServicePrincipal -Tenant $TenantID
        }
        catch {
            Write-Error -Message "$($_)"
            break
        }

        # Create base resources in Azure Stack
        $Location = $StackEnvironment.StorageEndpointSuffix.split(".")[0]

        Write-Host -Object "Creating resource group, storage account and container"
        try {
            $RG = New-AzureRmResourceGroup -Name $StackResourceGroup -Location $Location -Force
            $StorageAccount = New-AzureRmStorageAccount -Name $StackStorageAccount -Type Standard_LRS -Location $Location -ResourceGroupName $RG.ResourceGroupName
            $ImagesContainer = New-AzureStorageContainer -Name $StackStorageContainer -Permission Blob -Context $StorageAccount.Context
        }
        catch {
            Write-Error -Message "$($_)"
            break
        }

        Write-Host -Object "Starting copy operation from public Azure to Azure Stack"
        foreach ($VHD in $AzureDisks) {
            Start-AzureStorageBlobCopy -AbsoluteUri $VHD.DiskURI -DestContainer $ImagesContainer.Name -DestBlob $VHD.DiskName -DestContext $StorageAccount.Context
        }

        $Completed = 0
        while ($Completed -ne $AzureDisks.Count) {
            $CopyStatii = @()
            $Completed = 0
            foreach ($VHD in $AzureDisks) {
                $CurrentCopy = Get-AzureStorageBlobCopyState -Blob $VHD.DiskName -Container $ImagesContainer.Name -Context $StorageAccount.Context
                $CurrentCopy | Add-Member -Name DiskName -MemberType NoteProperty -Value $VHD.DiskName -Force
                $CopyStatii += $CurrentCopy
                if ($CurrentCopy.Status -like "Success") {
                    if (-not $UseStorageAccount) {
                        try {
                            $TestIfDiskExists = Get-AzureRmDisk -DiskName $VHD.DiskName -ResourceGroupName $RG.ResourceGroupName
                        }
                        catch {
                            $TestIfDiskExists = $null
                        }
                        if (!$TestIfDiskExists) {
                            $UploadedVHD = "$($StorageAccount.PrimaryEndpoints.Blob)$($ImagesContainer.Name)/$($VHD.DiskName)"
                            if ($VHD.DiskType -like "Linux") {
                                $DiskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD -OsType "Linux"
                            }
                            elseif ($VHD.DiskType -like "Windows") {
                                $DiskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD -OsType "Windows"
                            }
                            elseif ($VHD.DiskType -like "DataDisk") {
                                $DiskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD
                            }
                            $Disk = New-AzureRmDisk -Disk $DiskConfig -ResourceGroupName $RG.ResourceGroupName -DiskName $VHD.DiskName -Verbose
                        }
                    }
                    $Completed ++
                }
            }
            Write-Host -Object "Status at: $(Get-Date -UFormat '%H:%M:%S - %d/%m/%Y')"
            $CopyStatii | Select-Object -Property DiskName, BytesCopied, TotalBytes, Status | Format-Table
            if ($Completed -ne $AzureDisks.Count) {
                Start-Sleep -Seconds 30
            }
        }

        ## Create VMs
        # Create a subnet configuration
        Write-Host -Object "Creating virtual network"
        $SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetRange

        # Create a virtual network
        $VirtualNetwork = New-AzureRmVirtualNetwork -ResourceGroupName $RG.ResourceGroupName -Location $Location -Name $VNetName -AddressPrefix $VNetRange -Subnet $SubnetConfig

        # Create a network security group
        Write-Host -Object "Creating network security group"
        $NetworkSG = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RG.ResourceGroupName -Location $Location -Name $NSGName

        $StorageContainerLocation = "$($StorageAccount.PrimaryEndpoints.Blob)$($ImagesContainer.Name)"

        $VMSizes = Get-AzureRmVMSize -Location $Location

        foreach ($VM in $FailbackVMs) {
            Write-Host -Object "Creating VM: $($VM.Name)"

            $PublicIPName = "$($VM.Name)-IP"
            $NICName = "$($VM.Name)-NIC"
            $VMName = $VM.Name
            $VMSize = $VM.HardwareProfile.VMSize

            if ($VMSizes.Name -notcontains $VMSize) {
                if ($VMSizes.Name -notcontains $VMSize.Replace("v3", "v2")) {
                    Write-Warning -Message "Setting VMSize to Standard_F8s_v2 as $($VMSize) does not exist on Azure Stack"
                    $VMSize = "Standard_F8s_v2"
                }
                else {
                    Write-Warning -Message "Setting VMSize to $($VMSize.Replace("v3","v2")) as $($VMSize) does not exist on Azure Stack"
                    $VMSize = $VMSize.Replace("v3", "v2")
                }
            }

            # Create a public IP address
            $PublicIP = New-AzureRmPublicIpAddress -ResourceGroupName $RG.ResourceGroupName -Location $Location -AllocationMethod 'Dynamic' -Name $PublicIPName

            # Create a virtual network card and associate it with the public IP address and NSG
            $NetworkInterface = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $RG.ResourceGroupName -Location $Location -SubnetId $VirtualNetwork.Subnets[0].Id -PublicIpAddressId $PublicIP.Id -NetworkSecurityGroupId $NetworkSG.Id

            # Create the virtual machine configuration object
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize

            # Add Network Interface Card
            $VirtualMachine = Add-AzureRmVMNetworkInterface -Id $NetworkInterface.Id -VM $VirtualMachine

            # Apply the disk properties to the virtual machine config
            if (!$UseStorageAccount) {
                $OSDisk = Get-AzureRmDisk -ResourceGroupName $RG.ResourceGroupName -Name $VM.StorageProfile.OsDisk.Name
                if ($OSDisk.OsType -like "Linux") {
                    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $($OSDisk.Id) -StorageAccountType "StandardLRS" -CreateOption Attach -Linux
                }
                elseif ($OSDisk.OsType -like "Windows") {
                    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $($OSDisk.Id) -StorageAccountType "StandardLRS" -CreateOption Attach -Windows
                }

                $LunNumber = 0
                foreach ($DataDisk in $VM.StorageProfile.DataDisks) {
                    $DDisk = Get-AzureRmDisk -ResourceGroupName $RG.ResourceGroupName -Name $DataDisk.Name
                    $VirtualMachine = Add-AzureRmVMDataDisk -CreateOption Attach -Lun $LunNumber -VM $VirtualMachine -ManagedDiskId $DDisk.Id
                    $LunNumber ++
                }
            }
            else {
                if ($VM.StorageProfile.OsDisk.OsType -like "Linux") {
                    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -VhdUri "$($StorageContainerLocation)/$($VM.StorageProfile.OsDisk.Name)" `
                        -StorageAccountType "StandardLRS" -Name $VM.StorageProfile.OsDisk.Name -CreateOption Attach -Linux
                }
                elseif ($VM.StorageProfile.OsDisk.OsType -like "Windows") {
                    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -VhdUri "$($StorageContainerLocation)/$($VM.StorageProfile.OsDisk.Name)" `
                        -StorageAccountType "StandardLRS" -Name $VM.StorageProfile.OsDisk.Name -CreateOption Attach -Windows
                }

                $LunNumber = 0
                foreach ($DataDisk in $VM.StorageProfile.DataDisks) {
                    $VirtualMachine = Add-AzureRmVMDataDisk -Name $DataDisk.Name -CreateOption Attach -Lun $LunNumber -VM $VirtualMachine -VhdUri "$($StorageContainerLocation)/$($DataDisk.Name)"
                    $LunNumber ++
                }
            }

            # Create the virtual machine
            New-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Location $Location -VM $VirtualMachine -AsJob
        }
        while ($(Get-Job).State -like "*Running*" -or $(Get-Job).State -like "*NotStarted*") {
            Write-Host -Object "Status at: $(Get-Date -UFormat '%H:%M:%S - %d/%m/%Y')"
            Get-Job | Select-Object -Property Id, Command, PSBeginTime, PSEndTime, State | Format-Table
            Get-Job | Wait-Job -Timeout 30 | Out-Null
        }
        Write-Host -Object "All VMs have been created" -ForegroundColor Green
        Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName | Select-Object -Property Name, ResourceGroupName, ProvisioningState | Format-Table
    }
}
