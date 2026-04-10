// main.bicep - Azure 101 Lab orchestrator (subscription-scoped)
// Deploys shared RG + single lab RG with baked-in troubleshooting faults
// Deploy once per group subscription (each group = 3 students sharing one subscription)
// All students in a group collaborate in a breakout room on the same set of resources.
//
// Usage:
//   az deployment sub create \
//     --location <region> \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters.bicepparam

targetScope = 'subscription'

// ============================================================
// PARAMETERS
// ============================================================

@description('Base name for the lab. Used to derive resource group and resource names.')
param labName string = 'azure101lab'

@description('Azure region for all resources.')
param location string

@description('Admin username for all lab VMs.')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for all lab VMs. Must meet Azure complexity requirements.')
param adminPassword string

@description('Optional: Object ID of a Microsoft Entra group or user to assign Contributor role on the lab RG. Leave empty to skip.')
param studentPrincipalId string = ''

@description('Principal type for the student RBAC assignment.')
@allowed(['Group', 'User'])
param studentPrincipalType string = 'Group'

@description('Contact email for budget and metric alert notifications.')
param alertEmail string = ''

@description('Budget start date (first of current month). Auto-generated - do not override.')
param budgetStartDate string = '${substring(utcNow('yyyy-MM-dd'), 0, 8)}01'

@description('VM size for lab VMs. Change if SKU is unavailable in your region.')
param vmSize string = 'Standard_D2alds_v7'

// ============================================================
// RESOURCE GROUPS
// ============================================================

resource sharedRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${labName}-shared-rg'
  location: location
}

resource labRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${labName}-rg'
  location: location
}

// ============================================================
// SHARED RESOURCES (in shared RG)
// Log Analytics workspace, Managed Identity
// NOTE: The DCR is deployed separately (after lab resources) to avoid
//       a race condition where the LAW tables haven't initialized yet.
// ============================================================

module shared 'modules/shared.bicep' = {
  name: 'shared-resources'
  scope: sharedRg
  params: {
    location: location
    labName: labName
  }
}

// ============================================================
// POLICY: Tag enforcement at subscription scope
// Audits resources missing required Department and Environment tags
// ============================================================

module policy 'modules/policy.bicep' = {
  name: 'policy-assignments'
  params: {
    location: location
  }
}

// ============================================================
// BUDGET: Subscription-level spending threshold
// ============================================================

resource labBudget 'Microsoft.Consumption/budgets@2023-11-01' = if (!empty(alertEmail)) {
  name: '${labName}-monthly-budget'
  properties: {
    timePeriod: {
      startDate: budgetStartDate
    }
    timeGrain: 'Monthly'
    amount: 50
    category: 'Cost'
    notifications: {
      actual80pct: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        contactEmails: [alertEmail]
        thresholdType: 'Actual'
      }
      actual100pct: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        contactEmails: [alertEmail]
        thresholdType: 'Actual'
      }
    }
  }
}

// ============================================================
// ACTIVITY LOG -> Log Analytics diagnostic setting
// Forwards subscription Activity Log to the shared workspace for KQL queries
// ============================================================

resource activityLogDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${labName}-activity-to-law'
  properties: {
    workspaceId: shared.outputs.logAnalyticsWorkspaceId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
  }
}

// ============================================================
// RBAC: Managed identity -> Contributor on lab RG
// Required for the fault-injection script to configure VMs
// ============================================================

module identityRole 'modules/role-assignment.bicep' = {
  name: 'identity-role'
  scope: labRg
  params: {
    principalId: shared.outputs.scriptIdentityPrincipalId
    builtInRoleId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    principalType: 'ServicePrincipal'
  }
}

// ============================================================
// LAB ENVIRONMENT (single RG for the group)
// All students collaborate on the same resources:
// 2 VNets (peered), 2 VMs, NSGs, Bastion, data disk, storage account
// ============================================================

module labEnvironment 'modules/user-environment.bicep' = {
  name: 'lab-environment'
  scope: labRg
  params: {
    labName: labName
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    logAnalyticsWorkspaceId: shared.outputs.logAnalyticsWorkspaceId
    alertEmail: alertEmail
    vmSize: vmSize
    scriptIdentityId: shared.outputs.scriptIdentityId
    scriptIdentityPrincipalId: shared.outputs.scriptIdentityPrincipalId
  }
}

// ============================================================
// DATA COLLECTION RULE (in shared RG)
// Deployed AFTER lab resources to give the LAW time to initialize
// its built-in Perf and Syslog tables. Without this delay, the DCR
// fails with InvalidOutputTable because the tables don't exist yet.
// ============================================================

module dcr 'modules/dcr.bicep' = {
  name: 'data-collection-rule'
  scope: sharedRg
  params: {
    location: location
    labName: labName
    logAnalyticsWorkspaceId: shared.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [labEnvironment] // ensures LAW has time to fully initialize
}

// ============================================================
// DCR ASSOCIATIONS (in lab RG)
// Links both VMs to the DCR after AMA agent is installed
// ============================================================

module dcrAssociations 'modules/dcr-associations.bicep' = {
  name: 'dcr-associations'
  scope: labRg
  params: {
    vm1Name: '${labName}-vm1'
    vm2Name: '${labName}-vm2'
    dataCollectionRuleId: dcr.outputs.dataCollectionRuleId
  }
}

// ============================================================
// FAULT INJECTION (in lab RG — native VM extensions + run commands)
// Installs CPU-spike cron job on VM1, fills data disk to >80%,
// uploads test blob using managed identity auth.
// Uses VM extensions and run commands instead of deploymentScripts
// to avoid Azure Policy conflicts with storage account key auth.
// ============================================================

module faultInjection 'modules/fault-injection.bicep' = {
  name: 'inject-faults'
  scope: labRg
  params: {
    vm1Name: '${labName}-vm1'
    storageAccountName: labEnvironment.outputs.storageAccountName
    location: location
    scriptIdentityClientId: shared.outputs.scriptIdentityClientId
  }
  dependsOn: [identityRole]
}

// ============================================================
// VNET FLOW LOGS (in NetworkWatcherRG)
// NSG flow logs are retired; VNet flow logs replace them.
// NetworkWatcherRG is referenced as existing because it may already
// exist in a different location from a previous deployment.
// Prerequisite: az network watcher configure --locations <region> --enabled true
// ============================================================

resource networkWatcherRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'NetworkWatcherRG'
}

module flowLogs 'modules/flow-logs.bicep' = {
  name: 'vnet-flow-logs'
  scope: networkWatcherRg
  params: {
    location: location
    vnet1Id: labEnvironment.outputs.vnet1Id
    vnet1Name: labEnvironment.outputs.vnet1Name
    vnet2Id: labEnvironment.outputs.vnet2Id
    vnet2Name: labEnvironment.outputs.vnet2Name
    storageAccountId: labEnvironment.outputs.storageAccountId
    logAnalyticsWorkspaceId: shared.outputs.logAnalyticsWorkspaceId
  }
}

// ============================================================
// RBAC: Student Contributor on the lab RG (Optional)
// Contributor covers control plane but NOT data plane (storage blob access)
// The data-plane gap is the RBAC challenge in Module 6
// ============================================================

module studentContributor 'modules/role-assignment.bicep' = if (!empty(studentPrincipalId)) {
  name: 'student-contributor'
  scope: labRg
  params: {
    principalId: studentPrincipalId
    builtInRoleId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    principalType: studentPrincipalType
  }
}

// ============================================================
// OUTPUTS
// ============================================================

output sharedResourceGroup string = sharedRg.name
output labResourceGroup string = labRg.name
output labWorkspaceId string = shared.outputs.logAnalyticsWorkspaceId
output vm1Name string = labEnvironment.outputs.vm1Name
output vm2Name string = labEnvironment.outputs.vm2Name
output vm1PrivateIp string = labEnvironment.outputs.vm1PrivateIp
output vm2PrivateIp string = labEnvironment.outputs.vm2PrivateIp
output vnet1AddressSpace string = labEnvironment.outputs.vnet1AddressSpace
output vnet2AddressSpace string = labEnvironment.outputs.vnet2AddressSpace
output storageAccount string = labEnvironment.outputs.storageAccountName
