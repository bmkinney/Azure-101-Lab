# Proctor Guide

## Overview

This guide is for the lab proctor delivering the Azure 101 Operations Lab. The lab environment is pre-deployed using Bicep so students spend their time troubleshooting, not building infrastructure.

A single Bicep deployment creates isolated environments for all students in one resource group. Each environment contains intentional misconfigurations that map to the lab's troubleshooting scenarios.

## Prerequisites

Before deploying the lab environment, confirm:

- an Azure subscription is available for the lab
- you have `Owner` or `Contributor` + `User Access Administrator` on the target resource group
- Azure CLI is installed and authenticated (`az login`)
- Bicep CLI is available (`az bicep version` — bundled with Azure CLI 2.20+)
- you know how many students will participate and their assigned prefixes

## Student prefixes

Each student is assigned a unique prefix used for all their resources. Common convention:

| Student | Prefix |
|---|---|
| Student 1 | `userA` |
| Student 2 | `userB` |
| Student 3 | `userC` |
| Student 4 | `userD` |
| Student 5 | `userE` |

Add or remove entries in the Bicep parameters file as needed.

## Deployment instructions

### Step 1 — Create the resource group

```bash
az group create \
  --name azure101lab-rg \
  --location eastus
```

### Step 2 — Copy and edit the parameters file

```bash
cp infra/parameters.example.bicepparam infra/parameters.bicepparam
```

Edit `infra/parameters.bicepparam`:
- update `userPrefixes` to match your student list
- update `location` to your approved region
- set `adminPassword` to a strong shared password (minimum 12 characters, must include uppercase, lowercase, number, and special character)
- optionally set `studentPrincipalId` to a Microsoft Entra group object ID containing all students (for the RBAC scenario)

### Step 3 — Deploy

```bash
az deployment group create \
  --resource-group azure101lab-rg \
  --template-file infra/main.bicep \
  --parameters infra/parameters.bicepparam
```

Deployment takes approximately 10-15 minutes depending on region and VM availability.

### Step 4 — Verify deployment

After deployment completes, verify:

```bash
# List all resources in the resource group
az resource list \
  --resource-group azure101lab-rg \
  --query "[].{name:name, type:type}" \
  --output table

# Confirm VMs are deallocated (this is intentional)
az vm list \
  --resource-group azure101lab-rg \
  --show-details \
  --query "[].{name:name, powerState:powerState}" \
  --output table
```

Expected output: All VMs should show `VM deallocated`.

---

## What gets deployed

### Shared resources

| Resource | Name | Purpose |
|---|---|---|
| Log Analytics workspace | `azure101lab-law` | Shared workspace for KQL and monitoring exercises |
| Data Collection Rule | `azure101lab-dcr` | Routes VM telemetry to the workspace |
| User-assigned managed identity | `azure101lab-script-identity` | Runs the VM deallocate deployment script |

### Per-user resources

For each user prefix (e.g., `userA`):

| Resource | Name pattern | Purpose |
|---|---|---|
| Virtual Network | `userA-vnet` | Lab network with `10.10.0.0/16` address space |
| Management Subnet | `userA-mgmt-snet` | `10.10.1.0/24` — unused, exists for comparison |
| Workload Subnet | `userA-workload-snet` | `10.10.2.0/24` — VM subnet with NSG and route table |
| Network Security Group | `userA-nsg` | Associated to workload subnet, contains fault |
| Route Table | `userA-rt` | Associated to workload subnet, contains fault |
| Network Interface | `userA-nic` | In workload subnet, no public IP |
| Virtual Machine | `userA-vm` | Ubuntu 22.04, Standard_B1s, deallocated |
| Storage Account | `useraazure101labst` | Boot diagnostics target |

Each subsequent user gets the next /16 block: userB = `10.11.0.0/16`, userC = `10.12.0.0/16`, etc.

---

## Baked-in faults

The Bicep deployment includes intentional misconfigurations. **Do not fix these before the lab.** They are the lab exercises.

### Fault 1 — VM is deallocated

| Detail | Value |
|---|---|
| **Scenario** | VM Troubleshooting (Module 1) |
| **What's wrong** | VM is in `Deallocated` power state |
| **How it was created** | Deployment script runs `az vm deallocate` after VM creation |
| **What students see** | VM shows as stopped/deallocated in the portal Overview page |
| **Expected discovery path** | Check VM Overview → Power state shows deallocated → Review Activity Log for stop/deallocate operation → Note the timestamp |
| **Resolution** | Start the VM from the portal or CLI |
| **Discussion points** | Difference between stopped (still billing for compute reservation) vs deallocated (no compute billing). How Activity Log captures who/what stopped the VM. |

### Fault 2 — Failed VM extension

| Detail | Value |
|---|---|
| **Scenario** | VM Troubleshooting (Module 1) |
| **What's wrong** | Custom Script Extension is in a `Failed` state |
| **How it was created** | Extension attempts to run `/opt/nonexistent-setup-script.sh` which does not exist |
| **What students see** | Extensions + applications blade shows `FailedCustomScript` with a failure status |
| **Expected discovery path** | After starting the VM → Check Extensions blade → See failed extension → Review error message → Identify that the script path does not exist |
| **Resolution** | Remove or fix the failed extension |
| **Discussion points** | Extensions run inside the guest OS. A failed extension does not prevent the VM from running. How to view extension logs (/var/log/azure/). |

### Fault 3 — NSG DenyAllInbound rule

| Detail | Value |
|---|---|
| **Scenario** | NSG / Subnet Validation (Module 2) |
| **What's wrong** | NSG has a `DenyAllInbound` rule at priority 200 that blocks all inbound traffic |
| **How it was created** | Explicit security rule in the Bicep NSG definition |
| **What students see** | After starting the VM, any inbound connectivity attempt fails. Effective security rules show deny at a priority higher than default rules. |
| **Expected discovery path** | Open NSG → Review inbound rules → Notice DenyAllInbound at priority 200 → Recognize this is above the default AllowVnetInBound (65000) → Check Effective security rules on the NIC → Confirm the deny applies |
| **Resolution** | Delete the DenyAllInbound rule, or add a higher-priority allow rule (e.g., priority 100) for required traffic |
| **Discussion points** | NSG rule priority (lower number = higher priority). Default rules vs custom rules. Subnet-level vs NIC-level NSG association. Effective security rules combine both. |

### Fault 4 — Blackhole route

| Detail | Value |
|---|---|
| **Scenario** | Route Table / Routing (Module 3) |
| **What's wrong** | Route table has a `0.0.0.0/0 → None` route that drops all outbound traffic |
| **How it was created** | Custom route in the Bicep route table definition with `nextHopType: 'None'` |
| **What students see** | VM cannot reach any external destination. Effective routes on the NIC show `0.0.0.0/0` with next hop `None`. |
| **Expected discovery path** | Open NIC → Effective routes → See `0.0.0.0/0` next hop `None` → Open route table → Identify `blackhole-default` route → Understand this overrides the default internet route |
| **Resolution** | Delete the `blackhole-default` route from the route table |
| **Discussion points** | Route tables override system routes. `None` next hop means drop traffic. Effective routes show the actual routing behavior, not just what's configured. UDR vs system routes. |

### Fault 5 — Reader role (RBAC)

| Detail | Value |
|---|---|
| **Scenario** | VM Troubleshooting — RBAC Discovery (Module 1) |
| **What's wrong** | Students have `Reader` role on the resource group, which is insufficient to start VMs, modify NSGs, or delete routes |
| **How it was created** | Optional RBAC assignment in Bicep (requires `studentPrincipalId` parameter) |
| **What students see** | "You do not have permission" or "Authorization failed" when attempting to start the VM in Module 1 |
| **Expected discovery path** | Attempt to start VM → Get permission denied → Open Access Control (IAM) on resource group → Review role assignments → See Reader role → Understand Reader allows view but not modify |
| **Resolution** | Proctor upgrades the student to Contributor role (see "Mid-lab RBAC upgrade" below) |
| **Discussion points** | Reader vs Contributor vs Owner. Scope hierarchy (resource, resource group, subscription). Least-privilege principle. Inherited vs direct role assignments. |

### Fault 6 — Missing tags and cost concerns

| Detail | Value |
|---|---|
| **Scenario** | Cost and Policy Validation (Module 5) |
| **What's wrong** | Resources are missing `Department` and `Environment` tags that organization policy may require |
| **How it was created** | Bicep intentionally omits tags on all per-user resources |
| **What students see** | Resources have no tags. If Azure Policy is configured (see "Optional Policy setup"), deployments or compliance checks flag non-compliant resources. |
| **Expected discovery path** | Open any resource → Check Tags → See no tags applied → Review cost implications of resources left running → Identify VM SKU, storage SKU, and disk as cost items |
| **Resolution** | Apply required tags. Identify resources that could be downsized or removed. |
| **Discussion points** | Tags as organizational metadata. Tag governance via Azure Policy. Cost awareness: deallocated VMs still incur disk costs. Storage account costs. How to identify orphaned resources. |

---

## Mid-lab RBAC upgrade

If you configured the RBAC scenario (set `studentPrincipalId` in parameters), students will initially have only `Reader` access. After they complete the RBAC troubleshooting module and identify the problem, upgrade their access:

### Option A — Upgrade via CLI

```bash
# Replace <student-principal-id> with the Entra group or user object ID
az role assignment create \
  --assignee <student-principal-id> \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/azure101lab-rg"
```

### Option B — Upgrade via portal

1. Open the resource group in the Azure portal
2. Go to **Access control (IAM)**
3. Click **Add** → **Add role assignment**
4. Select **Contributor**
5. Select the student group or individual users
6. Click **Review + assign**

### Timing

Upgrade students to Contributor during Module 1, after they discover the Reader role limitation and document their finding. This is typically around the 20-minute mark in a 120-minute delivery. Students need Contributor access to start the VM and continue with the remaining modules.

---

## Optional: Azure Policy setup for tag enforcement

Azure Policy operates at subscription or management group scope, outside the resource group Bicep deployment. To add the policy dimension for Module 5:

### Create a tag enforcement policy assignment

```bash
# Audit resources missing the "Department" tag
az policy assignment create \
  --name "audit-department-tag" \
  --display-name "Audit missing Department tag" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b466-ef6698cc4571" \
  --scope "/subscriptions/<sub-id>/resourceGroups/azure101lab-rg" \
  --params '{"tagName": {"value": "Department"}}'

# Audit resources missing the "Environment" tag
az policy assignment create \
  --name "audit-environment-tag" \
  --display-name "Audit missing Environment tag" \
  --policy "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b466-ef6698cc4571" \
  --scope "/subscriptions/<sub-id>/resourceGroups/azure101lab-rg" \
  --params '{"tagName": {"value": "Environment"}}'
```

This uses the built-in "Require a tag on resources" policy in **Audit** mode (not Deny), so it flags non-compliance without blocking student actions.

Policy compliance evaluation can take up to 30 minutes. Deploy policies before the lab starts.

---

## Scenario walkthrough guide

### Module 1 — VM Troubleshooting + RBAC Discovery (30-35 minutes)

**Business symptom to present:** "A workload owner reports the VM is not responding."

**What's actually wrong:**
1. VM is deallocated (Fault 1)
2. Students have Reader role — cannot start VM (Fault 5)
3. Custom Script Extension failed (Fault 2)

**Expected student investigation:**
1. Open VM Overview — see Power state: `VM deallocated`
2. Check Activity Log — see `Deallocate Virtual Machine` operation
3. Attempt to start the VM — **get permission denied**
4. Open Access Control (IAM) on the resource group
5. Review role assignments — see Reader role
6. Recognize Reader allows view but not modify
7. Document: need Contributor at resource group scope
8. **Notify the proctor** — proctor upgrades to Contributor (see "Mid-lab RBAC upgrade" below)
9. Start the VM successfully
10. After VM starts — check Extensions + applications blade
11. See `FailedCustomScript` in failed state
12. Review extension error detail — script path does not exist
13. Remove the failed extension

**Key teaching moments:**
- Power state vs Provisioning state distinction
- Activity Log as an audit trail for operations
- **Visibility does not equal authority — Reader role prevents write operations**
- **Reader vs Contributor vs Owner role distinction**
- **Scope hierarchy: resource, resource group, subscription, management group**
- **Least-privilege principle: always start with the minimum required role**
- Boot diagnostics and Run command as portal-native management tools (no public IP on this VM)
- Extensions are guest-level operations that leave audit traces

**Proctor action:** After students identify the RBAC problem and document their finding, upgrade them to Contributor (see "Mid-lab RBAC upgrade" below). This typically happens 15-20 minutes into Module 1.

**Wrap-up questions:**
- What is the difference between a stopped and deallocated VM?
- Where would you find who stopped the VM?
- Why couldn't you start the VM initially? What role did you need?
- If you needed to allow someone to only restart VMs, what role would you assign?
- What's the risk of assigning Owner at the subscription level?
- Does a failed extension prevent the VM from running?

---

### Module 2 — NSG / Subnet Validation (15-20 minutes)

**Business symptom to present:** "After starting the VM, traffic is not reaching it as expected."

**What's actually wrong:**
- DenyAllInbound rule at priority 200 blocks all inbound traffic (Fault 3)

**Expected student investigation:**
1. Open VM → Networking (or open the NIC directly)
2. Confirm VM is in the workload subnet
3. Confirm NSG is associated to the workload subnet
4. Open NSG → Inbound security rules
5. See `DenyAllInbound` at priority 200
6. Recognize this blocks everything before any default allow rules fire
7. Check Effective security rules on the NIC — confirm deny applies
8. Delete the rule or add a higher-priority allow

**Key teaching moments:**
- NSG rule priority: lower number = higher priority = evaluated first
- Default rules (65000-65500) are always present but custom rules override them
- Effective security rules show the combined, evaluated view
- Subnet-level NSG vs NIC-level NSG — where to look

**Wrap-up questions:**
- If you add an allow rule at priority 300, will traffic get through? Why or why not?
- What is the difference between subnet-level and NIC-level NSG association?
- How do you view what rules are actually being applied vs configured?

---

### Module 3 — Route Table / Routing (15-20 minutes)

**Business symptom to present:** "After fixing the NSG, the VM still cannot reach external destinations."

**What's actually wrong:**
- Route table has `0.0.0.0/0 → None` blackhole route (Fault 4)

**Expected student investigation:**
1. Open the NIC → Effective routes
2. See `0.0.0.0/0` with next hop type `None`
3. Open the route table associated to the workload subnet
4. See `blackhole-default` custom route
5. Understand `None` means "drop the traffic"
6. Delete the `blackhole-default` route
7. Verify Effective routes now show the system default route for internet

**Key teaching moments:**
- User-defined routes (UDR) override system routes
- `None` next hop drops traffic silently — no ICMP unreachable
- Effective routes are the source of truth, not the route table alone
- Route tables affect the entire subnet, not individual NICs

**Wrap-up questions:**
- What would happen if the next hop was a virtual appliance IP that doesn't exist?
- How would you add a route for a specific destination without affecting all traffic?
- Where do system routes come from?

---

### Module 4 — Azure Monitor and KQL Triage (15-20 minutes)

**Business symptom to present:** "Your team lead wants evidence of what went wrong. Show them."

**What students should find:**
- No new fault to discover — students use Monitor and KQL to find evidence of Faults 1-4

**Expected student investigation:**
1. Open Monitor → Activity Log (or Log Analytics workspace)
2. Filter to the lab resource group and last few hours
3. Find the VM deallocate operation (Fault 1 evidence)
4. Find the extension failure event (Fault 2 evidence)
5. Find NSG or route modification operations if students already fixed them
6. Run KQL queries against the Log Analytics workspace:

```kusto
// Find all operations in the resource group
AzureActivity
| where TimeGenerated > ago(4h)
| project TimeGenerated, OperationNameValue, ActivityStatusValue, Caller
| order by TimeGenerated desc
```

```kusto
// Look for failed operations
AzureActivity
| where TimeGenerated > ago(4h)
| where ActivityStatusValue == "Failed" or ActivityStatusValue == "Failure"
| project TimeGenerated, OperationNameValue, ActivityStatusValue, Properties
```

```kusto
// Check VM heartbeat (may show gaps from when VM was deallocated)
Heartbeat
| where TimeGenerated > ago(4h)
| summarize LastSeen=max(TimeGenerated) by Computer
```

**Key teaching moments:**
- Activity Log records control plane operations (who did what, when)
- KQL is a powerful filter/analysis tool — start broad, then narrow
- Heartbeat gaps correlate with VM state changes
- Evidence-based troubleshooting vs guessing

**Wrap-up questions:**
- How would you find who made a change to the NSG?
- What's the difference between Activity Log and Diagnostics logs?
- Can you set up an alert to notify you when a VM is deallocated?

---

### Module 5 — Cost and Policy Validation (15-20 minutes)

**Business symptom to present:** "Before we hand this environment off, review it for compliance and cost concerns."

**What students should find:**
- Resources have no tags (Fault 6)
- Deallocated VMs still have managed disks incurring cost
- Storage accounts incur cost even if empty
- If Azure Policy is configured: compliance dashboard shows non-compliant resources

**Expected student investigation:**
1. Open any resource → Tags → See no tags
2. Review the resource list — identify cost-bearing items
3. Note: deallocated VM = no compute charge, but disk still costs money
4. Note: storage account exists and costs money even if unused
5. If policy is configured: open Policy → Compliance → See non-compliant resources
6. Document what tags should be applied and what resources could be cleaned up

**Key teaching moments:**
- Tags are metadata for billing, ownership, and environment tracking
- Deallocated ≠ free — disks, IPs, and storage still cost
- Azure Policy can audit or enforce governance standards
- Cost hygiene: regularly review what's running and what's needed

**Wrap-up questions:**
- What costs remain when a VM is deallocated?
- How would you enforce that all resources must have a Department tag?
- What's the difference between Audit and Deny policy effects?

---

## Delivery timing

### 120-minute agenda

| Time | Module | Notes |
|---|---|---|
| 0:00-0:10 | Orientation | Introduce lab, hand out prefixes, confirm portal access |
| 0:10-0:45 | VM Troubleshooting + RBAC | Faults 1-2 + Fault 5: deallocated VM, Reader role, failed extension. Upgrade to Contributor mid-module. |
| 0:45-1:05 | NSG / Subnet Validation | Fault 3: DenyAllInbound rule |
| 1:05-1:25 | Route Table / Routing | Fault 4: blackhole route |
| 1:25-1:40 | Azure Monitor and KQL | Evidence gathering for all previous faults |
| 1:40-1:55 | Cost and Policy | Fault 6: missing tags, cost review |
| 1:55-2:00 | Wrap-up | Recap findings, discuss teardown |

### 90-minute condensed agenda

| Time | Module | Notes |
|---|---|---|
| 0:00-0:10 | Orientation | Introduce lab, hand out prefixes |
| 0:10-0:40 | VM Troubleshooting + RBAC | Faults 1-2 + Fault 5. Upgrade to Contributor mid-module. |
| 0:40-0:55 | NSG + Routing | Faults 3-4 (combined) |
| 0:55-1:10 | Azure Monitor and KQL | Evidence gathering |
| 1:10-1:20 | Cost and Policy | Fault 6 |
| 1:20-1:30 | Wrap-up | Recap, teardown |

---

## Teardown

After the lab is complete:

### Delete the resource group (removes everything)

```bash
az group delete --name azure101lab-rg --yes --no-wait
```

### Remove policy assignments (if configured)

```bash
az policy assignment delete --name "audit-department-tag" \
  --scope "/subscriptions/<sub-id>/resourceGroups/azure101lab-rg"

az policy assignment delete --name "audit-environment-tag" \
  --scope "/subscriptions/<sub-id>/resourceGroups/azure101lab-rg"
```

### Confirm cleanup

```bash
az group show --name azure101lab-rg 2>/dev/null && echo "Still exists" || echo "Deleted"
```

---

## Troubleshooting the deployment itself

### Deployment fails on VM availability

If the region does not have `Standard_B1s` capacity, either:
- change `location` to a different region
- or edit `user-environment.bicep` to use `Standard_B1ls_v2` or another small burstable SKU

### Deployment script fails (VM deallocate)

The deployment script uses a user-assigned managed identity. If it fails:
1. Check the deployment script logs in the portal (resource type: `Microsoft.Resources/deploymentScripts`)
2. Verify the managed identity has Contributor on the resource group
3. The identity role assignment and the deployment script are in the same deployment — if the identity was just created, the role may take a few minutes to propagate. Re-run the deployment.

### Storage account name conflict

Storage account names are globally unique. If a name is taken, edit the naming pattern in `user-environment.bicep` to add a short suffix.

### RBAC assignment fails

If `studentPrincipalId` is incorrect or the principal does not exist, the RBAC assignment will fail. Verify the Object ID:

```bash
# For a group
az ad group show --group "<group-name>" --query id --output tsv

# For a user
az ad user show --id "<user@domain.com>" --query id --output tsv
```
