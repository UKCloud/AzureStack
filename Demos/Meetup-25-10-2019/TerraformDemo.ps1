######################## Misc Set up ##################################
# Set up folders and files for demo
try {
    # folders
    New-Item -Path "AzurePublic" -ItemType Directory -Force | Out-Null
    New-Item -Path "AzureStack" -ItemType Directory -Force | Out-Null

    # terraform files
    New-Item -Path "AzureStack\main.tf" -ItemType File -Force | Out-Null
    New-Item -Path "AzureStack\variables.tf" -ItemType File -Force | Out-Null
    New-Item -Path "AzureStack\terraform.tfvars" -ItemType File -Force | Out-Null
}
catch {
    Write-Error -Message "$($_)"
    Write-Error -Message "$($_.Exception.Message)"
    break
}

# Check Selenium is installed, if not download it.
try {
    $SeleniumCheck = Get-Module -Name Selenium
    if (-not $SeleniumCheck) {
        Install-Module -Name Selenium
        Import-Module -Name Selenium
    }
}
catch {
    Write-Error -Message "$($_)"
    Write-Error -Message "$($_.Exception.Message)"
    break
}

Clear-Host
######################## End Misc Set up ##################################


######################## SPN Setup ###################################
# Use if context error is encountered and try again
Get-AzureRmContext | Remove-AzureRmContext -Force

## Declare Variables
# SPN variables
[String]$UniqueId = Get-Random -Maximum "100"
$AppName = "TF-Demo" + $UniqueId
$AppURL = "https://tf$UniqueId-demo.app"
$AppPassword = 'Password123!'

## Azure (Stack) credentials
$PasswordString = 'Password123!!'

## Role assignment
$PublicAzureRole = "Contributor"
$AzureStackRole = "Contributor"

# Setup Azure credentials
$TenantDomain = "meetuponboardingtest01.onmicrosoft.com"
$PublicAzureAdminUsername = "admin" + "@" + $TenantDomain
$PublicAzureAdminPassword = ConvertTo-SecureString -String $PasswordString -AsPlainText -Force
$PublicAzureAdminCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $PublicAzureAdminUsername, $PublicAzureAdminPassword
$ArmEndpoint = "https://management.frn00006.azure.ukcloud.com"

# Selenium VM variables
$RgName = "testrga" + $UniqueId
$VmCount = "2"
$VmUserName = "azsdemousr"
$VmPassword = "azsdemopw1!!"


# Login to Azure public and create an SPN
try {
    Write-Output -InputObject "Creating SPN in Azure Public and waiting 30 seconds... `n"
    # Log in to your public Azure Subscription and Azure AD you will be creating your SPN on
    Connect-AzureAD -Credential $PublicAzureAdminCred -TenantId $TenantDomain -ErrorAction "Stop" | Out-Null
    Connect-AzureRmAccount -Credential $PublicAzureAdminCred -ErrorAction "Stop" | Out-Null

    # List subscriptions
    $AzureSub = Get-AzureRmSubscription -ErrorAction "Stop" | Select-Object -Property SubscriptionId, TenantId

    # Set context to be your active Subscription
    Get-AzureRmSubscription -SubscriptionId $AzureSub.SubscriptionId -TenantId $AzureSub.TenantId -ErrorAction "Stop"| Set-AzureRmContext | Out-Null

    # Create an Azure AD application
    $App = New-AzureADApplication -DisplayName $AppName -HomePage $AppURL -IdentifierUris $AppURL
    $AppPassword = New-AzureADApplicationPasswordCredential -ObjectId $App.ObjectId -Value $AppPassword

    # Create a Service Principal Name (SPN) for the application you created earlier.
    New-AzureADServicePrincipal -AppId $App.AppId -ErrorAction "Stop" | Out-Null

    # Requires a few seconds for the SPN to be created
    Start-Sleep -Seconds 30

    Write-Output -InputObject "SPN: $AppName Successfully created in tenant domain: $TenantDomain under subscription: $($AzureSub.SubscriptionId)`n"
}
catch {
    Write-Error -Message "$($_)"
    Write-Error -Message "$($_.Exception.Message)"
    break
}

# Assign roles the the SPN for Azure Public
$Retry = 0
do {
    $SPNSuccess = $null
    try {
        New-AzureRmRoleAssignment -RoleDefinitionName $PublicAzureRole -ServicePrincipalName $App.AppId -ErrorAction "Stop" | Out-Null
        $SPNSuccess = $true
    }
    catch {
        if ($Retry -le 10) {
            $Retry++
            Write-Output -Message "Cannot retrieve Microsoft Cloud Agreement from the Partner Center API, retrying... - retry count: $Retry`n"
            Start-Sleep -Seconds 5
        }
        else {
            Write-Error -Message "$($_)"
            Write-Error -Message "$($_.Exception.Message)"
            break
        }
    }
}
while (-not $SPNSuccess)

# Grant Permission to Azure Active Directory to SPN
$Req = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$Req.ResourceAppId = "00000002-0000-0000-c000-000000000000"
$Acc1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "5778995a-e1bf-45b8-affa-663a9f3f4d04", "Role"
$Acc2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "abefe9df-d5a9-41c6-a60b-27b38eac3efb", "Role"
$Acc3 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "78c8a3c8-a07e-4b9e-af1b-b5ccab50a175", "Role"
$Acc4 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "1138cb37-bd11-4084-a2b7-9f71582aeddb", "Role"
$Acc5 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "9728c0c4-a06b-4e0e-8d1b-3d694e8ec207", "Role"
$Acc6 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7", "Role"
$Acc7 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "1cda74f2-2616-4834-b122-5cb1b07f8a59", "Role"
$Acc8 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "aaff0dfd-0295-48b6-a5cc-9f465bc87928", "Role"
$Acc9 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "a42657d6-7f20-40e3-b6f0-cee03008a62a", "Scope"
$Acc10 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "5778995a-e1bf-45b8-affa-663a9f3f4d04", "Scope"
$Acc11 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "78c8a3c8-a07e-4b9e-af1b-b5ccab50a175", "Scope"
$Acc12 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "970d6fa6-214a-4a9b-8513-08fad511e2fd", "Scope"
$Acc13 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "6234d376-f627-4f0f-90e0-dff25c5211a3", "Scope"
$Acc14 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "c582532d-9d9e-43bd-a97c-2667a28ce295", "Scope"
$Acc15 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "cba73afc-7f69-4d86-8450-4978e04ecd1a", "Scope"
$Acc16 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6", "Scope"
$Acc17 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2d05a661-f651-4d57-a595-489c91eda336", "Scope"
$Req.ResourceAccess = $Acc1, $Acc2, $Acc3, $Acc4, $Acc5, $Acc6, $Acc7, $Acc8, $Acc9, $Acc10, $Acc11, $Acc12, $Acc13, $Acc14, $Acc15, $Acc16, $Acc17

# Set permissions for the SPN
try {
    Set-AzureADApplication -ObjectId $App.ObjectId -RequiredResourceAccess $Req -ErrorAction "Stop"
    Write-Output -InputObject "Successfully set permissions for SPN: $AppName`n"
}
catch {
    Write-Error -Message "$($_)"
    Write-Error -Message "$($_.Exception.Message)"
    break
}

# Login to Azure Stack and assign a role to the SPN
try {
    # Set the Azure Stack credentials
    $AzsUsernameAdmin = "admin" + "@" + $TenantDomain
    $AzsUserPasswordAdmin = ConvertTo-SecureString -String $PasswordString -AsPlainText -Force
    $AzsCredAdmin = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AzsUsernameAdmin, $AzsUserPasswordAdmin

    # Add the Azure Stack environment and login
    Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint -ErrorAction "Stop" | Out-Null
    Connect-AzureRmAccount -EnvironmentName "AzureStackUser" -Credential $AzsCredAdmin -ErrorAction "Stop" | Out-Null

    # Get Azure Stack Subscription details
    $AzureStackSub = Get-AzureRmSubscription -ErrorAction "Stop" | Select-Object -Property SubscriptionId, TenantId

    # Get location of Azure Stack
    $Location = (Get-AzureRmLocation).Location

    # Get SPN details from Azure AD
    $AzsApp = Get-AzureRmADApplication -DisplayNameStartWith "$($App.DisplayName)" -ErrorAction "Stop"
    Write-Output -InputObject "Successfully retrieved SPN: $($App.DisplayName) from Azure Stack domain: $TenantDomain`n"

    # Set the SPN a role in Azure Stack e.g. Contributor
    New-AzureRmRoleAssignment -RoleDefinitionName $AzureStackRole -ServicePrincipalName $AzsApp.ApplicationId.Guid -ErrorAction "Stop" | Out-Null
    Write-Output -InputObject "Successfully assigned role of: $AzureStackRole to $AppName`n"
}
catch {
    Write-Error -Message "$($_)"
    Write-Error -Message "$($_.Exception.Message)"
    break
}

# Export data for terraform provider variables for Azure Stack
$TFVars = @{
ArmEndpoint    = "$($ArmEndpoint)"
SubId          = "$($AzureStackSub.SubscriptionId)"
ClientId       = "$($App.AppId)"
ClientSecret   = "$($AppPassword.Value)"
TenantId       = "$($AzureStackSub.TenantId)"
Location       = "$($Location)"
RgName         = "$($RgName)"
VmCount        = "$($VmCount)"
VmUserName     = "$($VmUserName)"
VmPassword     = "$($VmPassword)"
}

Write-Output -InputObject "SPN setup finished"
######################## End SPN Setup #############################


######################## Selenium ##################################
# Open the docs using Selenium #STRINGS MAY NOT WORK, IF SO REMOVE QUOTES
$Firefox_Options = New-Object -TypeName "OpenQA.Selenium.Firefox.FirefoxOptions"
$Firefox_Options.LogLevel = 6
$Driver = New-Object -TypeName "OpenQA.Selenium.Firefox.FirefoxDriver" -ArgumentList $Firefox_Options

# Open web page
Enter-SeUrl -Url "https://docs.ukcloud.com/articles/azure/azs-how-create-vm-terraform.html?tabs=tabid-1%2Ctabid-a" -Driver $Driver
# Change tab to linux vm

# Get the form elements from the docs page
$ArmEndpointField = Find-SeElement -Driver $Driver -Name "arm_endpoint"
$SubIdField = Find-SeElement -Driver $Driver -Name "subscription_id"
$ClientIdField = Find-SeElement -Driver $Driver -Name "client_id"
$ClientSecretField = Find-SeElement -Driver $Driver -Name "client_secret"
$TenantIdField = Find-SeElement -Driver $Driver -Name "tenant_id"
$LocationField = Find-SeElement -Driver $Driver -Name "location"
$RgNameField = Find-SeElement -Driver $Driver -Name "rg_name"
$VmCountField = Find-SeElement -Driver $Driver -Name "vm_count"
$VmUserNameField = Find-SeElement -Driver $Driver -Name "vm_username"
$VmPassword = Find-SeElement -Driver $Driver -Name "vm_password"
$TfMainFileCodeBlock = Find-SeElement -Driver $Driver -ClassName "language-hcl"


# Populate forms
Send-SeKeys -Element $ArmEndpointField -Keys $TFVars.ArmEndpoint
Send-SeKeys -Element $SubIdField -Keys $TFVars.SubId
Send-SeKeys -Element $ClientIdField -Keys $TFVars.ClientId
Send-SeKeys -Element $ClientSecretField -Keys $TFVars.ClientSecret
Send-SeKeys -Element $TenantIdField -Keys $TFVars.TenantId
Send-SeKeys -Element $LocationField -Keys $TFVars.Location
Send-SeKeys -Element $RgNameField -Keys $TFVars.RgName
Send-SeKeys -Element $VmCountField -Keys $TFVars.VmCount
Send-SeKeys -Element $VmUserNameField -Keys $TFVars.VmUserName
Send-SeKeys -Element $VmPassword -Keys $TFVars.VmPassword

# Get data from template files
$TfMainFileCodeBlock.Text[2] | Set-Content -Path ".\AzureStack\main.tf"
$TfMainFileCodeBlock.Text[4] | Set-Content -Path ".\AzureStack\terraform.tfvars"
$TfMainFileCodeBlock.Text[5] | Set-Content -Path ".\AzureStack\variables.tf"

# USE IF SELENIUM FAILS: Write-Output -InputObject "$OutputTFVarsAzureStack"
######################## End Selenium ##############################


######################## Azure Stack ###############################
# Run in a different PowerShell session to keep variables available for Azure Public
.\terraform.exe init .\AzureStack
.\terraform.exe apply -state-out=".\AzureStack\state" -state=".\AzureStack\state" -var-file=".\AzureStack\terraform.tfvars" -lock="false" -auto-approve .\AzureStack
######################## Azure Stack ###############################


######################## Azure Public ###############################
# Export data for terraform provider variables for Azure Public
(((Get-Content -Path ".\AzureStack\terraform.tfvars") -replace "subscription_id.*", "subscription_id = `"$($AzureSub.SubscriptionId)`"") -replace "location.*", "location        = `"uksouth`"") -replace "arm_endpoint.*", "" | Out-File -FilePath ".\AzurePublic\terraform.tfvars" -Encoding ascii -Force -Verbose
(Get-Content -Path ".\AzurePublic\terraform.tfvars") | Where-Object -FilterScript { $_.trim() -ne "" } | Set-Content -Path ".\AzurePublic\terraform.tfvars" -Force

(Get-Content -Path ".\AzureStack\variables.tf" | Select-Object -Skip 4) | Set-Content -Path ".\AzurePublic\variables.tf"

# Replace Azure Stack resource provider in main.tf with one for Azure Public
((Get-Content -Path ".\AzureStack\main.tf") -replace "azurestack", "azurerm") -notmatch "arm_endpoint*" | Out-File -FilePath ".\AzurePublic\main.tf" -Encoding ascii -Force
# Get-ChildItem -Path "." -Filter "*tfstate*" | Remove-Item

# Initialise and run terraform
.\terraform.exe init .\AzurePublic
.\terraform.exe apply -state-out=".\AzurePublic\state" -state=".\AzurePublic\state" -var-file=".\AzurePublic\terraform.tfvars" -lock="false" -auto-approve .\AzurePublic
######################## Azure Public END ###############################


######################## VM Display/Testing #############################
### Get ssh credentials
$SshUsername = ((Get-Content .\AzureStack\terraform.tfvars | Select-String -Pattern "admin_username") -Split "=")[1] -replace "`"" -replace " "
$SshPassword = ((Get-Content .\AzureStack\terraform.tfvars | Select-String -Pattern "admin_password") -Split "=")[1] -replace "`"" -replace " "

## Connect to the VM in Azure Public
# .\terraform.exe init .\AzurePublic
$AzureVMPublicIp = ((.\terraform.exe state show -state=".\AzurePublic\state" azurerm_public_ip.public-ip[0] | Select-String  -SimpleMatch "ip_address") -Split "=")[1] -replace "`"" -replace " "
$AzureVMPublicIp2 = ((.\terraform.exe state show -state=".\AzurePublic\state" azurerm_public_ip.public-ip[1] | Select-String  -SimpleMatch "ip_address") -Split "=")[1] -replace "`"" -replace " "
$AzVM1 = echo y | plink -v  $SshUsername@$AzureVMPublicIp -pw $SshPassword "hostnamectl && uptime"
$AzVM2 = echo y | plink -v  $SshUsername@$AzureVMPublicIp2 -pw $SshPassword "hostnamectl && uptime"

Write-Output -InputObject "`t------ AzVM1 ------"
Write-Output -InputObject $AzVM1
Write-Output -InputObject "`t------ AzVM2 ------"
Write-Output -InputObject $AzVM2


## Connect to the VM in Azure Stack
.\terraform.exe init .\AzureStack | Out-Null
$AzsVMPublicIp = ((.\terraform.exe state show -state=".\AzureStack\state" azurestack_public_ip.public-ip[0] | Select-String  -SimpleMatch "ip_address") -Split "=")[1] -replace "`"" -replace " "
$AzsVMPublicIp2 = ((.\terraform.exe state show -state=".\AzureStack\state" azurestack_public_ip.public-ip[1] | Select-String  -SimpleMatch "ip_address") -Split "=")[1] -replace "`"" -replace " "
$AzsVM1 = echo y | plink -v  $SshUsername@$AzsVMPublicIp -pw $SshPassword "hostnamectl && uptime"
$AzsVM2 = echo y | plink -v  $SshUsername@$AzsVMPublicIp2 -pw $SshPassword "hostnamectl && uptime"

Write-Output -InputObject "`t------ AzsVM1 ------"
Write-Output -InputObject $AzsVM1
Write-Output -InputObject "`t------ AzsVM2 ------"
Write-Output -InputObject $AzsVM2

######################## End VM Display/Testing ##########################