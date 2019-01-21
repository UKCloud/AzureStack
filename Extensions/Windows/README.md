# Windows Custom Script Extensions

This document outlines the function of each of these extensions as well as how to use them.

## How to use custom script extensions with Windows via the portal

1. Log into the Azure / Azure Stack portal.
2. Navigate to the VM that you wish to use the extension with.
3. Select the **Extensions** blade under the *settings* section.
4. Click **+Add**.
5. Select **Custom Script Extension**, then click **Create**.
6. Upload the extension file.
7. Specify arguments as required (See extension information below for help).
8. Click **OK**

## How to use custom script extensions with Windows via PowerShell

```PowerShell
Set-AzureRmVMCustomScriptExtension -FileUri "https://raw.githubusercontent.com/UKCloud/AzureStack/<Extension Location>"  `
-ResourceGroupName "<Resource Group Name>" -Location "<Location>" -VMName "<VM Name>" -Name "<Extension Name>" -Run "<Extension Arguments>"
```

## VMSetupForSR.ps1

### Overview

This extension configures a VM to the specifications outlined [here](https://docs.microsoft.com/en-us/azure/site-recovery/azure-stack-site-recovery#step-1-prepare-azure-stack-vms) for replication with Azure Site Recovery. It performs the following changes:

- Disables Remote User Access control
- Allows File and Printer Sharing inbound firewall rules
- Allows Windows Management Instrumentation inbound firewall rules

### Arguments

`powershell -ExecutionPolicy Unrestricted -File VMSetupForSR.ps1`

## ASRCSConfig.ps1

### Overview

This extension configures a windows server VM to function as a configuration server for Azure Site Recovery. This extension follows the process outlined [here](https://docs.microsoft.com/en-us/azure/site-recovery/azure-stack-site-recovery).

### Arguments

`powershell -ExecutionPolicy Unrestricted -File ASRCSConfig.ps1 -Username <AAD Username> -Password <AAD Password> -ArmEndpoint <AzureStack Endpoint> -MySQLRootPassword <SQL Root Password> -MySQLUserPassword <SQL User Password> -AzureStorageAccount <Azure Storage Account> -AzureResourceGroup <Azure Resource Group> -VaultName <ASR Vault Name> -ConfigServerUsername <Windows VM Username> -ConfigServerPassword <Windows VM Password> -EncryptionKey <Encryption Key> -WindowsUsername <Replicated Windows VM Username> -WindowsPassword <Replicated Windows VM Password> -LinuxRootPassword <Replicated Linux VM Root Password> -StackResourceGroup <AzureStack Resource Group>`

| Field | Description | Example |
|-------|-------------|---------|
| Username | Your Azure Active Directory Username (the email address you use to login to public Azure and Azure Stack) | example\@example.onmicrosoft.com |
| Password | Your Azure Active Directory Password | |
| ArmEndpoint | The Azure Resource Manager endpoint for Azure Stack | https://management.frn00006.azure.ukcloud.com |
| MySQLRootPassword | The root password for the MySQL server created on the Configuration Server | |
| MySQLUserPassword | The user password for the MySQL server created on the Configuration Server | |
| AzureStorageAccount | The name of the storage account to be created on public Azure (Must be unique across public Azure)  | stacksiterecoverysa |
| AzureResourceGroup | The name of the resource group to be created on public Azure  | SiteRecoveryTestRG |
| VaultName | The name of the recovery services vault to be created on public Azure  | AzureStackVault |
| ConfigServerUsername | The username for the configuration server  | ConfigAdmin |
| ConfigServerPassword | The password for the configuration server | |
| EncryptionKey | The encryption key for the MySQL database on the configuration server  | ExampleEncryptionKey |
| WindowsUsername | The username of an administrator account on the Windows VMs to be protected  | Administrator |
| WindowsPassword | The password of an administrator account on the Windows VMs to be protected | |
| LinuxRootPassword | The password of the root account on the Linux VMs to be protected | |
| StackResourceGroup | The name of the resource group which the VM is in on Azure Stack  | SiteRecovery-RG |