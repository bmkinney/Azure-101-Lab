// vm-stop.bicep - Deployment script to deallocate VMs and inject extension fault
// Uses a user-assigned managed identity with Contributor on the resource group
// FAULTS:
//   1. VMs are left in a deallocated state for students to discover
//   2. A FailedCustomScript extension is installed (runs a non-existent script)

@description('Comma-separated list of VM names to deallocate.')
param vmNameList string

@description('Resource group containing the VMs.')
param resourceGroupName string

@description('Azure region for the deployment script resource.')
param location string

@description('Resource ID of the user-assigned managed identity.')
param scriptIdentityId string

@description('Azure Resource Manager endpoint URL.')
param armEndpoint string

@description('Azure subscription ID for REST API calls.')
param subscriptionId string

resource faultInjection 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'inject-lab-faults'
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

echo "=== Injecting lab faults ==="

IFS=',' read -ra VMS <<< "$VM_NAMES"

# Fault 2: Install a FailedCustomScript extension on each VM (before deallocating)
# Uses REST API to set a custom extension instance name (FailedCustomScript)
echo "--- Installing FailedCustomScript extensions ---"
for vm in "${VMS[@]}"; do
  echo "Installing FailedCustomScript on $vm..."

  cat > /tmp/ext-body.json << EOF
{
  "location": "${LOCATION}",
  "properties": {
    "publisher": "Microsoft.Azure.Extensions",
    "type": "CustomScript",
    "typeHandlerVersion": "2.1",
    "autoUpgradeMinorVersion": true,
    "settings": {
      "commandToExecute": "/opt/nonexistent-setup-script.sh"
    }
  }
}
EOF

  az rest --method PUT \
    --headers "Content-Type=application/json" \
    --url "${ARM_ENDPOINT}subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Compute/virtualMachines/${vm}/extensions/FailedCustomScript?api-version=2024-07-01" \
    --body @/tmp/ext-body.json \
    2>&1 || echo "Expected: FailedCustomScript failed on $vm (this is intentional)"
done

# Fault 1: Deallocate all VMs
echo "--- Deallocating lab VMs ---"
for vm in "${VMS[@]}"; do
  echo "Deallocating $vm..."
  az vm deallocate --resource-group "$RG_NAME" --name "$vm" --no-wait || echo "Warning: failed to deallocate $vm"
done

echo "=== Fault injection complete ==="
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
      {
        name: 'SUB_ID'
        value: subscriptionId
      }
      {
        name: 'ARM_ENDPOINT'
        value: armEndpoint
      }
      {
        name: 'LOCATION'
        value: location
      }
    ]
  }
}
