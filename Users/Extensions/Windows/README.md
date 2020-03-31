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

`powershell -ExecutionPolicy Unrestricted -File ASRCSConfig.ps1 -ClientID <Client ID> -ClientSecret <Client Secret> -TenantID <Tenant ID> -ArmEndpoint <AzureStack Endpoint> -MySQLRootPassword <SQL Root Password> -MySQLUserPassword <SQL User Password> -AzureStorageAccount <Azure Storage Account> -AzureResourceGroup <Azure Resource Group> -VaultName <ASR Vault Name> -ConfigServerUsername <Windows VM Username> -ConfigServerPassword <Windows VM Password> -EncryptionKey <Encryption Key> -WindowsUsername <Replicated Windows VM Username> -WindowsPassword <Replicated Windows VM Password> -LinuxRootPassword <Replicated Linux VM Root Password> -StackResourceGroup <AzureStack Resource Group>`

| Field | Description | Example |
|-------|-------------|---------|
| ClientID | The application ID of a service principal with contributor permissions on Azure Stack and Azure | 00000000-0000-0000-0000-000000000000 |
| ClientSecret | A password of the service principal specified in the ClientID parameter | ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jkx]= |
| TenantID | The Tenant/Directory ID of your AAD domain | 31537af4-6d77-4bb9-a681-d2394888ea26 |
| ArmEndpoint | The Azure Resource Manager endpoint for Azure Stack | https://management.frn00006.azure.ukcloud.com |
| MySQLRootPassword | The root password for the MySQL server created on the Configuration Server (Must meet password requirements specified [below](#MySQL-Password-Requirements)) | |
| MySQLUserPassword | The user password for the MySQL server created on the Configuration Server (Must meet password requirements specified [below](#MySQL-Password-Requirements)) | |
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

#### MySQL Password Requirements

Password must conform to all of the following rules:

- Password must contain at least one letter
- Password must contain at least one number
- Password must contain at least one special character (_!@#$%)
- Password must be between 8 and 16 characters
- Password cannot contain spaces

## AzureBackupConfig.ps1

### Overview

This extension configures the Microsoft Azure Recovery Services agent on a windows VM. This allows the VM to backup to a Recovery Services vault on public Azure. The extension is installed following the process [here](https://docs.microsoft.com/en-us/azure/backup/backup-configure-vault).

### Arguments

`powershell -ExecutionPolicy Unrestricted -File ASRCSConfig.ps1 -ClientID <Client ID> -ClientSecret <Client Secret> -TenantID <Tenant ID> -AzureResourceGroup <Azure Resource Group> -VaultName <ASR Vault Name> -AzureLocation <Azure Location> -ExistingRG -ExistingVault -TempFilesPath <Temp Files Path> -EncryptionKey <Encryption Key> -BackupDays <Days to schedule backups on> -BackupTimes <Times to schedule backups at> -RetentionLength <Number of days to keep backups for> -FoldersToBackup <Folders to backup> -BackupNow`

| Field | Description | Example |
|-------|-------------|---------|
| ClientId | The application ID of a service principal with contributor permissions on Azure. | 00000000-0000-0000-0000-000000000000 |
| ClientSecret | The Tenant/Directory ID of your AAD domain. | ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]= |
| TenantId | The Tenant/Directory ID of your AAD domain. | 31537af4-6d77-4bb9-a681-d2394888ea26 |
| AzureResourceGroup | The name of the resource group to be created on public Azure. | AzureStackBackupRG |
| VaultName | The name of the recovery services vault to be created on public Azure. | AzureStackVault |
| AzureLocation | The location of the recovery services vault on public Azure. | UK West |
| ExistingRG | Switch used to specify that the resource group already exists in public Azure. | |
| ExistingVault | Switch used to specify that the vault already exists in public Azure. | |
| TempFilesPath | Location on the server where setup files will be stored. | C:\temp |
| EncryptionKey | The encryption key for the MySQL database on the configuration server. | ExampleEncryptionKey |
| BackupDays | A comma separated list of the days to backup on. | 'Monday,Friday' |
| BackupTimes | A comma separated list of the times to backup at on the backup days. | '16:00, 20:00' |
| RetentionLength | The number of days to keep each backup for. | 7 |
| FoldersToBackup | A comma separated list of folders to backup. By default backs up all drives excluding temporary storage. | 'C:\Users, C:\Users\TestUser\Documents' |
| BackupNow | Switch used to specify that the server should backup once the MARS agent is installed. | |
| NoSchedule | Switch used to specify that the schedule configuration step can be skipped. | |

## SysprepVM.ps1

### Overview

This extension deprovisions a Windows VM using the sysprep tool. Once it has been run the VM can be used to create a custom image.

### Arguments

`powershell -ExecutionPolicy Unrestricted -File SysprepVM.ps1`
