---
title: Azure Stack Marketplace Management | UKCloud Ltd
description: Azure Stack Marketplace Management Module Guide
services: azure-stack
author: Chris Black

toc_rootlink: Operators
toc_sub1: How To
toc_sub2:
toc_sub3:
toc_sub4:
toc_title: Marketplace Management
toc_fullpath: Operators/Update Azure Stack/azs-how-ps-marketplace-management.md
toc_mdlink: azs-how-ps-marketplace-management.md
---
# Azure Stack Update Procedure

This guide is intended to provide a reference on how can we manage Marketplace Images using *PowerShell* **Marketplace Management Module**.

Includes functions:

    - Get-AzsMarketplaceImages
    - Download-AzsMarketplaceImage
    - Remove-AzsMarketplaceImages
    - Remove-AzsMarketplaceImagesAll

> [!NOTE]
> Module is using cmdlets from azs.azurebridge.admin -> [more info](https://docs.microsoft.com/en-us/powershell/module/azs.azurebridge.admin/?view=azurestackps-1.3.0)

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.3 -> [Azure Stack Modules Install Guide](https://github.com/UKCloud/AzureStack/blob/master/docs/Tenants/PowerShell/ConfigurePowerShellEnvironment.md)

> [!IMPORTANT]
> You might need to force the latest module by running
> ```powershell
> Install-Module -Name AzureStack -RequiredVersion 1.3 -AllowClobber -Force -Verbose
> ```

## How to install it

There is a installmodules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

You need to log in to Azure Stack first before you can execute the commands as they will fail otherwise.

> [!NOTE]
> Module assumes default Resource Group and Activation names as they appear to be fixed in Azure Stack currently, they are being matched *activation* wildcard name.

### Examples

* List currently downloaded images:

    ```powershell
    Get-AzsMarketplaceImages
    ```

* List currently downloaded images with detailed info:

    ```powershell
    Get-AzsMarketplaceImages -ListDetails
    ```

    > [!CAUTION]
    > You cannot use it if you want to pipe the output to Remove-AzsMarketplaceImages

* Remove all images that are currently downloaded:

    ```powershell
    Remove-AzsMarketplaceImages
    ```

* Download Marketplace Images:

    ```powershell
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
    ```

> [!TIP]
> There are more examples of usage inside the functions in the module itself.

#### Re-Download all images

If you want to delete all the images and download the ones you want run this:

```powershell
# Find all images that are currently installed
Get-AzsMarketplaceImages
# Delete all images without prompting for confirmation
Get-AzsMarketplaceImages | Remove-AzsMarketplaceImages -Verbose -Confirm:$false -Force
# Download new images based on the declared array
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

# Download items based on the array above
Download-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload -Confirm:$false -Force -Verbose
```

## ToDo

* Publish to PowerShell Gallery
* Expand examples