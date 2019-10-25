#Requires -Module "ServiceFabric"

# Initialise environment and variables
# Declare endpoint
$StackArmEndpoint = "https://management.frn00006.azure.ukcloud.com"

## Add environment
Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $StackArmEndpoint

# Create your Credentials
$AzsUsername = "admin@meetuponboardingtest01.onmicrosoft.com"
$AzsPassword = 'meetupdemo123!!'
$AzsUserPassword = ConvertTo-SecureString -String $AzsPassword -AsPlainText -Force
$AzsCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AzsUsername, $AzsUserPassword

## Login
Connect-AzureRmAccount -EnvironmentName "AzureStackUser" -Credential $AzsCred

# Obtain unique value
$UniqueId = Get-Random -Maximum 100

# Key vault variables
$ResourceGroupNameKV = "TestSFCKV$($UniqueId)"
$VaultName = "TestVault$($UniqueId)"
$KeyVaultSecretName = "Secret$($UniqueId)"

# Service Fabric variables
$ResourceGroupName = "TestSFC01$($UniqueId)"
$AdminUserName = "testadmin"
$AdminPassword = "Password1234!"
$FilePath = "C:\temp\Test$($UniqueId)"


### PowerShell Stuff ###
$NewKeyVault = New-AzsKeyVault -ResourceGroupName $ResourceGroupNameKV -VaultName $VaultName
$NewCert = New-Certificate -CertPath $FilePath -AppName $ResourceGroupName
# Supply Cmdlet default value.
$NewKeyVaultSecret = New-AzsKeyVaultSecret -VaultName $($NewKeyVault.VaultName) -KeyVaultSecretName $KeyVaultSecretName -PfxFilePath $($NewCert.PfxFilePath)

$CertThumbprint = $($NewKeyVaultSecret.Thumbprint)
$SourceVaultValue = $($NewKeyVaultSecret.KeyVaultID)
$CertUrl = $($NewKeyVaultSecret.SecretID)

$StopWatch = [Diagnostics.StopWatch]::StartNew()
$NewServiceFabricClusterEndpoint = New-AzsSFCluster -ResourceGroupName $ResourceGroupName -AdminUserName $AdminUserName -AdminPassword $AdminPassword -SourceVaultValue $SourceVaultValue -ClusterCertificateUrlValue $CertUrl -ClusterCertficateThumbprint $CertThumbprint -ServerCertficateUrlValue $CertUrl -ServerCertficateThumbprint $CertThumbprint -AdminClientCertificateThumbprint $CertThumbprint
$StopWatch.Stop()
Write-Output -InputObject "New-AzsSFCluster deployment cmdlet took $($StopWatch.Elapsed) to execute."

Publish-ServiceFabricAppWithVisualStudio -FilePath $FilePath -SolutionPath $FilePath\Voting.sln
Set-XML -ServiceFabricClusterUrl $NewServiceFabricClusterEndpoint -CertThumbprint $CertThumbprint -FilePath $FilePath
Connect-ServiceFabricCluster -ConnectionEndpoint $NewServiceFabricClusterEndpoint -X509Credential -ServerCertThumbprint $CertThumbprint -FindType FindByThumbprint -FindValue $CertThumbprint -StoreLocation "CurrentUser" -StoreName "My" -Verbose
# Replace endpoint to be dashboard.
$ServiceFabricDashboardEndpoint = $NewServiceFabricClusterEndpoint -replace "19000", "19080"
# Open Service Fabric cluster dashboard.
[System.Diagnostics.Process]::Start("chrome.exe", "https://$ServiceFabricDashboardEndpoint") | Out-Null
# Deploy the web app to fabric.
& "$FilePath\Voting\Scripts\Deploy-FabricApplication.ps1" -ApplicationPackagePath "$FilePath\Voting\pkg\Debug" -PublishProfileFile "$FilePath\Voting\PublishProfiles\Cloud.xml" -DeployOnly:$false -ApplicationParameter:@{ } -UnregisterUnusedApplicationVersionsAfterUpgrade $false -OverrideUpgradeBehavior "None" -OverwriteBehavior "SameAppTypeAndVersion" -SkipPackageValidation:$false -ErrorAction "Stop"
# Open Web app.
$WebAppEndpointOnServiceFabric = $NewServiceFabricClusterEndpoint -replace "19000", "8080"
$Deployed = $false
do {
    try {
        [Void]((Invoke-WebRequest -Uri "http://$WebAppEndpointOnServiceFabric" -UseBasicParsing).StatusCode -ne 200)
        $Deployed = $true
    }
    catch {
        Write-Output -InputObject "Sleeping until web App is ready..."
        Start-Sleep -Seconds 5
    }
}
while (-not $Deployed)

Write-Output -InputObject "Voting web App is now ready!"

# Populate voting inside the App
Import-Module -Name "Selenium"
$Firefox_Options = New-Object -TypeName "OpenQA.Selenium.Firefox.FirefoxOptions"
$Firefox_Options.LogLevel = 6
$Driver = New-Object -TypeName "OpenQA.Selenium.Firefox.FirefoxDriver" -ArgumentList $Firefox_Options
Enter-SeUrl -Driver $Driver -Url "http://$WebAppEndpointOnServiceFabric"
Start-Sleep -Milliseconds 50

$VotingOptions = @("Azure Stack", "AWS Outposts", "Google Anthos", "UKCloud", "Azure Stack is not a brand... it is a way of life!", "Chicken Noodles", "Happy Azure Stacking", "Thank you for coming!")

foreach ($VotingOption in $VotingOptions) {
    $Element = Find-SeElement -Driver $Driver -Id "txtAdd"
    Start-Sleep -Milliseconds 50
    Send-SeKeys -Element $Element -Keys $VotingOption
    $ElementClick = Find-SeElement -Driver $Driver -Id "btnAdd"
    Start-Sleep -Milliseconds 50
    Invoke-SeClick -Element $ElementClick -Driver $Driver
}

$Count = 0
while (($Count -le 10)) {
    $HappyAzureStackingButton = Find-SeElement -Driver $Driver -ClassName "btn-success" | Where-Object -FilterScript { $_.Text -like "*Azure Stack is not a brand... it is a way of life!*" }
    Invoke-SeClick -Element $HappyAzureStackingButton -Driver $Driver
    $Count++
}
#Stop-SeDriver -Driver $Driver
