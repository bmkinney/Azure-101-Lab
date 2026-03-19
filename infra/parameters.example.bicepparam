using 'main.bicep'

param userPrefixes = [
  'userA'
  'userB'
  'userC'
]

param location = 'eastus'

param adminUsername = 'azureuser'

param adminPassword = '<REPLACE-with-strong-password>'

// Optional: Set to the Object ID of a Microsoft Entra group containing all students
// This assigns Reader role on the resource group (intentionally insufficient for RBAC scenario)
// Leave empty to skip RBAC assignment via Bicep
param studentPrincipalId = ''
param studentPrincipalType = 'Group'
