# Resource Map

## Pre-deployed lab environment

The lab uses a multi-resource-group architecture:

- **Shared resource group** (`azure101lab-shared-rg`): contains resources shared across all participants
- **Per-student resource groups** (`azure101lab-<prefix>-rg`): each student gets their own isolated resource group

### Per-user resources (in `azure101lab-<prefix>-rg`)
- 1 VNet with 2 subnets (management and workload)
- 1 NSG (associated to workload subnet)
- 1 route table (associated to workload subnet)
- 1 NIC (in workload subnet, no public IP)
- 1 Ubuntu VM on `Standard_B1s` (deployed with intentional issues)
- 1 storage account (boot diagnostics)

### Shared resources (in `azure101lab-shared-rg`)
- 1 Log Analytics workspace (shared across all participants for KQL exercises)
- 1 Data Collection Rule (connects VMs to the workspace)
- 1 User-assigned managed identity (used by deployment script)

## Relationship summary

- the VM uses a NIC
- the NIC connects the VM to the workload subnet
- the workload subnet exists inside the VNet
- an NSG is associated to the workload subnet
- a route table is associated to the workload subnet
- the VM NIC does not have a direct public IP
- the storage account is used for boot diagnostics
- the shared Log Analytics workspace collects telemetry from all participant VMs via Azure Monitor Agent

## Troubleshooting impact map

### VM problem
Check:
- VM power state (running vs deallocated)
- provisioning state
- extension status
- boot diagnostics
- Activity Log

### Connectivity problem
Check:
- subnet selection
- NSG association and rules
- effective security rules
- route table association and routes
- effective routes on NIC

### Permission problem
Check:
- role assignment
- scope (resource, resource group, subscription)
- inherited access

### Governance problem
Check:
- policy compliance
- missing tags
- naming, region, or SKU constraints

### Cost concern
Check:
- unused resources
- oversized SKUs
- resources that cost money even when VM is deallocated (disks, storage)
