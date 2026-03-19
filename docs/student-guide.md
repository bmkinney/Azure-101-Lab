# Student Guide

## Overview

This lab is a 90-120 minute hands-on Azure Operations lab. Your lab environment has been pre-deployed by the proctor. Each participant works in a sandbox subscription and is responsible for troubleshooting resources inside their own environment.

Your environment contains intentional misconfigurations. Your job is to find them, diagnose the root cause, and fix them.

## Learning objectives

By the end of the lab, participants should be able to:

- validate VM, network, and storage configuration
- troubleshoot VM state and extension issues
- troubleshoot NSG and routing issues using effective methods
- use Azure Monitor and basic KQL for triage and evidence gathering
- recognize RBAC scope issues and permission problems
- identify basic cost and policy concerns

## Lab assumptions

- a sandbox subscription already exists
- your lab environment has been pre-deployed by the proctor
- each participant has resources deployed under their assigned user prefix
- Azure Policy may already be applied at the subscription or management group scope

## Your assigned environment

Your proctor will give you:
- your assigned user prefix (e.g., `userA`)
- your resource group name (e.g., `azure101lab-userA-rg`)
- login credentials for your VM

### Naming convention

All resources in your environment follow this pattern:

- virtual network: `<userPrefix>-vnet`
- management subnet: `<userPrefix>-mgmt-snet`
- workload subnet: `<userPrefix>-workload-snet`
- network security group: `<userPrefix>-nsg`
- route table: `<userPrefix>-rt`
- virtual machine: `<userPrefix>-vm`
- network interface: `<userPrefix>-nic`
- storage account: `<userPrefix>azure101labst` (lowercase, no hyphens)

### Your environment resources

| Resource | Name (example for `userA`) | Notes |
|---|---|---|
| Virtual Network | `userA-vnet` | Contains management and workload subnets |
| Network Security Group | `userA-nsg` | Associated to workload subnet |
| Route Table | `userA-rt` | Associated to workload subnet |
| Network Interface | `userA-nic` | In workload subnet, no public IP |
| Virtual Machine | `userA-vm` | Ubuntu 22.04, Standard_B1s |
| Storage Account | `useraazure101labst` | Boot diagnostics |

### Important notes

- this lab does not assign a public IP directly to the VM NIC
- for guest-level troubleshooting, use portal-native tools such as boot diagnostics, serial console, and Run command
- the VM is a private resource — direct internet SSH is not part of the design
- you share a Log Analytics workspace (in a separate shared resource group) with other participants for KQL exercises

## Azure Cloud Shell first-time use

Azure Cloud Shell is the easiest way to run Azure CLI commands directly from the Azure portal.

### First-time Cloud Shell setup in the portal

1. Sign in to the Azure portal.
2. Select the `Cloud Shell` icon in the top navigation bar.
3. Choose `Bash` when prompted.
4. If this is your first time using Cloud Shell, Azure will ask you to create backing storage.
5. Create the Cloud Shell storage in the subscription and region approved for your sandbox.
6. Wait for the shell session to initialize.
7. Run the following command to confirm the CLI is available:

```bash
az version --output table
```

### Important Cloud Shell notes

- Cloud Shell creates supporting storage resources for the shell session.
- Those Cloud Shell resources are separate from the lab resources.
- If your organization has a preferred resource group for shared tooling, use that rather than your lab resource group.
- If Cloud Shell is blocked by policy, you can run the same commands from a local Azure CLI installation.

### Initial CLI setup commands

Run these commands once at the start of the lab.

```bash
## To view your current subscription context.
az account show --output table
```

If you need to change subscriptions:

```bash
## List subscriptions
az account list --output table
## Set the subscription to the identified sandbox subscription for this lab.
az account set --subscription "<subscription-name-or-id>"
az account show --output table
```

### Set your shell variables

Use these commands to define the names used throughout the rest of the lab. Replace values if your assigned prefix is different.

```bash
userPrefix="userA"
resourceGroupName="azure101lab-${userPrefix}-rg"
vnetName="${userPrefix}-vnet"
nsgName="${userPrefix}-nsg"
routeTableName="${userPrefix}-rt"
nicName="${userPrefix}-nic"
vmName="${userPrefix}-vm"
storageAccountName="${userPrefix}azure101labst"
```

Optional defaults for the current shell session:

```bash
az configure --defaults group=$resourceGroupName
```

## Lab flow

1. Orient yourself with the pre-deployed environment
2. Troubleshoot the VM (includes RBAC discovery when a write action fails)
3. Troubleshoot the network (NSG and routing)
4. Gather evidence using Azure Monitor and KQL
5. Review cost and policy compliance
6. Discuss findings

Each module below includes an expandable solution and validation section. Try the task first, then expand the solution section only if you need confirmation, a recovery path, or additional Microsoft Learn references.

---

## Module 0 — Orientation

### Objective

Understand the lab scope, your pre-deployed environment, and what you need to find and fix.

### Tasks

- confirm the resource group and your assigned user prefix with the proctor
- open the Azure portal and navigate to the resource group
- identify all resources deployed under your prefix
- confirm you can access Azure Cloud Shell
- identify where to find Activity Log, Access Control (IAM), Network Watcher, and Log Analytics
- review the resource list and understand the relationships between VNet, subnets, NSG, route table, NIC, and VM

### Success criteria

- you know which resources are yours
- you know what portal views you will use for troubleshooting
- you have Cloud Shell or CLI ready

---

## Module 1 — VM Troubleshooting

### Business symptom

A workload owner reports that the VM is not responding.

### Objective

Determine whether the issue is caused by VM state, guest configuration, permissions, or network access.

### Tasks

- check VM power state and provisioning state
- review the Activity Log for recent operations on the VM
- attempt to remediate the VM state issue
- if a write action fails, investigate why
- inspect boot diagnostics if available
- check extension status for failures
- determine the remediation steps

### Validation checks

- identify the VM state issue
- identify any permissions issues preventing remediation
- identify any extension problems
- explain the next remediation actions

### Hints

- Hint 1: Start with the VM Overview page — what does the power state say?
- Hint 2: Check the Activity Log for operations that changed the VM state.
- Hint 3: Try to fix the state — if you get a permissions error, investigate IAM.
- Hint 4: After fixing the VM state, check the Extensions + applications blade.
- Hint 5: This VM does not have a direct public IP. Use serial console, Run command, or boot diagnostics for guest-level investigation.

### Useful CLI commands

```bash
# Check VM power state
az vm get-instance-view \
  --resource-group $resourceGroupName \
  --name $vmName \
  --query "instanceView.statuses[].{code:code, displayStatus:displayStatus}" \
  --output table

# Check VM details
az vm show \
  --resource-group $resourceGroupName \
  --name $vmName \
  --show-details \
  --query "{name:name, powerState:powerState, provisioningState:provisioningState}" \
  --output table

# Start the VM
az vm start \
  --resource-group $resourceGroupName \
  --name $vmName

# Check your role assignments on the resource group
az role assignment list \
  --resource-group $resourceGroupName \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --output table

# List extensions
az vm extension list \
  --resource-group $resourceGroupName \
  --vm-name $vmName \
  --output table
```

<details>
<summary>Show Module 1 solution and validation</summary>

### What's wrong

1. **The VM is deallocated.** The power state shows `VM deallocated`. It needs to be started.
2. **You have Reader role.** When you try to start the VM, you get a permission denied error. Reader allows viewing resources but not modifying them.
3. **A custom script extension has failed.** After the permissions issue is resolved and the VM is started, the `FailedCustomScript` extension is in a failed state.

### Solution steps

#### Part A — Discover the VM is deallocated

1. Open the VM Overview page.
2. Note the Power state: `VM deallocated`.
3. Open the Activity Log for the VM, filter to the last few hours.
4. Find the `Deallocate Virtual Machine` operation — this confirms something stopped the VM.

#### Part B — RBAC discovery (sub-module)

5. Attempt to start the VM from the Overview page or CLI (`az vm start`).
6. You receive an error: **"You do not have permission"** or **"Authorization failed"**.
7. Open **Access Control (IAM)** on the resource group.
8. Click **View my access** or check **Role assignments**.
9. See that your account has `Reader` assigned at the resource group scope.
10. Recognize: **Reader = view only.** You need `Contributor` to modify resources.
11. Check subscription scope — is there a higher-level assignment? (Likely not.)
12. Document: the minimum fix is to assign `Contributor` at the resource group scope.
13. **Notify your proctor** that you have identified the RBAC issue. The proctor will upgrade your access to Contributor.

#### Part C — Fix the VM and extension

14. After the proctor upgrades your access, start the VM from the Overview page or CLI (`az vm start`).
15. After the VM starts, open Extensions + applications.
16. Find `FailedCustomScript` in a failed state.
17. Review the error message — the script path `/opt/nonexistent-setup-script.sh` does not exist.
18. Remove the failed extension from the portal or CLI:

```bash
az vm extension delete \
  --resource-group $resourceGroupName \
  --vm-name $vmName \
  --name FailedCustomScript
```

### Expected outcomes

- you can distinguish a deallocated VM from a running one
- you found evidence in the Activity Log of when and how the VM was stopped
- you discovered that visibility does not equal authority — Reader role prevents write operations
- you understand the difference between Reader, Contributor, and Owner roles
- you understand scope hierarchy (resource, resource group, subscription) and inheritance
- you identified a failed extension and understood it runs inside the guest OS
- you understand that portal-native tools (boot diagnostics, Run command, serial console) are the management path when there is no public IP

### Module completion check

You are done with Module 1 when:

- you identified the deallocate operation in the Activity Log
- you identified Reader role as the cause of the permissions error
- you documented the least-privilege fix (Contributor at resource group scope)
- the proctor upgraded your access
- the VM is running
- you addressed the failed extension

### Microsoft Learn references

- Azure Virtual Machines monitoring data reference: https://learn.microsoft.com/azure/virtual-machines/monitor-vm-reference
- Serial console for Linux virtual machines: https://learn.microsoft.com/troubleshoot/azure/virtual-machines/linux/serial-console-linux
- Azure RBAC overview: https://learn.microsoft.com/azure/role-based-access-control/overview
- Understand scope for Azure RBAC: https://learn.microsoft.com/azure/role-based-access-control/scope-overview
- Troubleshoot Azure RBAC: https://learn.microsoft.com/azure/role-based-access-control/troubleshooting

</details>

---

## Module 2 — NSG / Subnet Validation

### Business symptom

After starting the VM, traffic is not reaching it as expected.

### Objective

Validate whether the problem is caused by subnet design, NSG rules, or both.

### Tasks

- confirm which subnet the VM NIC is using
- review the NSG associated to the subnet
- review NSG inbound and outbound rules
- review effective security rules on the NIC
- determine what is blocking traffic and fix it

### Validation checks

- identify the specific rule causing the issue
- describe how to remediate it

### Hints

- Hint 1: Open the NSG and carefully read the inbound rules and their priorities.
- Hint 2: Lower priority number = higher priority = evaluated first.
- Hint 3: Check effective security rules on the NIC to see the combined enforced rules.
- Hint 4: Compare custom rules to the default rules — which ones fire first?

### Useful CLI commands

```bash
# Check subnet NSG association
az network vnet subnet show \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --name "${userPrefix}-workload-snet" \
  --query "{subnet:name, nsg:networkSecurityGroup.id}" \
  --output jsonc

# List NSG rules
az network nsg rule list \
  --resource-group $resourceGroupName \
  --nsg-name $nsgName \
  --output table

# Show effective security rules
az network nic show-effective-nsg \
  --resource-group $resourceGroupName \
  --name $nicName \
  --output table
```

<details>
<summary>Show Module 2 solution and validation</summary>

### What's wrong

The NSG has a **DenyAllInbound** rule at **priority 200**. This blocks all inbound traffic before any default allow rules (which start at priority 65000) can apply.

### Solution steps

1. Open the VM → Networking, or open the NIC directly.
2. Confirm the NIC is in the workload subnet.
3. Open the NSG (`<userPrefix>-nsg`).
4. Review Inbound security rules.
5. Find `DenyAllInbound` at priority 200 — this denies all inbound traffic from any source.
6. Recognize that default rules like `AllowVnetInBound` (priority 65000) cannot override this because 200 < 65000.
7. Fix: delete the `DenyAllInbound` rule, or add a more specific allow rule at a priority lower than 200 (e.g., 100).

```bash
# Delete the deny rule
az network nsg rule delete \
  --resource-group $resourceGroupName \
  --nsg-name $nsgName \
  --name DenyAllInbound
```

8. Verify effective security rules after the fix.

### Expected outcomes

- you understand NSG rule priority evaluation order
- you can read effective security rules and compare to raw configuration
- you can fix an overly broad deny rule

### Module completion check

You are done with Module 2 when:

- you identified the blocking rule and its priority
- you fixed the NSG configuration
- you verified with effective security rules

### Microsoft Learn references

- Diagnose network traffic filtering problems: https://learn.microsoft.com/azure/virtual-network/diagnose-network-traffic-filter-problem
- Network security groups overview: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview

</details>

---

## Module 3 — Route Table / Routing

### Business symptom

After fixing the NSG, the VM still cannot reach external destinations.

### Objective

Determine whether the route table is causing the connectivity problem.

### Tasks

- review the effective routes on the VM NIC
- review the route table associated to the workload subnet
- identify any routes that drop or redirect traffic unexpectedly
- remediate the routing issue

### Validation checks

- identify the problematic route
- explain why the route causes the failure
- confirm the fix

### Hints

- Hint 1: Check effective routes on the NIC — the source of truth for routing.
- Hint 2: A custom route with next hop `None` drops traffic silently.
- Hint 3: User-defined routes override system default routes.

### Useful CLI commands

```bash
# Show effective routes on the NIC
az network nic show-effective-route-table \
  --resource-group $resourceGroupName \
  --name $nicName \
  --output table

# Show route table configuration
az network route-table route list \
  --resource-group $resourceGroupName \
  --route-table-name $routeTableName \
  --output table
```

<details>
<summary>Show Module 3 solution and validation</summary>

### What's wrong

The route table has a custom route `blackhole-default` with address prefix `0.0.0.0/0` and next hop type `None`. This drops all outbound traffic to the internet.

### Solution steps

1. Open the NIC → Effective routes.
2. Find the route `0.0.0.0/0` with next hop `None`.
3. Open the route table (`<userPrefix>-rt`).
4. Find the `blackhole-default` route.
5. Understand: `nextHopType: None` means the traffic is silently dropped.
6. Delete the route:

```bash
az network route-table route delete \
  --resource-group $resourceGroupName \
  --route-table-name $routeTableName \
  --name blackhole-default
```

7. Verify effective routes — `0.0.0.0/0` should now show the system default route with next hop `Internet`.

### Expected outcomes

- you understand that custom routes override system routes
- you know what `None` next hop means
- you can use effective routes to see actual routing behavior vs configuration

### Module completion check

You are done with Module 3 when:

- you identified the blackhole route
- you removed it
- you verified effective routes show the correct default route

### Microsoft Learn references

- Diagnose virtual machine routing problems: https://learn.microsoft.com/troubleshoot/azure/virtual-network/diagnose-network-routing-problem
- Manage route tables: https://learn.microsoft.com/azure/virtual-network/manage-route-table

</details>

---

## Module 4 — Azure Monitor and KQL Triage

### Business symptom

The team needs evidence, not guesses, about what happened to this environment.

### Objective

Use Azure monitoring data and KQL to find evidence of the issues you have already troubleshot.

### Tasks

- open the Activity Log for the resource group
- identify operations related to the VM being stopped, the extension failure, and any changes you made
- open the shared Log Analytics workspace
- run KQL queries to surface relevant events
- correlate log evidence to the issues you found in earlier modules

### Sample KQL starter queries

Use only the tables available in your environment.

```kusto
// Recent activity in the resource group
AzureActivity
| where TimeGenerated > ago(4h)
| project TimeGenerated, OperationNameValue, ActivityStatusValue, Caller, ResourceGroup
| order by TimeGenerated desc
```

```kusto
// Failed operations
AzureActivity
| where TimeGenerated > ago(4h)
| where ActivityStatusValue == "Failed" or ActivityStatusValue == "Failure"
| project TimeGenerated, OperationNameValue, ActivityStatusValue, Properties
```

```kusto
// VM heartbeat (may show gaps from deallocated period)
Heartbeat
| where TimeGenerated > ago(4h)
| summarize LastSeen=max(TimeGenerated) by Computer
```

```kusto
// Diagnostics if available
AzureDiagnostics
| where TimeGenerated > ago(4h)
| take 50
```

### Validation checks

- identify at least one useful query result
- correlate log evidence to one of the earlier troubleshooting scenarios

### Hints

- Hint 1: Start with `AzureActivity` — it captures control plane operations like VM start, stop, and configuration changes.
- Hint 2: Look for the VM deallocate event and any extension failure events.
- Hint 3: Not every table exists in every environment. Use `search *` or check available tables first.

<details>
<summary>Show Module 4 solution and validation</summary>

### What to find

There is no new fault to discover. This module is about using monitoring tools to find evidence of the faults from earlier modules.

### Solution steps

1. Open Monitor → Activity Log or navigate to the resource group Activity Log.
2. Filter to the last 4 hours and your resource group.
3. Look for:
   - `Deallocate Virtual Machine` — evidence of the VM being stopped
   - Extension deployment operations — evidence of the failed custom script
   - Any NSG or route table modifications — evidence of your own fixes
4. Open the shared Log Analytics workspace.
5. Run the AzureActivity query to see all operations.
6. Run the failed operations query to find failures.
7. Run the Heartbeat query — if the VM has been running, you should see a recent heartbeat. Gaps indicate when the VM was down.
8. Correlate timestamps between events.

### Expected outcomes

- you identify the VM deallocate event with timestamp and caller
- you find extension failure events
- you run at least one useful KQL query
- you connect evidence to fault domains rather than guessing

### Module completion check

You are done with Module 4 when:

- you used Activity Log or KQL to find evidence of at least two earlier faults
- you can explain what happened and when

### Microsoft Learn references

- Azure Activity Log overview: https://learn.microsoft.com/azure/azure-monitor/essentials/activity-log
- Log queries in Azure Monitor: https://learn.microsoft.com/azure/azure-monitor/logs/log-query-overview
- Kusto query language overview: https://learn.microsoft.com/azure/data-explorer/kusto/query/

</details>

---

## Module 5 — Cost and Policy Validation

### Business symptom

The team wants to know whether this environment is compliant and cost-aware.

### Objective

Review the environment for obvious cost waste and policy constraints.

### Tasks

- inspect resources for missing tags
- review SKUs and sizing decisions
- check whether policy flags any non-compliant resources
- identify what costs money even when the VM is deallocated
- document what should be cleaned up or changed

### Validation checks

- identify one cost concern and one governance concern
- explain what change you would make to improve both

### Hints

- Hint 1: Check the Tags blade on your resources.
- Hint 2: A deallocated VM does not mean free — what else costs money?
- Hint 3: Check Policy compliance views if available.
- Hint 4: Cost awareness in this lab is about good habits, not exact budgeting.

<details>
<summary>Show Module 5 solution and validation</summary>

### What's wrong

1. **Resources have no tags.** All resources are missing `Department` and `Environment` tags that organizational policy may require.
2. **Cost items persist even with a deallocated VM.** The managed OS disk and storage account incur costs whether the VM is running or not.

### Solution steps

1. Open any resource in your prefix → Tags → Notice no tags are applied.
2. Review the full resource list in the resource group.
3. Identify cost-bearing items:
   - VM managed OS disk (billed even when VM is deallocated)
   - Storage account (billed even if empty)
   - Log Analytics workspace ingestion (shared cost)
4. If Azure Policy is configured, open Policy → Compliance.
5. Look for non-compliant resources flagged for missing tags.
6. Apply tags where required:

```bash
# Apply tags to a resource (replace <sub-id> with your subscription ID)
az tag update \
  --resource-id "/subscriptions/<sub-id>/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$vmName" \
  --operation merge \
  --tags Department=Lab Environment=Training
```

7. Document what resources could be cleaned up after the lab.

### Expected outcomes

- you identify missing tags as a governance concern
- you understand that deallocated VMs still have cost (disk, storage)
- you know how Azure Policy can audit or enforce tag compliance
- you can identify cleanup candidates

### Module completion check

You are done with Module 5 when:

- you identified at least one cost concern
- you identified at least one governance concern
- you documented cleanup recommendations

### Microsoft Learn references

- Azure Policy overview: https://learn.microsoft.com/azure/governance/policy/overview
- Microsoft Cost Management: https://learn.microsoft.com/azure/cost-management-billing/

</details>

---

## What to record during the lab

For each module, record:

- the symptom
- the tools you used (portal, CLI, or both)
- the evidence you found
- the root cause
- the remediation you applied

## Microsoft Learn references

- Get started with Azure Cloud Shell: https://learn.microsoft.com/azure/cloud-shell/quickstart
- Azure Cloud Shell overview: https://learn.microsoft.com/azure/cloud-shell/overview
- Prepare your environment for the Azure CLI: https://learn.microsoft.com/cli/azure/get-started-tutorial-1-prepare-environment
- Network security groups overview: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview
- Manage route tables: https://learn.microsoft.com/azure/virtual-network/manage-route-table
- Storage account overview: https://learn.microsoft.com/azure/storage/common/storage-account-overview
- Azure RBAC overview: https://learn.microsoft.com/azure/role-based-access-control/overview
- Azure Policy overview: https://learn.microsoft.com/azure/governance/policy/overview
- Log queries in Azure Monitor: https://learn.microsoft.com/azure/azure-monitor/logs/log-query-overview

## Teardown

At the end of the lab:

- your proctor will handle resource cleanup
- confirm that you have saved your notes for the recap discussion
- do not delete resources unless instructed by the proctor
