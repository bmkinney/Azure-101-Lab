// dcr.bicep - Data Collection Rule for Azure Monitor Agent
// Deployed separately from the LAW to avoid the InvalidOutputTable race condition.
// The LAW needs time to initialize its built-in tables (Perf, Syslog) after creation.
// By deploying the DCR in its own module after other resources, the LAW has
// sufficient time to fully initialize before the DCR references those tables.

@description('Azure region for the DCR.')
param location string

@description('Base name prefix for resources.')
param labName string = 'azure101lab'

@description('Resource ID of the Log Analytics workspace.')
param logAnalyticsWorkspaceId string

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
          workspaceResourceId: logAnalyticsWorkspaceId
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

output dataCollectionRuleId string = dataCollectionRule.id
