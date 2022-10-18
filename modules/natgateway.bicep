param location string
param name string
param tags object = {}

resource natgateway_pip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: '${name}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource natgateway_pip_prefix 'Microsoft.Network/publicIPPrefixes@2021-08-01' = {
  name: '${name}-pip-prefix'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    prefixLength: 31
    publicIPAddressVersion: 'IPv4'
  }
}

resource natgateway 'Microsoft.Network/natGateways@2022-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natgateway_pip.id
      }
    ]
    publicIpPrefixes: [
      {
        id: natgateway_pip_prefix.id
      }
    ]
  }
}

output id string = natgateway.id
