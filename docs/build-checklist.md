# Deployment Verification Checklist

Use this checklist after running the Bicep deployment to confirm the lab environment is ready. Run once per group subscription.

## Pre-deployment

- [ ] One Azure subscription per student group (3 students per group)
- [ ] Owner or Contributor + User Access Administrator on each subscription
- [ ] Parameters file created for each group with location, admin password, alertEmail
- [ ] Student principal ID set for Contributor assignment
- [ ] Network Watcher registered in each subscription's target region

## Resource groups

- [ ] Shared resource group (`azure101lab-shared-rg`) is created
- [ ] Lab resource group (`azure101lab-rg`) is created

## Shared resources (in `azure101lab-shared-rg`)

- [ ] Log Analytics workspace (`azure101lab-law`) is deployed
- [ ] Data Collection Rule (`azure101lab-dcr`) is deployed with CPU, memory, disk, network counters + syslog (cron)
- [ ] Managed identity (`azure101lab-script-identity`) is deployed
- [ ] Managed identity has Contributor role on the lab resource group

## Lab resources (in `azure101lab-rg`)

### Networking

- [ ] VNet 1 (`azure101lab-vnet1`) created with workload subnet + AzureBastionSubnet
- [ ] VNet 2 (`azure101lab-vnet2`) created with workload subnet
- [ ] VNet peering active in both directions (`vnet1-to-vnet2`, `vnet2-to-vnet1`)
- [ ] NSG 1 (`azure101lab-nsg1`) associated to VNet1 workload subnet — DenyCrossVNetOutbound rule blocks outbound to VNet2 (intentional)
- [ ] NSG 2 (`azure101lab-nsg2`) associated to VNet2 workload subnet — DenyCrossVNetInbound rule blocks inbound from VNet1 (intentional)
- [ ] Bastion (`azure101lab-bastion`) deployed in VNet1 AzureBastionSubnet

### Compute

- [ ] VM1 (`azure101lab-vm1`) — Ubuntu 22.04, Standard_D2alds_v7, **running** (not deallocated)
- [ ] VM1 has 4 GB data disk attached
- [ ] VM2 (`azure101lab-vm2`) — Ubuntu 22.04, Standard_D2alds_v7, **running**
- [ ] VM2 has `ncat -lk 1433` TCP listener active (Custom Script Extension)
- [ ] Azure Monitor Agent installed on both VMs
- [ ] DCR association exists for both VMs

### Storage

- [ ] Storage account (`azure101labst<unique>`) created
- [ ] Blob container `lab-data` exists
- [ ] Storage diagnostic settings enabled (StorageBlobLogs → LAW)
- [ ] Boot diagnostics enabled on both VMs

### Monitoring

- [ ] VNet flow logs enabled for both VNets (with Traffic Analytics)
- [ ] Metric alert for VM1 data disk >80% used
- [ ] Action group configured with alert email

## Faults (verify these are present)

- [ ] CPU spike cron job on VM1 (`stress --cpu 2 --timeout 600` every hour at minute 0)
- [ ] Data disk on VM1 filled >80% with `app-logs.dat`
- [ ] NSG deny rules block cross-VNet traffic on port 1433 between VNet1 and VNet2
- [ ] Test blob uploaded to `lab-data` container (for Module 7 audit)

## Subscription-level resources

- [ ] Azure Policy: `audit-department-tag` assignment active (DoNotEnforce — audit-only)
- [ ] Azure Policy: `audit-environment-tag` assignment active (DoNotEnforce — audit-only)
- [ ] Policy compliance scan completed (allow up to 30 minutes)
- [ ] Budget (`azure101lab-monthly-budget`) set at $50/month with 80% and 100% thresholds
- [ ] Activity Log diagnostic setting forwarding to LAW

## RBAC

- [ ] Students have **Contributor** on the lab resource group (assigned via Bicep)
- [ ] Students have **Reader** at subscription scope (for Cost Management / Policy views)
- [ ] Students do **not** have Storage Blob Data Contributor (intentional — Module 6 fault)

## Final checks

- [ ] All VMs are **running** (`az vm list -d --query "[].{name:name, powerState:powerState}" -o table`)
- [ ] Bastion is provisioned in the lab RG
- [ ] Resource count matches expected (~15 resources in lab RG)
- [ ] VM credentials documented and ready to hand out to each group
