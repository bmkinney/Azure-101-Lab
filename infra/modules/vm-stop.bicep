// vm-stop.bicep - Deployment script to deallocate VMs after creation
// Uses a user-assigned managed identity with Contributor on the resource group
// FAULT: VMs are left in a deallocated state for students to discover

@description('Comma-separated list of VM names to deallocate.')
param vmNameList string

@description('Resource group containing the VMs.')
param resourceGroupName string

@description('Azure region for the deployment script resource.')
param location string

@description('Resource ID of the user-assigned managed identity.')
param scriptIdentityId string

resource deallocateVms 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'deallocate-lab-vms'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.60.0'
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
#!/bin/bash
set -e
echo "Deallocating lab VMs..."
IFS=',' read -ra VMS <<< "$VM_NAMES"
for vm in "${VMS[@]}"; do
  echo "Deallocating $vm in resource group $RG_NAME..."
  az vm deallocate --resource-group "$RG_NAME" --name "$vm" --no-wait || echo "Warning: failed to deallocate $vm"
done
echo "Deallocate commands issued for all lab VMs."
'''
    environmentVariables: [
      {
        name: 'VM_NAMES'
        value: vmNameList
      }
      {
        name: 'RG_NAME'
        value: resourceGroupName
      }
    ]
  }
}
