function Start-AzsAks {
    <#
    .SYNOPSIS
        Performs pre-requisite checks for using the module.

    .DESCRIPTION
        Check whether OpenSSH Client (Required for this module to interact with the Kubernetes Cluster) is installed and if not will install it.
        Also checks if the user is logged into Azure Stack and will log them in if not.

    .PARAMETER ArmEndpoint
        The ARM endpoint for the Azure Stack endpoint you are logging into. Defaults to: "https://management.frn00006.azure.ukcloud.com"

    .EXAMPLE
        Start-AzsAks
    
    .EXAMPLE
        Start-AzsAks -ArmEndpoint "https://management.frn00006.azure.ukcloud.com"
    
    .NOTES
        This command requires administrator privileges to check for/install OpenSSH Client. Without these privileges this step will be skipped.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ArmEndpoint = "https://management.frn00006.azure.ukcloud.com"
    )
    process {
        try {
            $CheckForSSH = Get-WindowsCapability -Online | Where-Object {$_.Name -like '*OpenSSH*' -and $_.Name -like "*Client*"}
            if ($CheckForSSH.State -notlike "*Installed*") {
                Add-WindowsCapability -Online -Name $CheckForSSH.Name
            }
        } catch {
            Write-Host "Not executing as administrator, unable to check if OpenSSH is installed" -ForegroundColor Red
        }   
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                $UserCredentials = Get-Credential
                Add-AzureRmEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint
                Connect-AzureRmAccount -EnvironmentName "AzureStackUser" -Credential $UserCredentials
            }
        }
    }
}


function Get-AzsAksCredentials {
    <#
    .SYNOPSIS
        Gets access credentials for a Kubernetes cluster.

    .DESCRIPTION
        Gets access credentials for a Kubernetes cluster. Mimics the Azure CLI command: az aks get-credentials

    .PARAMETER PrivateKeyLocation
        The local file path to the private SSH key for the Kubernetes cluster. Example: "C:\AzureStack\KuberenetesKey.ppk"

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Example: "AKS-RG"

    .PARAMETER OutFile
        The output file to save the access credential information to. Defaults to "Config"
    
    .EXAMPLE
        Get-AzsAksCredentials -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -ResourceGroupName "AKS-RG"
    
    .EXAMPLE
        Get-AzsAksCredentials -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -ResourceGroupName "AKS-RG" -OutFile "Config"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-get-credentials
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [String]$PrivateKeyLocation,
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [parameter(Mandatory = $false)]
        [String]$OutFile = "Config"
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*master*"}).IpAddress
        $MasterNodes = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*master*"}
        $Username = $MasterNodes[0].OSProfile.AdminUsername
        Invoke-Command -ScriptBlock {param($PrivateKeyLocation, $Username, $IPAddress, $OutFile) ssh -i $PrivateKeyLocation $Username@$IPAddress kubectl config view --flatten | Out-File $OutFile} -ArgumentList $PrivateKeyLocation, $Username, $IPAddress, $OutFile
    }
}


function New-AzsAks {
    <#
    .SYNOPSIS
        Create a new Kubernetes cluster.

    .DESCRIPTION
        Create a new Kubernetes cluster from template. Mimics the Azure CLI command: az aks create

    .PARAMETER DeploymentName
        The name of the resource group deployment within Azure Stack. Defaults to: "AKSClusterDeployment"

    .PARAMETER ResourceGroupName
        The name of the resource group to create for the Kubernetes cluster. Example: "AKS-RG"

    .PARAMETER Location
        The location to create the Kubernetes cluster in. Defaults to: "frn00006"
    
    .PARAMETER SSHKeyPath
        The file path of the public SSH key to create the Kubernetes cluster with. Example: "C:\AzureStack\KuberenetesKey.pub"
    
    .PARAMETER AdminUsername
        The administrator username for the Kubernetes cluster. Defaults to: "azureuser"

    .PARAMETER DNSPrefix
        Prefix for hostnames that are created. Example: "examplednsprefix"
    
    .PARAMETER ServicePrincipal
        The application ID of a service principal with contributor permissions on Azure Stack. Example: "00000000-0000-0000-0000-000000000000"
    
    .PARAMETER ClientSecret
        A secret of the service principal specified in the ServicePrincipal parameter. Example: "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]="

    .PARAMETER AgentPoolProfileCount
        The number of nodes in the Kubernetes agent node pool. Defaults to 3.

    .PARAMETER AgentPoolProfileVMSize
        The VM size of the nodes in the Kubernetes agent node pool. Defaults to "Standard_D2_v2"
    
    .PARAMETER MasterPoolProfileCount
        The number of nodes in the Kubernetes master node pool. Defaults to 3.
    
    .PARAMETER MasterPoolProfileVMSize
        The VM size of the nodes in the Kubernetes master node pool. Defaults to "Standard_D2_v2"
    
    .PARAMETER StorageProfile
        The type of storage to use. Can be either "blobdisk" for storage accounts, or "manageddisk" for managed disks. Defaults to "manageddisk"
    
    .PARAMETER KubernetesAzureCloudProviderVersion
        The version of kubernetes to use for creating the cluster. Run Get-AzsAksVersions to list available versions. Defaults to the latest version

    .EXAMPLE
        New-AzsAks -ResourceGroupName "AKS-RG" -SSHKeyPath "C:\AzureStack\KuberenetesKey.pub" `
            -ServicePrincipal "00000000-0000-0000-0000-000000000000" -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" `
            -storageProfile "blobdisk"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create

    .LINK
        https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-solution-template-kubernetes-azuread
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)]
        [String]$DeploymentName = "AKSClusterDeployment",
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [parameter(Mandatory = $false)]
        [String]$Location = "frn00006",
        [parameter(Mandatory = $true)]
        [String]$SSHKeyPath,
        [parameter(Mandatory = $false)]
        [String]$AdminUsername = "azureuser",
        [parameter(Mandatory = $false)]
        [String]$DNSPrefix,
        [parameter(Mandatory = $true)]
        [String]$ServicePrincipal,
        [parameter(Mandatory = $true)]
        [String]$ClientSecret,
        [parameter(Mandatory = $false)]
        [int]$AgentPoolProfileCount = 3,
        [parameter(Mandatory = $false)]
        [String]$AgentPoolProfileVMSize = "Standard_D2_v2",
        [parameter(Mandatory = $false)]
        [int]$MasterPoolProfileCount = 3,
        [parameter(Mandatory = $false)]
        [String]$MasterPoolProfileVMSize = "Standard_D2_v2",
        [parameter(Mandatory = $false)]
        [ValidateSet("blobdisk", "manageddisk")]
        [String]$StorageProfile = "manageddisk",
        [parameter(Mandatory = $false)]
        [ValidateSet("1.7", "1.8", "1.9", "1.10", "1.11")]
        [String]$KubernetesAzureCloudProviderVersion = "1.11"
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        $ServicePrincipalSecure = ConvertTo-SecureString $ServicePrincipal -AsPlainText -Force
        $ClientSecretSecure = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $KubernetesTemplateURI = "https://portal.frn00006.azure.ukcloud.com:30015//artifact/20161101/Microsoft.AzureStackKubernetesCluster.0.3.0/DeploymentTemplates/azuredeploy.json"
        $SSHKey = Get-Content -Path $SSHKeyPath -Raw
        if (!$DNSPrefix) {
            $DNSPrefix = $ResourceGroupName.tolower()
        }

        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location
        New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $KubernetesTemplateURI -sshPublicKey $SSHKey -masterProfileDnsPrefix $DNSPrefix `
            -servicePrincipalClientId $ServicePrincipalSecure -servicePrincipalClientSecret $ClientSecretSecure -agentPoolProfileCount $AgentPoolProfileCount -agentPoolProfileVMSize $AgentPoolProfileVMSize `
            -masterPoolProfileCount $MasterPoolProfileCount -masterPoolProfileVMSize $MasterPoolProfileVMSize -storageProfile $StorageProfile -kubernetesAzureCloudProviderVersion $KubernetesAzureCloudProviderVersion -Verbose

    }
}


function Remove-AzsAks {
    <#
    .SYNOPSIS
        Deletes a Kubernetes cluster.

    .DESCRIPTION
        Deletes a Kubernetes cluster. Mimics the Azure CLI command: az aks delete

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Example: "AKS-RG"
    
    .EXAMPLE
        Remove-AzsAks -ResourceGroupName "AKS-RG"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
        This cmdlet will erase the entire resource group which the cluster is in. Use at your own risk.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-delete
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force -Verbose
        Write-Host "Kubernetes cluster in $($ResourceGroupName) has been deleted"
    }
}


function Get-AzsAks {
    <#
    .SYNOPSIS
        Lists all Kubernetes clusters in the current subscription.

    .DESCRIPTION
        Lists all Kubernetes clusters in the current subscription. Mimics the Azure CLI command: az aks list

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Used when looking for a specific cluster. Example: "AKS-RG"
    
    .EXAMPLE
        Get-AzsAks

    .EXAMPLE
        Get-AzsAks -ResourceGroupName "AKS-RG"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-list
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, DontShow = $true)]
        [String]$ResourceGroupName
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        if ($ResourceGroupName) {
            $FirstMasterVMs = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "k8s-master*" -and $_.Name -like "*0"}
        } else {
            $FirstMasterVMs = Get-AzureRmVM | Where-Object {$_.Name -like "k8s-master*" -and $_.Name -like "*0"}
        }
        $ArrayOfClusters = @()
        foreach ($VM in $FirstMasterVMs) {
            $PoolVMs = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName | Where-Object {$_.Name -like "*k8s*" -and $_.Name -notlike "*master*"}
            $PoolName = (($PoolVMs[0].Name).Split("-"))[1]
            $MasterVMs = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName | Where-Object {$_.Name -like "*k8s*" -and $_.Name -like "*master*"}
            $CreationVM = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName | Where-Object {$_.Name -like "vmd*"}
            $DNSName = (Get-AzureRmPublicIpAddress -ResourceGroupName $VM.ResourceGroupName | Where-Object {$_.Name -like "k8s*"}).IpAddress
            $KubernetesDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $VM.ResourceGroupName | Where-Object {$_.TemplateLink}
            $KubernetesCluster = [PSCustomObject]@{
                "Resource group"         = $VM.ResourceGroupName
                "Kubernetes version"     = $VM.Tags.orchestrator
                "ACS engine version"     = $VM.Tags.acsengineVersion
                "Deployment Timestamp"   = $KubernetesDeployment.Timestamp
                "Number of Master nodes" = $MasterVMs.Count
                "Number of Slave nodes"  = $PoolVMs.Count
                "Master node VM size"    = $KubernetesDeployment.Parameters.masterPoolProfileVMSize.Value
                "Slave node VM size"     = $KubernetesDeployment.Parameters.agentPoolProfileVMSize.Value
                "Slave pool name"        = $PoolName
                "Storage Type"           = $KubernetesDeployment.Parameters.storageProfile.Value
                "Admin Username"         = $KubernetesDeployment.Parameters.linuxAdminUsername.Value
                "FQDN"                   = $DNSName.DnsSettings.Fqdn
                "Creation VM Name"       = $CreationVM.Name
            }
            $ArrayOfClusters += $KubernetesCluster
        }
        $ArrayOfClusters
    }
}


function Start-AzsAksScale {
    <#
    .SYNOPSIS
        Scales the node pool of a Kubernetes cluster horizontally.

    .DESCRIPTION
        Scales the node pool of a Kubernetes cluster horizontally. Can be used to scale up or down. Mimics the Azure CLI command: az aks scale

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Example: "AKS-RG"

    .PARAMETER PrivateKeyLocation
        The local file path to the private SSH key for the Kubernetes cluster. Example: "C:\AzureStack\KuberenetesKey.ppk"

    .PARAMETER Location
        The location which the Kubernetes cluster is in. Defaults to: "frn00006"

    .PARAMETER ServicePrincipal
        The application ID of a service principal with contributor permissions on Azure Stack. Example: "00000000-0000-0000-0000-000000000000"
    
    .PARAMETER ClientSecret
        A secret of the service principal specified in the ServicePrincipal parameter. Example: "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]="

    .PARAMETER NewNodeCount
        The number of nodes to scale the node pool to. Example: "5"

    .PARAMETER PoolName
        The name of the node pool to scale. Defaults to "linuxpool2"

    .EXAMPLE
        Start-AzsAksScale -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -ServicePrincipal "00000000-0000-0000-0000-000000000000" `
            -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -NewNodeCount 5
    
    .EXAMPLE
        Start-AzsAksScale -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -Location "frn00006" -ServicePrincipal "00000000-0000-0000-0000-000000000000" `
            -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -NewNodeCount 5 -PoolName "linuxpool2"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-scale
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [parameter(Mandatory = $true)]
        [String]$PrivateKeyLocation,
        [parameter(Mandatory = $false)]
        [String]$Location = "frn00006",
        [parameter(Mandatory = $true)]
        [String]$ServicePrincipal,
        [parameter(Mandatory = $true)]
        [String]$ClientSecret,
        [parameter(Mandatory = $true)]
        [int]$NewNodeCount,
        [parameter(Mandatory = $false)]
        [string]$PoolName = "linuxpool2"
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        $CreationVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -notlike "*k8s*"}
        $ResourceNameSuffix = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*k8s*" -and $_.Name -notlike "*master*"})[0].Tags["resourceNameSuffix"]
        $Tags = $CreationVM.Tags
        if (!$Tags["poolName"]) {
            $Tags += @{poolName = "CreationVM"}
        }
        if (!$Tags["resourceNameSuffix"]) {
            $Tags += @{resourceNameSuffix = $ResourceNameSuffix} 
        }
        $CreationVM.Plan = @{"name" = " "}
        $CreationVM | Set-AzureRmResource -Tag $Rags -Force | Out-Null
        $MasterFQDN = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*master*"}).DnsSettings.Fqdn
        $Username = $CreationVM.OSProfile.AdminUsername
        $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "vmd*"}).IpAddress
        $ScaleCommand = "/var/lib/waagent/custom-script/download/0/acs-engine/bin/acs-engine scale"
        $SubscriptionID = (Get-AzureRmContext).Subscription.Id
        $DeploymentDirectory = "/var/lib/waagent/custom-script/download/0/acs-engine/_output/" + $MasterFQDN.Split(".")[0]
        Invoke-Command -ScriptBlock {
            param($PrivateKeyLocation, $Username, $IPAddress, $ScaleCommand, $ResourceGroupName, $Location, $ServicePrincipal, $ClientSecret, $SubscriptionID, $NewNodeCount, $DeploymentDirectory, $MasterFQDN, $PoolName) 
            ssh -i $PrivateKeyLocation $Username@$IPAddress sudo $ScaleCommand --resource-group $ResourceGroupName --auth-method client_secret --azure-env AzureStackCloud --location $Location --client-id $ServicePrincipal `
                --client-secret $ClientSecret --subscription-id $SubscriptionID --new-node-count $NewNodeCount --deployment-dir $DeploymentDirectory --master-FQDN $MasterFQDN --node-pool $PoolName
        } -ArgumentList $PrivateKeyLocation, $Username, $IPAddress, $ScaleCommand, $ResourceGroupName, $Location, $ServicePrincipal, $ClientSecret, $SubscriptionID, $NewNodeCount, $DeploymentDirectory, $MasterFQDN, $PoolName

        # Actual clean-up as the command (sometimes, completely at random) can't do it
        $PoolVMs = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*$PoolName*"}
        $PoolNICs = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*$PoolName*"}
        if (!!$PoolVMs[0].StorageProfile.OsDisk.ManagedDisk) {
            foreach ($MDID in $PoolVMs.StorageProfile.OsDisk.ManagedDisk.Id) {
                $NodeNumber = [convert]::ToInt32(($MDID.Split("-")[-1][0]), 10)
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
}


function Show-AzsAks {
    <#
    .SYNOPSIS
        Shows the details for a specific Kubernetes cluster.

    .DESCRIPTION
        Shows the details for a specific Kubernetes cluster. Mimics the Azure CLI command: az aks show

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Example: "AKS-RG"

    .EXAMPLE
        Show-AzsAks -ResourceGroupName "AKS-RG"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-show
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName
    )

    process {
        Get-AzsAks -ResourceGroupName $ResourceGroupName
    }
}


function Get-AzsAksVersions {
    <#
    .SYNOPSIS
        Get the versions available for creating a Kubernetes cluster. 

    .DESCRIPTION
        Get the versions available for creating a Kubernetes cluster. Mimics the Azure CLI command: az aks get-versions

    .EXAMPLE
        Get-AzsAksVersions
    
    .NOTES
        This cmdlet can only be run a limited amount of times per hour, due to GitHub Rate Limits. See links for details.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-get-versions

    .Link
        https://developer.github.com/apps/building-github-apps/understanding-rate-limits-for-github-apps/
    #>

    process {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $URL = "https://api.github.com/repos/msazurestackworkloads/acs-engine/contents/examples/azurestack"
        $Branch = @{"ref" = "acs-engine-v0209-1809"}
        $GitHubFiles = (Invoke-WebRequest -URI $URL -Body $Branch -Method GET -UseBasicParsing | ConvertFrom-Json).name | Where-Object {$_ -like "*kubernetes*"}
        $Versions = @()
        foreach ($Filename in $GitHubFiles) {
            $VersionNum = [PSCustomObject] @{
                VersionNumber = $Filename.Replace(".json", "").Replace("azurestack-kubernetes", "")
            }
            $Versions += $VersionNum
        }
        $Versions = $Versions | Sort-Object -Property @{Expression = {[convert]::ToInt32(($_.VersionNumber -split "\.")[-1])}} 
        $Versions
    }
}


function Start-AzsAksUpgrade {
    <#
    .SYNOPSIS
        Upgrade a Kubernetes cluster to a newer version.

    .DESCRIPTION
        Upgrade a Kubernetes cluster to a newer version. Mimics the Azure CLI command: az aks upgrade

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Example: "AKS-RG"

    .PARAMETER PrivateKeyLocation
        The local file path to the private SSH key for the Kubernetes cluster. Example: "C:\AzureStack\KuberenetesKey.ppk"

    .PARAMETER Location
        The location which the Kubernetes cluster is in. Defaults to: "frn00006"

    .PARAMETER ServicePrincipal
        The application ID of a service principal with contributor permissions on Azure Stack. Example: "00000000-0000-0000-0000-000000000000"
    
    .PARAMETER ClientSecret
        A secret of the service principal specified in the ServicePrincipal parameter. Example: "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]="

    .PARAMETER KubernetesUpgradeVersion
        The version of Kubernetes to upgrade the cluster to. Available versions can be found using Get-AzsAksUpgradeVersions. Example: "1.11.2"

    .EXAMPLE
        Start-AzsAksUpgrade -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -ServicePrincipal "00000000-0000-0000-0000-000000000000" `
            -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -KubernetesUpgradeVersion "1.11.2"
    
    .EXAMPLE
        Start-AzsAksUpgrade -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -Location "frn00006" -ServicePrincipal "00000000-0000-0000-0000-000000000000" `
            -ClientSecret "ftE2u]iVLs_J4+i-:q^Ltf4!&{!w3-%=3%4+}F2jk|]=" -KubernetesUpgradeVersion "1.11.2"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-upgrade
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [parameter(Mandatory = $true)]
        [String]$PrivateKeyLocation,
        [parameter(Mandatory = $false)]
        [String]$Location = "frn00006",
        [parameter(Mandatory = $true)]
        [String]$ServicePrincipal,
        [parameter(Mandatory = $true)]
        [String]$ClientSecret,
        [parameter(Mandatory = $true)]
        [String]$KubernetesUpgradeVersion
    )

    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        } catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }

    process {
        $CreationVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "vmd*"}
        $ResourceNameSuffix = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*k8s*" -and $_.Name -notlike "*master*"})[0].Tags["resourceNameSuffix"]
        $Tags = $CreationVM.Tags
        if (!$tags["poolName"]) {
            $Tags += @{poolName = "CreationVM"}
        }
        if (!$tags["resourceNameSuffix"]) {
            $Tags += @{resourceNameSuffix = $ResourceNameSuffix} 
        }
        $CreationVM.Plan = @{"name" = " "}
        $CreationVM | Set-AzureRmResource -Tag $Tags -Force | Out-Null
        $MasterFQDN = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*master*"}).DnsSettings.Fqdn
        $Username = $CreationVM.OSProfile.AdminUsername
        $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "vmd*"}).IpAddress
        $ScaleCommand = "/var/lib/waagent/custom-script/download/0/acs-engine/bin/acs-engine upgrade"
        $SubscriptionID = (Get-AzureRmContext).Subscription.Id
        $DeploymentDirectory = "/var/lib/waagent/custom-script/download/0/acs-engine/_output/" + $MasterFQDN.Split(".")[0]
        $CurrentVersion = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "*k8s*" -and $_.Name -like "*master*"})[0].Tags["orchestrator"].Split(":")[1]
        if ($CurrentVersion -eq $KubernetesUpgradeVersion) {
            Write-Host "Can't upgrade Kubernetes version - Cluster is already running version $CurrentVersion" -ForegroundColor Red
        } else {
            Invoke-Command -ScriptBlock {
                param($PrivateKeyLocation, $Username, $IPAddress, $ScaleCommand, $ResourceGroupName, $Location, $ServicePrincipal, $ClientSecret, $SubscriptionID, $DeploymentDirectory, $MasterFQDN, $KubernetesAzureCloudProviderVersion) 
                ssh -i $PrivateKeyLocation $Username@$IPAddress sudo $ScaleCommand --resource-group $ResourceGroupName --auth-method client_secret --azure-env AzureStackCloud --location $Location --client-id $ServicePrincipal `
                    --client-secret $ClientSecret --subscription-id $SubscriptionID --deployment-dir $DeploymentDirectory --master-FQDN $MasterFQDN --upgrade-version $KubernetesAzureCloudProviderVersion
            } -ArgumentList $PrivateKeyLocation, $Username, $IPAddress, $ScaleCommand, $ResourceGroupName, $Location, $ServicePrincipal, $ClientSecret, $SubscriptionID, $DeploymentDirectory, $MasterFQDN, $KubernetesAzureCloudProviderVersion
        }
    }
}


function Get-AzsAksUpgradeVersions {
    <#
    .SYNOPSIS
        Get the upgrade versions available for a Kubernetes cluster.

    .DESCRIPTION
        Get the upgrade versions available for a Kubernetes cluster. Mimics the Azure CLI command: az aks get-upgrades

    .PARAMETER ResourceGroupName
        The name of the resource group which the Kubernetes cluster is in. Example: "AKS-RG"

    .PARAMETER PrivateKeyLocation
        The local file path to the private SSH key for the Kubernetes cluster. Example: "C:\AzureStack\KuberenetesKey.ppk"

    .PARAMETER Location
        The location which the Kubernetes cluster is in. Defaults to: "frn00006"

    .EXAMPLE
        Get-AzsAksUpgradeVersions -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk"
    
    .EXAMPLE
        Get-AzsAksUpgradeVersions -ResourceGroupName "AKS-RG" -PrivateKeyLocation "C:\AzureStack\KuberenetesKey.ppk" -Location "frn00006"
    
    .NOTES
        This cmdlet requires you to be logged into Azure Stack to run successfully.
    
    .LINK
        https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-get-upgrades
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [parameter(Mandatory = $true)]
        [String]$PrivateKeyLocation,
        [parameter(Mandatory = $false)]
        [String]$Location = "frn00006"
    )

    process {
        $CreationVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "vmd*"}
        $IPAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "vmd*"}).IpAddress
        $Username = $CreationVM.OSProfile.AdminUsername
        $FirstMasterVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName | Where-Object {$_.Name -like "k8s-master*" -and $_.Name -like "*0"}
        $CurrentVersion = $FirstMasterVM.Tags["orchestrator"].Split(":")[1]
        $Command = "/var/lib/waagent/custom-script/download/0/acs-engine/bin/acs-engine orchestrators"
        Write-Host "Current Kubernetes version is: $CurrentVersion" -ForegroundColor Green
        Invoke-Command -ScriptBlock {
            param($PrivateKeyLocation, $Username, $IPAddress, $Command, $CurrentVersion) 
            ssh -i $PrivateKeyLocation $Username@$IPAddress sudo $Command --orchestrator kubernetes --version $CurrentVersion
        } -ArgumentList $PrivateKeyLocation, $Username, $IPAddress, $Command, $CurrentVersion
    }
}