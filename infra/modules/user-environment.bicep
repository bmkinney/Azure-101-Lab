// user-environment.bicep - Per-user lab environment with baked-in faults
// Deploys: VNet, subnets, NSG (with deny rule), route table (with blackhole),
//          NIC, VM (with failed extension), storage account, DCR association

@description('User prefix for resource naming (e.g., userA, userB).')
param userPrefix string

@description('Azure region for all resources.')
param location string

@description('Index offset for unique VNet address space (0-based).')
param addressIndex int

@description('Admin username for the VM.')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for the VM.')
param adminPassword string

@description('Resource ID of the shared Data Collection Rule.')
param dataCollectionRuleId string

// --- Naming ---
var vnetName = '${userPrefix}-vnet'
var mgmtSubnetName = '${userPrefix}-mgmt-snet'
var workloadSubnetName = '${userPrefix}-workload-snet'
var nsgName = '${userPrefix}-nsg'
var routeTableName = '${userPrefix}-rt'
var nicName = '${userPrefix}-nic'
var vmName = '${userPrefix}-vm'
var storageAccountName = toLower(replace('${userPrefix}azure101labst', '-', ''))

// --- Address Space ---
// Each user gets a unique /16: 10.10.0.0/16, 10.11.0.0/16, etc.
var secondOctet = 10 + addressIndex
var vnetAddressSpace = '10.${secondOctet}.0.0/16'
var mgmtSubnetPrefix = '10.${secondOctet}.1.0/24'
var workloadSubnetPrefix = '10.${secondOctet}.2.0/24'

// ============================================================
// NETWORK SECURITY GROUP
// FAULT: DenyAllInbound rule at priority 200 blocks all inbound traffic
// ============================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Deny all inbound traffic'
        }
      }
    ]
  }
}

// ============================================================
// ROUTE TABLE
// FAULT: Blackhole route 0.0.0.0/0 -> None kills all outbound traffic
// ============================================================
resource routeTable 'Microsoft.Network/routeTables@2024-01-01' = {
  name: routeTableName
  location: location
  properties: {
    routes: [
      {
        name: 'blackhole-default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'None'
        }
      }
    ]
  }
}

// ============================================================
// VIRTUAL NETWORK AND SUBNETS
// ============================================================
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressSpace]
    }
    subnets: [
      {
        name: mgmtSubnetName
        properties: {
          addressPrefix: mgmtSubnetPrefix
        }
      }
      {
        name: workloadSubnetName
        properties: {
          addressPrefix: workloadSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
    ]
  }
}

// ============================================================
// NETWORK INTERFACE
// No public IP by design — forces portal-native management tools
// ============================================================
resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ============================================================
// STORAGE ACCOUNT — boot diagnostics target
// Note: intentionally missing Department and Environment tags (cost/policy fault)
// ============================================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ============================================================
// VIRTUAL MACHINE
// Ubuntu 22.04 LTS, Standard_B1s, password auth for lab simplicity
// FAULT: Will be deallocated post-deployment (via vm-stop module)
// ============================================================
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
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

// ============================================================
// FAILED CUSTOM SCRIPT EXTENSION
// FAULT: Intentionally runs a non-existent command to produce a failed extension
// ============================================================
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'FailedCustomScript'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: '/opt/nonexistent-setup-script.sh'
    }
  }
}

// ============================================================
// AZURE MONITOR AGENT + DATA COLLECTION RULE ASSOCIATION
// Connects this VM to the shared Log Analytics workspace
// ============================================================
resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [vmExtension]
}

resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${vmName}-dcr-association'
  scope: vm
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [amaExtension]
}

// ============================================================
// OUTPUTS
// ============================================================
output vmName string = vm.name
output vmResourceId string = vm.id
output nicPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output storageAccountName string = storageAccount.name
output vnetAddressSpace string = vnetAddressSpace
