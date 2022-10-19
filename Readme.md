# Windows Server 2022 Scale-Out File Server Cluster with Ultra Disk

## How to deploy

1. Create a resource group.
```sh
az group create -n <resource group> -l <region>
```
2. Deploy the resources.
```sh
az deployment group create \
    --name <deployment name> \
    --resource-group <resource group> \
    --template-file main.bicep \
    --parameters adminPassword="<admin password>"
```

