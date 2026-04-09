# Scenario List

## Scenario design goals

All scenarios are pre-deployed in the lab environment via Bicep. Students do not build infrastructure — they troubleshoot it.

Each scenario presents:
- an **observable symptom** the student can reproduce
- a clear **objective** defining what "fixed" looks like
- **references** to Microsoft Learn documentation (no step-by-step hints)

Students work in groups of 3, sharing one subscription and one resource group. Each group collaborates in a breakout room on the same set of resources.

## Scenario 1 — VM Performance

### Focus area
VM monitoring, metrics analysis, and compute right-sizing

### Pre-deployed fault
- A cron job on VM1 runs `stress --cpu 2` for 10 minutes every hour, pegging 2 vCPUs at 100%
- VM1 is `Standard_D2alds_v7` (2 vCPU) — completely saturated during spike

### Participant outcome
The participant identifies the periodic CPU spike using Azure Monitor metrics, connects via Bastion to observe the process, and resizes the VM to 4+ vCPU so the spike only consumes ≤50% CPU.

### Evidence sources
- Azure Monitor → Metrics (Percentage CPU on VM1)
- Bastion SSH → `top` or `htop` to see `stress` process
- VM size comparison before and after resize

## Scenario 2 — Network Connectivity (NSG)

### Focus area
NSG rule analysis, cross-VNet troubleshooting, Network Watcher tools

### Pre-deployed fault
- Two VNets are peered, each with its own NSG
- No custom allow rules exist — custom deny rules on each NSG block cross-VNet traffic, so SQL (port 1433) between VM1 and VM2 fails
- VM2 runs a TCP listener on port 1433 (simulates SQL)

### Participant outcome
The participant tests connectivity from VM1 to VM2 on port 1433 (fails), identifies that NSG rules are needed on both sides, adds allow rules, and verifies connectivity.

### Evidence sources
- `nc -zv <VM2-IP> 1433` from VM1 via Bastion
- NSG rule review on both NSG1 and NSG2
- Effective security rules on both NICs
- Network Watcher NSG diagnostics

## Scenario 3 — Disk Capacity

### Focus area
Azure disk management, Linux filesystem administration, Azure Monitor alerts

### Pre-deployed fault
- VM1 has a 4 GB data disk mounted at `/mnt/data`
- The disk is filled to >80% with a large file (`app-logs.dat`)
- An Azure Monitor metric alert fires on disk usage >80%

### Participant outcome
The participant receives or observes the disk alert, resizes the disk in Azure, extends the partition and filesystem inside the OS via Bastion, and confirms utilization drops below threshold.

### Evidence sources
- Azure Monitor → Alerts (fired disk alert)
- Bastion SSH → `df -h /mnt/data`
- Disk properties in the portal (size change)
- Post-resize `df -h` showing reduced utilization

## Scenario 4 — Azure Monitor & KQL Evidence

### Focus area
Log Analytics, KQL queries, operational evidence gathering

### Pre-deployed fault
- None — this scenario uses monitoring data to provide evidence of Scenarios 1-3

### Participant outcome
The participant writes KQL queries showing CPU spike trends, VNet flow log blocks, disk utilization, and validates the DCR is collecting all expected telemetry.

### Evidence sources
- Perf table (CPU and disk metrics)
- AzureNetworkAnalytics_CL (VNet flow log denied traffic)
- Heartbeat table (VM availability)
- DCR configuration review

## Scenario 5 — Cost & Policy Compliance

### Focus area
Azure Policy, tag governance, Cost Management, budgets

### Pre-deployed fault
- All resources are missing required `Department` and `Environment` tags
- Azure Policy (Audit effect) is assigned at subscription scope flagging non-compliance
- A subscription budget ($50/month) is deployed with alert thresholds

### Participant outcome
The participant identifies non-compliant resources via Azure Policy, applies the required tags, generates an ACM cost report by tag, and reviews the budget configuration.

### Evidence sources
- Azure Policy → Compliance (non-compliant resource count)
- Resource Tags blade
- Cost Management → Cost analysis (grouped by tag)
- Cost Management → Budgets

## Scenario 6 — RBAC (Data Plane)

### Focus area
Control-plane vs data-plane RBAC, storage blob access

### Pre-deployed fault
- Students have Contributor role (control plane) but NOT `Storage Blob Data Contributor` (data plane)
- A blob container `lab-data` exists with a pre-uploaded test file

### Participant outcome
The participant attempts a blob upload (gets 403), discovers the control-plane vs data-plane distinction, assigns `Storage Blob Data Contributor` to themselves on the storage account, and uploads successfully.

### Evidence sources
- 403 error on blob upload attempt
- IAM role assignment review
- Successful blob upload after role assignment

## Scenario 7 — Storage Access Audit

### Focus area
Storage diagnostic logging, KQL investigation, security audit

### Pre-deployed fault
- Storage account diagnostic settings send `StorageBlobLogs` to Log Analytics
- Prior blob access events exist from fault injection and Module 6 activities

### Participant outcome
The participant queries `StorageBlobLogs` in Log Analytics to identify who accessed blob storage, what operations were performed, and from which IP addresses.

### Evidence sources
- StorageBlobLogs table in Log Analytics
- KQL queries identifying callers by principal ID and IP

## Scenario 8 — Change Tracking

### Focus area
Activity Logs, Azure Resource Graph, change auditing

### Pre-deployed fault
- None — this scenario builds on real changes made during Scenarios 1-6

### Participant outcome
The participant uses Activity Logs and Resource Graph to document infrastructure changes: VM resize, NSG rule additions, disk resize, and role assignments. They produce an audit trail with timestamps and callers.

### Evidence sources
- AzureActivity table (control plane operations)
- Azure Resource Graph → `resourcechanges` table
- Activity Log in the portal

## Recommended sequence

1. VM Performance (Module 1)
2. Network Connectivity — NSG (Module 2)
3. Disk Capacity (Module 3)
4. Azure Monitor & KQL Evidence (Module 4)
5. Cost & Policy Compliance (Module 5)
6. RBAC — Data Plane (Module 6)
7. Storage Access Audit (Module 7)
8. Change Tracking (Module 8)

Modules 1-3 create the operational evidence that Modules 4 and 8 rely on. Module 6 creates the access needed for Module 7.
