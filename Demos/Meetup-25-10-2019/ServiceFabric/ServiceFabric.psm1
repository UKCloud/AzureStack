function New-AzsKeyVault { 
    <#
    .SYNOPSIS
        Create a new key vault in Azure Stack.

    .PARAMETER ResourceGroupName
        The name of the resource group to create for the key vault.

    .PARAMETER Location
        The location to create the key vault in. Defaults to: "frn00006".

    .PARAMETER VaultName
        The name of the key vault to create within the resource group. 

    .EXAMPLE 
        New-AzsKeyVault -ResourceGroupName "TestSFCKV" -VaultName "TestSFVault"
    
    .EXAMPLE
        New-AzsKeyVault -ResourceGroupName "TestSFCKV" -VaultName "TestSFVault" -Location "frn00006"

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceGroupName, 

        [Parameter(Mandatory = $false)]
        [String]
        $Location = "frn00006",

        [Parameter(Mandatory = $true)]
        [String]
        $VaultName
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as a user.
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://adminmanagement*" -or $Context.Environment.ResourceManagerUrl -like "*azure.com*" -or -not $Context.Subscription.Name) {
                Write-Error -Message "You are not logged into Azure Stack. Current context is $($Context.Environment.ResourceManagerUrl). Login to Azure Stack to proceed."
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message "You are not logged in. Run Connect-AzureRmEnvironment to login." -ErrorId "AzureRmContextError"
                break
            }
        }
    }
    process {
        try {
            $ResourceGroup = New-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location
        }
        catch {
            Write-Error -Message "Failed to create new resource group: $($ResourceGroupName) in $($Location)."
            break
        }
        try {
            New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -EnabledForDeployment -EnabledForTemplateDeployment
        }
        catch {
            Write-Error -Message "Failed to create new key vault named: $($VaultName) in resource group: $($ResourceGroupName) in $($Location)."
            break
        }
    }
}


function New-Certificate {
    <#
    .SYNOPSIS
        Create a new certificate for use during service fabric deployment.
    
    .PARAMETER CertPath
        The path to place the newly created certificate. Defaults to: "C:\Temp".

    .PARAMETER Location
        The location used when creating the certificate name. Defaults to: "frn00006".

    .PARAMETER AppName
        The name of the application used when creating the certificate name. Defaults to: "TestVM".
    
    .PARAMETER CertName
        The name of the certificate. Defaults to: "$AppName.$Location.cloudapp.azure.com".

    .EXAMPLE 
        New-Certificate
    
    .EXAMPLE
        New-Certificate -CertPath "C:\Temp\ServiceFabricTest" -AppName "ServiceFabricTest"

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateScript( { if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force -Verbose } else { $true } })]
        [String]
        $CertPath = "C:\Temp",

        [Parameter(Mandatory = $false)]
        [String]
        $Location = "frn00006",

        [Parameter(Mandatory = $false)]
        [String]
        $AppName = "TestVM",

        [Parameter(Mandatory = $false)]
        [String]
        $CertName = "$AppName.$Location.cloudapp.azure.com"
    )

    begin {
        # Create new self-signed certificate.
        try {
            $Cert = New-SelfSignedCertificate -DnsName $CertName -CertStoreLocation "Cert:\LocalMachine\My"
            $CertWithThumb = "$CertStoreLocation\$($Cert.Thumbprint)"
            $FilePath = "$CertPath\$CertName.pfx"
        }
        catch {
            Write-Error -Message "Failed to create self-signed certificate. Terminating..." -ErrorAction "Stop"
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    process {
        # Use certutil.exe to export certificate file.
        try {
            # Declare blank password.
            $PWD = '""'
            & C:\Windows\system32\certutil.exe -ExportPFX -f -p $PWD "My" $Cert.Thumbprint $FilePath ExtendedProperties,EncryptCert
        }
        catch {
            Write-Error -Message "Failed to export certificate. Terminating..." -ErrorAction "Stop"
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    end {
        try {
            $PfxFilePath = [PSCustomObject]@{
                PfxFilePath = $($FilePath)
            }
            $CertImport = Import-PfxCertificate -FilePath $FilePath -CertStoreLocation "Cert:\CurrentUser\My"
            return $PfxFilePath, $CertImport
        }
        catch {
            Write-Error -Message "Failed to import certificate. Terminating..." -ErrorAction "Stop"
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        
    }   
}


function New-AzsKeyVaultSecret {
    <#
    .SYNOPSIS
        Create a new key vault secret.

    .PARAMETER VaultName
        Name of the key vault.
        
    .PARAMETER KeyVaultSecretName
        Name of the key vault secret which stores the certificate values.
    
    .PARAMETER PfxFilePath
        File path to the certificate.

    .PARAMETER Password
        Password for the certificate. Must be passed as [SecureString]. See ConvertTo-SecureString for more info.

    .EXAMPLE
        New-AzsKeyVaultSecret -VaultName "TestVault" -KeyVaultSecretName "Secret01" -PfxFilePath "C:\Temp\TestVM.frn00006.cloudapp.azure.com.pfx"
    
    .EXAMPLE
        [SecureString]$Password = "SomeSecretPassword" | ConvertTo-SecureString -AsPlainText -Force
        New-AzsKeyVaultSecret -VaultName "TestVault" -KeyVaultSecretName "Secret01" -PfxFilePath "C:\Temp\TestVM.frn00006.cloudapp.azure.com.pfx" -Password $Password
    
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $VaultName, 

        [Parameter(Mandatory = $true)]
        [String]
        $KeyVaultSecretName,

        [Parameter(Mandatory = $true)]
        [String]
        $PfxFilePath,
    
        [Parameter(Mandatory = $false)]
        [SecureString]
        $Password
    )


    function Get-ThumbprintFromPfx {
        <#
        .SYNOPSIS
            Helper function.
        
        .DESCRIPTION
            Returns a System.Security.Cryptography.X509Certificates.X509Certificate2 object from a PfxFilePath and Password.
        
        .PARAMETER PfxFilePath
            File path to the certificate.

        .PARAMETER Password
            Password for the certificate. Must be passed as [SecureString]. See ConvertTo-SecureString for more info.
        
        .EXAMPLE
            [SecureString]$Password = "SomeSecretPassword" | ConvertTo-SecureString -AsPlainText -Force
            Get-ThumbprintFromPfx -PfxFilePath "C:\Temp\TestVM.frn00006.cloudapp.azure.com.pfx" -Password $Password
        
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [String]
            $PfxFilePath,

            [Parameter(Mandatory = $false)]
            [SecureString]
            $Password
        )
        return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxFilePath, $Password)
    }


    function Publish-SecretToKeyVault {
        <#
        .SYNOPSIS
            Sets key vault secret.
        
        .DESCRIPTION
            Sets a key vault secret value to be a certificate file.
        
        .PARAMETER PfxFilePath
            File path to the certificate.

        .PARAMETER Password
            Password for the certificate. Must be passed as [SecureString]. See ConvertTo-SecureString for more info.
        
        .PARAMETER VaultName
            Name of the key vault.
        
        .PARAMETER KeyVaultSecretName
            The name of the key vault secret to set.
        
        .EXAMPLE
            [SecureString]$Password = "SomeSecretPassword" | ConvertTo-SecureString -AsPlainText -Force
            Publish-SecretToKeyVault -PfxFilePath "C:\Temp\TestVM.frn00006.cloudapp.azure.com.pfx" -Password $Password -VaultName "TestVault" -KeyVaultSecretName "Secret01" -Verbose
        
        .EXAMPLE
            Publish-SecretToKeyVault -PfxFilePath "C:\Temp\TestVM.frn00006.cloudapp.azure.com.pfx" -VaultName "TestVault" -KeyVaultSecretName "Secret01" -Verbose
        
        #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [String]
            $PfxFilePath,

            [Parameter(Mandatory = $false)]
            [SecureString]
            $Password,

            [Parameter(Mandatory = $true)]
            [String]
            $VaultName,

            [Parameter(Mandatory = $true)]
            [String]
            $KeyVaultSecretName
        )

        $CertContentInBytes = [IO.File]::ReadAllBytes($PfxFilePath)
        $PfxAsBase64EncodedString = [System.Convert]::ToBase64String($CertContentInBytes)

        $JsonObject = ConvertTo-Json -Depth 10 ([PSCustomObject]@{
                data     = $PfxAsBase64EncodedString
                dataType = 'pfx'
                password = $Password 
  
            })

        $JsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($JsonObject)
        $JsonEncoded = [System.Convert]::ToBase64String($JsonObjectBytes)
        $Secret = ConvertTo-SecureString -String $JsonEncoded -AsPlainText -Force
        Set-AzureKeyVaultSecret -VaultName $VaultName -Name $KeyVaultSecretName -SecretValue $Secret

        $PfxCertObject = Get-ThumbprintFromPfx -PfxFilePath $PfxFilePath -Password $Password
        
        $CertificateValues = [PSCustomObject]@{
            KeyVaultID = (Get-AzureRmKeyVault -VaultName $VaultName).ResourceId
            SecretID   = (Get-AzureKeyVaultSecret -VaultName $VaultName -Name $KeyVaultSecretName).id
            Thumbprint = ($PfxCertObject.Thumbprint)

        }

        return $CertificateValues
          
    }
    Publish-SecretToKeyVault -PfxFilePath $PfxFilePath -Password $Password -VaultName $VaultName -KeyVaultSecretName $KeyVaultSecretName -Verbose
}


function New-AzsSFCluster {
    <#
    .SYNOPSIS
        Create a new Service Fabric Cluster.
    
    .DESCRIPTION
        Create a new Service Fabric Cluster on Azure Stack.
   
    .PARAMETER ResourceGroupName
        The name of the resource group to create for the Service Fabric Cluster.
   
    .PARAMETER Location
        The location to create the Service Fabric Cluster in. Defaults to: "frn00006".
   
    .PARAMETER DeploymentName
        The name of the deployment within Azure Stack. Defaults to: "SFCDeployment".
   
    .PARAMETER ClusterName
        The name of the cluster within Azure Stack. Defaults to: "SFCluster".
   
    .PARAMETER NodeTypePrefix
        The Service Fabric node type name. Defaults to: "SFNode".
   
    .PARAMETER PrimaryNtInstanceCount
        The size of the VM scale set. Defaults to: 3.
   
    .PARAMETER VMImageSku
        The VM image to deploy onto the fabric. Defaults to: "2016-Datacenter".
   
    .PARAMETER VMNodeSize
        The Service Fabric Node size. Defaults to: "Standard_D3_v2".
           
    .PARAMETER AdminUserName
        The remote desktop user id.
   
    .PARAMETER AdminPassword
        The remote desktop user password.
   
    .PARAMETER ServiceFabricTCPGatewayPort
        The Service Fabric Cluster TCP gateway port. Used to connect using the service fabric client. Defaults to: 19000.
   
    .PARAMETER ServiceFabricHTTPGatewayPort
        The Service Fabric Cluster HTTP gateway port. Used to connect using the service fabric client. Defaults to: 19080.
   
    .PARAMETER ServiceFabricReverseProxyEndpointPort
        The Service Fabric Cluster reverse proxy endpoint. Used to connect using the service fabric client. Defaults to: 19081.
   
    .PARAMETER LBApplicationPorts
        An array of application ports to be opened. Defaults to: @(80, 8080).
   
    .PARAMETER NSGPorts
        An array of additional ports to be opened in the NSG. Defaults to: @(3389, 8081).
   
    .PARAMETER DNSService
        DNS Service, optional feature. Defaults to: "Yes".
   
    .PARAMETER RepairManager
        Repair Manager, optional feature. Defaults to: "Yes". 	
   
    .PARAMETER SourceVaultValue
        Resource Id of the key vault.
   
    .PARAMETER ClusterCertificateUrlValue
        URL of key vault where the certificate was uploaded.
   
    .PARAMETER ClusterCertficateThumbprint
        Certificate thumbprint.
   
    .PARAMETER ServerCertficateUrlValue
        URL of the key vault where the certificate was uploaded.
   
    .PARAMETER ServerCertficateThumbprint
        Certificate thumbprint.
   
    .PARAMETER ServiceFabricUrl
        Service Fabric deployment package download url. Defaults to:"https://download.microsoft.com/download/8/3/6/836E3E99-A300-4714-8278-96BC3E8B5528/6.5.641.9590/Microsoft.Azure.ServiceFabric.WindowsServer.6.5.641.9590.zip"
    
    .PARAMETER ServiceFabricRuntimeUrl
        Service Fabric runtime download url. Defaults to:"https://download.microsoft.com/download/B/0/B/B0BCCAC5-65AA-4BE3-AB13-D5FF5890F4B5/6.5.641.9590/MicrosoftAzureServiceFabric.6.5.641.9590.cab"
   
    .PARAMETER ScriptBaseUrl
        Service Fabric ARM template. Defaults to:"https://systemgallery.blob.frn00006.azure.ukcloud.com/dev20161101-microsoft-windowsazure-gallery/Microsoft.ServiceFabricCluster.1.0.3/DeploymentTemplates/MainTemplate.json"

    .EXAMPLE
        New-AzsSFCluster -ResourceGroupName "TestSFC8080-3-RG" -AdminUserName "testadmin" -AdminPassword "Password123!" -SourceVaultValue "/subscriptions/1e0ffc2d-184f-4038-887d-b8548ede4d0b/resourceGroups/ResourceGroupTest/providers/Microsoft.KeyVault/vaults/TestVault" -ClusterCertificateUrlValue "https://testvault.vault.frn00006.azure.ukcloud.com:443/secrets/Secret/05bb445ba36b41ca9582ee4fa1e5108d" -ClusterCertficateThumbprint "174B275734E6819C618AD92B6F326DA4569FF610" -ServerCertficateUrlValue "https://testvault.vault.frn00006.azure.ukcloud.com:443/secrets/Secret/05bb445ba36b41ca9582ee4fa1e5108d" -ServerCertficateThumbprint "174B275734E6819C618AD92B6F326DA4569FF610" -AdminClientCertificateThumbprint  "174B275734E6819C618AD92B6F326DA4569FF610"
    
    #>   	
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceGroupName,
   
        [Parameter(Mandatory = $false)]
        [String]
        $Location = "frn00006",
   
        [Parameter(Mandatory = $false)]
        [String]
        $DeploymentName = "SFCDeployment",

        [Parameter(Mandatory = $false)]
        [String]
        $ClusterName = "SFCluster",

        [Parameter(Mandatory = $false)]
        [String]
        $NodeTypePrefix = "SFNode",

        [Parameter(Mandatory = $false)]
        [Int]
        $PrimaryNtInstanceCount = 3,

        [Parameter(Mandatory = $false)]
        [String]
        $VmImageSku = "2016-Datacenter",

        [Parameter(Mandatory = $false)]
        [String]
        $VmNodeSize = "Standard_D2_v2",
                
        [Parameter(Mandatory = $true)]
        [String]
        $AdminUserName,

        [Parameter(Mandatory = $true)]
        [String]
        $AdminPassword,

        [Parameter(Mandatory = $false)]
        [Int]
        $ServiceFabricTCPGatewayPort = 19000, 

        [Parameter(Mandatory = $false)]
        [Int]
        $ServiceFabricHTTPGatewayPort = 19080,

        [Parameter(Mandatory = $false)]
        [Int]
        $ServiceFabricReverseProxyEndpointPort = 19081,

        [Parameter(Mandatory = $false)]
        [Array]
        $LBApplicationPorts = @(80, 8080), 

        [Parameter(Mandatory = $false)]
        [Array]
        $NSGPorts = @(3389, 8081),   

        [Parameter(Mandatory = $true)]
        [String]
        $SourceVaultValue,

        [Parameter(Mandatory = $true)]
        [String]
        $ClusterCertificateUrlValue,

        [Parameter(Mandatory = $true)]
        [String]
        $ClusterCertficateThumbprint,

        [Parameter(Mandatory = $true)]
        [String]
        $ServerCertficateUrlValue,

        [Parameter(Mandatory = $true)]
        [String]
        $ServerCertficateThumbprint,

        [Parameter(Mandatory = $false)]
        [String]
        $ReverseProxyCertficateUrlValue,

        [Parameter(Mandatory = $false)]
        [String]
        $ReverseProxyCertficateThumbprint,
                
        [Parameter(Mandatory = $true)]
        [String]
        $AdminClientCertificateThumbprint,

        [Parameter(Mandatory = $false)]
        [String]
        $NonClientCertficateThumbprint,
                
        [Parameter(Mandatory = $false)]
        [String]
        $DNSService = "Yes",

        [Parameter(Mandatory = $false)]
        [String]
        $RepairManager = "Yes",

        [Parameter(Mandatory = $false)]
        [Uri]
        $ServiceFabricUrl = "https://download.microsoft.com/download/8/3/6/836E3E99-A300-4714-8278-96BC3E8B5528/6.5.641.9590/Microsoft.Azure.ServiceFabric.WindowsServer.6.5.641.9590.zip",

        [Parameter(Mandatory = $false)]
        [Uri]
        $ServiceFabricRuntimeUrl = "https://download.microsoft.com/download/B/0/B/B0BCCAC5-65AA-4BE3-AB13-D5FF5890F4B5/6.5.641.9590/MicrosoftAzureServiceFabric.6.5.641.9590.cab",

        [Parameter(Mandatory = $false)]
        [Uri]
        $ScriptBaseUrl = "https://systemgallery.blob.frn00006.azure.ukcloud.com/dev20161101-microsoft-windowsazure-gallery/Microsoft.ServiceFabricCluster.1.0.3/DeploymentTemplates/MainTemplate.json",

        [Parameter(Mandatory = $false)]
        [Uri]
        $TemplateUri = "https://systemgallery.blob.frn00006.azure.ukcloud.com/dev20161101-microsoft-windowsazure-gallery/Microsoft.ServiceFabricCluster.1.0.3/DeploymentTemplates/MainTemplate.json"
    )

    begin {
        try {
            # Azure Powershell way to check if we are logged in as a user
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://adminmanagement*" -or $Context.Environment.ResourceManagerUrl -like "*azure.com*" -or -not $Context.Subscription.Name) {
                Write-Error -Message "You are not logged into Azure Stack. Current context is $($Context.Environment.ResourceManagerUrl). Login to Azure Stack to proceed."
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message "You are not logged in. Run Connect-AzureRmEnvironment to login." -ErrorId 'AzureRmContextError'
                break
            }
        }
        $AdminPasswordSecure = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    }
    process {
        try {
            New-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location -Force | Out-Null

            $NewDeployment = New-AzureRmResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateUri -NodeTypePrefix $NodeTypePrefix -PrimaryNtInstanceCount $PrimaryNtInstanceCount `
                -VmImageSku $VmImageSku -VmNodeSize $VmNodeSize -AdminUserName $AdminUserName -AdminPassword $AdminPasswordSecure `
                -ServicefabricTcpGatewayPort $ServiceFabricTCPGatewayPort -ServicefabricHttpGatewayPort $ServiceFabricHTTPGatewayPort -ServicefabricReverseProxyEndpointPort $ServiceFabricReverseProxyEndpointPort `
                -LBApplicationPorts $LBApplicationPorts -NSGPorts $NSGPorts -SourceVaultValue $SourceVaultValue -ClusterCertificateUrlValue $ClusterCertificateUrlValue `
                -ClusterCertificateThumbprint $ClusterCertficateThumbprint -ServerCertificateUrlValue $ServerCertficateUrlValue -ServerCertificateThumbprint $ServerCertficateThumbprint `
                -ReverseProxyCertificateUrlValue $ReverseProxyCertficateUrlValue -ReverseProxyCertificateThumbprint $ReverseProxyCertficateThumbprint -AdminClientCertificateThumbprint $AdminClientCertificateThumbprint `
                -NonAdminClientCertificateThumbprints $NonClientCertficateThumbprint -DNSService $DNSService -RepairManager $RepairManager -ServiceFabricRuntimeUrl $ServiceFabricRuntimeUrl -ServiceFabricUrl $ServiceFabricUrl `
                -ScriptBaseUrl $ScriptBaseUrl -ClusterName $ClusterName -Verbose

            #.clusterMgmtEndpoint
            return $NewDeployment.Outputs.clientConnectionEndpoint.Value 
        }
        catch {
            Write-Error -Message "Service fabric deployment failed: $($_.Exception.Message) Terminating..." -ErrorAction "Stop"
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}


function Publish-ServiceFabricAppWithVisualStudio {
    <#
    .SYNOPSIS
        Deploy a Service Fabric app.
    
    .DESCRIPTION
        Deploy a Service Fabric app using Visual Studio.

    .PARAMETER MsBuild
        Visual Studio location for msbuild.exe. Defaults to: "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe".

    .PARAMETER FilePath
        Location to store the app repository. Example: "C:\temp\Test12\Voting.sln".

    .PARAMETER SolutionPath
        Location of the app that needs to be built. Example: "C:\temp\Test12\Voting.sln".

    .PARAMETER Uri
        Downloads nuget package. Defaults to: "https://www.nuget.org/api/v2/package/Microsoft.VisualStudio.Azure.Fabric.MSBuild/1.6.7",

    .PARAMETER GitHubUri
        Uri to download the app from. Defaults to: "https://github.com/Azure-Samples/service-fabric-dotnet-quickstart".

    .PARAMETER Version
        Specifies the version to use. Defaults to: "Microsoft.VisualStudio.Azure.Fabric.MSBuild.1.6.7".

    .EXAMPLE
        Publish-ServiceFabricAppWithVisualStudio -FilePath "C:\temp\Test10" -SolutionPath "C:\temp\Test10\Voting.sln"

    .LINK 
        https://github.com/Azure-Samples/service-fabric-dotnet-quickstart
    
    #>
    [CmdletBinding()]
    param (         
        [Parameter(Mandatory = $false)]
        [String]
        $MsBuild = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",

        [Parameter(Mandatory = $true)]
        [String]
        $FilePath,
        
        [Parameter(Mandatory = $true)]
        [String]
        $SolutionPath,

        [Parameter(Mandatory = $false)]
        [String]
        $Uri = "https://www.nuget.org/api/v2/package/Microsoft.VisualStudio.Azure.Fabric.MSBuild/1.6.7",

        [Parameter(Mandatory = $false)]
        [String]
        $GitHubUri = "https://github.com/Azure-Samples/service-fabric-dotnet-quickstart",

        [Parameter(Mandatory = $false)]
        [String]
        $Version = "Microsoft.VisualStudio.Azure.Fabric.MSBuild.1.6.7"
    )
    
    process {
        Set-Location $FilePath
        git clone $GitHubUri
        $RepoName = $GitHubUri.Split("/")[-1]
        Get-ChildItem -Path "$FilePath\$RepoName\*" -Force -Recurse | Move-Item -Destination $FilePath -Force -Verbose 
        Remove-item -Path "$FilePath\$RepoName\" -Force

        $MSBuildFabricPackage = "$FilePath\packages\$Version"
        New-Item -Path $MSBuildFabricPackage -ItemType Directory
        Invoke-WebRequest -Uri $Uri -UseBasicParsing -OutFile "$MSBuildFabricPackage\$Version.nupkg.zip"
        Expand-Archive -Path "$MSBuildFabricPackage\$Version.nupkg.zip" -DestinationPath $MSBuildFabricPackage

        Write-Host -Object "Restoring NuGet packages" -ForegroundColor Green
        & $MsBuild /t:Restore $SolutionPath 

        Write-Host -Object "Publishing $($SolutionPath)" -ForegroundColor Green
        & $MsBuild /t:Package $SolutionPath
        
        Write-Host -Object "Building $($SolutionPath)" -ForegroundColor Green
        & $MsBuild /t:Build $SolutionPath 
    }
}


function Set-XML {
    <#
    .SYNOPSIS
        Set XML content.
    
    .DESCRIPTION
        Set the XML content of Cloud.xml.
    
    .PARAMETER ServiceFabricClusterUrl
        The URL of the Service Fabric Cluster.
    
    .PARAMETER CertThumbprint
        The certificate thumbprint.
    
    .PARAMETER FilePath
        The file path to the app.
    
    .EXAMPLE
        Set-XML -ServiceFabricClusterUrl "sfclusterrewq6r4r3qw7e.frn00006.cloudapp.azure.ukcloud.com:19000" -CertThumbprint "174B275734E6819C618AD92B6F326DA4569FF610" -FilePath $FilePath
    
    #>
    [CmdletBinding()]
    param (         
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceFabricClusterUrl,

        [Parameter(Mandatory = $true)]
        [String]
        $CertThumbprint,

        [Parameter(Mandatory = $true)]
        [String]
        $FilePath
    )

    process {
        $ContentInsert = @"
<ClusterConnectionParameters 
ConnectionEndpoint="$ServiceFabricClusterUrl"
X509Credential="true"
ServerCertThumbprint=`"$CertThumbprint`"
FindType="FindByThumbprint"
FindValue=`"$CertThumbprint`"
StoreLocation="CurrentUser"
StoreName="My" />
"@

        $CloudPath = "$FilePath\Voting\PublishProfiles\Cloud.xml"
        $CloudXML = Get-Content -Path $CloudPath
        $XML = $CloudXML | ForEach-Object { $_ -replace "<ClusterConnectionParameters />", $ContentInsert }
        $XML | Set-Content -Path $CloudPath -Force -Verbose
    }
}
