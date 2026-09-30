# References: The kit works in existing projects (brownfield install)

Line numbers are for `main` @ `622ef95` (v1.23.0).

## Codebase

- `install.sh:1159` — unconditional `cp` of `VERSION` (F1).
- `install.sh:1035-1038` — `read … < /dev/tty` aborts without a TTY (F7).
- `install.sh:1217`, `:1251`, `:1316` — whole-directory skip for `agent_docs/`, `tasks/`, `scripts/` (F5, F6).
- `install.sh:1380-1384`, `:1411-1414`, `:1451-1455` — skip branches that add the user's own hooks, agents and skills to `.kit-manifest` (N1); the hooks branch also drops `.claude/hooks/lib` (F12).
- `install.sh:1484-1501` — existing `settings.json` → "Skipped", no hook registered (F2).
- `install.sh:1640` — `--gitignore` block; `.kit-baseline` missing from it (G1).
- `install.sh:606-614` — `backup_file` into `.kit-backup/<UTC stamp>/`, which ignores itself in git.
- `install.sh:677-725` — `upgrade_file`, the three-way update against the baseline (ADR-017) to reuse for migration and `CLAUDE.md`.
- `install.sh:333-474` — `run_diff` (`--diff` on a scratch copy, ADR-021), the preview mechanism for the migration.
- `uninstall.sh:120-128` — `kit_wrote` / `baseline_hash`: the baseline lookup the ownership rule builds on.
- `uninstall.sh:211`, `:213-215`, `:258-310`, `:389`, `:425-443` — removal of `VERSION`, `CLAUDE.md` (no hash check, F9), `tasks/` (F4), `settings.json` (unconditional, N1), and the manifest backstop (N1).
- `.claude/hooks/session-end.sh:28-31` — `reports/` and its partial `.gitignore` (G2).
- `.claude/hooks/lib/roots.sh` — package / worktree / state roots; ~11 hooks still build `STATE_DIR` by appending `/.hook-state` themselves.
- `.claude/hooks/lib/state-counter.sh:26` — the `*` self-gitignore pattern `.hook-state/` uses.
- `scripts/lib/manifest.sh` — shared manifest primitives; home for the ownership classifier.
- `scripts/test-install.sh` — install/uninstall smoke tests (948 lines); style for `test-layout.sh`, `test-migrate.sh`, `test-adopt.sh`.
- `bench/scenarios/s15-session-end-writes-audit-line.json` — the one scenario that reads `reports/`.
- `.claude/skills/constitution/SKILL.md:110, 197` and `.claude/skills/quality-audit/SKILL.md:41-42` — `golden-principles.yaml` defaults to `.claude/`; lookup order differs (harmless).
- `CLAUDE.project.md` consumers (22): `session-start.sh`, `gen-agents-md.sh`, `convert.sh`, `doctor.sh` and 18 skills — the real cost of D7.

## Decisions and lessons

- `tasks/decisions.md` → ADR-009 (plugin, option D), ADR-010 (`/harness-init` scoped to `docs/`), ADR-011 (managed-block markers precedent), ADR-017 (per-file baseline), ADR-021 (`--diff` on a scratch copy), ADR-023 (a `CLAUDE.md` is the kit's only if it reads like one; pre-baseline fallback), ADR-027 (solo-maintained), ADR-028 (npm opt-in), ADR-029 (`ACK_` prefix cutover — precedent for a clean cut migrated by `doctor`).
- `tasks/lessons/2026-09-28-separate-preservation-from-integration.md` — preserving a user file and integrating the kit are separate axes.
- `tasks/lessons/2026-09-28-installed-capabilities-need-runtime-activation.md` — background for D9 (deferred here).
- `tasks/todo.md` → Up Next → "Install / upgrade architecture proposal" and "Playbook module" (ordering: Playbook after R2).

## Skills

- `/verification-status` — record the smoke test and processed / failed / skipped counts per release.
- `/review-pipeline` and the `devils-advocate` agent — review each release PR, especially the R1 classifier and the R2 migrator.
- `/doc-gardening` — reused by R4 on the documents adoption produces.
- `/harness-init`, `/constitution`, `/references-sync` — optional follow-ups adoption may suggest; not extended in this milestone.

## Local artifacts (gitignored — may not exist in other checkouts)

- `artifacts/2026-09-28-kit-install-architecture-proposal.html` — the original diagnosis and proposal (F1–F16, phases 0–5, D1–D9).
- `artifacts/2026-09-28-kit-install-proposal-office-hours.html` — the validation: facts rechecked on `622ef95`, platform claims, N1 reproduction, the office-hours answers.
- `artifacts/2026-09-28-kit-root-layout-analysis.html` — entry-by-entry root analysis and decisions A–E.

## External

- <https://code.claude.com/docs/en/memory.md> — `CLAUDE.md` locations, `@import` (relative paths, 4 hops, approval only outside the project), `.claude/rules/` with `paths:`; the "<200 lines" target. Silent on `./CLAUDE.md` + `./.claude/CLAUDE.md` together (tested instead — `shape.md` → Decision 11).
- <https://code.claude.com/docs/en/sub-agents.md> — agents discovered recursively under `.claude/agents/`; identity from `name`.
- <https://code.claude.com/docs/en/skills.md> — skills only at `.claude/skills/<name>/SKILL.md`.
- <https://code.claude.com/docs/en/hooks-guide.md> — settings scopes merge; no include/extends; `$CLAUDE_PROJECT_DIR`; SessionStart `source` values.
- <https://code.claude.com/docs/en/permission-modes.md> — `.claude/` (except `.claude/worktrees/`) is a protected path for Claude's writes.
