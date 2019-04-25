# Azure Site Recovery Functionality Module

This guide is intended to provide a reference on how to use the **Azure Site Recovery Functionality** module for PowerShell.

Includes functions:

    - Test-AzureSiteRecoveryFailOver
    - Start-AzureSiteRecoveryFailOver
    - Start-AzureSiteRecoveryFailBack

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.7.1 -> [Azure Stack Modules Install Guide](https://docs.ukcloud.com/articles/azure/azs-how-configure-powershell-users.html)

## How to install it

There is a InstallModules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

> [!IMPORTANT]
> **You need to log in to public Azure first before you can execute the commands as they will fail otherwise.**.

### Examples

* Perform a test failover of your protected VMs to Azure:

    ```PowerShell
    Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault"
    ```

* Perform a failover of your protected VMs to Azure:

    ```PowerShell
    Start-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault"
    ```

* Perform a fail back of all VMs in an Azure resource group to Azure Stack:

    ```PowerShell
    Start-AzureSiteRecoveryFailBack -AzureResourceGroup "SiteRecovery-RG" -Username "exampleuser@contoso.onmicrosoft.com" `
        -StackResourceGroup "FailBack-RG" -StackStorageAccount "FailBackSA" -StackStorageContainer "FailBackContainer"
    ```

> [!TIP]
> More usage examples can be found by running `Get-Help <FunctionName> -Full`
