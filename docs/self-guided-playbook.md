# Self-Guided Playbook

## Purpose

This document defines how the lab works as a fully self-guided experience with a pre-deployed environment.

## Audience

Core hosting and cloud engineers who need baseline Azure operational troubleshooting skills.

## Self-guided goals

Learners should be able to complete the lab independently and leave the session able to:

- troubleshoot VM performance using Azure Monitor metrics and SSH
- debug cross-VNet connectivity using NSG rules and Network Watcher
- manage disk capacity alerts with Azure disk resize and Linux filesystem extension
- write KQL queries to produce evidence of issues and fixes
- audit cost and policy compliance using Cost Management and Azure Policy
- understand control-plane vs data-plane RBAC
- investigate storage access using diagnostic logs
- track infrastructure changes using Activity Log and Resource Graph

## Recommended duration

- ~4 hours for all 8 modules (full experience)
- ~2.5 hours for core modules 1-5 (condensed delivery, assign 6-8 as follow-up)

## Prerequisites

Before starting, confirm:

- the lab environment has been pre-deployed by the proctor
- you know your group's resource group name (e.g., `azure101lab-rg`)
- you can access Azure portal
- you have VM credentials (username: `azureuser`, password from proctor)
- you can connect to VMs via Bastion (no public IP on VMs)

## Your pre-deployed environment

Each group has:
- 2 VNets peered together (VNet1 with workload + Bastion, VNet2 with workload)
- 2 NSGs (one per VNet workload subnet, with deny rules blocking cross-VNet traffic)
- 1 Bastion host for SSH access
- 2 Ubuntu VMs (VM1 with data disk, VM2 with TCP listener on port 1433)
- 1 storage account with `lab-data` blob container
- NSG flow logs, storage diagnostic logs, and metric alerts
- Access to a shared Log Analytics workspace

The environment contains intentional faults. Your job is to find and fix them.

## Self-guided completion pattern

Use the repository materials in this order:

1. Read [student-guide.md](student-guide.md) — this is your primary guide
2. Use [troubleshooting-guide.md](troubleshooting-guide.md) when a symptom appears
3. Use [scenario-list.md](scenario-list.md) to understand the scenario objectives
4. Ask your proctor for hints if you get stuck

## Known-good checkpoints

Use these checkpoints as you progress:

### Module 1 — VM Performance
1. Portal access confirmed and resource group identified
2. Connected to VM1 via Bastion
3. Identified periodic 100% CPU from `stress` process
4. Identified VM1 is Standard_D2alds_v7
5. Resized VM1 to 4+ vCPU — CPU spike now ≤50%

### Module 2 — Network Connectivity
6. Ran `nc -zv <VM2-IP> 1433` from VM1 — timed out
7. Reviewed NSG1 and NSG2 — deny rules block cross-VNet traffic on port 1433
8. Added allow rules on both NSGs
9. Verified `nc -zv <VM2-IP> 1433` succeeds

### Module 3 — Disk Capacity
10. Reviewed fired metric alert for disk >80%
11. SSH to VM1 → `df -h /mnt/data` shows >80% used
12. Resized disk in Azure portal
13. Ran `growpart` + `resize2fs` inside VM1
14. Verified disk has free space and alert clears

### Module 4 — KQL Evidence
15. Queried `Perf` table for CPU trends
16. Queried NSG flow logs for port 1433 traffic
17. Queried disk metrics for capacity trend
18. Produced evidence summary for all modules 1-3

### Module 5 — Cost & Policy
19. Reviewed Policy → Compliance for non-compliant resources
20. Applied `Department` and `Environment` tags
21. Reviewed Cost Management → Cost analysis
22. Reviewed budget threshold and alerts

### Module 6 — RBAC Data Plane
23. Attempted blob upload to `lab-data` → got 403
24. Identified missing `Storage Blob Data Contributor` role
25. Assigned role → upload succeeded

### Module 7 — Storage Audit
26. Queried `StorageBlobLogs` in LAW
27. Identified callers, IPs, and operations
28. Documented findings

### Module 8 — Change Tracking
29. Reviewed Activity Log for all changes made during the lab
30. Queried Resource Graph `resourcechanges`
31. Documented audit trail

## Common learner issues

- Not using Bastion to SSH — there are no public IPs on the VMs
- Not checking both NSGs when debugging cross-VNet connectivity
- Forgetting the Linux OS steps after resizing a disk in Azure (growpart + resize2fs)
- Confusing control-plane Contributor with data-plane Storage Blob Data Contributor
- Not waiting for metrics/logs to appear in LAW (allow 5-10 minutes for ingestion)
- Overlooking that NSG flow logs and StorageBlobLogs are in the same LAW as VM telemetry

## If you get stuck

Work the problem in this order:

1. Restate the symptom in one sentence
2. Identify the exact resource involved
3. Check the relevant tool (Metrics, NSG rules, IAM, Policy, Activity Log)
4. Ask your proctor if you need to verify your solution
5. Open the linked Microsoft Learn article for the module you are on

## Follow-up

After completing the lab:

- Save your notes for the recap discussion
- Note which scenarios were most helpful
- Your proctor will handle resource cleanup
