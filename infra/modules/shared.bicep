// shared.bicep - Shared resources for the Azure 101 Lab
// Deploys: Log Analytics workspace, Data Collection Rule (platform VM metrics + syslog),
//          user-assigned managed identity for deployment scripts

@description('Azure region for all shared resources.')
param location string

@description('Base name prefix for shared resources.')
param labName string = 'azure101lab'

// --- Log Analytics Workspace ---
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${labName}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// --- Ensure LAW tables exist before DCR references them ---
// Prevents race condition where DCR deploys before Perf/Syslog tables are initialized
resource perfTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: logAnalyticsWorkspace
  name: 'Perf'
  properties: {
    retentionInDays: 30
  }
}

resource syslogTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: logAnalyticsWorkspace
  name: 'Syslog'
  properties: {
    retentionInDays: 30
  }
}

// --- Data Collection Rule for Azure Monitor Agent ---
// Captures platform VM metrics (CPU, memory, disk, network) and syslog
// Used by Modules 1, 3, 4 for performance trending and KQL exercises
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${labName}-dcr'
  location: location
  dependsOn: [perfTable, syslogTable]
  properties: {
    dataSources: {
      performanceCounters: [
        {
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor Information(_Total)\\% Processor Time'
            '\\Processor Information(_Total)\\% User Time'
            '\\Memory\\Available Bytes'
            '\\Memory\\% Used Memory'
            '\\LogicalDisk(*)\\% Used Space'
            '\\LogicalDisk(*)\\Free Megabytes'
            '\\LogicalDisk(*)\\Disk Reads/sec'
            '\\LogicalDisk(*)\\Disk Writes/sec'
            '\\Network Interface(*)\\Bytes Total/sec'
          ]
          name: 'perfCounterDataSource'
        }
      ]
      syslog: [
        {
          streams: ['Microsoft-Syslog']
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'kern'
            'syslog'
          ]
          logLevels: [
            'Alert'
            'Critical'
            'Emergency'
            'Error'
            'Warning'
            'Notice'
            'Info'
          ]
          name: 'syslogDataSource'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'lawDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-Perf', 'Microsoft-Syslog']
        destinations: ['lawDestination']
      }
    ]
  }
}

// --- User-Assigned Managed Identity for Deployment Scripts ---
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${labName}-script-identity'
  location: location
}

// --- Outputs ---
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output dataCollectionRuleId string = dataCollectionRule.id
output scriptIdentityId string = scriptIdentity.id
output scriptIdentityPrincipalId string = scriptIdentity.properties.principalId
