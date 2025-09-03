// AZ 104 Ward Directory Bicep file for Load Balancer config.

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Prefix to use for VM names')
param vmNamePrefix string = 'BackendVM'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Size of VM')
param vmSize string = 'Standard_D2s_v3'

// Defining the VNet address space prefixes.
@description('Virtual network address prefix')
param vNetAddressPrefix string = '10.0.0.0/16'

@description('Backend subnet address prefix')
param vNetSubnetAddressPrefix string = '10.0.0.0/24'

@description('Bastion subnet address prefix')
param vNetBastionSubnetAddressPrefix string = '10.0.2.0/24'

@description('Frontend IP address of load balancer')
param lbFrontendIPAddress string = '10.0.0.6'

// Defining the NAT Gateway
var natGatewayName = 'lb-nat-gateway-az-104-ward-directory'
var natGatewayPublicIPAddressName = 'lb-nat-gateway-ip-az-104-ward-directory'
var vNetName = 'lb-vnet-az-104-ward-directory'
var vNetSubnetName = 'backend-subnet-az-104-ward-directory'
var storageAccountType = 'Standard_LRS'
var storageAccountName = uniqueString(resourceGroup().id)
var loadBalancerName = 'internal-lb-az-104-ward-directory'
var networkInterfaceName = 'lb-nic-az-104-ward-directory'
var numberOfInstances = 5
var lbSkuName = 'Standard'
var bastionName = 'lb-bastion-az-104-ward-directory'
var bastionSubnetName = 'AzureBastionSubnetWardDirectory'
var bastionPublicIPAddressName = 'lb-bastion-ip-az-104-ward-directory'

resource natGateway 'Microsoft.Network/natGateways@2023-09-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natGatewayPublicIPAddress.id
      }
    ]
  }
}

resource natGatewayPublicIPAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: natGatewayPublicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource vNet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
  }
}

resource vNetName_bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vNet
  name: bastionSubnetName
  properties: {
    addressPrefix: vNetBastionSubnetAddressPrefix
  }
}

resource vNetName_vNetSubnetName 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vNet
  name: vNetSubnetName
  properties: {
    addressPrefix: vNetSubnetAddressPrefix
    natGateway: {
      id: natGateway.id
    }
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIPAddress.id
          }
          subnet: {
            id: vNetName_bastionSubnet.id
          }
        }
      }
    ]
  }
}

resource bastionPublicIPAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: bastionPublicIPAddressName
  location: location
  sku: {
    name: lbSkuName
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = [
  for i in range(0, numberOfInstances): {
    name: '${networkInterfaceName}${i}'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            subnet: {
              id: vNetName_vNetSubnetName.id
            }
            loadBalancerBackendAddressPools: [
              {
                id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
              }
            ]
          }
        }
      ]
    }
    dependsOn: [
      loadBalancer
    ]
  }
]

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        properties: {
          subnet: {
            id: vNetName_vNetSubnetName.id
          }
          privateIPAddress: lbFrontendIPAddress
          privateIPAllocationMethod: 'Static'
        }
        name: 'LoadBalancerFrontend'
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool1'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIpConfigurations',
              loadBalancerName,
              'LoadBalancerFrontend'
            )
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'lbprobe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
        name: 'lbrule'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'lbprobe'
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = [
  for i in range(0, numberOfInstances): {
    name: '${vmNamePrefix}${i}'
    location: location
    properties: {
      hardwareProfile: {
        vmSize: vmSize
      }
      osProfile: {
        computerName: '${vmNamePrefix}${i}'
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      storageProfile: {
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2019-Datacenter'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: networkInterface[i].id
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
          storageUri: storageAccount.properties.primaryEndpoints.blob
        }
      }
    }
  }
]

output location string = location
output name string = loadBalancer.name
output resourceGroupName string = resourceGroup().name
output resourceId string = loadBalancer.id
