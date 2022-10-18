param location string
param vnetName string
param vmName string
param subnetName string
param privateIPAddress string
param vmSize string = 'Standard_D2s_v3'
param computerName string = 'DC1'
param domainName string
param adminUsername string
@secure()
param adminPassword string
param tags object = {}

var modulesUrl = 'https://github.com/levi106/dsc/releases/download/v1.7/CreateADPDC.zip'

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2019-12-01' existing = {
  name: subnetName
  parent: vnet
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-12-01' = {
  name: '${vmName}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: '${vmName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIPAddress
          subnet: {
            id: subnet.id
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: false
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadOnly'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          name: '${vmName}_DataDisk_0'
          caching: 'None'
          createOption: 'Empty'
          diskSizeGB: 20
          lun: 0
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource dsc 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${vmName}-dsc'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: false
    settings: {
      ModulesUrl: modulesUrl
      ConfigurationFunction: 'CreateADPDC.ps1\\CreateADPDC'
      Properties: {
        DomainName: domainName
        AdminCreds: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        adminPassword: adminPassword
      }
    }
  }
}

module vnet_update './vnet.bicep' = {
  name: 'update-vnet'
  scope: resourceGroup()
  dependsOn: [dsc]
  params: {
    name: vnet.name
    location: location
    addressPrefixes: vnet.properties.addressSpace.addressPrefixes
    subnets: vnet.properties.subnets
    dnsServers: [privateIPAddress]
  }
}

output domainName string = domainName
