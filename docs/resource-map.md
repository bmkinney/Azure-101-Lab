# Resource Map

## Minimal v1 environment

Each participant should end the build phase with:
- 1 resource group
- 1 VNet
- 2 subnets
- 1 NSG
- 1 route table
- 1 NAT gateway
- 1 Standard public IP for the NAT gateway
- 1 Ubuntu VM on a small burstable SKU such as `Standard_B1s`
- 1 storage account

## Relationship summary

- the VM uses a NIC
- the NIC connects the VM to a subnet
- the subnet exists inside the VNet
- an NSG can be associated to the subnet or NIC
- a route table is associated to a subnet
- a NAT gateway is associated to the workload subnet for outbound internet access
- the VM NIC should not have a direct public IP
- the storage account is a separate resource but part of the same operational scope for the lab

## Troubleshooting impact map

### VM problem
Check:
- VM state
- provisioning state
- extension status
- boot diagnostics

### Connectivity problem
Check:
- subnet selection
- NSG association and rules
- route table association and routes
- NAT gateway association for outbound design validation

### Permission problem
Check:
- role assignment
- scope
- inherited access

### Governance problem
Check:
- policy error details
- naming, tags, region, or SKU constraints

### Cost concern
Check:
- unused resources
- oversized SKUs
- temporary resources left running
