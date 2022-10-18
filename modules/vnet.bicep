param name string
param location string
param addressPrefixes array
param subnets array
param dnsServers array = []
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
    dhcpOptions: {
      dnsServers: dnsServers
    }
  }
}

output name string = vnet.name
