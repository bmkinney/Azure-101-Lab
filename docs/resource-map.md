# Resource Map

## Pre-deployed lab environment

Each group of 3 students shares one Azure subscription, one resource group, and one set of resources. Students collaborate in a breakout room. The proctor deploys the Bicep template once per group subscription.

- **Shared resource group** (`azure101lab-shared-rg`): Log Analytics, DCR, managed identity
- **Lab resource group** (`azure101lab-rg`): all lab resources for the group

### Lab resources (in `azure101lab-rg`)

- 2 VNets (VNet1 with workload + Bastion subnets, VNet2 with workload subnet)
- VNet peering in both directions
- 2 NSGs (one per VNet workload subnet, with deny rules blocking cross-VNet traffic)
- 1 Bastion host (in VNet1 AzureBastionSubnet)
- 2 NICs (one per VM, in respective workload subnets)
- 2 Ubuntu VMs on `Standard_B1s` (VM1 with data disk, VM2 with TCP listener on 1433)
- 1 storage account (blob container `lab-data`, boot diagnostics)
- NSG flow logs for both NSGs (Traffic Analytics enabled)
- Storage diagnostic settings (StorageBlobLogs → LAW)
- Metric alert (disk capacity >80% on VM1)
- Action group (email notifications)

### Shared resources (in `azure101lab-shared-rg`)

- 1 Log Analytics workspace (shared for KQL, flow logs, storage logs, Activity Log)
- 1 Data Collection Rule (CPU, memory, disk, network counters + syslog including cron)
- 1 User-assigned managed identity (runs fault injection script)

### Subscription-level resources

- Azure Policy assignments (Audit: `Department` and `Environment` tags)
- Budget ($50/month with 80% and 100% alert thresholds)
- Activity Log diagnostic setting (forwards to LAW)

## Network topology

```
VNet1 (10.10.0.0/16)
├── workload-snet (10.10.1.0/24) ─── NSG1 ─── VM1 (data disk, CPU spike cron)
└── AzureBastionSubnet (10.10.254.0/26) ─── Bastion
        │
        │  VNet peering (both directions)
        │
VNet2 (10.11.0.0/16)
└── workload-snet (10.11.1.0/24) ─── NSG2 ─── VM2 (TCP 1433 listener)
```

Students SSH to both VMs through Bastion. Cross-VNet connectivity requires NSG rules (Module 2).

## Relationship summary

- VM1 and VM2 are in separate VNets connected by peering
- Bastion provides SSH access to both VMs (via VNet peering)
- NSG1 controls traffic to/from VM1's subnet (deny outbound to VNet2); NSG2 controls traffic to/from VM2's subnet (deny inbound from VNet1)
- No custom allow rules exist — NSG1 has a deny-outbound rule to VNet2, NSG2 has a deny-inbound rule from VNet1
- VM1 has a 4 GB data disk (mounted, pre-filled >80%)
- VM2 runs `ncat -lk 1433` to simulate a SQL listener
- Storage account has a `lab-data` blob container for RBAC / audit exercises
- NSG flow logs and storage diagnostic logs feed into the shared LAW
- The DCR routes VM performance counters and syslog to the shared LAW
- Activity Log at subscription scope also feeds into the shared LAW

## Troubleshooting impact map

### VM performance problem (Module 1)
Check:
- Azure Monitor metrics (CPU percentage)
- Bastion SSH → `top` or `htop`
- VM size (vCPU count vs workload)
- Cron jobs (`crontab -l`)
- Syslog in LAW for cron entries

### Cross-VNet connectivity problem (Module 2)
Check:
- VNet peering status (Connected on both sides)
- NSG1 outbound rules and NSG2 inbound rules
- Effective security rules on both NICs
- `nc -zv <VM2-IP> 1433` from VM1
- NSG flow logs in LAW
- Network Watcher IP flow verify

### Disk capacity problem (Module 3)
Check:
- Azure Monitor metric alerts (fired alerts)
- `df -h /mnt/data` on VM1
- Disk size in portal vs filesystem usage
- Disk resize + partition extension steps

### Monitoring / KQL evidence (Module 4)
Check:
- Log Analytics → KQL queries
- Perf table (CPU, disk, memory, network)
- Syslog table (cron entries)
- AzureNetworkAnalytics_CL (flow logs)
- AzureActivity (control plane operations)

### Cost and policy compliance (Module 5)
Check:
- Policy → Compliance → non-compliant resources
- Resource tags (Department, Environment)
- Cost Management → Cost analysis (group by tag)
- Budget threshold and alerts

### RBAC data-plane problem (Module 6)
Check:
- IAM on storage account → role assignments
- Control plane (Contributor) vs data plane (Storage Blob Data Contributor)
- Error message: 403 AuthorizationPermissionMismatch

### Storage access audit (Module 7)
Check:
- StorageBlobLogs in LAW
- Caller IP, operation name, status code
- Correlation with blob upload attempts

### Change tracking (Module 8)
Check:
- Activity Log (VM resize, NSG changes, disk resize, role assignments)
- Resource Graph `resourcechanges` table
- Attribution (who made each change)
