using 'main.bicep'

// Deploy once per group subscription. Each group = up to 3 students sharing one subscription
// and one resource group. All students collaborate on the same set of resources via a breakout room.

param labName = 'azure101lab'

param location = 'eastus'

param adminUsername = 'azureuser'

param adminPassword = '<REPLACE-with-strong-password>'

// Optional: Set to the Object ID of a Microsoft Entra group containing all students in this group.
// This assigns Contributor role on the lab resource group.
// Contributor covers control-plane operations but NOT storage data-plane (blob upload/download).
// The data-plane gap is the RBAC challenge in Module 6.
// Leave empty to skip RBAC assignment via Bicep.
param studentPrincipalId = ''
param studentPrincipalType = 'Group'

// Contact email for budget alerts and metric alert notifications.
// Leave empty to skip budget and alert email configuration.
param alertEmail = ''

// VM size for lab VMs. Must be 1 vCPU for Module 1 CPU spike scenario.
// Override if Standard_B1s is unavailable in your region (e.g., Standard_B1ls_v2).
// param vmSize = 'Standard_B1s'
