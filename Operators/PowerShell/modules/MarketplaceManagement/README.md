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
toc_fullpath: Operators/How To/azs-how-ps-marketplace-management.md
toc_mdlink: azs-how-ps-marketplace-management.md
---
# Azure Stack Marketplace Management Module

This guide is intended to provide a reference on how can we manage Marketplace Images using *PowerShell* **Marketplace Management Module**.

Includes functions:

    - Get-AzsMarketplaceImages
    - Get-AzsAvailableMarketplaceImages
    - Download-AzsMarketplaceImage
    - Remove-AzsMarketplaceImages
    - Remove-AzsMarketplaceImagesAll

> [!NOTE]
> Module is using cmdlets from azs.azurebridge.admin -> [more info](https://docs.microsoft.com/en-us/powershell/module/azs.azurebridge.admin/?view=azurestackps-1.3.0)

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.3 -> [Azure Stack Modules Install Guide](https://github.com/UKCloud/AzureStack/blob/master/operators/powershell/azs-how-ps-configure-powershell-operator.md)

> [!IMPORTANT]
> You might need to force the latest module by running
> ```powershell
> Install-Module -Name AzureStack -RequiredVersion 1.3 -AllowClobber -Force -Verbose
> ```

## How to install it

There is a installmodules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

> [!IMPORTANT]
> **You need to log in to Azure Stack first before you can execute the commands as they will fail otherwise.**.

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

* List all available images in the Azure Marketplace

    ```powershell
    Get-AzsAvailableMarketplaceImages -ListDetails
    ```

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
### New List as of 27-09-2018
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
    "roguewave.centosbased75-arm", `
    "microsoft.sqlserver2014sp2webwindowsserver2012r2-arm-12.20.0", `
    "microsoft.sqlserver2016sp2webwindowsserver2016-arm-13.1.900310", `
    "microsoft.sqlserver2017webonubuntuserver1604lts-arm-14.0.1000320", `
    "microsoft.sqlserver2017webonsles12sp2-arm-14.0.1000320", `
    "microsoft.sqlserver2017webonwindowsserver2016-arm-14.0.1000320", `
    "microsoft.sqlserver2016sp1webwindowsserver2016-arm-13.1.900310", `
    "microsoft.azurestackkubernetescluster-0.3.0", `
    "microsoft.servicefabriccluster-1.0.0",
    "microsoft.customscriptextension-arm-1.9.1", `
    "microsoft.custom-script-linux-arm-1.5.2.2", `
    "microsoft.custom-script2-linux-arm-2.0.6"
)

# Download items based on the array above
Download-AzsMarketplaceImages -ImagesToDownload $ImagesToDownload -Confirm:$false -Force -Verbose
```

## ToDo

* Publish to PowerShell Gallery
* Expand examples
