---
title: Installed capabilities need runtime discovery, activation, and maintenance hooks
created: 2026-09-28
updated: 2026-09-28
tags: [hooks, modules, subagents]
problem_type: process
source: correction
confidence: high
top_rule: false
status: active
related: []
# --- Typed relations (all optional; consumed by scripts/lesson-graph.sh) ---
supersedes: []
applies_to: [hooks, subagents, context-hygiene]
contradicts: []
related_decisions: []
---

## Issue

The installation-architecture proposal covered where subagents and optional modules would live, and proposed some module invariants, but did not make runtime discovery complete. The existing `subagent-pre.sh` and `subagent-post.sh` hooks only record telemetry; they do not tell Claude which subagents are available. Module reminders were proposed, while project-document maintenance was deferred to an optional later phase. The maintainer corrected that installed subagents, Wiki/HTML modules, and relevant project-document updates should all be surfaced naturally by hooks.

## Root Cause

The proposal separated files by ownership and location without applying the same lifecycle analysis to every installed capability. It treated installation and passive instructions as sufficient discovery, and treated documentation drift as optional rather than part of ongoing kit maintenance.

## Rule

For every installed capability, design all four lifecycle parts explicitly: discovery at session start, task-time activation, deterministic invariants where possible, and maintenance after relevant changes. Installing files is not equivalent to making the capability operational. Keep objective invariants blocking, and keep judgment-based update reminders advisory or require an explicit impact decision rather than guessing.

## Verification

Any proposal that installs a capability carries a lifecycle matrix (discovery, activation, maintenance, verification) covering subagents, each installed module, and the project documents it touches, and its implementation plan puts the required hooks in a non-optional phase.

## References

- `.claude/hooks/subagent-pre.sh` and `.claude/hooks/subagent-post.sh` — telemetry only; neither tells Claude which subagents exist
- `.claude/hooks/session-start.sh` — injects Tier 1 pointers but nothing about installed modules or agents
