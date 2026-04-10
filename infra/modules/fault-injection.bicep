// fault-injection.bicep - Post-deployment fault injection using native VM resources
// Uses VM extensions and run commands instead of deploymentScripts to avoid
// Azure Policy conflicts with storage account key-based authentication.
//
// FAULTS INJECTED:
//   1. CPU spike cron job on VM1 — pegs 2 vCPUs at 100% for 10 min every hour
//   2. Data disk on VM1 — formatted, mounted, filled to >80%
//   3. Test blob uploaded to storage account (for Module 6 RBAC + Module 7 audit)

@description('Name of VM1 (e.g., azure101lab-vm1).')
param vm1Name string

@description('Name of the storage account for blob upload.')
param storageAccountName string

@description('Azure region for resources.')
param location string

@description('Client ID of the user-assigned managed identity (for IMDS token).')
param scriptIdentityClientId string

// Reference the existing VM (deployed by user-environment.bicep)
resource vm1 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vm1Name
}

// --------------------------------------------------
// Fault 1: CPU spike cron job via CustomScript extension
// Installs stress tool and creates a cron job that runs every hour
// at minute 0, pegging 2 CPU cores for 10 minutes.
// On a Standard_D2alds_v7 (2 vCPU) this means 100% CPU during spike.
// Student fix: resize VM to a larger SKU so spike uses a smaller percentage of CPU.
// --------------------------------------------------

resource cpuSpike 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm1
  name: 'CpuSpikeCron'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y stress && echo \'0 * * * * root /usr/bin/stress --cpu 2 --timeout 600\' > /etc/cron.d/cpu-spike && chmod 644 /etc/cron.d/cpu-spike && /usr/bin/stress --cpu 2 --timeout 600 &'
    }
  }
}

// --------------------------------------------------
// Fault 2: Format, mount, and fill the data disk to >80%
// The 4 GB data disk is LUN 0 (/dev/sdc on these VMs).
// We partition, format, mount, then fill with ~3.4 GB using fallocate.
// --------------------------------------------------

resource diskFill 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm1
  name: 'FillDataDisk'
  location: location
  properties: {
    source: {
      script: 'if [ ! -b /dev/sdc1 ]; then echo "type=83" | sfdisk /dev/sdc && mkfs.ext4 /dev/sdc1; fi && mkdir -p /mnt/data && mount /dev/sdc1 /mnt/data && grep -q "/mnt/data" /etc/fstab || echo "/dev/sdc1 /mnt/data ext4 defaults 0 2" >> /etc/fstab && fallocate -l 3400M /mnt/data/app-logs.dat && echo "Disk filled"'
    }
    asyncExecution: false
    timeoutInSeconds: 300
  }
  dependsOn: [cpuSpike]
}

// --------------------------------------------------
// Fault 3: Upload a test blob to the storage account
// Uses the user-assigned managed identity attached to VM1 to get
// an access token from IMDS, then uploads via REST API.
// This avoids any dependency on storage account key-based auth.
// Creates evidence for Module 7 (storage access audit)
// and gives Module 6 a file to discover.
// --------------------------------------------------

resource blobUpload 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm1
  name: 'UploadTestBlob'
  location: location
  properties: {
    source: {
      script: 'TOKEN=$(curl -sf "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/&client_id=${scriptIdentityClientId}" -H "Metadata: true" | python3 -c \'import sys,json;print(json.load(sys.stdin)["access_token"])\') && echo "This is a test configuration file for the lab." | curl -sf -X PUT "https://${storageAccountName}.blob.core.windows.net/lab-data/config/app-settings.txt" -H "Authorization: Bearer \$TOKEN" -H "x-ms-blob-type: BlockBlob" -H "x-ms-version: 2020-10-02" -H "Content-Type: text/plain" --data-binary @- && echo "Blob uploaded"'
    }
    asyncExecution: false
    timeoutInSeconds: 120
  }
  dependsOn: [diskFill]
}
