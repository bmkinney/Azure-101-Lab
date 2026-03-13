# V2 Roadmap

## Purpose

This document captures the backlog for a future v2 of the Azure Operations lab.

## Why defer v2

The v1 goal is to prove the learning flow first:
- can participants build the environment quickly enough
- are the scenarios realistic and teachable
- which parts of the lab create the most confusion
- which steps are best candidates for automation later

## Candidate v2 enhancements

### Terraform-based provisioning
- deploy a baseline lab environment per participant or per cohort
- standardize resource naming and topology
- reduce build-time variance across participants

### GitHub-based automation
- add validate, plan, apply, and destroy workflows
- support customer fork and self-service delivery
- support repeatable cohort resets

### Fault injection and reset
- introduce prebuilt faults in a controlled way
- allow partial reset of specific scenarios
- support rapid re-delivery of the lab

### Lab operations
- add cohort setup guidance where needed for customer reuse
- document expected timings and operational overhead
- support optional pre-staged labs for shorter self-guided sessions

## Decision gate for v2

Move to v2 after at least one live or pilot delivery confirms:
- the v1 scope is correct
- the timing is realistic
- the scenario order works
- the most valuable automation targets are clear
