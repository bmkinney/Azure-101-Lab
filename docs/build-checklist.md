# Deployment Verification Checklist

Use this checklist after running the Bicep deployment to confirm the lab environment is ready.

## Pre-deployment

- [ ] subscription is available and accessible
- [ ] you have Owner or Contributor + User Access Administrator on the subscription
- [ ] parameters file is updated with student prefixes, location, and admin password
- [ ] student principal ID is set (if using the RBAC scenario)

## Resource groups

- [ ] Shared resource group (`azure101lab-shared-rg`) is created
- [ ] Per-student resource groups (`azure101lab-<prefix>-rg`) are created

## Shared resources (in `azure101lab-shared-rg`)

- [ ] Log Analytics workspace (`azure101lab-law`) is deployed
- [ ] Data Collection Rule (`azure101lab-dcr`) is deployed
- [ ] Managed identity (`azure101lab-script-identity`) is deployed
- [ ] Managed identity has Contributor role on each student resource group

## Per-user resources (repeat for each user prefix, in `azure101lab-<prefix>-rg`)

- [ ] VNet created with correct address space
- [ ] Management and workload subnets created
- [ ] NSG created and associated to workload subnet
- [ ] NSG contains `DenyAllInbound` rule at priority 200 (intentional fault)
- [ ] Route table created and associated to workload subnet
- [ ] Route table contains `blackhole-default` route with next hop `None` (intentional fault)
- [ ] NIC created in workload subnet with no public IP
- [ ] VM created with Ubuntu 22.04 and Standard_B1s
- [ ] VM is in **deallocated** state (intentional fault)
- [ ] `FailedCustomScript` extension is present and in failed state (intentional fault)
- [ ] Azure Monitor Agent extension is installed
- [ ] Data Collection Rule association exists for the VM
- [ ] Storage account created for boot diagnostics
- [ ] Boot diagnostics enabled on the VM

## RBAC (if configured)

- [ ] Student principal has Reader role on each student resource group
- [ ] Proctor is ready to upgrade students to Contributor mid-lab

## Policy (if configured)

- [ ] Tag audit policies assigned at each student resource group scope
- [ ] Policy compliance scan has completed (allow up to 30 minutes)

## Final checks

- [ ] All VMs show as deallocated (`az vm list --resource-group azure101lab-<prefix>-rg --show-details --query "[].{name:name,powerState:powerState}" -o table`)
- [ ] Resource count matches expected number per student resource group
- [ ] Student prefixes and credentials are documented and ready to hand out
