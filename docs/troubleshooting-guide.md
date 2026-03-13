# Troubleshooting Guide

## Core troubleshooting pattern

Use the same flow in every module:
1. define the symptom
2. gather evidence
3. isolate the fault domain
4. validate the hypothesis
5. recommend or perform remediation

## Azure tools to know

### Compute
- VM Overview
- Boot diagnostics
- Activity Log
- extension status

### Networking
- VNet and subnet views
- NSG rules
- NIC settings
- effective security rules
- effective routes

### Monitoring
- Azure Monitor
- Log Analytics
- Activity Log
- KQL query editor

### Authorization
- Access Control (IAM)
- role assignments
- scope hierarchy

### Governance
- Policy compliance views
- deployment error details
- resource inventory and cost-related cleanup review

## Good troubleshooting habits

- start broad, then narrow
- use evidence before changing configuration
- confirm the actual scope before changing RBAC
- confirm the actual association before changing networking
- document what changed and why

## Common mistakes

- changing multiple things at once
- assuming the resource is in the expected subnet
- ignoring route tables because the NSG looks suspicious
- assuming a deployment error is a platform issue instead of policy
- assuming visibility means write access
