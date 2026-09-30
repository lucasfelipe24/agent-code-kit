# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### R2 — kit folder and layout cut (plan approved 2026-09-30; start at PR A)

Spec: `tasks/specs/2026-09-28-brownfield-install/` → R2. Answered 2026-09-30:
Q1 = full layout (ADR-031, accepted), Q2 = python3 (ADR-032, accepted), Q3 =
mirror the installed layout in this repo (ADR-035, accepted), Q4 = defer
`module.conf` (ADR-034, accepted), Q5–Q10 as recommended (Q7 changed: one
release, below). Plan and ADR-033 (migration design, accepted) approved by the
maintainer 2026-09-30, with the recommended agent-collision sub-rules.

#### Goal

Four checks, each a case in `scripts/test-install.sh` or the new
`scripts/test-migrate.sh` that fails on `main` @ `239fd48` and passes on the
release:

- **Criterion 2** — brownfield fixture whose `.claude/settings.json` holds only
  its own permissions, `env` and one hook of its own: after `init </dev/null`,
  every hook of the profile is registered (the kit hook paths named in
  `settings.json` ∪ `settings.local.json` ⊇ the profile's set), the project's
  entries, permissions and `env` are unchanged as JSON and in order, and
  `doctor` passes its wiring checks. The same after `--upgrade`.
- **Criterion 4** — `init` → `--diff` → `--upgrade` → `uninstall --force` on the
  brownfield fixture (plus a user `CLAUDE.project.md`,
  `.claude/hooks/project/x.sh`, a wiki page and a project agent named
  `code-reviewer`) leaves `snap` of the project byte-identical to the snapshot
  taken before `init`, `settings.json` included.
- **Criterion 5** — a v1.23.0 install (greenfield and brownfield), a `main`
  (R1, marked record) install and a pre-baseline install (`.kit-baseline`
  deleted) are migrated: `--diff` names exactly what `--upgrade` then does
  (`same_counts`, moves included); every file rewritten or removed is in
  `.kit-backup/<stamp>/` first; the project's files are byte-identical; the end
  line reads `migrated N · carried E · yours Y · replaced R (backed up) ·
  blocked 0 · failed 0`. Then by hand on the maintainer's 5 projects: `--diff`
  reviewed, `--upgrade`, counts recorded.
- **Criterion 7** — after `init` in an empty git project, the first path component
  of every `git ls-files --others --exclude-standard` entry is in Decision 6's
  closed list; after migrating the fixtures, no `settings*.json` command or
  `statusLine` and no shipped kit file names a legacy kit path
  (`scripts/check-kit-paths.sh`, new, run by CI).

Plus: gates G1–G3 (Claude Code behavior) pass by hand; `npm run check` (clean
worktree), `npm test`, markdownlint and CI on ubuntu and macOS (bash 3.2); this
repo's own `doctor.sh` behavior checks pass after every PR.

#### Context

R1 is merged, not released. Release PR #11 (`1.24.0`) stays open until R2 ships
too — the maintainer cuts one release with everything — so the migrator must
handle v1.23.0 records (unmarked, N1-widened manifests), `main` installs made
through `curl | bash` (marked records) and records deleted by hand. All three
tags (v1.22.4, v1.22.5, v1.23.0) write `.kit-baseline`; a pre-baseline install
exists only synthetically.

Measured on `docs/r2-plan` (= `main` @ `239fd48` outside `tasks/`): 395 tracked
files (`CHANGELOG.md` excluded).

What moves, in projects and in this repo (ADR-031, ADR-035):

| From | To | Files in the kit |
|---|---|---|
| `.kit-manifest`, `.kit-baseline` | `.claude/kit/manifest`, `.claude/kit/baseline` | 2 records (the tracked `.kit-manifest` here becomes `scaffold/kit-manifest.txt`) |
| `VERSION` | `.claude/kit/install.conf` `version=` | 1 (this repo keeps its root `VERSION` for release-please) |
| `agent_docs/*.md` | `.claude/kit/docs/` | 12 |
| `scripts/<10 shipped>` | `.claude/kit/scripts/` | 10 |
| `tasks/lessons/_TEMPLATE.md`, `tasks/handoff.md`, `.claude/*.example` | `.claude/kit/templates/` | 4 |
| `WIKI.md`, `ARTIFACTS.md` | `.claude/kit/modules/{wiki,html}/` | 2 |
| `.claude/agents/*.md` | `.claude/agents/kit/` | 6 + the wiki agent |
| `.claude/hooks/*.sh` + `lib/` | `.claude/kit/hooks/` | 28 + 9 |

References to those paths, by what has to change:

| Where | Files | Lines |
|---|---|---|
| All tracked files | 259 of 395 | 1286 |
| KitBench (`bench/scenarios/` + `bench/README.md`) | 159 — every one of the 158 scenarios | 310 (295 `"hook"` fields) |
| `test-install.sh` + `test-cli.sh` | 2 | 179 |
| `install.sh`, `uninstall.sh`, `bin/` | 3 | 101 |
| 8 `CLAUDE.md` templates | 8 | 117 |
| Skills (core + wiki) | 23 | 68 |
| Kit docs (`agent_docs/`) | 6 | 48 |
| `README.md` + pt-BR | 2 | 20 |
| `tasks/` (history — not rewritten) | 14 | — |

- Hook command sites: `settings.json` 25 commands in 8 events,
  `settings.strict.json` 30 in 9, all `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<n>.sh`;
  each install carries 25 or 30, plus whatever the project put in
  `settings.local.json`. Permissions: 23 allow, 13 deny (never merged).
- Skills and docs citing hook, agent or template paths: 22 files, 89 lines
  (`agent_docs/hooks.md` 33, `CLAUDE.md` 7, each example `CLAUDE.md` 3,
  `CODEBASE_MAP.md` 7, `mcp-audit` 3, `review-pipeline`, `note`,
  `lesson-refresh`, `subagents.md`, `skills.md`, READMEs 2 each). 9 hooks name
  a hook or template path in a message.
- Code that lists agents non-recursively: `convert.sh:46`, `gen-skill-docs.sh:28`,
  `check-counts.sh:48`, `doctor.sh:528-533`, `capabilities/SKILL.md:42`,
  `lib/manifest.sh:101-106`, `install.sh:1652-1670`, `:1843-1854`,
  `uninstall.sh:121`, `:503`, `:919`.
- Hooks find `lib/` through `$(dirname "$0")/lib` (26 of 28), so they move as a
  folder; `skill-compliance.sh:32-35` derives the skills folder from its own
  (breaks), `scripts/note.sh:40-44` sources `.claude/hooks/lib/redact-secrets.sh`,
  `doctor.sh:64,67,270-272,673` hard-code `.claude/hooks/`.
- Only 3 of 37 skills are built from `.tmpl`; the `## Kit Context` block cites no
  moving path. Path edits in skills are hand edits plus a CI residue check.
- This repo reads as a legacy install today (tracked `.kit-manifest`, local
  git-excluded `.kit-baseline` and wiki module). Without a refusal, an
  `--upgrade --local .` here after R2 would migrate its tracked tree.

#### R1 facts this plan builds on

- Ownership block `# >>> ack-ownership` … `# <<< ack-ownership` in
  `scripts/lib/manifest.sh:134-205`, copied byte for byte into
  `uninstall.sh:141-212` and `scripts/doctor.sh:176-247`
  (`test-install.sh:1125-1131` fails on drift). States: `absent`, `kit`,
  `kit-edited`, `unverified`, `unrecorded`, `no-record`; plus
  `ack_record_complete` (ADR-030) and `ack_prior_install`. Every function
  hard-codes `$1/.kit-baseline`.
- `install.sh`: `owner_of` `:571-576`, `install_file` `:598-621`,
  `install_tree` `:676-689`, `upgrade_file` `:848-901`, `backup_file`
  `:777-785`, `replace_file` `:791-809` (writes through links), `baseline_write`
  `:963-997`, the EXIT trap's partial record `:1060-1067`, `run_diff`
  `:346-499` (copy list `:388-429`; `_plan_compare` `:264-295` reports only add /
  update / conflict), F2 warning `:1946-1967`.
- `uninstall.sh` removes by record (`may_remove` `:284-303`, backstop
  `:520-586`) and still removes overlays (`:379-395`), `wiki/` + `raw-sources/`
  (`:465-466`) and `artifacts/` (`:489`) whole after a warning.

#### Decisions

Answered (2026-09-30): Q1 ADR-031 = B (full layout); Q2 ADR-032 = A (python3,
hook entries and strict `ACK_*` env only, never permissions); Q3 ADR-035 = A
(mirror); Q4 ADR-034 = B (defer `module.conf`, reverses shape.md Decision 12);
Q5 `install.conf` (`layout`, `version`, `profile`, `modules`); Q6 rewrite known
kit paths in a kit-written `CLAUDE.md` the user edited, after a backup; Q7 one
release — #11 stays open until R2 ships; Q8 `fetch-depth: 0` for the install
job; Q9 uninstall supports both layouts; Q10 project files calling kit scripts
are reported, never rewritten.

Open:

- **ADR-033** (migration design) — accepted 2026-09-30.
- **Agent name collisions** — ADR-031 records the default the coordinator asked
  for (the project's agent wins; the kit's isn't installed; reported). Confirm
  the two sub-rules: a project file with no `name:` counts by its stem, and a
  collision that appears after install removes the kit's untouched copy on
  `--upgrade` (with a backup).
- **After G3** — if a running session keeps its start-up hooks, confirm the
  two-run removal of legacy hooks (S23).

#### Steps

Seven PRs, in order, each from an up-to-date `main`, squash-only (ADR-002).
Every merge is live for `curl | bash` users, so each PR leaves the kit working on
its own, and the migrator's map grows with each flip PR: an install upgraded
between two of them is migrated for the rows that exist, and the next
`--upgrade` moves the rest (state is per row, ADR-033). Release PR #11 stays open
until PR D4 merges.

| PR | Branch | Steps | Risk | Closes |
|---|---|---|---|---|
| A | `fix/r2-uninstall-keeps-user-data` | S1–S2 | low: uninstall only keeps more | part of 4 |
| B | `feat/r2-settings-merge` | S3–S7 | medium: writes the project's `settings.json` | 2 |
| C | `feat/r2-migrator` | S8–S12 | none at runtime: not wired | tested migrator |
| D1 | `feat/r2-layout-records` | S13–S16 | medium: first wired migration, 3 files | records out of the root |
| D2 | `feat/r2-layout-agents` | S17–S18 | medium: 7 files, name collisions | `.claude/agents/` the project's |
| D3 | `feat/r2-layout-docs-scripts` | S19–S21 | high by size: 60 % of the content edits | 7 |
| D4 | `feat/r2-layout-hooks` | S22–S24 | highest: every hook command, this repo's own gates | `.claude/hooks/` the project's; 5 |

Why this split: the spec's single "layout" PR can't be thinned by type of file,
because in a mirrored repo a category's source move, its installer flip, its
migrator rows and its reference edits must land together (this repo's
`settings.json` and `CLAUDE.md` are the shipped ones). So the flip is cut by
category, smallest and safest first: D1 wires the migrator into the real
installer on 3 bookkeeping files; D2 adds one rule (names) on 7 files; D3 is the
bulk of the text; D4 carries the settings rewrite and the safety hooks last,
behind gates G2–G3. C stays dark, so the migrator is tested on fixtures before
any flip. B can be built in parallel with C.

Gates (by hand, exact commands in `RELEASING.md` from D2 on; results recorded
with `/verification-status`):

- **G1 — agents in a subfolder** (before PR D2 merges). In
  `P=$(mktemp -d)`, `git init`, then write `.claude/agents/kit/ack-probe.md`:
  frontmatter `name: ack-probe`, `description: Probe agent for the kit's layout
  test.`, body `Whatever you are asked, reply with exactly: ACK-PROBE-7431`.
  Run `cd "$P" && claude -p --agent ack-probe "What is your codeword?"` and
  `cd "$P" && claude -p "Use the ack-probe subagent and print exactly what it
  replies."`. Pass: both outputs contain `ACK-PROBE-7431`. Fail: stop D2 and
  re-plan (agents stay flat, ADR-031 amended).
- **G2 — hooks under `.claude/kit/hooks/`** (before PR D4 merges). In a scratch
  git project, install the D4 branch
  (`bash <kit>/install.sh --local <kit> </dev/null`), then
  `claude -p --permission-mode acceptEdits "Create src/app.py whose only line is:
  def broken(:"`. Pass: `.hook-state/last_quality_gate.json` has
  `"status": "failed"` and `.hook-state/` holds the session-start state, i.e.
  PostToolUse and SessionStart ran from `.claude/kit/hooks/`. Then
  `claude -p "Run: git push origin HEAD:main"` in the same project with a
  `main` branch checked out: pass when the transcript shows branch-protect's
  BLOCKED message.
- **G3 — a running session while hooks move** (before PR D4 merges). Install
  v1.23.0 into a scratch project; start `claude` there interactively and make one
  edit; in another terminal run the D4 branch's `install.sh --local <kit>
  --upgrade`; back in the session make another edit and run `/hooks`. Record
  which paths `/hooks` lists and whether the second edit updated
  `.hook-state/quality-gate-state.json`. Outcome A (the session follows the
  rewritten settings): no extra step. Outcome B (it keeps start-up paths): S23's
  two-run removal and restart notice apply.
- Informational (no gate): the same `name` in `.claude/agents/x.md` and
  `.claude/agents/kit/x.md` with different codewords, run 5 times — shows why the
  collision rule never leaves both; a `settings.json` with a `//` line — does
  Claude Code load it? (the merge never writes one either way).

Per-PR gate (every PR, before merge, in a clean `git worktree`):

1. Brownfield round trip on the R1 smoke fixture plus a project
   `.claude/agents/code-reviewer.md` and `.claude/agents/review/code-reviewer.md`
   (both `name: code-reviewer`): `init </dev/null` → `--diff` → `--upgrade` →
   `uninstall --force`, `git status --porcelain` after each; nothing `M` that the
   step doesn't own.
2. Upgrade of a v1.23.0 install AND a pre-baseline install through the PR's code,
   `same_counts` between `--diff` and `--upgrade`, backup listed.
3. This repo: `bash .claude/kit/scripts/doctor.sh` (from D3 on; `scripts/doctor.sh`
   before) passes its behavior checks; the refusal fires on
   `install.sh --local . --upgrade`.
4. `/review-pipeline` + the `devils-advocate` agent; findings fixed or logged
   under Not Now with a reason.
5. `(processed / failed / skipped)` recorded with `/verification-status`.

R1 lessons that bind every step:

- Every removal or overwrite goes through the classifier; never a path list or
  the manifest alone.
- Back up before any rewrite or removal (one stamp per run); new files as temp +
  `mv`.
- Report `processed / failed / skipped` with reasons.
- `--diff` must equal `--upgrade`: whatever a decision reads must be in the
  scratch copy (`install.sh:388-429`); what's read outside it (Q10's `git grep`)
  is read-only and printed by both.
- bash 3.2: no associative arrays, `mapfile`, `${x,,}`; empty arrays as
  `${a[@]+"${a[@]}"}` under `set -u`. Under `pipefail` an early-exiting reader
  (`grep -q`, `grep -m1`, `head`) fails the pipeline — capture whole output or
  use a herestring. CI's Pipefail Grep Guard (`validate.yml:207-237`) rejects
  `| grep -q` in any `pipefail` script.
- Prove red: every fails-first case runs against `main`'s scripts in a scratch
  dir.

##### S0 — Baseline (no commit)

- Cut each branch from `main`. In a clean worktree run `npm run check`,
  `npm test`, markdownlint; record the counts with `/verification-status`.

##### S1 — Uninstall keeps the project's overlays (PR A)

- Files: `uninstall.sh:379-395`, `:754-759`, `--help` `:70`; `bin/cli.sh:43`;
  `scripts/test-install.sh`; `README.md` + `README.pt-BR.md` uninstall section.
- Change: `CLAUDE.project.md` goes only when byte-identical to the kit's copy
  (`same_as_kit`, `:223-225`; without the kit tree it stays).
  `agent_docs/project/` and `.claude/hooks/project/` go only when empty.
  `--keep-project` stays accepted, now a no-op.
- Fails first (red on `main`): an edited `CLAUDE.project.md`,
  `.claude/hooks/project/x.sh` and `agent_docs/project/mission.md` survive
  `uninstall --force` byte-identical; the pristine template goes.
- Verify: `bash scripts/test-install.sh && bash scripts/test-cli.sh`.
- Rollback: revert.

##### S2 — Uninstall keeps module data (PR A)

- Files: `uninstall.sh:433-491`, `:604-620`, `:741-752`; tests.
- Change: `wiki/` and `raw-sources/` are never removed whole: `wiki/index.md` /
  `wiki/log.md` go only while byte-identical to what `create_wiki_index` /
  `create_wiki_log` write (`install.sh:66-88`; uninstall carries the two
  strings), then empty dirs bottom-up. `artifacts/index.html` and
  `design-system.html` go only while identical to `html-module/templates/`.
  Everything else stays and is listed.
- Fails first (red on `main`, which runs `rm -rf`): a wiki page, a raw source and
  an artifact survive; untouched seeds go.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.
- PR A gate.

##### S3 — Settings engine: merge, strip, rewrite (PR B)

- Files: new block `# >>> ack-settings` … `# <<< ack-settings` (python3 heredoc
  function `ack_settings`) in `install.sh` after `kit_attention_report`
  (`:127-208`), copied byte for byte into `uninstall.sh`; `test-install.sh`
  (byte-identity check, as `:1125-1131`).
- Change: bash supplies facts, python applies policy:
  `ack_settings <mode> <file> <kit_settings> <kit_hooks> <records>`, where
  `<kit_hooks>` lists the hook paths the classifier calls the kit's. Modes:
  - `plan` — TSV, writes nothing.
  - `merge` — per kit hook of the profile: absent from `settings.json` and
    `settings.local.json` → a new group with the kit's matcher, appended to the
    event; equal to its `#hook` record → the kit's current entry; different →
    kept, "edited"; no record → kept, recorded only if equal to the kit's; stale
    and equal to its record → removed. Strict `ACK_*` `env` keys added only
    when absent.
  - `strip` — remove exactly the kit's entries.
  - `rewrite <old>=<new>…` — in the kit's entries only (command names a path in
    `<kit_hooks>`), replace the path, keep every other field; a `statusLine`
    command naming the kit's `scripts/statusline.sh` likewise. Entries under
    `.claude/hooks/project/`, or naming a file the record calls the project's,
    are never touched.
  Never touched: other entries, key order, `permissions`, other keys. Output keeps
  indent (2, 4 or tab, detected), non-ASCII and the final newline; no change → no
  write; a symlinked file is written through; not strict JSON → no write, `plan`
  says `manual`.
- Record: `#hook<TAB><event><TAB><path><TAB><sha256 of canonical {matcher, hook}>`
  header lines, regenerated by `baseline_write` (`:973-986`).
- Fails first (the function doesn't exist on `main`): golden cases — empty hooks;
  an own hook in the same event; a kit hook registered only in
  `settings.local.json` (not added); an edited kit entry (merge keeps it; rewrite
  changes only its path); a stale kit entry; a project hook named like a kit hook
  and one under `hooks/project/` (untouched by every mode); a relative legacy
  command `.claude/hooks/x.sh` (rewritten in place); `statusLine`
  `./scripts/statusline.sh` (rewritten only when the script is the kit's);
  4-space and tab indent round trip; a JSONC comment (no write, `manual`); a
  symlinked file; `rewrite` run twice (second run writes nothing); `strip` of a
  `merge` equal to the input bytes.
- Verify: `bash scripts/test-install.sh`. Rollback: revert (nothing calls it).

##### S4 — `init` merges into a project's `settings.json` (PR B)

- Files: `install.sh:1738-1763`, `:1957-1967` (the R1 warning becomes the
  no-python3 path), `:1997-2013`; tests; README `:420` area.
- Change: `settings.json` present and not the kit's → `backup_file`, `merge`,
  report `registered N kit hooks · kept M of yours`. The file stays unrecorded;
  only `#hook` lines are recorded. Without a usable python3
  (`.claude/hooks/lib/python3.sh`'s probe): the R1 warning, exit 0, doctor
  fails.
- Fails first (red on `main`): the criterion-2 check; under the PATH shim
  (`test-install.sh:950-970` pattern, without python3) the warning is still
  printed; a greenfield install is unchanged.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S5 — `--upgrade` and `--diff` keep registrations current (PR B)

- Files: `install.sh:1758-1759`, `run_diff` copy list `:409`
  (+ `settings.local.json`), `:496`, `print_attention` `:214-258`; tests
  `:418-476`.
- Change: `--upgrade` runs `merge` on a kit-edited or unrecorded `settings.json`
  (an untouched kit file keeps whole-file `upgrade_file`). `--diff` shows the
  per-entry plan from the scratch run.
- Fails first (red on `main`): a v1.23.0 brownfield install gains the missing
  hooks on `--upgrade`, named first by `--diff` (`same_counts`); an edited kit
  entry is kept and reported.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S6 — Uninstall strips the kit's entries (PR B)

- Files: `uninstall.sh:507-509`, `:698-704`, `:731-738`, `:870-877`; tests.
- Change: a `settings.json` that isn't the kit's loses exactly the entries whose
  hook this run removes (`strip`), after a backup; without python3 the R1
  warning stays and names the entries.
- Fails first (red on `main`): the criterion-4 round trip with a merged 2-space
  `settings.json` is byte-identical after uninstall.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S7 — Doctor and docs (PR B)

- Files: `scripts/doctor.sh:427-453` ("run install.sh --upgrade to register
  them"); `agent_docs/hooks.md`; `README.md` + pt-BR `:374-382`;
  `CODEBASE_MAP.md:299-302`; ADR-021 and ADR-017 amendment notes.
- Verify: `bash scripts/test-install.sh`, markdownlint. Rollback: revert.
- PR B gate.

##### S8 — The record can live in either layout (PR C)

- Files: ownership block `scripts/lib/manifest.sh:134-205`, re-copied into
  `uninstall.sh` and `doctor.sh`; tests `:1121-1196`.
- Change: `ack_record_file <dest>` → `.claude/kit/baseline` if present, else
  `.kit-baseline`; `ack_record_hash` looks in the new record first, then the
  legacy one. `ack_layout <dest> <map>` → `none` · `legacy` · `partial` (any
  legacy map row still on disk beside a new record) · `2`. `ack_prior_install`
  also accepts `.claude/kit/manifest`. New `ack_agent_name <file>` (frontmatter
  `name:`, CR and quotes stripped, else the stem) — in the block because install,
  uninstall and doctor all need it.
- Fails first: each layout state on crafted trees; names from quoted, CRLF and
  missing `name:` files; every R1 classifier case stays green unchanged.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S9 — Path map (PR C)

- Files: new `scripts/lib/layout.sh` (sourced by `install.sh` only; joins
  `package.json` `files` in D1); tests.
- Change: `ack_layout_map <kit_dir> [category…]` prints `category<TAB>legacy<TAB>new`
  rows, derived from the kit tree, never hand-listed: `records`, `version`
  (`VERSION` → `install.conf`), `agents` (each kit agent, wiki's included),
  `docs` (`agent_docs/<f>.md`, never `project/`), `scripts` (each
  `KIT_USER_SCRIPTS` entry), `templates` (4), `modules` (2 schemas), `hooks`
  (each `*.sh` and `lib/*.sh`). The installer passes only the categories its
  release has flipped, so the map grows PR by PR (D1 → D4).
- Fails first: the full map lists every file a fresh v1.23.0 standard `--wiki
  --html` install put under a moving path (premise check, as R1 S1), and nothing
  else.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S10 — Fixtures (PR C)

- Files: new `scripts/test-migrate.sh` (helpers as `test-install.sh:620-626`,
  `:737-755`); `package.json` `scripts` (`test:migrate`, in `npm test`) and
  `.github/workflows/validate.yml:119` `fetch-depth: 0` (both protected, Q8).
- Change: fixtures built per run:
  - (a) v1.23.0 standard, greenfield, from `git worktree add <tmp> v1.23.0`;
    (b) v1.23.0 on the brownfield fixture (N1-widened manifest); (c) (a) and (b)
    with `.kit-baseline` deleted; (d) a `main` install (marked record); (e) wiki +
    html modules; (f) an edited kit doc, script, hook and agent;
  - (g) the project's own `scripts/validate.sh` under a marked record;
  - (h) agents: a project `.claude/agents/code-reviewer.md` (`name:
    code-reviewer`), and separately one at `.claude/agents/review/code-reviewer.md`,
    and one with no `name:` whose stem is `planner`;
  - (i) settings: kit entries edited (matcher, timeout), a project hook named
    `secret-scan.sh` the record calls the project's, a `hooks/project/` entry,
    kit hooks registered in `settings.local.json`, a `statusLine` on
    `./scripts/statusline.sh`, a `settings.json` with a `//` comment;
  - (j) a copy of this repo's tracked tree (`git archive HEAD`).
  No tag → "skipped (no v1.23.0 tag)", counted, never passed.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S11 — Planner (PR C)

- Files: `scripts/lib/layout.sh`; `scripts/test-migrate.sh`.
- Change: `ack_migration_plan <dest> <kit_dir> <categories>` — reads only —
  one row per map row: `move`, `carry`, `replace`, `yours`, `done`, `resume`,
  `blocked <reason>`, `refuse <reason>` (ADR-033). Rules beyond the classifier:
  - templates move only while byte-identical to a kit copy (never recorded
    before R1); otherwise `yours`;
  - agents: a kit agent whose `ack_agent_name` a non-kit file under
    `.claude/agents/` (any depth) already declares → `yours` ("the kit's version
    isn't installed"), and its legacy kit copy, if any, is backed up and removed
    rather than moved — never both;
  - hooks rows are `blocked` when python3 is unusable or either settings file
    fails `ack_settings plan` (not strict JSON) — the legacy hooks stay;
  - `refuse` for a kit source tree (`install.sh`, `uninstall.sh`,
    `scaffold/tasks/todo.md`, `bench/scenarios/` all present, or the target is
    the source) and for a layout newer than the running kit.
- Fails first: exact expected rows for fixtures (a)–(j); (h) → `yours` for
  `code-reviewer` and `planner`; (i) comment file → hooks `blocked`; (j) →
  `refuse`.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S12 — Executor (PR C)

- Files: `scripts/lib/layout.sh`; `scripts/test-migrate.sh`.
- Change: `ack_migrate_apply` runs the plan in phases, each safe to repeat:
  1. back up every origin, both records, `VERSION` (if the kit's), both settings
     files and `.gitignore` into one `.kit-backup/<stamp>/`; a failed copy stops
     before anything moves;
  2. copy each `move` / `carry` / `replace` (temp + `mv`), verify its sha;
  3. write the new records (carried hashes; mark per ADR-030) and `install.conf`;
  4. rewrite executable references with S3's `rewrite` (hook commands in both
     settings files, `statusLine`) and the `--gitignore` block
     (`install.sh:1900-1941` format);
  5. remove each verified origin, then empty legacy dirs, then the legacy records.
  Report: `migrated N · carried E · yours Y · replaced R (backed up) · blocked K ·
  failed F`.
- Fails first: for each fixture, the final tree equals the expected one; a run
  cut after each phase (a destination made unwritable, then restored) and re-run
  equals an uncut run (`snap`); project files byte-identical; every removed or
  rewritten file is in the backup; a second run on a migrated tree writes nothing.
- Verify: `bash scripts/test-migrate.sh && bash scripts/test-install.sh`.
- Rollback: revert (nothing calls it).
- PR C gate — `devils-advocate` on S11–S12 first.

##### S13 — This repo stops looking like an install (PR D1)

- Files: `git mv .kit-manifest scaffold/kit-manifest.txt`;
  `scripts/sync-manifest.sh`, `lib/manifest.sh` `MANIFEST_FILE` users,
  `validate.yml:148-151`, `CODEBASE_MAP.md`; the refusal (S11's test) in
  `install.sh` (before any mode, including `--diff`), `uninstall.sh` (before
  detection); `.git/info/exclude` note for the maintainer: delete the local
  `.kit-baseline` after this PR merges.
- Fails first: fixture (j) through `install.sh`, `--upgrade`, `--diff` and
  `uninstall.sh` → each exits non-zero with the refusal and writes nothing
  (`snap`).
- Verify: `npm run check`, `bash scripts/test-install.sh`. Rollback: revert.

##### S14 — Records and version under `.claude/kit/` (PR D1)

- Files: `install.sh:26,31`, `:1308-1311`, `:1415-1427` (the project's `VERSION`
  is never read or written again), `:1894-1897`, `:1916-1938` (`--gitignore`:
  `.claude/kit/` for these entries); `package.json` `files`
  (+ `scripts/lib/layout.sh`, protected); tests.
- Change: fresh installs write `.claude/kit/{manifest,baseline,install.conf}`;
  `--upgrade` runs `ack_migrate_apply` for `records version` after the layout
  check (`:1390-1391`); guards: a `--version` older than this release over a
  layout-2 or partial install → refuse; no hash tool → stop.
- Fails first (red on `main`): no `VERSION`, `.kit-manifest`, `.kit-baseline` at
  the root after `init`; fixtures (a)–(d) migrated for these rows with
  `same_counts`.
- Verify: `bash scripts/test-install.sh && bash scripts/test-migrate.sh`.
- Rollback: revert; installs migrated meanwhile keep their records under
  `.claude/kit/` (a reverted installer reads them as no prior install — Risks).

##### S15 — `--diff` previews moves (PR D1)

- Files: `run_diff` `:388-429` (copy `.claude/kit`, `.claude/agents/kit`,
  `settings.local.json`, `.gitignore`), `_plan_compare` `:264-295` (`move` and
  `remove` rows; bookkeeping `:269` gains the new records),
  `print_upgrade_summary` `:1029-1058` (`· N moved` appended, fields kept for
  `upgrade_counts`, `test-install.sh:753`), the Q10 report; tests.
- Fails first: `same_counts` with moves on fixtures (a)–(d).
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S16 — Uninstall, doctor, CLI, session-start in both layouts (PR D1)

- Files: `uninstall.sh:100-113`, `:348-366`; `scripts/doctor.sh:155-159` and a
  layout check (`legacy` / `partial` → fail "run install.sh --upgrade (--diff
  first)"); `bin/cli.sh:132-135` (version from `install.conf` in a project);
  `.claude/hooks/session-start.sh` (one line when `partial`: two `[ -f ]`
  tests); new bench scenario, `check-counts.sh:30` (158 → 159); tests.
- Fails first: criterion 4 on a layout-2 install and on a v1.23.0 install (Q9);
  doctor fails on (a) and on a half-migrated tree, passes after `--upgrade`.
- Verify: `npm test`. Rollback: revert.
- PR D1 gate.

##### S17 — Agents move in this repo and the tooling that lists them (PR D2, after G1)

- Files: `git mv .claude/agents/*.md .claude/agents/kit/`,
  `wiki-module/.claude/agents/wiki-maintainer.md` stays (payload);
  recursive listing in `convert.sh:46`, `gen-skill-docs.sh:28`,
  `check-counts.sh:48`, `doctor.sh:528-533`, `capabilities/SKILL.md:42`,
  `lib/manifest.sh:101-106`; `package.json` `files` `:41`; docs
  (`subagents.md:131`, `CODEBASE_MAP.md`, READMEs); `RELEASING.md` (G1).
- Fails first: `check-counts.sh` counts 6 agents under `.claude/agents/kit/`;
  `convert.sh` exports the same 6.
- Verify: `npm run check`, `bash scripts/test-cli.sh`. Rollback: revert.

##### S18 — Installer places agents by name (PR D2)

- Files: `install.sh:1652-1670`, `:1843-1854`; `uninstall.sh:121`, `:503`,
  `:919`; doctor's duplicate-name check; the map's `agents` category passed to
  the migrator; tests (`:826-833`, `:1272-1316` brownfield cases move to the new
  path).
- Change: before placing a kit agent, collect `ack_agent_name` of every non-kit
  `.md` under `.claude/agents/`; a taken name → not installed, not recorded,
  reported "yours — the kit's version isn't installed". `--upgrade`: a collision
  that appeared after install → the kit's copy, if `kit`, is backed up and
  removed; if `kit-edited`, kept and reported. Doctor fails on any `name`
  declared twice under `.claude/agents/`.
- Fails first: fixtures (h) — `init`, `--upgrade`, `--diff` and migration never
  leave two files with one name; the kit's other agents are under `kit/`; doctor
  fails on a hand-made duplicate.
- Verify: `bash scripts/test-install.sh && bash scripts/test-migrate.sh`.
- Rollback: revert.
- PR D2 gate, G1 recorded.

##### S19 — Docs, scripts, templates and module schemas move in this repo (PR D3)

- Files: one commit: `git mv` of `agent_docs/*.md` (12) →
  `.claude/kit/docs/`, the 10 shipped scripts → `.claude/kit/scripts/`, the 4
  templates → `.claude/kit/templates/` (`lesson.md`, `handoff.md`,
  `commands.json.example`, `mcp-allowlist.txt.example`; this repo's
  `tasks/lessons/_TEMPLATE.md` and `tasks/handoff.md` deleted), `WIKI.md` /
  `ARTIFACTS.md` → `.claude/kit/modules/…`; with it `package.json` `files`
  `:40,:50-60,:66-67`, `validate.yml:109,124,139` chmod lines,
  `check-scaffold.sh:61-66`, `gen-agents-md.sh:169`, `sync-manifest.sh`,
  `test-install.sh` / `test-cli.sh` paths, bench s17, s18, s49, s50, and this
  repo's own `CLAUDE.md` (it is the template: S21).
- Fails first: `npm run check` + `npm test` on the moved tree; every path the
  generic `CLAUDE.md` cites resolves here (new check in `sync-manifest.sh
  --check`).
- Verify: `npm run check && npm test`. Rollback: revert.

##### S20 — Installer and migrator for those categories (PR D3)

- Files: `install.sh:1433-1505`, `:1507-1537` (no templates seeded into
  `tasks/`), `:1547-1592`, `:1765-1784` (`.example` → templates), `:1787-1873`
  (schemas), `:1997-2031`; `bin/cli.sh:64-122` (run `.claude/kit/scripts/…`; a
  legacy install gets the upgrade message); `uninstall.sh:121`, `:270-276`,
  `:919-923`; doctor `:165`, `:286-295`, `:540-541`, `:595-661`; tests.
- Change: the map gains `docs scripts templates modules`; the migrator's phase 4
  rewrites a `statusLine` on the kit's `scripts/statusline.sh`; a kit-written
  `CLAUDE.md` the user edited gets the literal map after a backup (Q6); Q10
  report; `agent_docs/project/` no longer created.
- Fails first (red on `main`): the criterion-7 check; the R1 round trip on the
  new layout; criterion 5 for these rows on (a)–(g).
- Verify: `bash scripts/test-install.sh && bash scripts/test-migrate.sh &&
  bash scripts/test-cli.sh`. Rollback: revert.

##### S21 — Content paths and the residue check (PR D3)

- Files: 8 `CLAUDE.md` templates (117 lines), 23 skill files (68 lines, 3
  `agent_docs/project/` lines kept), 6 kit docs (48), relative links in
  `deepening-review/references/*.md`, hook messages (`bash-budget.sh:147`,
  `read-budget.sh:102`, `lib/redact-secrets.sh:8`), `.claude/extensions/README.md`,
  `scaffold/tasks/`; READMEs (20 lines), `CODEBASE_MAP.md`, `AGENTS.md`
  (regenerated), `CONTRIBUTING.md`; new `scripts/check-kit-paths.sh`, run by
  `sync-manifest.sh --check`.
- Change: one scripted rewrite by the map, then hand review; the check fails on a
  legacy kit path in any shipped file, with an allowlist (`agent_docs/project/`,
  the project's `VERSION` in `ship`, the migrator's map, `CHANGELOG.md`,
  `tasks/`).
- Fails first: the check fails on `main`'s tree and passes after the rewrite.
- Verify: `npm run check`, `bash scripts/validate-skills.sh`, markdownlint.
  Rollback: revert.
- PR D3 gate — criterion 7 closes here.

##### S22 — Hooks move in this repo (PR D4)

- Files: one commit, made from a terminal with no Claude Code session open in
  this repo: `git mv .claude/hooks/*.sh .claude/hooks/lib .claude/kit/hooks/`
  (`.claude/hooks/project/` stays); `.claude/settings.json` (25 commands),
  `scripts/gen-strict-settings.sh` → `settings.strict.json` (30); all 158
  scenarios (`"hook"` fields and setup paths: 310 lines by `sed`, s44 included);
  `bench/README.md`; `validate.yml:109,124,139`; `package.json` `files`
  `:43`; `skill-compliance.sh:32-35` (skills from `$CLAUDE_PROJECT_DIR` or
  `${SCRIPT_DIR%/kit/hooks}/skills`); `scripts/note.sh:44`
  (`.claude/kit/scripts/note.sh` after D3); the 4 hooks' BLOCKED messages and
  the other 5 hooks' path mentions; `test-install.sh` / `test-cli.sh` paths;
  docs (`agent_docs/hooks.md` 33 lines, `CODEBASE_MAP.md`, READMEs, skills
  `mcp-audit`, `note`, `lesson-refresh`, `scorecard`, `doc-gardening`,
  `capabilities`).
- Fails first: `npm run bench` 159/159 on the moved tree; doctor's behavior
  checks pass on this repo; `gen-strict-settings.sh --check`.
- Verify: `npm run check && npm test`; open a new Claude Code session here and
  make one edit — the quality gate records it.
- Rollback: revert (then restart sessions here).

##### S23 — Installer and migrator for hooks (PR D4, after G2 and G3)

- Files: `install.sh:1398-1411` (lib pre-flight on the new path), `:1597-1646`,
  `:1946-1955`, `kit_attention_report` `:133,159`, `_kit_symlinks` `:311`;
  `uninstall.sh:121`, `:495-504`, `:919`; doctor `:64,67`, `:270-272`,
  `:326-343`, `:407-456`, `:673`; tests.
- Change: the map gains `hooks`; phase 4 runs S3's `rewrite` on `settings.json`
  and `settings.local.json`; blocked rows keep the legacy hooks registered and
  make doctor fail with the reason. G3 outcome B: phase 5 leaves legacy hook
  files in place while `.hook-state/` shows a session started after the backup
  stamp, and says "restart Claude Code sessions in this project, then run
  --upgrade again"; the next run removes them.
- Fails first (red on `main`): fixtures (a)–(i) end with every kit command under
  `.claude/kit/hooks/` in both settings files, project entries byte-equal, edited
  kit entries keeping their edits, a second run writing nothing; the JSONC
  fixture `blocked` with hooks still at `.claude/hooks/` and registered.
- Verify: `bash scripts/test-migrate.sh && bash scripts/test-install.sh &&
  npm run bench`. Rollback: revert.

##### S24 — Release notes and the maintainer run (PR D4)

- Files: `README.md` + pt-BR, `RELEASING.md` (G1–G3 as release smokes, plus R3's
  D2 later), ADR-033 status; amendment notes on ADR-017, ADR-021, ADR-023.
- Change: the hard cut stated — `--diff`, then `--upgrade`; legacy doctor and
  scripts refused afterwards; restore from `.kit-backup/<stamp>/`.
- PR D4 gate; G2, G3 recorded; then `--diff` + `--upgrade` on the maintainer's
  5 projects, counts recorded; then the maintainer releases (#11 → R1 + R2).

#### Size

7 PRs, 24 steps plus S0 and 3 manual gates. PR D3 and D4 are each larger than
all of R1: D3 moves 28 files and edits the 8 templates, 23 skills, 6 docs and
both READMEs; D4 moves 37 files and edits all 158 bench scenarios, both settings
files and ~25 other files. In total about 259 tracked files change (1286 lines
name a moved path), plus the new migrator, merge engine and two test suites.

#### Protected changes and repo obligations

- ADR-031, ADR-032, ADR-033, ADR-034, ADR-035 accepted.
  `package.json` (`files`, `scripts`) and `.github/workflows/validate.yml` trip
  `protect-changes.sh`: `CLAUDE_APPROVED=1` after the ADR.
- `sync-manifest.sh --check`, `check-scaffold.sh`, `check-counts.sh` (159 from
  D1), `gen-agents-md.sh` + `check:agents-md`, `gen-strict-settings.sh --check`,
  `validate-skills.sh`, `check-prefix-residue.sh`, `check-kit-paths.sh` pass in a
  clean worktree (the local wiki module drifts them here — don't fix it).

#### Dependencies

- No new packages: bash 3.2, awk, a sha256 tool, git; python3 for merge,
  rewrite and `--diff`, as today.
- PR C before D1; D1 before D2–D4; G1 before D2 merges;
  G2 and G3 before D4 merges. B in parallel with C.

#### Risks

- **Migrator misclassification — highest for users.** A wrong `move` takes a
  project file away from where its tools expect it. Mitigation: facts from the R1
  classifier only; backup first; `--diff` first; fixtures (a)–(j) in CI;
  `devils-advocate` on S11–S12.
- **The hooks move in this repo — highest for the maintainer.** D4 rewrites the
  paths of the safety hooks this repo develops under; a missed reference is a
  hook "not found", a non-blocking error, so gates go quiet. Mitigation: the move
  in one commit outside a session, doctor's behavior checks and a fresh-session
  edit in the D4 gate, G2.
- **Settings rewrite on projects.** Every kit hook command in two files changes;
  a running session may keep old paths (G3). Mitigation: owner-based rewrite,
  backup, idempotent, `blocked` instead of a guess, the two-run removal if G3
  says so.
- **Agent name collisions.** Two files with one `name` load unpredictably.
  Mitigation: the project's wins, the kit's is never installed beside it, doctor
  fails on duplicates.
- **Size.** 259 files over 4 flip PRs; review fatigue is the practical risk.
  Mitigation: scripted rewrites (reviewable as one `sed` + map), residue check,
  per-category PRs.
- **Hard cut outside the maintainer's control.** Legacy scripts, a project's CI
  calling `./scripts/validate.sh`, a `statusLine` in user-level settings.
  Mitigation: rewrite what the kit owns, report the rest, doctor/CLI messages,
  release notes.
- **Revert after a flip PR** can't un-migrate installs. Mitigation: forward-fix;
  backups; #11 held until D4's gate.
- **Settings formatting.** Byte identity only for formats the writer reproduces;
  others are reported as reformatted.

#### Failure Modes

- Planner, a CRLF record → misses → `yours` → nothing moves. Mitigation: `\r`
  stripped (R1); a CRLF fixture.
- Executor, disk full between phases 2 and 5 → both copies exist. Mitigation:
  `partial`, doctor and session-start say "resume"; a re-run finishes.
- Executor, the user edits a moved file between a cut run and the re-run.
  Mitigation: `resume` verifies against the origin; a mismatch is `failed`,
  listed, origin kept.
- Rewrite, `settings.json` is a symlink into a dotfiles repo → written through,
  named in `--diff` (`_kit_symlinks`).
- Rewrite, the project runs a kit hook through a wrapper
  (`bash -c '… .claude/hooks/secret-scan.sh'`) → the path inside is rewritten
  when the file is the kit's; any other shape is reported by `plan`.
- Agents, a project adds `code-reviewer.md` after install → `--upgrade` removes
  the kit's untouched copy with a backup; doctor fails until then.
- Uninstall strip without python3 → kit entries point at removed hooks.
  Mitigation: the R1 warning names each.
- `--diff` over a partial layout → the scratch copy includes both layouts' paths
  from the map; a partial fixture in `same_counts`.
- This repo, a session open during S22's commit → its hooks vanish mid-session.
  Mitigation: the step says to close sessions first; a new session after.

#### Verification

Per step: its fails-first case is red against `main`'s scripts and green on the
branch. Release gate after D4, in a clean worktree of `main`:

1. Typecheck — n/a; `bash -n` on every touched `.sh`; the python heredocs parsed
   in the tests.
2. Lint — `npm run check`; `npx --yes markdownlint-cli2 "**/*.md" "#node_modules"`.
3. Tests — `npm test` (KitBench 159, `test-install.sh`, `test-migrate.sh`,
   `test-cli.sh`); CI green on ubuntu and macOS.
4. Smoke — G1–G3; the R1 fixture in a fresh `git init` project, no TTY: `init` →
   `git status --porcelain` shows only `??` entries in the closed list; doctor
   passes; `--diff` / `--upgrade` / `uninstall --force` → clean. A v1.23.0
   install upgraded through `bin/cli.sh init --upgrade`.
5. Silent failures, recorded with `/verification-status`:

| Item | Processed | Failed | Skipped (reason) |
|---|---|---|---|
| Fixtures (a)–(j) migrated, `same_counts` held | | | |
| Kit hooks registered vs the profile's set (criterion 2) | | | |
| Kit hook commands rewritten vs found, both settings files | | | |
| Agent collisions reported vs planted | | | |
| Project files byte-identical after each stage | | | |
| Shipped files free of legacy kit paths (`check-kit-paths.sh`) | | | |
| Maintainer's 5 projects: `--diff` reviewed, upgraded | | | |

#### Could not verify (gated or informational)

- Agents in a subfolder — documented (sub-agents docs, fetched 2026-09-30:
  recursive scan, identity from `name`, duplicates load one by filesystem order),
  not run: gate G1.
- Hooks run from `$CLAUDE_PROJECT_DIR/.claude/kit/hooks/` — documented as shell
  commands with that variable expanded, not run: gate G2.
- A running session while settings are rewritten — not documented as far as
  checked, not run: gate G3.
- Claude Code accepting comments or trailing commas in `settings.json` —
  unknown; the merge and rewrite never write such a file. Informational smoke.
- The same handler in both settings files runs once — documented (hooks docs),
  not run.
- Hook order inside an event — the merge appends groups; no kit hook is assumed to
  depend on order; not checked against the docs.

#### Spec vs code

- R2.7 (skill paths through a generated Kit Context block): the block cites no
  moving path and `build-skills.sh` builds 3 of 37 skills — replaced by a scripted
  rewrite plus `check-kit-paths.sh`.
- R2.6 (doctor refuses a legacy layout): a legacy install runs its own old doctor
  and hooks; only the new doctor (after migration, or via `npx … doctor`) can.
- R2.4 (node → python3): settled as python3 only (ADR-032).
- R2.3 ("~7 hard-coded sites"): 8 code files plus `package.json` and
  `CLAUDE.md`; `module.conf` deferred (ADR-034).
- Spec risk sizes are stale: `install.sh` 2032 lines (spec: 1718),
  `test-install.sh` 1490 (948), 158 bench scenarios (136).
- Decision 6 lists `CLAUDE.project.md` as "legacy", but D7 is deferred, so fresh
  installs still create it; the criterion-7 check allows it.
- `--diff --version <tag>` runs the tag's installer on the scratch copy while
  `--upgrade --version <tag>` runs the current one with the tag's tree
  (`install.sh:439` vs `:1280-1305`) — true today; S14 refuses downgrades across
  the cut.
- Mirroring moves this repo's `VERSION`? No: release-please bumps it
  (`release-please-config.json` extra-file); it stays as the repo's own and the
  installer reads it as the kit's version.

#### Not Now

- `module.conf` + `CONTRACT.md` — first step of the Playbook module (ADR-034).
- Installing modules into this repo with `install.sh` (the refusal covers it);
  the maintainer's local wiki stays as it is.
- Moving `.hook-state/`, `DESIGN.md` timing, `CLAUDE.project.md` on new installs
  (D7) — out of the milestone.
- A configurable `tasks/` path; `npx … doctor` running the package's doctor;
  widening the Pipefail Grep Guard to `grep -m1` / `head`.

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
- [x] Committed and merged.

Risks: `check-scaffold.sh` requires templates shared with `scaffold/tasks/` to
stay byte-identical — none of the files above is one of them.

---

## Up Next

### Docs site — Fumadocs on GitHub Pages (shaped 2026-09-30; implemented, PR open)

Spec: `tasks/specs/2026-09-30-docs-site/` (plan, decisions, references).
ADR-036 accepted. Worktree `.claude/worktrees/docs-site`, branch
`worktree-docs-site`.

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
layout (shipped to `main` — see Done), R2 `.claude/kit/` + migration (planned,
ADR-031 to ADR-035 accepted — see In Progress), R3 `CLAUDE.md`
managed block, R4 adoption. R2–R4 are protected changes and need ADRs. The
Playbook's `--playbook` module (its phase 3) waits for R2 and starts with
`module.conf` (ADR-034).

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

### R1 — brownfield fixes (shipped to `main` 2026-09-30; release PR #11 open)

Merged as PR #10 (`fix/r1-uninstall-ownership`), PR #12
(`feat/r1-install-per-file`) and PR #13 (`fix/r1-brownfield-surface`); ships as
`1.24.0` when release PR #11 merges. Closed N1, F1, F2, F4, F5, F6, F7, F9, F12,
G1, G2, each with a regression case in `scripts/test-install.sh`, plus KitBench
s163. Facts later releases build on:

- Ownership is the install record, never the manifest: `ack_owner <dest> <rel>`
  (`absent` · `kit` · `kit-edited` · `unverified` · `unrecorded` · `no-record`),
  `ack_record_complete`, `ack_prior_install`, in `scripts/lib/manifest.sh` between
  `# >>> ack-ownership` markers, copied byte for byte into `uninstall.sh` and
  `scripts/doctor.sh` (a test fails on drift).
- ADR-030: an unrecorded file is the project's only under a record marked
  `#complete`; otherwise ADR-023 A (back up, replace). `install.sh` applies it
  through `owner_of`, `install_file`, `install_tree` and `upgrade_file`.
- `VERSION` is the kit's only when recorded (or a pre-R1 kit line listed by the
  old manifest); a project's own is never written, and the kit version reads
  "unknown" there until R2.
- An existing `settings.json` that isn't the kit's gets a loud warning at `init`
  and a doctor failure (R1 Q4 = B) until R2 merges it.
- The session audit log lives in `.hook-state/`; `--upgrade` moves an old
  `reports/` log.
- Deferred to R2: uninstall still removes overlays and module data by default
  (R1 Q6); see also Not Now.

Everything earlier is in `CHANGELOG.md`.

---

## Not Now

Parked scope — deferred work, revisit when prioritized. (CLAUDE.md → Scope Discipline routes out-of-scope items here.)

- **Uninstall without a matching kit copy keeps untouched templates** — `cat uninstall.sh | bash` or a newer `@latest` uninstall can't compare the overlay/artifact templates and keeps them as "yours"; recording their hashes in `.kit-baseline` would fix it. Also: the empty-dir pass drops user-made empty folders under `wiki/`, `raw-sources/`, `artifacts/`, `project/` without listing them; `WIKI_SEED_*` duplicates install.sh's seed text. _(deferred from the R2 PR A review; the overlay-deletion item itself is fixed by PR A)_
- **README skill groups miss `/capabilities`** — the "All 37 skills" list in both READMEs has 36 in its groups; `/capabilities` is only in the intro table, so the docs site lists it under "Other". Add it to _Project setup_ in both READMEs. _(found 2026-09-30 by the docs-site generator)_
- **`gen-skill-docs.sh` guards have no test** — the refuse-to-delete-unmarked-folder guard, exit 2 on bad usage and `--dry-run` writing nothing are only covered by `pages.yml`'s build. Add smoke cases to `scripts/test-cli.sh`. _(found 2026-09-30 by /review-pipeline on the docs-site PR)_
- **Uninstall leftovers from the PR A review (R1)** — `kit_leftover` is still a second, simpler classifier next to `ack_owner`; the kept-`settings.json` warning doesn't name the hook entries; `VERSION` is always removed; `CLAUDE.md.kit-new` is never swept; the `tasks/` empty-dir pass also removes the project's own empty folders. _(deferred from the PR A adversarial review)_

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
