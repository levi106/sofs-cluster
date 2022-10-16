param prefix string = 'sofs-cluster'
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

var tags = {}

module dc './modules/dc.bicep' = {
  name: 'dc'
  scope: resourceGroup()
  params: {
    location: location
    vnetName: '${prefix}-vnet'
    vmName: '${prefix}-dc'
    domainName: 'contoso.local'
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}
