---
title: Separate safe file preservation from successful kit integration
created: 2026-09-28
updated: 2026-09-28
tags: [installer, upgrade, claude-md]
problem_type: process
source: correction
confidence: high
top_rule: false
status: active
related: []
# --- Typed relations (all optional; consumed by scripts/lesson-graph.sh) ---
supersedes: []
applies_to: [migrations, scope-discipline, verification]
contradicts: []
related_decisions: [adr-017, adr-023]
---

## Issue

The architecture diagnosis correctly found the branches that leave a user-owned `CLAUDE.md` untouched and the three-way upgrade behavior for a kit-managed file, but its framing emphasized that an untouched user file does not gain the kit integration. This made the proposal read as though `install.sh --upgrade` did not preserve `CLAUDE.md`, even though preservation is a deliberate, tested safety property.

## Root Cause

The analysis conflated two independent properties: preserving existing user content and integrating kit instructions into Claude Code. A file may be preserved perfectly while the kit remains unreferenced. The proposal also introduced a section-level migration design without first stating that the existing baseline-backed three-way mechanism should remain the primary preservation mechanism.

## Rule

When reviewing install or migration behavior, report preservation and integration as separate axes. State the exact branch matrix for user-owned, untouched kit-managed, locally edited, conflicting, pre-baseline, and explicit-template cases. Reuse existing three-way and backup guarantees before proposing additional migration logic.

## Verification

The architecture artifact has a preservation-versus-integration matrix and says the new managed-block migration builds on `upgrade_file`, `.kit-baseline`, backups, and `.kit-new` rather than replacing them.

## References

- `install.sh:644-704`
- `install.sh:733-762`
- `install.sh:1061-1095`
- `install.sh:1144-1159`
- `scripts/test-install.sh:667-688`
- `scripts/test-install.sh:839-853`
- [[installed-capabilities-need-runtime-activation]]
