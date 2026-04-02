// policy.bicep - Azure Policy assignments for tag enforcement
// Scope: subscription (deployed from main.bicep)
// Uses the built-in "Require a tag on resources" policy (Deny effect) with
// enforcementMode = DoNotEnforce so it audits without blocking deployments.
//
// Module 5 fault: Resources are missing required tags. Students must identify
// non-compliant resources via Policy > Compliance and apply tags.

targetScope = 'subscription'

@description('Azure region for the assignment metadata.')
param location string

// --- Built-in Policy: "Require a tag on resources" ---
// Policy Definition ID: 96670d01-0a4d-4649-9c89-2d3abc0a5025
// Effect: Deny (set enforcementMode to DoNotEnforce for audit-only behaviour)

resource auditDepartmentTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'audit-department-tag'
  location: location
  properties: {
    displayName: 'Audit resources missing Department tag'
    description: 'Audits any resource that does not have a Department tag applied.'
    policyDefinitionId: tenantResourceId(
      'Microsoft.Authorization/policyDefinitions',
      '96670d01-0a4d-4649-9c89-2d3abc0a5025'
    )
    parameters: {
      tagName: {
        value: 'Department'
      }
    }
    enforcementMode: 'DoNotEnforce'
  }
}

resource auditEnvironmentTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'audit-environment-tag'
  location: location
  properties: {
    displayName: 'Audit resources missing Environment tag'
    description: 'Audits any resource that does not have an Environment tag applied.'
    policyDefinitionId: tenantResourceId(
      'Microsoft.Authorization/policyDefinitions',
      '96670d01-0a4d-4649-9c89-2d3abc0a5025'
    )
    parameters: {
      tagName: {
        value: 'Environment'
      }
    }
    enforcementMode: 'DoNotEnforce'
  }
}
