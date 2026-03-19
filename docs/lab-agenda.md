# Lab Agenda

## Recommended 120-minute agenda

### 0:00-0:10
Orientation
- lab goals and environment overview
- hand out user prefixes and credentials
- confirm portal and Cloud Shell access

### 0:10-0:45
VM Troubleshooting + RBAC Discovery
- identify deallocated VM
- review Activity Log
- attempt to start the VM — get permission denied
- investigate IAM, identify Reader role
- proctor upgrades students to Contributor
- start the VM
- discover and address failed extension

### 0:45-1:05
NSG / Subnet Validation
- identify DenyAllInbound rule at priority 200
- review effective security rules
- fix the deny rule

### 1:05-1:25
Route Table / Routing
- identify blackhole route 0.0.0.0/0 → None
- review effective routes
- remove the blackhole route

### 1:25-1:40
Azure Monitor and KQL Triage
- review Activity Log for evidence of earlier faults
- run KQL queries against shared Log Analytics workspace
- correlate evidence to fault domains

### 1:40-1:55
Cost and Policy Validation
- identify missing tags
- review cost implications of deallocated VMs
- review policy compliance if configured

### 1:55-2:00
Wrap-up
- recap findings
- discuss real-world parallels
- confirm teardown plan

## Condensed 90-minute agenda

### 0:00-0:10
Orientation
- hand out prefixes and credentials
- confirm access

### 0:10-0:40
VM Troubleshooting + RBAC Discovery
- discover deallocated VM, hit permission denied
- identify Reader role, proctor upgrades to Contributor
- start VM, fix failed extension

### 0:40-0:55
NSG and Routing (combined)
- identify and fix DenyAllInbound rule
- identify and fix blackhole route

### 0:55-1:10
Azure Monitor and KQL Triage
- find evidence of earlier faults

### 1:10-1:20
Cost and Policy
- review tags, costs, compliance

### 1:20-1:30
Wrap-up
