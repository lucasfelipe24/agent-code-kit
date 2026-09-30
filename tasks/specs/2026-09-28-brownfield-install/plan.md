# Feature: The kit works in existing projects (brownfield install)

**Status:** Shaped — not started. Each release starts with its own plan in `tasks/todo.md`, approved before any code; R2–R4 are protected changes and each needs an ADR in `tasks/decisions.md`.
**Date:** 2026-09-28
**Source:** `/office-hours` validation of the install/upgrade architecture proposal (local, gitignored artifacts listed in `references.md`). This folder carries everything needed to plan; the artifacts are background only.

---

## Goal

A project that already exists — its own `CLAUDE.md`, `.claude/settings.json`, `.claude/` hooks/agents/skills, `scripts/`, `tasks/`, `VERSION` — gets a kit that actually runs after `init`, loses nothing on `init`, `--upgrade` or `uninstall`, and keeps no kit-internal versioned files at its root.

Done means all seven acceptance criteria hold (each release closes some of them):

| # | Criterion | Closed by |
|---|---|---|
| 1 | Brownfield project with its own `CLAUDE.md`: in a new session after `init`, Claude follows the kit rules (checked with `claude -p` or `/memory`), and the user's file is not edited outside the managed block. | R3 |
| 2 | Brownfield project with its own `settings.json`: every hook of the profile is registered; the user's entries and permissions are preserved. | R2 (R1 makes the gap loud) |
| 3 | `init` changes no project file except the managed block and the kit's entries in `settings.json` (hash before/after). | R1, R3 |
| 4 | `uninstall` returns the project to its pre-`init` state: nothing the user created is removed (`VERSION`, `tasks/`, their own `.claude/`). | R1, R2 |
| 5 | `--upgrade` of the maintainer's 5 current projects runs without loss: diff reviewed first, backup present, user files identical. | every release |
| 6 | Adoption: the generated `CODEBASE_MAP.md` and `.claude/commands.json` pass `docs-check`, and every declared command runs. | R4 |
| 7 | No kit-internal versioned file at the project root — only what a tool requires there and what belongs to the project. Directories generated at runtime and ignored by git may stay at the root, hidden. No executable reference to an old path after the migration. | R2 |

Test for criterion 7: after `init` in an empty project, the first path component of every entry `git ls-files --others --exclude-standard` lists is in the closed root list (see `shape.md` → Decision 6).

## Context

- **Who:** the maintainer's 5 projects — all brownfield — plus a few installs by people the maintainer knows. Brownfield is the main install path, not an edge case.
- **Why now:** reproduced on v1.23.0 (`main` @ `622ef95`), the kit in an existing project is installed but inert, and install/uninstall lose project data:
  - `init` skips whole directories that already exist (`agent_docs/`, `tasks/`, `scripts/`, `.claude/hooks|agents|skills`, `settings.json`), so an existing `.claude/` gets no kit hook, agent or skill, and an existing `settings.json` gets no hook registered.
  - An existing `CLAUDE.md` is skipped: no kit rule is ever loaded. Without a TTY, `init` aborts.
  - `VERSION` of the project is overwritten, then deleted by `uninstall`.
  - **N1 (new, reproduced):** in the skip branches, `init` records the *user's own* hooks, agents, skills and `settings.json` in `.kit-manifest`; `uninstall` then lists all of them for removal, plus the emptied `.claude/`.
- **Today's workaround:** manual steps in the README (`:288`, `:419`) — move `CLAUDE.md`, delete it, run `--upgrade`.
- **Cost of doing nothing:** every known install is brownfield, so every known install is exposed.

## Approach

Four releases; each leaves the kit working and ships alone.

### R1 — Fixes in the current layout (no protected change)

One ownership rule, applied everywhere: **a file is the kit's only if `.kit-baseline` records it** (and, for removal, only if its hash still matches). Build it first as an isolated classifier with fixtures — it is the riskiest assumption (C1) and R1 is where it gets tested, on the uninstall path, before any migration code exists.

1. Ownership classifier + fixtures: v1.23.0 installer on a project with its own `.claude/`; the same install with `.kit-baseline` removed; a user file with the same name as a kit file (e.g. `.claude/agents/code-reviewer.md`).
2. **N1, F4, F9** — `uninstall` removes only baseline-owned, unchanged files; directories only when left empty; never `settings.json` unless the kit wrote it.
3. **F5, F6, F12, N1 (install side)** — per-file copy for `agent_docs/`, `tasks/`, `scripts/`, `.claude/hooks|agents|skills` (as `--upgrade` already does); collisions are skipped and reported; only files the kit wrote enter the manifest.
4. **F1** — never overwrite a `VERSION` that isn't the kit's (see Open Questions for where the kit version lives meanwhile).
5. **F2** — until R2 merges `settings.json`: a loud warning at `init` and a `doctor` failure when kit hooks aren't registered.
6. **F7** — without a TTY, `init` continues with "skip existing, never overwrite" and reports what it skipped.
7. **G1** — the `--gitignore` block also ignores `.kit-baseline`.
8. **G2** — the session audit log moves from `reports/` into `.hook-state/` (decision B); `--upgrade` moves an existing log.
9. A regression test per defect in `scripts/test-install.sh`; KitBench scenario for G2.

### R2 — Kit folder and layout cut (protected: ADRs for layout, settings merge, migration, modules)

1. `.claude/kit/` holds `VERSION`, `manifest`, `baseline`, `install.conf` (version, profile, stack, modules, integration mode, adoption state, layout), `docs/` (was `agent_docs/`), `scripts/`, `hooks/` + `lib/`, `templates/` (lesson, handoff, `*.example`), `modules/<name>/`. `.claude/hooks/` becomes the project's only.
2. Kit agents under `.claude/agents/kit/` (subfolders are discovered; identity comes from `name`). Skills stay at `.claude/skills/<name>/` (required).
3. `module.conf` + `CONTRACT.md` per module (`wiki`, `html`): installer, uninstall and doctor iterate module manifests instead of the ~7 hard-coded sites. `WIKI.md` / `ARTIFACTS.md` leave the root.
4. `settings.json` merge by owner: an entry is the kit's when its command runs a hook under `.claude/kit/hooks/`; an entry that differs from the baseline's copy is kept and reported, not overwritten. Tool order: node → python3 → manual instruction + loud warning + doctor failure.
5. Migrator (legacy layout → layout 2): plan per file with the R1 classifier → `--diff` preview on a scratch copy (ADR-021) → backup to `.kit-backup/<stamp>/` → copy + verify sha → rewrite `settings.json`, `.gitignore` block → remove verified origins. **No journal file:** a re-run derives each step's state from disk (destination sha ok + origin gone = done).
6. Hard cut (D8): after the upgrade, `session-start`, `doctor`, scripts and skills read only the new paths; legacy is known only to the migrator; `doctor` refuses a legacy or half-migrated layout with the instruction to resume.
7. Path references in skills go through a generated "Kit Context" block (`build-skills.sh`) plus a CI sync check, so the move is one block + the remaining hand edits.
8. `uninstall` driven by `install.conf` + baseline.

### R3 — `CLAUDE.md` integration (protected: ADR)

1. A managed block (`<!-- agent-code-kit:start/end -->`) with `@import` lines generated from `install.conf`; an inactive module never appears. The imported core is the current template (root or stack) copied to `.claude/kit/CLAUDE.kit.md` — consolidating the 8 copies (F8) is out of scope.
2. Modes `--claude-md=block|separate|skip`. Interactive: ask. Without a TTY: `separate` — the block goes to `.claude/CLAUDE.md`, the user's `./CLAUDE.md` is untouched. If `.claude/CLAUDE.md` is already the user's: ask for `block`; without a TTY, generate `.claude/rules/agent-code-kit.md` inline (imports inside rules are undocumented).
3. Upgrade rewrites only the block's inside; identical block → no write; missing markers or a hand-edited block → leave it, write the proposal next to it as `CLAUDE.md.kit-new`, report.
4. Legacy kit `CLAUDE.md`: reuse the existing three-way logic (`upgrade_file`); a legacy `CLAUDE.project.md` is imported by the block.
5. `doctor` and `session-start` flag a missing block when `install.conf` says it should exist; `uninstall` removes the block, not the file.
6. `gen-agents-md.sh` / `convert.sh` read the core + the project area outside the block + legacy `CLAUDE.project.md`.
7. Manual release smoke in `RELEASING.md`: the D2 load test (`claude -p` codewords in both files).

### R4 — Adoption (protected: ADR)

1. `adopt-scan.sh` → `.claude/kit/adopt/facts` (markers and lockfiles, package/Makefile/justfile/pyproject scripts, CI commands, lint/format configs, depth-2 tree, docs/ADR inventory, other tools' rules via the `convert import` list, commit style).
2. `docs-check.sh`: one placeholder list shared with `validate.sh` and `doctor.sh` (F11); every cited path exists; Key Commands = `commands.json` and each command resolves; declared stack appears in manifests (warning).
3. `/kit-adopt` skill, phases with checkpoints: `commands.json` (candidates from facts; code runs each with a timeout and keeps only those that run) → `CODEBASE_MAP.md` (fills only empty sections; unevidenced claims marked "(inferred — review)") → project area of `CLAUDE.md` (conflicts with kit rules become questions) → link existing ADRs. Drafts are written **outside `.claude/`** (a gitignored path) or through a kit script — Claude's writes into `.claude/` prompt every time.
4. Validation + promotion (temp + `mv` per file); report processed / failed / skipped with reasons; `install.conf` → `adoption=done` + hashes; failures leave `adoption=pending(reason)` and a re-run resumes.
5. `session-start` shows "adoption pending: run /kit-adopt" (one line; the full capability digest is out of scope).

## Files to Touch

R1:
- `install.sh` — per-file copy in the skip branches (`:1217` agent_docs, `:1251` tasks, `:1316` scripts, `:1381` hooks, `:1411` agents, `:1451` skills); `VERSION` guard (`:1159`); no-TTY path (`:1035-1038`); settings warning (`:1484-1501`); `--gitignore` block (`:1640`).
- `uninstall.sh` — ownership rule for removal (`:211` VERSION, `:213-215` CLAUDE.md, `:258-310` tasks, `:389` settings.json, `:425-443` manifest backstop).
- New `scripts/lib/ownership.sh` (or inside `scripts/lib/manifest.sh`) — the classifier, shared by install, uninstall, doctor and later the migrator.
- `scripts/doctor.sh` — fail on unregistered kit hooks.
- `.claude/hooks/session-end.sh` (`:28-31`), `.claude/skills/scorecard/SKILL.md`, `bench/scenarios/s15-session-end-writes-audit-line.json` — G2.
- `scripts/test-install.sh` — regression cases.

R2:
- `install.sh`, `uninstall.sh`, `scripts/lib/manifest.sh`, `scripts/doctor.sh`, `bin/cli.sh` (`:65-111` resolve scripts under `.claude/kit/`).
- `.claude/settings.json`, `scripts/gen-strict-settings.sh` → `.claude/settings.strict.json` — hook command paths.
- `.claude/hooks/session-start.sh` (reads `install.conf`), `scripts/note.sh:44` (hook lib path), `.claude/hooks/skill-compliance.sh:32` (finds skills relative to its own folder).
- `wiki-module/`, `html-module/`, `WIKI.md`, `ARTIFACTS.md` → module folders with `module.conf` + `CONTRACT.md`.
- `scripts/build-skills.sh`, `.claude/skills/_shared/blocks/`, skills citing `agent_docs/`, `scripts/`, `tasks/lessons`.
- `package.json` (`files`), `scripts/sync-manifest.sh`, `scripts/check-scaffold.sh`, `.github/workflows/validate.yml` (protected).
- New `scripts/test-layout.sh`, `scripts/test-migrate.sh`; `README.md`, `README.pt-BR.md`, `CODEBASE_MAP.md`, `AGENTS.md` (regenerated).

R3:
- `CLAUDE.md`, `examples/*/CLAUDE.md` (become the imported core), `install.sh`, `uninstall.sh`, `scripts/doctor.sh`, `.claude/hooks/session-start.sh`, `scripts/gen-agents-md.sh`, `scripts/convert.sh`, `RELEASING.md`, `scripts/test-layout.sh`.

R4:
- New `adopt-scan.sh`, `docs-check.sh`, `.claude/skills/kit-adopt/`, `scripts/test-adopt.sh` + fixtures; `scripts/validate.sh`, `scripts/doctor.sh` (shared placeholder list); `.claude/hooks/session-start.sh` (pending notice).

## Open Questions

- **F1 in R1:** where does the kit version live while the project owns `VERSION`? Recommended: skip + warn; the kit version reads "unknown" for that install until R2 moves it to `.claude/kit/VERSION`.
- **Source layout and dogfooding:** does the kit repo mirror the installed layout (`kit/` → `.claude/kit/`, `modules/`, `stacks/`), and how does this repo's own session keep working (its `CLAUDE.md` cites `agent_docs/`, `scripts/`)? Decide in the R2 ADR.
- **Pre-baseline installs:** how many existing installs predate `.kit-baseline` is unknown. No answer needed: the migrator applies the ADR-023 fallback (kit-named files replaced with a backup, loudly reported; everything else is the user's). The kit's git history starts at v1.22.4, so older releases can't be compared by content.
- **`tasks/` collision** (Celery, Gulp, Rake use `tasks/`): this milestone only detects non-kit content and doesn't mix; a configurable path is deferred.
- **Hard cut communication:** release notes for R2 must tell known external users to run `--upgrade` (with `--diff` first).
- **Playbook ordering:** the Playbook module goes after R2, so it is born on `module.conf`; `tasks/todo.md` → Up Next needs that order.

## Risks

- **Ownership misclassification (C1) — highest.** A wrong call replaces or removes a user file in a brownfield install, i.e. every known install. Mitigation: classifier first with fixtures (R1), backup before every rewrite/removal, `--diff` before the real run, per-file report.
- **D2 behavior is observed, not documented.** Claude Code 2.1.283 loads both `./CLAUDE.md` and `./.claude/CLAUDE.md` and resolves `@import` from both (tested 2026-09-28). A future release could change it; the release smoke catches it.
- **R2 blast radius:** `install.sh` (1718 lines), 37 skills, `doctor.sh`, 136 bench scenarios, `test-install.sh` (948 lines). Split R2 into reviewable PRs (classifier/migrator, layout, settings merge, modules).
- **Hard cut:** after upgrading the CLI, a legacy install is refused by `doctor` until `--upgrade` runs.
- **Adoption quality:** `docs-check` proves the output is valid, not useful; judge usefulness on public-repo fixtures.
- **Protected paths:** `package.json`, workflows and migrations trip `protect-changes.sh`; record the ADR before setting `CLAUDE_APPROVED=1`.
