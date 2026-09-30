# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### R1 — brownfield fixes (plan approved 2026-09-30, all recommendations)

Approved by the maintainer with every recommendation: Q1 = C (`#complete` line in the
record, recorded as ADR-030 in PR B), Q2 move to `.kit-backup/`, Q3 skip + warn +
"unknown", Q4 fail only when `settings.json` isn't the kit's, Q5 add `.kit-baseline`
and leave `VERSION` out when it is the project's, Q6 defer to R2, Q7 hold the
release-please PR until PR C and title PR B `feat:`. Start at S1 after this spec and
plan are merged to `main`.

Spec: `tasks/specs/2026-09-28-brownfield-install/` → R1 only; R2–R4 are not planned
here. Status: plan written 2026-09-28, not approved, no code yet.

#### Goal

On a brownfield fixture — its own `.claude/settings.json`, `.claude/hooks/`,
`.claude/agents/` (with a kit-named `code-reviewer.md`), `.claude/skills/`,
`scripts/`, a foreign `tasks/` (Celery-style), `VERSION` and `CLAUDE.md` — the
sequence `init` (with and without a TTY) → `--diff` → `--upgrade` →
`uninstall --force` leaves every pre-existing project file byte-identical at every
stage, installs, records and removes the kit's own files, and names every file it
left alone and why. Each defect (N1, F1, F2, F4, F5, F6, F7, F9, F12, G1, G2) gets a
regression case that fails on `main` @ `622ef95` and passes on the branch.
`npm run check` (clean worktree), `npm test` and markdownlint pass. The
"identical through `--upgrade`" part holds only if Q1 is answered B, C or D.

#### Context

Every known install is brownfield (spec → Context). Reproduced again on this
branch's code (identical to `main` @ `622ef95` outside `tasks/`) in a throwaway
`/tmp` project with its own `.claude/` (settings with permissions only,
`hooks/my-hook.sh`, `agents/code-reviewer.md`, `skills/my-skill/`),
`scripts/deploy.sh`, `tasks/celery.py` and `VERSION` = `3.4.0`:

- `init` exited 0 with zero kit hooks and zero kit scripts installed; `VERSION`
  became `1.23.0 # x-release-please-version`.
- `.kit-manifest` listed the project's `code-reviewer.md`, `my-hook.sh`,
  `my-skill`, `settings.json` and `VERSION`; `.kit-baseline` listed none of them.
- `uninstall --dry-run` listed all of them, plus `tasks/` (holding `celery.py`)
  and "will also remove empty .claude/ directory".
- `--upgrade` replaced the project's `code-reviewer.md` with the kit's (copy in
  `.kit-backup/`) — ADR-023 option A at work.

#### Current State

Line numbers re-verified on this branch; `install.sh`, `uninstall.sh`, `scripts/`
and `.claude/` are byte-identical to `main` @ `622ef95`, so the spec's citations hold.

- Ownership today is `.kit-manifest`. Skip branches add whatever exists:
  `install.sh:1221` (agent_docs), `:1252-1259` (tasks), `:1383` (hooks), `:1413`
  (agents), `:1455` (skills), `:1479` (extensions); unconditional adds: `:1160`
  VERSION, `:1166` CLAUDE.md, `:1183` CODEBASE_MAP.md, `:1485` settings.json,
  `:1529` / `:1601` module schemas, `:1570` / `:1584` module skills and agent,
  `seed_dir` `:535`, `upgrade_dir` `:748`.
- `.kit-baseline` (ADR-017) already records every file the installer writes into
  shared paths (`:1212`, `:1302`, `:1352`, `:1361`, `:1403`, `:1438`, `:1468`,
  `:1489`, `:1493`, `:1510`, `:1522`, `:1533`, `:1574`, `:1588`, `:1605`, and every
  `upgrade_file` branch `:677-725`). Not recorded: `VERSION`, `CODEBASE_MAP.md`,
  `CLAUDE.project.md`, `tasks/*`, `wiki/*.md`, `artifacts/*.html`. Both records are
  written only at the end of a run (`:1631-1635`; `baseline_write` `:785-811`).
- `init` skips whole directories: `agent_docs/` `:1216-1222`, `tasks/`
  `:1250-1259`, `scripts/` `:1315-1320`, `.claude/hooks/` `:1380-1384` (and never
  lists `lib/` — F12), `.claude/agents/` `:1410-1414`, `.claude/skills/`
  `:1450-1456`; an existing `settings.json` only gets "Skipped" (`:1497-1501`).
  `.example` templates are copied unconditionally on a plain run (`:1509`, `:1521`);
  `VERSION` is `cp`'d unconditionally (`:1159`). No TTY: `:1035-1038` errors — and on
  Linux `/dev/tty` exists without a controlling terminal, so CI reaches the `read`
  and dies there instead. The `--gitignore` block (`:1638-1670`) lacks
  `.kit-baseline` and is skipped whole when its marker exists (`:1643-1644`).
  `copy_if_new` (`:509-518`) is defined and unused.
- `--upgrade`: `upgrade_file` (`:677-725`) backs up and replaces an unrecorded file
  (ADR-023 A); `scripts/test-install.sh:663-684` asserts exactly that, and
  `:809-826` guards against the freeze that option B caused. `run_diff`
  (`:333-474`) previews by running the upgrade on a scratch copy; `:358` shows the
  project's `VERSION` as "Installed".
- `uninstall.sh` runs standalone (`curl | bash`) and does not source `scripts/lib/`
  (`scripts/lib/manifest.sh:15-19`). It trusts the manifest through the backstop
  (`:425-443`); `kit_wrote` (`:120-123`) checks presence in the record, not the hash
  (F9); it removes `VERSION` unconditionally (`:211`), `tasks/` with `rm -rf`
  (`:310`, `:627`) after a warning (F4), `settings.json` unconditionally (`:389`);
  its `.claude/`-empty message (`:513-552`) ignores `settings.local.json` (`:530`).
  `kit_leftover` (`:170-176`) is already the hash rule, for unlisted paths only.
- `scripts/doctor.sh` ships standalone into projects (`KIT_USER_SCRIPTS`,
  `scripts/lib/manifest.sh:38`), so it can't source `scripts/lib/` either. An
  unregistered hook is a warning (`:365`); only the quality-gate / stop-gate wiring
  fails (`:379`, `:384`).
- G2: `.claude/hooks/session-end.sh:27-32` writes `reports/session-audit.log` and
  creates `reports/.gitignore` only when missing. Readers and mentions:
  `.claude/skills/scorecard/SKILL.md:3,38,47,128` (no `.tmpl` behind it),
  `bench/scenarios/s15-session-end-writes-audit-line.json:11`,
  `bench/README.md:39,209`, `agent_docs/hooks.md:70,108`,
  `CODEBASE_MAP.md:122,165,245,286` (→ `AGENTS.md`), ADR-007
  (`tasks/decisions.md:158`). No hook deletes `.hook-state/` wholesale
  (`session-start.sh:85,87` remove two markers); the `*` self-ignore is
  `lib/state-counter.sh:26`.
- Tests: `scripts/test-install.sh` (948 lines; helpers `kit` / `fresh` / `snap`
  `:600-611`). Its own-files case adds them only after install (`:495-543`), which
  is why N1 was never caught. KitBench already supports `file_absent` and
  `file_contains`. CI runs the install test on ubuntu and macOS (bash 3.2).

#### Approach

One rule: facts first, policy second. A classifier reports facts about a path;
each operation applies Decision 4 to those facts.

Classifier — `ack_owner <dest> <rel>` in `scripts/lib/manifest.sh`, one word:

| State | Meaning |
|---|---|
| `absent` | nothing at `<rel>`, not even a link |
| `kit` | `.kit-baseline` records `<rel>` and the file still has that hash |
| `kit-edited` | recorded, but the file changed since |
| `unverified` | recorded, but it can't be hashed (no sha256 tool, unreadable, dangling link) |
| `unrecorded` | the record has file entries, none for `<rel>` |
| `no-record` | no `.kit-baseline`, or one with no file entry (ADR-023's definition) |

Plus `ack_record_complete <dest>` (a `#complete` header; only if Q1 = C) and
`ack_prior_install <dest>` (`.kit-manifest` or `.kit-baseline` exists, or
`CLAUDE.md` carries `## Session Boot`). Hash order sha256sum → shasum → python3
(as `install.sh:564-572`); CR stripped from record lines; bash 3.2, no associative
arrays, `LC_ALL=C`. The block sits between `# >>> ack-ownership` and
`# <<< ack-ownership` markers and is copied verbatim into `uninstall.sh` and
`scripts/doctor.sh`, which both run standalone; `test-install.sh` fails when the
three copies differ (same pattern as its `package.json` vs `KIT_USER_SCRIPTS`
check, `:90-92`).

Policy — the preservation matrix the 2026-09-28 lesson asks for:

| State | plain `init` | `--upgrade` | `uninstall` |
|---|---|---|---|
| `absent` | copy, record, list in manifest | copy, record, list (added) | — |
| `kit` | leave, list | update against the record (ADR-017), list | remove |
| `kit-edited` | leave, list | kept or `.kit-new` (ADR-017), list | keep, report "edited since install" |
| `unverified` | leave, list | as today (no hash tool: stops before any change) | keep, report "can't verify" |
| `unrecorded`, record marked complete | skip, report, not listed | skip, report "yours", not listed (Q1) | keep, report "not installed by the kit" |
| `unrecorded`, record not marked | skip, report, not listed | ADR-023 A: back up, replace, record | keep, report |
| `no-record`, prior install | skip, report; record not marked | ADR-023 A; record marked after the run | ADR-023 fallback (Q2) |
| `no-record`, first install | skip, report; record marked | same as `init` | — |

`VERSION` reads `kit-edited` as "the project's" (never a `.kit-new` at the root) and
has one legacy rule (S8). A skill directory and `.claude/hooks/lib/` are
all-or-nothing: if any file in an existing one is not the kit's, the kit writes
nothing into it.

#### Steps

Three PRs, in order, each branched from an up-to-date `main` (squash-only,
ADR-002). Every merge to `main` is live for `curl | bash` users at once
(`install.sh` clones `main`, `uninstall.sh` is fetched from it), so each PR must be
safe on its own.

- **PR A** `fix/r1-uninstall-ownership` — S0–S4. The classifier, tested on the
  uninstall path first (spec risk C1). Only makes uninstall more conservative.
- **PR B** `feat/r1-install-per-file` — S5–S8. The rule applied to `init` and
  `--upgrade` (F5, F6, F12, N1 install side, F1) plus ADR-030. Carries Q1.
- **PR C** `fix/r1-brownfield-surface` — S9–S12. Small independent fixes: F7, G1,
  F2, G2. G2 can split out if the reviewer prefers.

Why three: A and B each carry one ownership risk and get their own
`/review-pipeline` + `devils-advocate` pass; C bundles low-risk fixes that would
dilute B's review. Each step is one commit on its branch, test first.

##### S0 — Baseline the suite (no commit)

- Cut the branch from `main` (after the spec PR merges — see Dependencies). In a
  clean `git worktree`, run `npm run check`, `npm test` and markdownlint; record the
  pass counts with `/verification-status`.

##### S1 — Classifier and fixtures (PR A)

- Files: `scripts/lib/manifest.sh` (block + header comment), `uninstall.sh` and
  `scripts/doctor.sh` (verbatim copy, not called yet), `scripts/test-install.sh`
  (new `== ownership classifier ==` section).
- Fails first (red on `main`: function undefined): a table-driven case calls
  `ack_owner` on crafted projects for every state, plus a record holding only
  `#template` (→ `no-record`), `#` lines never matching a path, a CRLF record, a
  symlink and a dangling one, the no-hash PATH shim (`:763-773`), a kit-named
  project file (`.claude/agents/code-reviewer.md`) under a real install's record
  (→ `unrecorded`), and the same install with `.kit-baseline` removed
  (→ `no-record`). Plus the byte-identical block check.
- Premise check, written without the classifier so it runs on `main` too — expected
  green; if red, stop and re-plan: after fresh `standard`, `strict`, `minimal` and
  `--wiki --html` installs, every file under `agent_docs/*.md`, `scripts/`,
  `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`,
  `.claude/extensions/README.md`, `.claude/*.example`, `settings.json`, `WIKI.md`
  and `ARTIFACTS.md` has a record entry. That is Decision 4's premise and the guard
  against the freeze ADR-023 measured.
- Verify: `bash scripts/test-install.sh`.
- Rollback: `git revert` the commit (nothing calls the block yet).

##### S2 — Uninstall: N1, F9, settings.json (PR A)

- Files: `uninstall.sh` (detection `:116-208`, root files `:210-226`, `:388-391`,
  backstop `:393-443`, listing `:456-511`, `.claude/` emptiness `:513-552`, removal
  `:605-696`), `scripts/test-install.sh`, `README.md` + `README.pt-BR.md`
  (`:390-392`).
- Change: every candidate — manifest entries expanded to files, record entries,
  files under the shared dirs — goes through `ack_owner`. Only `kit` is removed,
  plus the `.kit-new*` copies beside a manifest entry and the bookkeeping files.
  `kit-edited`, `unverified` and `unrecorded` are kept and listed by reason.
  `CLAUDE.md` and `settings.json` follow the same rule; a kept `kit-edited`
  `settings.json` gets a warning naming the kit hook registrations that will point
  at removed scripts. Directories go only when empty; `.claude/` counts
  `settings.local.json` and every kept file. `kit_wrote`, `kit_leftover` and
  `manifest_covers` fold into the classifier. End line:
  `removed N · kept M (edited E, yours Y, unverified U)`.
- Fails first (red on `main`): brownfield fixture, then the manifest widened as
  v1.23.0 wrote it (as `:700-702` does) → `--dry-run` lists none of the project's
  files for removal and doesn't announce removing `.claude/`; `--force` leaves them
  byte-identical (`snap` before install equals after uninstall) and no kit file
  behind. The kit `CLAUDE.md` edited after install is kept (F9). The kit
  `settings.json` edited → kept with the warning; untouched → removed.
  `test-install.sh:476-488`, `:495-543` and `test-cli.sh:136-148` stay green.
- Verify: `bash scripts/test-install.sh && bash scripts/test-cli.sh`.
- Rollback: revert; uninstall goes back to trusting the manifest.

##### S3 — Uninstall: F4 tasks/ (PR A)

- Files: `uninstall.sh:258-312`, `:467-478`, `:556-561`, `:615-632`; tests;
  README `:390` + pt-BR.
- Change: never `rm -rf tasks/`. A file under `tasks/` goes only if `kit` or — for
  installs from before S6 records the scaffold — byte-identical to the kit's
  `scaffold/` copy when the kit tree is at hand (`same_as_kit`, `:151-153`); empty
  dirs then go bottom-up. Without the kit tree (`curl | bash`) an unrecorded
  scaffold file stays and is listed. `--keep-tasks` still keeps everything. The
  "(contains your data!)" warning becomes the kept list.
- Fails first (red on `main`, which runs `rm -rf`): `tasks/celery.py` beside the
  scaffold → `--force` keeps `celery.py` and `tasks/`, removes the pristine
  scaffold files, keeps an edited `todo.md`.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S4 — Uninstall with no record at all (PR A, needs Q2)

- Files: `uninstall.sh`, tests.
- Change (Q2 = A): with `no-record` and a prior install, each existing
  manifest-listed file moves to `.kit-backup/<UTC stamp>/` (a link is moved as a
  link, never followed), is listed, and is counted in the end line; `CLAUDE.md` only
  when it carries `## Session Boot` (ADR-023's rule). With Q2 = B: stop before
  removing anything and point at `install.sh --upgrade`.
- Fails first (red on `main`): record deleted, manifest widened, one symlinked
  skill → nothing is deleted outright; every listed file is under `.kit-backup/`;
  the link target is untouched.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.
- PR A gate: `/review-pipeline` + `devils-advocate` on the classifier and S2–S4.

##### S5 — Init: per-file copy in the skip branches (PR B)

- Files: `install.sh` — skip branches `:1216-1222`, `:1315-1320`, `:1380-1384`,
  `:1410-1414`, `:1450-1456`, `:1477-1480`; `.example` copies `:1503-1524`; manifest
  gating at `:535`, `:748`, `:1160`, `:1166`, `:1183`, `:1485`, `:1529`, `:1570`,
  `:1584`, `:1601`; `chmod +x` only on files the run wrote (`:1304`, `:1364`); a
  pre-flight for `.claude/hooks/lib/` after the kit source is ready (`:1076`, before
  the first write at `:1159`); the init summary; the next-steps line `:1697`.
- Change: `copy_if_new` becomes `install_file <src> <rel>` and applies the `init`
  column: `absent` → copy, `baseline_record`, `manifest_add`; kit states →
  `manifest_add` only; anything else → reported as the project's. Skills: a missing
  kit skill dir is copied whole; an existing one only per file when at least one
  file in it is the kit's, otherwise the whole skill is the project's. `hooks/lib`:
  a lib file that exists and isn't the kit's stops the run before anything is
  written (hooks would source a foreign lib and fail closed); otherwise per file,
  and `.claude/hooks/lib` is listed again (F12). `manifest_add` only for what the
  kit owns after the run (N1). A plain re-run no longer overwrites an edited
  `.example` (closes that Not Now item). The end prints
  `installed N · kept M existing files (yours)` and lists the kept ones;
  `./scripts/validate.sh` is recommended only when it's the kit's. A kit hook name
  the project already uses gets a warning when the kit's `settings.json` registers it.
- Fails first (red on `main`): brownfield fixture → every kit hook, `lib/` file,
  script, agent, skill and `agent_docs/` file installed and recorded; the project's
  files byte-identical (`snap`), in neither manifest nor record; a plain re-run
  keeps `.claude/hooks/lib` in the manifest (F12); an edited
  `.claude/commands.json.example` survives a re-run; a project skill named like a
  kit skill gets no kit file mixed in; a foreign file in `hooks/lib/` stops the run
  with nothing written. `:137-165` stays green.
- Verify: `bash scripts/test-install.sh`.
- Rollback: revert; the skip branches go back to skipping whole directories.

##### S6 — Init: F6 tasks/ (PR B)

- Files: `install.sh:1231-1286`, `seed_dir` `:520-547`; tests.
- Change: `tasks/` is kit-shaped when empty or holding any scaffold top-level name
  (`todo.md`, `decisions.md`, `handoff.md`, `lessons/`). Kit-shaped → seed the
  missing scaffold files with `install_file` semantics; foreign (e.g. only
  `celery.py`) → seed nothing and say the task board wasn't installed (a
  configurable path is deferred — spec → Open Questions). Every scaffold file the
  kit writes is now recorded, so S3 verifies it by hash without the kit tree;
  `seed_dir` and the lessons loop (`:1276-1285`) list only what the kit owns.
- Fails first (red on `main`): kit-shaped `tasks/` with only the project's
  `todo.md` → `decisions.md`, `handoff.md` and `lessons/` appear, `todo.md` is
  identical and reported; a foreign `tasks/` is untouched.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S7 — Upgrade: unrecorded files and the complete record (PR B, needs Q1; ADR-030)

- Files: `install.sh` — `upgrade_file` `:677-725`; `manifest_add` after the
  decision in `upgrade_dir` `:737-752`, skills `:1441-1449`, modules `:1566-1592`;
  `baseline_write` `:785-811` (emits `#complete`); summary `:813-837`; `run_diff`
  `:428-472` (parses the new section, appends the count); the EXIT trap
  `:839-848` (flushes a partial, unmarked record when a real run fails);
  `tasks/decisions.md` (ADR-030 + amendment notes on ADR-017 and ADR-023); tests;
  README `:377-381` + pt-BR.
- Change (Q1 = C): `unrecorded` under a record marked `#complete` → kept, not
  listed, reported "yours — the kit's version isn't installed"; unmarked or no
  record → ADR-023 A unchanged. `#complete` is written by a run that leaves every
  kit path recorded or known to be the project's — a first install, any
  `--upgrade`, an `init` over a marked record — never by a plain run over an
  unmarked or missing record. `--upgrade` with no prior install follows the `init`
  column. The summary appends `· N yours` at the end, so the field positions
  `upgrade_counts` / `preview_counts` parse still hold.
- Fails first (red on `main`): brownfield `init` → `--upgrade` keeps
  `code-reviewer.md` byte-identical and `--diff` says the same (`same_counts`).
  `:663-684` becomes two cases — marked record: the project's `scripts/validate.sh`
  is kept; `#complete` stripped: replaced with a backup (ADR-023 coverage stays).
  `:809-826` and `:828-840` stay unchanged and green. A first install interrupted
  after the hooks copy (a regular file planted at `.claude/agents`) leaves an
  unmarked partial record, and the next `--upgrade` completes it with no `.kit-new`.
- Verify: `bash scripts/test-install.sh`.
- Rollback: revert. Older installers ignore `#complete` (every reader skips `#`
  lines and their `baseline_write` drops it), so a record degrades to ADR-023 A.

##### S8 — F1 VERSION (PR B, needs Q3)

- Files: `install.sh:1158-1160`, `:358`, `:1649`; `uninstall.sh` root files; tests.
- Change: `VERSION` goes through the classifier. `absent` → write, record (new),
  list. `kit` → write the kit's copy (as today), record. `kit-edited`,
  `unrecorded`, or present at a first install → the project's: untouched, not
  listed, warning "VERSION is your project's — the kit's version isn't recorded
  here until R2"; `--diff` shows "Installed: unknown". Legacy rule (no install
  before R1 ever recorded `VERSION`): unrecorded + listed in the manifest + content
  `<semver> # x-release-please-version` → the kit's. Uninstall removes only `kit`.
  The `--gitignore` block leaves `VERSION` out when it's the project's (Q5).
- Fails first (red on `main`): the project's `VERSION` 3.4.0 byte-identical after
  `init`, `--upgrade` and `uninstall`; a greenfield `VERSION` recorded, then
  removed; a pre-R1 install (fingerprinted, unrecorded) updated, then recorded.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.
- PR B gate: the brownfield round trip (Verification) and `/review-pipeline` +
  `devils-advocate`.

##### S9 — F7 no TTY (PR C)

- Files: `install.sh:1019-1045`; tests; README `:288` + pt-BR.
- Change: a TTY means `/dev/tty` can be opened (`{ : </dev/tty; } 2>/dev/null`),
  not that it exists. Without one: an info line "No terminal — continuing:
  existing files are kept, never overwritten", and the run goes on; S5's end report
  lists what was kept. With one: the prompt is unchanged.
- Fails first (red on `main`, exit 1): an existing `CLAUDE.md`, the run detached
  from any controlling terminal with
  `python3 -c 'import os,sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' bash install.sh …`
  (Linux and macOS) → exit 0, kit installed, `CLAUDE.md` identical, the log names
  it. Without python3 the case reports itself skipped, never passed.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S10 — G1 gitignore (PR C, Q5)

- Files: `install.sh:1637-1670`; tests.
- Change: the block gains `.kit-baseline`. A `--gitignore` run over an existing
  block that lacks it inserts the line after the marker, once (temp + `mv`).
- Fails first (red on `main`): a new block holds `.kit-baseline`; an old block
  gains it exactly once over two runs.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S11 — F2 settings warning and doctor failure (PR C, Q4)

- Files: `install.sh:1484-1501` (warning) and the final message `:1691-1717`;
  `scripts/doctor.sh:330-368`; tests.
- Change: a kept `settings.json` that doesn't register the installed profile's kit
  hooks prints a loud block — count, list, "the kit's safety hooks and gates won't
  run until you add them from the kit's `.claude/settings.json` (R2 merges this
  automatically)", then "run ./scripts/doctor.sh". It reuses
  `kit_attention_report`'s `unregistered` lines (`:153-177`), with a grep fallback
  without python3. Exit stays 0. Doctor (Q4 = B) reads `settings.json` and
  `settings.local.json` (as `_doctor_gate_wiring` already does) and fails when
  `settings.json` isn't the kit's (`unrecorded` / `no-record`) and a non-opt-in kit
  hook (`kit` / `kit-edited`) is registered in neither; everything else stays a
  warning.
- Fails first (red on `main`): the brownfield `init` log carries the warning, also
  under the no-python3 shim; doctor there exits 1 naming the hooks; greenfield
  doctor still passes (`:202-207`); a kit-written `settings.json` with one hook
  removed warns without failing.
- Verify: `bash scripts/test-install.sh`. Rollback: revert.

##### S12 — G2 audit log (PR C)

- Files: `.claude/hooks/session-end.sh:5,27-32`;
  `.claude/skills/scorecard/SKILL.md:3,38,47,128`;
  `bench/scenarios/s15-session-end-writes-audit-line.json:11`; new
  `bench/scenarios/s163-session-end-leaves-project-reports-alone.json`;
  `install.sh` (`--upgrade` move, `--diff` line); `scripts/check-counts.sh:29`
  (157 → 158); `README.md` + `README.pt-BR.md` `:453`, `:466`;
  `bench/README.md:39,209` + an s163 row; `agent_docs/hooks.md:70,108`;
  `CODEBASE_MAP.md:122,165,245,286`, then regenerate `AGENTS.md`; an ADR-007
  amendment note.
- Change: the log goes to `.hook-state/session-audit.log`; the hook creates
  `.hook-state/.gitignore` (`*`, `!.gitignore`) when missing and never touches
  `reports/`. `--upgrade` appends an existing `reports/session-audit.log` ahead of
  any lines already in the new file, deletes the old one only if its size didn't
  change meanwhile, deletes `reports/.gitignore` only when its content is exactly
  the kit's `session-audit.log`, and removes `reports/` if that leaves it empty;
  `--diff` prints the planned move. Neither counts as an update or an addition. The
  scorecard's empty-log message names both paths.
- Fails first (red on `main`): s15 expects `.hook-state/session-audit.log` to grow
  and `reports/session-audit.log` absent; s163 plants a project
  `reports/.gitignore` and expects it unchanged with no log beside it;
  `test-install.sh` moves a planted log on `--upgrade` with its content preserved.
- Verify: `npm run bench`, `bash scripts/test-install.sh`,
  `bash scripts/check-counts.sh` (clean worktree), `bash scripts/validate-skills.sh`.
- Rollback: revert; logs already moved stay readable where they are.

#### Files to Touch

- `scripts/lib/manifest.sh` — the ownership block (source of truth).
- `uninstall.sh` — synced block; removal by ownership (S2–S4, S8).
- `install.sh` — per-file init, tasks, upgrade rule, VERSION, TTY, gitignore,
  settings warning, log move (S5–S12).
- `scripts/doctor.sh` — synced block; the F2 failure (S11).
- `scripts/test-install.sh` — every regression case and the round trip.
- `.claude/hooks/session-end.sh`, `.claude/skills/scorecard/SKILL.md`,
  `bench/scenarios/s15-…`, new `bench/scenarios/s163-…`, `bench/README.md`,
  `scripts/check-counts.sh` — G2.
- `README.md`, `README.pt-BR.md` — install, upgrade and uninstall behavior; bench count.
- `agent_docs/hooks.md`, `CODEBASE_MAP.md`, `AGENTS.md` (regenerated) — G2 path.
- `tasks/decisions.md` — ADR-030, plus amendment notes on ADR-017, ADR-023, ADR-007.

#### Protected changes and repo obligations

- No Protected Change as `protect-changes.sh` defines them: no dependency manifest,
  workflow, migration, auth path or build config. That holds only because the
  classifier lives in `scripts/lib/manifest.sh`. A new `scripts/lib/ownership.sh`
  would have to join `package.json` `files` (`:50` names `manifest.sh`, or `npx`
  installs can't source it) — protected — plus a `CODEBASE_MAP.md` entry and an
  `AGENTS.md` regeneration.
- Not protected, still needs approval: S7 reverses ADR-023's option A for records
  marked complete, so ADR-030 is recorded before PR B merges. `.kit-baseline` gains
  a header line (backward compatible — S7 rollback).
- `sync-manifest.sh --check`: unaffected (`kit_manifest_entries` unchanged, no new
  shipped script). `check-scaffold.sh`: unaffected (no `scaffold/` change).
  `check-counts.sh`: 157 → 158 in PR C, with the README phrases CONTRIBUTING.md:48
  requires. `gen-agents-md.sh`: rerun after the `CODEBASE_MAP.md` edits
  (`check:agents-md`). `validate.sh CODEBASE_MAP.md` must still pass.
  `validate-skills.sh` covers the scorecard edit.
- The local wiki module (git-excluded) makes `check:manifest` and `check-counts.sh`
  drift in this checkout — not to be fixed; run the checks in a clean worktree.

#### Dependencies

- No new packages. Tools already required: bash (3.2-compatible), awk, a sha256
  tool; python3 optional, as today.
- Merge `docs/brownfield-install-spec` (spec + this plan) into `main` first, so
  PR A's branch carries both.
- PR B needs Q1; S4 needs Q2; S8 needs Q3; S11 needs Q4; S8 and S10 need Q5.
  S0–S3, S9 and S12 need no answer.

#### Risks

- Blocking: Q1. Without an answer, PR B either keeps "the first `--upgrade`
  replaces the project's file" (A — criterion 5 fails) or brings back the freeze
  ADR-023 measured (B). C is the recommendation, D the narrow alternative.
- Stop condition: if the S1 premise check fails, "absent from the record = the
  project's" is false for this installer; stop and re-plan before S2.
- The block copied into three files can drift; the byte-identical test catches it,
  but every fix is made in `manifest.sh` and copied.
- `curl | bash` reads `main`: each PR is live when it merges, before any release.
- Pre-R1 brownfield installs: the project's files already listed in the manifest
  are replaced, with a backup, on their first R1 `--upgrade` (unmarked record),
  exactly as today; only a complete record protects them from then on. Release
  notes: run `--diff` first and check `.kit-backup/`.
- A `VERSION` the kit overwrote before R1 can't be restored by the kit. Release
  note: restore it from git; the kit then leaves it alone.

#### Failure Modes

- Classifier, record with CRLF endings (a teammate on Windows with
  `core.autocrlf`) → every lookup misses → all `unrecorded` → uninstall keeps kit
  files; under `#complete`, upgrade freezes them. Mitigation: strip `\r` on read;
  S1 CRLF case.
- Record marked complete, but a future write site forgets `baseline_record` → that
  kit file reads as the project's and is never updated (ADR-023's freeze).
  Mitigation: the S1 premise check runs every profile and module and fails on the
  missing entry.
- First install interrupted (Ctrl-C, disk full) after copying files → records are
  written only at the end, so a re-run sees unrecorded kit files as the project's.
  Mitigation: the EXIT trap flushes a partial, unmarked record (S7); the next
  `--upgrade` completes it.
- Per-file hooks: the project has its own `.claude/hooks/secret-scan.sh` and no
  `settings.json` → the kit's `settings.json` registers that name and runs the
  project's script. Mitigation: S5 warning; doctor's behavior checks.
- A foreign `hooks/lib/json-parse.sh` → kit hooks source it and fail closed on every
  Edit and Bash. Mitigation: the S5 pre-flight stops before any write.
- Uninstall keeps a `kit-edited` `settings.json` → it registers removed kit hooks,
  so each matching event shows a hook error. Mitigation: the S2 warning lists them;
  R2's merge removes them properly.
- Uninstall fallback on a symlinked `.claude/skills/<x>` → following the link would
  empty a shared dotfiles dir. Mitigation: move the link itself (S4 case).
- Doctor F2 with the kit hooks registered only in `settings.local.json` → a false
  failure. Mitigation: read both files (S11).
- F7 in a container with a pseudo-TTY but no stdin attached → `/dev/tty` opens and
  the prompt blocks. Known limit; `--upgrade` still skips the prompt.
- G2 move while another session ends → a line lands in the old file after the
  append. Mitigation: delete the old file only if its size is unchanged; else keep
  it and report.

#### Verification

Per step: its failing-first case is red against `main`'s scripts and green on the
branch — prove red by running the new test section with `main`'s `install.sh` /
`uninstall.sh` checked out into a scratch dir.

Release gate, once all three PRs are merged, in a clean `git worktree` of `main`:

1. Typecheck — n/a (bash); `bash -n` on every touched `.sh`.
2. Lint — `npm run check`; `npx --yes markdownlint-cli2 "**/*.md" "#node_modules"`.
3. Tests — `npm test` (KitBench 158/158, `test-install.sh` ALL PASS,
   `test-cli.sh`); CI green on ubuntu and macOS.
4. Smoke — `P=$(mktemp -d /tmp/ack-r1-smoke.XXXXXX)`, `git init` and a first
   commit holding the brownfield fixture (own `CLAUDE.md`, a `settings.json` with
   permissions only, `hooks/my-hook.sh`, `agents/code-reviewer.md`,
   `skills/my-skill/`, `scripts/deploy.sh`, `tasks/celery.py`, `VERSION` 3.4.0,
   `reports/.gitignore`):
   - `bash <kit>/install.sh --local <kit> </dev/null` (no TTY) →
     `git status --porcelain` shows only untracked (`??`) kit paths and no modified
     (`M`) entry; the F2 warning is printed; `bash scripts/doctor.sh` exits 1 naming
     the unregistered hooks.
   - `--diff` leaves `git status` identical; after `--upgrade` still no `M` entry.
   - `bash <kit>/uninstall.sh --dry-run`, then `--force` → `git status --porcelain`
     empty apart from `.hook-state/` and `.kit-backup/`.
   - An empty greenfield dir: install → doctor passes → uninstall → empty again.
   - Once through `bash <kit>/bin/cli.sh init` and `uninstall` (the npx path).
5. Silent failures — fill in and record with `/verification-status`:

| Item | Processed | Failed | Skipped (reason) |
|---|---|---|---|
| Defects N1, F1, F2, F4, F5, F6, F7, F9, F12, G1, G2: red on main, green on branch | | | |
| Smoke fixture: kit files installed, recorded, removed | | | |
| Smoke fixture: project files byte-identical after each stage | | | |
| Collisions reported by `init` vs collisions planted | | | |

#### Open Questions

- Q1 (blocking PR B) — On `--upgrade`, an unrecorded file at a kit path while a
  record exists: A) keep ADR-023 A (replace + backup); B) Decision 4 as written —
  the project's (brings back the freeze; `:809-826` fails); C) B only under a record
  marked `#complete` (recommended); D) record `init`'s collisions as `#user` lines
  and protect only those.
- Q2 (S4) — Uninstall with no record: A) move manifest-listed files to
  `.kit-backup/` (recommended; the spec's ADR-023 fallback); B) stop and ask for
  `--upgrade` first.
- Q3 (F1, the spec's own question) — Where the kit version lives while the project
  owns `VERSION`: A) nowhere, "unknown" until R2 (the spec's recommendation,
  recommended); B) a `#version` header in `.kit-baseline` (one more line if Q1 = C).
- Q4 (S11) — Doctor fails: A) on any unregistered kit hook (breaks deliberate
  disabling, which install's next steps invite); B) only when `settings.json`
  isn't the kit's (recommended); C) only when no kit hook is registered at all.
- Q5 (S8, S10) — Old `--gitignore` blocks: add `.kit-baseline` on a re-run
  (recommended) or only in new blocks? The block also ignores `VERSION`,
  `scripts/`, `tasks/` and `.claude/` wholesale, hiding a brownfield project's own
  new files there: leave `VERSION` out when it's the project's in R1 (recommended)
  and the rest to R2?
- Q6 (scope) — Uninstall still removes `CLAUDE.project.md` and the `project/`
  overlays unless `--keep-project`, while criterion 4 says nothing the user
  created is removed. R1 (same classifier, small) or R2? Recommended: R2.
- Q7 (release) — Hold the release-please PR until PR C, so known installs upgrade
  once (recommended), and title PR B `feat:` so R1 ships as 1.24.0?

#### Not Now

- `--upgrade` still runs `chmod +x` over every `scripts/*.sh` and
  `.claude/hooks/*.sh` (`install.sh:1314`, `:1379`), the project's own included.
- `uninstall.sh:595` still needs a TTY without `--force`.
- `npx … doctor` runs the project's own `scripts/doctor.sh` when one collides
  (`bin/cli.sh:64-70`); it could fall back to the package's.
- Wiki and HTML modules: a project's own `WIKI.md` or `artifacts/` still go
  wholesale on uninstall — R2 `module.conf`.
- Adopting existing files byte-identical to the kit's (a hand-copied kit) instead
  of reporting them as the project's.
- `install.sh` and the ownership block each keep a `file_hash`; R2 dedupes them
  when the scripts move.
- An existing `CLAUDE.md` still leaves the kit's rules unloaded (F3) — R3.

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
