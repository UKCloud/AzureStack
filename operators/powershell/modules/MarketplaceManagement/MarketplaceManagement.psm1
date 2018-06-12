Function Get-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Get Existing Marketplace Items
        
    .DESCRIPTION
        Get Existing Marketplace Items

    .PARAMETER ListDetails
        List all the details of Existing Marketplace Items
        Note: You cannot use it if you want to pipe the output to Remove-AzsMarketplaceImages

    .EXAMPLE
        Get-AzsMarketplaceImage

    .EXAMPLE
        Get-AzsMarketplaceImage -Verbose

    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [alias("AllProperties")]
        [switch]$ListDetails
    )
 
    begin {
        Try {
            Get-AzsLocation | Out-Null
            Write-Verbose -Message "Checking if user is logged in to Azure Stack"
        }
        Catch {
            Write-Error "Run Login-AzureRmAccount to login before running this command." 
            Break 
        }
    }
    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -like "*activation*"} | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Find all downloaded images
        $GetProducts = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG

        # Get all downloaded images details
        #$GetProducts | Select-Object -Property @{Name = 'DownloadName'; Expression = {(($_.Name) -replace "default/", "")}}, GalleryItemIdentity, DisplayName, publisherDisplayName, @{Name="SizeInMB";Expression={([math]::Round(($_.payloadLength / 1MB),2)) }}, @{Name="SizeInGB";Expression={([math]::Round(($_.payloadLength / 1GB),2)) }}, @{Name="productPropertiesVersion";Expression={$_.productProperties.version}}, provisioningState
        <#If ($ListDetails) {
            Write-Host "Hit1"
            $GetProducts | Select-Object -Property @{Name = 'DownloadName'; Expression = {(($_.Name) -replace "default/", "")}}, GalleryItemIdentity, DisplayName, publisherDisplayName, @{Name = "SizeInMB"; Expression = {([math]::Round(($_.payloadLength / 1MB), 2)) }}, @{Name = "SizeInGB"; Expression = {([math]::Round(($_.payloadLength / 1GB), 2)) }}, @{Name = "productPropertiesVersion"; Expression = {$_.productProperties.version}}, provisioningState
        }#>
    }
    end { 
        If ($ListDetails) {
            #Write-Host "Hit2"
            $GetProducts | Select-Object -Property @{Name = 'DownloadName'; Expression = {(($_.Name) -replace "default/", "")}}, GalleryItemIdentity, DisplayName, publisherDisplayName, @{Name = "SizeInMB"; Expression = {([math]::Round(($_.payloadLength / 1MB), 2)) }}, @{Name = "SizeInGB"; Expression = {([math]::Round(($_.payloadLength / 1GB), 2)) }}, @{Name = "productPropertiesVersion"; Expression = {$_.productProperties.version}}, provisioningState
        }
        Else {
            return $GetProducts | Select-Object -Property @{Name = 'DownloadName'; Expression = {(($_.Name) -replace "default/", "")}} | Select-Object -ExpandProperty DownloadName
        }
    }
}
Function Remove-AzsMarketplaceImagesAll {
    <#
    .SYNOPSIS
        Remove ALL Existing Marketplace Items

    .DESCRIPTION
        Remove ALL Existing Marketplace Items

    .EXAMPLE
        Remove-AzsMarketplaceImage

    .EXAMPLE
        Remove-AzsMarketplaceImage -Verbose

    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    param ()
 
    begin {
        Try {
            Get-AzsLocation | Out-Null
            Write-Verbose -Message "Checking if user is logged in to Azure Stack"
        }
        Catch {
            Write-Error "Run Login-AzureRmAccount to login before running this command." 
            Break 
        }
    }
    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -like "*activation*"} | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Find all downloaded images
        $GetProducts = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG

        # Delete all downloaded images
        $GetProducts |  Remove-AzsAzureBridgeDownloadedProduct -AsJob -Confirm:$false -Force #-WhatIf
    }
}


Function Remove-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Remove Existing Marketplace Items
        
    .DESCRIPTION
        Remove Existing Marketplace Items

    .PARAMETER ImagesToDelete
        Provide List of Images to delete manually or via Pipe from Get-AzsMarketplaceItems

    .EXAMPLE
        Remove-AzsMarketplaceImages

    .EXAMPLE
        Remove-AzsMarketplaceImages -Verbose

    .EXAMPLE
        Remove-AzsMarketplaceImages -Verbose -Confirm:$false
    
    .EXAMPLE
        Remove-AzsMarketplaceImages -Verbose -WhatIf

    .EXAMPLE
        Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January","SQLServer2016SP1StandardWindowsServer2016.February" -Confirm:$true -WhatIf
        
    .EXAMPLE
        Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January","SQLServer2016SP1StandardWindowsServer2016.February" -Confirm:$true -Force -WhatIf

    #>
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = "High")]
    param
    (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [alias("filter")]
        [AllowNull()]
        [AllowEmptyString()]
        $ImagesToDelete,
        [switch]$Force # = "custom*script*extension"
    )
 
    begin {
        Try {
            Get-AzsLocation | Out-Null
            Write-Verbose -Message "Checking if user is logged in to Azure Stack"
        }
        Catch {
            Write-Error "Run Login-AzureRmAccount to login before running this command." 
            Break 
        }
    }
    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -like "*activation*"} | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # If no images are specified delete all images
        If ([string]::IsNullOrEmpty(($ImagesToDelete))) {
            #Write-Host "Not Pipe 111111111111111111"
            If ($PSCmdlet.ShouldProcess($GetProducts.Name, 'Delete the downloaded product')) {
                #Write-Host "Not Pipe"
                # Find all downloaded images
                $GetProducts = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG
                # Delete all downloaded images
                $GetProducts |  Remove-AzsAzureBridgeDownloadedProduct -AsJob -Force # -Confirm:$true # -WhatIf
            }
        }
        # Delete all downloaded images from pipe
        #$ImagesToDelete
        ForEach ($Image in $ImagesToDelete) {
            #Write-Host "Not Pipe 2222222222222222222222222"
            If ($PSCmdlet.ShouldProcess($Image, 'Delete the downloaded product')) {
                if ($Force -or  $PSCmdlet.ShouldContinue("Are you sure you want to delete $($DownloadItemsLatestName.DownloadName)?", $null)) {
                    Remove-AzsAzureBridgeDownloadedProduct -Name $Image -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -AsJob -Force
                }
            }
        }
    }
}



Function Download-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Download Marketplace Items
    
    .DESCRIPTION
        Download Marketplace Items

    .PARAMETER ImagesToDownload    
        Provide List of Images to download
    
    .PARAMETER ListDetails    
        List all the details of Existing Marketplace Items
        Note: This will not download anything but only list items
    
    .EXAMPLE
        Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM."

    .EXAMPLE
        Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February"

    .EXAMPLE
        Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February"  -Verbose

    .EXAMPLE
        Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February"  -Verbose -Confirm:$false

    .EXAMPLE
        Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February"-WhatIf
    
    .EXAMPLE
        Download-AzsMarketplaceImages -Verbose -WhatIf

    .EXAMPLE
        # Declare Array of Images you want to download
        $ImagesToDownload = @(
            "SQLServer2016SP1StandardWindowsServer2016", `
            "SQLServer2016SP1EnterpriseWindowsServer2016", `
            "bitnami.jenkins", `
            "bitnami.nginxstack", `
            "Canonical.UbuntuServer1404LTS", `
            "Canonical.UbuntuServer1604LTS", `
            "Canonical.UbuntuServer1710", `
            "Canonical.UbuntuServer1804", `
            "Microsoft.Powershell.DSC-", `
            "Microsoft.SQLIaaSExtension.", `
            "Microsoft.WindowsServer2012Datacenter-ARM.*.paygo", `
            "Microsoft.WindowsServer2016Datacenter-ARM.*.paygo", `
            "Microsoft.WindowsServer2016DatacenterServerContainers-ARM.*.paygo", `
            "Microsoft.WindowsServer2016DatacenterServerCore-ARM.*.paygo", `
            "RogueWave.CentOSbased69-ARM.", `
            "RogueWave.CentOSbased73-ARM.", `
            "RogueWave.CentOSbased74-ARM." 
        )
        Download-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload
    #>
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'High')]
    param
    (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [alias("filter")]
        $ImagesToDownload, # = "custom*script*extension"
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [alias("AllProperties")]
        [switch]$ListDetails,
        [switch]$Force
    )
 
    begin {
        Try {
            Get-AzsLocation | Out-Null
            Write-Verbose -Message "Checking if user is logged in to Azure Stack"
        }
        Catch {
            Write-Error "Run Login-AzureRmAccount to login before running this command." 
            Break 
        }
    }
    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -like "*activation*"} | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Download selected images
        
        # Declare Empty Array to capture Names of Images to Download
        $ArrayOfDownloadItemsLatestNames = @()

        # Iterate through Array of Names to find the latest Image
        ForEach ($DownloadItem in $ImagesToDownload) {
            $LatestImage = Get-AzsAzureBridgeProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG | Where-Object {$_.Name -like "*$DownloadItem*"} | Select-Object -First 1
            # Create Custom Object to populate $ArrayOfDownloadItemsArray so we can pass it to Download Function
            $ourObject = [PSCustomObject]@{
                DownloadName             = $LatestImage | Select-Object -Property @{Name = 'DownloadName'; Expression = {(($_.Name) -replace "default/", "")}} | Select-Object -ExpandProperty DownloadName
                GalleryItemIdentity      = $LatestImage | Select-Object -ExpandProperty GalleryItemIdentity
                DisplayName              = $LatestImage | Select-Object -ExpandProperty DisplayName
                publisherDisplayName     = $LatestImage | Select-Object -ExpandProperty publisherDisplayName
                SizeInMB                 = $LatestImage | Select-Object -Property @{Name = "SizeInMB"; Expression = {([math]::Round(($_.payloadLength / 1MB), 2)) }}  | Select-Object -ExpandProperty SizeInMB
                SizeInGB                 = $LatestImage | Select-Object -Property @{Name = "SizeInGB"; Expression = {([math]::Round(($_.payloadLength / 1GB), 2)) }}  | Select-Object -ExpandProperty SizeInGB
                productPropertiesVersion = $LatestImage | Select-Object -Property @{Name = "productPropertiesVersion"; Expression = {$_.productProperties.version}} | Select-Object -ExpandProperty productPropertiesVersion
                provisioningState        = $LatestImage | Select-Object -ExpandProperty provisioningState
            }
            $ArrayOfDownloadItemsLatestNames += $ourObject
        }
        If ($ListDetails) {
            return $ArrayOfDownloadItemsLatestNames
        }
        Else {
            # Iterate through Latest Image names and download the image
            ForEach ($DownloadItemsLatestName in $ArrayOfDownloadItemsLatestNames) {
                If ($PSCmdlet.ShouldProcess($DownloadItemsLatestName.DownloadName, 'Start product download')) {
                    # Determine whether to continue with the command. Only continue if...
                    if ($Force -or  $PSCmdlet.ShouldContinue("Are you sure you want to download $($DownloadItemsLatestName.DownloadName)?", $null)) {
                        Invoke-AzsAzureBridgeProductDownload -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -Name $($DownloadItemsLatestName.DownloadName) -AsJob  -Force #-Confirm:$false #-WhatIf
                    }
                }
            }
        }
    }
}



<# Examples of usage
Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM." -WhatIf
Download-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February" -WhatIf

# Declare Array of Images you want to download
$ImagesToDownload = @(
    "SQLServer2016SP1StandardWindowsServer2016", `
    "SQLServer2016SP1EnterpriseWindowsServer2016", `
    "bitnami.jenkins", `
    "bitnami.nginxstack", `
    "Canonical.UbuntuServer1404LTS", `
    "Canonical.UbuntuServer1604LTS", `
    "Canonical.UbuntuServer1710", `
    "Canonical.UbuntuServer1804", `
    "Microsoft.Powershell.DSC-", `
    "Microsoft.SQLIaaSExtension.", `
    "Microsoft.WindowsServer2012Datacenter-ARM.*.paygo", `
    "Microsoft.WindowsServer2016Datacenter-ARM.*.paygo", `
    "Microsoft.WindowsServer2016DatacenterServerContainers-ARM.*.paygo", `
    "Microsoft.WindowsServer2016DatacenterServerCore-ARM.*.paygo", `
    "RogueWave.CentOSbased69-ARM.", `
    "RogueWave.CentOSbased73-ARM.", `
    "RogueWave.CentOSbased74-ARM." 
)
Download-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload -WhatIf
Download-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload -ListDetails -WhatIf


#Get-AzsMarketplaceImages |  Remove-AzsMarketplaceImages -WhatIf -Verbose
#$ImagesToDelete = "SQLServer2016SP1StandardWindowsServer2016.February"
#Remove-AzsAzureBridgeDownloadedProduct -Name $ImagesToDelete -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -WhatIf

#Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January","SQLServer2016SP1StandardWindowsServer2016.February" -WhatIf -Verbose
#Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January" -WhatIf -Confirm:$true
#Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January","SQLServer2016SP1StandardWindowsServer2016.February" -Confirm:$true -Force -WhatIf

#Remove-AzsMarketplaceImages -WhatIf
Get-AzsMarketplaceImages |  Remove-AzsMarketplaceImages -WhatIf -Verbose

Get-AzsMarketplaceImages -ListDetails
#>