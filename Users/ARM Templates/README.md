# How to use ARM templates on Azure Stack

## Via the portal

1. Login to the [Azure Stack Portal](https://portal.frn00006.azure.ukcloud.com/).
2. Click on **+ Create a resource**
3. Go to the **Custom** section
4. Select **Template Deployment** and click **Create**
5. Click **Template**
6. Copy the desired template into the editor, then click **Save**
7. Input the required parameters
8. Click **Create**

## Via PowerShell

```PowerShell
# Login to Azure Stack
## Register an AzureRM environment that targets your Azure Stack instance
Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint "https://management.frn00006.azure.ukcloud.com"

## Create your Credentials
$AzsUsername =  "<username>@<myDirectoryTenantName>.onmicrosoft.com"
$AzsPassword = '<your password>'
$AzsSecurePassword = ConvertTo-SecureString $AzsPassword -AsPlainText -Force
$AzsCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AzsUsername, $AzsSecurePassword 

## Sign in to your environment
Login-AzureRmAccount -Credential $AzsCredentials -EnvironmentName "AzureStackUser"

# Deploy the ARM template
$ResourceGroupName = "<Resource Group Name>"
New-AzureRmResourceGroup -Name $ResourceGroupName -Location "frn00006"
New-AzureRmResourceGroupDeployment -Name "<Chosen deployment name>" -ResourceGroupName $ResourceGroupName `
    -TemplateUri "https://raw.githubusercontent.com/UKCloud/AzureStack/master/<Template Location>/azuredeploy.json" `
    -Parameter1 "<Parameter 1>" -Parameter2 "<Parameter 2>" ... -Verbose
```
