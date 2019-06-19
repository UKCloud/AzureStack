# Azure Stack Kubernetes Module

This guide is intended to provide a reference on how to use the **Azure Stack Kubernetes** module for PowerShell.

Includes functions:

    - Start-AzsAks
    - Get-AzsAksCredentials
    - New-AzsAks
    - Remove-AzsAks
    - Get-AzsAks
    - Start-AzsAksScale
    - Show-AzsAks
    - Get-AzsAksVersions
    - Start-AzsAksUpgrade
    - Get-AzsAksUpgradeVersions

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.7.1 -> [Azure Stack Modules Install Guide](https://docs.ukcloud.com/articles/azure/azs-how-configure-powershell-users.html)

## How to install it

There is a InstallModules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

> [!IMPORTANT]
> **You need to log in to Azure Stack first before you can execute most of the commands as they may fail otherwise.**.

### Examples

* Create a new Kubernetes cluster:

    ```PowerShell
    New-AzsAks -ResourceGroupName "AKS-RG" -SSHKeyPath "C:\AzureStack\KuberenetesKey.pub" `
        -ServicePrincipal "00000000-0000-0000-0000-000000000000" -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -StorageProfile "blobdisk"
    ```

* List all Kubernetes clusters in the current subscription:

    ```PowerShell
    Get-AzsAks
    ```

* Scale the node pool of a Kubernetes cluster horizontally:

    ```PowerShell
    Start-AzsAksScale -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" `
        -ServicePrincipal "00000000-0000-0000-0000-000000000000" -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -NewNodeCount 5
    ```

* Upgrade a Kubernetes cluster to a newer version:

    ```PowerShell
    Start-AzsAksUpgrade -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -ServicePrincipal "00000000-0000-0000-0000-000000000000" `
        -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -KubernetesUpgradeVersion "1.11.2"
    ```

* Deletes a Kubernetes cluster:

    ```PowerShell
    Remove-AzsAks -ResourceGroupName "AKS-RG"
    ```

> [!TIP]
> More usage examples can be found by running `Get-Help <FunctionName> -Full`
