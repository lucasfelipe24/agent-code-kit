---
title: Separate repository access from distributed artifact access
created: 2026-09-27
updated: 2026-09-30
tags: [distribution, privacy, requirements]
problem_type: process
source: correction
confidence: high
top_rule: false
status: active
related: []
supersedes: []
applies_to: [scope-discipline, deploy]
contradicts: []
related_decisions: [adr-025, adr-028]
---

## Issue

The user asked to keep the current product and private repository unchanged while allowing users to use the product without repository access. The response proposed changing the registry, workflow, license, and installation model, expanding the scope beyond the requirement.

## Root Cause

The request was interpreted as requiring secrecy from authorized users rather than separating access to the private source repository from access to the existing distributable artifact. The answer did not distinguish "cannot browse the repository" from "cannot inspect files necessarily installed on the user's machine."

## Rule

Preserve the existing product and delivery model first. When a request is about access, separate who can reach the source repository from who can reach the distributed artifact, and answer within the current model before proposing to change the registry, workflow, license or installation. If the answer needs a change to any of those, present it as an option with its cost, not as the plan.

Context has since moved: the repository became public (ADR-025) and npm publishing is opt-in (ADR-028). The rule stands as scope discipline; its original recommendation, publishing the curated artifact to a public registry, no longer applies to this repo.

## Verification

State explicitly which files are distributed, which repository-only files remain private, and whether the proposed path requires repository credentials or project changes.

## References

- `package.json` → `files`
- `scripts/test-install.sh` → package-content assertions
