// role-assignment.bicep - Generic role assignment module
// Reused for both managed identity (Contributor) and student (Contributor) role assignments

@description('Principal ID (object ID) to assign the role to.')
param principalId string

@description('Built-in role definition GUID (e.g., acdd72a7-... for Reader).')
param builtInRoleId string

@description('Type of the principal.')
@allowed(['ServicePrincipal', 'Group', 'User'])
param principalType string = 'ServicePrincipal'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, builtInRoleId)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtInRoleId)
    principalType: principalType
  }
}
