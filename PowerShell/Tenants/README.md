---
title: Configure the Azure Stack user's PowerShell environment for UKCloud |  based on Microsoft Docs
description: Configure the Azure Stack user's PowerShell environment
services: azure-stack
author: Chris Black
---

# Configure the Azure Stack user's PowerShell environment

As an Azure Stack user, you can configure your Azure Stack Development Kit's PowerShell environment. After you configure, you can use PowerShell to manage Azure Stack resources such as subscribe to offers, create virtual machines, deploy Azure Resource Manager templates,  etc. This topic is scoped to use with the user environments only, if you want to set up PowerShell for the cloud operator environment, refer to the [Configure the Azure Stack operator's PowerShell environment](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/azure-stack-powershell-configure-admin.md) article. 

## Prerequisites

Run the following prerequisites either from the [development kit](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/azure-stack-connect-azure-stack.md#connect-to-azure-stack-with-remote-desktop), or from a Windows-based external client if you are [connected through VPN](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/azure-stack-connect-azure-stack.md#connect-to-azure-stack-with-vpn):

* Install [Azure Stack-compatible Azure PowerShell modules](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/azure-stack-powershell-install.md).  
* Download the [tools required to work with Azure Stack](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/azure-stack-powershell-download.md). 

## Configure the user environment and sign in to Azure Stack

UKCloud FRN00006 Region is based on the Azure AD deployment type, run the following scripts to configure PowerShell for Azure Stack (Make sure to replace the AADTenantName, GraphAudience endpoint, and ArmEndpoint values as per your environment configuration):

### Azure Active Directory (AAD) based deployments

  ```powershell
  # Set Execution Policy
  # Navigate to the downloaded folder for AzureStackTools and import the **Connect** PowerShell module. Example: cd c:\AzureStack-Tools\
  Set-ExecutionPolicy RemoteSigned
  Import-Module .\Connect\AzureStack.Connect.psm1

  # For UKCloud Azure Stack FRN00006 Region, this value is set to https://management.frn00006.azure.ukcloud.com.
  $ArmEndpoint = "https://management.frn00006.azure.ukcloud.com"

  # For UKCloud Azure Stack FRN00006 Region, this value is set to https://graph.windows.net/.
  $GraphAudience = "https://graph.windows.net/"

  # Azure Active Directory Domain that you are trying connect to. Examples are: <myDirectoryTenantName>.onmicrosoft.com or just your federated with AAD Domain i.e. ukcloud.com
  $AADTenantName = "<myDirectoryTenantName>.onmicrosoft.com"

  # Register an AzureRM environment that targets your Azure Stack instance
  Add-AzureRMEnvironment `
    -Name "AzureStackUser" `
    -ArmEndpoint $ArmEndpoint

  # Set the GraphEndpointResourceId value
  Set-AzureRmEnvironment `
    -Name "AzureStackUser" `
    -GraphAudience $GraphAudience

  # Get the Active Directory tenantId that is used to by your on-boarded domain on Azure Stack
  $TenantID = Get-AzsDirectoryTenantId `
    -AADTenantName $AADTenantName `
    -EnvironmentName "AzureStackUser"

  # Sign in to your environment
  Login-AzureRmAccount `
    -EnvironmentName "AzureStackUser" `
    -TenantId $TenantID
   ```

### Azure Active Directory (AAD) based deployments - Streamlined version for ease of use

  ```powershell
  # Set Execution Policy
  Set-ExecutionPolicy RemoteSigned

  # Register an AzureRM environment that targets your Azure Stack instance
  Add-AzureRMEnvironment -Name "AzureStackUser" -ArmEndpoint "https://management.frn00006.azure.ukcloud.com"

  # Sign in to your environment
  Login-AzureRmAccount -EnvironmentName "AzureStackUser"
   ```

### Azure Active Directory (AAD) based deployments - Embedded Credentials

  ```powershell
  # Set Execution Policy
  Set-ExecutionPolicy RemoteSigned

  # Register an AzureRM environment that targets your Azure Stack instance
  Add-AzureRMEnvironment -Name "AzureStackUser" -ArmEndpoint "https://management.frn00006.azure.ukcloud.com"

  # Create your Credentials
  $AZSusername =  "<username>@<myDirectoryTenantName>.onmicrosoft.com"
  $AZSpassword = '<your password>'
    $AZSuserPassword = ConvertTo-SecureString "$AZSpassword" -AsPlainText -Force
    $AZScred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AZSusername,$AZSuserPassword

  # Sign in to your environment
  Login-AzureRmAccount -Credential $AZScred -EnvironmentName "AzureStackUser"
   ```

## Test the connectivity

Now that we've got everything set-up, let's use PowerShell to create resources within Azure Stack. For example, you can create a resource group for an application and add a virtual machine. Use the following command to create a resource group named "MyResourceGroup":

```powershell
New-AzureRmResourceGroup -Name "MyResourceGroup" -Location "frn00006"
```

## Next steps

* [Develop templates for Azure Stack](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/user/azure-stack-develop-templates.md)
* [Deploy templates with PowerShell](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-stack/user/azure-stack-deploy-template-powershell.md)
