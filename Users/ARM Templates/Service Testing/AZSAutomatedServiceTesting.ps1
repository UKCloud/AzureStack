function Start-AllTests {
    param (
        [Parameter(Mandatory = $false)]
        [String]
        $Location = "frn00006"
    )

    begin {
        try {
            # Azure PowerShell way to check if we are logged in as User
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            Write-Debug -Message "Retrieved context for user $($Context.Account.Id)"
            if ($Context.Environment.ResourceManagerUrl -like "*https://adminmanagement*" -or $Context.Environment.ResourceManagerUrl -like "*azure.com*" -or -not $Context.Subscription.Name) {
                Write-Error -Message 'You are seeing this because Connect-AzureEnvironment command did not log in with AzureStackUser context correctly. This command needs to run as User otherwise it will delete ALL RGs in Azure Stack!!!'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureEnvironment to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }

        function Start-ArmDeployments {
            param (
                $Section,
                [String]
                $Url
            )
            process {
                if ($Section.Values.Values) {
                    $Url = $Url + "/" + $Section.Keys
                    Write-Output -InputObject "Starting $($Section.Keys) deployments"

                    foreach ($InnerSection in $Section.Values) {
                        Start-ArmDeployments -Section $InnerSection -Url $Url
                    }
                }
                else {
                    foreach ($Deployment in $Section.Keys) {
                        Write-Output -InputObject "Deploying $Deployment"
                        $TemplateUrl = $Url + "/" + $Section[$Deployment] + "/azuredeploy.json"
                        $global:DeploymentTracker += New-AzureRmResourceGroupDeployment -Name $Deployment -TemplateUri $TemplateUrl -ResourceGroupName $ResourceGroupName -AsJob
                    }
                }
            }
        }
    }

    process {
        $BaseTemplateUrl = "https://raw.githubusercontent.com/UKCloud/AzureStack/Service-Testing/Users/ARM%20Templates/Service%20Testing"
        $global:ResourceGroupName = "TestService-RG"
        $global:DeploymentTracker = @()

        $Templates = @{
            UnitTests = @{
                Networking = @{
                    DNSZone               = "Create-DNS-Zone"
                    LoadBalancer          = "Create-Load-Balancer"
                    LocalNetworkGateway   = "Create-Local-Network-Gateway"
                    NetworkInterfaceCard  = "Create-NIC"
                    NetworkSecurityGroup  = "Create-NSG"
                    PublicIP              = "Create-Public-IP"
                    RouteTable            = "Create-Route-Table"
                    VirtualNetwork        = "Create-Virtual-Network"
                    VirtualNetworkGateway = "Create-Virtual-Network-Gateway"
                    VPNConnection         = "Create-VPN-Connection"
                }
            }
        }

        # Create Test Resource Group
        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location

        Start-ArmDeployments -Section $Templates -Url $BaseTemplateUrl
        while ($DeploymentTracker.State -contains "*Running*") {
            $DeploymentTracker | Select-Object -Property @{Name = "Deployment Name"; Expression = {$_.Name.Split("'")[3]} }, State, PSBeginTime, PSEndTime | Format-Table
        }
        $DeploymentTracker | Select-Object -Property @{Name = "Deployment Name"; Expression = {$_.Name.Split("'")[3]} }, State, PSBeginTime, PSEndTime | Format-Table
    }
}
