# Answer Key

> **For proctors only.** Do not share this document with students during the lab.

---

## Module 1 — VM Performance

### What's wrong

A cron job runs on VM1 every 15 minutes (at :00, :15, :30, :45), executing `stress --cpu 2 --timeout 300` which pegs 2 CPU cores at 100% for 5 minutes. Since VM1 is `Standard_D2alds_v7` (2 vCPU), this saturates the entire VM.

### Solution steps

1. Open Azure Monitor → Metrics for VM1. Select `Percentage CPU` with a 1-hour time range and 1-minute granularity. Observe periodic spikes to 100%.
2. Use Bastion to SSH into VM1. Run `top` to observe the `stress` process consuming CPU when the spike is active. Use `top | grep stress` to filter for the stress process specifically.
3. Inspect the cron job: `cat /etc/cron.d/cpu-spike`
4. The root cause is a legitimate workload process on an undersized VM. First, identify the current VM SKU.

   **To identify the VM SKU (portal):**
   - Navigate to VM1 → Size under Availability + scale
   - Note the current SKU (e.g., `Standard_D2alds_v7` with 2 vCPU)

   **To identify the VM SKU (CLI):**
   ```bash
   az vm show --resource-group azure101lab-rg --name azure101lab-vm1 --query hardwareProfile.vmSize -o tsv
   ```

5. Resize VM1 to a larger SKU (4+ vCPU) via the portal or CLI:

   **To resize (portal):**
   - Stop the VM (navigate to VM1 → Stop if required)
   - Navigate to VM1 → Size under Availability + scale
   - Select a larger SKU (e.g., `Standard_D4alds_v7` with 4 vCPU)
   - Click Resize
   - Start the VM

   **To resize (CLI):**
   ```bash
   # Check available resize options
   az vm list-vm-resize-options --name azure101lab-vm1 --resource-group azure101lab-rg --output table

   # Resize the VM
   az vm resize --name azure101lab-vm1 --resource-group azure101lab-rg --size Standard_D4alds_v7
   ```

6. After resize, the next cron spike will only consume ~50% CPU (2 out of 4 cores), keeping the VM responsive. Verify in Azure Monitor metrics that CPU utilization during the spike period has dropped.

### Completion check

- Azure Monitor metrics show the periodic CPU spike pattern
- VM1 has been resized to 4+ vCPU
- Post-resize metrics confirm CPU utilization during spikes is ≤50%

---

## Module 2 — Network Connectivity (NSG)

### What's wrong

VNet1 and VNet2 are peered, so routing works. However, each VNet's subnet has its own NSG with a **custom deny rule blocking cross-VNet traffic**. NSG1 has a `DenyCrossVNetOutbound` rule (priority 4096) blocking all outbound to VNet2's address space, and NSG2 has a `DenyCrossVNetInbound` rule (priority 4096) blocking all inbound from VNet1's address space. Without the deny rules, Azure's default `AllowVnetInBound` rule would allow peered VNet traffic — so the deny rules are what create the block.

Students need to add explicit allow rules at a higher priority (lower number) than 4096 on both NSGs to permit SQL traffic on port 1433.

### Solution steps

1. From VM1 via Bastion, test connectivity: `nc -zv <VM2-IP> 1433 -w 5` — observe timeout/failure.
2. Open NSG1 (on VNet1's workload subnet). Review inbound and outbound rules.
3. Open NSG2 (on VNet2's workload subnet). Review inbound rules.
4. Add rules to allow SQL traffic:
   - **NSG1 (outbound)** — Add outbound allow rule: 
     - Rule name: `AllowOutboundVM2Vnet2Subnet`
     - Description: `Allow Outbound VM2 Vnet2 Subnet for port 1433`
     - Priority: 100
     - Destination: VNet2 subnet prefix (`10.11.0.0/16`)
     - Destination port: 1433
     - Protocol: TCP (must be lower priority number than 4096)
   - **NSG2 (inbound)** — Add inbound allow rule:
     - Rule name: `AllowInboundVM1Vnet1Subnet`
     - Description: `Allow inbound VM1 Vnet1 Subnet for port 1433`
     - Priority: 100
     - Source: VNet1 subnet prefix (`10.10.0.0/16`)
     - Destination port: 1433
     - Protocol: TCP (must be lower priority number than 4096)
5. Test again from VM1: `nc -zv <VM2-IP> 1433 -w 5` — should succeed.
6. Use Network Watcher → NSG diagnostics or effective security rules to verify.

### Completion check

- `nc -zv <VM2-IP> 1433` succeeds from VM1
- NSG rules on both sides explicitly allow port 1433
- Student can explain why rules were needed on both NSGs

---

## Module 3 — Disk Capacity

### What's wrong

VM1 has a 4 GB data disk mounted at `/mnt/data`. A large file (`app-logs.dat`, ~3.4 GB) fills it to over 80%. An Azure Monitor metric alert fires on this condition.

### Solution steps

1. Confirm the issue: SSH to VM1 via Bastion, run `df -h /mnt/data` — see >80% used.
2. Resize the disk in Azure:
   - Stop (deallocate) VM1 if required by the disk SKU, or use online resize if supported.
   - In the portal, navigate to VM1 → Disks → select the data disk → Size + performance → increase to 16 GB or larger.
   - Start VM1 if it was deallocated.
3. Extend the filesystem inside the OS. The lab places ext4 directly on the whole data disk (no partition table), so only `resize2fs` is needed. The stable device path is `/dev/disk/azure/data/by-lun/0`:
   ```bash
   # Verify the new disk size is visible
   lsblk
   # Resolve the data disk device (NVMe on D*v7 SKUs)
   DISK=$(readlink -f /dev/disk/azure/data/by-lun/0)
   echo "$DISK"
   # Resize the filesystem to fill the now-larger disk
   sudo resize2fs "$DISK"
   # Verify
   df -h /mnt/data
   ```
4. Confirm disk utilization is now well below 80%.
5. Check Azure Monitor → Alerts to see the alert has resolved (may take a few minutes).

### Completion check

- Data disk has been resized to a larger capacity in Azure
- The partition and filesystem inside the OS have been extended
- `df -h /mnt/data` shows utilization well below 80%

---

## Module 4 — Azure Monitor & KQL Evidence

### Preflight — verify diagnostic settings and ingestion before running guest-side queries

**Important:** VNet and NSG logs will not appear in Log Analytics unless diagnostic settings are configured to route them to the workspace. If students report missing `NTANetAnalytics` or `AzureDiagnostics` tables:

1. Check that diagnostic settings are enabled for the NSGs and VNets:
   - Navigate to each NSG → Diagnostic settings
   - Verify that flow logs or diagnostic logs are enabled and sending to the shared Log Analytics workspace
   - Check that VNet flow logs are enabled and routed to Log Analytics
2. Ask the proctor to verify diagnostic settings are configured, or enable them yourself if you have permissions.

Guest-side metrics (`Perf`, `Syslog`) only exist once the Azure Monitor Agent (AMA) successfully sends data. If students report `Perf` "does not exist", the table is simply empty for this workspace — not missing. Run these diagnostics first:

```kusto
// 1. Is AMA ingesting at all?
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastSeen=max(TimeGenerated) by Computer, Category
```

Both `azure101lab-vm1` and `azure101lab-vm2` should appear with `LastSeen` within the last 5–10 min. If a VM is missing:

- VM may be deallocated — `az vm list -d -o table`
- AMA extension may be absent — `az vm extension list -g azure101lab-rg --vm-name <vm> -o table` (look for `AzureMonitorLinuxAgent`)
- DCR association may be missing — check the DCR resource → Resources tab

```kusto
// 2. Is the Perf table receiving rows for the lab VMs?
Perf
| where TimeGenerated > ago(1h)
| where Computer startswith "azure101lab"
| summarize rows=count() by Computer
```

If this returns zero rows but Heartbeat has rows, the DCR is not routing performance counters — check the DCR `dataSources.performanceCounters` section.

### Fallback when guest metrics are unavailable

Platform metrics (from the hypervisor) are **always** available via the portal Metrics blade or Azure CLI, independent of AMA:

```powershell
$vmId = az vm show -g azure101lab-rg -n azure101lab-vm1 --query id -o tsv
az monitor metrics list `
  --resource $vmId `
  --metric "Percentage CPU" `
  --interval PT5M `
  --start-time 2026-04-20T00:00:00Z `
  --output table
```

Note: `AzureMetrics` is **not** a valid KQL fallback in this workspace — the lab does not deploy a VM-metrics diagnostic setting that routes platform metrics to Log Analytics.

### Simple Mode Alternative for Proctors Assisting Students Without KQL Experience

If students are unfamiliar with KQL, Log Analytics offers a **simple mode** visual query builder that provides an alternative to hand-written queries. Simple mode is UI-based (dropdown menus, filters, aggregations) rather than text-based. It can produce the same results as KQL for the required evidence objectives.

**Important:** Guide students through simple mode exploration rather than providing completed queries. The goal is to help students produce evidence—either via KQL or simple mode—without sacrificing their learning.

#### Objective 1: CPU Trend (Module 1) — Simple Mode Steps

1. In Log Analytics → **Logs**, click **+** → select **New query** (or leave the default blank query editor)
2. In the editor, click the **Editor type** dropdown (top right) and select **Simple mode**
3. In the **Table** dropdown, select **Perf**
4. Click **Add filter** and select:
   - Field: `Computer`
   - Operator: `equals`
   - Value: `azure101lab-vm1` (or the actual VM name)
5. Click **Add filter** again:
   - Field: `ObjectName`
   - Operator: `equals`
   - Value: `Processor`
6. Click **Add filter** again:
   - Field: `CounterName`
   - Operator: `equals`
   - Value: `% Processor Time`
7. Click **Add filter** again:
   - Field: `InstanceName`
   - Operator: `equals`
   - Value: `_Total`
8. Click **Add filter** again:
   - Field: `TimeGenerated`
   - Operator: `is in the last`
   - Value: `4 hours`
9. Under **Aggregations**, click **Add aggregation**:
   - Aggregate: `CounterValue` (select `Average`)
   - Group by: `TimeGenerated` (set to `5 minutes`)
10. Click **Run** to execute the query
11. Select the **Chart** tab to visualize the CPU trend over time

#### Objective 2: VNet Flow Log Analysis (Module 2) — Simple Mode Steps

1. In Log Analytics → **Logs**, click **+** → select **New query**
2. Click the **Editor type** dropdown and select **Simple mode**
3. In the **Table** dropdown, select **NTANetAnalytics**
   - Note: If `NTANetAnalytics` is not available, check diagnostic settings are configured for VNet flow logs (see "Preflight" section above)
4. Click **Add filter**:
   - Field: `TimeGenerated`
   - Operator: `is in the last`
   - Value: `4 hours`
5. Click **Add filter**:
   - Field: `DestPort`
   - Operator: `equals`
   - Value: `1433`
6. Click **Add filter**:
   - Field: `FlowStatus`
   - Operator: `equals`
   - Value: `D` (for Denied traffic)
7. Under **Columns**, select the fields to display (e.g., `TimeGenerated`, `SrcIp`, `DestIp`, `DestPort`, `FlowStatus`, `AclRule`)
   - Note: `AclRule` may not exist in all workspace versions; if not visible, skip it
8. Click **Run** to execute the query
9. Review the results to find denied attempts from VM1's VNet to VM2 on port 1433 before the NSG fix

#### Objective 3: Disk Utilization (Module 3) — Simple Mode Steps

1. In Log Analytics → **Logs**, click **+** → select **New query**
2. Click the **Editor type** dropdown and select **Simple mode**
3. In the **Table** dropdown, select **Perf**
4. Click **Add filter**:
   - Field: `Computer`
   - Operator: `equals`
   - Value: `azure101lab-vm1`
5. Click **Add filter**:
   - Field: `ObjectName`
   - Operator: `equals`
   - Value: `Logical Disk`
6. Click **Add filter**:
   - Field: `CounterName`
   - Operator: `equals`
   - Value: `% Used Space`
7. Click **Add filter**:
   - Field: `InstanceName`
   - Operator: `equals`
   - Value: `/mnt/data`
8. Click **Add filter**:
   - Field: `TimeGenerated`
   - Operator: `is in the last`
   - Value: `4 hours`
9. Under **Aggregations**, click **Add aggregation**:
   - Aggregate: `CounterValue` (select `Average`)
   - Group by: `TimeGenerated` (set to `5 minutes`)
10. Click **Run** to execute the query
11. Select the **Chart** tab to visualize disk utilization before and after the resize

#### Objective 4: DCR Validation — Simple Mode Steps

1. In Log Analytics → **Logs**, click **+** → select **New query**
2. Click the **Editor type** dropdown and select **Simple mode**
3. In the **Table** dropdown, select **Heartbeat**
4. Click **Add filter**:
   - Field: `TimeGenerated`
   - Operator: `is in the last`
   - Value: `1 hour`
5. Under **Aggregations**, click **Add aggregation**:
   - Aggregate: Select `max` on `TimeGenerated`
   - Group by: `Computer`
6. Click **Run** to execute the query
7. Verify both `azure101lab-vm1` and `azure101lab-vm2` appear with recent heartbeat timestamps

**Reference:** [Getting started with Kusto Query Language - Simple mode](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-tutorial#use-simple-mode)

### Solution steps

1. Open the shared Log Analytics workspace → Logs.
2. **CPU trend (Module 1):**
   ```kusto
   Perf
   | where Computer == "<vm1-name>"
   | where ObjectName == "Processor" and CounterName == "% Processor Time"
   | where InstanceName == "_Total"
   | where TimeGenerated > ago(4h)
   | summarize AvgCPU=avg(CounterValue) by bin(TimeGenerated, 5m)
   | render timechart
   ```
   Look for periodic spikes to 100% before resize and ~50% after.

3. **VNet flow logs (Module 2):** Traffic Analytics uses `NTANetAnalytics` (the older `AzureNetworkAnalytics_CL` table is only present on legacy workspaces). Note: Traffic Analytics has a ~10-min processing interval, so the first rows can take 30–60 min to appear after deployment.
   ```kusto
   NTANetAnalytics
   | where TimeGenerated > ago(4h)
   | where DestPort == 1433
   | where FlowStatus == "D"   // Denied
   | project TimeGenerated, SrcIp, DestIp, DestPort, FlowStatus, AclRule, SubType
   | order by TimeGenerated desc
   ```
   If `AclRule` is not a column in your workspace schema (column names have shifted across TA versions), drop it from `project` or run `NTANetAnalytics | getschema` to list current columns.
   If the table doesn't exist yet, confirm ingestion with:
   ```kusto
   union withsource=T *
   | where TimeGenerated > ago(4h)
   | where T startswith "NTA" or T == "AzureNetworkAnalytics_CL"
   | summarize count() by T
   ```

4. **Disk utilization (Module 3):**
   ```kusto
   Perf
   | where Computer == "<vm1-name>"
   | where ObjectName == "Logical Disk" and CounterName == "% Used Space"
   | where InstanceName == "/mnt/data"
   | where TimeGenerated > ago(4h)
   | summarize AvgUsed=avg(CounterValue) by bin(TimeGenerated, 5m)
   | render timechart
   ```

5. **DCR validation:** Navigate to the DCR resource in the shared RG. Review data sources and confirm performance counters, syslog, and destinations are configured. In Log Analytics:
   ```kusto
   Heartbeat
   | where TimeGenerated > ago(1h)
   | summarize LastSeen=max(TimeGenerated) by Computer
   ```
   Both VMs should appear with recent heartbeats.

### Completion check

- At least 3 KQL queries executed with meaningful results
- CPU spike pattern visible in a time chart
- Blocked VNet flow log entries found
- Disk utilization trend visible
- Both VMs reporting heartbeats to Log Analytics

---

## Module 5 — Cost & Policy Compliance

### What's wrong

1. **Missing tags:** All resources in the lab resource group are missing the required `Department` and `Environment` tags. Azure Policy is assigned at the subscription scope with the **Modify** effect ("Add or replace a tag on resources"), so non-compliant resources surface in the Compliance blade and can be fixed with a remediation task.
2. **Budget:** A monthly budget of $50 is deployed at the subscription level with alerts at 80% and 100%.

### Solution steps

#### Tag compliance
1. Open Azure Policy → Compliance. Filter to your subscription.
2. Find the two policy assignments: "Add or replace the Department tag" and "Add or replace the Environment tag" (Modify effect).
3. Drill into the non-compliant resources.
4. Trigger a manual policy compliance scan to evaluate current compliance:
   ```bash
   az policy state trigger-scan
   ```
5. Create a **remediation task** for each policy so the policy's managed identity stamps the missing tag onto existing resources. Portal: Policy → Remediation → Create remediation task → pick the assignment. Or CLI:
   ```bash
   az policy remediation create \
     --name "remediate-department-tag" \
     --policy-assignment "modify-department-tag"

   az policy remediation create \
     --name "remediate-environment-tag" \
     --policy-assignment "modify-environment-tag"
   ```
   The Modify policy's system-assigned identity (granted Contributor at subscription scope) applies the tag — no manual per-resource tagging required.
6. Re-check Compliance after remediation completes; resources should move to compliant.

#### Cost report
6. Navigate to the subscription → Reporting + Analytics → Cost Management → Cost analysis at the subscription scope.
7. Set the date range to the last 7 days, view type to "Actual cost".
8. Group by Tag (Department) to see costs by tag.

#### Budget review
9. Navigate to Cost Management → Budgets.
10. Review the `azure101lab-monthly-budget` — $50/month with alerts at 80% and 100%.
    - Note: For alerts to be received, an **action group** must be configured on the budget to route notifications (email, SMS, webhook, etc.)
    - If no action group is configured, the budget will fire but notifications will not be delivered

### Completion check

- Non-compliant resources identified via Azure Policy
- Remediation task created for each tag policy; resources become compliant
- Cost analysis report generated with tag grouping
- Budget reviewed and alert thresholds understood

---

## Module 6 — RBAC (Data Plane)

### What's wrong

Students have the custom **Azure 101 Lab Student** role at the subscription scope. It grants control-plane permissions (manage resources, configure settings) but does NOT grant data-plane permissions for storage blob operations. Uploading, downloading, or listing blobs requires a data-plane role such as `Storage Blob Data Contributor`.

The usual control-plane "escape hatch" is also closed: the custom role removes `Microsoft.Storage/storageAccounts/listkeys/action` and `regeneratekey/action`, and the storage account has `allowSharedKeyAccess: false`. Students cannot retrieve an account key to authenticate with shared-key auth, so the only path to blob data is an Entra ID data-plane role assignment.

### What students can do

The custom role by itself cannot write role assignments. To let students self-remediate without granting Owner, the lab also grants the student principal **Role Based Access Control Administrator** scoped only to the lab storage account, with an ABAC condition that restricts the roles they may grant to `Storage Blob Data Reader` and `Storage Blob Data Contributor`. Any attempt to assign Owner, User Access Administrator, or a role on a different resource will be denied by the condition — this is itself a teachable moment about ABAC and scoped RBAC Admin.

### Solution steps

1. Navigate to the storage account → Containers → `lab-data`. Try to upload a file. Observe the 403 error.
2. Open the storage account → Access Control (IAM).
3. Click "View my access" — see that you have the custom Lab Student role inherited from the subscription, but no Storage Blob Data role.
4. Click Add → Add role assignment.
5. Search for `Storage Blob Data Contributor` and select it.
6. Assign it to yourself (Members → select your user account).
7. Wait 1-2 minutes for RBAC propagation.
8. Retry the blob upload — it should succeed.

Alternatively via CLI:
```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>"
```

### Completion check

- Student can explain the difference between control-plane and data-plane RBAC
- `Storage Blob Data Contributor` assigned on the storage account
- File successfully uploaded to the `lab-data` container

---

## Module 7 — Storage Access Audit

### What to find

Storage diagnostic settings are configured to send `StorageRead`, `StorageWrite`, and `StorageDelete` events to Log Analytics. The fault injection script and any student blob operations will appear in the logs.

### Solution steps

1. Open the shared Log Analytics workspace → Logs.
2. Query storage access events:
   ```kusto
   StorageBlobLogs
   | where TimeGenerated > ago(24h)
   | where AccountName == "<storage-account-name>"
   | project TimeGenerated, OperationName, CallerIpAddress, AuthenticationType,
             RequesterObjectId, StatusCode, Uri
   | order by TimeGenerated desc
   ```
3. Identify unique callers:
   ```kusto
   StorageBlobLogs
   | where TimeGenerated > ago(24h)
   | where AccountName == "<storage-account-name>"
   | summarize OperationCount=count(), LastAccess=max(TimeGenerated)
       by RequesterObjectId, CallerIpAddress, AuthenticationType
   ```
4. Document the findings: who accessed what, when, and from where.
5. Cross-reference `RequesterObjectId` values with Azure AD to identify the principals.

### Completion check

- At least one KQL query against `StorageBlobLogs` executed successfully
- Callers identified by principal ID and/or IP address
- Student can explain how diagnostic settings enable storage audit logging

---

## Module 8 — Change Tracking

### Solution steps

1. **Activity Log (portal):** Navigate to your resource group → Activity Log. Filter to today. Find:
   - `Resize Virtual Machine` or `Write Virtual Machine` — the Module 1 VM resize
   - `Write Network Security Group` or `Create or Update Security Rule` — Module 2 NSG changes
   - `Update Disk` or `Write Disk` — Module 3 disk resize
   - `Create Role Assignment` — Module 6 RBAC assignment

2. **Activity Log (KQL):** In the Log Analytics workspace:
   ```kusto
   AzureActivity
   | where TimeGenerated > ago(4h)
   | where ResourceGroup contains "azure101lab"
   | where ActivityStatusValue == "Success"
   | project TimeGenerated, OperationNameValue, Caller, ResourceId
   | order by TimeGenerated desc
   ```

3. **Resource Graph:** In the portal, open Azure Resource Graph Explorer (not Log Analytics — different query surface) and run:
   ```kusto
   resourcechanges
   | extend ChangedAt    = todatetime(properties.changeAttributes.timestamp),
            ChangeType   = tostring(properties.changeType),
            ChangedBy    = tostring(properties.changeAttributes.changedBy),
            TargetId     = tostring(properties.targetResourceId),
            TargetType   = tostring(properties.targetResourceType),
            Changes      = properties.changes
   | where ChangedAt > ago(24h)
   | where TargetId contains "azure101lab"
   | project ChangedAt, ChangeType, ChangedBy, TargetType, TargetId, Changes
   | order by ChangedAt desc
   ```
   
   Note: If you receive an error like "The name 'resourcechanges' does not refer to any known table", verify you are in the **Azure Resource Graph Explorer** (not Log Analytics Logs). The query syntax differs between the two tools.
   `ChangedBy` is the caller's UPN (users) or objectId (service principals/managed identities). `Changes` shows the before/after for each changed property — expand it to see, e.g., `hardwareProfile.vmSize` go from `Standard_D2alds_v7` to `Standard_D4alds_v7`.

4. Document each change: what was changed, who made it (Caller), and the timestamp.

### Completion check

- At least 3 change events identified across Modules 1, 2, 3, or 6
- Changes attributed to a specific user (Caller field)
- Timestamps documented
- Student can explain when to use Activity Log vs Resource Graph for change tracking
