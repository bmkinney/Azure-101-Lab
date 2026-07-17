using 'main.bicep'

// Deploy once per group subscription. Each group = up to 3 students sharing one subscription
// and one resource group. All students collaborate on the same set of resources via a breakout room.

param labName = 'azure101lab'

param location = 'eastus'

param adminUsername = 'azureuser'

param adminPassword = '<REPLACE-with-strong-password>'

// Optional: Set to the Object ID of a Microsoft Entra group containing all students in this group.
// This assigns a custom "Azure 101 Lab Student" role at the SUBSCRIPTION scope.
// The role is Contributor-equivalent control plane MINUS storage account key access and
// role-assignment writes — so students cannot bypass the Module 6 data-plane lesson with
// the storage key, and cannot grant themselves higher roles. Subscription scope lets them
// edit shared-rg DCRs/diagnostics (Module 4) and run policy remediation (Module 5).
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
