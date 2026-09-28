---
title: Separate repository access from distributed artifact access
created: 2026-09-27
updated: 2026-09-27
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
related_decisions: []
---

## Issue

The user asked to keep the current product and private repository unchanged while allowing users to use the product without repository access. The response proposed changing the registry, workflow, license, and installation model, expanding the scope beyond the requirement.

## Root Cause

The request was interpreted as requiring secrecy from authorized users rather than separating access to the private source repository from access to the existing distributable artifact. The answer did not distinguish "cannot browse the repository" from "cannot inspect files necessarily installed on the user's machine."

## Rule

When discussing private-source distribution, first preserve the existing product and delivery model. Distinguish repository privacy from artifact visibility, and recommend publishing the existing curated artifact to a public package registry when users may inspect installed runtime files but must not access the source repository.

## Verification

State explicitly which files are distributed, which repository-only files remain private, and whether the proposed path requires repository credentials or project changes.

## References

- `package.json` → `files`
- `scripts/test-install.sh` → package-content assertions
