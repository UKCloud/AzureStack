# Declare endpoint
$ArmEndpoint = "https://management.frn00006.azure.ukcloud.com"
Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint
#$TenantId = Get-AzsDomainTenantId -TenantId "contoso.onmicrosoft.com"
$Domain = "contoso.onmicrosoft.com"
$TenantId = (Invoke-WebRequest -Uri https://login.windows.net/$Domain/.well-known/openid-configuration -UseBasicParsing | ConvertFrom-Json).Token_Endpoint.Split('/')[3]

# Public Azure token
Invoke-Command -ArgumentList $TenantId -ScriptBlock { & pwsh.exe -Command "& { [Void](Connect-AzAccount -Tenant $TenantId); `$Context = Get-AzContext; `$CachedTokens = `$Context.TokenCache.ReadItems() | Where-Object -FilterScript { `$_.TenantId -eq `$Context.Tenant.Id } | Sort-Object -Property ExpiresOn -Descending; `$AzureRmAccessToken = `$CachedTokens[0].AccessToken; `$AzureRmAccessToken | Out-File -FilePath `"C:\Token.txt`" -Encoding ascii -Force }"; $global:AccessToken = Get-Content -Path "C:\Token.txt"; Remove-Item -Path "C:\Token.txt" -Force }
Connect-AzureRmAccount -Tenant $TenantId -AccessToken $AccessToken -AccountId "1950a258-227b-4e31-a9cf-717495945fc2"
Get-AzureRmResourceGroup
# Azure Stack token
Invoke-Command -ArgumentList $TenantId, $ArmEndpoint -ScriptBlock { & pwsh.exe -Command "& { Add-AzEnvironment -Name 'AzureStackUser' -ArmEndpoint $ArmEndpoint; [Void](Connect-AzAccount -Tenant $TenantId -Environment 'AzureStackUser'); `$Context = Get-AzContext; `$CachedTokens = `$Context.TokenCache.ReadItems() | Where-Object -FilterScript { `$_.TenantId -eq `$Context.Tenant.Id } | Sort-Object -Property ExpiresOn -Descending; `$AzureRmAccessToken = `$CachedTokens[0].AccessToken; `$AzureRmAccessToken | Out-File -FilePath `"C:\Token.txt`" -Encoding ascii -Force }"; $global:AccessToken = Get-Content -Path "C:\Token.txt"; Remove-Item -Path "C:\Token.txt" -Force }
Connect-AzureRmAccount -Tenant $TenantId -AccessToken $AccessToken -AccountId "1950a258-227b-4e31-a9cf-717495945fc2" -Environment "AzureStackUser"
Get-AzureRmResourceGroup


# dockerfile
# FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-20190910-windowsservercore-ltsc2016
# FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-20190910-windowsservercore-ltsc2019

# Test Variables
$LongVar1 = "I Love Azure Stack"
$LongVar2 = "I Love Azure Stack even more now."
$LongVar3 = "I Love Azure Stack maybe still."
$LongVar4 = "I Love Azure Stack who knows why."
$LongVar5 = "I Love Azure Stack - Ignite?"
$LongVar6 = "I Love Azure Stack - how about Traffic Manager MSFT?"


# Service Fabric Repos
[System.Diagnostics.Process]::Start("chrome.exe", "https://systemgallery.blob.frn00006.azure.ukcloud.com/dev20161101-microsoft-windowsazure-gallery/Microsoft.ServiceFabricCluster.1.0.3/DeploymentTemplates/MainTemplate.json") | Out-Null
[System.Diagnostics.Process]::Start("chrome.exe", "https://github.com/Azure-Samples/service-fabric-dotnet-quickstart") | Out-Null
# https://systemgallery.blob.frn00006.azure.ukcloud.com/dev20161101-microsoft-windowsazure-gallery/Microsoft.ServiceFabricCluster.1.0.3/DeploymentTemplates/MainTemplate.json
# https://github.com/Azure-Samples/service-fabric-dotnet-quickstart# Fabric quickstart .net application sample. Contribute to Azure-Samples/service-fabric-dotnet-quickstart development by creating an account on GitHub.github.com

<# Pre-requisites for Service Fabric code to work:
1. PowerShell 5+ and lots of modules ;-)
2. Visual Studio (not VSCode)
3. Service Fabric SDK | described here -> https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-solution-template-service-fabric-cluster?view=azs-1908 - found here -> https://docs.microsoft.com/en-gb/azure/service-fabric/service-fabric-get-started#install-the-sdk-and-tools
4. Valid Azure Stack subscription
5. Git tools
#>
