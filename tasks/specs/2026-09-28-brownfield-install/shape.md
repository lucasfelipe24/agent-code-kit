# Decisions: The kit works in existing projects (brownfield install)

Source of each decision: **maintainer** (answered in the office-hours), **delegated** (the maintainer asked the agent to decide by good sense on 2026-09-28), or **proposal** (a confirmed decision D1–D9 of the original proposal, kept). Deferring a proposal decision out of this milestone does not revoke it.

## Decision 1: Who this is for
**Chosen**: brownfield first — the maintainer's 5 projects (all existing projects) plus a few installs by people the maintainer knows. *(maintainer)*
**Alternatives**: treat greenfield as the main path, as the current installer does.
**Rationale**: 5 of 5 known own installs are brownfield. Greenfield-only optimizations (3-entry root, map created on demand) lose priority.

## Decision 2: Acceptance criteria
**Chosen**: the seven criteria in `plan.md` → Goal, all in this milestone. *(maintainer)*
**Alternatives**: only the four install/uninstall/upgrade criteria, leaving adoption (6) and layout (7) for later.
**Rationale**: the maintainer wants adoption and a clean root in the same milestone; the release split keeps each step small.

## Decision 3: Four releases, not one
**Chosen**: R1 fixes → R2 kit folder + layout cut → R3 `CLAUDE.md` integration → R4 adoption; each leaves the kit working. *(delegated)*
**Alternatives**: a single release with everything.
**Rationale**: the fixes are urgent and need no layout change; a single release would put the urgent fixes and the riskiest code (the migration) in one `--upgrade` of every known install.

## Decision 4: Ownership comes from the baseline, never from the manifest alone
**Chosen**: a file is the kit's only if `.kit-baseline` records it; removal also requires an unchanged hash. With no `.kit-baseline` at all (pre-baseline install), apply ADR-023: kit-named files replaced with a backup and reported; everything else is the user's. *(delegated, from finding N1 / C1)*
**Alternatives**: trust `.kit-manifest` (current behavior); compare content with every past release.
**Rationale**: N1 shows the manifest of brownfield installs lists the user's own files. The installer records a baseline entry for every file it writes, so absence is a reliable signal. Content comparison with old releases is impossible: the repository history starts at v1.22.4.

## Decision 5: Kit folder is `.claude/kit/`
**Chosen**: `.claude/kit/` for every kit-internal file. *(proposal D1)*
**Alternatives**: `.kit/`, `.agent-code-kit/` — both add a root entry and lack `.claude/`'s write protection.
**Rationale**: no new root entry; Claude's writes into `.claude/` prompt, which protects files only the installer should write.

## Decision 6: What stays at the project root
**Chosen**: only what a tool requires there, what belongs to the project, and runtime output ignored by git. Closed list — required: `CLAUDE.md`, `.claude/`; project: `CODEBASE_MAP.md`, `tasks/` (on demand), `wiki/`, `raw-sources/`, `artifacts/` (with their modules), legacy `CLAUDE.project.md`; runtime, hidden: `.hook-state/`, `.kit-backup/`; on demand by opt-in tools: `AGENTS.md`, `.gitignore` block, `docs/`, `convert.sh` outputs, `DESIGN.md`. Leaving for `.claude/kit/`: `VERSION`, `.kit-manifest`, `.kit-baseline`, `agent_docs/`, `scripts/`, `WIKI.md`, `ARTIFACTS.md`. Not created: `agent_docs/project/*`, template files inside `tasks/`. *(maintainer for runtime dirs; delegated for the rest)*
**Alternatives**: the proposal's version, which also moved runtime state into `.claude/kit/state/` (phase 5).
**Rationale**: the rule set used — tool requirement wins; a name common in projects is a veto (`VERSION`, `scripts/`, `reports/`); what Claude edits every session stays outside `.claude/`; installer-only files go in; runtime output ignored by git may stay at the root. Moving `.hook-state/` would touch 18 hooks and 57 bench scenarios for no user-visible gain, since it is already ignored by git.

## Decision 7: `.kit-manifest` and `.kit-baseline` leave the root
**Chosen**: move to `.claude/kit/manifest` and `.claude/kit/baseline`. *(delegated, decision A)*
**Alternatives**: keep them at the root — hidden, no collision, zero cost.
**Rationale**: they are generated but versioned (teammates need them to upgrade and uninstall), so the runtime exception doesn't cover them.

## Decision 8: `reports/` folds into `.hook-state/`
**Chosen**: the session audit log lives under `.hook-state/`. *(delegated, decision B)*
**Alternatives**: keep `reports/` at the root.
**Rationale**: `reports/` is a common project folder name, and `session-end.sh` only creates `reports/.gitignore` when missing — a project with its own `reports/.gitignore` sees `session-audit.log` in `git status` and can commit it (G2). The move touches 1 hook, 1 skill and 1 bench scenario; no hook deletes `.hook-state/` wholesale.

## Decision 9: Upgrade conflicts stay next to the file
**Chosen**: `*.kit-new` stays beside the file it conflicts with. *(delegated, decision D)*
**Alternatives**: collect them in `.claude/kit/conflicts/` (proposal).
**Rationale**: like `.orig` / `.rej`, a conflict is temporary and asks for action; beside the file is where the user looks.

## Decision 10: Migration without a journal file
**Chosen**: backup first, copy + verify, rewrite, remove verified origins; a re-run derives each step's state from disk. *(delegated)*
**Alternatives**: a TSV `migration.journal` with per-step status (proposal).
**Rationale**: the proposal's own completion test ("destination sha ok and origin gone") is a disk check, so the journal duplicates state that can drift from it. The per-file report stays.

## Decision 11: `CLAUDE.md` integration by managed block and `@import`
**Chosen**: block with generated `@import` lines; modes `block | separate | skip`; `separate` (block in `.claude/CLAUDE.md`) is the default without a TTY. *(proposal D2, validated)*
**Alternatives**: keep skipping an existing `CLAUDE.md` (today: kit inert); overwrite it (data loss).
**Rationale**: tested on 2026-09-28 with Claude Code 2.1.283 in throwaway directories — a new `claude -p` session quoted codewords from `./CLAUDE.md`, `./.claude/CLAUDE.md` and a file imported from each. Not documented, so it becomes a manual release smoke.

## Decision 12: `module.conf` enters this milestone
**Chosen**: per-module `module.conf` + `CONTRACT.md` in R2. *(delegated)*
**Alternatives**: defer to the next milestone.
**Rationale**: criterion 7 already forces `WIKI.md` and `ARTIFACTS.md` out of the root, which touches the same ~7 hard-coded sites; doing both at once avoids editing them twice and lets the Playbook module be born on `module.conf`.

## Decision 13: Out of this milestone
**Chosen**: deferred — single core + `stacks/` (F8), `DESIGN.md` in the standard profile (D6), no `CLAUDE.project.md` on new installs (D7), capability digest, module invariants and doc-impact gate (D9), Harness as a module (F10 persists meanwhile), plugin packaging, moving `.hook-state/`. *(delegated)*
**Alternatives**: include them, as the proposal's phases 3 and 5 did.
**Rationale**: no acceptance criterion needs them. Deferring D7 also removes, for now, its conflict with the Playbook (which reads `## Tracking` from `CLAUDE.project.md`).

## Decision 14: `DESIGN.md`, when it lands, only with a frontend signal
**Chosen**: create `DESIGN.md` only when the project shows a frontend (deterministic markers), not on every standard install. *(delegated, decision C — changes D6's timing, not its location)*
**Alternatives**: always in the standard profile (D6 as written).
**Rationale**: in a project with no UI (Go API, Rust CLI) it is root noise with no consumer.

## Decision 15: Adoption is a skill backed by deterministic scan and check
**Chosen**: `/kit-adopt` + `adopt-scan.sh` + `docs-check.sh`; `session-start` points to it while adoption is pending; headless mode opt-in. *(proposal D4)*
**Alternatives**: CLI only (bash can't write prose); prompt only (no facts, no validation); extend `/harness-init` (ADR-010 scopes it to `docs/`).
**Rationale**: the kit's own Model vs Code rule — scanning, validating and promoting are deterministic; describing the architecture is judgment.

## Decision 16: Hard cut to layout 2
**Chosen**: after the R2 upgrade only the new paths are read; legacy is known only to the migrator. *(proposal D8, justified by Decision 1)*
**Alternatives**: a runtime fallback window reading both layouts.
**Rationale**: installs outside the maintainer's control exist, so the migration must be automatic; the users are few and reachable, so no fallback window is needed.
