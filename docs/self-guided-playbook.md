# Self-Guided Playbook

## Purpose

This document defines how the lab works as a fully self-guided experience.

## Audience

Core hosting and cloud engineers who need baseline Azure operational troubleshooting skills.

## Self-guided goals

Learners should be able to complete the lab independently and leave the session able to:

- build a basic Azure environment in a resource group
- understand the relationship between VM, NIC, subnet, NSG, route table, and storage
- use Azure portal views and logs for triage
- reason through RBAC scope and permission failures
- recognize simple cost and policy concerns

## Recommended duration

- 90 minutes for a focused lab run
- 120 minutes for a slower pace with deeper reading of linked references

## Sandbox prerequisites

Before starting, confirm:

- a sandbox subscription is available
- you have a dedicated resource group, or permission to create one
- you have `Contributor` on your resource group
- you can access Azure portal and Log Analytics if required
- you understand any subscription-level policies that may affect the lab

## Recommended baseline lab design

Each learner creates:
- 1 VNet
- 2 subnets
- 1 NSG
- 1 route table
- 1 NAT gateway
- 1 Standard public IP for the NAT gateway
- 1 Ubuntu VM on a small burstable SKU such as `Standard_B1s`
- 1 storage account

The environment should remain intentionally simple.

## Self-guided completion pattern

Use the repository materials in this order:

1. read [student-guide.md](student-guide.md)
2. use [build-checklist.md](build-checklist.md) during deployment
3. use [troubleshooting-guide.md](troubleshooting-guide.md) when a symptom appears
4. expand the solution and validation sections inside [student-guide.md](student-guide.md) only after attempting the task yourself
5. use [scenario-list.md](scenario-list.md) to understand the scenario objectives

## Known-good checkpoints

Use these checkpoints as you progress:

1. resource group confirmed
2. VNet and two subnets created
3. NSG created and associated
4. route table created and associated
5. VM deployed successfully
6. storage account created successfully
7. Activity Log and Access Control locations identified

## Common learner issues

- using overlapping address spaces
- creating the VM in the wrong subnet
- associating the NSG to the wrong place
- forgetting that route tables affect subnet traffic
- assuming visibility implies write permission
- treating policy errors as generic deployment failures

## If you get stuck

Work the problem in this order:

1. restate the symptom in one sentence
2. identify the exact resource involved
3. check recent Activity Log entries
4. check the relevant resource configuration
5. compare your result to the expandable solution section in [student-guide.md](student-guide.md)
6. open the linked Microsoft Learn article for the module you are on

## Reset guidance

For v1, reset is manual:
- delete and recreate failed resources
- rebuild from the last known-good checkpoint
- if necessary, delete and recreate the full resource group

## Follow-up

After completing the lab:

- clean up all billable resources
- note which scenarios took the longest
- note which policy and RBAC issues were most confusing
- use that feedback to refine future versions of the lab