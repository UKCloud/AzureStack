param (
    [string]$AzureResourceGroup = $(throw "-AzureResourceGroup is required."),
    [string]$Username = $(throw "-Username is required."),  
    [string]$Password = $(Read-Host "Input password" -AsSecureString -Force),
    [string]$ArmEndpoint = $(throw "-ArmEndpoint is required."),
    [string]$StackResourceGroup = $(throw "-StackResourceGroup is required."),
    [string]$StackStorageAccount = $(throw "-StackStorageAccount is required."),
    [string]$StackStorageContainer =  $(throw "-StackStorageContainer is required."),
    [string]$VNetName = "myVNetwork",
    [string]$SubnetName = 'default',
    [string]$SubnetRange = '192.168.1.0/24',
    [string]$VNetRange = '192.168.0.0/16',
    [string]$NSGName = 'myNSG'
)


$Credentials = New-Object System.Management.Automation.PSCredential ($Username, $Password) 
Login-AzureRmAccount -Credential $Credentials

$RGName = Get-AzureRmResourceGroup -Name $AzureResourceGroup
Write-Host "Retrieving VMs from $($RGName.ResourceGroupName) resource group"
$VMsinRG = Get-AzureRmVM -ResourceGroupName $($RGName.ResourceGroupName)
$VMNames = @()
Foreach ($VM in $VMsinRG) {
    $VMNames += $($VM.Name)
}

Write-Host "VMs to failback:"
$VMNames



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
    }
    elseif ($VMObj.StorageProfile.OsDisk.ManagedDisk) {
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

$StackEnvironment = Add-AzureRMEnvironment -Name 'AzureStack' -ArmEndpoint $ArmEndpoint
Login-AzureRmAccount -EnvironmentName 'AzureStack' -Credential $Credentials

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
    foreach ($VHD in $AzureDisks){
        $CurrentCopy = Get-AzureStorageBlobCopyState -Blob $VHD.DiskName -Container $ImagesContainer.Name -Context $StorageAccount.Context
        if ($CurrentCopy.Status -like "Success") {
            try {
                $TestIfDiskExists = Get-AzureRmDisk -DiskName $VHD.DiskName -ResourceGroupName $RG.ResourceGroupName
            }
            catch {
                $TestIfDiskExists = $null
            }
            if (!$TestIfDiskExists) {
                $UploadedVHD = "$($StorageAccount.PrimaryEndpoints.Blob)$($StorageContainer)/$($VHD.DiskName)"
                if ($VHD.DiskType -like "Linux") {
                    $diskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD -OsType "Linux"
                }
                elseif ($VHD.DiskType -like "Windows") {
                    $diskConfig = New-AzureRmDiskConfig -AccountType "StandardLRS" -Location $Location -CreateOption Import -SourceUri $UploadedVHD -OsType "Windows"
                }
                elseif ($VHD.DiskType -like "DataDisk") {
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
    if ($OSDisk.OsType -like "Linux"){
        $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -ManagedDiskId $($OSDisk.Id) -StorageAccountType "StandardLRS" -CreateOption Attach -Linux
    }
    elseif ($OSDisk.OsType -like "Windows"){
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