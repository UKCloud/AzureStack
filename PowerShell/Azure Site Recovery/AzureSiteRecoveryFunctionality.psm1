function Test-AzureSiteRecoveryFailOver {
    <#
    .SYNOPSIS
        Performs a test failover of your protected VMs to Azure.

    .DESCRIPTION
        Performs a test failover of all protected VMs in a single vault to Azure. Will test failover protected VMs asynchronously, then
        perform clean-up asynchronously.

    .PARAMETER VaultName
        The name of the site recovery vault in public Azure. Example: "AzureStackRecoveryVault"

    .PARAMETER Username
        Your Azure AD username. Used for logging into public Azure. Example: "exampleuser@contoso.onmicrosoft.com"
    
    .PARAMETER Password
        Your Azure AD password as a SecureString. Used for logging into public Azure. If not specified then an input prompt will appear for this.

    .PARAMETER Confirmation
        Switch to specify whether to prompt the user to continue if the failover doesn't complete successfully

    .EXAMPLE
        Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault" -Username "exampleuser@contoso.onmicrosoft.com"

    .EXAMPLE
        Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault" -Username "exampleuser@contoso.onmicrosoft.com" -Password $SecurePass
    
    .EXAMPLE
        Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault" -Username "exampleuser@contoso.onmicrosoft.com" -Password $SecurePass -Confirmation
    
    .NOTES
        As this command performs a test failover, no production VMs will be affected.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VaultName,
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $false)]
        [SecureString]$Password = $(Read-Host "Input password" -AsSecureString -Force),
        [Parameter(Mandatory = $false)]
        [switch]$Confirmation
    )

    begin {
        try {
            $Credentials = New-Object System.Management.Automation.PSCredential ($Username, $Password) 
            Login-AzureRmAccount -Credential $Credentials
        }
        catch {
            Write-Host "Failed to login to public Azure. Exiting...." -ForegroundColor Red
            $Error[-1]
            break
        }
    }

    process {
        # Retrieve the vault information
        $VaultVar = Get-AzureRmRecoveryServicesVault -Name $VaultName
        Set-AzureRmRecoveryServicesAsrVaultContext -Vault $VaultVar
        $FabricVar = Get-AzureRmRecoveryServicesAsrFabric
        $ContainerVar = Get-AzureRmRecoveryServicesAsrProtectionContainer -Fabric $FabricVar
        $ProtectedVMs = Get-AzureRmRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ContainerVar
        Write-Host "VMs to test failover: $($ProtectedVMs.Name)" -ForegroundColor Green

        # Start test failover
        $FailoverJobs = @()
        foreach ($VM in $ProtectedVMs) {
            $FailoverJob = Start-AzureRmRecoveryServicesAsrTestFailoverJob -Direction PrimaryToRecovery -ReplicationProtectedItem $VM -AzureVMNetworkId $VM.SelectedRecoveryAzureNetworkId
            $FailoverJobs += $FailoverJob
        }

        # Check test failover status
        $FailureTest = $false
        $NumJobsComplete = 0
        While ($FailoverJobs.Count -ne $NumJobsComplete) {
            $NumJobsComplete = 0
            $FailoverStatii = @()
            foreach ($Job in $FailoverJobs) {
                $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
                $FailoverStatus = New-Object -TypeName System.Object
                $FailoverStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                $FailoverStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                $FailoverStatii += $FailoverStatus
            }
            Write-Host ""
            Write-Host "$(Get-Date -DisplayHint Time)"
            ($FailoverStatii | Format-Table | Out-String).split("`n")[1..2]
            $FailoverStatii | Out-String -Stream | ForEach-Object {
                if ($_ -clike "* Succeeded*") {
                    Write-Host "$($_)" -ForegroundColor Green
                    $NumJobsComplete += 1
                } elseif ($_ -clike "* Failed*") {
                    Write-Host "$($_)" -ForegroundColor Red
                    $NumJobsComplete += 1
                    $FailureTest = $true
                } elseif ($_ -clike "* InProgress*") {
                    Write-Host "$($_)"
                }
            }
            if ($FailoverJobs.Count -ne $NumJobsComplete) {
                Start-Sleep -Seconds 30
            }
        }

        # Start test failover clean-up
        Write-Host "Starting test failover clean-up"
        $CleanupJobs = @()
        foreach ($VM in $ProtectedVMs) {
            $CleanupJob = Start-AzureRmRecoveryServicesAsrTestFailoverCleanupJob -ReplicationProtectedItem $VM 
            $CleanupJobs += $CleanupJob
        }

        # Check status of clean-up jobs
        $CleanupFailureTest = $false
        $NumJobsComplete = 0
        While ($CleanupJobs.Count -ne $NumJobsComplete) {
            $NumJobsComplete = 0
            $CleanupStatii = @()
            foreach ($Job in $CleanupJobs) {
                $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
                $CleanupStatus = New-Object -TypeName System.Object
                $CleanupStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
                $CleanupStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
                $CleanupStatii += $CleanupStatus
            }
            Write-Host ""
            Write-Host "$(Get-Date -DisplayHint Time)"
            ($CleanupStatii | Format-Table | Out-String).split("`n")[1..2]
            $CleanupStatii | Out-String -Stream | ForEach-Object {
                if ($_ -clike "* Succeeded*") {
                    Write-Host "$($_)" -ForegroundColor Green
                    $NumJobsComplete += 1
                } elseif ($_ -clike "* Failed*") {
                    Write-Host "$($_)" -ForegroundColor Red
                    $NumJobsComplete += 1
                    $CleanupFailureTest = $true
                } elseif ($_ -clike "* InProgress*") {
                    Write-Host "$($_)"
                }
            }
            if ($CleanupJobs.Count -ne $NumJobsComplete) {
                Start-Sleep -Seconds 30
            }
        }
        if ($Confirmation -eq $true) {
            # Ask user if they want to continue if one or more test failover jobs fail
            $Valid = $false
            while ($Valid -eq $false -and $FailureTest -eq $true) {
                if ($FailureTest -eq $true) {
                    $YesNo = Read-Host -Prompt "One or more of the VMs failed during test failover. Are you sure you want to proceed? (y/n)"
                    if ($YesNo -like "*n*") {
                        Write-Host "Exiting..."
                        return $false
                    } elseif ($YesNo -notlike "*y*") {
                        Write-Host ""
                        Write-Host "Please enter a valid option (E.G. y or n)"
                    } else {
                        Write-Host "Proceeding..."
                        $Valid = $true   
                    }
                }
            }

            # Ask user if they want to continue if one or more cleanup jobs fail
            $Valid = $false
            while ($Valid -eq $false -and $CleanupFailureTest -eq $true) {
                if ($CleanupFailureTest -eq $true) {
                    $YesNo = Read-Host -Prompt "One or more of the VMs failed during test failover clean-up. Are you sure you want to proceed? (y/n)"
                    if ($YesNo -like "*n*") {
                        Write-Host "Exiting..."
                        return $false
                    } elseif ($YesNo -notlike "*y*") {
                        Write-Host ""
                        Write-Host "Please enter a valid option (E.G. y or n)"
                    } else {
                        Write-Host "Proceeding..."
                        $Valid = $true   
                    }
                }
            }
        } else {
            $Valid = $true
            if ($FailureTest -eq $true) {
                Write-Host "One or more of the VMs failed during test failover." -ForegroundColor Red
                $Valid = $false
            }
            if ($CleanupFailureTest -eq $true) {
                Write-Host "One or more of the VMs failed during test failover clean-up." -ForegroundColor Red
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

    .PARAMETER Username
        Your Azure AD username. Used for logging into public Azure. Example: "exampleuser@contoso.onmicrosoft.com"
    
    .PARAMETER Password
        Your Azure AD password as a SecureString. Used for logging into public Azure. If not specified then an input prompt will appear for this.

    .EXAMPLE
        Start-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault" -Username "exampleuser@contoso.onmicrosoft.com"

    .EXAMPLE
        Start-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault" -Username "exampleuser@contoso.onmicrosoft.com" -Password $SecurePass
    
    .NOTES
        This command performs a full failover of your production VMs. As part of this process your VMs may be shut down. Proceed at your own risk.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VaultName,
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $false)]
        [SecureString]$Password = $(Read-Host "Input password" -AsSecureString -Force)
    )

    begin {
        try {
            $Credentials = New-Object System.Management.Automation.PSCredential ($Username, $Password) 
            Login-AzureRmAccount -Credential $Credentials
        }
        catch {
            Write-Host "Failed to login to public Azure. Exiting...." -ForegroundColor Red
            $Error[-1]
            break
        }
    }

    process {
        $TestSuccessful = Test-AzureSiteRecoveryFailover -VaultName $VaultName -Username $Username -Password $Password -Confirmation

        if ($TestSuccessful -eq $false) {
            break
        } elseif ($TestSuccessful -eq $true) {

            # Start actual failover
            Write-Host "Starting failover..."
            $FailoverJobs = @()
            foreach ($VM in $ProtectedVMs) {
                $FailoverJob = Start-AzureRmRecoveryServicesAsrUnplannedFailoverJob -Direction PrimaryToRecovery -ReplicationProtectedItem $VM
                $FailoverJobs += $FailoverJob
            }

            # Checking failover status
            $Failure = $false
            $FailoverErrors = @()
            $NumJobsComplete = 0
            While ($FailoverJobs.Count -ne $NumJobsComplete) {
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
                Write-Host ""
                Write-Host "$(Get-Date -DisplayHint Time)"
                ($FailoverStatii | Format-Table | Out-String).split("`n")[1..2]
                $FailoverStatii | Out-String -Stream | ForEach-Object {
                    if ($_ -clike "* Succeeded*") {
                        Write-Host "$($_)" -ForegroundColor Green
                        $NumJobsComplete += 1
                    } elseif ($_ -clike "* Failed*") {
                        Write-Host "$($_)" -ForegroundColor Red
                        $NumJobsComplete += 1
                        $Failure = $true
                    } elseif ($_ -clike "* InProgress*") {
                        Write-Host "$($_)"
                    }
                }
                if ($FailoverJobs.Count -ne $NumJobsComplete) {
                    Start-Sleep -Seconds 30
                }
            }

            if ($Failure -eq $true) {
                Write-Host "One or more VMs failed to failover:"
                $FailoverErrors | Format-Table
            } else {
                Write-Host "Committing replicated VMs..."
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
            While ($CommitJobs.Count -ne $NumJobsComplete) {
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
                Write-Host ""
                Write-Host "$(Get-Date -DisplayHint Time)"
                ($CommitStatii | Format-Table | Out-String).split("`n")[1..2]
                $CommitStatii | Out-String -Stream | ForEach-Object {
                    if ($_ -clike "* Succeeded*") {
                        Write-Host "$($_)" -ForegroundColor Green
                        $NumJobsComplete += 1
                    } elseif ($_ -clike "* Failed*") {
                        Write-Host "$($_)" -ForegroundColor Red
                        $NumJobsComplete += 1
                        $CommitFailure = $true
                    } elseif ($_ -clike "* InProgress*") {
                        Write-Host "$($_)"
                    }
                }
                if ($CommitJobs.Count -ne $NumJobsComplete) {
                    Start-Sleep -Seconds 30
                }
            }

            if ($CommitFailure -eq $true) {
                Write-Host "One or more VMs failed to commit:"
                $FailoverErrors | Format-Table
            } else {
                Write-Host "Failover completed successfully" -ForegroundColor Green
            }
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

    .PARAMETER Username
        Your Azure AD username. Used for logging into public Azure. Example: "exampleuser@contoso.onmicrosoft.com"
    
    .PARAMETER Password
        Your Azure AD password as a SecureString. Used for logging into public Azure. If not specified then an input prompt will appear for this.
    
    .PARAMETER ArmEndpoint
        The ARM endpoint for the Azure Stack endpoint you are failing back to. Defaults to: "https://management.frn00006.azure.ukcloud.com"

    .PARAMETER StackResourceGroup
        The name of the resource group to be created in Azure Stack that the VMs will be failed back to. Example: "FailBack-RG"

    .PARAMETER StackStorageAccount
        The name of the storage account to be created in Azure Stack that the VMs will be failed back to. Example "FailBackSA"

    .PARAMETER StackStorageContainer
        The name of the storage container to be created in the created storage account. Example "FailBackContainer"
    
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

    .EXAMPLE
        Start-AzureSiteRecoveryFailOver -AzureResourceGroup "SiteRecovery-RG" -Username "exampleuser@contoso.onmicrosoft.com" -StackResourceGroup "FailBack-RG" -StackStorageAccount "FailBackSA" `
            -StackStorageContainer "FailBackContainer"

    .EXAMPLE
        Start-AzureSiteRecoveryFailOver -AzureResourceGroup "SiteRecovery-RG" -Username "exampleuser@contoso.onmicrosoft.com" -Password $SecurePassword -ArmEndpoint "https://management.frn00006.azure.ukcloud.com" `
            -StackResourceGroup "FailBack-RG" -StackStorageAccount "FailBackSA" -StackStorageContainer "FailBackContainer" -VNetName "myVNetwork" -SubnetName "default" -VNetRange "192.168.0.0/16" `
            -SubnetRange "192.168.1.0/24" -NSGName "myNSG"
    
    .NOTES
        This command does not clear the VMs from public Azure. Once you have confirmed that the fail back process has completed successfully, these can be removed with Remove-AzureRmResourceGroup -Name $AzureResourceGroup
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$AzureResourceGroup,
        [Parameter(Mandatory = $true)]
        [String]$Username,
        [Parameter(Mandatory = $false)] 
        [SecureString]$Password = $(Read-Host "Input password" -AsSecureString -Force),
        [Parameter(Mandatory = $false)]
        [String]$ArmEndpoint = "https://management.frn00006.azure.ukcloud.com",
        [Parameter(Mandatory = $true)]
        [String]$StackResourceGroup,
        [Parameter(Mandatory = $true)]
        [String]$StackStorageAccount,
        [Parameter(Mandatory = $true)]
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
        [String]$NSGName = "myNSG"
    )
    begin {
        try {
            $Credentials = New-Object System.Management.Automation.PSCredential ($Username, $Password) 
            Login-AzureRmAccount -Credential $Credentials
        }
        catch {
            Write-Host "Failed to login to public Azure. Exiting...." -ForegroundColor Red
            $Error[-1]
            break
        }
    }
    process {
        $RGName = Get-AzureRmResourceGroup -Name $AzureResourceGroup
        Write-Host "Retrieving VMs from $($RGName.ResourceGroupName) resource group"
        $VMsinRG = Get-AzureRmVM -ResourceGroupName $($RGName.ResourceGroupName)
        $VMNames = @()
        Foreach ($VM in $VMsinRG) {
            $VMNames += $($VM.Name)
        }

        Write-Host "VMs to failback:"
        $VMNames

        # Declare Arrays
        $AzureDisks = @()
        $FailbackVMs = @()

        ### Get disk URIs
        Write-Host "Retrieving Disk URIs"
        ForEach ($VMName in $VMNames) {
            $VMObj = Get-AzureRmVM -ResourceGroupName $($RGName.ResourceGroupName) -Name $VMName
            $FailbackVMs += $VMObj
            Write-Host "Stopping virtual machine $($VMObj.Name)"
            Stop-AzureRmVM -Name $VMObj.Name -ResourceGroupName $VMObj.ResourceGroupName -Confirm:$false -Force
            if ($VMObj.StorageProfile.OsDisk.Vhd.Uri) {
                $VHDUri = $VMObj.StorageProfile.OsDisk.Vhd.Uri
            } elseif ($VMObj.StorageProfile.OsDisk.ManagedDisk) {
                $ManagedDisk = Get-AzureRmDisk -ResourceGroupName $($RGName.ResourceGroupName) -DiskName $($VMObj.StorageProfile.OsDisk.Name)
                $VHDUri = $ManagedDisk | Grant-AzureRmDiskAccess -DurationInSecond 7200 -Access Read
            }
            $AzureDisk = New-Object -TypeName System.Object
            $AzureDisk | Add-Member -Name VMName -MemberType NoteProperty -Value $VMObj.Name
            $AzureDisk | Add-Member -Name DiskType -MemberType NoteProperty -Value $VMObj.StorageProfile.OsDisk.OsType
            $AzureDisk | Add-Member -Name DiskName -MemberType NoteProperty -Value $VMObj.StorageProfile.OsDisk.Name
            $AzureDisk | Add-Member -Name DiskURI -MemberType NoteProperty -Value $VHDUri
            $AzureDisks += $AzureDisk
            if ($VMObj.StorageProfile.DataDisks) {
                ForEach ($Disk in $VMObj.StorageProfile.DataDisks) {
                    $ManagedDisk = Get-AzureRmDisk -ResourceGroupName $($RGName.ResourceGroupName) -DiskName $($Disk.Name)
                    $VHDUri = $ManagedDisk | Grant-AzureRmDiskAccess -DurationInSecond 7200 -Access Read
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
        $StackEnvironment = Add-AzureRMEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint
        Login-AzureRmAccount -EnvironmentName "AzureStackUser" -Credential $Credentials

        # Create storage account in Azure Stack
        $Location = $StackEnvironment.GalleryURL.split(".")[1]

        Write-Host "Creating resource group, storage account and container"
        $RG = New-AzureRmResourceGroup -Name $StackResourceGroup -Location $Location -Force
        $StorageAccount = New-AzureRmStorageAccount -Name $StackStorageAccount -Type Standard_LRS -Location $Location -ResourceGroupName $RG.ResourceGroupName
        $ImagesContainer = New-AzureStorageContainer -Name $StackStorageContainer -Permission Blob -Context $StorageAccount.Context

        Write-Host "Starting copy operation from public Azure to Azure Stack"
        Foreach ($VHD in $AzureDisks) {
            Start-AzureStorageBlobCopy -AbsoluteUri $VHD.DiskURI.AccessSAS -DestContainer $ImagesContainer.Name -DestBlob $VHD.DiskName -DestContext $StorageAccount.Context
        }

        $Completed = 0
        While ($Completed -ne $AzureDisks.Count) {
            $Completed = 0
            foreach ($VHD in $AzureDisks) {
                $CurrentCopy = Get-AzureStorageBlobCopyState -Blob $VHD.DiskName -Container $ImagesContainer.Name -Context $StorageAccount.Context
                if ($CurrentCopy.Status -like "Success") {
                    try {
                        $TestIfDiskExists = Get-AzureRmDisk -DiskName $VHD.DiskName -ResourceGroupName $RG.ResourceGroupName
                    } catch {
                        $TestIfDiskExists = $null
                    }
                    if (!$TestIfDiskExists) {
                        $UploadedVHD = "$($StorageAccount.PrimaryEndpoints.Blob)$($StorageContainer)/$($VHD.DiskName)"
                        if ($VHD.DiskType -like "Linux") {
                            $diskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD -OsType "Linux"
                        } elseif ($VHD.DiskType -like "Windows") {
                            $diskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD -OsType "Windows"
                        } elseif ($VHD.DiskType -like "DataDisk") {
                            $diskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD
                        }
                        $disk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $RG.ResourceGroupName -DiskName $VHD.DiskName -Verbose
                    }
                    $Completed ++
                }
            }
            Start-Sleep -Seconds 20
        }


        ## Create VMS

        # Create a subnet configuration
        Write-Host "Creating virtual network"
        $SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetRange

        # Create a virtual network
        $VirtualNetwork = New-AzureRmVirtualNetwork -ResourceGroupName $RG.ResourceGroupName -Location $Location -Name $VNetName -AddressPrefix $VNetRange -Subnet $SubnetConfig

        # Create a network security group
        Write-Host "Creating network security group"
        $NetworkSG = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RG.ResourceGroupName -Location $Location -Name $NSGName

        ForEach ($Vm in $FailbackVMs) {
            Write-Host "Creating VM: $($VM.Name)"
    
            $PublicIPName = "$($VM.Name)IP"
            $NICName = ($Vm.NetworkProfile.NetworkInterfaces.id).split("/")[8]
            $VMName = ($VM.Name)
            $VMSize = $Vm.HardwareProfile.VmSize
    
            # Create a public IP address
            $PublicIP = New-AzureRmPublicIpAddress -ResourceGroupName $RG.ResourceGroupName -Location $Location -AllocationMethod 'Dynamic' -Name $PublicIPName
    
            # Create a virtual network card and associate it with the public IP address and NSG
            $NetworkInterface = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $RG.ResourceGroupName -Location $Location -SubnetId $VirtualNetwork.Subnets[0].Id -PublicIpAddressId $PublicIP.Id -NetworkSecurityGroupId $NetworkSG.Id
    
            # Create the virtual machine configuration object
            $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
    
            # Add Network Interface Card 
            $VirtualMachine = Add-AzureRmVMNetworkInterface -Id $NetworkInterface.Id -VM $VirtualMachine
    
            # Applies the OS disk properties to the virtual machine.
            $OSDisk = Get-AzureRMDisk -ResourceGroupName $RG.ResourceGroupName -Name $Vm.StorageProfile.OsDisk.Name
            if ($OSDisk.OsType -like "Linux") {
                $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $($OSDisk.Id) -StorageAccountType "StandardLRS" -CreateOption Attach -Linux
            } elseif ($OSDisk.OsType -like "Windows") {
                $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $($OSDisk.Id) -StorageAccountType "StandardLRS" -CreateOption Attach -Windows
            }
    
    
            $LunNumber = 0
            ForEach ($DataDisk in $Vm.StorageProfile.DataDisks) {
                $DDisk = Get-AzureRMDisk -ResourceGroupName $RG.ResourceGroupName -Name $DataDisk.Name
                $VirtualMachine = Add-AzureRmVMDataDisk -CreateOption Attach -Lun $LunNumber -VM $VirtualMachine -ManagedDiskId $DDisk.Id
                $LunNumber ++
            }
    
            # Create the virtual machine.
            $NewVM = New-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Location $Location -VM $VirtualMachine
            $NewVM
    
        }
    }
}

