// fault-injection.bicep - Post-deployment fault injection script
// Uses a user-assigned managed identity with Contributor on the lab RG
// FAULTS INJECTED:
//   1. CPU spike cron job on VM1 — pegs 2 vCPUs at 100% for 10 min every hour
//   2. Data disk on VM1 — formatted, mounted, filled to >80%
//   3. Test blob uploaded to storage account (for Module 6 RBAC + Module 7 audit)

@description('Name of VM1 to inject faults on (e.g., azure101lab-vm1).')
param vmName string

@description('Resource group containing the lab VMs.')
param vmResourceGroup string

@description('Name of the storage account for blob upload.')
param storageAccountName string

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
echo "=== Processing $VM_NAME in $VM_RG ==="

# --------------------------------------------------
# Fault 1: Install CPU spike cron job via CustomScript
# Installs stress tool and creates a cron job that runs every hour
# at minute 0, pegging 2 CPU cores for 10 minutes.
# On a Standard_D2alds_v7 (2 vCPU) this means 100% CPU during spike.
# Student fix: resize VM to a larger SKU so spike uses a smaller percentage of CPU.
# --------------------------------------------------
echo "--- Installing CPU spike cron job on $VM_NAME ---"
cat > /tmp/cpu-spike-body.json << EOF
{
  "location": "${LOCATION}",
  "properties": {
    "publisher": "Microsoft.Azure.Extensions",
    "type": "CustomScript",
    "typeHandlerVersion": "2.1",
    "autoUpgradeMinorVersion": true,
    "settings": {
      "commandToExecute": "apt-get update && apt-get install -y stress && echo '0 * * * * root /usr/bin/stress --cpu 2 --timeout 600' > /etc/cron.d/cpu-spike && chmod 644 /etc/cron.d/cpu-spike && /usr/bin/stress --cpu 2 --timeout 600 &"
    }
  }
}
EOF

az rest --method PUT \
  --headers "Content-Type=application/json" \
  --url "${ARM_ENDPOINT}subscriptions/${SUB_ID}/resourceGroups/${VM_RG}/providers/Microsoft.Compute/virtualMachines/${VM_NAME}/extensions/CpuSpikeCron?api-version=2024-07-01" \
  --body @/tmp/cpu-spike-body.json \
  2>&1 || echo "Warning: CpuSpikeCron setup on $VM_NAME may have issues"

# --------------------------------------------------
# Fault 2: Format, mount, and fill the data disk to >80%
# The 4 GB data disk is LUN 0. We partition, format, mount,
# then fill with ~3.4 GB of data using fallocate.
# Use Run Command (avoids CustomScript conflict with Fault 1).
# --------------------------------------------------
echo "--- Filling data disk on $VM_NAME ---"
az vm run-command invoke \
  --resource-group "$VM_RG" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts 'DISK=/dev/sdc; if [ ! -b ${DISK}1 ]; then echo "type=83" | sfdisk ${DISK} && mkfs.ext4 ${DISK}1; fi && mkdir -p /mnt/data && mount ${DISK}1 /mnt/data && grep -q "/mnt/data" /etc/fstab || echo "${DISK}1 /mnt/data ext4 defaults 0 2" >> /etc/fstab && fallocate -l 3400M /mnt/data/app-logs.dat && echo "Disk filled"' \
  2>&1 || echo "Warning: disk fill on $VM_NAME may have issues"

# --------------------------------------------------
# Fault 3: Upload a test blob to the storage account
# This creates evidence for Module 7 (storage access audit)
# and gives Module 6 a file to attempt to download.
# --------------------------------------------------
echo "--- Uploading test blob ---"
echo "This is a test configuration file for the lab." > /tmp/test-config.txt
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "lab-data" \
  --name "config/app-settings.txt" \
  --file "/tmp/test-config.txt" \
  --auth-mode key \
  2>&1 || echo "Warning: blob upload may have issues"

echo "=== Fault injection complete ==="
'''
    environmentVariables: [
      {
        name: 'VM_NAME'
        value: vmName
      }
      {
        name: 'VM_RG'
        value: vmResourceGroup
      }
      {
        name: 'STORAGE_ACCOUNT'
        value: storageAccountName
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
