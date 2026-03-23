using 'main.bicep'

param labName = 'azure101lab'

param userPrefixes = [
  'userA'
  'userB'
  'userC'
]

param location = 'eastus'

param adminUsername = 'azureuser'

param adminPassword = '<REPLACE-with-strong-password>'

// Optional: Set to the Object ID of a Microsoft Entra group containing all students
// This assigns Reader role on each student resource group (intentionally insufficient for RBAC scenario)
// Leave empty to skip RBAC assignment via Bicep
param studentPrincipalId = ''
param studentPrincipalType = 'Group'
