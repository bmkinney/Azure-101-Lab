// main.bicep - Azure 101 Lab orchestrator
// Deploys shared resources and per-user lab environments with baked-in faults
//
// Usage:
//   az deployment group create \
//     --resource-group <rg-name> \
//     --template-file infra/main.bicep \
//     --parameters infra/parameters.example.bicepparam

targetScope = 'resourceGroup'

// ============================================================
// PARAMETERS
// ============================================================

@description('Array of user prefixes to deploy environments for (e.g., ["userA", "userB", "userC"]).')
param userPrefixes array

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

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
// SHARED RESOURCES
// Log Analytics workspace, Data Collection Rule, Managed Identity
// ============================================================

module shared 'modules/shared.bicep' = {
  name: 'shared-resources'
  params: {
    location: location
  }
}

// ============================================================
// PER-USER ENVIRONMENTS
// Each user gets: VNet, subnets, NSG (deny rule), route table (blackhole),
// NIC, VM (failed extension), storage account
// ============================================================

var vmNames = [for (prefix, i) in userPrefixes: '${prefix}-vm']
var vmNameList = join(vmNames, ',')

module userEnvironments 'modules/user-environment.bicep' = [for (prefix, i) in userPrefixes: {
  name: 'env-${prefix}'
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
// VM DEALLOCATE SCRIPT
// Runs after all VMs are deployed to stop them (VM troubleshooting fault)
// ============================================================

module vmStop 'modules/vm-stop.bicep' = {
  name: 'deallocate-vms'
  params: {
    vmNameList: vmNameList
    resourceGroupName: resourceGroup().name
    location: location
    scriptIdentityId: shared.outputs.scriptIdentityId
  }
  dependsOn: [userEnvironments]
}

// ============================================================
// RBAC ASSIGNMENT (Optional)
// Assigns Reader role to the student principal on the resource group
// FAULT: Reader is insufficient — students need Contributor to remediate issues
// ============================================================

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(studentPrincipalId)) {
  name: guid(resourceGroup().id, studentPrincipalId, 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  properties: {
    principalId: studentPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalType: studentPrincipalType
  }
}

// ============================================================
// OUTPUTS
// ============================================================

output labWorkspaceId string = shared.outputs.logAnalyticsWorkspaceId
output deployedUsers array = [for (prefix, i) in userPrefixes: {
  userPrefix: prefix
  vmName: userEnvironments[i].outputs.vmName
  privateIp: userEnvironments[i].outputs.nicPrivateIp
  vnetAddressSpace: userEnvironments[i].outputs.vnetAddressSpace
  storageAccount: userEnvironments[i].outputs.storageAccountName
}]
