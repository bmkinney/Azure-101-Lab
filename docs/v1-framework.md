# Azure Operations Lab v1 Framework

## 1. Lab objective

Build a 90-120 minute hands-on Azure Operations lab that teaches core Azure build, triage, and remediation skills across:

- VM troubleshooting
- VNet, NSG, and routing validation
- Azure Monitor and KQL triage
- RBAC troubleshooting
- Cost and Azure Policy validation

Primary goal:
- create repeatable baseline operational skills
- reduce dependence on a few architects for routine Azure troubleshooting

## 2. Delivery model

Recommended v1 model:

- host the lab content in a GitHub repo that the customer can copy or fork
- customer can fork the repo into their GitHub organization for reuse
- assume a sandbox subscription already exists before the lab starts
- each participant receives their own resource group in the sandbox subscription
- each participant builds and troubleshoots their own Azure resources by following the lab guide

This is the right v1 model because it is:
- simple to stand up
- easy to explain
- low overhead for the first release
- aligned to learning-by-doing
- easy to evolve into an automated v2 later

## 3. Core assumptions for v1

The lab will assume:

- the customer provides a sandbox subscription
- each lab user has a dedicated resource group
- each lab user has enough access to create and manage resources inside their own resource group
- subscription-level governance such as policies may already exist and can be observed during the lab
- the lab guide is the primary delivery artifact

Recommended minimum participant access:

- `Contributor` on their own resource group
- `Reader` at subscription scope if broader visibility is needed for policy or cost views

## 4. Design principles for v1

The lab should be:

- hands-on and build-first
- simple enough to complete in 90-120 minutes
- focused on common operational tasks
- isolated per participant
- light on prerequisites
- realistic enough to reflect normal Azure operations work

Important design choice:
v1 should avoid heavy automation. Participants should create the core resources themselves so they learn what the objects are, how they relate, and where to troubleshoot them.

This also makes reset simple:
- the participant can delete and recreate resources inside their own resource group
- the repository can provide known-good checkpoints in the guide
- the customer can rerun the lab later without depending on any live delivery support

## 5. Recommended repo structure

A good v1 repo structure:

- `README.md`
  - overview
  - prerequisites
  - lab assumptions
  - future roadmap

- `docs/`
  - `v1-framework.md`
  - `student-guide.md`
  - `self-guided-playbook.md`
  - `lab-agenda.md`
  - `scenario-list.md`
  - `answer-key.md` as an optional redirect file only

- `assets/`
  - diagrams
  - screenshots
  - architecture visuals

For v1, the repository is primarily documentation.

## 6. Lab build model

In v1, each participant builds a small Azure environment in their own resource group.

Recommended participant-built resources:

- 1 virtual network
- 2 subnets
- 1 network security group
- 1 route table
- 1 virtual machine
- 1 storage account
- diagnostic settings where appropriate
- Azure Monitor data collection and KQL exercises using available logs

The lab should use a progressive flow:

1. create the core resources
2. validate basic connectivity and configuration
3. introduce or expose issues
4. troubleshoot and remediate
5. review operational lessons learned

## 7. Recommended lab topology

Keep the topology intentionally small.

### Minimal v1 participant environment
- 1 resource group per participant
- 1 VNet
- 2 subnets
- 1 NSG
- 1 route table
- 1 NAT gateway associated to the workload subnet
- 1 Standard public IP attached to the NAT gateway
- 1 Ubuntu VM on a small burstable SKU such as `Standard_B1s`
- 1 storage account
- Azure Monitor access for logs and KQL exercises

### How issues should be introduced in v1
Because resources are being built manually, faults should be introduced through documented lab steps rather than through automation. Examples:

- create an NSG rule that blocks expected management traffic
- apply a route that breaks a connectivity path
- remove or misconfigure a VM setting and validate the symptom
- attempt an action that fails because of RBAC scope
- review an existing policy restriction in the sandbox subscription
- identify a cost concern based on resource choices or unused components

## 8. Lab modules and timing

For a 90-120 minute session:

### Module 0 - setup and orientation (10 min)
- lab goals
- sandbox assumptions
- resource map
- where to look first
- how success is validated

### Module 1 - build the core environment (20-25 min)
Participant tasks:
- create a resource group if needed
- create a VNet and subnets
- create an NSG and associate it correctly
- create a NAT gateway for outbound internet access
- create a small Ubuntu VM on a burstable SKU
- create a storage account

Outcome:
- participant understands the core Azure objects and their relationships

### Module 2 - VM troubleshooting (15-20 min)
Scenario examples:
- VM requires portal-native troubleshooting because it has no direct public IP
- service not running
- configuration issue after initial deployment
- VM setting or networking symptom that requires triage

Outcome:
- participant identifies whether issue is guest OS, platform, or access related

### Module 3 - VNet / NSG / routing validation (20-25 min)
Scenario examples:
- traffic blocked by NSG
- wrong subnet association
- route table causing asymmetric or dropped path

Outcome:
- participant validates effective NSG rules, subnet config, route path, and connectivity

### Module 4 - Azure Monitor and KQL triage (20 min)
Scenario examples:
- use Log Analytics to identify connection failures, heartbeat gaps, or activity anomalies
- query AzureActivity, AzureDiagnostics, or VM insights tables

Outcome:
- participant uses KQL to isolate the likely failure domain

### Module 5 - RBAC troubleshooting (15-20 min)
Scenario examples:
- user can view but not perform an action
- scope does not allow the required operation
- action is blocked because permission is outside the participant boundary

Outcome:
- participant identifies a scope problem and understands the required remediation path

### Module 6 - Cost and policy validation (15-20 min)
Scenario examples:
- find idle spend
- identify non-compliant tag/location/SKU issue
- determine why an action is denied by policy

Outcome:
- participant can explain both the policy finding and basic cost concern

### Wrap-up (10 min)
- review answers
- reinforce triage sequence
- identify portal views and KQL queries to reuse in real operations

## 9. Student experience

The student guide should be task-based, not instruction-heavy.

Each scenario should include:

- business symptom
- starting state
- objective
- allowed tools
- validation criteria
- optional hint 1 / hint 2 / hint 3

Avoid giving exact click paths immediately.
Force diagnostic thinking first.

Good prompt style:
- "An application owner reports they cannot reach the VM over the expected management path. Determine whether the problem is the VM, NSG, route, or RBAC."

Not good:
- "Go to NSG rules and add port 3389."

## 10. Self-guided experience

The self-guided playbook should include:

- sandbox prerequisites
- expected duration
- lab topology diagram
- student guide with embedded expandable solution sections
- reset instructions
- common failure patterns
- escalation guidance for when the learner is blocked

Also include:
- hint 1, hint 2, and hint 3 for each major module
- links to effective routes, activity log, access control, and other portal locations learners should check next

## 11. Reset and teardown model

For v1:

### Reset
- participants can delete and recreate resources in their own resource group
- the guide should include known-good checkpoints after each major build step
- the repository should include a cleanup checklist between runs

### Teardown
- delete all resources in the participant resource group at the end of the lab
- optionally delete and recreate the resource group between cohorts

This keeps the v1 reset model easy to understand and easy to operate.

## 12. Security and access model

Keep access minimal and intentional.

### Recommended participant permissions
At minimum, grant only what is needed to complete the exercise.
Examples:
- `Contributor` on the participant resource group
- `Reader` at subscription scope if needed for policy, activity log, or cost review

Avoid broad subscription `Owner` unless absolutely necessary.
Use RBAC scope boundaries as part of the learning experience.

## 13. v1 success criteria

The lab is successful if participants can:

- build a basic Azure environment from scratch in their own resource group
- determine where to start troubleshooting in Azure
- distinguish compute, network, monitoring, RBAC, and policy issues
- use Azure Monitor and basic KQL for triage
- recognize scope-related RBAC failures
- identify simple cost waste and policy non-compliance
- remediate common issues with confidence

## 14. What v1 should not try to do

Do not overload the first version with:

- Terraform automation
- GitHub Actions deployment workflows
- landing zone design
- advanced hub-spoke architecture
- firewall/NVA deep dives
- multi-subscription governance complexity
- custom role engineering unless needed

v1 should optimize for clarity and repeatability.

## 15. Recommended next deliverables

The next useful set of artifacts would be:

1. repo skeleton
2. lab architecture diagram
3. student guide outline
4. self-guided playbook outline
5. first 5 scenario definitions
6. build checklist for participants
7. v2 backlog for Terraform and GitHub automation

## 16. Immediate next steps

Initial v1 documentation set created in this repository:

- `docs/student-guide.md`
- `docs/self-guided-playbook.md`
- `docs/lab-agenda.md`
- `docs/scenario-list.md`
- `docs/build-checklist.md`
- `docs/v2-roadmap.md`

Recommended next actions:

- refine the step-by-step build instructions based on the preferred VM OS and lab region
- decide which troubleshooting prompts should appear directly in the self-guided materials
- add one simple architecture diagram for the participant environment
- pilot the flow with a small audience and capture timing feedback

## 17. V2 roadmap

Terraform and GitHub workflow automation should move to v2 after the manual lab is proven.

Candidate v2 enhancements:

- Terraform-based lab provisioning
- GitHub Actions for validate, plan, apply, and destroy
- prebuilt fault injection and reset automation
- standardized cohort deployment model
- reusable customer fork model for self-service lab delivery
