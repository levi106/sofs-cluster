param location string
param vnetName string
param subnetName string
param vmssName string
param lbName string = '${vmssName}-lb'
param domainName string
param zones array = ['1']
param faultDomainCount int = 1
param vmNamePrefix string = 'VM'
param vmSize string = 'Standard_D2s_v3'
param vmCount int = 2
param dataDiskCount int = 1
param diskMaxShares int = vmCount
param dataDiskSieGB int = 1024
param clusterName string = 'cluster1'
param sofsName string = 'sofs1'
param shareName string = 'share1'
param adminUsername string
@secure()
param adminPassword string
param tags object = {}

var prepModuleUrl = 'https://github.com/levi106/dsc/releases/download/v1.14/PrepareSOFS.zip'
var configModuleUrl = 'https://github.com/levi106/dsc/releases/download/v1.14/ConfigSOFS.zip'

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2019-12-01' existing = {
  name: subnetName
  parent: vnet
}

resource lb 'Microsoft.Network/loadBalancers@2020-11-01' = {
  name: lbName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendConfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool1'
        properties: {
          loadBalancerBackendAddresses: []
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'All'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendConfig1')
          }
          frontendPort: 0
          backendPort: 0
          protocol: 'All'
          loadDistribution: 'Default'
          enableFloatingIP: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'backendPool1')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'probe1')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe1'
        properties: {
          protocol: 'Tcp'
          port: 3389
        }
      }
    ]
  }
}

resource witnessStorage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'witness${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2022-08-01' = {
  name: vmssName
  location: location
  tags: tags
  zones: zones
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: faultDomainCount
    singlePlacementGroup: false
    additionalCapabilities: {
      ultraSSDEnabled: true
    }
  }
}

resource dataDisks 'Microsoft.Compute/disks@2022-07-02' = [for i in range(0, dataDiskCount): {
  name: '${vmssName}_DataDisk_${i}'
  location: location
  tags: tags
  sku: {
    name: 'UltraSSD_LRS'
  }
  zones: zones
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSieGB
    maxShares: diskMaxShares
  }
}]

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-12-01' = [for i in range(0, vmCount): {
  name: '${vmssName}-nsg${i}'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}]

@batchSize(1)
resource vm 'Microsoft.Compute/virtualMachines@2022-08-01' = [for i in range(0, vmCount): {
  name: '${vmssName}-vm${i}'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    virtualMachineScaleSet: {
      id: vmss.id
    }
    additionalCapabilities: {
      ultraSSDEnabled: true
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      dataDisks: [for i in range(0, dataDiskCount): {
        lun: i
        name: dataDisks[i].name
        createOption: 'Attach'
        managedDisk: {
          id: dataDisks[i].id
        }
      }]
    }
    osProfile: {
      computerName: '${vmNamePrefix}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
      }
    }
    networkProfile: {
      networkApiVersion: '2020-11-01'
      networkInterfaceConfigurations: [
        {
          name: '${vmssName}-nic${i}'
          properties: {
            primary: true
            enableAcceleratedNetworking: true
            enableIPForwarding: false
            ipConfigurations: [
              {
                name: 'ipconfig1'
                properties: {
                  subnet: {
                    id: subnet.id
                  }
                  privateIPAddressVersion: 'IPv4'
                  primary: true
                  loadBalancerBackendAddressPools: [
                    {
                      id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb.name, 'backendPool1')
                    }
                  ]
                }
              }
            ]
            networkSecurityGroup: {
              id: nsg[i].id
            }
          }
        }
      ]
    }
  }
}]

resource vmprep 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  name: 'prepvm0'
  location: location
  tags: tags
  parent: vm[1]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: prepModuleUrl
        script: 'PrepareClusterNode.ps1'
        function: 'PrepareClusterNode'
      }
      configurationArguments: {
        domainName: domainName
      }
    }
    protectedSettings: {
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
      }
    }
  }
}

resource vmconfig 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  name: 'configvm1'
  location: location
  tags: tags
  parent: vm[0]
  dependsOn: [vmprep]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: configModuleUrl
        script: 'ConfigureCluster.ps1'
        function: 'ConfigureCluster'
      }
      configurationArguments: {
        domainName: domainName
        clusterName: clusterName
        namePrefix: vmNamePrefix
        vmCount: vmCount
        dataDiskSizeGB: dataDiskSieGB
        witnessType: 'Cloud'
        witnessStorageName: witnessStorage.name
        sofsName: sofsName
        shareName: shareName
      }
    }
    protectedSettings: {
      configurationArguments: {
        adminCreds: {
          userName: adminUsername
          password: adminPassword
        }
        witnessStorageKey: {
          userName: 'PLACEHOLDER-DO-NOT-USE'
          password: witnessStorage.listKeys().keys[0].value
        }
      }
    }
  }
}
