---
title: Azure Stack Ip Pools | UKCloud Ltd
description: Azure Stack Ip Pools Module Guide
services: azure-stack
author: Chris Black

toc_rootlink: Operators
toc_sub1: How To
toc_sub2:
toc_sub3:
toc_sub4:
toc_title: Ip Pools
toc_fullpath: Operators/How To/azs-how-ps-ip-pools.md
toc_mdlink: azs-how-ps-ip-pools.md
---
# Azure Stack Ip Pools Module

This guide is intended to provide a reference on how can we manage provision new Public IP Pool to Azure Stack *PowerShell* **IpPools Module**.

Includes functions:

    - Get-NetworkIpPoolInfo
    - New-AzsPublicIpPool

> [!NOTE]
> Module is using cmdlets from azs.fabric.admin -> [more info](https://docs.microsoft.com/en-gb/powershell/module/azs.fabric.admin/?view=azurestackps-1.3.0)

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.3 -> [Azure Stack Modules Install Guide](https://github.com/UKCloud/AzureStack/blob/master/operators/powershell/azs-how-ps-configure-powershell-operator.md)

> [!IMPORTANT]
> You might need to force the latest module by running
> ```PowerShell
> Install-Module -Name AzureStack -RequiredVersion 1.3 -AllowClobber -Force -Verbose
> ```

## How to install it

There is a InstallModules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

> [!IMPORTANT]
> **You need to log in to Azure Stack first before you can execute the commands as they will fail otherwise.**

> [!NOTE]
> Modules provisions Broadcast IP as the Last IP as this is what currently has been configured in Azure Stack for other Pools - it also appears to be usable so might as well have one extra IP.

### Examples

* Check Network Settings:
    ```PowerShell
    Get-NetworkIpPoolInfo -IPAddress "57.139.61.192" -SubnetMask "255.255.255.192"
    ```

    * Return:
        ```PowerShell
        Network ID:  57.139.61.192/26
        First Address:  57.139.61.193  <-- typically the default gateway
        Last Address:  57.139.61.254
            Broadcast:  57.139.61.255


        NetworkID        FirstAddress  LastAddress   Broadcast
        ---------        ------------  -----------   ---------
        57.139.61.192/26 57.139.61.193 57.139.61.254 57.139.61.255
        ```

* Provision New Public Ip Pool based on IP and Subnet:
    ```PowerShell
    New-AzsPublicIpPool -IPAddress "57.139.61.192" -SubnetMask "255.255.255.192" -IPPoolName "PublicIpPoolExtension-1" -Confirm:$false -Force -Verbose
    ```
    > [!CAUTION]
    > You cannot delete provisioned Ip Pool so be careful!

> [!TIP]
> More usage examples can be found by running `Get-Help <FunctionName> -Full`

## ToDo

* Publish to PowerShell Gallery
* Expand examples