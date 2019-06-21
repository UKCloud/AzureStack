#Requires -Modules AzureRM.ContainerRegistry, AzureRM.ContainerInstance, AzureRM.TrafficManager, AzureRM.Automation
# Capture elapsed time
$StartTime = Get-Date

# Unique param
$UniqueId = "5"

########### Login to Azure Stack
# Declare endpoint
$ArmEndpoint = "https://management.frn00006.azure.ukcloud.com"

# Register an AzureRM environment that targets your Azure Stack instance
Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint

$Username = "admin@meetupdemo123ukcloud5.onmicrosoft.com"
$Password = 'ukcloud123!!!'
$SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($Username , $SecurePassword)

# Login to Azure Stack
Connect-AzureRmAccount -Credential $Cred -Environment "AzureStackUser"

########### Create service principal
# Declare Variables
$AppName = "MeetUpTestApp" + $UniqueId
$AppURL = "https://MeetUptest.app" + $UniqueId
[String]$AppPasswordString = (New-Guid).Guid
$AppPassword = ConvertTo-SecureString -String $AppPasswordString -AsPlainText -Force
$AzureStackRole = "Owner"

# Create an Azure AD application, this is the object that you need in order to set SPN record against.
# Record ApplicationId from output.
try {
    $App = New-AzureRmADApplication -DisplayName $AppName -HomePage $AppURL -IdentifierUris $AppURL -Password $AppPassword
    $AppGet = Get-AzureRmADApplication -ApplicationId $App.ApplicationId.Guid
    $AppGet

    # Create a Service Principal Name (SPN) for the application you created earlier.
    $SPN = New-AzureRmADServicePrincipal -ApplicationId $AppGet.ApplicationId.Guid

    # Find Object Id of your Service Principal Name in Azure Stack
    $SPNAzsGet = Get-AzureRmADServicePrincipal -SearchString "$($AppGet.DisplayName)"
    $SPNAzsGet

    # Assign the Service Principal Name a role i.e. Owner, Contributor, Reader, etc. - In Azure Stack
    $RoleAssignmentAzs = New-AzureRmRoleAssignment -RoleDefinitionName $AzureStackRole -ServicePrincipalName $AppGet.ApplicationId.Guid
    $RoleAssignmentGet = Get-AzureRmRoleAssignment -ObjectId $SPNAzsGet.Id.Guid
    $RoleAssignmentGet
}
catch {
    Write-Error -Message $_
    break
}

# Export data of your SPN
$SPNObject = [PSCustomObject]@{
    ArmEndpoint  = $ArmEndpoint
    ClientId     = $AppGet.ApplicationId.Guid
    ClientSecret = $AppPasswordString
}
$SPNObject

########### Deploy kubernetes cluster as job
# Declare variables
$AzsRGName = "MeetupDemo-RG" + $UniqueId
$KeyVar = "meetup" + $UniqueId

# Create new ssh key
ssh-keygen -t rsa -C "meetup@demo.com" -f $KeyVar -q -N '""'

# Create new kubernetes cluster
Start-Job -Name "KubeCluster" -ArgumentList @($AzsRGName, "$($PWD.Path)\$KeyVar", $SPNObject.ClientId, $SPNObject.ClientSecret, $Username, $Password, $ArmEndpoint) -ScriptBlock {
    param (
        $ResourceGroupName,
        $SSHKeyPath,
        $ServicePrincipal,
        $ClientSecret,
        $Username,
        $Password,
        $ArmEndpoint
    )
    # Login to Azure Stack
    # Register an AzureRM environment that targets your Azure Stack instance
    Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint

    $SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ($Username , $SecurePassword)

    # Login to Azure Stack
    Connect-AzureRmAccount -Credential $Cred -Environment "AzureStackUser"

    # Create kubernetes cluster
    New-AzsAks -ResourceGroupName $ResourceGroupName -SSHKeyPath "$SSHKeyPath.pub" -ServicePrincipal $ServicePrincipal -ClientSecret $ClientSecret
}
# Allow job to actually start
Start-Sleep -Seconds 20

# Check that deployment is running
Get-AzureRmResourceGroupDeployment -ResourceGroupName $AzsRGName

########### Connect to Public Azure
# Login to Public Azure
Connect-AzureRmAccount -Credential $Cred

########### Deploy Container Registry and Container Group
# Create Container Registry
## Declare variables
$AzureRGName = "Container-RG" + $UniqueId
$Location = "uksouth"
$ContainerRegName = "azsmeetupregistry00" + $UniqueId
$DockerFilePath = ".\Demos\Meetup-21-06-2019\"
$DockerTag = "meetupdemo"

try {
    $ResourceGroup = New-AzureRmResourceGroup -Name $AzureRGName -Location $Location
    $ResourceGroup

    $ContainerRegistry = New-AzureRmContainerRegistry -ResourceGroupName $AzureRGName -Name $ContainerRegName -EnableAdminUser -Sku "Basic" -Location $Location
    $ContainerRegistry = Get-AzureRmContainerRegistry -ResourceGroupName $AzureRGName -Name $ContainerRegName

    $ContainerRegistryCreds = Get-AzureRmContainerRegistryCredential -Registry $ContainerRegistry
    $ContainerRegistryCreds
    $ContainerRegistryCreds.Password | docker login $ContainerRegistry.LoginServer -u $ContainerRegistryCreds.Username --password-stdin

    ## Create or declare docker image
    ### Build docker image from GitHub repo
    $DockerTag = $ContainerRegName + ".azurecr.io/$DockerTag" + ":v1"
    docker build $DockerFilePath -t $DockerTag --no-cache

    ### Publish docker image to the container registry
    docker push $DockerTag
}
catch {
    Write-Error -Message $_
    break
}

# Deploy container into a Container Group
# Declare variables
$ContainerName = "meetupdocscontainer" + $UniqueId
$DNSLabel = "meetup-docs-azure" + $UniqueId
$ContainerCreds = New-Object System.Management.Automation.PSCredential ($ContainerRegistryCreds.Username, ($ContainerRegistryCreds.Password | ConvertTo-SecureString -AsPlainText -Force))

try {
    $ContainerGroup = New-AzureRmContainerGroup -ResourceGroupName $AzureRGName -Name $ContainerName -Image $DockerTag -IpAddressType "Public" -RegistryCredential $ContainerCreds -OsType "Linux" -DnsNameLabel $DNSLabel -Port @(80, 443)
    $ContainerGroup
}
catch {
    Write-Error -Message $_
    break
}

########### Deploy Traffic Manager
# Create Traffic Manager
## Declare variables
$TrafficManagerProfileName = "trafficmanagerprofile00" + $UniqueId
$TrafficManagerDnsName = "meetupdocstm00" + $UniqueId

try {
    $TrafficManagerProfile = New-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $AzureRGName -RelativeDnsName $TrafficManagerDnsName -TrafficRoutingMethod "Priority" -Ttl 10 -MonitorProtocol HTTPS -MonitorPort 443 -MonitorPath "/" -Verbose
}
catch {
    Write-Error -Message $_
    break
}

# Add Azure Endpoint to Traffic Manager
## Declare variables
try {
    $Endpoint1 = New-AzureRmTrafficManagerEndpoint -Name $ContainerGroup.Name -ProfileName $TrafficManagerProfileName -ResourceGroupName $AzureRGName -Priority 1 -Type "ExternalEndpoints" -Target $ContainerGroup.IpAddress -EndpointStatus "Enabled" -Verbose
    $Endpoint1
}
catch {
    Write-Error -Message $_
    break
}
# Construct Traffic Manager URL
$TrafficManagerURL = "https://$($TrafficManagerProfile.RelativeDnsName)" + ".trafficmanager.net"

########### Deploy Automation Account and Runbook
# Declare variables
$AutomationAccountName = "MeetupAutomationAcc00" + $UniqueId
$AutomationCredName = "MeetupAutomationCred00" + $UniqueId
$AutomationRunbookName = "MeetupAutomationRunbook00" + $UniqueId
$AutomationRunbookType = "PowerShell"

## Runbook variables
$TMProfileVariable = "TrafficManagerProfile"
$TMRGVariable = "TrafficManagerRG"
$RunbookOutFilePath = ".\Runbook.ps1"

## Get modules
$ModuleArray = @()
$ModuleArray += [PSCustomObject]@{
    Name      = "AzureRM.Profile"
    ModuleURI = (Find-Module -Name "AzureRM.Profile").RepositorySourceLocation + "/package/AzureRM.Profile"
}
$ModuleArray += [PSCustomObject]@{
    Name      = "AzureRM.TrafficManager"
    ModuleURI = (Find-Module -Name "AzureRM.TrafficManager").RepositorySourceLocation + "/package/AzureRM.TrafficManager"
}

try {
    # Create automation account
    New-AzureRmAutomationAccount -ResourceGroupName $AzureRGName -Location $Location -Name $AutomationAccountName
    # Create automation credential
    New-AzureRmAutomationCredential -Name $AutomationCredName -Description "MeetupCred" -AutomationAccountName $AutomationAccountName -ResourceGroupName $AzureRGName -Value $Cred -Verbose
    # Create automation variables
    New-AzureRmAutomationVariable -Name $TMProfileVariable -Description "Traffic Manager Profile Variable" -Value $TrafficManagerProfileName -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName -Encrypted $false
    New-AzureRmAutomationVariable -Name $TMRGVariable -Description "Traffic Manager Resource Group" -Value $AzureRGName -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName -Encrypted $false
    # Create automation runbook
    New-AzureRmAutomationRunbook -Name $AutomationRunbookName -Description "MeetupRunbook" -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName -Type $AutomationRunbookType -Verbose

    # Import modules for automation
    foreach ($Module in $ModuleArray) {
        New-AzureRmAutomationModule -Name $Module.Name -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName -ContentLinkUri $Module.ModuleURI -Verbose
        do {
            Write-Host -Object "Waiting for module $($Module.Name) to be downloaded to the Automation Account" -ForegroundColor Green
            $ModuleStatus = Get-AzureRmAutomationModule -Name $Module.Name -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName
            $ModuleStatus
            if ($ModuleStatus.ProvisioningState -notlike "Succeeded") {
                Start-Sleep -Seconds 5
            }
        }
        while ($ModuleStatus.ProvisioningState -notlike "Succeeded")
    }

    # Create automation runbook file
    @"
`$AutomationCred = Get-AutomationPSCredential -Name $AutomationCredName
`$UserName = `$AutomationCred.UserName
`$SecurePassword = `$AutomationCred.Password
`$Password = `$AutomationCred.GetNetworkCredential().Password
`$AutomationCred = New-Object System.Management.Automation.PSCredential (`$UserName, `$Password)
Connect-AzureRmAccount -Credential `$AutomationCred

`$TMProfileName = Get-AutomationVariable -Name $TMProfileVariable
`$TMResourceGroup = Get-AutomationVariable -Name $TMRGVariable
`$TMProfile = Get-AzureRmTrafficManagerProfile -Name `$TMProfileName -ResourceGroupName `$TMResourceGroup
`$TMProfile.Endpoints[0].Priority = 2
`$TMProfile.Endpoints[1].Priority = 1
Set-AzureRmTrafficManagerProfile -TrafficManagerProfile `$TMProfile

Write-Output -InputObject `$TMProfile.Endpoints
"@ | Out-File -FilePath $RunbookOutFilePath -Verbose -Encoding "ASCII" -Force

    # Import automation runbook code
    Import-AzureRmAutomationRunbook -Name $AutomationRunbookName -Path $RunbookOutFilePath -Type $AutomationRunbookType -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName -Published -Force
}
catch {
    Write-Error -Message $_
    break
}

########### Login to Azure Stack
# Login to Azure Stack
Connect-AzureRmAccount -Credential $Cred -Environment "AzureStackUser"

########### Check kubernetes cluster
# Check kubernetes cluster deployment status
$KubernetesClusterDeploymentStatus = Get-AzureRmResourceGroupDeployment -ResourceGroupName $AzsRGName
$KubernetesClusterDeploymentStatus | Select-Object -Property DeploymentName, ResourceGroupName, ProvisioningState, TimeStamp
while ($KubernetesClusterDeploymentStatus.ProvisioningState -contains "Running" ) {
    Start-Sleep -Seconds 10
    $KubernetesClusterDeploymentStatus = Get-AzureRmResourceGroupDeployment -ResourceGroupName $AzsRGName
    $KubernetesClusterDeploymentStatus | Select-Object -Property DeploymentName, ResourceGroupName, ProvisioningState, TimeStamp
}

########### Configure kubernetes cluster
# Declare variables
$KubeYamlFile = "docs.yaml"

# Get kubernetes cluster details
$KubernetesCluster = Get-AzsAks -ResourceGroupName $AzsRGName
$KubernetesCluster

# Create yaml file for deploying kubernetes service and deployment
@"
apiVersion: v1
kind: Service
metadata:
  name: meetupdemo
spec:
  selector:
    app: meetupdemo
  type: LoadBalancer
  ports:
  - name: http
    protocol: TCP
    port: 80
  - name: https
    protocol: TCP
    port: 443
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: meetupdemo
  labels:
    app: meetupdemo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: meetupdemo
  template:
    metadata:
      labels:
        app: meetupdemo
    spec:
      containers:
      - name: azsmeetupreg
        image: $DockerTag
        ports:
        - containerPort: 80
        - containerPort: 443
      imagePullSecrets:
      - name: regcred
"@ | Out-File -FilePath $KubeYamlFile -Encoding "ASCII" -Force

# Configure kubernetes cluster from yaml file over ssh
# Invoke-Command -ScriptBlock {
#     scp -o "StrictHostKeyChecking no" -i $KeyVar $KubeYamlFile ($($KubernetesCluster."Admin Username" + "@" + $KubernetesCluster."BackEndPublicIP") + ":/home/$($KubernetesCluster."Admin Username")/$KubeYamlFile");
#     ssh -o "StrictHostKeyChecking no" -i $KeyVar $($KubernetesCluster."Admin Username" + "@" + $KubernetesCluster."BackEndPublicIP") docker login $ContainerRegistry.LoginServer -u $ContainerRegistryCreds.Username --password $ContainerRegistryCreds.Password `&`& docker pull $DockerTag `&`& kubectl create secret generic regcred --from-file=.dockerconfigjson=/home/$($KubernetesCluster."Admin Username")/.docker/config.json --type=kubernetes.io/dockerconfigjson `&`& kubectl apply -f $KubeYamlFile
# }

# Invoke-Command -ScriptBlock {
#     ssh -o "StrictHostKeyChecking no" -i $KeyVar $($KubernetesCluster."Admin Username" + "@" + $KubernetesCluster."BackEndPublicIP") kubectl get service
# }

# Configure kubernetes cluster from yaml file over ssh
"scp -o `"StrictHostKeyChecking no`" -i $KeyVar $KubeYamlFile $($KubernetesCluster.`"Admin Username`" + `"@`" + $KubernetesCluster.`"BackEndPublicIP`" + `":/home/$($KubernetesCluster.`"Admin Username`")/$KubeYamlFile`");" | Set-Clipboard
"ssh -o `"StrictHostKeyChecking no`" -i $KeyVar $($KubernetesCluster.`"Admin Username`" + `"@`" + $KubernetesCluster.`"BackEndPublicIP`") docker login $($ContainerRegistry.LoginServer) -u $($ContainerRegistryCreds.Username) --password $($ContainerRegistryCreds.Password) ``&``& docker pull $DockerTag ``&``& kubectl create secret generic regcred --from-file=.dockerconfigjson=/home/$($KubernetesCluster.`"Admin Username`")/.docker/config.json --type=kubernetes.io/dockerconfigjson ``&``& kubectl apply -f $KubeYamlFile" | Set-Clipboard

# Check kubernetes cluster service status
"ssh -o `"StrictHostKeyChecking no`" -i $KeyVar $($KubernetesCluster.`"Admin Username`" + `"@`" + $KubernetesCluster.`"BackEndPublicIP`") kubectl get services" | Set-Clipboard

# Get kubernetes cluster details
$KubernetesCluster = Get-AzsAks -ResourceGroupName $AzsRGName
$KubernetesCluster
while ($KubernetesCluster.FrontEndPublicIp -like "LoadBalancer not deployed") {
    Start-Sleep -Seconds 10
    $KubernetesCluster = Get-AzsAks -ResourceGroupName $AzsRGName
    $KubernetesCluster
}

########### Connect to Public Azure
# Login to Public Azure
Connect-AzureRmAccount -Credential $Cred

########### Add Azure Stack Endpoint to Traffic Manager
try {
    $Endpoint2 = New-AzureRmTrafficManagerEndpoint -Name "AzsKubernetesCluster" -ProfileName $TrafficManagerProfileName -ResourceGroupName $AzureRGName -Priority 2 -Type "ExternalEndpoints" -Target $KubernetesCluster.FrontEndPublicIp -EndpointStatus "Enabled" -Verbose
    $Endpoint2
}
catch {
    Write-Error -Message $_
    break
}

# Print TM Endpoint so we can see it is actually running
$TrafficManagerURL

########### Run automation runbook to swap endpoints
# Get Traffic Manager profile before swap
$TMProfileBefore = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $AzureRGName | Select-Object -ExpandProperty Endpoints | Select-Object -Property Name, ProfileName, Target, EndpointStatus, Priority, EndpointMonitorStatus

# Start automation runbook
try {
    Start-AzureRmAutomationRunbook -Name $AutomationRunbookName -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName
}
catch {
    Write-Error -Message $_
    break
}

# Check automation runbook job status
do {
    $RunbookJob = Get-AzureRmAutomationJob -ResourceGroupName $AzureRGName -AutomationAccountName $AutomationAccountName | Select-Object -First 1
    $RunbookJob | Select-Object -Property AutomationAccountName, Status, ResourceGroupName, JobId
    if ($RunbookJob.Status -notlike "Completed") {
        Start-Sleep -Seconds 5
    }
}
while ($RunbookJob.Status -notlike "Completed")

# Get Traffic Manager profile after swap
$TMProfileAfter = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $AzureRGName | Select-Object -ExpandProperty Endpoints | Select-Object -Property Name, ProfileName, Target, EndpointStatus, Priority, EndpointMonitorStatus

# Show endpoint changes
Write-Output -InputObject "Traffic manager endpoint before:"
$TMProfileBefore | Format-Table -Property Name, Target, Priority
Write-Output -InputObject "Traffic manager endpoint after:"
$TMProfileAfter | Format-Table -Property Name, Target, Priority

# Print TM Endpoint so we can see it is actually running
$TrafficManagerProfile = Get-AzureRmTrafficManagerProfile -Name $TrafficManagerProfileName -ResourceGroupName $AzureRGName
$TrafficManagerURL = "https://$($TrafficManagerProfile.RelativeDnsName)" + ".trafficmanager.net"
$TrafficManagerURL

# Check dns resolution
Start-Sleep -Seconds 10
Resolve-DnsName -Name $($TrafficManagerURL).TrimStart("https://")