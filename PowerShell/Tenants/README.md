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

### Install Azure Stack PowerShell

> [!NOTE]
> The following steps require PowerShell 5.0. To check your version, run $PSVersionTable.PSVersion and compare the "Major" version.
> For "legacy" Operating Systems like Windows Server 2008 R2 and Windows 7, or Windows Server 2012 R2, Windows Server 2012, and Windows 8.1
> Download the [Windows Management Framework 5.1](https://docs.microsoft.com/en-us/powershell/wmf/5.1/install-configure)

  ```powershell
  # Set Execution Policy
  Set-ExecutionPolicy RemoteSigned
  # PowerShell commands for Azure Stack are installed through the PowerShell gallery. To register the PSGallery repository, open an elevated PowerShell session from the development kit # or  from a Windows-based external client if you are connected through VPN and run the following command:
  Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
  # Uninstall existing versions of PowerShell
  Get-Module -ListAvailable | where-Object {$_.Name -like “Azure*”} | Uninstall-Module
  # Install the AzureRM.Bootstrapper module. Select Yes when prompted to install NuGet 
  Install-Module -Name AzureRm.BootStrapper
  # Install and import the API Version Profile required by Azure Stack into the current PowerShell session.
  Use-AzureRmProfile -Profile 2017-03-09-profile -Force
  Install-Module -Name AzureStack -RequiredVersion 1.2.11
  ```

## Configure the user environment and sign in to Azure Stack

UKCloud FRN00006 Region is based on the Azure AD deployment type, run the following scripts to configure PowerShell for Azure Stack (Make sure to replace the AADTenantName, GraphAudience endpoint, and ArmEndpoint values as per your environment configuration):

### Azure Active Directory (AAD) based deployments

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