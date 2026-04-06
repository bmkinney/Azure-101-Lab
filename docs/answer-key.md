# Answer Key

> **For proctors only.** Do not share this document with students during the lab.

---

## Module 1 — VM Performance

### What's wrong

A cron job runs on VM1 every hour at minute 0, executing `stress --cpu 2 --timeout 600` which pegs 2 CPU cores at 100% for 10 minutes. Since VM1 is `Standard_D2alds_v7` (2 vCPU), this saturates the entire VM.

### Solution steps

1. Open Azure Monitor → Metrics for VM1. Select `Percentage CPU` with a 1-hour time range and 1-minute granularity. Observe periodic spikes to 100%.
2. Use Bastion to SSH into VM1. Run `top` or `htop` to observe the `stress` process consuming CPU when the spike is active.
3. Inspect the cron job: `cat /etc/cron.d/cpu-spike`
4. The root cause is a legitimate workload process on an undersized VM. Resize VM1 to a larger SKU via the portal or CLI.
5. After resize, the next cron spike will only consume ~50% CPU (2 out of 4 cores), keeping the VM responsive.
6. Verify in Azure Monitor metrics that CPU utilization during the spike period has dropped.

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
   - **NSG1** — Add outbound allow rule: priority 100, destination = VNet2 subnet prefix (`10.11.0.0/16`), destination port = 1433, protocol = TCP (must be lower priority number than 4096)
   - **NSG2** — Add inbound allow rule: priority 100, source = VNet1 subnet prefix (`10.10.0.0/16`), destination port = 1433, protocol = TCP (must be lower priority number than 4096)
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
3. Extend the partition and filesystem inside the OS:
   ```bash
   # Verify the new disk size is visible
   lsblk
   # Extend the partition (if using sfdisk/fdisk)
   sudo growpart /dev/sdc 1
   # Resize the filesystem
   sudo resize2fs /dev/sdc1
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

### Solution steps

1. Open the shared Log Analytics workspace → Logs.
2. **CPU trend (Module 1):**
   ```kusto
   Perf
   | where Computer == "<vm1-name>"
   | where ObjectName == "Processor Information" and CounterName == "% Processor Time"
   | where TimeGenerated > ago(4h)
   | summarize AvgCPU=avg(CounterValue) by bin(TimeGenerated, 5m)
   | render timechart
   ```
   Look for periodic spikes to 100% before resize and ~50% after.

3. **NSG flow logs (Module 2):**
   ```kusto
   AzureNetworkAnalytics_CL
   | where TimeGenerated > ago(4h)
   | where FlowStatus_s == "D"  // Denied
   | where DestPort_d == 1433
   | project TimeGenerated, SrcIP_s, DestIP_s, DestPort_d, FlowStatus_s, NSGRule_s
   | order by TimeGenerated desc
   ```

4. **Disk utilization (Module 3):**
   ```kusto
   Perf
   | where Computer == "<vm1-name>"
   | where ObjectName == "LogicalDisk" and CounterName == "% Used Space"
   | where InstanceName contains "sdc"
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
- Blocked NSG flow log entries found
- Disk utilization trend visible
- Both VMs reporting heartbeats to Log Analytics

---

## Module 5 — Cost & Policy Compliance

### What's wrong

1. **Missing tags:** All resources in the lab resource group are missing the required `Department` and `Environment` tags. Azure Policy is assigned at the subscription scope to audit (not deny) resources missing these tags, so they show as non-compliant.
2. **Budget:** A monthly budget of $50 is deployed at the subscription level with alerts at 80% and 100%.

### Solution steps

#### Tag compliance
1. Open Azure Policy → Compliance. Filter to your subscription.
2. Find the two policy assignments: "Audit resources missing Department tag" and "Audit resources missing Environment tag".
3. Drill into the non-compliant resources.
4. Apply tags to your resources via the portal (resource → Tags blade) or CLI:
   ```bash
   az tag update \
     --resource-id "<resource-id>" \
     --operation merge \
     --tags Department=Lab Environment=Training
   ```
5. Trigger a policy compliance scan or wait for the next automatic evaluation.

#### Cost report
6. Navigate to Cost Management → Cost analysis at the subscription scope.
7. Set the date range to the last 7 days, view type to "Actual cost".
8. Group by Tag (Department) to see costs by tag.

#### Budget review
9. Navigate to Cost Management → Budgets.
10. Review the `azure101lab-monthly-budget` — $50/month with alerts at 80% and 100%.

### Completion check

- Non-compliant resources identified via Azure Policy
- Tags applied to at least the VM and storage account
- Cost analysis report generated with tag grouping
- Budget reviewed and alert thresholds understood

---

## Module 6 — RBAC (Data Plane)

### What's wrong

Students have **Contributor** role on the resource group. Contributor grants control-plane permissions (manage resources, configure settings) but does NOT grant data-plane permissions for storage blob operations. Uploading, downloading, or listing blobs requires a data-plane role such as `Storage Blob Data Contributor`.

### Solution steps

1. Navigate to the storage account → Containers → `lab-data`. Try to upload a file. Observe the 403 error.
2. Open the storage account → Access Control (IAM).
3. Click "View my access" — see that you have `Contributor` inherited from the resource group.
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

3. **Resource Graph:** In the portal, open Azure Resource Graph Explorer and run:
   ```kusto
   resourcechanges
   | where properties.changeAttributes.timestamp > ago(4h)
   | where resourceGroup contains "azure101lab"
   | project properties.changeAttributes.timestamp,
             properties.changeType,
             targetResourceType,
             targetResourceId,
             properties.changes
   | order by properties_changeAttributes_timestamp desc
   ```

4. Document each change: what was changed, who made it (Caller), and the timestamp.

### Completion check

- At least 3 change events identified across Modules 1, 2, 3, or 6
- Changes attributed to a specific user (Caller field)
- Timestamps documented
- Student can explain when to use Activity Log vs Resource Graph for change tracking
