// policy.bicep - Azure Policy assignments for tag enforcement
// Scope: subscription (deployed from main.bicep)
// Effect: Audit — students can observe non-compliance without being blocked
//
// Module 5 fault: Resources are missing required tags. Students must identify
// non-compliant resources via Policy > Compliance and apply tags.

targetScope = 'subscription'

@description('Azure region for the assignment metadata.')
param location string

// --- Built-in Policy: "Require a tag on resources" ---
// Policy Definition ID: 871b6d14-10aa-478d-b466-ce391a7bc4db

resource auditDepartmentTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'audit-department-tag'
  location: location
  properties: {
    displayName: 'Audit resources missing Department tag'
    description: 'Audits any resource that does not have a Department tag applied.'
    policyDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/policyDefinitions',
      '871b6d14-10aa-478d-b466-ce391a7bc4db'
    )
    parameters: {
      tagName: {
        value: 'Department'
      }
    }
    enforcementMode: 'Default'
  }
}

resource auditEnvironmentTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'audit-environment-tag'
  location: location
  properties: {
    displayName: 'Audit resources missing Environment tag'
    description: 'Audits any resource that does not have an Environment tag applied.'
    policyDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/policyDefinitions',
      '871b6d14-10aa-478d-b466-ce391a7bc4db'
    )
    parameters: {
      tagName: {
        value: 'Environment'
      }
    }
    enforcementMode: 'Default'
  }
}
