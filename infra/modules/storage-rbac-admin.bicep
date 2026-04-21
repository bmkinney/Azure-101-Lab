// storage-rbac-admin.bicep - Grants Role Based Access Control Administrator
// to the student principal, scoped to a single storage account, with an ABAC
// condition that limits assignable roles to Storage Blob Data Reader/Contributor.
//
// Purpose (Module 6): students have Contributor on the lab RG, which lacks
// Microsoft.Authorization/*/Write. They need a way to grant themselves
// Storage Blob Data Contributor without giving them Owner/User Access
// Administrator. RBAC Administrator with a role-restriction condition
// preserves the teaching moment while enforcing least privilege.

@description('Principal ID (object ID) to grant scoped RBAC Admin to.')
param principalId string

@description('Principal type for the assignment.')
@allowed(['Group', 'User', 'ServicePrincipal'])
param principalType string = 'Group'

@description('Name of the storage account that will be the assignment scope.')
param storageAccountName string

// Built-in role: Role Based Access Control Administrator
var rbacAdminRoleId = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'

// Assignable roles students may grant (GUIDs, not full resource IDs, per ABAC syntax)
var storageBlobDataReader = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var storageBlobDataContrib = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource rbacAdminScoped 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, principalId, rbacAdminRoleId, 'blob-data-only')
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', rbacAdminRoleId)
    description: 'Lab: allow students to self-assign only Storage Blob Data roles on this storage account'
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${storageBlobDataReader}, ${storageBlobDataContrib}})) AND ((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/delete\'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${storageBlobDataReader}, ${storageBlobDataContrib}}))'
  }
}
