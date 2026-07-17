# Troubleshooting Guide

## Core troubleshooting pattern

Use the same flow in every module:
1. Define the symptom
2. Gather evidence
3. Isolate the fault domain
4. Validate the hypothesis
5. Recommend or perform remediation

## Azure tools to know

### Compute
- VM Overview (size, power state, provisioning state)
- Azure Monitor → Metrics (CPU percentage, disk usage)
- Bastion (SSH to VMs without public IPs)
- Run command (execute scripts without SSH)

### Networking
- VNet and subnet views
- VNet peering status
- NSG inbound/outbound rules
- Effective security rules (on NIC)
- Network Watcher → IP flow verify
- Network Watcher → VNet flow logs
- `nc -zv <ip> <port>` for connectivity testing

### Disk management
- Azure Monitor → Alerts (metric alert for disk >80%)
- `df -h` (filesystem usage in Linux)
- `lsblk` (block device listing)
- Disk resize in portal + OS-level partition and filesystem extension

### Monitoring and KQL
- Log Analytics workspace → Logs (KQL editor)
- `Perf` table (CPU, memory, disk, network counters)
- `Syslog` table (cron entries, system events)
- `AzureNetworkAnalytics_CL` (VNet flow logs via Traffic Analytics)
- `StorageBlobLogs` (blob access audit)
- `AzureActivity` (control plane operations)
- `resourcechanges` (Resource Graph for change tracking)

### Authorization
- Access Control (IAM)
- Role assignments (control plane vs data plane)
- Scope hierarchy (resource → resource group → subscription → management group)

### Governance
- Azure Policy → Compliance
- Cost Management → Cost analysis
- Cost Management → Budgets
- Resource tags

## Module-specific tool guidance

### Module 1 — VM Performance
- **Start with:** Azure Monitor → Metrics → CPU Percentage for VM1
- **Then:** Bastion SSH → `top` to see `stress` process → `crontab -l` for schedule
- **Goal:** Reduce CPU utilization below the alert threshold

### Module 2 — Network Connectivity
- **Start with:** Bastion SSH to VM1 → `nc -zv <VM2-IP> 1433`
- **Then:** Review NSG1 outbound rules and NSG2 inbound rules
- **Also check:** Effective security rules on both NICs, VNet peering status
- **Goal:** Establish connectivity from VM1 to VM2 on port 1433

### Module 3 — Disk Capacity
- **Start with:** Azure Monitor → Alerts → fired disk alert
- **Then:** Bastion SSH → `df -h /mnt/data` and `ls -lah /mnt/data`
- **Goal:** Reduce disk utilization below the alert threshold

### Module 4 — KQL Evidence
- **Start with:** Log Analytics → Logs
- **Key queries:** Perf (CPU trends), AzureNetworkAnalytics_CL (flow logs), disk metrics
- **Goal:** Produce evidence artifacts for Modules 1-3

### Module 5 — Cost & Policy
- **Start with:** Azure Policy → Compliance
- **Then:** Check resource tags, Cost Management → Cost analysis
- **Fix with:** Create a remediation task for each tag policy (Modify effect) so the policy identity applies `Department` and `Environment` tags

### Module 6 — RBAC Data Plane
- **Start with:** Try uploading a blob to `lab-data` container → 403 error
- **Then:** IAM on storage account → review role assignments
- **Goal:** Gain the necessary permissions to upload blobs

### Module 7 — Storage Audit
- **Start with:** Log Analytics → `StorageBlobLogs` table
- **Key fields:** CallerIpAddress, OperationName, StatusCode, AccountName
- **Goal:** Report on who accessed what and when

### Module 8 — Change Tracking
- **Start with:** Activity Log → filter to lab resource group
- **Also check:** Resource Graph → `resourcechanges` table
- **Goal:** Document all infrastructure changes with attribution

## Good troubleshooting habits

- Start broad, then narrow
- Use evidence before changing configuration
- Confirm the actual scope before changing RBAC
- Confirm the actual association before changing networking
- Document what changed and why
- Allow 5-10 minutes for logs/metrics to appear in Log Analytics

## Common mistakes

- Changing multiple things at once
- Not checking both NSGs in a cross-VNet scenario
- Resizing a disk in Azure but forgetting the OS-level steps
- Confusing control-plane roles with data-plane roles (check the role description carefully)
- Not waiting for log ingestion before concluding data is missing
- Running KQL queries against the wrong time range
