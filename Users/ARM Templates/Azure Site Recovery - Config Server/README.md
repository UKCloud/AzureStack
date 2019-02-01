# Deployment of a Configuration Server for Azure Site Recovery

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FUKCloud%2FAzureStack%2Fmaster%2FARM%20Templates%2FConfigServer-SiteRecovery%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template allows you to deploy a configuration server for Azure Site Recovery. This template requires a virtual network to already be created for the server to be deployed on.

The configuration server that is deployed creates all necessary resources on public Azure for Azure Site Recovery and if this template is deployed into a resource group with VMs, these VMs will be automatically be protected.

## Prerequisites

- Ensure a virtual network is already available within the resource group you wish to deploy the configuration server to, with any VMs that you wish to be protected residing on this network.

- A public Azure subscription on the same domain as an Azure Stack subscription.

- A service principal with contributor permissions on both subscriptions

- For any VMs which you wish to be protected, be sure to add the relevant custom script extension. These are required as specified in the [Azure Stack Site Recovery documentation](https://docs.microsoft.com/en-us/azure/site-recovery/azure-stack-site-recovery#step-1-prepare-azure-stack-vms). The URLs for these custom scripts are as follows:
  - Windows: https://raw.githubusercontent.com/UKCloud/AzureStack/master/Extensions/Windows/VMSetupForSR.ps1
  
    This extension disables Remote User Access control and allows WMI and File and Printer sharing on the firewall.
  
  - Linux: https://raw.githubusercontent.com/UKCloud/AzureStack/master/Extensions/Linux/SetRootPassword.sh

    This extension sets the root password to the input parameter, as root access is required for Azure Site Recovery.

    > ### **Note**
    >
    > For the Linux extension, use the following command syntax: `sh ChangePassword.sh <password>`
    >
    > The Windows extension does not require any parameters to be specified.

## High Level Overview of the Deployment Process

1. The ARM template deploys pre requisite resources (NIC, Public IP, NSG, etc.) for the configuration server.

2. The configuration server is deployed with a custom script extension.

3. The custom script extension performs the following steps:
    1. Installs all prerequisites on the configuration server.
    2. Creates a resource group, recovery services vault, storage account and virtual network on public Azure.
    3. Installs the configuration server service.
    4. Configures the recovery services vault.
    5. Protects any VMs on the same virtual network as the configuration server.

## ARM Template parameters

| Field | Description | Example |
|-------|-------------|---------|
| ClientID | The application ID of a service principal with contributor permissions on Azure Stack and Azure | 00000000-0000-0000-0000-000000000000 |
| ClientSecret | A password of the service principal specified in the ClientID parameter | ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jkx]= |
| TenantID | The Tenant/Directory ID of your AAD domain | 31537af4-6d77-4bb9-a681-d2394888ea26 |
| StackArmEndpoint | The Azure Resource Manager endpoint for Azure Stack | https://management.frn00006.azure.ukcloud.com |
| ConfigurationServerName | The name of the configuration server VM | SRConfigServer |
| TempFilesPath | Location on configuration server where setup files will be stored | C:\TempASR\ |
| ExtractionPath | The name of the folder within the TempFilesPath where the configuration server unified setup will be extracted to | Extracted |
| MySQLRootPassword | The root password for the MySQL server created on the Configuration Server (Must meet password requirements specified in [below](#MySQL-Password-Requirements)) | |
| MySQLUserPassword | The user password for the MySQL server created on the Configuration Server (Must meet password requirements specified [below](#MySQL-Password-Requirements)) | |
| AzureVNetName | The name of the virtual network to be created on public Azure | SiteRecoveryVNet |
| StackVNetName | The name of the existing virtual network to connect the configuration server to on Azure Stack | SiteRecoveryVNet |
| StackSubnetName | The name of the existing virtual network subnet to connect the configuration server to on Azure Stack | default |
| AzureStorageAccount | The name of the storage account to be created on public Azure (Must be unique across public Azure)  | stacksiterecoverysa |
| StackStorageAccount | The name of the storage account to be created on Azure Stack (Must be unique across Azure Stack)  | siterecoverycssa |
| AzureSubnetRange | The subnet range of the virtual network to be created on public Azure (In CIDR notation)  | 192.168.1.0/24 |
| AzureVNetRange | The address space of the virtual network to be created on public Azure (In CIDR notation)  | 192.168.0.0/16 |
| AzureLocation | The location of the recovery services vault on public Azure  | UK West |
| ReplicationPolicyName | The name of the site recovery replication policy to be created in the recovery services vault  | ReplicationPolicy |
| AzureResourceGroup | The name of the resource group to be created on public Azure  | SiteRecoveryTestRG |
| VaultName | The name of the recovery services vault to be created on public Azure  | AzureStackVault |
| ConfigServerUsername | The username for the configuration server  | ConfigAdmin |
| ConfigServerPassword | The password for the configuration server | |
| EncryptionKey | The encryption key for the MySQL database on the configuration server  | ExampleEncryptionKey |
| WindowsUsername | The username of an administrator account on the Windows VMs to be protected  | Administrator |
| WindowsPassword | The password of an administrator account on the Windows VMs to be protected | |
| LinuxRootPassword | The password of the root account on the Linux VMs to be protected | |

## Notes

This ARM template and accompanying scripts were created following the process found in the [Azure Stack Site Recovery documentation](https://docs.microsoft.com/en-us/azure/site-recovery/azure-stack-site-recovery#step-1-prepare-azure-stack-vms).

### MySQL Password Requirements

Password must conform to all of the following rules:

- Password must contain at least one letter
- Password must contain at least one number
- Password must contain at least one special character (_!@#$%)
- Password must be between 8 and 16 characters
- Password cannot contain spaces

## See Also

PowerShell scripts for fail over and fail back can be found here: [Azure Site Recovery PowerShell Scripts](https://github.com/UKCloud/AzureStack/tree/master/PowerShell/Azure%20Site%20Recovery)