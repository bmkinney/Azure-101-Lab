// flow-logs.bicep - VNet Flow Logs (deployed to NetworkWatcherRG)
// Replaces NSG flow logs (retired June 2025). VNet flow logs capture all
// traffic in the virtual network, including traffic not covered by NSGs.
//
// Creates the Network Watcher if it doesn't already exist for the region.

param location string
param vnet1Id string
param vnet1Name string
param vnet2Id string
param vnet2Name string
param storageAccountId string
param logAnalyticsWorkspaceId string

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-05-01' = {
  name: 'NetworkWatcher_${location}'
  location: location
}

resource vnet1FlowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = {
  parent: networkWatcher
  name: '${vnet1Name}-flowlog'
  location: location
  properties: {
    targetResourceId: vnet1Id
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

resource vnet2FlowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = {
  parent: networkWatcher
  name: '${vnet2Name}-flowlog'
  location: location
  properties: {
    targetResourceId: vnet2Id
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
