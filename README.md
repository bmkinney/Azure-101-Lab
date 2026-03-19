# Azure 101 Lab

This repository holds the customer-facing Azure 101 / Azure Operations lab assets for the Xylem project.

## Scope

The lab is a 90-120 minute hands-on Azure Operations lab for customer hosting and cloud engineers. The environment is pre-deployed using Bicep so students focus on troubleshooting, not infrastructure creation.

Primary focus areas:
- VM troubleshooting
- VNet / NSG / routing validation
- Azure Monitor and KQL triage
- RBAC troubleshooting
- Cost and policy validation

## Delivery model

- the lab environment is deployed by the proctor using Bicep before the session
- a single deployment creates isolated environments for all students in one resource group
- each student environment contains intentional misconfigurations for troubleshooting
- students spend their time diagnosing and fixing issues, not building infrastructure
- assume a sandbox subscription already exists for the customer

## Architecture

Each student gets:
- a VNet with management and workload subnets
- an NSG with a baked-in deny rule (troubleshooting exercise)
- a route table with a baked-in blackhole route (troubleshooting exercise)
- a private Ubuntu 22.04 VM (deallocated, with a failed extension)
- a storage account for boot diagnostics
- access to a shared Log Analytics workspace for KQL exercises

![Azure 101 Lab topology preview](assets/azure-101-lab-topology-preview.svg)

Editable Draw.io source: [assets/azure-101-lab-topology.drawio](assets/azure-101-lab-topology.drawio)

## Quick start (for proctors)

```bash
# 1. Create the resource group
az group create --name azure101lab-rg --location eastus

# 2. Copy and edit the parameters file
cp infra/parameters.example.bicepparam infra/parameters.bicepparam
# Edit: set userPrefixes, adminPassword, and optionally studentPrincipalId

# 3. Deploy
az deployment group create \
  --resource-group azure101lab-rg \
  --template-file infra/main.bicep \
  --parameters infra/parameters.bicepparam
```

See [docs/proctor-guide.md](docs/proctor-guide.md) for full deployment and delivery instructions.

## Project structure

- [infra/main.bicep](infra/main.bicep) - Bicep deployment orchestrator
- [infra/modules/](infra/modules/) - Bicep modules (shared resources, per-user environment, VM stop script)
- [infra/parameters.example.bicepparam](infra/parameters.example.bicepparam) - example parameters file
- [docs/proctor-guide.md](docs/proctor-guide.md) - proctor deployment and delivery guide
- [docs/student-guide.md](docs/student-guide.md) - participant-facing troubleshooting guide
- [docs/self-guided-playbook.md](docs/self-guided-playbook.md) - self-guided lab structure and checkpoints
- [docs/scenario-list.md](docs/scenario-list.md) - scenario inventory with pre-deployed faults
- [docs/build-checklist.md](docs/build-checklist.md) - proctor deployment verification checklist
- [docs/lab-agenda.md](docs/lab-agenda.md) - recommended 90 and 120 minute agendas
- [docs/troubleshooting-guide.md](docs/troubleshooting-guide.md) - troubleshooting method and Azure tools
- [docs/resource-map.md](docs/resource-map.md) - resource topology and relationships
- [docs/v1-framework.md](docs/v1-framework.md) - original lab framework (historical)
- [docs/v2-roadmap.md](docs/v2-roadmap.md) - deferred automation backlog
- assets/ - diagrams and supporting visuals
