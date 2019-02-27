# Linux Custom Script Extensions

This document outlines the function of each of these extensions as well as how to use them.

## How to use custom script extensions with Linux via the portal

1. Log into the Azure / Azure Stack portal.
2. Navigate to the VM that you wish to use the extension with.
3. Select the **Extensions** blade under the *settings* section.
4. Click **+Add**.
5. Select **Custom Script For Linux**, then click **Create**.
6. Upload the extension file.
7. Construct the command based off of the information below specific to the extension.
8. Click **OK**

## How to use custom script extensions with Linux via PowerShell

```PowerShell
$Extensions = Get-AzureRmVMExtensionImage -Location "<Location>" -PublisherName Microsoft.Azure.Extensions -Type CustomScript
$ExtensionVersion = $Extensions[0].Version[0..2] -join ""
$ScriptSettings = @{"fileUris" = @("https://raw.githubusercontent.com/UKCloud/AzureStack/<Extension Location>"); "commandToExecute" = "<Extension Specific Command>"};
Set-AzureRmVMExtension -ResourceGroupName "<Resource Group Name>" -Location "<Location>" -VMName "<VM Name>" -Name $Extensions[0].Type -Publisher $Extensions[0].PublisherName -ExtensionType $Extensions[0].Type -TypeHandlerVersion $ExtensionVersion -Settings $ScriptSettings
```

## SetRootPassword.sh

### Overview

This extension changes the root password of a Linux VM to the specified value. This is necessary for Azure Site Recovery, however it is bad practice to use this in any circumstance where it is not necessary. This script also enables root via SSH, which is also required for Azure Site Recovery.

### Command Structure

`sh ChangePassword.sh <Password>`

**Example**: `sh ChangePassword.sh Password123!`
