# Self-Guided Playbook

## Purpose

This document defines how the lab works as a fully self-guided experience with a pre-deployed environment.

## Audience

Core hosting and cloud engineers who need baseline Azure operational troubleshooting skills.

## Self-guided goals

Learners should be able to complete the lab independently and leave the session able to:

- troubleshoot VM state and extension issues
- recognize RBAC scope and permission failures when attempting write operations
- understand the relationship between VM, NIC, subnet, NSG, route table, and storage
- use Azure portal views and logs for triage
- recognize simple cost and policy concerns

## Recommended duration

- 90 minutes for a focused lab run
- 120 minutes for a slower pace with deeper reading of linked references

## Prerequisites

Before starting, confirm:

- the lab environment has been pre-deployed by the proctor
- you have your assigned user prefix (e.g., `userA`)
- you have your resource group name (e.g., `azure101lab-userA-rg`)
- you can access Azure portal and Cloud Shell
- you have VM credentials (if needed for serial console or Run command)

## Your pre-deployed environment

Each learner has:
- 1 VNet with 2 subnets
- 1 NSG (associated to workload subnet)
- 1 route table (associated to workload subnet)
- 1 NIC (in workload subnet, no public IP)
- 1 Ubuntu VM on `Standard_B1s`
- 1 storage account (boot diagnostics)
- Access to a shared Log Analytics workspace

The environment contains intentional misconfigurations. Your job is to find and fix them.

## Self-guided completion pattern

Use the repository materials in this order:

1. read [student-guide.md](student-guide.md) — this is your primary guide
2. use [troubleshooting-guide.md](troubleshooting-guide.md) when a symptom appears
3. expand the solution and validation sections inside [student-guide.md](student-guide.md) only after attempting the task yourself
4. use [scenario-list.md](scenario-list.md) to understand the scenario objectives

## Known-good checkpoints

Use these checkpoints as you progress:

1. portal access confirmed and your resource group identified
2. VM state issue identified (deallocated)
3. Permission denied when attempting to start VM — Reader role identified
4. Proctor upgraded access to Contributor
5. VM started and failed extension addressed
6. NSG deny rule identified and fixed
7. Blackhole route identified and removed
8. KQL evidence gathered for at least two faults
9. Missing tags and cost concerns documented

## Common learner issues

- not attempting to start the VM before investigating permissions — the permission denied error is the natural trigger for RBAC discovery
- not checking boot diagnostics or serial console (remember: no public IP on the VM)
- overlooking the NSG rule priority — always check priority numbers
- forgetting to check effective routes vs just the route table
- treating policy errors as generic deployment failures
- not correlating Activity Log timestamps with the issues found

## If you get stuck

Work the problem in this order:

1. restate the symptom in one sentence
2. identify the exact resource involved
3. check the Activity Log for recent entries
4. check the relevant resource configuration
5. compare your result to the expandable solution section in [student-guide.md](student-guide.md)
6. open the linked Microsoft Learn article for the module you are on

## Follow-up

After completing the lab:

- save your notes for the recap discussion
- note which scenarios were most confusing
- your proctor will handle resource cleanup
