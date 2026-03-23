# Scenario List

## Scenario design goals

All scenarios are pre-deployed in the lab environment via Bicep. Students do not build infrastructure — they troubleshoot it.

Each scenario reinforces operational thinking:
- identify the symptom
- gather evidence
- isolate the fault domain
- recommend or perform remediation

## Scenario 1 — VM Troubleshooting + RBAC Discovery

### Focus area
VM state, extension troubleshooting, and RBAC discovery

### Pre-deployed faults
- VM is in a **deallocated** state
- Students have **Reader** role on their resource group (insufficient to start the VM)
- Custom Script Extension has **failed** (attempts to run a non-existent script)

### Participant outcome
The participant identifies the VM is deallocated, attempts to start it, discovers the Reader role prevents write operations, gets upgraded to Contributor by the proctor, starts the VM, and addresses the failed extension.

### Evidence sources
- VM Overview (power state, provisioning state)
- Activity Log (deallocate operation)
- Permission denied error when attempting to start the VM
- Access Control (IAM) on the student's resource group (role assignments)
- Extensions + applications blade (failed extension status)
- Boot diagnostics

## Scenario 2 — NSG / Subnet Validation

### Focus area
Network security group rule analysis

### Pre-deployed fault
- NSG contains a **DenyAllInbound** rule at **priority 200** that blocks all inbound traffic

### Participant outcome
The participant identifies the deny rule, understands priority evaluation, and removes or overrides the rule.

### Evidence sources
- NSG inbound rules
- Effective security rules on the NIC
- Subnet association confirmation

## Scenario 3 — Route Table / Routing

### Focus area
Routing validation

### Pre-deployed fault
- Route table contains a **blackhole route** (`0.0.0.0/0 → None`) that drops all outbound traffic

### Participant outcome
The participant identifies the blackhole route using effective routes and removes it.

### Evidence sources
- Effective routes on the NIC
- Route table configuration
- Subnet association

## Scenario 4 — Azure Monitor and KQL Triage

### Focus area
Operational evidence and log analysis

### Pre-deployed fault
- None — this scenario uses monitoring to find evidence of faults from Scenarios 1-3

### Participant outcome
The participant uses Activity Log and KQL to surface VM stop events, extension failures, and configuration changes.

### Evidence sources
- AzureActivity table (control plane operations)
- Heartbeat table (VM availability gaps)
- AzureDiagnostics (if available)
- Shared Log Analytics workspace

## Scenario 5 — Cost and Policy Validation

### Focus area
Governance and operational hygiene

### Pre-deployed fault
- Resources are missing required tags (`Department`, `Environment`)
- Deallocated VMs still incur disk costs

### Participant outcome
The participant identifies missing `Department` and `Environment` tags, reviews subscription-level and resource group-level cost information using Cost Management, recognizes persistent costs even with deallocated VMs, checks budgets, and reviews policy compliance.

### Evidence sources
- Resource Tags blade (`Department` and `Environment` tags missing)
- Policy compliance views (if policy is configured)
- Subscription overview (cost summary and resource counts)
- Cost Management → Cost analysis (resource group scope, grouped by resource type)
- Cost Management → Budgets (spending thresholds and alerts)
- Resource inventory review
- SKU and sizing review

## Recommended scenario sequence

1. VM Troubleshooting + RBAC Discovery (discover deallocated VM, hit permission denied, identify Reader role, get upgraded to Contributor, start VM, fix extension)
2. NSG / Subnet Validation (fix the deny rule)
3. Route Table / Routing (fix the blackhole route)
4. Azure Monitor and KQL (gather evidence of all previous faults)
5. Cost and Policy Validation (identify missing tags, cost concerns)

This sequence is intentional: RBAC surfaces naturally in Scenario 1 when students try to start the VM. Once upgraded to Contributor, students can fix infrastructure and then use monitoring to find evidence.
