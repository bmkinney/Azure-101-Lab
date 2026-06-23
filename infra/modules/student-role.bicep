// student-role.bicep - Custom RBAC role for lab students (subscription scope)
//
// Replaces the previous "Contributor on the lab RG + manual subscription Reader"
// model. Each group has a dedicated subscription, so a single custom role assigned
// at the subscription scope gives students everything they need for Modules 1-8
// while removing the two capabilities that broke the lab's teaching objectives:
//
//   1. Storage account key access (listKeys / regenerateKey) - issue #14.
//      Without these, students cannot retrieve the access key to upload blobs via
//      shared-key auth, so Module 6 (control-plane vs data-plane RBAC) stays intact.
//      The only path to blob upload is self-assigning Storage Blob Data Contributor
//      via the separate, ABAC-restricted RBAC Admin grant (storage-rbac-admin.bicep).
//
//   2. Role-assignment writes (Microsoft.Authorization/*/Write|Delete) - students
//      cannot grant themselves higher roles anywhere. The only RBAC write they can
//      perform is the narrowly scoped, condition-restricted Storage Blob Data grant.
//
// The role is modeled as "Contributor minus" - it keeps Contributor's full NotActions
// deny-list and adds the two storage key actions. Subscription scope (vs the old
// RG scope) also resolves the cross-RG scope gaps in Modules 4 and 5 (issues #15/#16),
// where the DCR/Log Analytics workspace and policy remediation live outside the lab RG.

targetScope = 'subscription'

@description('Principal ID (object ID) of the student group or user to assign the custom role to.')
param principalId string

@description('Principal type for the role assignment.')
@allowed(['Group', 'User', 'ServicePrincipal'])
param principalType string = 'Group'

// Custom role definition: Contributor-equivalent control plane, minus storage key
// access. The display name includes the subscription ID because custom role display
// names must be unique within the Entra directory and each group subscription deploys
// its own copy.
resource studentRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'azure101-lab-student-role')
  properties: {
    roleName: 'Azure 101 Lab Student - ${subscription().subscriptionId}'
    description: 'Lab student role: Contributor-equivalent control plane minus storage account key access and role-assignment writes. Grants no storage data-plane access, preserving the Module 6 RBAC teaching objective.'
    type: 'CustomRole'
    assignableScopes: [
      subscription().id
    ]
    permissions: [
      {
        actions: [
          '*'
        ]
        notActions: [
          // --- Contributor's built-in deny-list (kept verbatim) ---
          'Microsoft.Authorization/*/Delete'
          'Microsoft.Authorization/*/Write'
          'Microsoft.Authorization/elevateAccess/Action'
          'Microsoft.Blueprint/blueprintAssignments/write'
          'Microsoft.Blueprint/blueprintAssignments/delete'
          'Microsoft.Compute/galleries/share/action'
          'Microsoft.Purview/consents/write'
          'Microsoft.Purview/consents/delete'
          'Microsoft.Resources/deploymentStacks/manageDenySetting/action'
          'Microsoft.Subscription/cancel/action'
          'Microsoft.Subscription/enable/action'
          // --- Lab additions: block storage key access (issue #14) ---
          'Microsoft.Storage/storageAccounts/listkeys/action'
          'Microsoft.Storage/storageAccounts/regeneratekey/action'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

resource studentRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, studentRoleDef.id)
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: studentRoleDef.id
  }
}

output roleDefinitionId string = studentRoleDef.id
output roleName string = studentRoleDef.properties.roleName
