# Student Guide

## Overview

This is a hands-on Azure Operations lab. Your environment has been pre-deployed by the proctor into a dedicated group subscription. Each group of 3 students shares one resource group with one set of resources containing intentional misconfigurations. You will work together in a breakout room to diagnose and resolve each challenge.

Your job is to observe the symptoms, diagnose root causes, and prove that you fixed each problem. No one will hand you the steps — you need to think through each challenge as a team.

## Learning objectives

By the end of the lab, participants should be able to:

- use Azure Monitor metrics to identify VM performance problems
- troubleshoot cross-VNet connectivity using NSG analysis and Network Watcher
- resize Azure disks and extend Linux filesystems
- write KQL queries to provide evidence of operational issues and resolutions
- identify Azure Policy non-compliance and produce cost reports
- distinguish control-plane vs data-plane RBAC and fix permission gaps
- investigate storage access patterns using Log Analytics
- track infrastructure changes using Activity Logs and Resource Graph

## Lab assumptions

- each group of 3 students shares one Azure subscription and one resource group
- your lab environment has been pre-deployed by the proctor
- all group members collaborate on the same set of resources
- you have Contributor access on your resource group (control-plane operations)
- Azure Bastion is available for SSH access to your VMs

## Your assigned environment

Your proctor will give you:
- your group's resource group name (e.g., `azure101lab-rg`)
- login credentials for the VMs

### Naming convention

| Resource | Name |
|---|---|
| VNet 1 (workload) | `azure101lab-vnet1` |
| VNet 2 (database) | `azure101lab-vnet2` |
| NSG 1 | `azure101lab-nsg1` |
| NSG 2 | `azure101lab-nsg2` |
| VM 1 (workload) | `azure101lab-vm1` |
| VM 2 (database) | `azure101lab-vm2` |
| Bastion | `azure101lab-bastion` |
| Storage Account | `azure101labst` |
| Data Disk | `azure101lab-vm1-datadisk` |

### Environment topology

Your group environment contains:

- **VNet 1** (`10.10.0.0/16`) with a workload subnet and AzureBastionSubnet
- **VNet 2** (`10.11.0.0/16`) with a workload subnet
- VNet peering between VNet 1 and VNet 2
- **VM1** in VNet 1 — Ubuntu 22.04, Standard_B1s (1 vCPU), 4 GB data disk
- **VM2** in VNet 2 — Ubuntu 22.04, Standard_B1s, running a service on port 1433
- **Azure Bastion** for SSH access to both VMs
- **Storage account** with a `lab-data` blob container
- **NSG per VNet** with custom deny rules blocking cross-VNet traffic
- Both VMs report metrics and logs to a shared Log Analytics workspace
- NSG flow logs are enabled and flow to Log Analytics

## Lab flow

1. Module 1 — VM Performance
2. Module 2 — Network Connectivity (NSG)
3. Module 3 — Disk Capacity
4. Module 4 — Azure Monitor & KQL Evidence
5. Module 5 — Cost & Policy Compliance
6. Module 6 — RBAC (Data Plane)
7. Module 7 — Storage Access Audit
8. Module 8 — Change Tracking

Each module presents a **symptom** you can observe, an **objective** that defines what "fixed" means, and **references** to Microsoft Learn documentation.

---

## Module 0 — Orientation

### Objective

Confirm your environment is accessible and familiarize yourself with the resource layout.

- navigate to your resource group in the Azure portal
- identify all resources deployed under your prefix
- confirm you can access Azure Bastion to SSH into VM1 and VM2
- locate the shared Log Analytics workspace
- locate Activity Log, Access Control (IAM), Network Watcher, and Azure Monitor in the portal

---

## Module 1 — VM Performance

### Symptom

Users report the application hosted on VM1 becomes unresponsive for approximately 10 minutes every hour. During these periods, the VM is extremely slow and connections time out.

### Objective

Identify the root cause of the periodic performance degradation using Azure Monitor metrics. Remediate the issue so that the application remains responsive during peak load periods. Prove the fix by showing improved metrics after remediation.

### References

- [Monitor Azure virtual machines](https://learn.microsoft.com/azure/virtual-machines/monitor-vm)
- [Resize a virtual machine](https://learn.microsoft.com/azure/virtual-machines/resize-vm)
- [Connect to a VM using Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-connect-vm-ssh-linux)

---

## Module 2 — Network Connectivity (NSG)

### Symptom

VM1 cannot connect to the database service running on VM2. Attempts to reach VM2 on port 1433 from VM1 result in connection timeouts.

You can reproduce this by connecting to VM1 via Bastion and testing connectivity:
```bash
nc -zv <VM2-private-IP> 1433 -w 5
```

### Objective

Establish connectivity between VM1 and VM2 on port 1433 by configuring the appropriate NSG rules. Both VMs are in separate VNets that are peered. Verify the connection works after your fix.

### References

- [Network security groups overview](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Diagnose VM network traffic filter problems](https://learn.microsoft.com/azure/virtual-network/diagnose-network-traffic-filter-problem)
- [Virtual network peering](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
- [Network Watcher overview](https://learn.microsoft.com/azure/network-watcher/network-watcher-overview)

---

## Module 3 — Disk Capacity

### Symptom

You received an alert (or see a fired alert in Azure Monitor → Alerts) indicating that the data disk on VM1 is over 80% full. The application is at risk of running out of storage, which could cause data loss or service outages.

### Objective

Resize the data disk in Azure to a larger size, then extend the partition and filesystem inside the VM's operating system. Confirm that disk utilization has dropped below the alert threshold.

### References

- [Expand virtual hard disks on a Linux VM](https://learn.microsoft.com/azure/virtual-machines/linux/expand-disks)
- [Azure managed disks overview](https://learn.microsoft.com/azure/virtual-machines/managed-disks-overview)
- [Azure Monitor alerts overview](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-overview)

---

## Module 4 — Azure Monitor & KQL Evidence

### Symptom

Your manager requires documented, query-based evidence that the operational issues from Modules 1–3 have been identified and addressed. Verbal summaries are not sufficient — you need to produce KQL query results.

### Objective

Using the shared Log Analytics workspace, produce KQL queries that show:

1. **CPU trend from Module 1** — the historical CPU spike pattern on VM1 before and after the resize
2. **NSG flow log analysis from Module 2** — blocked traffic events between VM1 and VM2 before the NSG fix
3. **Disk utilization from Module 3** — data disk capacity trend before and after the resize
4. **DCR validation** — confirm that the Data Collection Rule is sending all expected data sources to Log Analytics

### References

- [Log queries in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/logs/log-query-overview)
- [KQL quick reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/kql-quick-reference)
- [Azure Monitor Logs overview](https://learn.microsoft.com/azure/azure-monitor/logs/data-platform-logs)
- [Traffic Analytics](https://learn.microsoft.com/azure/network-watcher/traffic-analytics)

---

## Module 5 — Cost & Policy Compliance

### Symptom

When attempting to deploy a new resource, the deployment may fail or produce compliance warnings related to missing tags. Additionally, management has requested a cost report for the lab subscription to understand current spending.

Navigate to **Azure Policy → Compliance** in the portal and observe the non-compliant resource count. Also check the tags on your resources.

### Objective

1. Identify all resources in your resource group that are non-compliant with tag policies and apply the required `Department` and `Environment` tags.
2. Generate an Azure Cost Management report showing actual spend in the last 7 days, grouped by tag, at the subscription scope.
3. Review the subscription budget and confirm alerts are configured.

### References

- [Azure Policy overview](https://learn.microsoft.com/azure/governance/policy/overview)
- [Quickstart: Explore and analyze costs](https://learn.microsoft.com/azure/cost-management-billing/costs/quick-acm-cost-analysis)
- [Tutorial: Create and manage Azure budgets](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets)

---

## Module 6 — RBAC (Data Plane)

### Symptom

You need to upload a configuration file to the storage account's `lab-data` blob container. When you attempt to upload via the Azure portal or CLI, you receive an error:

> **AuthorizationPermissionMismatch (403)**  
> "This request is not authorized to perform this operation using this permission."

### Objective

Identify why your Contributor role is insufficient for blob data operations. Assign the correct data-plane role to yourself on the storage account and successfully upload a file to the `lab-data` container.

### References

- [Azure built-in roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
- [Authorize access to blob data in the Azure portal](https://learn.microsoft.com/azure/storage/blobs/authorize-data-operations-portal)
- [Assign Azure roles using the portal](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal)

---

## Module 7 — Storage Access Audit

### Symptom

The security team has flagged suspicious access patterns on the storage account's blob containers. They need an investigation report showing who has been accessing files, what operations were performed, and from which IP addresses.

### Objective

Using the shared Log Analytics workspace, query the `StorageBlobLogs` table to identify all callers who accessed the storage account's blob data. Report the principal identities, operation types, IP addresses, and timestamps.

### References

- [Monitor Azure Blob Storage](https://learn.microsoft.com/azure/storage/blobs/monitor-blob-storage)
- [StorageBlobLogs schema](https://learn.microsoft.com/azure/azure-monitor/reference/tables/storageblobreadalogs)
- [Azure Monitor diagnostic settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)

---

## Module 8 — Change Tracking

### Symptom

An auditor has requested a report of all infrastructure changes made during the lab session. They need evidence of what resources were changed, who made the changes, and when they occurred.

### Objective

Using Azure Activity Logs and Azure Resource Graph, document the infrastructure changes you made during the lab. Your report should include:

1. VM resize event (Module 1)
2. NSG rule modifications (Module 2)
3. Disk resize operation (Module 3)
4. Role assignment change (Module 6)

### References

- [Azure Activity Log](https://learn.microsoft.com/azure/azure-monitor/essentials/activity-log)
- [Azure Resource Graph overview](https://learn.microsoft.com/azure/governance/resource-graph/overview)
- [Azure Change Analysis](https://learn.microsoft.com/azure/azure-monitor/change/change-analysis)

---

## What to record during the lab

For each module, record:

- the symptom you observed
- the tools and queries you used
- the evidence you found
- the root cause
- the remediation you applied
- the proof that the fix worked

## Teardown

At the end of the lab:

- your proctor will handle resource cleanup
- confirm that you have saved your notes for the recap discussion
- do not delete resources unless instructed by the proctor
