# Build Checklist

Use this checklist during the build phase of the lab.

## Before you start
- confirm the subscription you will use
- confirm the resource group you will use or create
- confirm you have the required permissions
- confirm the naming prefix you will use

## Resource group
- resource group exists
- resource group is in the intended region
- tags are applied if required by policy

## Virtual network
- VNet created successfully
- address space documented
- address space does not overlap with your planned subnet ranges

## Subnets
- management subnet created
- workload subnet created
- subnet ranges are documented
- no overlap exists between subnets

## Network security group
- NSG created successfully
- inbound and outbound rules reviewed
- NSG association is understood and documented

## Route table
- route table created successfully
- custom routes reviewed
- subnet association confirmed

## NAT gateway
- NAT gateway created successfully
- Standard public IP created for the NAT gateway
- NAT gateway is associated to the workload subnet

## Virtual machine
- VM created successfully
- VM image is Ubuntu 22.04 or the approved Ubuntu image for the lab
- VM size is a small burstable SKU such as `Standard_B1s`
- VM is in the intended subnet
- VM NIC does not have a direct public IP attached
- power state is running
- provisioning state is successful
- portal-native admin access method is known, such as serial console or Run command
- boot diagnostics location is known

## Storage account
- storage account created successfully
- naming is compliant
- region and SKU are understood

## Monitoring access
- Activity Log location is known
- Log Analytics access is confirmed if available
- at least one KQL query location is known

## RBAC review
- you know where to view role assignments
- you know the difference between resource, resource group, and subscription scope

## Cost and policy review
- you checked for required tags or naming restrictions
- you reviewed any deployment warnings or policy errors
- you identified which resources should be deleted at the end of the lab

## Ready for troubleshooting
- the baseline environment is deployed
- you can identify each major resource and its relationship to the others
- you are ready to move into the scenario modules
