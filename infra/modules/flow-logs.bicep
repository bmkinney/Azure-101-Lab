// flow-logs.bicep - NSG Flow Logs (deployed to NetworkWatcherRG)
// Network Watcher auto-creates in NetworkWatcherRG; flow logs must be children
// of that watcher, so this module is scoped there from main.bicep.
//
// Prerequisite: Network Watcher must be enabled for the region.
//   az network watcher configure --locations <region> --enabled true

param location string
param nsg1Id string
param nsg1Name string
param nsg2Id string
param nsg2Name string
param storageAccountId string
param logAnalyticsWorkspaceId string

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-01-01' existing = {
  name: 'NetworkWatcher_${location}'
}

resource nsg1FlowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-01-01' = {
  parent: networkWatcher
  name: '${nsg1Name}-flowlog'
  location: location
  properties: {
    targetResourceId: nsg1Id
    storageId: storageAccountId
    enabled: true
    retentionPolicy: {
      enabled: true
      days: 7
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: logAnalyticsWorkspaceId
        trafficAnalyticsInterval: 10
      }
    }
  }
}

resource nsg2FlowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-01-01' = {
  parent: networkWatcher
  name: '${nsg2Name}-flowlog'
  location: location
  properties: {
    targetResourceId: nsg2Id
    storageId: storageAccountId
    enabled: true
    retentionPolicy: {
      enabled: true
      days: 7
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: logAnalyticsWorkspaceId
        trafficAnalyticsInterval: 10
      }
    }
  }
}
