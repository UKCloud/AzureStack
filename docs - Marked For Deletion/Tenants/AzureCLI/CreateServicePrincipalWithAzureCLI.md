

| title       | description      | services        | author |
| :------------- |:-------------| :--------------------- | :----- |
| Create a Service Principal with Azure CLI      | Learn how to create a Service Principal using the Azure CLI | azure-stack | Paul Brown |
## Create a Service Principal using the Azure CLI

### Connect to Azure Stack and select Subscription
```azurecli az cloud set --n AzureStack
## Login
az login
## List subscriptions
az account list --output table
## Select subscription using "SUBSCRIPTION_ID = id" field referenced from above
az account set --subscription="SUBSCRIPTION_ID"
```
### Create Service Principal
```azurecli
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID"
```

```azurecli
This command will output five values
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2017-06-05-10-41-15",
  "name": "http://azure-cli-2017-06-05-10-41-15",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```
### Login  to Service Principal
##### Note, CLIENT_ID=appID, CLIENT_SECRET=password, TENANT_ID=tenant
```azurecli
az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID
```
### Test values have worked 
```azurecli
az vm list-sizes --location frn00006
```
