// main.bicep - Azure 101 Lab orchestrator (subscription-scoped)
// Deploys shared RG + per-student RGs with baked-in troubleshooting faults
//
// Usage:
//   az deployment sub create \
//     --location <region> \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters.example.bicepparam

targetScope = 'subscription'

// ============================================================
// PARAMETERS
// ============================================================

@description('Base name for the lab. Used to derive resource group names.')
param labName string = 'azure101lab'

@description('Array of user prefixes to deploy environments for (e.g., ["userA", "userB", "userC"]).')
param userPrefixes array

@description('Azure region for all resources.')
param location string

@description('Admin username for all lab VMs.')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for all lab VMs. Must meet Azure complexity requirements.')
param adminPassword string

@description('Optional: Object ID of a Microsoft Entra group or user to assign Reader role for RBAC scenario. Leave empty to skip RBAC assignment.')
param studentPrincipalId string = ''

@description('Principal type for the RBAC assignment. Use "Group" for an Entra group or "User" for individual users.')
@allowed(['Group', 'User'])
param studentPrincipalType string = 'Group'

// ============================================================
// RESOURCE GROUPS
// ============================================================

resource sharedRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${labName}-shared-rg'
  location: location
}

resource studentRgs 'Microsoft.Resources/resourceGroups@2024-03-01' = [for prefix in userPrefixes: {
  name: '${labName}-${prefix}-rg'
  location: location
}]

// ============================================================
// SHARED RESOURCES (in shared RG)
// Log Analytics workspace, Data Collection Rule, Managed Identity
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
// RBAC: Managed identity → Contributor on each student RG
// Required for the fault-injection script to deallocate VMs and
// install extensions in student resource groups
// ============================================================

module identityRole 'modules/role-assignment.bicep' = [for (prefix, i) in userPrefixes: {
  name: 'identity-role-${prefix}'
  scope: studentRgs[i]
  params: {
    principalId: shared.outputs.scriptIdentityPrincipalId
    builtInRoleId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    principalType: 'ServicePrincipal'
  }
}]

// ============================================================
// PER-USER ENVIRONMENTS (each in its own RG)
// Each user gets: VNet, subnets, NSG (deny rule), route table (blackhole),
// NIC, VM (failed extension), storage account
// ============================================================

module userEnvironments 'modules/user-environment.bicep' = [for (prefix, i) in userPrefixes: {
  name: 'env-${prefix}'
  scope: studentRgs[i]
  params: {
    userPrefix: prefix
    location: location
    addressIndex: i
    adminUsername: adminUsername
    adminPassword: adminPassword
    dataCollectionRuleId: shared.outputs.dataCollectionRuleId
  }
}]

// ============================================================
// FAULT INJECTION SCRIPT (in shared RG)
// Installs FailedCustomScript extension and deallocates VMs across student RGs
// ============================================================

var vmRgPairs = [for (prefix, i) in userPrefixes: '${prefix}-vm:${labName}-${prefix}-rg']
var vmRgPairList = join(vmRgPairs, ',')

module vmStop 'modules/vm-stop.bicep' = {
  name: 'inject-faults'
  scope: sharedRg
  params: {
    vmRgPairList: vmRgPairList
    location: location
    scriptIdentityId: shared.outputs.scriptIdentityId
    subscriptionId: subscription().subscriptionId
    armEndpoint: environment().resourceManager
  }
  dependsOn: [userEnvironments, identityRole]
}

// ============================================================
// RBAC: Student Reader on each student RG (Optional)
// FAULT: Reader is insufficient — students need Contributor to remediate issues
// ============================================================

module studentReader 'modules/role-assignment.bicep' = [for (prefix, i) in userPrefixes: if (!empty(studentPrincipalId)) {
  name: 'student-reader-${prefix}'
  scope: studentRgs[i]
  params: {
    principalId: studentPrincipalId
    builtInRoleId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
    principalType: studentPrincipalType
  }
}]

// ============================================================
// OUTPUTS
// ============================================================

output sharedResourceGroup string = sharedRg.name
output labWorkspaceId string = shared.outputs.logAnalyticsWorkspaceId
output deployedUsers array = [for (prefix, i) in userPrefixes: {
  userPrefix: prefix
  resourceGroup: studentRgs[i].name
  vmName: userEnvironments[i].outputs.vmName
  privateIp: userEnvironments[i].outputs.nicPrivateIp
  vnetAddressSpace: userEnvironments[i].outputs.vnetAddressSpace
  storageAccount: userEnvironments[i].outputs.storageAccountName
}]
