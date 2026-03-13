# Student Guide

## Overview

This lab is a 90-120 minute hands-on Azure Operations lab. Each participant works in a sandbox subscription and is responsible for building and troubleshooting resources inside their own resource group.

## Learning objectives

By the end of the lab, participants should be able to:

- build a basic Azure environment in a dedicated resource group
- validate VM, network, and storage configuration
- troubleshoot NSG and routing issues
- use Azure Monitor and basic KQL for triage
- recognize RBAC scope issues
- identify basic cost and policy concerns

## Lab assumptions

- a sandbox subscription already exists
- each participant has a dedicated resource group or permission to create one
- each participant has `Contributor` on their own resource group
- Azure Policy may already be applied at the subscription or management group scope

## Required naming convention and variables

Use your assigned user prefix for every resource created in this lab. The intent is that each participant can be identified quickly and all resources in the sandbox remain easy to track.

### User prefix rule

- your prefix should be your assigned username or alias
- use the same prefix for every resource in the lab
- example user prefix: `userA`

### Naming standard

For this lab, use the following pattern:

- resource group: `<userPrefix>-azure101lab-rg`
- all other resources: `<userPrefix>-<resource-purpose>`

Example for `userA`:

- resource group: `userA-azure101lab-rg`
- virtual network: `userA-vnet`
- management subnet: `userA-mgmt-snet`
- workload subnet: `userA-workload-snet`
- network security group: `userA-nsg`
- route table: `userA-rt`
- NAT gateway: `userA-nat`
- NAT public IP: `userA-nat-pip`
- virtual machine: `userA-vm`

Storage accounts have stricter naming rules in Azure. Use lowercase letters and numbers only.

Example storage account for `userA`:

- `useraazure101labst`

### Lab variables

Use the following values unless your sandbox subscription requires different values.

| Variable | Example value for `userA` | Notes |
|---|---|---|
| `userPrefix` | `userA` | Your assigned lab prefix |
| `resourceGroupName` | `userA-azure101lab-rg` | Required naming pattern |
| `vnetName` | `userA-vnet` | Main lab VNet |
| `vnetAddressSpace` | `10.20.0.0/16` | Must not overlap with your subnet ranges |
| `mgmtSubnetName` | `userA-mgmt-snet` | Management subnet |
| `mgmtSubnetPrefix` | `10.20.1.0/24` | Subnet inside the VNet range |
| `workloadSubnetName` | `userA-workload-snet` | Workload subnet |
| `workloadSubnetPrefix` | `10.20.2.0/24` | Subnet inside the VNet range |
| `nsgName` | `userA-nsg` | NSG for subnet or NIC association |
| `routeTableName` | `userA-rt` | Route table for routing exercises |
| `nicName` | `userA-nic` | NIC used by the lab VM |
| `natGatewayName` | `userA-nat` | NAT gateway for outbound internet access |
| `natPublicIpName` | `userA-nat-pip` | Standard public IP attached to the NAT gateway |
| `vmName` | `userA-vm` | Main lab virtual machine |
| `vmImage` | `Ubuntu2204` | Default Ubuntu image for this lab |
| `vmSize` | `Standard_B1s` | Burstable SKU chosen for fast, low-cost lab deployment |
| `adminUsername` | `azureuser` | Default Linux admin user for the VM |
| `location` | `eastus` | Use the sandbox-approved region |
| `storageAccountName` | `useraazure101labst` | Lowercase and globally unique |

### Important notes

- all resource names except the storage account should keep your user prefix exactly as assigned
- the storage account name must be lowercase and cannot contain hyphens
- if your storage account name is already taken globally, append a short numeric suffix while keeping the same user prefix at the start of the name
- if your sandbox subscription requires a different IP range, use the subscription-approved values instead
- if policy blocks a name or region choice, record that outcome as part of the lab
- this lab uses a small Ubuntu VM on a burstable SKU to keep deployment time and cost low
- this lab does not assign a public IP directly to the VM NIC
- outbound internet access should use a NAT gateway associated to the workload subnet
- this lab treats the VM as a private resource, so direct internet SSH is not part of the default design
- for guest-level troubleshooting, prefer portal-native tools such as boot diagnostics, serial console, and Run command

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
- Those Cloud Shell resources are separate from the Azure 101 lab resources.
- If your organization has a preferred resource group for shared tooling, use that rather than your lab resource group.
- If Cloud Shell is blocked by policy, you can run the same commands from a local Azure CLI installation.

### Initial CLI setup commands

Run these commands once at the start of the lab.

```bash
az account show --output table
az account list-locations --query "[].{Region:name}" --output table
```

If you need to change subscriptions:

```bash
az account set --subscription "<subscription-name-or-id>"
az account show --output table
```

### Set your shell variables

Use these commands to define the names used throughout the rest of the lab. Replace values if your assigned prefix or approved region is different.

```bash
userPrefix="userA"
location="eastus"
resourceGroupName="${userPrefix}-azure101lab-rg"
vnetName="${userPrefix}-vnet"
vnetAddressSpace="10.20.0.0/16"
mgmtSubnetName="${userPrefix}-mgmt-snet"
mgmtSubnetPrefix="10.20.1.0/24"
workloadSubnetName="${userPrefix}-workload-snet"
workloadSubnetPrefix="10.20.2.0/24"
nsgName="${userPrefix}-nsg"
routeTableName="${userPrefix}-rt"
nicName="${userPrefix}-nic"
natGatewayName="${userPrefix}-nat"
natPublicIpName="${userPrefix}-nat-pip"
vmName="${userPrefix}-vm"
vmImage="Ubuntu2204"
vmSize="Standard_B1s"
adminUsername="azureuser"
storageAccountName="useraazure101labst"
```

Optional defaults for the current shell session:

```bash
az configure --defaults group=$resourceGroupName location=$location
```

## Lab flow

1. Build the core environment
2. Validate that the environment is functional
3. Work through the troubleshooting scenarios
4. Capture findings and fixes
5. Clean up resources at the end

Each module below includes an expandable solution and validation section. Try the task first, then expand the solution section only if you need confirmation, a recovery path, or additional Microsoft Learn references.

## Module 0 - orientation

### Objective
Understand the lab scope, resource relationships, and success criteria.

### Tasks
- confirm the subscription and resource group you will use
- confirm your assigned `userPrefix`
- confirm the naming and IP variables you will use for the lab
- open Azure Cloud Shell and verify `az` is working if you plan to use the CLI path
- review the resource map in the repository materials
- confirm what permissions you have
- identify where to find Activity Log, Access Control, Network Watcher, and Log Analytics

### Success criteria
- you know which resource group is yours
- you know the exact naming pattern for every resource you will create
- you know which Azure tools you are expected to use during the lab

## Module 1 - build the core environment

### Objective
Create a small Azure environment that will be used for all later troubleshooting tasks.

### Required resources
- 1 virtual network
- 2 subnets
- 1 network security group
- 1 route table
- 1 NAT gateway
- 1 Standard public IP for the NAT gateway
- 1 network interface
- 1 Ubuntu virtual machine on a burstable SKU
- 1 storage account

### Tasks
- create the resource group using your assigned naming pattern if it does not already exist
- create the virtual network using your assigned `vnetName` and `vnetAddressSpace`
- create the two subnets using your assigned subnet names and prefixes
- create the NSG and associate it to the appropriate subnet or NIC
- create the route table and associate it to the workload subnet
- create a NAT gateway for outbound internet access and associate it to the workload subnet
- create the NIC without assigning a public IP directly to it
- deploy a small Ubuntu VM named with your user prefix into the workload subnet
- create a storage account in the same resource group using the required lowercase naming convention
- enable boot diagnostics if available in the chosen flow

### Task 1 - create or validate the resource group

#### Portal steps
- open `Resource groups` in the Azure portal
- select `Create` if the resource group does not already exist
- use `resourceGroupName` for the name
- use the approved `location`
- apply required tags if policy requires them

#### Azure CLI commands

```bash
az group create \
	--name $resourceGroupName \
	--location $location \
	--output table
```

#### Verify with Azure CLI

```bash
az group show \
	--name $resourceGroupName \
	--query "{name:name,location:location,provisioningState:properties.provisioningState}" \
	--output table
```

### Task 2 - create the virtual network and management subnet

#### Portal steps
- open `Virtual networks`
- select `Create`
- use `vnetName` for the VNet name
- use `vnetAddressSpace` for the address space
- create the first subnet using `mgmtSubnetName` and `mgmtSubnetPrefix`

#### Azure CLI commands

```bash
az network vnet create \
	--resource-group $resourceGroupName \
	--name $vnetName \
	--location $location \
	--address-prefixes $vnetAddressSpace \
	--subnet-name $mgmtSubnetName \
	--subnet-prefixes $mgmtSubnetPrefix \
	--output table
```

#### Verify with Azure CLI

```bash
az network vnet show \
	--resource-group $resourceGroupName \
	--name $vnetName \
	--query "{name:name,addressSpace:addressSpace.addressPrefixes,subnets:subnets[].{name:name,prefix:addressPrefix}}" \
	--output jsonc
```

### Task 3 - create the workload subnet

#### Portal steps
- open your VNet
- open `Subnets`
- create a second subnet using `workloadSubnetName` and `workloadSubnetPrefix`

#### Azure CLI commands

```bash
az network vnet subnet create \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--address-prefixes $workloadSubnetPrefix \
	--output table
```

#### Verify with Azure CLI

```bash
az network vnet subnet show \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--query "{name:name,prefix:addressPrefix}" \
	--output table
```

### Task 4 - create the network security group and associate it

#### Portal steps
- open `Network security groups`
- create an NSG named `nsgName`
- after creation, associate the NSG to the workload subnet unless your sandbox instructions require NIC-level association

#### Azure CLI commands

```bash
az network nsg create \
	--resource-group $resourceGroupName \
	--name $nsgName \
	--location $location \
	--output table

az network vnet subnet update \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--network-security-group $nsgName \
	--output table
```

#### Verify with Azure CLI

```bash
az network vnet subnet show \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--query "{subnet:name,nsg:networkSecurityGroup.id}" \
	--output jsonc

az network nsg show \
	--resource-group $resourceGroupName \
	--name $nsgName \
	--query "{name:name,defaultRules:defaultSecurityRules[].name}" \
	--output jsonc
```

### Task 5 - create the route table and associate it

#### Portal steps
- open `Route tables`
- create a route table named `routeTableName`
- associate it to the workload subnet

#### Azure CLI commands

```bash
az network route-table create \
	--resource-group $resourceGroupName \
	--name $routeTableName \
	--location $location \
	--output table

az network vnet subnet update \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--route-table $routeTableName \
	--output table
```

#### Verify with Azure CLI

```bash
az network vnet subnet show \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--query "{subnet:name,routeTable:routeTable.id}" \
	--output jsonc

az network route-table show \
	--resource-group $resourceGroupName \
	--name $routeTableName \
	--query "{name:name,routes:routes[].name}" \
	--output jsonc
```

### Task 6 - create the NAT gateway and associate it to the workload subnet

#### Portal steps
- open `NAT gateways`
- create a NAT gateway named `natGatewayName`
- on the outbound IP step, create a Standard public IP named `natPublicIpName`
- associate the NAT gateway to `workloadSubnetName`

#### Azure CLI commands

```bash
az network public-ip create \
	--resource-group $resourceGroupName \
	--name $natPublicIpName \
	--location $location \
	--sku Standard \
	--allocation-method Static \
	--version IPv4 \
	--output table

az network nat gateway create \
	--resource-group $resourceGroupName \
	--name $natGatewayName \
	--location $location \
	--public-ip-addresses $natPublicIpName \
	--idle-timeout 10 \
	--output table

az network vnet subnet update \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--nat-gateway $natGatewayName \
	--output table
```

#### Verify with Azure CLI

```bash
az network nat gateway show \
	--resource-group $resourceGroupName \
	--name $natGatewayName \
	--query "{name:name,publicIpAddresses:publicIpAddresses[].id,idleTimeoutInMinutes:idleTimeoutInMinutes}" \
	--output jsonc

az network vnet subnet show \
	--resource-group $resourceGroupName \
	--vnet-name $vnetName \
	--name $workloadSubnetName \
	--query "{subnet:name,natGateway:natGateway.id}" \
	--output jsonc
```

### Task 7 - create the NIC without a public IP

#### Portal steps
- create a NIC named `nicName`
- place the NIC in `workloadSubnetName`
- do not assign a public IP directly to the NIC

#### Azure CLI commands

```bash
az network nic create \
	--resource-group $resourceGroupName \
	--name $nicName \
	--vnet-name $vnetName \
	--subnet $workloadSubnetName \
	--output table
```

#### Verify with Azure CLI

```bash
az network nic show \
	--resource-group $resourceGroupName \
	--name $nicName \
	--query "{name:name,subnet:ipConfigurations[0].subnet.id,privateIp:ipConfigurations[0].privateIPAddress,publicIp:ipConfigurations[0].publicIPAddress}" \
	--output jsonc
```

### Task 8 - create the VM

#### Portal steps
- open `Virtual machines`
- create a VM named `vmName`
- use Ubuntu Server 22.04 LTS or the matching `vmImage` value
- use the burstable `Standard_B1s` size unless your sandbox requires a different small burstable SKU
- place the VM in `workloadSubnetName`
- confirm the attached NIC is `nicName`
- enable boot diagnostics if the option is available

#### Azure CLI commands

```bash
az vm create \
	--resource-group $resourceGroupName \
	--name $vmName \
	--location $location \
	--nics $nicName \
	--image $vmImage \
	--size $vmSize \
	--admin-username $adminUsername \
	--generate-ssh-keys \
	--output table
```

#### Verify with Azure CLI

```bash
az vm show \
	--resource-group $resourceGroupName \
	--name $vmName \
	--show-details \
	--query "{name:name,powerState:powerState,privateIps:privateIps,publicIps:publicIps}" \
	--output table

az vm get-instance-view \
	--resource-group $resourceGroupName \
	--name $vmName \
	--query "instanceView.statuses[].displayStatus" \
	--output table
```

### Task 9 - create the storage account

#### Portal steps
- open `Storage accounts`
- create a storage account using `storageAccountName`
- keep the deployment in the same resource group and approved region
- use a small lab-appropriate SKU such as `Standard_LRS`

#### Azure CLI commands

```bash
az storage account create \
	--resource-group $resourceGroupName \
	--name $storageAccountName \
	--location $location \
	--sku Standard_LRS \
	--kind StorageV2 \
	--https-only true \
	--min-tls-version TLS1_2 \
	--output table
```

#### Verify with Azure CLI

```bash
az storage account show \
	--resource-group $resourceGroupName \
	--name $storageAccountName \
	--query "{name:name,location:location,sku:sku.name,kind:kind,provisioningState:provisioningState}" \
	--output table
```

### Task 10 - verify the baseline deployment

#### Portal steps
- open the resource group overview
- confirm all expected resources are present
- confirm the VM is running and the NIC is in the expected subnet
- confirm the workload subnet is associated with the NAT gateway
- confirm the VM NIC does not have a public IP assigned directly

#### Azure CLI commands

```bash
az resource list \
	--resource-group $resourceGroupName \
	--query "[].{name:name,type:type,location:location}" \
	--output table
```

### Validation checks
- confirm the VM is running
- confirm the VM NIC is in the intended subnet
- confirm the VM NIC does not have a public IP attached directly
- confirm the NSG association is visible and understandable
- confirm the route table association is visible
- confirm the NAT gateway association is visible on the workload subnet
- confirm the storage account is deployed successfully

### Success criteria
- the environment is built and ready for troubleshooting

<details>
<summary>Show module 1 solution and validation</summary>

### Goal

Create the baseline Azure environment in your assigned resource group using your user prefix.

### Solution checks

1. Confirm your assigned `userPrefix`.
2. Confirm your resource group name follows the pattern `<userPrefix>-azure101lab-rg`.
3. Confirm your VNet name, subnet names, and IP ranges before creating anything.
4. Confirm your storage account name is lowercase and does not contain hyphens.
5. Confirm you are using Ubuntu 22.04 and a burstable SKU such as `Standard_B1s` for the VM.
6. Confirm the VM NIC will not receive a direct public IP and that outbound access will use a NAT gateway.

### Expected outcomes

- the resource group exists
- the VNet and two subnets exist
- the NSG exists and is associated correctly
- the route table exists and is associated correctly
- the NAT gateway exists and is associated to the workload subnet
- the NIC exists without a direct public IP
- the VM is running
- the VM is Ubuntu and deployed on a burstable size such as `Standard_B1s`
- the storage account exists

### Module completion check

You are done with module 1 when:

- the VM NIC is in the intended subnet
- the VM NIC does not have a public IP attached directly
- the NAT gateway association is visible on the workload subnet
- the storage account is deployed successfully

### Microsoft Learn references

- Virtual network overview: https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview
- Create a Linux VM in the portal: https://learn.microsoft.com/azure/virtual-machines/linux/quick-create-portal
- Create a complete Linux virtual machine with Azure CLI: https://learn.microsoft.com/azure/virtual-machines/linux/create-cli-complete
- Quickstart: Create a NAT gateway: https://learn.microsoft.com/azure/nat-gateway/quickstart-create-nat-gateway
- Manage NAT gateway: https://learn.microsoft.com/azure/nat-gateway/manage-nat-gateway
- Network security groups overview: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview
- Manage route tables: https://learn.microsoft.com/azure/virtual-network/manage-route-table
- Storage account overview: https://learn.microsoft.com/azure/storage/common/storage-account-overview

</details>

## Module 2 - VM troubleshooting

### Business symptom
A workload owner reports that the VM is not behaving as expected.

### Objective
Determine whether the issue is caused by VM state, guest configuration, or network access.

### Tasks
- check VM power state and provisioning state
- inspect boot diagnostics, serial console, or Run command if available
- review extension status and recent operations
- determine whether the issue is platform, guest, or connectivity related

### Validation checks
- identify the likely fault domain
- explain the next remediation action

### Hints
- Hint 1: Start with Overview, Activity Log, and Boot diagnostics.
- Hint 2: Compare provisioning state with runtime symptoms.
- Hint 3: This VM does not have a direct public IP, so use serial console, Run command, and network configuration rather than expecting direct internet SSH.

<details>
<summary>Show module 2 solution and validation</summary>

### Goal

Determine whether the VM issue is caused by platform state, guest configuration, or network access.

Because the VM NIC has no direct public IP, do not treat direct internet SSH as the default management path for this lab.

### Solution steps

1. Open the VM overview page.
2. Review `Power state` and `Provisioning state`.
3. Open `Activity log` for the VM.
4. Filter to the last 1 to 2 hours.
5. Look for failed operations, restart events, extension updates, or configuration changes.
6. Open `Boot diagnostics` if available.
7. If needed, use `Run command` or `Serial console` for guest-level investigation.
8. Open the `Extensions + applications` view.
9. Review whether any extension is failed, transitioning, or timed out.
10. Record what evidence you find before making changes.

### Expected outcomes

- you can distinguish runtime state from provisioning state
- you can identify whether the issue likely started after a recent change
- you identify whether the VM is failing before logon, after startup, or only at connectivity time
- you identify whether an extension problem is involved
- you understand that no direct public IP on the VM means portal-native management tools are expected

### Module completion check

You are done with module 2 when:

- you know the VM power state and provisioning state
- you reviewed activity log and diagnostics evidence
- you identified the most likely fault domain

### Microsoft Learn references

- Azure Virtual Machines monitoring data reference: https://learn.microsoft.com/azure/virtual-machines/monitor-vm-reference
- Monitor Azure virtual machines with Azure Monitor: https://learn.microsoft.com/training/modules/monitor-azure-vm-using-diagnostic-data/
- Serial console for Linux virtual machines in Azure: https://learn.microsoft.com/troubleshoot/azure/virtual-machines/linux/serial-console-linux

</details>

## Module 3 - VNet / NSG / routing validation

### Business symptom
Traffic is not reaching the VM as expected.

### Objective
Validate whether the problem is caused by subnet design, NSG rules, or route configuration.

### Tasks
- review subnet associations
- review NSG inbound and outbound rules
- review effective security rules if available
- review the route table and effective routes
- determine what is blocking or redirecting traffic

### Validation checks
- identify the specific network control causing the issue
- describe how to remediate it safely

### Hints
- Hint 1: Confirm which subnet the VM NIC is actually using.
- Hint 2: Check whether the NSG is associated to the NIC, subnet, or both.
- Hint 3: A route table can break traffic even when the NSG looks correct.

<details>
<summary>Show module 3 solution and validation</summary>

### Goal

Determine whether traffic is failing because of subnet placement, NSG rules, or routing.

### Solution steps

1. Open the VM.
2. Go to `Networking` or open the attached NIC.
3. Confirm which subnet the NIC is using.
4. Confirm that subnet is the intended one for the lab.
5. Open the subnet and confirm whether an NSG is associated.
6. Open the NIC and confirm whether an NSG is associated there as well.
7. Open the NSG rules.
8. Review inbound rules for expected management or workload traffic.
9. Review outbound rules if return traffic could be affected.
10. Pay attention to rule priority and whether a deny rule overrides an allow rule.
11. Open `Effective security rules` if available.
12. Review the combined effect of subnet and NIC NSGs.
13. Open the workload subnet and confirm whether a route table is associated.
14. Open the NIC and locate `Effective routes`.
15. Review whether a custom route changes the next hop unexpectedly.
16. Confirm the workload subnet is also associated with the NAT gateway.

### Expected outcomes

- you know the actual subnet in use
- you know where traffic filtering is applied
- you can identify whether a rule priority or scope is the cause of the problem
- you can verify actual enforced rules instead of assuming from raw configuration
- you confirm whether routing contributes to the issue

### Module completion check

You are done with module 3 when:

- you confirmed the correct subnet
- you checked NSG association scope
- you reviewed rule priority
- you reviewed effective routes
- you identified whether NSG or routing is the root cause

### Microsoft Learn references

- Diagnose network traffic filtering problems: https://learn.microsoft.com/azure/virtual-network/diagnose-network-traffic-filter-problem
- Diagnose virtual machine routing problems: https://learn.microsoft.com/troubleshoot/azure/virtual-network/diagnose-network-routing-problem
- Troubleshoot network security issues learning module: https://learn.microsoft.com/training/modules/troubleshoot-network-security-issues/

</details>

## Module 4 - Azure Monitor and KQL triage

### Business symptom
The team needs evidence, not guesses, about what is failing.

### Objective
Use Azure monitoring data and KQL to isolate the likely failure pattern.

### Tasks
- locate the relevant Log Analytics workspace or available logs
- review Activity Log for recent changes
- run basic KQL queries against available tables
- identify timestamps, failure patterns, and likely root cause area

### Sample KQL starter ideas
Use only the tables available in your environment.

```kusto
AzureActivity
| where TimeGenerated > ago(2h)
| order by TimeGenerated desc
```

```kusto
Heartbeat
| where TimeGenerated > ago(2h)
| summarize LastSeen=max(TimeGenerated) by Computer
```

```kusto
AzureDiagnostics
| where TimeGenerated > ago(2h)
| take 50
```

### Validation checks
- identify one useful query and explain what it shows
- correlate log evidence to one of the earlier troubleshooting domains

### Hints
- Hint 1: Start with `AzureActivity` for configuration and control plane changes.
- Hint 2: If the VM was recently deployed, check for provisioning events first.
- Hint 3: Do not assume every table exists in every sandbox.

<details>
<summary>Show module 4 solution and validation</summary>

### Goal

Use logs and KQL to move from suspicion to evidence.

### Solution steps

1. Open `Monitor` or `Activity log`.
2. Filter to your resource group and the last 1 to 2 hours.
3. Look for create, update, delete, restart, failed deployment, or policy-denied operations.
4. Record the relevant timestamps.
5. Open the assigned Log Analytics workspace if one exists.
6. Open the Logs experience.
7. Check whether tables such as `AzureActivity`, `Heartbeat`, or `AzureDiagnostics` are available.
8. Run a recent activity query:

```kusto
AzureActivity
| where TimeGenerated > ago(2h)
| order by TimeGenerated desc
```

9. If `Heartbeat` exists, run:

```kusto
Heartbeat
| where TimeGenerated > ago(2h)
| summarize LastSeen=max(TimeGenerated) by Computer
```

10. If `AzureDiagnostics` exists, run:

```kusto
AzureDiagnostics
| where TimeGenerated > ago(2h)
| take 50
```

11. Narrow the time range or resource scope if the result set is too broad.
12. Correlate the results to the VM, NSG, route, or deployment issue you are investigating.

### Expected outcomes

- you identify whether recent changes correlate with the issue
- you establish a time window for deeper investigation
- you know which data sources are available in your environment
- you produce at least one useful query result
- you connect evidence to a likely fault domain

### Module completion check

You are done with module 4 when:

- you identified a relevant time window
- you used at least one useful query
- you correlated logs to the issue rather than guessing

### Microsoft Learn references

- Azure Activity Log overview: https://learn.microsoft.com/azure/azure-monitor/essentials/activity-log
- Log queries in Azure Monitor: https://learn.microsoft.com/azure/azure-monitor/logs/log-query-overview
- Kusto query language overview: https://learn.microsoft.com/azure/data-explorer/kusto/query/
- Diagnostic settings in Azure Monitor: https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings

</details>

## Module 5 - RBAC troubleshooting

### Business symptom
An action fails even though the resource is visible.

### Objective
Determine whether the issue is caused by missing permissions or wrong scope.

### Tasks
- review Access Control for the resource group and affected resource
- determine which role is currently assigned
- determine whether the scope is too narrow or missing inheritance
- document the minimum role or scope needed for success

### Validation checks
- identify whether the problem is role definition, scope, or assignment absence
- explain the least-privilege fix

### Hints
- Hint 1: Being able to see a resource does not mean you can modify it.
- Hint 2: Compare resource-level, resource-group-level, and subscription-level scope.
- Hint 3: Look for inherited assignments and deny conditions.

<details>
<summary>Show module 5 solution and validation</summary>

### Goal

Determine whether a failed action is caused by missing access, wrong role, or wrong scope.

### Solution steps

1. Record the exact action that failed.
2. Record the resource on which it failed.
3. Record whether the failure happened at the resource, resource group, or subscription level.
4. Capture the error message if one is shown.
5. Open `Access control (IAM)` on the affected resource.
6. Review role assignments.
7. Repeat at the resource group scope.
8. Repeat at the subscription scope if your permissions allow it.
9. Note whether the expected access is direct or inherited.
10. Compare the failed action to the current assigned role.
11. Decide whether the issue is missing assignment, wrong role, or wrong scope.
12. Determine the smallest scope that would allow the needed action.
13. Document the recommended fix rather than granting broad access.

### Expected outcomes

- you have a precise access problem statement
- you know where the user currently has access
- you know whether inheritance is helping or not
- you can explain whether the issue is scope or role related
- you can describe a least-privilege remediation path

### Module completion check

You are done with module 5 when:

- you identified the failed action and resource
- you reviewed role assignments at relevant scopes
- you documented the least-privilege fix

### Microsoft Learn references

- Azure RBAC overview: https://learn.microsoft.com/azure/role-based-access-control/overview
- Understand scope for Azure RBAC: https://learn.microsoft.com/azure/role-based-access-control/scope-overview
- Troubleshoot Azure RBAC: https://learn.microsoft.com/azure/role-based-access-control/troubleshooting

</details>

## Module 6 - Cost and policy validation

### Business symptom
The team wants to know whether the build is compliant and cost-aware.

### Objective
Review the environment for obvious cost waste and policy constraints.

### Tasks
- inspect the resources you created for idle or unnecessary components
- review SKUs and sizing decisions
- check whether policy blocked or constrained any step
- identify required tags, allowed regions, or naming constraints if present

### Validation checks
- identify one cost concern and one governance concern
- explain what change you would make to improve both

### Hints
- Hint 1: Start with what you created but do not need anymore.
- Hint 2: Review deployment errors carefully for policy details.
- Hint 3: Cost awareness in this lab is about good habits, not exact budgeting.

<details>
<summary>Show module 6 solution and validation</summary>

### Goal

Review whether the lab environment is compliant with policy and whether any obvious cost waste exists.

### Solution steps

1. Review the resources in your resource group.
2. Identify any resource that is temporary and not needed after the lab.
3. Review whether the VM size is larger than necessary for a training exercise.
4. Review whether extra public IPs, disks, or other chargeable items were created unintentionally.
5. Confirm the only public IP in the design is the one attached to the NAT gateway, not to the VM NIC.
6. Record what should be deleted after the lab.
7. Review any deployment error or warning messages from earlier tasks.
8. Look for policy-related language about denied resource types, regions, SKUs, tags, or naming.
9. Open `Policy` or the relevant compliance view if available to you.
10. Determine whether the lab was affected by an existing governance control.
11. Record the control and the required compliant behavior.

### Expected outcomes

- you identify at least one resource or design choice that could increase cost unnecessarily
- you understand that cleanup is part of good Azure operations hygiene
- you identify at least one governance constraint, or confirm none affected your deployment
- you can explain how policy changes deployment behavior

### Module completion check

You are done with module 6 when:

- you identified one cost concern
- you identified one policy or governance concern, or confirmed none applied
- you documented what should be cleaned up at the end of the lab

### Microsoft Learn references

- Azure Policy overview: https://learn.microsoft.com/azure/governance/policy/overview
- Troubleshoot Azure Policy not allowed resource type errors: https://learn.microsoft.com/azure/azure-resource-manager/troubleshooting/error-policy-requestdisallowedbypolicy
- Microsoft Cost Management documentation: https://learn.microsoft.com/azure/cost-management-billing/

</details>

## What to record during the lab

For each module, record:
- the symptom
- the tools you used, including whether you used portal, CLI, or both
- the evidence you found
- the likely root cause
- the remediation you would apply

## Microsoft Learn references for the build flow

- Get started with Azure Cloud Shell: https://learn.microsoft.com/azure/cloud-shell/quickstart
- Azure Cloud Shell overview: https://learn.microsoft.com/azure/cloud-shell/overview
- Prepare your environment for the Azure CLI: https://learn.microsoft.com/cli/azure/get-started-tutorial-1-prepare-environment?view=azure-cli-latest
- Quickstart: Create a virtual network: https://learn.microsoft.com/azure/virtual-network/quickstart-create-virtual-network
- Create a complete Linux virtual machine with Azure CLI: https://learn.microsoft.com/azure/virtual-machines/linux/create-cli-complete
- Create a Linux VM in the portal: https://learn.microsoft.com/azure/virtual-machines/linux/quick-create-portal
- Quickstart: Create a NAT gateway: https://learn.microsoft.com/azure/nat-gateway/quickstart-create-nat-gateway
- Manage NAT gateway: https://learn.microsoft.com/azure/nat-gateway/manage-nat-gateway
- Network security groups overview: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview
- Manage route tables: https://learn.microsoft.com/azure/virtual-network/manage-route-table
- Storage account overview: https://learn.microsoft.com/azure/storage/common/storage-account-overview

## Teardown

At the end of the lab:
- delete all resources in your resource group unless your sandbox retention guidance says otherwise
- confirm that no billable resources remain running
- keep your notes for the recap discussion
