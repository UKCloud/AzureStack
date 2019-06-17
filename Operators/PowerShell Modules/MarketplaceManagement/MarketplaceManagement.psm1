function Get-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Get existing marketplace items

    .DESCRIPTION
        Get existing marketplace items

    .PARAMETER ListDetails
        List all the details of existing marketplace items
        Note: You cannot use it if you want to pipe the output to Remove-AzsMarketplaceImages

    .EXAMPLE
        Get-AzsMarketplaceImage

    .EXAMPLE
        Get-AzsMarketplaceImage -ListDetails -Verbose

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("AllProperties")]
        [Switch]$ListDetails
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find activation resource group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Find all downloaded images
        $GetProducts = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG

        # Return/Print downloaded image array
        if ($ListDetails) {
            $GetProducts | Select-Object -Property @{Name = 'DownloadName'; Expression = { (($_.Name) -replace "default/", "") }}, GalleryItemIdentity, DisplayName, PublisherDisplayName, PublisherIdentifier, Offer, OfferVersion, Sku, @{Name = "SizeInMB"; Expression = { ([Math]::Round(($_.PayloadLength / 1MB), 2)) }}, @{Name = "SizeInGB"; Expression = { ([Math]::Round(($_.PayloadLength / 1GB), 2)) }}, @{Name = "ProductVersionNumber"; Expression = { $_.ProductProperties.Version }}, ProvisioningState, Description
        }
        else {
            $GetProducts | Select-Object -Property DisplayName, @{Name = 'DownloadName'; Expression = { (($_.Name) -replace "default/", "") }}, PublisherIdentifier, Offer, OfferVersion, Sku, ProductKind, ProductProperties
        }
    }
}

function Remove-AzsMarketplaceImagesAll {
    <#
    .SYNOPSIS
        Remove ALL existing marketplace items

    .DESCRIPTION
        Remove ALL existing marketplace items

    .EXAMPLE
        Remove-AzsMarketplaceImage

    .EXAMPLE
        Remove-AzsMarketplaceImage -Verbose

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find activation resource group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find activation details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Find all downloaded images
        $GetProducts = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG

        # Delete all downloaded images
        $GetProducts | Remove-AzsAzureBridgeDownloadedProduct -AsJob -Confirm:$false -Force
    }
}


function Remove-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Remove existing marketplace items

    .DESCRIPTION
        Remove existing marketplace items

    .PARAMETER ImagesToDelete
        Provide list of images to delete manually or via pipe from Get-AzsMarketplaceItems

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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param
    (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Alias("Filter")]
        [AllowNull()]
        [AllowEmptyString()]
        [String[]]
        $ImagesToDelete,
        [Parameter(Mandatory = $false)]
        [Switch]
        $Force
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # If no images are specified delete all images
        if ([String]::IsNullOrEmpty(($ImagesToDelete))) {
            if ($PSCmdlet.ShouldProcess($GetProducts.Name, "Delete the downloaded product")) {
                # Find all downloaded images
                $GetProducts = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG
                # Delete all downloaded images
                $GetProducts | Remove-AzsAzureBridgeDownloadedProduct -AsJob -Confirm:$false -Force
            }
        }
        # Delete all downloaded images from pipe
        foreach ($Image in $ImagesToDelete) {
            if ($PSCmdlet.ShouldProcess($Image, "Delete the downloaded product")) {
                if ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to delete $($DownloadItemsLatestName.DownloadName)?", $null)) {
                    Remove-AzsAzureBridgeDownloadedProduct -Name $Image -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -AsJob -Confirm:$false -Force
                }
            }
        }
    }
}

function Import-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Download marketplace items

    .DESCRIPTION
        Download marketplace items

    .PARAMETER ImagesToDownload
        Provide list of images to download

    .PARAMETER ListDetails
        List all the details of Existing Marketplace Items
        Note: This will not download anything but only list items

    .EXAMPLE
        Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM."

    .EXAMPLE
        Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February"

    .EXAMPLE
        Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February" -Verbose

    .EXAMPLE
        Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February" -Verbose -Confirm:$false

    .EXAMPLE
        Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February" -WhatIf

    .EXAMPLE
        Import-AzsMarketplaceImages -Verbose -WhatIf

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
        Import-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload

    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
        [Alias("Filter")]
        $ImagesToDownload, # = "custom*script*extension"
        [Parameter(Mandatory = $false)]
        [Alias("AllProperties")]
        [Switch]
        $ListDetails,
        [Parameter(Mandatory = $false)]
        [Switch]
        $Force
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Download selected images

        # Declare Empty Array to capture Names of Images to Download
        $ArrayOfDownloadItemsLatestNames = @()

        # Iterate through Array of Names to find the latest Image
        foreach ($DownloadItem in $ImagesToDownload) {
            $LatestImage = Get-AzsAzureBridgeProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG | Where-Object -FilterScript { $_.Name -like "*$DownloadItem*" } | Select-Object -First 1
            # Create Custom Object to populate $ArrayOfDownloadItemsArray so we can pass it to Download function
            $OurObject = [PSCustomObject]@{
                DownloadName             = $LatestImage | Select-Object -Property @{Name = 'DownloadName'; Expression = { (($_.Name) -replace "default/", "") }} | Select-Object -ExpandProperty DownloadName
                GalleryItemIdentity      = $LatestImage | Select-Object -ExpandProperty GalleryItemIdentity
                DisplayName              = $LatestImage | Select-Object -ExpandProperty DisplayName
                PublisherDisplayName     = $LatestImage | Select-Object -ExpandProperty PublisherDisplayName
                PublisherIdentifier      = $LatestImage | Select-Object -ExpandProperty PublisherIdentifier
                SizeInMB                 = $LatestImage | Select-Object -Property @{Name = "SizeInMB"; Expression = { ([Math]::Round(($_.PayloadLength / 1MB), 2)) }} | Select-Object -ExpandProperty SizeInMB
                SizeInGB                 = $LatestImage | Select-Object -Property @{Name = "SizeInGB"; Expression = { ([Math]::Round(($_.PayloadLength / 1GB), 2)) }} | Select-Object -ExpandProperty SizeInGB
                ProductPropertiesVersion = $LatestImage | Select-Object -Property @{Name = "ProductVersionNumber"; Expression = { $_.ProductProperties.Version }} | Select-Object -ExpandProperty ProductPropertiesVersion
                Offer                    = $LatestImage | Select-Object -ExpandProperty Offer
                OfferVersion             = $LatestImage | Select-Object -ExpandProperty OfferVersion
                Sku                      = $LatestImage | Select-Object -ExpandProperty Sku
                ProvisioningState        = $LatestImage | Select-Object -ExpandProperty ProvisioningState
            }
            $ArrayOfDownloadItemsLatestNames += $OurObject
        }
        if ($ListDetails) {
            return $ArrayOfDownloadItemsLatestNames
        }
        else {
            # Iterate through Latest Image names and download the image
            foreach ($DownloadItemsLatestName in $ArrayOfDownloadItemsLatestNames) {
                if ($PSCmdlet.ShouldProcess($DownloadItemsLatestName.DownloadName, "Start product download")) {
                    # Determine whether to continue with the command. Only continue if...
                    if ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to download $($DownloadItemsLatestName.DownloadName)?", $null)) {
                        Invoke-AzsAzureBridgeProductDownload -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -Name $($DownloadItemsLatestName.DownloadName) -AsJob -Force #-Confirm:$false #-WhatIf
                    }
                }
            }
        }
    }
}

function Get-AzsAvailableMarketplaceImages {
    <#
    .SYNOPSIS
        Get a list of Available Marketplace Items

    .DESCRIPTION
        Get a list of Available Marketplace Items so that we can compare the lists

    .PARAMETER ListDetails
        List all the details of Available Marketplace Items
        Note: You cannot use it if you want to pipe the output to Remove-AzsMarketplaceImages

    .PARAMETER LatestImages
        List only the latest images

    .EXAMPLE
        Get-AzsAvailableMarketplaceImages

    .EXAMPLE
        Get-AzsAvailableMarketplaceImages -ListDetails

    .EXAMPLE
        Get-AzsAvailableMarketplaceImages -ListDetails -LatestImages

    .EXAMPLE
        Get-AzsAvailableMarketplaceImages -Verbose

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Alias("AllProperties")]
        [Switch]
        $ListDetails,
        [Parameter(Mandatory = $false)]
        [Switch]
        $LatestImages
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find Activation Resource Group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # List available images
        $ListOfImages = Get-AzsAzureBridgeProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG

        if ($LatestImages) {
            $ListOfImages = $ListOfImages | Group-Object -Property DisplayName -AsString -AsHashTable
            $LatestImagesArray = @()
            foreach ($Table in $ListOfImages.Values) {
                $NewestVersionNumber = ($Table.ProductProperties.Version | Measure-Object -Maximum).Maximum
                $NewestVersion = $Table | Where-Object -FilterScript { $_.ProductProperties.Version -eq $NewestVersionNumber }
                $LatestImagesArray += $NewestVersion
            }
            $ListOfImages = $LatestImagesArray
        }

        if ($ListDetails) {
            # Declare Empty Array to capture Names of Images to List
            $ArrayOfAvailableItems = @()

            # Iterate through Array of Names to find the Image Details
            foreach ($Image in $ListOfImages) {
                # Create Custom Object to populate $ArrayOfDownloadItemsArray so we can pass it to Download function
                $OurObject = [PSCustomObject]@{
                    DownloadName             = $Image | Select-Object -Property @{Name = 'DownloadName'; Expression = { (($_.Name) -replace "default/", "") }} | Select-Object -ExpandProperty DownloadName
                    GalleryItemIdentity      = $Image | Select-Object -ExpandProperty GalleryItemIdentity
                    DisplayName              = $Image | Select-Object -ExpandProperty DisplayName
                    PublisherDisplayName     = $Image | Select-Object -ExpandProperty PublisherDisplayName
                    PublisherIdentifier      = $Image | Select-Object -ExpandProperty PublisherIdentifier
                    SizeInMB                 = $Image | Select-Object -Property @{Name = "SizeInMB"; Expression = { ([Math]::Round(($_.PayloadLength / 1MB), 2)) }} | Select-Object -ExpandProperty SizeInMB
                    SizeInGB                 = $Image | Select-Object -Property @{Name = "SizeInGB"; Expression = { ([Math]::Round(($_.PayloadLength / 1GB), 2)) }} | Select-Object -ExpandProperty SizeInGB
                    ProductPropertiesVersion = $Image | Select-Object -Property @{Name = "ProductVersionNumber"; Expression = { $_.ProductProperties.Version }} | Select-Object -ExpandProperty ProductPropertiesVersion
                    Offer                    = $Image | Select-Object -ExpandProperty Offer
                    OfferVersion             = $Image | Select-Object -ExpandProperty OfferVersion
                    Sku                      = $Image | Select-Object -ExpandProperty Sku
                    ProvisioningState        = $Image | Select-Object -ExpandProperty ProvisioningState
                }
                $ArrayOfAvailableItems += $OurObject
            }
            return $ArrayOfAvailableItems
        }
        else {
            return $ListOfImages
        }
    }
}

function Update-AzsMarketplaceImages {
    <#
    .SYNOPSIS
        Get a list of marketplace images where updates are available and download the updated versions.

    .DESCRIPTION
        Get a list of marketplace images (virtual machines and virtual machine extensions) where updates are available and download the updated versions.

    .PARAMETER ListDetails
        Only list the available updates instead of downloading them

    .EXAMPLE
        Update-AzsMarketplaceImages

    .EXAMPLE
        Update-AzsMarketplaceImages -ListDetails

    .NOTES
        Most of the code here is validating which of the available images relates to which current image. This is way harder than it should be as
        completely different images i.e. Kubernetes and Remote Desktop Services can have the same Offer, Publisher and Sku. Also some images are
        present twice in the marketplace with slightly different minor versions.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Switch]
        $ListDetails
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find activation resource group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Get a list of downloaded images
        $CurrentImages = Get-AzsMarketplaceImages

        # Get a list of available images
        $AvailableImages = Get-AzsAzureBridgeProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG | Select-Object -Property DisplayName, @{Name = 'DownloadName'; Expression = { (($_.Name) -replace "default/", "") }}, PublisherIdentifier, Offer, OfferVersion, Sku, ProductKind, ProductProperties

        # Declare empty array for storing info of images to be downloaded
        $ImagesToBeDownloaded = @()

        foreach ($Image in $CurrentImages) {
            # If image is a virtual machine...
            if ($Image.ProductKind -like "*virtualMachine*") {
                # Find new image which matches publisher, offer and sku
                $NewestVersion = $AvailableImages | Where-Object -FilterScript { ($_.PublisherIdentifier -like $Image.PublisherIdentifier) -and ($_.Offer -like $Image.Offer) -and ($_.Sku -like $Image.Sku) }
                # If multiple match, refine by Display Name
                if ($NewestVersion.Count) {
                    $NewestVersion = $NewestVersion | Where-Object -FilterScript { $_.DisplayName -like $Image.DisplayName }
                    # If multiple still match, find the one with the newest version number
                    if ($NewestVersion.Count) {
                        $NewestVersionNumber = ($NewestVersion.ProductProperties.Version | Measure-Object -Maximum).Maximum
                        $NewestVersion = $NewestVersion | Where-Object -FilterScript { $_.ProductProperties.Version -eq $NewestVersionNumber }
                    }
                }
            }
            # If image is a virtual machine extension...
            elseif ($Image.ProductKind -like "*virtualMachineExtension*") {
                # Find new image which matches publisher and display name
                $NewestVersion = $AvailableImages | Where-Object -FilterScript { ($_.PublisherIdentifier -like $Image.PublisherIdentifier) -and ($_.DisplayName -like $Image.DisplayName) }
            }

            # If the image is a newer version than the currently installed image, add it to the array
            if (($Image.OfferVersion -notlike $NewestVersion.OfferVersion) -or ($Image.ProductProperties.Version -notlike $NewestVersion.ProductProperties.Version)) {
                $ImagesToBeDownloaded += $NewestVersion
            }
        }

        if ($ImagesToBeDownloaded) {
            if ($ListDetails) {
                return $ImagesToBeDownloaded
            }
            else {
                # Download new images
                foreach ($Download in $ImagesToBeDownloaded) {
                    if ($PSCmdlet.ShouldProcess($ImagesToBeDownloaded.Name, "Download the specified product")) {
                        Write-Verbose -Message "$($ImagesToBeDownloaded)"
                        Invoke-AzsAzureBridgeProductDownload -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -Name $Download.DownloadName -AsJob -Force
                    }
                }
                # Check download status
                Get-AzsMarketplaceUpdateStatus
                # Remove old images after new ones are downloaded
                Remove-AzsMarketplaceDuplicateImages -Force
                # Check removal status
                Get-AzsMarketplaceUpdateStatus
            }
        }
        else {
            Write-Output -InputObject "No new images to be downloaded"
            return $null
        }
    }
}

function Remove-AzsMarketplaceDuplicateImages {
    <#
    .SYNOPSIS
        Remove all duplicate marketplace images.

    .DESCRIPTION
        Remove all duplicate marketplace images. Will help us to keep only the latest images.

    .PARAMETER ListDetails
        Only list the available updates instead of deleting them.

    .EXAMPLE
        Remove-AzsMarketplaceDuplicateImages

    .EXAMPLE
        Remove-AzsMarketplaceDuplicateImages -ListDetails

    .EXAMPLE
        Remove-AzsMarketplaceDuplicateImages -ListDetails -Verbose

    .EXAMPLE
        Remove-AzsMarketplaceDuplicateImages -ListDetails -Confirm:$false -Verbose

    .EXAMPLE
        Remove-AzsMarketplaceDuplicateImages -ListDetails -Confirm:$false -Force -Verbose

    .NOTES
        It will have to be run after the Update-AzsMarketplaceImages function.
        We need to do it so that we only keep the latest images in our marketplace.
        We cannot delete the images at the same time as we update them because it can take a very long time to download an image and our customers would be affected.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [Switch]
        $ListDetails,
        [Parameter(Mandatory = $false)]
        [Switch]
        $Force
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Find activation resource group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Get a list of downloaded images
        $ListOfImages = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG

        # Declare empty array for storing info of images to be deleted
        $ImagesToBeDeleted = @()
        $ListOfImages = $ListOfImages | Group-Object -Property DisplayName -AsString -AsHashTable
        foreach ($Table in $ListOfImages.Values) {
            if ($Table.Count) {
                $NewestVersionNumber = ($Table.ProductProperties.Version | Measure-Object -Maximum).Maximum
                $NewestVersion = $Table | Where-Object -FilterScript { $_.ProductProperties.Version -ne $NewestVersionNumber }
                $ImagesToBeDeleted += $NewestVersion
            }
        }
        if ($ListDetails) {
            # Declare Empty Array to capture Names of Images to List
            $ArrayOfDuplicateImages = @()

            # Iterate through Array of Names to find the Image Details
            foreach ($Image in $ImagesToBeDeleted) {
                # Create Custom Object to populate $ArrayOfDownloadItemsArray so we can pass it to Download function
                $OurObject = [PSCustomObject]@{
                    DownloadName             = $Image | Select-Object -Property @{Name = 'DownloadName'; Expression = { (($_.Name) -replace "default/", "") }} | Select-Object -ExpandProperty DownloadName
                    GalleryItemIdentity      = $Image | Select-Object -ExpandProperty GalleryItemIdentity
                    DisplayName              = $Image | Select-Object -ExpandProperty DisplayName
                    PublisherDisplayName     = $Image | Select-Object -ExpandProperty PublisherDisplayName
                    PublisherIdentifier      = $Image | Select-Object -ExpandProperty PublisherIdentifier
                    SizeInMB                 = $Image | Select-Object -Property @{Name = "SizeInMB"; Expression = { ([Math]::Round(($_.PayloadLength / 1MB), 2)) }} | Select-Object -ExpandProperty SizeInMB
                    SizeInGB                 = $Image | Select-Object -Property @{Name = "SizeInGB"; Expression = { ([Math]::Round(($_.PayloadLength / 1GB), 2)) }} | Select-Object -ExpandProperty SizeInGB
                    ProductPropertiesVersion = $Image | Select-Object -Property @{Name = "ProductVersionNumber"; Expression = { $_.ProductProperties.Version }} | Select-Object -ExpandProperty ProductPropertiesVersion
                    Offer                    = $Image | Select-Object -ExpandProperty Offer
                    OfferVersion             = $Image | Select-Object -ExpandProperty OfferVersion
                    Sku                      = $Image | Select-Object -ExpandProperty Sku
                    ProvisioningState        = $Image | Select-Object -ExpandProperty ProvisioningState
                }
                $ArrayOfDuplicateImages += $OurObject
            }
            if (-not $ArrayOfDuplicateImages) {
                Write-Warning -Message "No duplicate images found"
            }
            return $ArrayOfDuplicateImages
        }
        else {
            if (-not $ImagesToBeDeleted) {
                Write-Warning -Message "No duplicate images found - nothing will be deleted"
            }
            else {
                # Delete all duplicate images
                if ($PSCmdlet.ShouldProcess($ImagesToBeDeleted.Name, "Delete the downloaded product")) {
                    if ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to delete $($ImagesToBeDeleted.Name)?", $null)) {
                        Write-Coloured -InputObject "Deleting duplicate images..." -ForegroundColour Green
                        Write-Verbose -Message "$($ImagesToBeDeleted)"
                        $ImagesToBeDeleted | Remove-AzsAzureBridgeDownloadedProduct -AsJob -Confirm:$false -Force
                    }
                }
            }
        }
    }
}

function Get-AzsMarketplaceUpdateStatus {
    <#
    .SYNOPSIS
        Get current status of marketplace update.

    .DESCRIPTION
        Get current status of marketplace update - downloads/deletions of images.

    .PARAMETER SmtpServer
        SmtpServer to relay emails through - defaults to our O365 relay.

    .PARAMETER Recipient
        Email address of the first recipient - defaults to MSFT Teams Update channel.

    .PARAMETER Recipient2
        Email address of the second recipient - defaults to cblack@ukcloud.com.

    .PARAMETER ProgressInterval
        How often check progress. Defaults to 30.
        Note: 30 = 120s x 30 ~ 60 min - every hour, set it to 15 for 30 min.

    .PARAMETER RetryDelay
        How often the Stack will be queried - default value is 120s.

    .PARAMETER SendEmail
        Declare whether to send an email or not - default value is $true.

    .EXAMPLE
        Get-AzsMarketplaceUpdateStatus

    .EXAMPLE
        Get-AzsMarketplaceUpdateStatus -SmtpServer "ukcloud-com.mail.protection.outlook.com" -Recipient "551f9304.ukcloud.com@emea.teams.ms" -Recipient2 "user@ukcloud.com"

    .EXAMPLE
        Get-AzsMarketplaceUpdateStatus -SmtpServer "ukcloud-com.mail.protection.outlook.com" -Recipient "551f9304.ukcloud.com@emea.teams.ms" -Recipient2 "user@ukcloud.com" -ProgressInterval "15"

    .EXAMPLE
        Get-AzsMarketplaceUpdateStatus -SmtpServer "ukcloud-com.mail.protection.outlook.com" -Recipient "551f9304.ukcloud.com@emea.teams.ms" -Recipient2 "user@ukcloud.com" -ProgressInterval "15" -SendEmail:$false

    .NOTES
        It will have to be run after the Update-AzsMarketplaceImages function.
        We need to do it so that we only keep the latest images in our marketplace.
        We cannot delete the images at the same time as we update them because it can take a very long time to download an image and our customers would be affected.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        $SmtpServer = "ukcloud-com.mail.protection.outlook.com",
        [Parameter(Mandatory = $false)]
        $Recipient = "551f9304.ukcloud.com@emea.teams.ms",
        [Parameter(Mandatory = $false)]
        $Recipient2 = "cblack@ukcloud.com",
        [Parameter(Mandatory = $false)]
        [Int]
        $ProgressInterval = 30,
        [Parameter(Mandatory = $false)]
        [Int]
        $RetryDelay = 120,
        [Parameter(Mandatory = $false)]
        [Switch]
        $SendEmail = $true
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as admin
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -notlike "*https://adminmanagement*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackAdmin context correctly.'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        # Email variables
        $From = "AzureStackMarketplaceStatus@ukcloud.com"

        # Get Azure Stack region information
        $AzsUpdateLocation = Get-AzsUpdateLocation

        # Find activation resource group
        $ActivationRG = Get-AzureRmResourceGroup | Where-Object -FilterScript { $_.ResourceGroupName -like "*activation*" } | Select-Object -ExpandProperty ResourceGroupName
        #$ActivationRG = "azurestack-activation"

        # Find Activation Details
        $ActivationDetails = Get-AzsAzureBridgeActivation -ResourceGroupName $ActivationRG

        # Get a list of currently downloading images
        $ListOfImages = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG | Where-Object -FilterScript { $_.ProvisioningState -notlike "Succeeded" -and $_.ProvisioningState -notlike "Failed" }
        $ProgressCount = 0
        $ListOfDownloads = $ListOfImages.Name
        while ($ListOfImages.ProvisioningState -contains "Downloading" -or $ListOfImages.ProvisioningState -contains "Deleting") {
            $ListOfImages = Get-AzsAzureBridgeDownloadedProduct -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG | Where-Object -FilterScript { $ListOfDownloads -contains $_.Name } | Select-Object -Property DisplayName, GalleryItemIdentity, @{Name = "ProductVersionNumber"; Expression = { $_.ProductProperties.Version }} , ProductKind, @{Name = "SizeInGB"; Expression = { ([Math]::Round(($_.PayloadLength / 1GB), 2)) } }, ProvisioningState  | Sort-Object -Property ProductKind, DisplayName
            $ListOfImages | Format-Table -AutoSize
            if ((($ProgressCount -eq 0) -or ($ListOfImages.ProvisioningState -notcontains "Downloading" -and $ListOfImages.ProvisioningState -notcontains "Deleting" -and $ListOfImages.ProvisioningState -notcontains "DeletePending" -and $ListOfImages.ProvisioningState -notcontains "DownloadPending")) -and ($SendEmail)) {
                if ($ListOfImages.ProvisioningState -contains "Downloading") {
                    $CurrentState = "Downloading"
                }
                elseif ($ListOfImages.ProvisioningState -contains "Deleting") {
                    $CurrentState = "Deleting"
                }
                elseif ($ListOfImages.ProvisioningState -contains "DeletePending" -or $ListOfImages.ProvisioningState -contains "DownloadPending") {
                    $CurrentState = "Pending"
                }
                elseif ($ListOfImages.ProvisioningState -contains "Failed") {
                    $CurrentState = "Failed"
                }
                else {
                    $CurrentState = "Succeeded"
                }
                # Send an email depending on update status and $ProgressInterval
                $GetDate = Get-Date -Format "dd-MM-yyyy"
                $GetDateFull = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
                $Subject = "UKCloud for Microsoft Azure - Updating $($ListOfDownloads.Count) marketplace items in Azure Stack Region $($AzsUpdateLocation.Location) - current version $($AzsUpdateLocation.CurrentVersion) - $GetDate - $CurrentState"
                $HtmlBodyStream = $ListOfImages | ConvertTo-Html -Fragment | Out-String -Stream
                $HtmlBodyArray = @()
                $SucceededCount = 0
                $DownloadingCount = 0
                $DeletingCount = 0
                $PendingCount = 0
                $FailedCount = 0
                foreach ($TableRow in $HtmlBodyStream) {
                    switch -Wildcard ($TableRow) {
                        "*<td>Downloading</td>*" {
                            $TableRow = $TableRow -replace "<tr>", "<tr style='background-color:#ffffbf'>"
                            $TableRow = $TableRow -replace "<td>Downloading</td>", "<td><b>Downloading</b></td>"
                            $DownloadingCount++
                        }
                        "*<td>Deleting</td>*" {
                            $TableRow = $TableRow -replace "<tr>", "<tr style='background-color:#ffffbf'>"
                            $TableRow = $TableRow -replace "<td>Deleting</td>", "<td><b>Deleting</b></td>"
                            $DeletingCount++
                        }
                        "*<td>Succeeded</td>*" {
                            $TableRow = $TableRow -replace "<tr>", "<tr style='background-color:#c1ffc3'>"
                            $SucceededCount++
                        }
                        "*<td>DeletePending</td>*" {
                            $TableRow = $TableRow -replace "<tr>", "<tr style='background-color:#c6d6ff'>"
                            $PendingCount++
                        }
                        "*<td>DownloadPending</td>*" {
                            $TableRow = $TableRow -replace "<tr>", "<tr style='background-color:#c6d6ff'>"
                            $PendingCount++
                        }
                        "*<td>Failed</td>*" {
                            $TableRow = $TableRow -replace "<tr>", "<tr style='background-color:red'>"
                            $FailedCount++
                        }
                    }
                    $HtmlBodyArray += $TableRow
                }
                $HtmlBodyString = $HtmlBodyArray | Out-String
                $Body = @"
<style>
body
{
font-family: 'Open Sans';
line-height:20px;
color:#000000;
}
table
{
font-family:'Open Sans';
width:100%;
border-collapse:collapse;
}
table td, th
{
font-size:16px;
font-weight:normal;
border:1px solid #000000;
padding:5px;
line-height:20px;
}
table th
{
#text-transform:uppercase;
font-weight:bold;
text-align:left;
padding-top:5px;
padding-bottom:4px;
background-color:#2589CD;
color:#fff;
}
</style>
<b>UKCloud for Microsoft Azure - Updating $($ListOfDownloads.Count) marketplace items in Azure Stack Region $($AzsUpdateLocation.Location) - current version $($AzsUpdateLocation.CurrentVersion) - $GetDateFull</b>
<br>
<b>Current status: Succeeded: $SucceededCount Downloading: $DownloadingCount Deleting: $DeletingCount Pending: $PendingCount Failed: $FailedCount</b>
<br>

$HtmlBodyString

<center><b>Current state: $($CurrentState)</b></center>
"@
                Send-MailMessage -To $Recipient -From $From -Subject $Subject -SmtpServer $SmtpServer -Body $Body -BodyAsHtml -UseSsl
                Send-MailMessage -To $Recipient2 -From $From -Subject $Subject -SmtpServer $SmtpServer -Body $Body -BodyAsHtml -UseSsl
            }
            $ProgressCount++
            if ($ProgressCount -eq $ProgressInterval) {
                $ProgressCount = 0
            }
            if ($ListOfImages.ProvisioningState -contains "Downloading") {
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }
}

<# Examples of usage
Get-AzsAvailableMarketplaceImages -ListDetails

Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM." -WhatIf
Import-AzsMarketplaceImages -ImagesToDownload "RogueWave.CentOSbased69-ARM.","SQLServer2016SP1StandardWindowsServer2016.February" -WhatIf

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
### New List as of 21-08-2018
$ImagesToDownloadNew = @(
    "microsoft.freesqlserverlicensesqlserver2017developeronsles12sp2-arm-14.0.1000320", `
    "microsoft.freelicensesqlserver2016sp2expresswindowsserver2016-arm-13.1.900310", `
    "microsoft.freesqlserverlicensesqlserver2017expressonsles12sp2-arm-14.0.1000320", `
    "microsoft.freelicensesqlserver2016sp2developerwindowsserver2016-arm-13.1.900310", `
    "microsoft.freelicensesqlserver2016sp1developerwindowsserver2016-arm-13.1.900310", `
    "microsoft.freesqlserverlicensesqlserver2017developeronwindowsserver2016-arm-14.0.1000204", `
    "microsoft.freesqlserverlicensesqlserver2017expressonwindowsserver2016-arm-14.0.1000320", `
    "microsoft.sqlserver2017enterpriseonsles12sp2-arm-14.0.1000320", `
    "microsoft.sqlserver2016sp2enterprisewindowsserver2016-arm-13.1.900310", `
    "microsoft.sqlserver2017standardonsles12sp2-arm-14.0.1000320", `
    "microsoft.sqlserver2017enterprisewindowsserver2016-arm-14.0.1000320", `
    "microsoft.sqlserver2016sp2standardwindowsserver2016-arm-13.1.900310", `
    "microsoft.sqlserver2017standardonwindowsserver2016-arm-14.0.1000320", `
    "microsoft.sqlserver2016sp1enterprisewindowsserver2016-arm-13.1.900310", `
    "microsoft.sqlserver2016sp1standardwindowsserver2016-arm-13.1.900310", `
    "canonical.ubuntuserver1404lts-arm", `
    "canonical.ubuntuserver1604lts-arm", `
    "canonical.ubuntuserver1804lts-arm", `
    "microsoft.dsc-arm-2.76.0.0", `
    "microsoft.sqliaasextension", `
    "microsoft.windowsserver2012datacenter-arm-paygo", `
    "microsoft.windowsserver2016datacenter-arm-payg", `
    "microsoft.datacenter-core-1709-with-containers-smalldisk-payg", `
    "microsoft.windowsserver2016datacenterwithcontainers-arm-payg" , `
    "microsoft.windowsserver2016datacenterservercore-arm-payg", `
    "roguewave.centosbased69-arm", `
    "roguewave.centosbased73-arm", `
    "roguewave.centosbased610-arm", `
    "roguewave.centosbased75-arm"
)

Import-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload -WhatIf
Import-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload -ListDetails -WhatIf


#Get-AzsMarketplaceImages |  Remove-AzsMarketplaceImages -WhatIf -Verbose
#$ImagesToDelete = "SQLServer2016SP1StandardWindowsServer2016.February"
#Remove-AzsAzureBridgeDownloadedProduct -Name $ImagesToDelete -ActivationName $ActivationDetails.Name -ResourceGroupName $ActivationRG -WhatIf

#Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January","SQLServer2016SP1StandardWindowsServer2016.February" -WhatIf -Verbose
#Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January" -WhatIf -Confirm:$true
#Remove-AzsMarketplaceImages -ImagesToDelete "RogueWave.CentOSbased69-ARM.January","SQLServer2016SP1StandardWindowsServer2016.February" -Confirm:$true -Force -WhatIf

#Remove-AzsMarketplaceImages -WhatIf
Get-AzsMarketplaceImages |  Remove-AzsMarketplaceImages -WhatIf -Verbose

Get-AzsMarketplaceImages -ListDetails

$Image = $CurrentImages | Where-Object -FilterScript { $_.DownloadName -like "*microsoft.datacenter-core-1709-with-containers-smalldisk-payg-1709.30.20180717*" }
$CurrentImages = $CurrentImages | Where-Object -FilterScript { $_.Offer -like "*SolutionTemplateOffer*" }
$AvailableImages | Where-Object -FilterScript { $_.Offer -like "*SolutionTemplateOffer*" } | Select PublisherIdentifier, DisplayName, GalleryItemIdentity
#>