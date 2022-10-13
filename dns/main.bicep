param prefix string = 'sofs-cluster'
param location string = resourceGroup().location
param vnetPrefix string = '172.17.0.0/16'
param subnetPrefix string = '172.17.0.0/24'

var vmName = '${prefix}-ad'
var tags = {}

resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' existing = {
  name: '${vmName}-nic'
}

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: '${prefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: [nic.properties.ipConfigurations[0].properties.privateIPAddress]
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}
