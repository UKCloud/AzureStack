# Azure Site Recovery Functionality Module

This guide is intended to provide a reference on how to use the **Azure Site Recovery Functionality** module for PowerShell.

Includes functions:

    - Test-AzureSiteRecoveryFailOver
    - Start-AzureSiteRecoveryFailOver
    - Start-AzureSiteRecoveryFailBack

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.6.0 -> [Azure Stack Modules Install Guide](https://docs.ukcloud.com/articles/azure/azs-how-configure-powershell-users.html)

## How to install it:

There is a installmodules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

> [!IMPORTANT]
> **You need to log in to public Azure first before you can execute the commands as they will fail otherwise.**.

### Examples

* Perform a test failover of your protected VMs to Azure:

    ```powershell
    Test-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault"
    ```

* Perform a failover of your protected VMs to Azure:

    ```powershell
    Start-AzureSiteRecoveryFailOver -VaultName "AzureStackRecoveryVault"
    ```

* Perform a fail back of all VMs in an Azure resource group to Azure Stack:

    ```powershell
    Start-AzureSiteRecoveryFailOver -AzureResourceGroup "SiteRecovery-RG" -Username "exampleuser@contoso.onmicrosoft.com" `
        -StackResourceGroup "FailBack-RG" -StackStorageAccount "FailBackSA" -StackStorageContainer "FailBackContainer"
    ```

> [!TIP]
> There are more examples of usage inside the functions in the module itself.