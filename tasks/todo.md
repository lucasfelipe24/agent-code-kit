# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### R2 — kit folder and layout cut (plan written 2026-09-30, not approved, no code yet)

Spec: `tasks/specs/2026-09-28-brownfield-install/` → R2. Protected: every PR below
except A needs its ADR accepted first — drafts ADR-031 … ADR-035 in
`tasks/decisions.md` (Status: proposed). Start only after the Decisions below are
answered; PR A needs none of them.

#### Goal

Four checks, each a script in `scripts/test-install.sh` (plus the new
`scripts/test-migrate.sh`) that fails on `main` @ `239fd48` and passes on the
release:

- **Criterion 2** — brownfield fixture whose `.claude/settings.json` holds only
  its own permissions, `env` and one hook of its own: after `init </dev/null`,
  every hook of the chosen profile is registered (the set of `.claude/hooks/*.sh`
  paths in `settings.json` ∪ `settings.local.json` ⊇ the profile's set), the
  project's entries, permissions and `env` are unchanged as JSON and in order,
  and `doctor` passes its wiring checks. The same after `--upgrade`.
- **Criterion 4** — `init` → `--diff` → `--upgrade` → `uninstall --force` on the
  brownfield fixture (plus a user `CLAUDE.project.md`, `.claude/hooks/project/x.sh`
  and a wiki page) leaves `snap` of the project byte-identical to the snapshot
  taken before `init`, `settings.json` included.
- **Criterion 5** — a v1.23.0 install (greenfield and brownfield) and a
  pre-baseline install (`.kit-baseline` deleted) are migrated: `--diff` names
  exactly what `--upgrade` then does (`same_counts`, moves included); every file
  rewritten or removed is in `.kit-backup/<stamp>/` first; the project's files are
  byte-identical; the end line reads
  `migrated N · carried E · yours Y · backed up B · failed 0`. Then by hand on
  the maintainer's 5 projects: `--diff` reviewed, `--upgrade`, counts recorded.
- **Criterion 7** — after `init` in an empty git project, the first path component
  of every `git ls-files --others --exclude-standard` entry is in Decision 6's
  closed list; after migrating the fixtures, no `settings*.json` command or
  `statusLine` and no shipped kit file names a legacy kit path
  (`scripts/check-kit-paths.sh`, new, run by CI).

Plus `npm run check` (clean worktree), `npm test`, markdownlint and CI on ubuntu
and macOS (bash 3.2).

#### Context

R1 is merged, not released: release PR #11 (`1.24.0`) is open, so every known
install is on v1.23.0 or older (or on `main` through `curl | bash`). All three
tags in history (v1.22.4, v1.22.5, v1.23.0) write `.kit-baseline`, so a
pre-baseline install can only be built synthetically (a v1.23.0 install with the
record deleted), as R1 did.

Measured on `docs/r2-plan` (= `main` @ `239fd48` outside `tasks/`), tracked files,
`CHANGELOG.md` excluded:

| Path that moves | Files | Lines | Where |
|---|---|---|---|
| `agent_docs/` | 57 | 263 | 8 `CLAUDE.md` templates, 15 skill files, 6 kit docs, 6 scripts, 3 installers, 7 `tasks/` |
| `scripts/` | 66 | 447 | includes maintainer-only scripts that don't move; 20 scripts, 8 skills, 5 bench scenarios |
| `.kit-manifest` | 22 | 107 | 3 installers, 5 scripts, CI, docs |
| `.kit-baseline` | 13 | 166 | 2 installers, 3 scripts, docs |
| `VERSION` | 20 | 112 | 3 installers, 3 scripts, 2 skills (`ship:102` is the project's own) |
| `WIKI.md` / `ARTIFACTS.md` | 19 / 16 | 63 / 48 | installers, doctor, check-counts, `capabilities`, 3 wiki-module files |
| `.claude/hooks/lib` | 16 | 61 | 4 hooks, 4 scripts, 1 bench scenario (s44) |
| `tasks/lessons/_TEMPLATE.md` | 24 | 38 | 8 `CLAUDE.md` templates, 2 skills, 6 scripts |
| `.claude/hooks/` (only if hooks move) | 206 | 641 | 157 of 158 bench scenarios (295 `"hook"` fields, relative to the kit source) |

- Shipped into a project: 147 files; 48 of them cite a moving path
  (`agent_docs/*.md`, the 10 `KIT_USER_SCRIPTS`, `.kit-*`, `WIKI.md`,
  `ARTIFACTS.md`) on 234 lines. The 8 `CLAUDE.md` templates carry 112 of them
  (root 25; examples 12–13 each).
- Skills: 19 of 37 core skills, 2 of 3 wiki skills and the wiki agent cite a
  moving path (70 lines, `.claude/hooks/` and `VERSION` included). 3 of those
  lines are `agent_docs/project/…` (project-owned, not moving). Only 3 skills are
  built from `.tmpl` (`code-quality-audit`, `dead-code-audit`, `testing-audit`);
  the `## Kit Context` block (`_shared/blocks/preamble.md`) sits in 17
  `SKILL.md` files, 14 of them hand-copied, and cites no moving path.
- Hooks: 28 scripts + 9 in `lib/`. 26 find their library through
  `$(dirname "$0")/lib`; `skill-compliance.sh:32-35` finds skills as
  `${SCRIPT_DIR%/hooks}/skills`; `scripts/note.sh:40-44` sources
  `$ROOT/.claude/hooks/lib/redact-secrets.sh`; `doctor.sh:64,67,270-272,673`
  hard-code `.claude/hooks/`. `settings.json` registers 25 hook commands in 8
  events, `settings.strict.json` 30 in 9, all as
  `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<name>.sh`; permissions: 23 allow, 13 deny
  (`Bash(curl*)`, `Bash(ssh*)`, …).
- Optional modules are hard-coded in 8 code files (`install.sh` 39 lines,
  `uninstall.sh` 15, `doctor.sh` 15, `capabilities` 2, `check-counts.sh` 2,
  `gen-agents-md.sh`, `sync-manifest.sh`, `lib/manifest.sh` 1 each) plus
  `package.json` (4) and `CLAUDE.md` (2).
- Sizes: `install.sh` 2032 lines, `uninstall.sh` 949, `doctor.sh` 772,
  `lib/manifest.sh` 205, `test-install.sh` 1490 (294 of its lines name a moving
  path), `bin/cli.sh` 145.
- This repo is itself a legacy install: `.kit-manifest` is tracked (104 lines,
  `sync-manifest.sh --check`) and a local, git-excluded `.kit-baseline` plus the
  wiki module sit beside it. After R2, `--upgrade` here would read it as a legacy
  install whose `agent_docs/` and `scripts/` files match the record — and move
  tracked source files out of the tree.

#### R1 facts this plan builds on

- Ownership block `# >>> ack-ownership` … `# <<< ack-ownership` in
  `scripts/lib/manifest.sh:134-205`, copied byte for byte into
  `uninstall.sh:141-212` and `scripts/doctor.sh:176-247`
  (`test-install.sh:1125-1131` fails on drift). `ack_owner` states: `absent`,
  `kit`, `kit-edited`, `unverified`, `unrecorded`, `no-record`;
  `ack_record_complete` (`#complete`, ADR-030); `ack_prior_install`. Every
  function hard-codes `$1/.kit-baseline`.
- `install.sh`: `owner_of` `:571-576`, `install_file` `:598-621`, `install_tree`
  `:676-689`, `upgrade_file` `:848-901`, `backup_file` `:777-785`,
  `replace_file` `:791-809`, `baseline_write` `:963-997` (headers regenerated,
  entries merged), the EXIT trap's partial record `:1060-1067`, `run_diff`
  `:346-499` (copy list `:388-429`, `_plan_compare` `:264-295` reports only
  add / update / conflict), F2 warning `:1946-1967`, `move_audit_log`
  `:1005-1025`.
- `uninstall.sh` removes by record (`may_remove` `:284-303`, backstop
  `:520-586`), keeps by reason, and still has a second classifier
  (`kit_leftover` `:242-248`). It still removes overlays by default
  (`:379-395`), `wiki/` + `raw-sources/` (`:465-466`) and `artifacts/` (`:489`)
  whole, after a warning.

#### Decisions needed

Q1–Q5 are protected (ADRs drafted); Q6–Q10 are plan choices. Recommendations in
bold.

- **Q1 (ADR-031) — Layout scope.** A) **Only what criterion 7 names:**
  `VERSION`, `.kit-manifest`, `.kit-baseline`, `agent_docs/`, the 10 shipped
  scripts, `WIKI.md`, `ARTIFACTS.md` into `.claude/kit/`; hooks, agents and
  templates stay. Migration touches no hook command. B) The spec's full list: also
  hooks + `lib/` → `.claude/kit/hooks/`, templates → `.claude/kit/templates/`,
  agents → `.claude/agents/kit/`. Rewrites every hook command in
  `settings.json` and `settings.local.json`; adds the agent-name collision below.
  C) B without the agents move. Recommendation: **A** — B and C close no
  criterion and carry most of the blast radius; hooks can move later with the
  same migrator (one more table row + the Q2 rewrite).
- **Q2 (ADR-032) — Settings merge.** Tool: A) **python3 only** (the installer
  already needs it for `--diff`, the attention report and doctor's wiring check),
  else the R1 warning + doctor failure; B) node → python3 → manual (spec), two
  implementations kept equal by shared golden vectors. Scope: **hook entries
  (and the strict profile's `ACK_*` `env` keys) only, never `permissions`** — the
  kit's deny list (`Bash(curl*)`, `Bash(ssh*)`, …) would change what the project
  lets Claude do.
- **Q3 (ADR-035) — Source layout and dogfooding.** A) Mirror the installed layout
  in this repo; B) **keep the source layout, the installer maps paths, and three
  tracked symlinks (`.claude/kit/docs`, `.claude/kit/scripts`,
  `.claude/kit/modules`) let this repo's own `CLAUDE.md` — which is the shipped
  generic template — cite installed paths**; C) keep the source layout and
  generate this repo's `CLAUDE.md` from the template with a CI drift check.
- **Q4 (ADR-034) — `module.conf` + `CONTRACT.md`.** A) In R2 (spec, shape.md
  Decision 12); B) **R2 only moves `WIKI.md` / `ARTIFACTS.md` (criterion 7);
  `module.conf` becomes the first step of the Playbook module**, its first new
  consumer. B reverses Decision 12, so it needs the maintainer's call.
- **Q5 (ADR-031) — Where the kit version and install facts live.** A)
  **`.claude/kit/install.conf` (`key=value`, read with awk, never sourced):
  `layout`, `version`, `profile`, `modules`** — R3 adds `integration`, R4
  `adoption`; `#template`, `#complete` and the new `#hook` lines stay record
  headers. B) `.claude/kit/VERSION` as a file, the rest as record headers, no
  `install.conf` until R3.
- **Q6 — A `CLAUDE.md` the kit wrote and the user edited** (`kit-edited`) still
  cites `agent_docs/…` after the move. A) **Rewrite only the known kit paths in it
  (literal map, backup first, reported)**; B) leave it, write
  `CLAUDE.md.kit-new`, report — its rules point at missing files until R3.
- **Q7 — Ship R1 first.** **Merge release PR #11 (`1.24.0`) before PR A**, so
  known installs gain complete records before they migrate. The migrator still
  handles v1.23.0 records.
- **Q8 — CI tags.** The v1.23.0 fixture needs the tag; `actions/checkout@v4`
  fetches none. **Add `fetch-depth: 0` to the install job
  (`.github/workflows/validate.yml:119`, protected)**; without the tag the case
  reports itself skipped, never passed.
- **Q9 — Legacy uninstall.** After the cut, `curl … uninstall.sh | bash` meets
  legacy installs. **Keep supporting both layouts** — uninstall is record-driven,
  so the layout is only where the record sits.
- **Q10 — Project files that run kit scripts** (a Makefile or CI calling
  `./scripts/validate.sh`). **Report them** (`git grep` over tracked files, read
  only, same output in `--diff` and `--upgrade`); never rewrite.

#### Spec items that can be deferred without failing criteria 2, 4, 5, 7

- Hooks + `lib/` to `.claude/kit/hooks/`, templates to `.claude/kit/templates/`,
  agents under `.claude/agents/kit/` (spec R2.1–2) — `.claude/` is on the closed
  root list, and `tasks/` is the project's. See Q1.
- `module.conf` + `CONTRACT.md` (R2.3) — Q4.
- Node as the first JSON tool (R2.4) — Q2.
- The generated "Kit Context" path block (R2.7) — the block cites no moving path
  and reaches 3 of 37 skills; the 70 references are hand prose. Replaced by one
  sed-style edit plus `check-kit-paths.sh` in CI.
- `session-start` reading `install.conf` (spec Files to Touch) — nothing in R2
  needs it; R3's block check does. R2 adds only a one-line "migration incomplete"
  notice (S18).
- "`uninstall` driven by `install.conf`" (R2.8) — it is record-driven already;
  only the record's location changes (S17).

#### Steps

Four PRs (a fifth only if Q4 = A), in order, each from an up-to-date `main`,
squash-only (ADR-002). Every merge is live for `curl | bash` users at once, so
each PR leaves the kit working on its own. Hold the release-please PR until PR D
merges (as R1 did), so known installs migrate once.

- **PR A** `fix/r2-uninstall-keeps-user-data` — S1–S2. Criterion 4's leftovers
  from R1 (R1 Q6, Not Now items): overlays and module data. Only makes
  uninstall more conservative; no protected change.
- **PR B** `feat/r2-settings-merge` — S3–S7. Criterion 2 in today's layout
  (ADR-032). Independent of the layout; D reuses its rewrite mode.
- **PR C** `feat/r2-migrator` — S8–S12. The record-aware classifier, layout
  detection, path map, planner and executor, tested on fixtures and **not wired**
  into `install.sh` (ADR-033). No behavior change: this is how the migrator is
  tested before the layout flips.
- **PR D** `feat/r2-layout-2` — S13–S21. The flip: fresh installs write layout 2,
  `--upgrade` / `--diff` migrate, uninstall / doctor / CLI / content follow, hard
  cut (ADR-031, ADR-035). Largest PR; C has already proven its engine.
- **PR E** (only if Q4 = A) `feat/r2-module-conf` — S22.

Why this order and not the spec's (classifier/migrator, layout, settings merge,
modules): A is the smallest, safest win and closes a criterion alone; B closes
criterion 2 and doesn't depend on the layout, so users get it before the risky
flip; C must precede D (test before flip); modules are last because they're
optional. C can be developed in parallel with B.

Per-PR gate (every PR, before merge, in a clean `git worktree`):

1. Brownfield round trip on the R1 smoke fixture (own `CLAUDE.md`, a
   `settings.json` with permissions and one own hook, `hooks/my-hook.sh`,
   `agents/code-reviewer.md`, `skills/my-skill/`, `scripts/deploy.sh`,
   `tasks/celery.py`, `VERSION` 3.4.0, `reports/.gitignore`): `init </dev/null` →
   `--diff` → `--upgrade` → `uninstall --force`, `git status --porcelain` checked
   after each; nothing `M` that the step doesn't own.
2. Upgrade of a v1.23.0 install AND of a pre-baseline install through the PR's
   code (from PR C on: the migration itself), `same_counts` between `--diff` and
   `--upgrade`, backup listed.
3. `/review-pipeline` + the `devils-advocate` agent on the diff; findings fixed or
   logged under Not Now with a reason.
4. `(processed / failed / skipped)` recorded with `/verification-status`.

R1 lessons that bind every step:

- Every removal or overwrite goes through the classifier (`owner_of` /
  `ack_owner`); never a path list alone, never the manifest alone.
- Back up before any rewrite or removal (`backup_file`, one stamp per run); write
  new files as temp + `mv` (`replace_file`).
- Report `processed / failed / skipped` with reasons; a quiet log never hides a
  skipped file.
- `--diff` must equal `--upgrade`: it runs the same code on a scratch copy, so
  anything a decision reads (`settings.local.json`, `.gitignore`, the legacy
  records) must be in the copy list (`install.sh:388-429`), and anything read
  outside it (Q10's `git grep`) must be read-only and printed by both.
- bash 3.2: no associative arrays, `mapfile`, `${x,,}`; empty arrays as
  `${a[@]+"${a[@]}"}` under `set -u`. Under `pipefail` a reader that exits early
  (`grep -q`, `grep -m1`, `head`) fails the pipeline — capture whole output or
  use a herestring. CI's Pipefail Grep Guard (`validate.yml:207-237`) rejects
  `| grep -q` in any `pipefail` script.
- Prove red: every fails-first case runs against `main`'s scripts checked out in
  a scratch dir.

##### S0 — Baseline (no commit)

- After Q7, cut each branch from `main`. In a clean worktree run `npm run check`,
  `npm test`, markdownlint; record the counts with `/verification-status`.

##### S1 — Uninstall keeps the project's overlays (PR A)

- Files: `uninstall.sh:379-395` (overlays), `:754-759` (warning), `--help`
  `:70`; `bin/cli.sh:43`; `scripts/test-install.sh`; `README.md` +
  `README.pt-BR.md` uninstall section.
- Change: `CLAUDE.project.md` goes only when byte-identical to the kit's copy
  (`same_as_kit`, `:223-225`) — it isn't recorded, and without the kit tree
  (`curl | bash`) it stays. `agent_docs/project/` and `.claude/hooks/project/` go
  only when empty. `--keep-project` becomes a no-op kept for compatibility.
- Fails first (red on `main`): a user-edited `CLAUDE.project.md`,
  `.claude/hooks/project/x.sh` and `agent_docs/project/mission.md` survive
  `uninstall --force` byte-identical; the pristine template goes.
- Verify: `bash scripts/test-install.sh && bash scripts/test-cli.sh`.
- Rollback: revert; uninstall removes overlays again after its warning.

##### S2 — Uninstall keeps module data (PR A)

- Files: `uninstall.sh:433-491`, `:604-620` (listing), `:741-752`; tests.
- Change: `wiki/` and `raw-sources/` are never removed whole: the seeds
  `wiki/index.md` / `wiki/log.md` go only while byte-identical to what
  `create_wiki_index` / `create_wiki_log` write (`install.sh:66-88`; the uninstall
  copy of those two strings sits beside them), then empty dirs bottom-up.
  `artifacts/`: `index.html` and `design-system.html` go only while identical to
  `html-module/templates/` (needs the kit tree, as S1); everything else stays and
  is listed. `--keep-wiki` / `--keep-artifacts` keep working.
- Fails first (red on `main`, which runs `rm -rf`): a wiki page, a raw source and
  an artifact survive; untouched seeds go; an emptied tree leaves no dir.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.
- PR A gate (above).

##### S3 — Settings merge engine (PR B)

- Files: new block `# >>> ack-settings` … `# <<< ack-settings` (a python3
  heredoc function `ack_settings`) in `install.sh` after `kit_attention_report`
  (`:127-208`), copied byte for byte into `uninstall.sh`; `test-install.sh`
  (byte-identity check, as `:1125-1131`).
- Change: bash computes facts, python applies policy.
  `ack_settings <mode> <file> <kit_settings> <kit_hooks> <records>` where
  `<kit_hooks>` is the list of `.claude/hooks/*.sh` paths the classifier calls
  the kit's (`kit` / `kit-edited`, or listed by the old manifest under
  `no-record`). Modes: `plan` (TSV, writes nothing), `merge`, `strip`,
  `rewrite <old>=<new>…` (literal path rewrite, used by PR D). A hook entry is
  the kit's when its command names a path in `<kit_hooks>` (regex as `:133`).
  Per kit hook of the profile: absent in `settings.json` and
  `settings.local.json` → add (a new group with the kit's matcher, appended to
  the event); present and equal to its `#hook` record → replace with the kit's
  current entry; present and different → keep, report "edited"; no record →
  keep, record it only if equal to the kit's. A kit entry the kit no longer ships
  → removed only if equal to its record. Never touched: other entries, key order,
  `permissions`, other keys; strict `env` keys `ACK_*` added only when absent.
  Output keeps the file's indent (2, 4 or tab, detected), its non-ASCII and its
  final newline; unchanged content → no write. Not strict JSON → no write,
  `plan` says "manual".
- Record: `#hook<TAB><event><TAB><path><TAB><sha256 of canonical {matcher, hook}>`
  header lines, regenerated by `baseline_write` (`:973-986`); older readers skip
  `#` lines (ADR-030 precedent).
- Fails first (the function doesn't exist on `main`): golden cases — empty
  hooks, own hook in the same event, a kit hook registered only in
  `settings.local.json` (not added), an edited kit entry (kept), a stale kit
  entry (removed / kept by record), a project hook named like a kit hook (never
  touched), 4-space and tab indent round trip, JSONC comment (no write), a
  `strip` of a `merge` equal to the input bytes.
- Verify: `bash scripts/test-install.sh`. Rollback: revert (nothing calls it).

##### S4 — `init` merges into a project's `settings.json` (PR B)

- Files: `install.sh:1738-1763`, `:1957-1967` (the R1 warning becomes the
  no-python3 path), the final message `:1997-2013`; tests; README `:420` area.
- Change: `settings.json` present and not the kit's → `backup_file`, `merge`,
  report `registered N kit hooks · kept M of yours`. The file stays unrecorded
  (it's the project's); only `#hook` lines are recorded. A kit-written file keeps
  today's path. Without a usable python3 (`.claude/hooks/lib/python3.sh`'s
  probe): the R1 warning, exit 0, doctor fails (R1 Q4).
- Fails first (red on `main`): the criterion-2 check in Goal; the PATH shim
  (`test-install.sh:950-970` pattern, without python3) still prints the
  warning; a greenfield install is unchanged.
- Verify: `bash scripts/test-install.sh`. Rollback: revert; back to the warning.

##### S5 — `--upgrade` and `--diff` keep registrations current (PR B)

- Files: `install.sh:1758-1759` (`Kept … not auto-merged`), `run_diff` copy list
  `:409` (+ `settings.local.json`), `:496` message, `print_attention`
  `:214-258`; `kit_attention_report` `unregistered` now means "the merge couldn't
  add it"; tests `:418-476`.
- Change: `--upgrade` runs `merge` on a kit-edited or unrecorded `settings.json`
  (whole-file `upgrade_file` stays for an untouched kit file). `--diff` shows the
  per-entry plan from the scratch run. Closes the Not Now item "existing installs
  keep relative hook commands" only where the entry equals its record; others are
  reported.
- Fails first (red on `main`): a v1.23.0 brownfield install gains the missing
  hooks on `--upgrade`; `--diff` names them first (`same_counts`); an edited kit
  entry is kept and reported.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S6 — Uninstall strips the kit's entries (PR B)

- Files: `uninstall.sh:507-509`, `:698-704`, `:731-738`, removal `:870-877`;
  tests.
- Change: a `settings.json` that isn't the kit's loses exactly the entries whose
  hook the kit removes in this run (`strip`), after a backup; a kit-written one
  follows R1. The R1 "may still register kit hooks" warning goes away when the
  strip succeeds; without python3 it stays and names the entries (closes a PR A
  review leftover).
- Fails first (red on `main`): the criterion-4 round trip with a merged
  `settings.json` (2-space indent) is byte-identical after uninstall.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S7 — Doctor and docs (PR B)

- Files: `scripts/doctor.sh:427-453` (message: "run install.sh --upgrade to
  register them"); `agent_docs/hooks.md`; `README.md` + pt-BR (upgrade section
  `:374-382`); `CODEBASE_MAP.md:299-302`; ADR-032 status; ADR-021 amendment note
  ("`.claude/settings.json` is never modified" no longer holds).
- Verify: `bash scripts/test-install.sh`, markdownlint. Rollback: revert.
- PR B gate (above).

##### S8 — The record can live in either layout (PR C)

- Files: ownership block `scripts/lib/manifest.sh:134-205` → re-copied into
  `uninstall.sh` and `doctor.sh`; tests `:1121-1196`.
- Change: `ack_record_file <dest>` → `.claude/kit/baseline` if it exists, else
  `.kit-baseline`; `ack_record_hash` looks in the layout-2 record first, then the
  legacy one (paths never overlap except the shared ones, where the newer record
  wins). `ack_layout <dest>` → `none` · `legacy` (only root records) · `partial`
  (both records, or the new one plus a legacy kit path still on disk) · `2`.
  `ack_prior_install` also accepts `.claude/kit/manifest`.
- Fails first: each layout state on crafted trees; every R1 classifier case stays
  green unchanged.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S9 — Path map (PR C)

- Files: new `scripts/lib/layout.sh` (sourced by `install.sh` only; added to
  `package.json` `files` in PR D); tests.
- Change: `ack_layout_map <kit_dir>` prints `legacy<TAB>new` rows, derived, not
  listed by hand: `agent_docs/<f>.md` → `.claude/kit/docs/<f>.md` (never
  `project/`); each `KIT_USER_SCRIPTS` entry → `.claude/kit/scripts/<s>`;
  `.kit-manifest` → `.claude/kit/manifest`; `.kit-baseline` →
  `.claude/kit/baseline`; `VERSION` → `.claude/kit/install.conf` `version=`
  (Q5); `WIKI.md` → `.claude/kit/modules/wiki/WIKI.md`; `ARTIFACTS.md` →
  `.claude/kit/modules/html/ARTIFACTS.md`. Q1 = B adds the hooks rows.
- Fails first: the map lists every file a fresh v1.23.0 standard install put under
  a moving path (premise check, as R1 S1) and nothing else.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S10 — Fixtures (PR C)

- Files: new `scripts/test-migrate.sh` (helpers copied from
  `test-install.sh:620-626`, `:737-755`); `package.json` `scripts` gains
  `test:migrate` and `npm test` runs it (protected); `validate.yml` install job
  (Q8, protected).
- Change: fixtures built once per run: (a) v1.23.0 standard, greenfield, from
  `git worktree add <tmp> v1.23.0`; (b) v1.23.0 on the brownfield fixture
  (N1-widened manifest); (c) (a) and (b) with `.kit-baseline` deleted
  (pre-baseline); (d) a `main` install (marked record); (e) wiki + html modules;
  (f) an edited kit doc and an edited kit script; (g) the project's own
  `scripts/validate.sh` under a marked record; (h) a copy of this repo's tracked
  tree (`git archive HEAD`). No tag → "skipped (no v1.23.0 tag)", counted,
  never passed.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S11 — Planner (PR C)

- Files: `scripts/lib/layout.sh`; `scripts/test-migrate.sh`.
- Change: `ack_migration_plan <dest> <kit_dir>` — reads only — prints one row per
  mapped path: `move` (kit, unchanged: the kit's current copy goes to the new
  path), `carry` (kit-edited: the user's copy goes, its old record hash carried
  so the next 3-way still works), `replace` (no-record and listed by the old
  manifest: ADR-023 A — backup, then move), `yours` (unrecorded under a marked
  record, or unlisted: stays where it is), `done` (origin gone, destination
  present), `resume` (both present, destination hash verified), `refuse` with a
  reason (the kit's own source tree; a layout newer than this kit).
- Fails first: exact expected rows for fixtures (a)–(h); (h) → `refuse`.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S12 — Executor (PR C)

- Files: `scripts/lib/layout.sh`; `scripts/test-migrate.sh`.
- Change: `ack_migrate_apply` runs the plan in phases, each safe to repeat:
  1. back up every origin, both records, `VERSION` (if the kit's),
     `settings.json`, `settings.local.json` and `.gitignore` into one
     `.kit-backup/<stamp>/`; a failed copy stops the run before anything moves;
  2. copy each `move` / `carry` / `replace` to its new path (temp + `mv`), verify
     its sha;
  3. write `.claude/kit/manifest`, `.claude/kit/baseline` (carried hashes; the
     mark follows ADR-030) and `install.conf`;
  4. rewrite the executable references: a `statusLine.command` naming a moved
     kit script, the `--gitignore` block (`install.sh:1900-1941` format), and,
     if Q1 = B, every kit hook command (S3 `rewrite`);
  5. remove each origin whose destination verified, then empty legacy dirs, then
     the legacy records last.
  State is read from disk (ADR-033): phase 5 not finished = `partial`. Report:
  `migrated N · carried E · yours Y · replaced R (backed up) · failed F`.
- Fails first: for each fixture, the final tree equals the expected one; a run cut
  after each phase (a destination made unwritable, then restored) and re-run
  equals an uncut run (`snap`); project files byte-identical; every removed or
  rewritten file is in the backup.
- Verify: `bash scripts/test-migrate.sh && bash scripts/test-install.sh`.
- Rollback: revert (nothing calls it).
- PR C gate (above) — `devils-advocate` pointed at S11–S12 first.

##### S13 — Source layout (PR D, needs Q3)

- Files (Q3 = B): three tracked symlinks `.claude/kit/docs → ../../agent_docs`,
  `.claude/kit/scripts → ../../scripts`, `.claude/kit/modules/wiki/WIKI.md` and
  `…/html/ARTIFACTS.md` → the root files; `.gitignore` unchanged;
  `scripts/sync-manifest.sh` + `kit_manifest_entries`
  (`lib/manifest.sh:67-132`) emit layout-2 paths; the tracked `.kit-manifest`
  becomes `scaffold/kit-manifest.txt` (so this repo stops looking like a legacy
  install) — `sync-manifest.sh`, `validate.yml:148-151`, `CODEBASE_MAP.md`.
- Fails first: a new check in `sync-manifest.sh --check` — every path the generic
  `CLAUDE.md` cites resolves in this repo.
- Verify: `npm run check`. Rollback: revert.

##### S14 — Fresh installs write layout 2 (PR D)

- Files: `install.sh:26,31` (record paths), `:1308-1311`, `:1415-1427`
  (VERSION → `install.conf`; the project's `VERSION` is never read or written
  again), `:1481-1505` (docs; no `agent_docs/project/`), `:1547-1592`
  (scripts), `:1787-1799`, `:1861-1873` (schemas), `:1894-1897`,
  `:1916-1938` (`--gitignore` block: `.claude/kit/` and the project paths only),
  `:1997-2031` (next steps); `package.json` `files` (+ `scripts/lib/layout.sh`,
  protected); tests.
- Fails first (red on `main`): the criterion-7 check; the R1 round trip on
  layout 2; `test-install.sh` paths updated (294 lines name a moving path — each
  rewrite reviewed, none deleted).
- Verify: `bash scripts/test-install.sh && bash scripts/test-cli.sh`.
- Rollback: revert; installs made meanwhile are migrated back by nothing — see
  Risks.

##### S15 — `--upgrade` migrates, `--diff` previews it (PR D)

- Files: `install.sh` after `:1390-1391` (layout check, then
  `ack_migrate_apply`), `run_diff` `:388-429` (copy `.claude/kit`,
  `settings.local.json`, `.gitignore`), `_plan_compare` `:264-295` (new `move`
  and `remove` rows; bookkeeping `:269` gains the layout-2 records),
  `print_upgrade_summary` `:1029-1058` (`· N moved` appended, field positions
  kept for `upgrade_counts` `test-install.sh:753`), Q10 report; tests.
- Change: guards before any write: the kit's own source tree → refuse (S11 (h));
  `--version` older than the R2 release on a layout-2 or partial install → refuse
  (today `--diff --version` runs the target's installer and `--upgrade --version`
  this one — they would disagree across the cut); no hash tool → stop (as today).
- Fails first (red on `main`): criterion 5 on fixtures (a)–(g) through
  `install.sh --upgrade`, `--diff` first, `same_counts` with moves.
- Verify: `bash scripts/test-migrate.sh && bash scripts/test-install.sh`.
- Rollback: revert. A migrated project keeps layout 2; the backup holds every
  legacy file.

##### S16 — `CLAUDE.md` that the kit wrote and the user edited (PR D, needs Q6)

- Files: `install.sh:1440-1449`; tests.
- Change (Q6 = A): a `kit-edited` `CLAUDE.md` gets the literal map (`agent_docs/<kit
  doc>` → `.claude/kit/docs/<kit doc>`, the 10 scripts, `WIKI.md`,
  `ARTIFACTS.md`) after a backup; the record's hash is updated only if the file
  was otherwise equal to the recorded one. A project's own `CLAUDE.md` is never
  touched.
- Fails first: an edited kit `CLAUDE.md` cites no legacy kit path afterwards and
  keeps the user's lines; a `/init` `CLAUDE.md` is byte-identical.
- Verify: `bash scripts/test-migrate.sh`. Rollback: revert.

##### S17 — Uninstall in both layouts (PR D)

- Files: `uninstall.sh:100-113` (record via `ack_record_file`), `:121`
  (`SHARED_DIRS` + `.claude/kit/docs|scripts|modules`), `:270-276`
  (`record_backed`), `:348-366` (bookkeeping: `.claude/kit/*`, `install.conf`;
  the root `VERSION` only by the R1 legacy rule), `:919-923` (+ `.claude/kit`);
  tests.
- Fails first: criterion 4 on a layout-2 install and on a v1.23.0 install
  (legacy layout, Q9).
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S18 — Doctor, CLI, session-start (PR D)

- Files: `scripts/doctor.sh:155-159`, `:165`, `:286-295`, `:540-541`,
  `:595-661`; new layout check (`legacy` / `partial` → fail "run install.sh
  --upgrade (--diff first)"); `bin/cli.sh:64-70`, `:96-104`, `:105-122` (run
  `.claude/kit/scripts/…`; a legacy install gets the upgrade message instead of
  its old scripts); `scripts/gen-agents-md.sh:169`;
  `.claude/hooks/session-start.sh` (one line when `ack_layout` is `partial`:
  cheap disk test, no parsing); new bench scenario + `check-counts.sh:29`
  (158 → 159); tests; `test-cli.sh`.
- Fails first: doctor fails on fixtures (a) and a half-migrated tree, passes after
  `--upgrade`; `npx … doctor` on a legacy install prints the upgrade line; the
  bench scenario sees the notice.
- Verify: `npm test`. Rollback: revert.

##### S19 — Content paths and the residue check (PR D)

- Files: the 48 shipped files that cite a moving path (8 `CLAUDE.md` templates,
  19 skills + 2 wiki skills + wiki agent, 6 kit docs, 10 scripts' usage lines,
  `bash-budget.sh:147`, `read-budget.sh:102`, `lib/redact-secrets.sh:8`,
  `.claude/extensions/README.md`, `scaffold/tasks/handoff.md`), relative links
  in `deepening-review/references/*.md` (`../../../../agent_docs/…`);
  `README.md` and pt-BR (`:285-286`, `:354-360` statusline, upgrade,
  uninstall); `CODEBASE_MAP.md`,
  `AGENTS.md` (regenerated), `CONTRIBUTING.md`; new `scripts/check-kit-paths.sh`
  run by `sync-manifest.sh --check` (as `check-prefix-residue.sh`).
- Change: one scripted rewrite by the S9 map, then hand review; the check fails on
  a legacy kit path in any file `package.json` ships, with a short allowlist
  (`agent_docs/project/`, the project's `VERSION` in `ship`, the migrator's map,
  `CHANGELOG.md`).
- Fails first: the check fails on `main`'s tree and passes after the rewrite.
- Verify: `npm run check`, `bash scripts/validate-skills.sh`, markdownlint.
  Rollback: revert.

##### S20 — Hooks move (PR D, only if Q1 = B or C)

- Files: `.claude/settings.json`, `scripts/gen-strict-settings.sh` →
  `settings.strict.json` (25 / 30 commands), `skill-compliance.sh:32-35`,
  `scripts/note.sh:44`, `doctor.sh:64,67,270-272,673`, 4 hooks' BLOCKED messages
  (`block-dangerous-commands.sh:16`, `branch-protect.sh:20`,
  `protect-changes.sh:38`, `protect-files.sh:24`), the map (S9), a
  `.claude/kit/hooks → ../hooks` source symlink (bench untouched), docs.
- Fails first: a migrated install's `settings.json` and `settings.local.json`
  name only `.claude/kit/hooks/`; doctor's Behavior section passes from there.
- Rollback: revert.

##### S21 — Release notes (PR D)

- Files: `README.md` + pt-BR, `RELEASING.md` (manual smokes below), ADR-031,
  ADR-033, ADR-035 status; amendment notes on ADR-017, ADR-021, ADR-023.
- Change: the hard cut is stated: run `--diff`, then `--upgrade`; legacy doctor
  and scripts are refused afterwards; restore from `.kit-backup/<stamp>/`.
- PR D gate (above), plus the manual run on the maintainer's 5 projects.

##### S22 — `module.conf` + `CONTRACT.md` (PR E, only if Q4 = A)

- Files: new `wiki-module/module.conf`, `html-module/module.conf`, a
  `CONTRACT.md` each; the 8 code files above loop over module manifests;
  `package.json`.
- Fails first: install, upgrade, uninstall and doctor results with both modules
  equal to PR D's (a pure refactor: same `snap`, same logs).
- Rollback: revert.

#### Protected changes and repo obligations

- ADRs before code: ADR-031 (PR D), ADR-032 (PR B), ADR-033 (PR C), ADR-034
  (PR E or deferral), ADR-035 (PR D). `package.json` (`files`, `scripts`) and
  `.github/workflows/validate.yml` trip `protect-changes.sh`: record the ADR,
  then `CLAUDE_APPROVED=1`.
- `sync-manifest.sh --check`, `check-scaffold.sh`, `check-counts.sh` (158 → 159
  in PR D), `gen-agents-md.sh` + `check:agents-md`, `gen-strict-settings.sh
  --check` (only if hooks move), `validate-skills.sh`, `check-prefix-residue.sh`
  must pass in a clean worktree (the local wiki module drifts them here — don't
  fix it).

#### Dependencies

- No new packages. bash 3.2, awk, a sha256 tool, git; python3 for the merge and
  `--diff`, as today.
- Q7 before PR A; ADR-032 before PR B; ADR-033 and Q8 before PR C; ADR-031,
  ADR-035, Q5, Q6 before PR D. PR C in parallel with PR B.

#### Risks

- **Migrator misclassification (C1 again) — highest.** A wrong `move` removes a
  project file from where its tools expect it. Mitigation: the plan is the R1
  classifier's facts only; backup first; `--diff` first; fixtures (a)–(h) in CI;
  `devils-advocate` on S11–S12.
- **This repo migrating itself.** Its tracked `.kit-manifest` and local
  `.kit-baseline` make it a legacy install whose `agent_docs/` and `scripts/`
  match the record: an `--upgrade --local .` after PR D would move tracked source
  files. Mitigation: S11 `refuse`, S13 renames the tracked manifest, fixture (h).
- **Hard cut outside the maintainer's control.** Legacy scripts, a project's CI
  calling `./scripts/validate.sh`, a README-documented `statusLine` pointing at
  `./scripts/statusline.sh`. Mitigation: statusLine rewritten (S12), Q10 report,
  doctor/CLI messages, release notes.
- **Settings rewrite formatting.** Criterion 4 byte identity holds only for files
  whose formatting the writer reproduces (a detected 2/4/tab indent, JSON as
  `json.dumps` writes it); compact or hand-aligned files come back reformatted.
  Mitigation: no write when unchanged; report "reformatted"; ADR-032 names it.
- **Revert after PR D ships** can't un-migrate installs: a reverted installer
  would see layout 2 as "no prior install". Mitigation: forward-fix; the backup
  holds every legacy file; hold the release until PR D's gate is green.
- `curl | bash` reads `main`: every PR is live on merge.

#### Failure Modes

- Planner, record with CRLF (Windows teammate) → all misses → `yours` → nothing
  moves, kit docs duplicated. Mitigation: `\r` stripped in the block (R1); a CRLF
  fixture.
- Executor, disk full between phases 2 and 5 → both copies exist. Mitigation:
  `partial` state, doctor and session-start say "resume", a re-run finishes.
- Executor, user edits a moved file between a cut run and the re-run → the
  destination hash no longer matches the plan. Mitigation: `resume` verifies
  against the origin, not the plan; a mismatch is `failed`, listed, origin kept.
- Merge, `settings.json` is a symlink into a dotfiles repo → temp + `mv` replaces
  the link. Mitigation: write through the link as `replace_file` does
  (`:793-799`), and say so in `--diff` (`_kit_symlinks`).
- Merge, a project registers a kit hook under a different matcher on purpose →
  kept as "edited", reported once, never overwritten.
- Uninstall strip, python3 missing → kit entries stay and point at removed
  scripts. Mitigation: the R1 warning names each entry.
- `--diff` over a partial layout → the scratch copy must include both layouts'
  paths, or the preview claims a fresh migration. Mitigation: copy list from the
  map, both directions; a partial fixture in `same_counts`.
- Doctor run from a subdirectory → relative paths miss. Known contract (run from
  the project root); the CLI `cd`s there.

#### Verification

Per step: its fails-first case is red against `main`'s scripts and green on the
branch. Release gate after PR D (and E) in a clean worktree of `main`:

1. Typecheck — n/a; `bash -n` on every touched `.sh`; the python heredocs parsed
   with `python3 -c 'import ast'` in the tests.
2. Lint — `npm run check`; `npx --yes markdownlint-cli2 "**/*.md" "#node_modules"`.
3. Tests — `npm test` (KitBench, `test-install.sh`, `test-migrate.sh`,
   `test-cli.sh`); CI green on ubuntu and macOS.
4. Smoke — the R1 fixture in a fresh `git init` project, no TTY: `init` →
   `git status --porcelain` shows only `??` entries in the closed list; doctor
   passes; `--diff` / `--upgrade` / `uninstall --force` → clean. A v1.23.0
   install upgraded by `bin/cli.sh init --upgrade`. The manual Claude Code
   smokes below.
5. Silent failures, recorded with `/verification-status`:

| Item | Processed | Failed | Skipped (reason) |
|---|---|---|---|
| Fixtures (a)–(h) migrated, `same_counts` held | | | |
| Kit hooks registered vs the profile's set (criterion 2) | | | |
| Project files byte-identical after each stage | | | |
| Shipped files free of legacy kit paths (`check-kit-paths.sh`) | | | |
| Maintainer's 5 projects: `--diff` reviewed, upgraded | | | |

#### Could not verify (smoke proposed)

- Agents in a subfolder (only if Q1 = B): the sub-agents docs (fetched
  2026-09-30) say `.claude/agents/` is scanned recursively, identity comes only
  from `name`, and two files with one `name` load "one of them, chosen by
  filesystem read order". Not run here. Smoke: fixture with
  `.claude/agents/kit/ack-probe.md` (`name: ack-probe`, prompt holds a codeword);
  `claude -p --agent ack-probe "Say your codeword"`.
- Hook commands under `$CLAUDE_PROJECT_DIR/.claude/kit/hooks/` (only if hooks
  move): documented as shell commands with `$CLAUDE_PROJECT_DIR` expanded — low
  risk, not run. Smoke: a SessionStart hook at that path that touches a marker;
  `claude -p "ok"`; the marker exists.
- A session already running while `--upgrade` rewrites hook paths — whether it
  picks the new paths up or keeps its start-up copy is not checked. Smoke: start
  a session, migrate in another terminal, make an Edit, look at `/hooks` and the
  quality-gate record.
- Whether Claude Code accepts comments or trailing commas in `settings.json` —
  unknown; the merge treats such a file as unparseable and writes nothing.
  Smoke: a fixture with a `//` line; does a registered SessionStart marker hook
  run?
- The same handler in `settings.json` and `settings.local.json` runs once
  (hooks docs, fetched 2026-09-30) — the merge relies on it only when a project
  registered a kit hook in both. Not run.
- Claude Code reading this repo's `.claude/kit/docs/…` through a tracked symlink
  (Q3 = B) and, for R3, `@import` through one — not run. Smoke:
  `claude -p "Quote the first heading of .claude/kit/docs/workflow.md"`.
- Hook order inside an event: the merge appends groups; no kit hook is assumed to
  depend on order. Not checked against the docs.

#### Spec vs code

- R2.7 (skill paths through a generated Kit Context block): the block cites
  `CODEBASE_MAP.md`, `CLAUDE.project.md` and `tasks/lessons/_index.md` — none
  move — and `build-skills.sh` builds 3 of 37 skills.
- R2.6 (doctor refuses a legacy layout): a legacy install runs its own old
  `scripts/doctor.sh` and old hooks; only the new doctor (after migration, or via
  `npx … doctor`) can refuse.
- R2.4 (node → python3): the installer, `--diff` and doctor use python3 only
  today; node exists only in `bin/agent-code-kit.js`.
- R2.3 ("~7 hard-coded sites"): 8 code files plus `package.json` and `CLAUDE.md`.
- Risks section sizes are stale: `install.sh` 2032 lines (spec: 1718),
  `test-install.sh` 1490 (948), bench 158 scenarios (136).
- Decision 6 lists `CLAUDE.project.md` as "legacy", but Decision 13 defers D7, so
  R2 fresh installs still create it at the root; the criterion-7 check must allow
  it.
- References (sub-agents): recursive discovery is documented; the undocumented
  part is which of two same-named agents loads — that makes `.claude/agents/kit/`
  riskier than today's flat folder when a project already has a
  `code-reviewer`.
- `--diff --version <tag>` runs the tag's installer on the scratch copy while
  `--upgrade --version <tag>` runs the current installer with the tag's tree
  (`install.sh:439` vs `:1280-1305`), so ADR-021's "same code" holds only without
  `--version` — today already.

#### Not Now

- Moving `.hook-state/` (Decision 13), `DESIGN.md` timing, `CLAUDE.project.md` on
  new installs (D7) — out of the milestone.
- A configurable `tasks/` path.
- `npx … doctor` running the package's doctor instead of the project's.
- Widening the Pipefail Grep Guard to `grep -m1` / `head` (existing Not Now).

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
layout (shipped to `main` — see Done), R2 `.claude/kit/` + migration (planned —
see In Progress), R3 `CLAUDE.md` managed block, R4 adoption. R2–R4
are protected changes and need ADRs. The Playbook's `--playbook` module (its
phase 3) waits for R2, so it's born on `module.conf`.

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

- **Uninstall deletes overlay files the project had before the kit** — `CLAUDE.project.md`, `agent_docs/project/`, `.claude/hooks/project/` are removed by default (warned in the listing) even when the kit only found them; only remove what the kit created. _(deferred from the PR B review; predates R1)_
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
