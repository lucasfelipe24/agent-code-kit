# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Configuration prefix cutover to ACK_ (ADR-029)

Goal: every kit variable, temp file and marker uses `ACK_` / `ack-`; the former
prefix appears in no tracked path or content (`scripts/check-prefix-residue.sh`
passes, and fails on planted residue); `doctor` migrates existing settings with
a backup and no printed values; a quality-gate failure noted under the former
marker still blocks. Released as a minor version by the maintainer's choice.

- [x] Rename 7 public variables, 3 internal names, the temp/marker files and the
  test scratch names; regenerate `.claude/settings.strict.json` from its script.
- [x] `doctor`: rename former-prefix keys in `.claude/settings.json` and
  `settings.local.json` (backup in `.hook-state/`, `ACK_` wins a conflict,
  values never printed); report exported former-prefix variables by target.
- [x] `--upgrade` / `--diff`: leave settings untouched, count former-prefix keys
  and point at `doctor`.
- [x] stop-gate / quality-gate carry the former gate marker over (s161);
  `convert` sweeps skills exported under the former marker.
- [x] Residue guard wired into `sync-manifest.sh --check` (CI Manifest Sync and
  `npm run check`); KitBench `null` env = unset.
- [ ] PR merged and released.

---

## Up Next

### Playbook module (decided 2026-09-28 — do not drop)

Adapt the engineering-playbook material reviewed on 2026-09-28 into the kit.
The full item-by-item spec (what to keep, adapt, correct or drop; ~60 factual
errors to fix on the way) is local, untracked:
`artifacts/2026-09-28-playbook-adaptation-spec.html`.

Decisions already made:

- **Placement (hybrid):** generic material goes to the core, loaded on demand;
  opinionated material and GitHub processes go to an optional `--playbook`
  module (same mechanism as `--wiki` / `--html`).
- **Issue-based processes are opt-in per project:** they apply only when
  `CLAUDE.project.md` declares `## Tracking: github-issues` and the repo has
  issues on; otherwise `tasks/todo.md` stays the tracker.
- **Rate limiting:** design guidance in `security.md` and `/security-audit`, plus
  one security-reviewer exception — missing throttling on credential endpoints
  (login, password reset) is a finding.
- **i18n:** English is the default and source locale; the rules apply only when
  the project already has i18n or asks for it (adding it is a Protected Change).
- **Opinionated choices** (libraries, naming, numbers) become defaults for when
  the project hasn't chosen; what the project already uses wins.
- **No external credits** in ported text.

Phases, one PR each, each starting with a plan approved here:

1. Core docs, loaded on demand through `prompt-router.sh` / `glob-guidance.sh`:
   database (migrations, types, indexes), multi-tenancy (the four real isolation
   strategies + five mandatory checks), API design + RFC 9457 errors, security,
   observability/logging, environments, Docker, CI/CD, git workflow, i18n; edits
   to `conventions.md` and `testing.md`. The `node-api` error-shape change needs
   an ADR.
2. Core process skills: `/pr-followup`, `/release`, `/incident`,
   `/security-audit`, `/onboard`; additions to `/ship`, `/dependency-audit`,
   the reviewers and the audit skills.
3. `--playbook` module: `/github-setup`, `/issue`, `PROCESS.md`, GitHub issue
   forms + PR template + labels, stack docs, git-hooks doc; install / upgrade /
   uninstall / doctor support with tests.
4. Stack templates: the few always-loaded lines per stack.
5. Deterministic checks from the spec, with KitBench scenarios.

### Install / upgrade architecture proposal (awaiting the maintainer's approval)

A separate review of init, upgrade, migration, modules and adoption produced a
phased proposal — analysis only, nothing implemented. Local, untracked:
`artifacts/2026-09-28-kit-install-architecture-proposal.html`. Open findings it
lists include: `VERSION` overwritten at the project root, an existing
`CLAUDE.md` / `settings.json` never integrated (no hook merge), all-or-nothing
directories, uninstall of edited `tasks/` / `CLAUDE.md`, a re-init dropping
`hooks/lib` from the manifest, and runtime discovery of subagents and active
modules (see the two lessons dated 2026-09-28). Review it, approve or cut the
phases, then plan here.

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

### Since the repository rebuild (1.22.4 → 1.22.5)

- [x] Repository rebuilt as a single clean commit; README redesigned in English
  and Portuguese; issues off, PRs limited to collaborators (ADR-027); npm
  publishing opt-in, GitHub releases only (ADR-028); CHANGELOG linted in CI
  (ADR-026); the link check scans every Markdown file.
- [x] Hook context reaches the model (`hookSpecificOutput`); Bash policy hooks
  close heredoc commits, `--no-verify`, dependency adds, secret staging,
  `+main` / `--all` pushes, `core.hooksPath`, pathspec files and unresolved cwd
  changes; KitBench 99 → 156 scenarios.
- [x] Skills/docs corrected (WCAG 2.2, audit commands, Next.js); `gen-agents-md`
  skips nested checkouts.

### Since v1.21.1

- [x] Pre-release fix round for the verification-core batch. Three adversarial
  reviews of the merged batch found bugs the batch had introduced — a `--diff`
  that destroyed user files and a stop gate that could be walked past — and they
  were fixed before 1.22.0 was cut. Only fail-open and data-loss problems the
  unreleased batch introduced counted as blockers; everything else went to
  **Not Now**.
  - Installs ship only the 10 user-facing scripts, and `sync-manifest.sh`
    exits 2 instead of reporting success without its library.
  - Doctor fails when the gates aren't wired in `settings.json`; the .NET
    advice no longer points `typecheck` at a single project; s58 and s61 assert
    what they claim; `check-counts.sh` guards the README's scenario numbers.
  - The quality gate fails closed: results are scoped by session, an
    unwritable `.hook-state` blocks, a per-file log replaces the last-run summary
    when python3 is unusable, worktrees the session edited are checked, and the
    check's process group is killed only on timeout (ADR-022).
    Sixteen new scenarios, s81–s96.
  - `--diff` never writes outside its scratch copy (it followed symlinks
    into shared directories), and an upgrade never replaces a file the kit didn't
    install without naming the backup (ADR-023).
- [x] Verification-core batch: verification results and upgrades you can trust.
  One PR per item.
  - PR 0: `--upgrade` updates kit-managed files against a per-file baseline (ADR-017).
  - PR 1a: worktree-aware roots and gate state, a process-group timeout, and multi-step bench scenarios (ADR-018).
  - PR 1b: per-file scoped gate results with passed / failed / timeout / error / skipped statuses (ADR-019).
  - PR 2: C#/.NET checks for `.cs`, `.csproj` and `.sln`, plus a dotnet template.
  - PR 3: `commands.json` schema validation, where an absent key auto-detects and `""` turns a check off; fast per-edit checks are separate from full checks (ADR-020).
  - PR 4: a doctor behavioral self-test. A broken edit blocks, compaction keeps the verdict, a fix unblocks, and worktrees stay isolated.
  - PR 5: `--diff` runs the real upgrade on a scratch copy, so the preview matches what `--upgrade` does. It also flags stale kit files and hook registrations that are missing or point at no script (ADR-021).
- [x] The README's collapsed "Manual install" recipe still copied
  `CODEBASE_MAP.md` and `tasks/` from the repo root, handing out the state that
  two earlier PRs stopped `install.sh` from shipping — on GitHub, on the site's
  Introduction page, and in the LLM docs dump. Now copies from `scaffold/`.

---

## Not Now

Parked scope — deferred work, revisit when prioritized. (CLAUDE.md → Scope Discipline routes out-of-scope items here.)

- **Multi-language test-runner detection** beyond Python/Node/Go/Rust (Ruby, Java, etc.) — the quality gate detects a fixed runner set today. _(deferred from the hook-shift work)_
- **HTTP/MCP-style hook handlers** — advanced handler types beyond the file-command hook model; flagged as out of scope. _(deferred from the hook-shift work)_
- **Cross-tool hook adapter** — port the deterministic hook layer to Cursor/Codex/Devin formats. Tracked separately because hooks don't port cleanly (see the `convert.sh codex` note: discipline survives as AGENTS.md rules, enforcement stays Claude-Code-only). _(deferred from the hook-shift work)_
- **Retro-clean existing installs** that already carry the foreign `tasks/` content from before `install.sh` stopped shipping it. Deliberately not done: that content is user data now, and an upgrade that deleted files under `tasks/` would be the more dangerous behavior.

Deferred by the pre-1.22.0 stopping rule: only fail-open or data-loss problems the
unreleased batch introduced blocked the release. Each of these either behaves the
same way in the released 1.21.x or is a known limit of the new design.

- **The GNU `timeout` fallback doesn't end a signalled check** — used on Linux when python3 isn't usable. The hook still returns on time, because check output goes to a file rather than a pipe. _(hooks review)_
- **`quality-gate-history.json` and `verification-ledger.json` are written without a lock** — concurrent runs can lose a ledger entry. The gate's own state is locked, so stop decisions are unaffected. _(hooks review)_
- **The out-of-project unrecorded marker under `$TMPDIR` is append-only** — filtered when read, cleaned only by the OS. _(hooks review)_
- **With neither `cksum` nor `date -r`, a fallback stamp stays stale and blocks** — fail-closed by design; `SKIP_QUALITY_GATE=1` is the escape. _(hooks review)_
- **Hook runs with no `session_id`** (doctor, manual invocations) **see every record** — fail-closed by design. _(hooks review)_
- **A real `--upgrade` writes through a dangling symlink** at a kit path, which can create a file outside the project (BSD `cp`). The same in 1.21.x; `--diff` warns about it. _(install review)_
- **Baseline entries are never pruned**, so a user's own file at a retired kit path can appear under "the kit no longer ships these". _(install review)_
- **A re-run without `--upgrade` overwrites an edited `.example` file with no backup** — the same in 1.21.x. _(install review)_
- **No `--template generic`**, so an unidentifiable `CLAUDE.md` can't be forced onto the generic template; the message says to merge by hand. _(install fix)_
- **An explicit `--template` after an "unidentified" upgrade** offers `.kit-new` instead of replacing, because the file has no baseline entry. Safe, but it differs from the pre-baseline path. _(install fix)_
- **The hedged "may be your own" list appears only in `--diff`**, because the first upgrade rewrites `.kit-manifest` before printing its summary. _(install review)_
- **One line of the symlink report** claims `--upgrade` writes through a `.kit-new` symlink; `write_kit_new` skips those. _(install review)_

Found while fixing the five v1.22.2 field bugs, outside their scope:

- **Existing installs keep relative hook commands and the `Task`-only matcher**: `--upgrade` never rewrites `.claude/settings.json`, and neither `--diff` nor doctor flags either. The same now applies to protect-files and protect-changes on the `Bash` matcher: existing installs have to register them by hand. _(v1.22.2 field bugs; hook enforcement fixes)_

Found by the final review of the hook hardening (1.22.5), first thing to pick up:

- **Git config exported in an earlier segment**: `export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null; git commit …` — `block-dangerous-commands.sh` only reads inline assignments on the git segment and the hook's own environment. _(hook review)_
- **`source` / `.` / `eval` of a file that changes directory**, then `git add .`: `protect-files.sh` fails closed only for functions and `pushd`/`popd`. _(hook review)_
- **The CI Pipefail Grep Guard only catches `grep -q`**: a pipe into `grep -m1` (or `head`) exits early the same way. `bin/cli.sh skills` hit it intermittently (fixed in the ACK cutover PR); widen the guard in `.github/workflows/validate.yml` (protected). _(ACK cutover CI)_
- **No-parser JSON fallback** (`lib/json-parse.sh`, no python3 and no jq) reads the first matching key at any depth and doesn't reject malformed JSON; `prompt-router` can route on a nested `prompt`. Advisory only. _(hook review)_

Found while fixing the hook enforcement gaps, outside their scope:

- **doctor's placeholder count misses HTML-comment placeholders**, so an untouched `scaffold/CODEBASE_MAP.md` reads "appears filled in"; the dotnet map's `<App>`-style tokens aren't counted either. _(v1.22.2 field bugs)_
