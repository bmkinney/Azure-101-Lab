# Proctor Guide

## Overview

This guide is for the lab proctor delivering the Azure 101 Operations Lab. The lab environment is pre-deployed using Bicep so students spend their time troubleshooting, not building infrastructure.

Each group of 3 students shares one Azure subscription and one resource group with a single set of resources. Students collaborate in a breakout room. The proctor deploys the Bicep template once per group subscription.

Students have **Contributor** role from the start — there is no mid-lab RBAC upgrade. The RBAC challenge (Module 6) focuses on data-plane vs control-plane permissions.

## Prerequisites

Before deploying the lab environment, confirm:

- one Azure subscription per student group (3 students per subscription)
- you have `Owner` or `Contributor` + `User Access Administrator` on each subscription
- Azure CLI is installed and authenticated (`az login`)
- Bicep CLI is available (`az bicep version` — bundled with Azure CLI 2.20+)
- you know the group assignments

## Student groups

| Group | Subscription | Students |
|---|---|---|
| Group 1 | Lab-Sub-01 | Alice, Bob, Carol |
| Group 2 | Lab-Sub-02 | Dave, Eve, Frank |
| Group 3 | Lab-Sub-03 | Grace, Hank, Ivy |

Adjust naming as needed. Each group gets its own `parameters.bicepparam` file.

## Deployment instructions

### Step 0 — Clone the repo in Azure Cloud Shell

Open [Azure Cloud Shell](https://shell.azure.com) (Bash) and clone the lab repository:

```bash
git clone https://github.com/bmkinney/Azure-101-Lab.git
cd Azure-101-Lab
```

If the repo was previously cloned, pull the latest changes instead:

```bash
cd Azure-101-Lab
git pull origin main
```

### Step 1 — Create a parameters file for each group

```bash
cp infra/parameters.example.bicepparam infra/parameters-group1.bicepparam
```

Edit `infra/parameters-group1.bicepparam`:
- update `location` to your approved region
- set `adminPassword` to a strong shared password
- set `studentPrincipalId` to the Entra group containing this group's students
- set `alertEmail` for budget and metric alert notifications

Repeat for each group.

### Step 2 — Deploy to each group subscription

Run the deployment once per group, targeting that group's subscription.
Use `--name` to give each deployment a unique name — subscription-scoped deployments
are location-locked by name, so reusing the default name across regions will fail.

```bash
# Group 1
az account set --subscription "Lab-Sub-01"
az deployment sub create \
  --name lab-group1 \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters infra/parameters-group1.bicepparam

# Group 2
az account set --subscription "Lab-Sub-02"
az deployment sub create \
  --name lab-group2 \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters infra/parameters-group2.bicepparam

# Repeat for each group
```

Deployment takes approximately 15-20 minutes per group (Bastion adds some time).

### Step 3 — Verify deployment

After each deployment completes:

```bash
# List resource groups
az group list \
  --query "[?starts_with(name, 'azure101lab')].{name:name, location:location}" \
  --output table

# List lab resources
az resource list \
  --resource-group azure101lab-rg \
  --query "[].{name:name, type:type}" \
  --output table

# Confirm VMs are running (not deallocated — this is the new design)
az vm list -d \
  --query "[].{name:name, powerState:powerState, resourceGroup:resourceGroup}" \
  --output table

# Verify Bastion is deployed
az network bastion list \
  --query "[].{name:name, resourceGroup:resourceGroup}" \
  --output table
```

Expected: All VMs should be **running**. Bastion should exist in the lab RG.

### Step 4 — Assign subscription Reader to students (for Module 5)

Students need **Reader** at the subscription scope for Cost Management and Policy Compliance views.

```bash
az role assignment create \
  --assignee <student-principal-id> \
  --role "Reader" \
  --scope "/subscriptions/<sub-id>"
```

Contributor on the resource group (assigned via Bicep) handles resource modifications. Subscription Reader adds visibility into cost management, budgets, and policy compliance at the subscription level.

---

## What gets deployed

### Per group subscription

| Resource Group | Contents |
|---|---|
| `azure101lab-shared-rg` | Log Analytics workspace, DCR, managed identity, fault injection script |
| `azure101lab-rg` | All lab resources (VNets, VMs, Bastion, storage, NSGs, flow logs, alerts) |

### Shared resources (in `azure101lab-shared-rg`)

| Resource | Name | Purpose |
|---|---|---|
| Log Analytics workspace | `azure101lab-law` | Shared workspace for KQL, metrics, flow logs |
| Data Collection Rule | `azure101lab-dcr` | Routes VM perf counters + syslog to workspace |
| Managed Identity | `azure101lab-script-identity` | Runs fault injection deployment script |

### Lab resources (in `azure101lab-rg`)

| Resource | Name | Purpose |
|---|---|---|
| VNet 1 | `azure101lab-vnet1` | Workload VNet with AzureBastionSubnet |
| VNet 2 | `azure101lab-vnet2` | Database VNet |
| VNet Peering | `vnet1-to-vnet2`, `vnet2-to-vnet1` | Cross-VNet connectivity |
| NSG 1 | `azure101lab-nsg1` | On VNet1 workload subnet (deny outbound to VNet2) |
| NSG 2 | `azure101lab-nsg2` | On VNet2 workload subnet (deny inbound from VNet1) |
| Bastion | `azure101lab-bastion` | SSH access to both VMs |
| VM 1 | `azure101lab-vm1` | Ubuntu 22.04, Standard_D2alds_v7, 4 GB data disk |
| VM 2 | `azure101lab-vm2` | Ubuntu 22.04, Standard_D2alds_v7, TCP listener on 1433 |
| Storage Account | `azure101labst<unique>` | Blob container `lab-data`, boot diagnostics |
| VNet Flow Logs | Per VNet | Flow logs to Log Analytics (Traffic Analytics) |
| Storage Diagnostics | On blob service | StorageBlobLogs to Log Analytics |

### Subscription-level resources

| Resource | Purpose |
|---|---|
| Azure Policy (Audit) | Tag enforcement for `Department` and `Environment` |
| Budget ($50/month) | Spending threshold with email alerts at 80% and 100% |
| Activity Log diag setting | Forwards Activity Log to Log Analytics |

---

## Baked-in faults

**Do not fix these before the lab.** They are the lab exercises.

### Fault 1 — CPU spike cron job (Module 1)

| Detail | Value |
|---|---|
| **What's wrong** | Cron job on VM1 runs `stress --cpu 2 --timeout 600` every hour at minute 0 |
| **Impact** | 100% CPU for 10 min/hour on a 2-vCPU VM (Standard_D2alds_v7) |
| **What students see** | Periodic unresponsiveness, 100% CPU in Azure Monitor metrics |
| **Resolution** | Resize VM1 to 4+ vCPU; spike then uses ≤50% |

### Fault 2 — Data disk at capacity (Module 3)

| Detail | Value |
|---|---|
| **What's wrong** | 4 GB data disk on VM1 filled to >80% with `app-logs.dat` |
| **Impact** | Disk alert fires, application at risk of data loss |
| **What students see** | Fired metric alert, `df -h /mnt/data` shows >80% |
| **Resolution** | Resize disk in Azure + extend partition/filesystem in OS |

### Fault 3 — NSG blocks cross-VNet traffic (Module 2)

| Detail | Value |
|---|---|
| **What's wrong** | Custom deny rules on NSG1 (outbound to VNet2) and NSG2 (inbound from VNet1) block all cross-VNet traffic |
| **Impact** | VM1 cannot reach VM2's SQL service |
| **What students see** | `nc -zv <VM2-IP> 1433` times out |
| **Resolution** | Add allow rules at priority <4096 on both NSG1 (outbound) and NSG2 (inbound) for port 1433 |

### Fault 4 — Missing tags (Module 5)

| Detail | Value |
|---|---|
| **What's wrong** | All resources missing `Department` and `Environment` tags |
| **Impact** | Azure Policy shows non-compliant resources |
| **What students see** | Policy → Compliance shows non-compliant count |
| **Resolution** | Apply required tags to resources |

### Fault 5 — No data-plane RBAC (Module 6)

| Detail | Value |
|---|---|
| **What's wrong** | Students have Contributor (control plane) but not `Storage Blob Data Contributor` (data plane) |
| **Impact** | Cannot upload/download blobs |
| **What students see** | 403 AuthorizationPermissionMismatch on blob upload |
| **Resolution** | Assign `Storage Blob Data Contributor` on the storage account |

### Fault 6 — Test blob + storage logging (Module 7)

| Detail | Value |
|---|---|
| **What's wrong** | Fault injection uploads a test blob; storage diagnostic logs capture access events |
| **Impact** | Serves as audit investigation evidence |
| **What students see** | `StorageBlobLogs` entries in Log Analytics |
| **Resolution** | Query and report on who accessed what |

---

## Module walkthrough guide

### Module 1 — VM Performance (30 min)

**Present:** "Users report the app on VM1 becomes unresponsive for ~10 minutes every hour."

**Expected path:** Azure Monitor metrics → see periodic 100% CPU → Bastion SSH → `top` shows `stress` → identify 2-vCPU bottleneck → resize VM → verify post-resize metrics.

**Teaching moments:** Azure Monitor metric analysis, VM sizing, Bastion access, connecting metrics to real symptoms.

### Module 2 — Network Connectivity / NSG (30 min)

**Present:** "VM1 cannot connect to the database service on VM2 (port 1433)."

**Expected path:** Bastion to VM1 → `nc -zv <VM2-IP> 1433` fails → review NSG1 and NSG2 rules → find deny rules blocking cross-VNet traffic → add allow rules at higher priority on both sides → verify.

**Teaching moments:** NSG rules evaluation, cross-VNet traffic, Network Watcher tools, both-sides-of-the-firewall thinking.

### Module 3 — Disk Capacity (30 min)

**Present:** "You received an alert that VM1's data disk is over 80% full."

**Expected path:** Azure Monitor alerts → Bastion SSH → `df -h /mnt/data` → resize disk in portal → `growpart` + `resize2fs` inside OS → verify.

**Teaching moments:** Azure disk management, Linux partition/filesystem extension, alert-driven response.

### Module 4 — Azure Monitor & KQL Evidence (30 min)

**Present:** "Your manager needs KQL-based evidence of all issues and fixes."

**Expected path:** Log Analytics → KQL queries for CPU trends, VNet flow logs, disk metrics → DCR validation → produce evidence.

**Teaching moments:** KQL fundamentals, correlation of logs to events, Traffic Analytics, DCR configuration.

### Module 5 — Cost & Policy Compliance (30 min)

**Present:** "Review this environment for compliance and cost awareness."

**Expected path:** Azure Policy → Compliance → non-compliant resources → apply tags → Cost Management → cost report by tag → review budget.

**Teaching moments:** Tag governance, Azure Policy effects, Cost Management navigation, budget alerting.

### Module 6 — RBAC Data Plane (20 min)

**Present:** "Upload a config file to the storage account's lab-data container."

**Expected path:** Attempt blob upload → 403 → review IAM → understand control vs data plane → assign Storage Blob Data Contributor → upload succeeds.

**Teaching moments:** Control-plane vs data-plane RBAC, least privilege, role assignment scope.

### Module 7 — Storage Access Audit (20 min)

**Present:** "Security flagged suspicious blob access. Investigate and report."

**Expected path:** Log Analytics → `StorageBlobLogs` → identify callers, IPs, operations → report findings.

**Teaching moments:** Storage diagnostic logging, KQL for security investigation, audit trail.

### Module 8 — Change Tracking (20 min)

**Present:** "An auditor needs a report of all infrastructure changes made during the lab."

**Expected path:** Activity Log → find VM resize, NSG changes, disk resize, role assignments → Resource Graph `resourcechanges` → document audit trail.

**Teaching moments:** Activity Log vs Resource Graph, change attribution, audit compliance.

---

## Teardown

After the lab is complete, for each group subscription:

```bash
# Delete lab resource groups
az group delete --name azure101lab-shared-rg --yes --no-wait
az group delete --name azure101lab-rg --yes --no-wait

# Policy assignments are at subscription scope — delete them
az policy assignment delete --name "audit-department-tag"
az policy assignment delete --name "audit-environment-tag"

# Budget
az consumption budget delete --budget-name "azure101lab-monthly-budget"

# Verify
az group list --query "[?starts_with(name, 'azure101lab')].name" --output tsv
```

---

## Troubleshooting the deployment

### Deployment fails on VM availability

If the region lacks `Standard_D2alds_v7` capacity, change `location` or override the `vmSize` parameter.

### Bastion deployment fails

Bastion requires the subnet to be named exactly `AzureBastionSubnet` with at least a /26 prefix. Verify the VNet definition in `user-environment.bicep`.

### Fault injection script fails

Check deployment script logs in the portal (resource type: `Microsoft.Resources/deploymentScripts`). Common issues:
- Managed identity role propagation delay — re-run the deployment
- VM not yet fully provisioned — the script has a 30-minute timeout

### Storage account name conflict

Storage account names are globally unique. Edit the naming pattern in `user-environment.bicep` to add a short suffix.

### VNet flow logs fail

Network Watcher must be registered in the target region. Run `az network watcher configure --resource-group NetworkWatcherRG --locations <region> --enabled true`.

### RBAC assignment fails

Verify the `studentPrincipalId` object ID:
```bash
az ad group show --group "<group-name>" --query id --output tsv
az ad user show --id "<user@domain.com>" --query id --output tsv
```
