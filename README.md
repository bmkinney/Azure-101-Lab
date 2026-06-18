# Azure 101 Lab

This repository holds the Azure 101 / Azure Operations lab assets.

## Scope

The lab is a ~4-hour hands-on Azure Operations lab for customer hosting and cloud engineers. The environment is pre-deployed using Bicep so students focus on troubleshooting, not infrastructure creation.

Primary focus areas:
- VM performance troubleshooting (CPU spike analysis, VM resize)
- Network connectivity debugging (cross-VNet NSG rules, peering)
- Disk capacity management (alerts, resize, Linux filesystem extension)
- Azure Monitor and KQL evidence gathering
- Cost Management and Azure Policy compliance
- RBAC control-plane vs data-plane permissions
- Storage access auditing via diagnostic logs
- Change tracking via Activity Log and Resource Graph

## Delivery model

- The lab environment is deployed by the proctor using Bicep before the session
- Each group of 3 students shares one Azure subscription and one resource group
- A subscription-scoped deployment creates a shared resource group and a single lab resource group
- The lab resource group contains intentional faults for challenge-based troubleshooting
- Students collaborate in breakout rooms on the same set of resources
- Students have Contributor from the start — no mid-lab RBAC upgrade needed
- Modules present a symptom and objective only — no hints, CLI commands, or task lists
- Assume a sandbox subscription already exists for each group

## Architecture

Each group gets:
- 2 VNets peered together (workload + database simulation)
- 2 NSGs with custom deny rules (cross-VNet connectivity blocked until students add allow rules)
- 1 Bastion host for SSH access (no public IPs on VMs)
- 2 Ubuntu 22.04 VMs (VM1 with data disk + CPU spike, VM2 with TCP 1433 listener)
- 1 storage account with blob container and diagnostic logging
- VNet flow logs with Traffic Analytics
- Metric alerts for disk capacity
- Access to a shared Log Analytics workspace

Subscription-level: Azure Policy (tag audit), budget ($50/month), Activity Log forwarding to LAW.

Editable Draw.io source: [assets/azure-101-lab-topology.drawio](assets/azure-101-lab-topology.drawio)

## Quick start (for proctors)

```bash
# 1. Copy and edit the parameters file for each group
cp infra/parameters.example.bicepparam infra/parameters-group1.bicepparam
# Edit: set location, adminPassword, studentPrincipalId, alertEmail

# 2. Deploy to each group subscription
az account set --subscription "Lab-Sub-01"
az deployment sub create \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters infra/parameters-group1.bicepparam

# Repeat for each group
```

See [docs/proctor-guide.md](docs/proctor-guide.md) for full deployment and delivery instructions.

## Modules

| # | Module | Fault | Duration |
|---|---|---|---|
| 1 | VM Performance | CPU spike from cron job on 2-vCPU VM | 30 min |
| 2 | Network Connectivity | No NSG rules for cross-VNet port 1433 | 30 min |
| 3 | Disk Capacity | 4 GB data disk filled >80% | 30 min |
| 4 | Azure Monitor & KQL | Produce evidence for Modules 1-3 | 30 min |
| 5 | Cost & Policy | Missing tags, budget review | 30 min |
| 6 | RBAC Data Plane | Contributor but no Storage Blob Data Contributor | 20 min |
| 7 | Storage Access Audit | Investigate blob access via StorageBlobLogs | 20 min |
| 8 | Change Tracking | Activity Log + Resource Graph audit trail | 20 min |

## Cost management (between lab sessions)

The lab VMs and Bastion generate ~$216/month if left running. Use the management scripts to stop resources between sessions and restart before the next lab.

> **Windows users:** These are Bash scripts (`.sh`). They will not run directly in PowerShell or Command Prompt. Use one of:
> - **Git Bash** (included with Git for Windows): `bash ./scripts/lab-status.sh -g azure101lab-rg`
> - **WSL**: `wsl bash ./scripts/lab-status.sh -g azure101lab-rg`
> - **Azure Cloud Shell** (Bash): scripts run natively

```bash
# Check current state
./scripts/lab-status.sh -g azure101lab-rg

# Stop all cost-generating resources (VMs + Bastion)
./scripts/lab-stop.sh -g azure101lab-rg

# Start resources ~30 min before the next lab
./scripts/lab-start.sh -g azure101lab-rg
```

**What gets stopped:**
- VMs are deallocated (compute charges stop, disks retained)
- Bastion + Public IP are deleted (cannot be stopped, only deleted/recreated)

```bash
# After the lab is complete — permanently delete ALL resources
./scripts/lab-teardown.sh -g azure101lab-rg
```

> ⚠️ **Teardown is irreversible.** It deletes both resource groups, the subscription budget,
> policy assignments, activity log diagnostic settings, and VNet flow logs. The script
> requires you to type the lab name to confirm (use `--yes` to skip in CI/CD).

**Warm-up timing:** Start resources 30 minutes before the lab. VMs boot in ~2 min but Azure Monitor Agent needs 15-20 min to populate Log Analytics with metrics and logs for alerts to fire.

**GitHub Actions (optional):** If your environment includes GitHub Actions, use the `lab-manage.yml` workflow for push-button start/stop via the Actions UI. Requires OIDC federated credentials (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets).

## Project structure

- [infra/main.bicep](infra/main.bicep) — Bicep deployment orchestrator (subscription-scoped)
- [infra/modules/](infra/modules/) — Bicep modules (shared, lab environment, fault injection, policy)
- [infra/parameters.example.bicepparam](infra/parameters.example.bicepparam) — example parameters file
- [docs/proctor-guide.md](docs/proctor-guide.md) — proctor deployment and delivery guide
- [docs/student-guide.md](docs/student-guide.md) — participant-facing challenge guide (8 modules)
- [docs/self-guided-playbook.md](docs/self-guided-playbook.md) — self-guided lab structure and checkpoints
- [docs/scenario-list.md](docs/scenario-list.md) — scenario inventory with faults and evidence sources
- [docs/build-checklist.md](docs/build-checklist.md) — proctor deployment verification checklist
- [docs/lab-agenda.md](docs/lab-agenda.md) — full (~4 hr) and condensed (~2.5 hr) agendas
- [docs/troubleshooting-guide.md](docs/troubleshooting-guide.md) — troubleshooting method and Azure tools
- [docs/resource-map.md](docs/resource-map.md) — resource topology, relationships, and impact map
- [docs/answer-key.md](docs/answer-key.md) — proctor-only solutions for all 8 modules
- [docs/v1-framework.md](docs/v1-framework.md) — original lab framework (historical)
- [docs/v2-roadmap.md](docs/v2-roadmap.md) — deferred automation backlog
- [scripts/lab-start.sh](scripts/lab-start.sh) — start VMs + recreate Bastion before lab
- [scripts/lab-stop.sh](scripts/lab-stop.sh) — deallocate VMs + delete Bastion after lab
- [scripts/lab-status.sh](scripts/lab-status.sh) — check current resource state
- [scripts/lab-teardown.sh](scripts/lab-teardown.sh) — permanently delete all lab resources
- [.github/workflows/lab-manage.yml](.github/workflows/lab-manage.yml) — optional GitHub Actions workflow
- assets/ — diagrams and supporting visuals
