# Lab Agenda

## Full agenda (8 modules)

### 0:00–0:10 — Orientation
- lab goals and environment overview
- hand out credentials and assign breakout rooms
- confirm portal access and Bastion connectivity

### 0:10–0:40 — Module 1: VM Performance
- observe periodic unresponsiveness reported by users
- investigate Azure Monitor CPU metrics on VM1
- use Bastion to SSH and observe the stress process
- resize VM1 to 4+ vCPU
- verify CPU spike now uses ≤50%

### 0:40–1:10 — Module 2: Network Connectivity (NSG)
- test VM1 → VM2 connectivity on port 1433 (fails)
- investigate NSG rules on both VNets
- add allow rules on both NSG1 and NSG2
- verify connectivity with `nc -zv`

### 1:10–1:40 — Module 3: Disk Capacity
- observe fired disk alert in Azure Monitor
- SSH via Bastion to confirm disk >80% full
- resize data disk in Azure
- extend partition and filesystem inside the OS
- verify utilization drops below threshold

### 1:40–2:10 — Module 4: Azure Monitor & KQL Evidence
- write KQL queries for CPU trend, VNet flow log blocks, disk utilization
- validate DCR is collecting all expected telemetry
- produce query-based evidence of Modules 1-3

### 2:10–2:40 — Module 5: Cost & Policy Compliance
- identify non-compliant resources via Azure Policy
- apply required Department and Environment tags
- generate ACM cost report by tag at subscription scope
- review budget configuration and alert thresholds

### 2:40–3:10 — Module 6: RBAC (Data Plane)
- attempt blob upload to storage account (403 error)
- investigate control-plane vs data-plane RBAC
- assign Storage Blob Data Contributor to self
- successfully upload a file

### 3:10–3:30 — Module 7: Storage Access Audit
- query StorageBlobLogs in Log Analytics
- identify callers, operations, and IP addresses
- report findings on who accessed blob storage

### 3:30–3:50 — Module 8: Change Tracking
- use Activity Log and Resource Graph to document changes
- identify VM resize, NSG modifications, disk resize, role assignments
- produce audit report with timestamps and callers

### 3:50–4:00 — Wrap-up
- recap findings and key learnings
- discuss real-world parallels
- confirm teardown plan

## Condensed agenda (core modules only)

If time is limited, prioritize Modules 1–5 (core operations):

### 0:00–0:10 — Orientation
### 0:10–0:40 — Module 1: VM Performance
### 0:40–1:10 — Module 2: Network Connectivity (NSG)
### 1:10–1:35 — Module 3: Disk Capacity
### 1:35–2:00 — Module 4: Azure Monitor & KQL Evidence
### 2:00–2:25 — Module 5: Cost & Policy Compliance
### 2:25–2:30 — Wrap-up

Modules 6-8 (RBAC, Storage Audit, Change Tracking) can be assigned as follow-up exercises or run in a second session.
