function Start-az-aks {
    try {
        $CheckForSSH = Get-WindowsCapability -Online | Where-Object {$_.Name -like '*OpenSSH*' -and $_.Name -like "*Client*"}
        if ($CheckForSSH.State -notlike "*Installed*"){
            Add-WindowsCapability -Online -Name $CheckForSSH.Name
        }
    } 
    catch {
        Write-Host "Not executing as administrator, unable to check if OpenSSH is installed" -ForegroundColor Red
    }    
    $Cred = Get-Credential
    Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint 'https://management.frn00006.azure.ukcloud.com'
    Login-AzureRmAccount -EnvironmentName "AzureStackUser" -Credential $Cred
}


function az-aks-Get-Credentials {
    param(
        [parameter(Mandatory=$true)][String]$PrivateKeyLocation,
        [parameter(Mandatory=$true)][String]$ResourceGroupName,
        [parameter(Mandatory=$false)][String]$OutFile = "config"
    )
    $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where {$_.Name -like "*master*"}).IpAddress
    $MasterNodes = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where {$_.Name -like "*master*"}
    $Username = $MasterNodes[0].OSProfile.AdminUsername
    Invoke-Command -ScriptBlock {param($PrivateKeyLocation, $Username, $IPAddress, $OutFile) ssh -i $PrivateKeyLocation $Username@$IPAddress kubectl config view --flatten | Out-File $OutFile} -ArgumentList $PrivateKeyLocation,$Username,$IPAddress,$OutFile
}


function az-aks-create {
    param(
        [parameter(Mandatory=$false)][String]$DeploymentName = "AKSClusterDeployment",
        [parameter(Mandatory=$true)][String]$ResourceGroupName,
        [parameter(Mandatory=$false)][String]$Location = "frn00006",
        [parameter(Mandatory=$true)][String]$SSHKeyPath,
        [parameter(Mandatory=$false)][String]$AdminUsername = "azureuser",
        [parameter(Mandatory=$false)][String]$DNSNamePrefix,
        [parameter(Mandatory=$true)][String]$ServicePrincipal,
        [parameter(Mandatory=$true)][String]$ClientSecret,
        [parameter(Mandatory=$false)][int]$AgentPoolProfileCount = 3,
        [parameter(Mandatory=$false)][String]$AgentPoolProfileVMSize = "Standard_D2_v2",
        [parameter(Mandatory=$false)][int]$MasterPoolProfileCount = 3,
        [parameter(Mandatory=$false)][String]$MasterPoolProfileVMSize = "Standard_D2_v2",
        [parameter(Mandatory=$false)][ValidateSet("blobdisk", "manageddisk")][String]$StorageProfile = "manageddisk",
        [parameter(Mandatory=$false)][ValidateSet("1.7", "1.8", "1.9", "1.10", "1.11")][String]$KubernetesAzureCloudProviderVersion = "1.11"
    )

    $ServicePrincipalSecure = ConvertTo-SecureString $ServicePrincipal -AsPlainText -Force
    $ClientSecretSecure = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $KubernetesTemplateURI = "https://portal.frn00006.azure.ukcloud.com:30015//artifact/20161101/Microsoft.AzureStackKubernetesCluster.0.3.0/DeploymentTemplates/azuredeploy.json"
    $SSHKey = Get-Content -Path $SSHKeyPath -Raw
    if (!$DNSNamePrefix) {
        $DNSNamePrefix = $ResourceGroupName.tolower()
    }

    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location
    New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $KubernetesTemplateURI -sshPublicKey $SSHKey -masterProfileDnsPrefix $DNSNamePrefix `
        -servicePrincipalClientId $ServicePrincipalSecure -servicePrincipalClientSecret $ClientSecretSecure -agentPoolProfileCount $AgentPoolProfileCount -agentPoolProfileVMSize $AgentPoolProfileVMSize `
        -masterPoolProfileCount $MasterPoolProfileCount -masterPoolProfileVMSize $MasterPoolProfileVMSize -storageProfile $StorageProfile -kubernetesAzureCloudProviderVersion $KubernetesAzureCloudProviderVersion -Verbose
}


function az-aks-delete {
    param(
        [parameter(Mandatory=$true)][String]$ResourceGroupName
    )
    Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force -Verbose
    Write-Host "Kubernetes cluster in $($ResourceGroupName) has been deleted"
}


function az-aks-list {
    param(
        [parameter(Mandatory=$false,DontShow=$true)][String]$ResourceGroupName
    )
    if ($ResourceGroupName) {
        $FirstMasterVMs = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | where {$_.Name -like "k8s-master*" -and $_.Name -like "*0"}
    }
    else {
        $FirstMasterVMs = Get-AzureRmVM | where {$_.Name -like "k8s-master*" -and $_.Name -like "*0"}
    }
    $ArrayOfClusters = @()
    ForEach ($VM in $FirstMasterVMs) {
        $ResourceGroup = $VM.ResourceGroupName
        $PoolVMs = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName | where {$_.Name -like "*k8s*" -and $_.Name -notlike "*master*"}
        $PoolName = (($PoolVMs[0].Name).Split("-"))[1]
        $MasterVMs = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName | where {$_.Name -like "*k8s*" -and $_.Name -like "*master*"}
        $CreationVM = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName | where {$_.Name -notlike "*k8s*"}
        $KubernetesDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroup | where {$_.TemplateLink}
        $KubernetesCluster = [PSCustomObject]@{
            "Resource group" = $VM.ResourceGroupName
            "Kubernetes version" = $VM.Tags.orchestrator
            "ACS engine version" = $VM.Tags.acsengineVersion
            "Deployment Timestamp" = $KubernetesDeployment.Timestamp
            "Number of Master nodes" = $MasterVMs.Count
            "Number of Slave nodes" = $PoolVMs.Count
            "Master node VM size" = $KubernetesDeployment.Parameters.masterPoolProfileVMSize.Value
            "Slave node VM size" = $KubernetesDeployment.Parameters.agentPoolProfileVMSize.Value
            "Slave pool name" = $PoolName
            "Storage Type" = $KubernetesDeployment.Parameters.storageProfile.Value
            "Admin Username" = $KubernetesDeployment.Parameters.linuxAdminUsername.Value
            "DNS Prefix" = $KubernetesDeployment.Parameters.masterProfileDnsPrefix.Value
            "Creation VM Name" = $CreationVM.Name
        }
        $ArrayOfClusters += $KubernetesCluster
    }
    $ArrayOfClusters
}


function az-aks-scale {
    param(
        [parameter(Mandatory=$true)][String]$ResourceGroupName,
        [parameter(Mandatory=$true)][String]$PrivateKeyLocation,
        [parameter(Mandatory=$false)][String]$Location = "frn00006",
        [parameter(Mandatory=$true)][String]$ServicePrincipal,
        [parameter(Mandatory=$true)][String]$ClientSecret,
        [parameter(Mandatory=$true)][int]$NewNodeCount,
        [parameter(Mandatory=$false)][string]$PoolName = "linuxpool2"
    )

    $CreationVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | where {$_.Name -notlike "*k8s*"}
    $resourceNameSuffix = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName | where {$_.Name -like "*k8s*" -and $_.Name -notlike "*master*"})[0].Tags["resourceNameSuffix"]
    $tags = $CreationVM.Tags
    if (!$tags["poolName"]) {
        $tags += @{poolName="CreationVM"}
    }
    if (!$tags["resourceNameSuffix"]) {
        $tags += @{resourceNameSuffix=$resourceNameSuffix} 
    }
    $CreationVM.Plan = @{"name"=" "}
    $CreationVM | Set-AzureRmResource -Tag $tags -Force | Out-Null
    $MasterFQDN = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where {$_.Name -like "*master*"}).DnsSettings.Fqdn
    $Username = $CreationVM.OSProfile.AdminUsername
    $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where {$_.Name -notlike "*k8s*"}).IpAddress
    $ScaleCommand = "/var/lib/waagent/custom-script/download/0/acs-engine/bin/acs-engine scale"
    $SubscriptionID = (Get-AzureRmContext).Subscription.Id
    $DeploymentDirectory = "/var/lib/waagent/custom-script/download/0/acs-engine/_output/" + $MasterFQDN.Split(".")[0]
    Invoke-Command -ScriptBlock {
        param($PrivateKeyLocation, $Username, $IPAddress, $ScaleCommand, $ResourceGroupName, $Location, $ServicePrincipal, $ClientSecret, $SubscriptionID, $NewNodeCount, $DeploymentDirectory, $MasterFQDN, $PoolName) 
        ssh -i $PrivateKeyLocation $Username@$IPAddress sudo $ScaleCommand --resource-group $ResourceGroupName --auth-method client_secret --azure-env AzureStackCloud --location $Location --client-id $ServicePrincipal `
        --client-secret $ClientSecret --subscription-id $SubscriptionID --new-node-count $NewNodeCount --deployment-dir $DeploymentDirectory --master-FQDN $MasterFQDN --node-pool $PoolName
    } -ArgumentList $PrivateKeyLocation,$Username,$IPAddress,$ScaleCommand,$ResourceGroupName,$Location,$ServicePrincipal,$ClientSecret,$SubscriptionID,$NewNodeCount,$DeploymentDirectory,$MasterFQDN,$PoolName

    # Actual clean-up as the command (sometimes, completely at random) can't do it

    $PoolVMs = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | where {$_.Name -like "*$PoolName*"}
    $PoolNICs = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName | where {$_.Name -like "*$PoolName*"}
    if (!!$PoolVMs[0].StorageProfile.OsDisk.ManagedDisk) {
        foreach ($MDID in $PoolVMs.StorageProfile.OsDisk.ManagedDisk.Id) {
            $NodeNumber = [convert]::ToInt32(($MDID.Split("-")[-1][0]),10)
            if ($NodeNumber -ge $NewNodeCount) {
                Remove-AzureRmResource -ResourceId $MDID
            }
        }
    }
    foreach ($NICID in $PoolNICs.Id) {
        if ($PoolVMs.NetworkProfile.NetworkInterfaces.Id -notcontains $NICID) {
            Remove-AzureRmResource -ResourceId $NICID
        }
    }
}


function az-aks-show {
    param(
        [parameter(Mandatory=$true)][String]$ResourceGroupName
    )
    az-aks-list -ResourceGroupName $ResourceGroupName
}


function az-aks-Get-Versions {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $URL = "https://api.github.com/repos/msazurestackworkloads/acs-engine/contents/examples/azurestack"
    $Branch = @{"ref"="acs-engine-v0209-1809"}
    $GitHubFiles = (Invoke-WebRequest -URI $URL -Body $Branch -Method GET -UseBasicParsing | ConvertFrom-Json).name | Where {$_ -like "*kubernetes*"}
    $Versions = @()
    ForEach ($Filename in $GitHubFiles) {
        $VersionNum = [PSCustomObject] @{
            VersionNumber = $Filename.Replace(".json","").Replace("azurestack-kubernetes","")
        }
        $Versions += $VersionNum
    }
    $Versions = $Versions | Sort-Object -Property @{Expression={[convert]::ToInt32(($_.VersionNumber -split "\.")[-1])}} 
    $Versions
}


function az-aks-upgrade {
    param(
        [parameter(Mandatory=$true)][String]$ResourceGroupName,
        [parameter(Mandatory=$true)][String]$PrivateKeyLocation,
        [parameter(Mandatory=$false)][String]$Location = "frn00006",
        [parameter(Mandatory=$true)][String]$ServicePrincipal,
        [parameter(Mandatory=$true)][String]$ClientSecret,
        [parameter(Mandatory=$true)][ValidateSet("1.7", "1.8", "1.9", "1.10", "1.11")][String]$KubernetesAzureCloudProviderVersion
    )

    $CreationVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | where {$_.Name -notlike "*k8s*"}
    $resourceNameSuffix = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName | where {$_.Name -like "*k8s*" -and $_.Name -notlike "*master*"})[0].Tags["resourceNameSuffix"]
    $tags = $CreationVM.Tags
    if (!$tags["poolName"]) {
        $tags += @{poolName="CreationVM"}
    }
    if (!$tags["resourceNameSuffix"]) {
        $tags += @{resourceNameSuffix=$resourceNameSuffix} 
    }
    $CreationVM.Plan = @{"name"=" "}
    $CreationVM | Set-AzureRmResource -Tag $tags -Force | Out-Null
    $MasterFQDN = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where {$_.Name -like "*master*"}).DnsSettings.Fqdn
    $Username = $CreationVM.OSProfile.AdminUsername
    $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where {$_.Name -notlike "*k8s*"}).IpAddress
    $ScaleCommand = "/var/lib/waagent/custom-script/download/0/acs-engine/bin/acs-engine upgrade"
    $SubscriptionID = (Get-AzureRmContext).Subscription.Id
    $DeploymentDirectory = "/var/lib/waagent/custom-script/download/0/acs-engine/_output/" + $MasterFQDN.Split(".")[0]
    Invoke-Command -ScriptBlock {
        param($PrivateKeyLocation, $Username, $IPAddress, $ScaleCommand, $ResourceGroupName, $Location, $ServicePrincipal, $ClientSecret, $SubscriptionID, $DeploymentDirectory, $MasterFQDN, $KubernetesAzureCloudProviderVersion) 
        ssh -i $PrivateKeyLocation $Username@$IPAddress sudo $ScaleCommand --resource-group $ResourceGroupName --auth-method client_secret --azure-env AzureStackCloud --location $Location --client-id $ServicePrincipal `
        --client-secret $ClientSecret --subscription-id $SubscriptionID --deployment-dir $DeploymentDirectory --master-FQDN $MasterFQDN --upgrade-version $KubernetesAzureCloudProviderVersion
    } -ArgumentList $PrivateKeyLocation,$Username,$IPAddress,$ScaleCommand,$ResourceGroupName,$Location,$ServicePrincipal,$ClientSecret,$SubscriptionID,$DeploymentDirectory,$MasterFQDN,$KubernetesAzureCloudProviderVersion
}