// shared.bicep - Shared resources for the Azure 101 Lab
// Deploys: Log Analytics workspace, user-assigned managed identity
// NOTE: The DCR is deployed separately (dcr.bicep) to avoid a race condition
//       where the LAW hasn't finished initializing its built-in tables (Perf, Syslog).

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

// --- User-Assigned Managed Identity for Fault Injection ---
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${labName}-script-identity'
  location: location
}

// --- Outputs ---
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output scriptIdentityId string = scriptIdentity.id
output scriptIdentityPrincipalId string = scriptIdentity.properties.principalId
output scriptIdentityClientId string = scriptIdentity.properties.clientId
