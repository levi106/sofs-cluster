param prefix string = 'ultradisk-cluster'
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

var tags = {}
var vnetPrefix = '172.17.0.0/16'
var defaultSubnetPrefix = '172.17.0.0/24'
var vmssSubnetPrefix = '172.17.1.0/24'
var dcVmPrivateIPAddress = '172.17.0.10'

var defaultSubnet = {
  name: 'default'
  properties: {
    addressPrefix: defaultSubnetPrefix
  }
}
var vmssSubnetName = 'vmss'

module natgateway './modules/natgateway.bicep' = {
  name: 'deploy-natgateway'
  scope: resourceGroup()
  params: {
    name: '${prefix}-natgw'
    location: location
  }
}

module vnet './modules/vnet.bicep' = {
  name: 'deploy-vnet'
  scope: resourceGroup()
  params: {
    name: '${prefix}-vnet'
    location: location
    subnets: [
      defaultSubnet
      {
        name: vmssSubnetName
        properties: {
          addressPrefix: vmssSubnetPrefix
          natGateway: {
            id: natgateway.outputs.id
          }
        }
      }
    ]
    addressPrefixes: [vnetPrefix]
  }
}

module dc './modules/dc.bicep' = {
  name: 'deploy-dc'
  scope: resourceGroup()
  params: {
    location: location
    vnetName: vnet.outputs.name
    subnetName: defaultSubnet.name
    vmName: '${prefix}-dc'
    domainName: 'contoso.local'
    privateIPAddress: dcVmPrivateIPAddress
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}

module vmss './modules/vmss.bicep' = {
  name: 'deploy-vmss'
  scope: resourceGroup()
  params: {
    location: location
    vnetName: vnet.outputs.name
    subnetName: vmssSubnetName
    vmssName: '${prefix}-vmss'
    domainName: dc.outputs.domainName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
