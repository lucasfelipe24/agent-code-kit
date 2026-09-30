---
title: Separate safe file preservation from successful kit integration
created: 2026-09-28
updated: 2026-09-30
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

- `install.sh:677-725` — `upgrade_file`, the three-way update
- `install.sh:757-783` — `kit_claude_md`, `installed_template`
- `install.sh:1090-1105` — the unknown-template branch that leaves `CLAUDE.md` untouched
- `install.sh:1144-1170` — first-install `CLAUDE.md` handling
- `scripts/test-install.sh:710-731` — an unknown template is left untouched
- `scripts/test-install.sh:883-894` — a `CLAUDE.md` written by `/init` survives the upgrade
- [[2026-09-28-installed-capabilities-need-runtime-activation]]

Line numbers are for `main` @ `622ef95`; they drift, so re-check them before citing.
