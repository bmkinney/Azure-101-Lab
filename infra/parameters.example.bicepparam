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

// Contact emails for budget alerts and metric alert notifications.
// Accepts one or more addresses. Use a distro group when available; otherwise list
// individual addresses. Leave empty to skip budget and alert email configuration.
// Single:   param alertEmail = ['proctor@contoso.com']
// Multiple: param alertEmail = ['proctor@contoso.com', 'instructor@contoso.com']
param alertEmail = []

// VM size for lab VMs. Override if Standard_D2alds_v7 is unavailable in your region.
// param vmSize = 'Standard_D2alds_v7'
