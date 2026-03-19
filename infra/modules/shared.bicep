// shared.bicep - Shared resources for the Azure 101 Lab
// Deploys: Log Analytics workspace, user-assigned managed identity for deployment scripts

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

// --- Data Collection Rule for Azure Monitor Agent ---
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${labName}-dcr'
  location: location
  properties: {
    dataSources: {
      performanceCounters: [
        {
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor Information(_Total)\\% Processor Time'
            '\\Memory\\Available Bytes'
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
