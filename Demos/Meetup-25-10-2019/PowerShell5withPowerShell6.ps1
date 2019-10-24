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
