# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### Docs sync after 1.23.0 — task audit, gitignored artifacts

Goal: every doc agrees with the code and with what shipped. `CODEBASE_MAP.md`
lists every skill, script, agent and module on disk (a name-by-name diff against
the tree comes back empty); no task, spec or lesson reports as open or current
something that has shipped or been superseded; `npm run check` and
`scripts/lesson-graph.sh --check` pass.

Audit (2026-09-28): the ACK_ cutover shipped (PR #6, v1.23.0, CI green); the
DFMT spike's follow-up shipped (`/note`, `journal-fold.sh`, the After Compaction
line); the Playbook module and the install proposal are not started, by design;
the Not Now items checked by grep are still open.

- [x] `.gitignore`: ignore `artifacts/` (repo-only; `.gitignore` isn't in the
  npm `files` list or the manifest).
- [x] `tasks/todo.md`: ACK_ cutover closed; Done pruned to what landed since
  1.23.0 (earlier work is in `CHANGELOG.md`); Up Next points at gitignored
  artifacts; the EOTP Not Now item dropped.
- [x] `CODEBASE_MAP.md`: added the 6 skills, 8 scripts + `scripts/lib/manifest.sh`,
  `devils-advocate`, `auto-mode.md`, `html-module/` / `wiki-module/`,
  `ARTIFACTS.md` / `WIKI.md` / `AGENTS.md`, `settings.strict.json`,
  `.claude-plugin/`, `.github/workflows/`, the release docs, `tasks/specs/` and
  `tasks/lessons/_archive/`; fixed the stale claims (root map called a template,
  grep/cut-only JSON parsing, a single gate verdict file, six hook events, After
  Compaction and upgrade flows). `AGENTS.md` regenerated from it.
- [x] `tasks/specs/2026-05-22-dfmt-spike/spec.md`: status → closed, follow-up
  shipped.
- [x] EOTP lesson archived to `tasks/lessons/_archive/` (contradicted ADR-028 and
  `RELEASING.md`); `_index.md` regenerated.
- [x] Verify: the map diff is empty; manifest, scaffold, strict-settings and
  skills checks pass; `AGENTS.md` regeneration is idempotent (the agents-md
  check passes once it's committed with the map); `lesson-graph.sh --check`,
  `validate.sh CODEBASE_MAP.md`, `check-counts.sh` and markdownlint pass.
- [ ] Committed and merged.

Risks: `check-scaffold.sh` requires templates shared with `scaffold/tasks/` to
stay byte-identical — none of the files above is one of them.

---

## Up Next

### Playbook module (decided 2026-09-28 — do not drop)

Adapt the engineering-playbook material reviewed on 2026-09-28 into the kit.
The full item-by-item spec (what to keep, adapt, correct or drop; ~60 factual
errors to fix on the way) is local, gitignored:
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

### Brownfield install (shaped 2026-09-28 — spec in `tasks/specs/`)

The install / upgrade architecture proposal was validated in an office-hours
session and cut to a milestone: the kit works in existing projects — rules
loaded, hooks registered, nothing lost on `init` / `--upgrade` / `uninstall`, no
kit-internal versioned file at the root, plus adoption. Spec, decisions and
references: `tasks/specs/2026-09-28-brownfield-install/`.

Four releases, each starting with a plan approved here: R1 fixes in the current
layout (first: `uninstall` removes the user's own `.claude/` files — N1), R2
`.claude/kit/` + migration, R3 `CLAUDE.md` managed block, R4 adoption. R2–R4
are protected changes and need ADRs. The Playbook's `--playbook` module (its
phase 3) waits for R2, so it's born on `module.conf`.

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

Nothing yet since 1.23.0 — everything earlier is in `CHANGELOG.md`.

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
