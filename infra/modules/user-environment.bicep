// user-environment.bicep - Group lab environment with baked-in faults
// Deploys: 2 VNets (peered), 2 NSGs, Bastion, 2 NICs, 2 VMs,
//          data disk on VM1, storage account (blob + diagnostics), DCR associations,
//          NSG flow logs, storage diagnostic settings
//
// All students in a group share this single set of resources and collaborate
// in a breakout room. One deployment per group subscription.
//
// Faults baked in:
//   - VM1: Standard_D2alds_v7 (CPU spike injected post-deploy via fault-injection.bicep)
//   - VM1: 4 GB data disk filled to >80% (via fault-injection.bicep)
//   - NSG1/NSG2: Custom deny rules block cross-VNet traffic (students add allow rules for 1433)
//   - Storage account: Missing Department and Environment tags (policy fault)
//   - Storage account: No Storage Blob Data Contributor assigned (RBAC data-plane fault)

@description('Base name prefix for all resources (e.g., azure101lab).')
param labName string = 'azure101lab'

@description('Azure region for all resources.')
param location string

@description('Admin username for VMs.')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for VMs.')
param adminPassword string

@description('Resource ID of the shared Data Collection Rule.')
param dataCollectionRuleId string

@description('Resource ID of the shared Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Contact email for metric alert notifications. Leave empty to skip alerts.')
param alertEmail string = ''

@description('VM size for both lab VMs.')
param vmSize string = 'Standard_D2alds_v7'

// --- Naming ---
var vnet1Name = '${labName}-vnet1'
var vnet2Name = '${labName}-vnet2'
var workloadSubnet1Name = '${labName}-workload-snet1'
var workloadSubnet2Name = '${labName}-workload-snet2'
var bastionSubnetName = 'AzureBastionSubnet'
var nsg1Name = '${labName}-nsg1'
var nsg2Name = '${labName}-nsg2'
var nic1Name = '${labName}-nic1'
var nic2Name = '${labName}-nic2'
var vm1Name = '${labName}-vm1'
var vm2Name = '${labName}-vm2'
var bastionName = '${labName}-bastion'
var bastionPipName = '${labName}-bastion-pip'
var storageAccountName = toLower(replace('${labName}st', '-', ''))

// --- Address Space ---
var vnet1AddressSpace = '10.10.0.0/16'
var vnet2AddressSpace = '10.11.0.0/16'
var workloadSubnet1Prefix = '10.10.1.0/24'
var bastionSubnetPrefix = '10.10.254.0/26'
var workloadSubnet2Prefix = '10.11.1.0/24'

// ============================================================
// NETWORK SECURITY GROUPS
// FAULT: Custom deny rules block cross-VNet traffic.
// NSG1 denies outbound to VNet2; NSG2 denies inbound from VNet1.
// Default AllowVnetInBound would otherwise allow peered traffic.
// Students must add allow rules on BOTH NSGs for port 1433.
// ============================================================

resource nsg1 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsg1Name
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyCrossVNetOutbound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: vnet2AddressSpace
          description: 'Block all outbound traffic to VNet2'
        }
      }
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsg2Name
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyCrossVNetInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: vnet1AddressSpace
          destinationAddressPrefix: '*'
          description: 'Block all inbound traffic from VNet1'
        }
      }
    ]
  }
}

// ============================================================
// VIRTUAL NETWORK 1 — Workload + Bastion
// ============================================================

resource vnet1 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnet1Name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnet1AddressSpace]
    }
    subnets: [
      {
        name: workloadSubnet1Name
        properties: {
          addressPrefix: workloadSubnet1Prefix
          networkSecurityGroup: {
            id: nsg1.id
          }
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// ============================================================
// VIRTUAL NETWORK 2 — Database workload
// ============================================================

resource vnet2 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnet2Name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnet2AddressSpace]
    }
    subnets: [
      {
        name: workloadSubnet2Name
        properties: {
          addressPrefix: workloadSubnet2Prefix
          networkSecurityGroup: {
            id: nsg2.id
          }
        }
      }
    ]
  }
}

// ============================================================
// VNET PEERING — VNet1 <-> VNet2
// ============================================================

resource peer1to2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: vnet1
  name: '${vnet1Name}-to-${vnet2Name}'
  properties: {
    remoteVirtualNetwork: {
      id: vnet2.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource peer2to1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: vnet2
  name: '${vnet2Name}-to-${vnet1Name}'
  properties: {
    remoteVirtualNetwork: {
      id: vnet1.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================
// AZURE BASTION — SSH access without public IPs on VMs
// Students use Bastion to connect to VM1 and VM2 via portal
// ============================================================

resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionPip.id
          }
          subnet: {
            id: vnet1.properties.subnets[1].id // AzureBastionSubnet
          }
        }
      }
    ]
  }
}

// ============================================================
// NETWORK INTERFACES — No public IPs
// ============================================================

resource nic1 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: nic1Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet1.properties.subnets[0].id // workload subnet 1
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: nic2Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet2.properties.subnets[0].id // workload subnet 2
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ============================================================
// STORAGE ACCOUNT — blob storage + boot diagnostics
// FAULT: Intentionally missing Department and Environment tags (Module 5)
// FAULT: No Storage Blob Data Contributor for students (Module 6)
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
    allowBlobPublicAccess: false
  }
}

// Blob service and container for RBAC challenge (Module 6)
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource labContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'lab-data'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================
// STORAGE DIAGNOSTIC SETTINGS → Log Analytics
// Sends StorageBlobLogs for Module 7 (storage access audit)
// ============================================================

resource storageBlobDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccountName}-blob-diag'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// ============================================================
// VIRTUAL MACHINE 1 — Workload VM
// Ubuntu 22.04 LTS (2 vCPU — undersized for CPU spike)
// FAULT: CPU spike injected post-deploy (Module 1)
// FAULT: 4 GB data disk filled to >80% (Module 3)
// ============================================================

resource vm1 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vm1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm1Name
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
      dataDisks: [
        {
          lun: 0
          name: '${vm1Name}-datadisk'
          diskSizeGB: 4
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic1.id
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
// VIRTUAL MACHINE 2 — Database/Service VM
// Ubuntu 22.04 LTS
// Runs a TCP listener on port 1433 (simulates SQL service)
// Configured via CustomScript extension at deploy time
// ============================================================

resource vm2 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vm2Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm2Name
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
          id: nic2.id
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

// VM2: Install TCP listener on port 1433 (simulates SQL endpoint)
resource vm2SqlListener 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm2
  name: 'SetupSqlListener'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'bash -c \'apt-get update && apt-get install -y ncat && cat > /etc/systemd/system/sql-listener.service << EOF\n[Unit]\nDescription=SQL Listener on 1433\nAfter=network.target\n[Service]\nExecStart=/usr/bin/ncat -lk 1433 -e /bin/echo\nRestart=always\n[Install]\nWantedBy=multi-user.target\nEOF\nsystemctl daemon-reload && systemctl enable sql-listener && systemctl start sql-listener\''
    }
  }
}

// ============================================================
// AZURE MONITOR AGENT + DCR ASSOCIATION (both VMs)
// ============================================================

resource ama1 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm1
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource ama2 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm2
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource dcr1 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${vm1Name}-dcr-association'
  scope: vm1
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [ama1]
}

resource dcr2 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${vm2Name}-dcr-association'
  scope: vm2
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [ama2]
}

// ============================================================
// METRIC ALERT: Data disk usage on VM1 (Module 3)
// Fires when data disk used percentage > 80%
// ============================================================

resource diskAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(alertEmail)) {
  name: '${vm1Name}-disk-alert'
  location: 'global'
  properties: {
    description: 'Data disk on ${vm1Name} is over 80% full.'
    severity: 2
    enabled: true
    scopes: [
      vm1.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Compute/virtualMachines'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'DiskUsedPercentage'
          metricName: 'Data Disk Used Percentage'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: diskAlertActionGroup.id
      }
    ]
  }
}

resource diskAlertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (!empty(alertEmail)) {
  name: '${labName}-disk-ag'
  location: 'global'
  properties: {
    groupShortName: 'DiskAlert'
    enabled: true
    emailReceivers: [
      {
        name: 'StudentEmail'
        emailAddress: alertEmail
      }
    ]
  }
}

// ============================================================
// OUTPUTS
// ============================================================
output vm1Name string = vm1.name
output vm2Name string = vm2.name
output vm1ResourceId string = vm1.id
output vm2ResourceId string = vm2.id
output vm1PrivateIp string = nic1.properties.ipConfigurations[0].properties.privateIPAddress
output vm2PrivateIp string = nic2.properties.ipConfigurations[0].properties.privateIPAddress
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output nsg1Id string = nsg1.id
output nsg1Name string = nsg1.name
output nsg2Id string = nsg2.id
output nsg2Name string = nsg2.name
output vnet1AddressSpace string = vnet1AddressSpace
output vnet2AddressSpace string = vnet2AddressSpace
