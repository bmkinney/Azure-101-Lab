// policy.bicep - Azure Policy assignments for tag enforcement + remediation
// Scope: subscription (deployed from main.bicep)
//
// Module 5 fault + objective: lab resources are deployed without the required
// Department and Environment tags. These two "Add or replace a tag on resources"
// Modify assignments mark every untagged resource as NON-COMPLIANT (so students still
// see the gap in Policy > Compliance) AND are remediable - students create a
// remediation task (portal or `az policy remediation create`) that stamps the missing
// tag. Audit/Deny "Require a tag" policies cannot be remediated, which is why this
// module uses the Modify effect (issue #16).
//
// Each Modify assignment needs a system-assigned managed identity. The built-in
// definition declares Contributor in its roleDefinitionIds, so each identity is granted
// Contributor at the subscription scope to allow the remediation to write tags.

targetScope = 'subscription'

@description('Azure region for the assignment metadata and managed identities.')
param location string

@description('Value applied by the Modify remediation for the Department tag.')
param departmentTagValue string = 'Engineering'

@description('Value applied by the Modify remediation for the Environment tag.')
param environmentTagValue string = 'Lab'

// Built-in Modify policy: "Add or replace a tag on resources"
var modifyTagPolicyId = '5ffd78d9-436d-4b41-a421-5baa819e3008'
// Built-in role required by the Modify policy's remediation identity (Contributor)
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// --- Department tag ---
resource departmentTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'modify-department-tag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Add missing Department tag (Modify)'
    description: 'Marks resources missing a Department tag as non-compliant and adds the tag when a remediation task runs.'
    policyDefinitionId: tenantResourceId(
      'Microsoft.Authorization/policyDefinitions',
      modifyTagPolicyId
    )
    parameters: {
      tagName: {
        value: 'Department'
      }
      tagValue: {
        value: departmentTagValue
      }
    }
  }
}

resource departmentTagRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'modify-department-tag', contributorRoleId)
  properties: {
    principalId: departmentTag.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// --- Environment tag ---
resource environmentTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'modify-environment-tag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Add missing Environment tag (Modify)'
    description: 'Marks resources missing an Environment tag as non-compliant and adds the tag when a remediation task runs.'
    policyDefinitionId: tenantResourceId(
      'Microsoft.Authorization/policyDefinitions',
      modifyTagPolicyId
    )
    parameters: {
      tagName: {
        value: 'Environment'
      }
      tagValue: {
        value: environmentTagValue
      }
    }
  }
}

resource environmentTagRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'modify-environment-tag', contributorRoleId)
  properties: {
    principalId: environmentTag.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalType: 'ServicePrincipal'
  }
}
