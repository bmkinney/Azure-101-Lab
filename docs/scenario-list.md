# Scenario List

## Scenario design goals

The scenarios should reinforce operational thinking:
- identify the symptom
- gather evidence
- isolate the fault domain
- recommend or perform remediation

## Scenario 1 - Build the baseline environment

### Focus area
Core Azure resource creation

### Participant outcome
The participant successfully creates:
- VNet
- subnets
- NSG
- route table
- NAT gateway
- a small Ubuntu VM on a burstable SKU
- storage account

### Why it matters
Participants need to understand the resource relationships before they can troubleshoot them.

## Scenario 2 - VM access or health issue

### Focus area
VM troubleshooting

### Example symptoms
- VM is running but guest-level troubleshooting is still required through portal-native management tools
- VM deployment succeeded but the workload is not usable
- provisioning or extension status suggests an issue

### Evidence sources
- VM Overview
- Activity Log
- Boot diagnostics
- extension status

## Scenario 3 - NSG or subnet association issue

### Focus area
Network security validation

### Example symptoms
- expected traffic is blocked
- rule priority creates an unexpected outcome
- NSG is associated to the wrong scope
- outbound design does not follow the expected NAT gateway pattern

### Evidence sources
- NSG rules
- subnet settings
- NIC settings
- effective security rules
- NAT gateway association on the workload subnet

## Scenario 4 - Route table issue

### Focus area
Routing validation

### Example symptoms
- traffic path does not behave as expected
- effective routes show an unexpected destination or next hop
- connectivity breaks after route changes

### Evidence sources
- route table configuration
- subnet association
- effective routes

## Scenario 5 - Azure Monitor and KQL triage

### Focus area
Operational evidence and log analysis

### Example symptoms
- recent changes impacted the environment
- telemetry shows a timing pattern
- the team needs proof of what changed and when

### Evidence sources
- AzureActivity
- Heartbeat
- AzureDiagnostics
- resource-specific logs if enabled

## Scenario 6 - RBAC scope issue

### Focus area
Authorization troubleshooting

### Example symptoms
- participant can view but not modify a resource
- an action fails at resource scope but works elsewhere
- expected access was assigned at the wrong scope

### Evidence sources
- Access Control (IAM)
- scope hierarchy
- role assignments

## Scenario 7 - Cost and policy review

### Focus area
Governance and operational hygiene

### Example symptoms
- unnecessary resources remain deployed
- policy blocks a configuration choice
- naming, tags, or region selection are constrained

### Evidence sources
- deployment errors
- policy compliance views
- resource inventory
- SKU and sizing review

## Recommended v1 scenario sequence

1. Build baseline environment
2. VM troubleshooting
3. NSG validation
4. Route validation
5. Monitor and KQL triage
6. RBAC troubleshooting
7. Cost and policy review

## Notes for v2

Potential future enhancements:
- prebuilt fault injection
- Terraform deployment of the lab environment
- reset automation
- scenario toggles by participant or cohort
