# Deployment of a Configuration Server for Azure Site Recovery

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FUKCloud%2FAzureStack%2Fmaster%2FARM%20Templates%2FConfigServer-SiteRecovery%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template allows you to deploy a Configuration Server for Azure Site Recovery. This template requires a virtual network to already be created for the server to be deployed on.

The configuration server that is deployed creates all necessary resources on public Azure for Azure Site Recovery and if this template is deployed into a resource group with VMs, these VMs will be automatically be protected.