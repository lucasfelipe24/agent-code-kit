# Architecture Decision Records

Track important technical decisions here so they don't get lost between sessions.

---

## Format

```markdown
### ADR-[number]: [Short title]
- **Date**: YYYY-MM-DD
- **Status**: proposed | accepted | rejected | superseded
- **Context**: [What problem are we solving? What constraint exists?]
- **Options**:
  - A) [Option] — Pros: ... / Cons: ...
  - B) [Option] — Pros: ... / Cons: ...
- **Decision**: [Which option and why]
- **Consequences**: [What changes as a result? Any risks?]
```

---

## Example

### ADR-001: Use Zod for request validation
- **Date**: 2026-03-01
- **Status**: accepted
- **Context**: API endpoints accept user input without validation. Need runtime validation with TypeScript type inference.
- **Options**:
  - A) Zod — Pros: TypeScript-first, small bundle, great DX / Cons: another dependency
  - B) Joi — Pros: mature, battle-tested / Cons: no TS inference, larger
  - C) Manual validation — Pros: no dependency / Cons: error-prone, verbose
- **Decision**: Zod (A). TypeScript inference eliminates duplicate type definitions. Small enough to justify the dependency.
- **Consequences**: All route handlers must validate input with Zod schemas. Schemas live in `src/schemas/`.

---

<!-- Add new decisions below this line -->

### ADR-036: The docs site is a Fumadocs project in `web/`, with its own dependencies
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: The kit has no docs site. `scripts/gen-skill-docs.sh` emits Fumadocs pages into a `../web` that holds no project, and ADR-009 pointed the plugin's `homepage` at a site that does not exist. The kit itself ships with zero runtime dependencies, and a site needs a framework. Spec: `tasks/specs/2026-09-30-docs-site/`.
- **Options**:
  - A) Fumadocs (Next 16 + fumadocs-core/ui/mdx + Tailwind 4) in `web/` with its own `package.json`, static export to GitHub Pages — Pros: the generator already targets it; search, i18n and sidebar come built in; the dependencies never touch the kit's `package.json`, npm `files` or `.kit-manifest`. / Cons: a Node toolchain and a lockfile to keep current, for a maintainer-only artifact.
  - B) A static generator with no framework (pandoc or a shell script over the markdown) — Pros: no dependencies. / Cons: search, i18n, navigation and theming would all be built by hand.
  - C) GitHub Pages with Jekyll straight from the markdown — Pros: no build step in the repo. / Cons: the kit tried and removed it (CHANGELOG, Cayman theme); no i18n or search worth the name.
- **Decision**: A — the maintainer's choice, dependencies approved 2026-09-30.
- **Consequences**: New `web/` project and `.github/workflows/pages.yml`. Generated pages are built in CI and gitignored. `gen-skill-docs.sh` becomes a maintained generator that the R2 moves also update. The maintainer enables Settings → Pages → Source = GitHub Actions once. `package.json` and `.claude-plugin/plugin.json` `homepage` move to the site URL.

### ADR-035: The kit's source repo mirrors the installed layout
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: R2 installs kit files under `.claude/kit/` (ADR-031). This repo is both the kit's source and a project that uses the kit: its `CLAUDE.md` is the shipped generic template, its `.claude/settings.json` is the shipped standard settings, and its own sessions run its hooks and skills. Once the template cites `.claude/kit/docs/…` and the settings run `.claude/kit/hooks/…`, this repo's sessions need those paths to exist. The repo also tracks a `.kit-manifest` and carries a local, git-excluded `.kit-baseline` and wiki module, so it already reads as a legacy install. Measured (2026-09-30, tracked files, `CHANGELOG.md` excluded): 72 files move; 259 of 395 tracked files name a moved path, on 1286 lines — among them all 158 KitBench scenarios (310 lines), `test-install.sh` and `test-cli.sh` (179 lines), the installers (101), the 8 `CLAUDE.md` templates (117), 23 skill files (68), 6 kit docs (48), both READMEs (20); 14 of the 259 are `tasks/` history, which is not rewritten.
- **Options**:
  - A) Mirror: the source tree takes the installed shape — `.claude/kit/{docs,scripts,hooks,templates,modules}` and `.claude/agents/kit/` — and the installer copies it — Pros: this repo runs exactly what users get; one shape to reason about; `kit_manifest_entries` and the install copy become the same list. / Cons: the largest diff of the milestone; Claude's writes into `.claude/` prompt, so every maintainer edit to a kit doc or script now prompts (hooks and skills already did); `--version <tag older than R2>` has a different source shape.
  - B) Keep the source layout; the installer maps paths; tracked symlinks let this repo's `CLAUDE.md` resolve installed paths — Pros: no file moves. / Cons: symlinks in the repo; reading through them untested; two shapes.
  - C) Keep the source layout and generate this repo's `CLAUDE.md` from the template — Pros: no symlinks. / Cons: two `CLAUDE.md` files and a generator; the shipped `settings.json` would need the same treatment.
- **Decision**: A, the maintainer's choice.
  - Moves per category, each in the PR that flips that category for installs (the shipped `settings.json` and `CLAUDE.md` are this repo's own, so the source and the installed paths can't change apart): agents → `.claude/agents/kit/`; `agent_docs/*.md` (12) → `.claude/kit/docs/`; the 10 shipped scripts → `.claude/kit/scripts/`; `scaffold/tasks/lessons/_TEMPLATE.md`, `scaffold/tasks/handoff.md`, `.claude/commands.json.example`, `.claude/mcp-allowlist.txt.example` → `.claude/kit/templates/`; `WIKI.md` / `ARTIFACTS.md` → `.claude/kit/modules/{wiki,html}/`; `.claude/hooks/*.sh` (28) + `lib/` (9) → `.claude/kit/hooks/`.
  - Stays: `VERSION` at the root (release-please's extra-file, the repo's release version, read by the installer as the kit's version); maintainer scripts (`test-*.sh`, `run-bench.sh`, generators, `scripts/lib/`) in `scripts/`; `wiki-module/` and `html-module/` payloads (skills must install to `.claude/skills/<name>/`); `agent_docs/project/` and `.claude/hooks/project/` as this repo's own overlays; `tasks/` minus the two template copies `check-scaffold.sh` compares today.
  - The tracked `.kit-manifest` becomes `scaffold/kit-manifest.txt` (a reference listing, not a record), so nothing in the tree reads as an install record.
  - Dogfood loop: `install.sh` (every mode) and `uninstall.sh` refuse to run when the target is a kit source tree (`install.sh`, `uninstall.sh`, `scaffold/tasks/todo.md` and `bench/scenarios/` all present, or the target is the `--local` source itself). The maintainer's local wiki module is left as it is; its git-excluded `.kit-baseline` is deleted by hand when the records move.
  - Every PR is one squash commit on `main` (ADR-002); inside a branch, a category's `git mv` and all its reference edits are one commit, so each commit passes `npm run check` and `npm test`.
- **Consequences**:
  - Largest risk: moving the hooks rewrites the paths of the safety hooks this repo runs on while it is being developed. A missed reference is a hook that isn't found — a non-blocking error — so the maintainer's gates go quiet rather than loud. The hooks PR runs doctor's behavior checks on this repo, the hooks smoke, and does the move outside a running Claude Code session.
  - `package.json` `files`, `validate.yml` (chmod lines `:109`, `:124`, `:139`), `check-counts.sh`, `check-scaffold.sh`, `sync-manifest.sh`, `gen-strict-settings.sh`, `gen-agents-md.sh`, `gen-skill-docs.sh`, `convert.sh` change with the categories they touch; `scripts/check-kit-paths.sh` fails on a legacy kit path in any shipped file.
  - Maintainer edits to kit docs and scripts prompt for permission (protected `.claude/` path).

### ADR-034: `module.conf` and `CONTRACT.md` wait for the Playbook module
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: shape.md Decision 12 (delegated) put a per-module `module.conf` + `CONTRACT.md` into R2, because criterion 7 moves `WIKI.md` and `ARTIFACTS.md` out of the root and that touches the module code anyway. Measured: module names and paths are hard-coded in 8 code files (`install.sh` 39 lines, `uninstall.sh` 15, `doctor.sh` 15, the `capabilities` skill 2, `check-counts.sh` 2, `gen-agents-md.sh`, `sync-manifest.sh`, `lib/manifest.sh` 1 each), plus `package.json` and `CLAUDE.md`. Two modules exist; the Playbook module is the next.
- **Options**:
  - A) R2 adds `module.conf` + `CONTRACT.md` per module and the 8 files loop over them — Pros: the Playbook is born on it; the module code is edited once. / Cons: a refactor no criterion needs, in the riskiest release.
  - B) R2 only moves the two schema files into `.claude/kit/modules/<name>/`; `module.conf` becomes step one of the Playbook module — Pros: R2 stays the size its criteria need; the format is designed with its third consumer in view. / Cons: the module sites are edited twice.
- **Decision**: B, the maintainer's choice.
- **Consequences**: Reverses shape.md Decision 12. The Playbook plan in `tasks/todo.md` → Up Next starts with `module.conf` + `CONTRACT.md`. R2's module folders are plain paths.

### ADR-033: How an install migrates to layout 2
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: R2 moves the records, `VERSION`, docs, scripts, templates, module schemas, hooks and agents (ADR-031). Every known install is on v1.23.0 or earlier — or on unreleased `main` via `curl | bash` — and release PR #11 (`1.24.0`) stays open until R2 ships, so the migrator meets unmarked v1.23.0 records whose manifests list the project's own files (N1), marked R1 records, and records deleted by hand. shape.md Decision 10 chose no journal; Decision 16 a hard cut. The move lands in four PRs, each live on `main` for `curl | bash` users, so an install may be migrated in several steps. A migration must survive a cut run, be previewed by `--diff` exactly (ADR-021), and never move or lose a file that isn't the kit's (Decision 4, ADR-023, ADR-030).
- **Options**:
  - A) Plan per file with the R1 classifier, apply in repeatable phases, read the state back from disk, one map row at a time — Pros: no second record to drift; a re-run is the recovery; the map can grow PR by PR; the plan is testable before any installer calls it. / Cons: every phase must be idempotent; a half-migrated row must be recognisable from disk alone.
  - B) A TSV journal of steps with statuses — Pros: explicit progress. / Cons: duplicates the disk and can disagree with it after a crash.
  - C) No migration; every script reads both layouts — Pros: nothing moves. / Cons: rejected by Decision 16.
- **Decision**: Recommended A:
  - The record may sit at `.claude/kit/baseline` or `.kit-baseline`; the ownership block looks in the new one first. `ack_layout` reports `none` · `legacy` · `partial` (any legacy row still on disk beside a new record) · `2`.
  - The map (legacy → new) is derived from the kit tree. Rows: records, `VERSION` → `install.conf`, docs, scripts, templates, module schemas, agents, hooks + `lib/`.
  - Plan rows: `move` (kit, unchanged), `carry` (kit-edited: the user's copy moves with its old record hash, so the next three-way update still works), `replace` (no record, listed by the old manifest: ADR-023 A with a backup), `yours` (stays), `done`, `resume`, `blocked` (a precondition is missing, the origin stays), `refuse`.
  - Templates under `tasks/` and `.claude/*.example` were never recorded before R1: they move only while byte-identical to a kit copy; otherwise they are the project's and stay.
  - Agents follow ADR-031's collision rule: a kit agent whose `name` a project agent already uses anywhere under `.claude/agents/` is not installed and is reported "yours — the kit's version isn't installed".
  - Hooks rows need the ADR-032 rewrite of every kit hook command in `settings.json` and `settings.local.json`; without a usable python3, or with a file that isn't strict JSON, the hooks rows are `blocked` — the legacy hooks stay, registered, and doctor fails with the reason.
  - Phases: back up every origin, both records, `settings*.json` and `.gitignore` into one `.kit-backup/<stamp>/` → copy and verify each sha → write the new records (mark per ADR-030) and `install.conf` → rewrite executable references (hook commands, a `statusLine` naming a moved kit script, the `--gitignore` block) → remove verified origins, empty legacy dirs, the legacy records last.
  - Refuses before any write: the kit's own source tree (ADR-035); a `--version` older than R2 over a layout-2 or partial install; no sha256 tool.
  - `--diff` runs the same migration on its scratch copy, which also copies `.claude/kit`, `.claude/agents/kit`, `settings.local.json` and `.gitignore`; the preview gains `move` and `remove` rows.
  - Project files that call kit scripts (a Makefile, CI) are reported, never rewritten. A kit-written `CLAUDE.md` the user edited gets the known kit paths rewritten after a backup.
  - Whether a running Claude Code session follows rewritten hook paths decides one detail (smoke gate G3 in the plan): if it keeps its start-up copy, legacy hooks are removed only by the next run once no session is live, and the upgrade says to restart sessions.
- **Consequences**: The ownership block changes (re-copied into `uninstall.sh` and `doctor.sh`). Uninstall reads either layout, so a legacy install can still be removed after the cut. A reverted installer can't un-migrate; recovery is the backup. The report ends `migrated N · carried E · yours Y · replaced R (backed up) · blocked K · failed F`. `test-migrate.sh` needs the v1.23.0 tag in CI (`fetch-depth: 0`).

### ADR-032: The kit's hooks are merged into a project's settings.json by owner, with python3
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: Criterion 2: a project with its own `.claude/settings.json` gets every hook of the profile registered and keeps its entries and permissions. R1 only warns and makes doctor fail. ADR-017 recorded the settings baseline "for the later merge work"; ADR-021 says `--upgrade` never modifies `settings.json`. Claude Code merges hooks across user, project and local settings and runs an identical handler once; it has no include/extends (hooks docs, fetched 2026-09-30). The kit's `settings.json` registers 25 commands in 8 events (strict: 30 in 9) and carries 23 allow / 13 deny permissions, among them `Bash(curl*)` and `Bash(ssh*)`. Moving the hooks (ADR-031) also needs every kit hook command in `settings.json` and `settings.local.json` rewritten.
- **Options**:
  - A) Merge hook entries only, by owner, with python3; without a usable python3, the R1 warning and doctor failure — Pros: python3 is already what `--diff`, the attention report and doctor's wiring check need; one implementation. / Cons: a machine with node and no python3 gets the manual path.
  - B) The same in node, then python3, then manual (spec) — Pros: every `npx` user has node. / Cons: two implementations to keep equal.
  - C) Register the kit's hooks in `.claude/settings.local.json` — Pros: never writes the project's `settings.json`. / Cons: gitignored, so teammates get no hooks.
  - D) No merge — Cons: criterion 2 fails.
- **Decision**: A, the maintainer's choice (the recommendation).
  - A hook entry is the kit's when its command names a hook path the ownership classifier calls the kit's; bash supplies those facts, python applies the policy. An entry that only resembles one — the same file name under `.claude/hooks/project/`, or a project's own hook the record doesn't list — is never touched.
  - Merge, per kit hook: absent from `settings.json` and `settings.local.json` → added as a new group with the kit's matcher; equal to its recorded copy → updated; different → kept and reported; stale and unchanged → removed. Per-entry records are `#hook` header lines in the install record.
  - Rewrite (used by the migration): in the kit's entries only, the legacy hook path is replaced by the new one, in both settings files, keeping every other field the user set; a `statusLine` command naming the kit's `scripts/statusline.sh` likewise. A re-run finds nothing to rewrite and writes nothing.
  - Never merged: `permissions` and other keys; the strict profile's `ACK_*` `env` keys are added only when absent.
  - Writes keep the file's indent, non-ASCII and final newline; no write when nothing changes; a backup first; a symlinked file is written through; a file that isn't strict JSON is never written.
  - Uninstall strips exactly the kit's entries.
- **Consequences**: Amends ADR-017 (the record gains `#hook` lines) and ADR-021 (`--upgrade` now changes `settings.json` and `settings.local.json`, and `--diff` shows it). Criterion 4's byte identity holds for files the writer reproduces (a detected 2/4/tab indent, `json.dumps` style); other formatting comes back reformatted and is reported. doctor's F2 failure remains the no-python3 safety net.

### ADR-031: Layout 2 — kit files move into `.claude/kit/`, kit agents into `.claude/agents/kit/`
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: Criterion 7: no kit-internal versioned file at the project root. shape.md Decisions 5–7 put them in `.claude/kit/` and name what leaves the root: `VERSION`, `.kit-manifest`, `.kit-baseline`, `agent_docs/`, `scripts/`, `WIKI.md`, `ARTIFACTS.md`. The spec's R2 list also moves hooks + `lib/`, templates and the kit's agents, so that `.claude/hooks/` and `.claude/agents/` become the project's own. The sub-agents docs (fetched 2026-09-30) say `.claude/agents/` is scanned recursively, identity comes only from `name`, and of two files with one `name` Claude Code loads one "chosen by filesystem read order".
- **Options**:
  - A) Move only what criterion 7 names; hooks, agents and templates stay — Pros: the migration rewrites no hook command. / Cons: `.claude/hooks/` and `.claude/agents/` stay shared with the project; a later move is a second migration.
  - B) The spec's full list — Pros: `.claude/hooks/` and `.claude/agents/` become the project's own; a settings entry and an agent are the kit's by path; one migration. / Cons: every kit hook command in two settings files is rewritten; a running session may keep old paths (unverified); agent names can collide across the tree.
  - C) B without the agents — Pros: no name collisions. / Cons: the rest of B's cost.
- **Decision**: B, the maintainer's choice, with these rules:
  - Layout: `.claude/kit/manifest`, `.claude/kit/baseline`, `.claude/kit/install.conf`, `.claude/kit/docs/`, `.claude/kit/scripts/`, `.claude/kit/hooks/` (+ `lib/`), `.claude/kit/templates/` (`lesson.md`, `handoff.md`, `commands.json.example`, `mcp-allowlist.txt.example`), `.claude/kit/modules/wiki/WIKI.md`, `.claude/kit/modules/html/ARTIFACTS.md`, and `.claude/agents/kit/<name>.md` (wiki's agent included). Skills stay at `.claude/skills/<name>/` (the only place Claude Code finds them). `.claude/hooks/project/` stays the project's overlay.
  - `install.conf`: `key=value`, read with awk, never sourced — `layout`, `version`, `profile`, `modules`; R3 adds `integration`, R4 `adoption`. `#template`, `#complete` and `#hook` stay record headers. The project's `VERSION` is never read or written again.
  - Agent names: before placing a kit agent, the installer reads the `name` of every `.md` under `.claude/agents/` (frontmatter `name:`, else the file's stem) that isn't a kit file. A kit agent whose `name` is taken is not installed, not recorded, not listed, and is reported "yours — the kit's version isn't installed", as ADR-030 does for paths. Never both. `--upgrade`, `--diff` and the migrator apply the same rule; a collision that appears after install (the project adds an agent later) makes `--upgrade` back up and remove the kit's untouched copy, or keep an edited one and report; doctor fails on any `name` declared twice under `.claude/agents/`.
  - Templates are no longer created inside `tasks/` or `.claude/`; the templates and skills cite `.claude/kit/templates/`.
- **Consequences**: Every kit hook command moves to `"$CLAUDE_PROJECT_DIR"/.claude/kit/hooks/<name>.sh` (25 standard / 30 strict per install, plus any in `settings.local.json`); hooks still find `lib/` beside themselves. `skill-compliance.sh:32-35` (skills relative to its own folder), `scripts/note.sh:44`, `doctor.sh:64,67,270-272,528-533,673`, the BLOCKED messages of 4 hooks, `convert.sh:46`, `gen-skill-docs.sh:28`, `check-counts.sh:48` and the `capabilities` skill (`.claude/agents/*.md`, not recursive) change. `agent_docs/project/` is no longer created; an existing one stays the project's. The `--gitignore` block lists `.claude/kit/` and `.claude/agents/kit/`. Three Claude Code behaviors become release smokes (plan: gates G1–G3).

### ADR-030: A file with no install-record entry is the project's once the record is marked complete
- **Date**: 2026-09-30
- **Status**: accepted
- **Context**: ADR-023 chose to replace a file at a kit path that `.kit-baseline` doesn't list (with a backup), because a record written by a plain re-run or a plain upgrade covered only part of the kit, and B ("the project's own") would have frozen kit files at an old version. The brownfield milestone (`tasks/specs/2026-09-28-brownfield-install/`) needs the opposite for a brownfield project: its own `.claude/agents/code-reviewer.md` or `scripts/validate.sh` must stay byte-identical through `init`, `--upgrade` and `--diff`. Only ADR-023's premise — an incomplete record — blocks that.
- **Options**:
  - A) Keep ADR-023 A (replace and back up) — Pros: nothing new to write. / Cons: every brownfield `--upgrade` still overwrites the project's files, so criterion 5 of the spec fails.
  - B) Treat every unrecorded file as the project's — Pros: simple. / Cons: the exact freeze ADR-023 measured (60 `.kit-new` files over a few releases) for installs whose record is partial.
  - C) A `#complete` header line in `.kit-baseline`, written only by a run that leaves every kit path recorded or known to be the project's — Pros: repairs B where the record is trustworthy and keeps A where it isn't; older installers skip `#` lines, so a record degrades to ADR-023 A. / Cons: one more thing to write correctly on every path that writes the record.
  - D) A `#covers` list naming which parts of the kit a record covers — Pros: finer. / Cons: ADR-023's objection stands: some fifteen writers, one forgotten brings the freeze back.
- **Decision**: C. An `unrecorded` file under a record marked `#complete` is the project's: kept, not listed in the manifest, reported ("yours — the kit's version isn't installed"). Under an unmarked or missing record, ADR-023 A applies unchanged. `#complete` is written by a first install, any `--upgrade`, and an `init` over an already-marked record; never by a plain run over an unmarked or missing record. A run that fails midway writes what it did as a partial record that keeps only the mark it can vouch for: a first install (what it hasn't reached is absent or the project's) and a record that was already marked keep `#complete`; an `--upgrade` that dies over an unmarked record leaves it unmarked. Under an unmarked record an unlisted file is judged like no record at all (the previous manifest decides), never as the project's.
- **Consequences**:
  - Amends ADR-017 (the record gains the header) and ADR-023 (its rule for unrecorded files now depends on the mark); their other rules stand.
  - A project that wants the kit's copy of a file it already had deletes it and re-runs.
  - `--diff` reports the same outcome as `--upgrade` (`same_counts`); the summary gains a trailing `· N yours`, so the fields `upgrade_counts` and `preview_counts` parse keep their positions.
  - Uninstall keeps an unrecorded file whatever the mark says (PR A).

### ADR-029: Configuration prefix is ACK_ — clean cutover, migrated by doctor
- **Date**: 2026-09-28
- **Status**: accepted
- **Context**: The kit's environment variables (`ACK_PROTECT_BUILD_CONFIGS`, `ACK_QUALITY_GATE_TIMEOUT`, `ACK_STOP_REVERIFY_BUDGET`, the `ACK_NOTIFY_*` set), its internal names and its temp/marker files carried a prefix from an earlier name of the project. The maintainer wants the product to use one prefix, `ACK_` / `ack-`, with no trace of the former one in the tracked tree. Existing installs keep `.claude/settings.json` across upgrades (ADR-017), so a strict install still sets the former build-config key; a rename would silently turn strict build-config blocking off there.
- **Options**:
  - A) Dual-read for a release (new name first, former as fallback) — Pros: no install breaks / Cons: the former prefix stays in hooks, docs and tests for the whole window, against the stated goal
  - B) Clean cutover, hooks read only `ACK_*`; `doctor` renames former keys in `.claude/settings.json` and `settings.local.json` automatically; the upgrade report points at `doctor` — Pros: zero residue; values carried over for installs that run `doctor` / Cons: exported shell variables can't be rewritten, only reported; `doctor` now writes settings
  - C) Clean cutover with no migration — Pros: least code / Cons: strict installs silently lose build-config blocking; a quality-gate failure noted in the former temp marker is forgotten
- **Decision**: B, at the maintainer's request, released as a **minor** version by the maintainer's choice even though former names stop working.
- **Consequences**:
  - `doctor` renames former-prefix `env` keys to `ACK_*` (values kept; an `ACK_` key already set wins), after a mode-600 backup in `.hook-state/`, and never prints a value. It names exported former-prefix variables by their `ACK_` target only; the user renames those in the shell profile or CI and restarts Claude Code. `--upgrade` still never writes `.claude/settings.json`; it now counts former-prefix keys and points at `doctor`.
  - State that must not be lost is carried over, not dropped: stop-gate and quality-gate move a quality-gate marker written under the former file prefix into the `ack-gate-*` one (an unrecordable failure keeps blocking), and `convert` sweeps skills exported under the former `-generated` marker. `doctor` removes the former python3-probe cache; the hooks just re-probe (~40 ms).
  - Code that must recognise the former prefix builds it from character codes, so `scripts/check-prefix-residue.sh` — run by `sync-manifest.sh --check`, i.e. CI's Manifest Sync job and `npm run check` — fails on any occurrence in a tracked path or content, with no allowlist. Git history, released tags and the npm package at 1.22.x are outside that guarantee.
  - Rollback: forward-fix preferred; in an emergency, pin the previous GitHub tag and restore settings from the `doctor` backups. Aliases are not reintroduced.

### ADR-028: Releases are GitHub-only; npm publishing is opt-in
- **Date**: 2026-09-28
- **Status**: accepted
- **Context**: The Release workflow published every release-please release to npm with the `NPM_TOKEN` secret. The maintainer wants to cut releases on GitHub only for now, without losing the ability to publish to npm again later.
- **Options**:
  - A) Delete the `publish-npm` job — Pros: nothing to gate / Cons: turning publishing back on means rewriting the job
  - B) Gate the job on a repository variable, `NPM_PUBLISH == 'true'` — Pros: off by default, back on with one command and the secret, no workflow edit / Cons: a job that is skipped on every release
  - C) Leave the job and just not set `NPM_TOKEN` — Pros: no change / Cons: every release run fails the publish job instead of skipping it
- **Decision**: B, at the maintainer's request.
- **Consequences**: Releases create the tag and the GitHub release; the npm package stays at the last published version (1.22.4), so `npx @lucasfelipe23/agent-code-kit` installs that version until publishing resumes, while the curl installer follows GitHub. To publish again: set `NPM_TOKEN`, then `gh variable set NPM_PUBLISH --body true` (RELEASING.md).

### ADR-027: Solo-maintained repository — issues off, pull requests limited to collaborators
- **Date**: 2026-09-28
- **Status**: accepted
- **Context**: The repository is public (ADR-025), and the maintainer develops the kit alone and won't take outside issues or pull requests. GitHub lets a repository turn issues off (`has_issues`), limit who can open pull requests (`pull_request_creation_policy`: `all` or `collaborators_only`, since February 2026), or turn pull requests off. The maintainer's own work and release-please both depend on pull requests: `branch-protect.sh` blocks pushes to `main`, and release-please opens the release PR.
- **Options**:
  - A) Leave issues and pull requests open and state the policy in the README — Pros: no setting to go wrong / Cons: strangers can still open issues and pull requests that will be ignored
  - B) Turn issues off and limit pull request creation to collaborators — Pros: no outside issues or pull requests; the maintainer's and release-please's pull requests keep working / Cons: GitHub doesn't document whether `github-actions[bot]` counts as a collaborator
  - C) Turn pull requests off — Pros: the strongest block / Cons: stops the maintainer's pull-request flow and release-please
- **Decision**: B, at the maintainer's request. Private vulnerability reporting was turned on as well, so a security report still has a private channel.
- **Consequences**: The README's Contributing section and `CONTRIBUTING.md` say outside contributions aren't accepted. If the next release-please run can't open its pull request, set `pull_request_creation_policy` back to `all`. With issues off, `/issues/N` links to pull requests still redirect to `/pull/N` (checked on two of them), so release-please's changelog links keep working.

### ADR-026: Lint CHANGELOG.md in CI
- **Date**: 2026-09-28
- **Status**: accepted
- **Context**: The Markdown Lint job in `.github/workflows/validate.yml` excluded `CHANGELOG.md` (`!CHANGELOG.md`), so it carried 52 errors no check reported: 51 × MD012, because release-please puts two blank lines under every version heading, and 1 × MD037 on unquoted `_shared/` / `_templates/`. release-please inserts each new release under the file's header and never rewrites it (`src/updaters/changelog.ts` splits at the first `\n###? v?[0-9[]`), so a directive in the header survives releases.
- **Options**:
  - A) Keep the exclusion — Pros: no change / Cons: the changelog stays unlinted; hand edits to it, like the historical link refreshes, go unchecked
  - B) Disable MD012 in the changelog header and lint it in CI — Pros: every other rule applies to the changelog; release-please output stays valid / Cons: an extra lint directive at the top of a generated file
  - C) Remove the double blank lines by hand and lint it — Pros: no directive / Cons: every release adds them back and fails CI
- **Decision**: B, at the maintainer's request. MD037 was fixed by quoting the directory names.
- **Consequences**: `CHANGELOG.md` opens with `<!-- markdownlint-disable MD012 -->`; CI lints it like every other Markdown file, in both places that run Markdown Lint: the `Validate` workflow and the release workflow's `validate-release-pr` job, which posts its own "Markdown Lint" status on release PRs. (The first change removed the exclusion from `validate.yml` only, so a broken changelog on a release PR showed one red and one green "Markdown Lint"; the release workflow was aligned on 2026-09-28.) Should release-please change its entry format, the release PR's Markdown Lint check reports it.

### ADR-025: Make the repository public
- **Date**: 2026-09-27
- **Status**: accepted
- **Context**: The repository had been kept private so users would get the product only through the npm package. On a private repository GitHub Actions spends the plan's monthly minutes, and GitHub warned the limit was close. The npm package already carries every file a user installs; privacy only hid the history, issues and maintainer files.
- **Options**:
  - A) Keep it private — Pros: history and maintainer files stay hidden / Cons: CI and releases spend paid minutes; no npm provenance; the curl install route doesn't work for users
  - B) Make it public — Pros: free Actions minutes; npm provenance; curl install works; outside contributions become possible / Cons: the full history and internal files are visible to anyone
- **Decision**: B, at the maintainer's request. The history was checked for secrets before the switch; the only key found is the AWS documentation example the tests use.
- **Consequences**: The release workflow publishes with `--provenance` again. The README offers curl as an alternative to npm; the Claude Code plugin route stays out of it until its manifest points at the kit's skills, agents and hooks. ADR-024's naming stands: GitHub owner `lucasfelipe24`, npm scope `lucasfelipe23`.

### ADR-024: Publish the npm package under the @lucasfelipe23 scope
- **Date**: 2026-09-27
- **Status**: accepted
- **Context**: The first npm publication (release `v1.22.1`) failed with `404 Scope not found`: the package was named `@lucasfelipe24/agent-code-kit`, but the maintainer's npm username — and therefore the only scope `NPM_TOKEN` can publish to — is `lucasfelipe23`. The GitHub repository stays `lucasfelipe24/agent-code-kit` and private. The package had never been published, so no installed user depends on the old name.
- **Options**:
  - A) Rename the package to `@lucasfelipe23/agent-code-kit` — Pros: publishes with the existing npm account and token / Cons: npm scope and GitHub owner differ.
  - B) Create an npm account named `lucasfelipe24` — Pros: npm and GitHub names match / Cons: a second npm account and token to maintain.
- **Decision**: A. The npm scope must be the npm username; the GitHub URLs (`repository`, `homepage`, plugin marketplace, raw install URLs) keep `lucasfelipe24` because they point at GitHub.
- **Consequences**: Install with `npx @lucasfelipe23/agent-code-kit init`. `v1.22.1` exists as a git tag and GitHub release only; the first npm version is the next patch, `1.22.2`, because the `v1.22.1` tag's `package.json` still carries the old name.

### ADR-005: Bash output budget observability (PostToolUse signal hook, non-blocking)
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: The kit ships 18 hooks watching Edit/Write but zero observability on Bash output. Empirically, Bash output (test logs, diff dumps, find/rg results) is the #1 context-window consumer in agentic sessions — frequently 30K+ tokens before the agent realises compaction is near. Inspired by [rtk](https://github.com/rtk-ai/rtk)'s core observation about command output dominance, but rtk's approach (lossy proxy-rewrite) conflicts with the kit's titiz / fidelity-preserving stance. The gap to close is awareness, not silent compression.
- **Options**:
  - A) **Adopt rtk-style proxy rewrite** — wrap Bash to rewrite verbose output (truncate, summarise). Pros: directly reduces tokens. Cons: lossy, hides information the agent might need, violates "verbatim outputs" expectations, introduces a wrapper layer.
  - B) **Signal-only PostToolUse hook** — track cumulative `len(stdout)+len(stderr)` per session as a `chars/4` token estimate; emit one-shot stderr warning at `$BASH_BUDGET_THRESHOLD` (default 50K). Pros: zero lossy behaviour, deterministic, no deps, low maintenance. Cons: doesn't reduce tokens itself — agent must react.
  - C) **Per-command policy with replacement suggestions** — hook inspects the command and rewrites verbose forms (e.g. `git status` → `git status --short`) before they run. Pros: actually saves tokens. Cons: surprising rewrites, command semantics shift mid-session, breaks scripts that parse output, much more code to maintain.
- **Decision**: B (signal-only). Rationale: the kit's hook philosophy is "measure and block", not "rewrite silently". Awareness + a `Compact Output Flags` table in `agent_docs/conventions.md` lets the agent react with full agency. The hook never alters behaviour; it only annotates the cost.
- **Sub-decisions**:
  - **Threshold default 50000 tokens** — covers ~200K chars stdout, roughly the point where compaction risk becomes material on a 200K-context model.
  - **One-shot warning per session** (`warned: true` latch) — repeating the warning every call past threshold would become noise; the agent already has the signal.
  - **`chars / 4` heuristic, no tokeniser** — deterministic, no Python/tokeniser dependency, accurate enough for a threshold signal (true token count would be marginally different but not directionally).
  - **First two words of the command** as the `by_command_top5` bucket key — distinguishes `git diff` from `git status` without proliferating one-off keys per file argument.
  - **Profile**: standard + strict (mirrors quality-gate). Observability is core, not opt-in.
- **Consequences**:
  - New hook `.claude/hooks/bash-budget.sh` (PostToolUse, matcher `Bash`)
  - New state file `.hook-state/bash-budget.json` (schema_version 1; self-gitignored via existing `.hook-state/.gitignore` pattern)
  - New env var `BASH_BUDGET_THRESHOLD` (escape hatch / tuning knob)
  - `agent_docs/conventions.md` gains a `## Compact Output Flags` reference table
  - `agent_docs/hooks.md` PostToolUse table gains a `Matcher` column (now that two matchers coexist there)
  - The hook reads `tool_response.stdout/stderr` directly via `jq` / `python3` because `lib/json-parse.sh` only handles `tool_input.*`. If a third hook needs `tool_response.*`, factor that into the shared lib.

### ADR-006: Typed-relation graph for lessons (zero-LLM, frontmatter-driven)
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR-005 lives in a sibling v1.11.0 PR (bash-budget hook). Numbering assumes that PR lands first; if order changes, this becomes ADR-005 and the sibling becomes ADR-006.
- **Context**: `tasks/lessons/` works well at ~10 lessons. At 50+, the flat `_index.md` index loses signal: superseded rules sit next to current ones, the agent can't tell which guidance is fresh, and silent contradictions accumulate. Inspired by [GBrain](https://github.com/garrytan/gbrain)'s **zero-LLM typed-edge knowledge graph** — relations between lessons should be explicit, deterministic, and parseable without inference. The kit can adopt the same pattern at much smaller scale: lesson-to-lesson and lesson-to-decision links carried in YAML frontmatter.
- **Options**:
  - A) **Typed YAML fields + python graph script** — extend `_TEMPLATE.md` with `supersedes`, `applies_to`, `contradicts`, `related_decisions`; ship `scripts/lesson-graph.sh` to parse, validate, and rewrite `_index.md` auto-sections. Pros: deterministic, zero third-party deps (bash + python3 stdlib), fast, idempotent, fits the kit's "ship a script + a template" pattern. Cons: a tiny custom YAML subset to maintain (no nested maps, no block lists — only what the kit's frontmatter actually uses).
  - B) **Adopt a real graph DB / SQLite cache** — store lessons in a structured store, query the index from the store. Pros: scales arbitrarily. Cons: massive overkill for ~10–50 records, introduces runtime + persistence, breaks the kit's "just markdown" promise.
  - C) **LLM-extracted relations** — let Claude infer `supersedes`/`contradicts` by reading lesson bodies on demand. Pros: no schema change. Cons: non-deterministic, expensive at session boot, contradicts the kit's hook philosophy ("use prompts for guidance; use code for behavior that should run every time").
  - D) **Status quo: rely on the `related: []` field + manual `_index.md`** — no schema change, no script. Pros: no work. Cons: the problem the issue describes (silent contradictions, stale Top Rules) is exactly what status quo produces.
- **Decision**: A (typed fields + graph script). Rationale: the kit's whole positioning is *deterministic discipline* — relation extraction must follow the same rule. Bash + python3 + a ~200-line script is the natural shape; it slots next to `migrate-lessons.sh` / `build-skills.sh` / `validate-skills.sh`. The new fields are **additive and optional**, so existing lessons remain valid with no migration cost.
- **Sub-decisions**:
  - **Keep the legacy `related: []` field**. It's free-form and untyped — useful for cross-references that don't fit a typed slot. Removing it would be a breaking change for whoever already filled it in.
  - **Auto-generate four sections, splice into `_index.md` between marker comments**. Markers (`<!-- BEGIN/END AUTO-GENERATED <name> -->`) allow the script to be idempotent and let humans freely add manual prose around them.
  - **Section order**: Top Rules → By Topic → Recently Added → Superseded. Top-of-mind first, archive-of-mind last. Format Reference and Lifecycle (manual prose) live below the auto sections.
  - **Custom YAML parser, not PyYAML**. The kit ships no Python dependencies; PyYAML would force a `pip install` step. The parser handles only the subset the lesson format uses (flat keys, inline lists, scalars) and rejects anything else with a clear error.
  - **`--check` mode for CI / pre-commit**. Exits non-zero when any warning is emitted; teams can wire this into `.github/workflows/validate.yml` without committing the generated `_index.md`.
  - **Lesson-refresh skill consumes the warnings**. New "Phase 1.5: Graph signals" in `SKILL.md` maps each warning class to a verdict bias, so periodic refreshes resolve graph debt as a normal byproduct.
- **Consequences**:
  - `tasks/lessons/_TEMPLATE.md` gains 4 optional frontmatter fields: `supersedes`, `applies_to`, `contradicts`, `related_decisions`
  - New script `scripts/lesson-graph.sh` (bash wrapper + python3 graph + writer)
  - `tasks/lessons/_index.md` restructured: 4 auto-generated sections between markers, manual prose (Format Reference, Lifecycle) follows
  - `.claude/skills/lesson-refresh/SKILL.md` gains a "Phase 1.5: Graph signals" block that maps each graph warning to a verdict bias
  - `install.sh` `--gitignore` listing gains `scripts/lesson-graph.sh` (kit-managed, like its siblings)
  - The shipped example lesson `2026-04-15-example-tsconfig.md` is migrated to use `applies_to: [scope-discipline, tooling]` as a real-world demonstration of the new schema
  - Validation warnings detect: `supersedes-target-missing`, `contradicts-target-missing`, `supersedes-cycle` (transitive), `contradicts-loop` (mutual), `top-rule-but-superseded`

### ADR-007: Session scorecards — structured metrics emitted by SessionEnd, aggregated by /scorecard
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — bash-budget → lesson graph → this PR. If merge order changes, renumber accordingly.
- **Amended 2026-09-30 (brownfield milestone)**: the audit log moved from `reports/session-audit.log` to `.hook-state/session-audit.log`. `reports/` is a common project folder name and the hook only created `reports/.gitignore` when missing, so a project with its own `reports/.gitignore` saw the log in `git status`. The hook now creates `.hook-state/.gitignore` and never touches `reports/`; `--upgrade` moves an existing log (appended ahead of any new lines) and removes the kit's own `reports/.gitignore`. Everything else in this ADR stands.
- **Context**: `session-end.sh` already writes a one-line audit record per session, but the v1 line only carries identifiers + `last_quality_gate`. The kit makes behavioral claims ("staff-engineer behavior", "disciplined process") but offers no per-session evidence — those claims remain a vibe question. Inspired by GBrain's `founder scorecard` pattern: structured assertions rolled into a stable JSON contract over time. Without per-session counts of hook fires, quality-gate runs, edits, and bypasses, there's no signal for whether the kit's discipline rules are actually firing.
- **Options**:
  - A) **Schema_version 2 enrichment + dedicated `/scorecard` skill** — extend session-end to aggregate `.hook-state/*` files plus the transcript into a metrics object; add a `/scorecard` skill that reads the windowed audit log and renders a markdown table. Pros: builds on the existing JSONL log (no new persistence layer), keeps v1 parsers working, surfaces a single readable summary. Cons: requires touching every blocking hook to add the counter bump.
  - B) **Telemetry to an external endpoint** — POST per-session metrics to a hosted collector. Pros: enables cross-machine aggregation. Cons: violates the kit's "no external services, no API keys" principle; adds privacy + reliability surface.
  - C) **Pure prompt-based reporting** — at session-end, ask the agent to summarize its own session. Pros: zero infrastructure. Cons: non-deterministic, the agent can omit/inflate, defeats the "deterministic measurement" point.
  - D) **Skip — let users run `/retro` for narrative review** — `/retro` already exists. Pros: no work. Cons: `/retro` is narrative + qualitative; it can't answer "did stop-gate actually fire 3 times this week?" deterministically.
- **Decision**: A (enrich + `/scorecard` skill). Rationale: the schema_version 2 record gives the kit a stable, machine-readable contract; v1 records remain valid (additive change, not breaking); the new `/scorecard` skill closes the loop with a human-readable view. The counter-bump pattern is minimal (one helper call per blocking hook, ~5 lines each); the shared `lib/state-counter.sh` keeps it DRY.
- **Sub-decisions**:
  - **Counter bump on `exit 2` only, not on every hook run**. The metric we want is "how often did the agent try to do something we blocked?", not "how often did the hook fire". A passing run is a non-event; a blocked run is the signal.
  - **`/scorecard` is a skill, not a script**. Aggregation requires judgment about windowing and threshold callouts that fit the agent's natural workflow. A shell script would force users to memorize flags; the skill lets `/scorecard --window 30d` flow naturally.
  - **`lessons_added` and `decisions_added` are mtime-based**, not git-aware. "Was the lesson archive evolved this session?" is the right question; whether the agent created a new file vs. edited an existing one is noise.
  - **`compactions_observed` is best-effort** from transcript parsing. The kit doesn't own Claude Code's transcript wire format, so over/under-counts are acceptable as long as the trend is informative. If the schema changes upstream, this field can be dropped — it's optional.
  - **Profile**: enabled in **standard** and **strict** (same as `quality-gate`). Observability of discipline is core, not opt-in.
- **Consequences**:
  - 5 blocking hooks (`protect-files`, `protect-changes`, `branch-protect`, `block-dangerous-commands`, `stop-gate`) each gain a one-line `bump_counter` call before their `exit 2`
  - `quality-gate.sh` writes both `last_quality_gate.json` (existing) and `quality-gate-history.json` (new cumulative runs / failures / last_status)
  - `stop-gate.sh` bumps `skip_gate_used` in the history file when the `SKIP_QUALITY_GATE` env is honored
  - `session-start.sh` writes `.hook-state/session-meta.json` (session_id, started_at, started_at_epoch) and resets stale `.hook-state/hook-firings.json`, `quality-gate-history.json`, `bash-budget.json` from any prior session
  - `session-end.sh` is rewritten: schema_version 2 records carry the full `metrics` object alongside the v1 top-level fields (timestamp, event, session_id, reason, transcript_path, last_quality_gate). v1 parsers continue to work because the v1 fields are preserved verbatim.
  - New shared lib `.claude/hooks/lib/state-counter.sh` (`bump_counter`, `reset_state`)
  - New skill `.claude/skills/scorecard/SKILL.md` — `/scorecard` invokes the aggregator (read-only against `reports/session-audit.log`)
  - `agent_docs/hooks.md` State Files table grows from 2 rows to 5; new helper lib mentioned in `lib/` reference
  - Backward compat: if `python3` is unavailable on the target machine, `session-end.sh` falls back to the v1 single-line shape. The block counters and quality-gate history simply don't accumulate in that environment.

### ADR-008: KitBench — reproducible eval harness for the kit's deterministic-enforcement claims
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — bash-budget (ADR-005) → lesson graph (ADR-006) → session scorecards (ADR-007) → this PR. Renumber on merge order changes.
- **Context**: The kit promises *deterministic enforcement* (ADR-003) and ships 18+ hooks. But hooks are bash scripts whose correctness depends on hard-to-test regex/grep semantics — and the v1.10.0 review caught multiple specific bugs (composer.lock slip-through in `protect-files`, `EXIT_CODE=$?` after `|| true` in `quality-gate`, basename-with-slash miss on `.github/workflows/ci.yml` in `protect-changes`, word-boundary regex rejecting "authentication" in `prompt-router`). Without a regression bench, those bugs were found by accident; the next analogous bug will be found by accident too. Inspired by [GBrain's BrainBench](https://github.com/garrytan/gbrain-evals) — *kits that make behavioural claims should ship benchmarks for those claims*.
- **Options**:
  - A) **Deterministic JSON-scenario harness** — each scenario is a single JSON file in `bench/scenarios/`: hook to run, setup files, stdin payload, env overrides, and expected assertions (exit code, stderr/stdout substrings, state-file fields, file existence). A runner (`scripts/run-bench.sh`) iterates them in isolated temp dirs and prints pass/fail. Pros: zero LLM, zero deps beyond `python3 + bash`, fast (<5s for 15 scenarios), trivial to add regression cases. Cons: doesn't cover end-to-end session behaviour — only the individual hook contracts.
  - B) **LLM-graded end-to-end evals** — drive a real Claude Code session, score the output. Pros: tests the whole stack. Cons: non-deterministic, slow, expensive, and the failure modes the kit cares about (a regex bug missing `.env.production`) don't show up as model-output differences.
  - C) **Per-hook unit tests in bash** — write `bats` or `shunit2` tests next to each hook. Pros: idiomatic for shell. Cons: adds a test framework dependency, harder to express "the state file must contain field X with value Y", harder to make scenarios self-contained portable JSON.
  - D) **Skip — rely on manual smoke testing per PR** — the status quo. Pros: no work. Cons: doesn't catch regressions, doesn't surface as a credibility marker, doesn't scale with the hook count.
- **Decision**: A (JSON-scenario harness). Rationale: matches the kit's existing tooling shape (bash scripts + python3 stdlib for JSON, no third-party deps), produces clear pass/fail output suitable for CI, and the scenario file format is friendly enough that adding a regression case takes <5 minutes (one JSON file, no boilerplate). The deliberate non-coverage of end-to-end Claude Code behaviour is intentional — the bench validates the *kit's deterministic surface*, not model behaviour.
- **Sub-decisions**:
  - **One scenario per file, one assertion bundle per scenario.** Scenarios as a flat list in `bench/scenarios/*.json` (alphabetical by filename = run order). One file per scenario is easier to grep, diff, and review than a multi-document `scenarios.json`.
  - **Each scenario runs in a fresh temp dir.** No shared state between scenarios. `setup_files` provides the initial state. The hook's writes (e.g. `.hook-state/last_quality_gate.json`) stay scoped to that temp dir, then it's deleted.
  - **`{TMPROOT}` / `{KIT_ROOT}` template substitution in string values** lets payloads reference absolute paths inside the per-scenario temp dir.
  - **Runner is `scripts/run-bench.sh`** — bash wrapper around python3, follows the same pattern as `scripts/lesson-graph.sh`. `--scenario`, `--filter`, `--verbose`, `--json` flags. Exit codes: 0 all pass / 1 some failed / 2 runner error.
  - **CI integration via `.github/workflows/validate.yml`** — a new `kitbench` job runs every PR. Failure blocks merge.
  - **`bench/` is kit-internal**, not user-facing. Users running `install.sh` don't get `bench/` — it's only meaningful for kit maintainers running tests on the kit itself. The shipped `scripts/run-bench.sh` exits 2 with a clear message when invoked outside the kit checkout (no `bench/scenarios/` present).
  - **Initial corpus of 15 scenarios** seeded from: (a) the lifecycle hook surface — one happy-path + one failure path per hook contract, and (b) every bug caught during the v1.10.0 code review, converted into a regression scenario. Notably, scenarios s02, s05, s08, s12 are all direct regression coverage of known historical bugs.
- **Consequences**:
  - New top-level `bench/` directory containing `README.md` + `scenarios/sNN-*.json` files
  - New script `scripts/run-bench.sh` (bash wrapper + python3 runner)
  - CI gains a `kitbench` job in `.github/workflows/validate.yml`
  - All 15 initial scenarios pass on the current kit (verified locally on this branch)
  - Adding a regression case is now a single-JSON-file change — no boilerplate, no test framework setup
  - Bench surfaces in `bench/README.md` as a credibility marker; future README work can reference it
  - The bench is local-only, no external services, no API keys

### ADR-009: Ship a Claude Code plugin marketplace entry (scaffold-first)
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — bash-budget (ADR-005) → lesson graph (ADR-006) → scorecards (ADR-007) → KitBench (ADR-008) → this PR. Renumber on merge order changes.
- **Context**: The kit currently distributes via `npx @lucasfelipe24/agent-code-kit init`, `curl install.sh | bash`, and `cargo install --git`. Missing from this list is Anthropic's [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugins) — the canonical discoverability surface for Claude Code users browsing for kits. [karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) ships as both `CLAUDE.md` *and* a marketplace plugin (`/plugin marketplace add forrestchang/andrej-karpathy-skills`), and a meaningful share of its 135K stars likely come from that surface. Without a plugin listing, the kit is invisible to that browse-and-install audience.
- **Marketplace mechanics (from official docs)**:
  - Plugin manifest at `.claude-plugin/plugin.json` (JSON, not YAML)
  - Skills must live at the plugin **root** as `skills/<name>/SKILL.md` — Claude Code does not look in `.claude/skills/`
  - Hooks must live at the plugin root as `hooks/hooks.json` — Claude Code does not consult `.claude/settings.json`'s hooks block from a plugin's perspective
  - Plugins are namespaced: a skill `hello` in plugin `agent-code-kit` becomes `/agent-code-kit:hello`
- **Options**:
  - A) **Scaffold + manifest only (this PR)** — ship `.claude-plugin/plugin.json` + README install path + this ADR. Defer the actual content packaging (skills/, hooks/, agents/) to a follow-up. Pros: ships a real, submittable manifest in v1.11.0; doesn't block the rest of the inspiration triad; no duplication. Cons: clicking install on the marketplace today would give the user metadata but no functional skills/hooks.
  - B) **Full duplication** — copy all 24 skills from `.claude/skills/` → `skills/`, convert `.claude/settings.json` hooks → `hooks/hooks.json`, copy `.claude/agents/` → `agents/`. Pros: works on first install. Cons: every kit change now requires updating two copies; either drift or a build step (deferred infrastructure work).
  - C) **Curated subset** — pick ~3 high-value skills (e.g. `debug`, `ship`, `scorecard`, `lesson-refresh`) and the 5 blocking hooks, duplicate just those. Pros: works on first install with a small surface. Cons: still dual-source-of-truth; the curation criterion becomes a question we have to defend.
  - D) **Build-time generator (`scripts/build-plugin.sh`)** — write a script that copies `.claude/skills/` → `skills/`, converts hooks, and bumps `version` from `VERSION`. Run pre-commit or pre-release. Pros: single source of truth (`.claude/`), generated plugin tree is always fresh. Cons: meaningfully more code; needs CI integration; would balloon this PR.
- **Decision**: A (scaffold-first). Rationale: the v1.11.0 batch is already six issues large, and the *blocker* for marketplace discoverability is the manifest existing in the repo with `version: 1.11.0` and a stable URL — not the contents being functional from day one. Submitting the listing happens after merge anyway (in-app form at [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit)), giving us a natural moment to land the content packaging in v1.12.0 before the listing goes live. Option D is the right *long-term* shape and should be the next PR after v1.11.0 ships.
- **Sub-decisions**:
  - **`version` field set to current kit version (1.10.0 at PR-open time)** — Claude Code uses this for update tracking. Plumbed forward in v1.11.0 via release-please.
  - **`repository` and `homepage` populated** — homepage points at the web docs site so the marketplace listing has a real landing page.
  - **`license: MIT`** — matches the repo's LICENSE file. Required for community-managed plugins.
  - **No `category` field** — Anthropic's marketplace schema includes a `category` enum (development, security, productivity, etc.) but that lives in the *marketplace.json* registry entry, not in our `plugin.json`. We don't need to pick a category here.
  - **README documents both paths side by side** — keeps npx/curl as the canonical "full kit" install and marks the plugin path as lightweight / discoverable. Avoids the "which do I use?" confusion.
- **Consequences**:
  - New file `.claude-plugin/plugin.json` (JSON manifest, valid against the marketplace schema)
  - `README.md` Quick Start gains a third install path + a comparison table
  - Submission to the marketplace happens out-of-band (manual step by maintainer at `claude.ai/settings/plugins/submit`) — not part of CI
  - **Follow-up required** (v1.12.0 candidate): land Option D — a build step that produces `skills/`, `hooks/hooks.json`, and `agents/` from the `.claude/` sources. Until then, installing via `/plugin install` gives users metadata only.
  - No risk to existing distribution channels: `install.sh`, `npx`, `cargo install --git` are untouched.

### ADR-010: Adopt OpenAI harness-style `docs/` structure as an opt-in scaffold (`/harness-init`)
- **Date**: 2026-05-18
- **Status**: accepted
- **Note**: ADR numbering assumes the v1.11.0 batch merges in this order — bash-budget (ADR-005) → lesson graph (ADR-006) → scorecards (ADR-007) → KitBench (ADR-008) → plugin marketplace (ADR-009) → this PR. Renumber on merge order changes.
- **Context**: [OpenAI's harness engineering write-up](https://openai.com/index/harness-engineering/) documented their move from one growing CLAUDE.md / AGENTS.md toward a thin ~100-line CLAUDE.md that points at a structured `docs/` tree (ARCHITECTURE / DESIGN / PLANS / QUALITY_SCORE / RELIABILITY + design-docs/exec-plans/references). Their explicit claim: a single large CLAUDE.md does not scale — *"context limited, too much guidance becomes disorientation, rots fast, hard to verify"*. The kit's current shape mirrors what OpenAI moved away from.
- **Options**:
  - A) **Opt-in scaffold via a new skill** (`/harness-init`) — ship templates in `.claude/skills/harness-init/templates/`, scaffold `docs/` only when invoked, document via a new `## Harness Docs` section in `CLAUDE.md` gated on `docs/ARCHITECTURE.md` presence (same shape as the existing WIKI/ARTIFACTS sections). Pros: zero impact on users who don't want the pattern; mirrors the kit's existing opt-in module shape. Cons: adoption requires explicit user action.
  - B) **Default-on scaffold** in `install.sh` — every `install.sh` run creates `docs/`. Pros: more visible. Cons: opinionated default contradicts the kit's "everything you don't ask for, you don't get" principle; existing projects with `docs/` would conflict.
  - C) **Replace `agent_docs/` with `docs/`** — rename the kit's own structure. Pros: ideological alignment. Cons: breaking change; `agent_docs/` semantics (agent behaviour guides) don't map cleanly onto OpenAI's project-knowledge `docs/`.
  - D) **Skip — point users at OpenAI's write-up if they want it** — no kit support. Pros: zero work. Cons: misses the chance to make the pattern one command away.
- **Decision**: A (opt-in scaffold via `/harness-init`). Rationale: the kit's value is *opinionated discipline*, not *opinionated knowledge architecture*. The harness pattern is genuinely useful past a certain project size, but premature for small ones — exactly the situation that warrants opt-in. The skill ships templates so the scaffold is consistent across users; the `CLAUDE.md → Harness Docs` section is conditional on `docs/ARCHITECTURE.md` existing so it's invisible for projects that haven't scaffolded.
- **Sub-decisions**:
  - **Skill, not script.** `/harness-init` is a `SKILL.md` (Claude reads instructions and creates files) rather than a `scripts/harness-init.sh`. Rationale: the skill needs per-file idempotency decisions, which is easier to phrase as an agent task than to encode in shell. The skill files act as the *contract*; consistency comes from `templates/`.
  - **`agent_docs/` and `docs/` coexist.** `agent_docs/` stays the kit's *agent-facing* guidance (workflow, conventions, hooks). `docs/` is the project's *system-facing* knowledge (architecture, plans, reliability). No rename, no migration — they serve different purposes and the boundary is clear from the directory names.
  - **CLAUDE.md addition is gated on `docs/ARCHITECTURE.md` existence.** Matches the existing `## Design System` / `## Knowledge Wiki` / `## HTML Artifacts` pattern; a no-op for projects that haven't scaffolded.
  - **`docs/QUALITY_SCORE.md` and `docs/references/` are reserved for sibling features** — `/quality-audit` writes to QUALITY_SCORE.md; `/references-sync` populates `references/`. The seed templates mention this so users know what fills in over time.
  - **CI cross-link freshness check is deferred.** The issue's AC mentioned a CI/lint hook for `docs/` ↔ CLAUDE.md link freshness — a non-trivial markdown-link checker that doesn't fit this PR's scope.
- **Consequences**:
  - New skill at `.claude/skills/harness-init/SKILL.md`
  - 10 template files under `.claude/skills/harness-init/templates/` (README, ARCHITECTURE, DESIGN, PLANS, QUALITY_SCORE, RELIABILITY, design-docs/{index,core-beliefs}, exec-plans/tech-debt-tracker, product-specs/index)
  - `CLAUDE.md` gains a `## Harness Docs` section, conditional on `docs/ARCHITECTURE.md` (same pattern as Knowledge Wiki / HTML Artifacts)
  - `CODEBASE_MAP.md` skill listing adds the new skill
  - Zero effect on users who don't invoke `/harness-init` — the section in CLAUDE.md is inert until they scaffold
  - **Follow-up (v1.12.0 candidate)**: CI cross-link freshness check between `docs/` and `CLAUDE.md`; also an `install.sh --harness` flag that auto-scaffolds on install for users who want it from day one.

### ADR-011: Quality drift audit via `golden-principles.yaml` + separate `/doc-gardening` skill
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: OpenAI's harness-engineering writeup describes "Fridays for AI cleanup" — periodic background tasks that scan for drift from golden principles, update quality scores, and propose refactors. The pattern doesn't scale at OpenAI when run as one-off rituals; codifying the principles into a YAML and running a deterministic checker does. The kit already has `/code-quality-audit` (generic smells) and `/documentation-audit` (completeness/clarity), but no skill for **project-specific** rules that change per repo, and no skill watching for **doc-vs-code drift** as opposed to doc quality.
- **Options**:
  - A) **Two new skills + YAML schema** — `/quality-audit` reads `golden-principles.yaml` and writes `docs/QUALITY_SCORE.md`; `/doc-gardening` cross-checks docs/ against the codebase. Clean separation of concerns. Each can run on its own `/loop` schedule.
  - B) **Extend `/code-quality-audit`** — add a `golden-principles.yaml` mode to the existing skill. Less surface area but conflates two ideas (generic smells vs project-specific rules) and the report shape differs.
  - C) **One mega-skill** — combine quality drift + doc drift into `/audit-drift`. Single entry point but the YAML schema only applies to half of it, making the skill awkward to extend.
- **Decision**: A (two new skills + YAML). Rationale: the two concerns have different inputs (YAML vs filesystem), different outputs (`docs/QUALITY_SCORE.md` vs `tasks/todo.md → ## Doc Drift`), and different cadences (daily vs weekly per OpenAI's recipe). Separation also lets either skill be turned off without affecting the other.
- **Sub-decisions**:
  - **YAML schema is deliberately minimal** — `id / rule / severity / detect / fix_hint` plus optional `paths / tags / enabled`. No AST queries built in; instead, the `command:` detect type lets users shell out to their own linter/Semgrep/etc. Keeps the skill an orchestrator, not an analyzer.
  - **Severity weights are fixed** (critical=5, major=2, minor=1). Score formula: `max(0, 100 - sum(weight × matches))`. Tunable later if needed, but starting opinionated.
  - **QUALITY_SCORE.md uses managed-block markers** — `<!-- quality-audit:start -->` / `<!-- quality-audit:end -->`. Content outside the block is preserved across runs so users can hand-edit context, trend annotations, etc.
  - **Quality-audit never creates `docs/`** — that's `/harness-init`'s job. Missing `docs/` → print to stdout, never auto-scaffold. Avoids a confusing surprise when a non-harness project runs the skill.
  - **Doc-gardening is heuristic** — false positives are expected. The `.doc-gardening-ignore` glob list + `docs/archive/` suppression keep the noise floor down. Findings are leads for human review, not auto-fixes.
  - **Both skills support `mode:headless`** for `/loop` and `/schedule` integration. Headless mode never opens PRs, never writes files outside the managed block, never asks questions — appends to `tasks/todo.md` instead so humans see results in the next session.
- **Consequences**:
  - 2 new skills: `.claude/skills/quality-audit/SKILL.md`, `.claude/skills/doc-gardening/SKILL.md`
  - 1 template: `.claude/skills/quality-audit/templates/golden-principles.example.yaml` (6 example principles covering type-safety, utils, architecture boundaries, error handling)
  - `CODEBASE_MAP.md` lists both new skills
  - No code outside `.claude/skills/` — both skills are pure markdown instructions; the agent executes detection rules at runtime
  - Pairs naturally with `/harness-init` (ADR-010) — that skill scaffolds `docs/QUALITY_SCORE.md`; this skill maintains it
  - **NOTE on numbering**: ADR-005..010 are reserved by sibling PRs (assumed merge order). If merge order changes, renumber to next free slot at merge time.

### ADR-023: Upgrade safety — the preview writes nothing, and a CLAUDE.md is the kit's only if it reads like one
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: A review of `--upgrade` and `--diff` (ADR-017, ADR-021) reproduced ten ways they lost or misreported user files. The `--diff` scratch copy kept symlinks, so its upgrade wrote through a linked `.claude/hooks` into the target and the backup went away with the scratch dir. The stale report trusted `.kit-manifest`, which older installs filled with the project's own scripts and skills, and told users to delete them. A retitled pre-baseline `CLAUDE.md` was swapped for an auto-detected template, and a `CLAUDE.md` written by `/init` — its first line is `# CLAUDE.md` too — was replaced as if it were the kit's generic template. An upgrade wrote into the existing file, so another hard link to it lost the user's content, and `chmod +x` over `*.sh` took the run down whenever a broken link sat among them. Smaller ones: the upgrade didn't count files it created outside the per-file path; a relative `--local` broke `--diff`; an upgrade without a hash tool left stale baseline hashes; an existing `.kit-new` was overwritten; .NET detection looked only at the root.
- **Options** (the two rules that needed a choice):
  - A file with no entry in `.kit-baseline`: A) **Replace it, keep the previous copy in `.kit-backup/` and name both in the log** — the route an install from before the record takes. B) Treat it as the user's own: keep it, offer `<file>.kit-new`, record nothing. B was written and then backed out: the record isn't complete enough for it. A plain re-run over an older install records only the two or three files it copied, and a plain upgrade records no module files, so kit files under such a record would be frozen as "yours" and never updated again — one more `.kit-new` per release (60 of them, measured over a few releases). A `#covers` line saying which parts of the kit a record covers repairs B, but the record is written from some fifteen places in `install.sh`, and one of them forgotten brings the freeze back. A file of the user's own replaced with a backup is recoverable; a safety hook frozen at an old version is not visible at all.
  - Stale candidates: A) baseline plus manifest, as before. B) **Baseline only**; in an install with no baseline, manifest paths are shown hedged and not counted. C) Baseline only, manifest ignored — pre-baseline installs would never hear of retired kit files.
- **Decision**: A for the first, B for the second, and:
  - `--diff` copies with `cp -RL`, then deletes any link left (BSD `cp` copies a broken one as a link). The preview names every kit path that is a symlink and where `--upgrade` will write through it.
  - An install "has a baseline" when `.kit-baseline` holds at least one file entry.
  - `CLAUDE.md` on upgrade: `--template` if given, else the baseline's `#template`, else the template its first line names — and that last one only when the file carries the kit's own `## Session Boot` section, since `/init` writes a `# CLAUDE.md` heading too. When none identifies it, it's left untouched and both `--diff` and `--upgrade` say so. Auto-detection only picks the template for a missing `CLAUDE.md`. .NET detection also finds a `.sln`/`.slnx`/`.csproj` up to three levels down when no root marker matches.
  - An update writes a new file — a temp file in the same directory, then `mv` — so another hard link to the old one keeps its content and a read-only kit file is replaced instead of stopping the run. `chmod +x` over the hooks and scripts can no longer end the run when a broken `*.sh` link sits among them.
  - `--upgrade` and `--diff` need `sha256sum`, `shasum` or `python3` and stop before changing anything without one. A fresh install proceeds, warns, and writes no `.kit-baseline`, so its first upgrade takes the no-baseline path rather than reading every file as the user's.
  - A kit copy never overwrites a `.kit-new`: it goes to the first free `.kit-new.<n>`. If an identical copy is already waiting, nothing is written and the file counts as kept.
  - Every file the upgrade creates counts as added. `--local` is made absolute when parsed.
- **Consequences**:
  - A file of the user's own at a kit path — their own `scripts/validate.sh`, say — is replaced by the kit's. The previous copy stays in `.kit-backup/<stamp>/` and the log names it, but the working copy is the kit's.
  - A `CLAUDE.md` the kit never wrote is never touched, so a project that wants the kit's has to ask for it with `--template`.
  - The hedged pre-baseline list appears in `--diff` only: the first upgrade rewrites `.kit-manifest` before its summary.
  - A broken symlink at a kit path still stops a real `--upgrade`, as before; the preview shows it as an addition.
  - `test-install.sh` has a case for each; 27 of its assertions fail against the previous installer.
### ADR-022: The quality gate fails closed — locked, session-scoped state, start-time snapshots, every checkout a session touched
- **Date**: 2026-09-11 (revised 2026-09-12 after a second review)
- **Status**: accepted
- **Context**: A review of the gate (ADR-018, ADR-019) reproduced eight ways a stop got through with a failure on record:
  - a session whose `cwd` moved into a git worktree read only the worktree's state;
  - a slow scope-wide pass overwrote a later run's failure and re-hashed content it never checked;
  - concurrent writers shared one temp file with no lock (1 of 12 records kept), and a torn state file loaded as empty;
  - a `python3` that exists but fails (the macOS xcode-select stub) read as "no status";
  - a finished check's leftover process held the output pipe past the limit, and the perl fallback leaked the tool it started;
  - a UnicodeEncodeError at stop read as "nothing blocks";
  - a declared command "verified" a file outside the project.

  Nearly every one was a reader or writer error swallowed by `2>/dev/null || true` and read as "nothing failed". A second review of the first fix found more:
  - the broken python3 now failed every valid `.py` edit;
  - an unwritable `.hook-state` or a full disk still lost results under `set -e`;
  - without a usable python3 only the last run counted;
  - an edit into another worktree by absolute path was never read at stop;
  - renaming or deleting a file hid a scope-wide failure;
  - a second session's SessionStart deleted the first session's failures;
  - ending a finished check's process group killed build servers (every dotnet build cold, ~1.0s → ~2.9s) and waited 3s on a TERM-ignoring leftover;
  - a SIGTERM left the check running;
  - stale re-verification had no total time bound.
- **Options**:
  - A) **Patch each case** where it was found. Small, but the next swallowed error fails open the same way.
  - B) **Fail closed at every boundary**: an error reading or writing gate state blocks, and the state itself is safe under concurrency, slow runs and parallel sessions.
- **Decision**: B.
  - **Locked, atomic state.** Every load-modify-save of `quality-gate-state.json` holds an exclusive `fcntl.flock` on `quality-gate-state.json.lock` and writes a unique `mkstemp` file renamed into place. A state that exists but can't be parsed raises; stop-gate blocks with how to reset it.
  - **Unrecordable results block.** A result that can't be recorded makes the run `error`. The file is noted in `.hook-state/quality-gate-unrecorded`, or — when nothing can be written there — in `${TMPDIR:-/tmp}/ack-gate-<key of the project>`, and quality-gate exits 2 so its stderr reaches Claude. stop-gate blocks on noted files until a record exists, and on a `.hook-state` that exists but isn't writable. A project nobody edited is never blocked.
  - **Start-time snapshots.** Runs are numbered at start (`seq`, `runs[scope].started`) with a snapshot of the scope's file hashes (`pending`). A run records nothing once a later run of its scope has started; a scope-wide pass re-covers only files unchanged since it started; the edited file keeps its start-time hash.
  - **Session scope.** Every record carries the payload's `session_id`, and stop-gate answers only for its own session's records; a record or a stop without one counts everywhere. That rule is per record everywhere it is applied, including the bash fallback used when neither python3 nor jq is available: a mixed state — one record from before session scoping, one another session's — must not read as "not ours". session-start no longer deletes gate state; records older than 7 days are pruned. It does clear `last_quality_gate.json` when that summary carries no `session_id`: a pre-v2 summary would otherwise resolve to "-", count as every session's, and block an upgrading project's first stop before it had made an edit. A summary that names a session is kept.
  - **Every checkout the session touched.** stop-gate checks the payload's `cwd`, `CLAUDE_PROJECT_DIR`, and every worktree the session stored results in: quality-gate notes those in `CLAUDE_PROJECT_DIR/.hook-state/quality-gate-roots`. Where results are written stays as ADR-018 decided.
  - **Moved content.** A scope-wide failure whose files were all renamed or deleted blocks until the scope runs again; a per-file failure goes away with its file.
  - **No usable python3.**
    - python3 counts only if it runs (`lib/python3.sh`); the ~40ms probe caches a "yes" in `${TMPDIR:-/tmp}/ack-python3-usable` while that file stays ours and newer than the python3 it names, and never caches a "no". Without a usable python3, quality-gate keeps a plain per-file log, `quality-gate-files.tsv`, with a content stamp (`cksum`, else the mtime). stop-gate reads it with bash alone: the latest line per file wins, and changed files are re-verified.
    - A per-file state that needs python3 to read blocks the session it holds records for; without jq that judgement is made per record, and any record visible to every session makes the state relevant.
    - A `.py` edit with neither ruff nor a working python3 is `skipped (tool-unavailable)`.
    - Helper I/O is forced to UTF-8.
  - **Time limits.**
    - The check's process group is killed on timeout, when the hook is signalled (TERM/INT/HUP), or when the hook disappears — not after a normal exit, so build servers stay warm.
    - Output goes to a file, so a leftover can't hold the hook. The perl fallback runs the check in its own group.
  - **Stop budget.**
    - Re-verification stops after `ACK_STOP_REVERIFY_BUDGET` (300s), and each re-run is capped by what is left. Claude Code kills a Stop hook at its timeout (600s by default) and a killed hook doesn't block, so the budget stays well under it.
    - Stale files not re-verified in time block.
    - Any unexpected error in stop-gate exits 2.
  - **Project scope.** `commands.json` applies only to files under the project root.
- **Consequences**:
  - A corrupt or unwritable state blocks until it is fixed or reset (delete `quality-gate-state.json` and `last_quality_gate.json`), or `SKIP_QUALITY_GATE=1` is set.
  - Session scope trusts the payload's `session_id`; hooks run without one (manual runs, doctor) see every record.
  - A subagent's edits in its own worktree block the session's stop too (ADR-018 kept them apart): the session answers for every checkout it touched, not only after merge-back.
- **Amended 2026-09-12**: review of the first implementation found two holes, both fixed here. The no-python/no-jq relevance test was a whole-file test, so a failing record belonging to no known session was read as another session's and let through (fail-open); it now decides per record. And a pre-v2 `last_quality_gate.json`, which carries no `session_id`, blocked a fresh session's first stop on every upgrading project; session-start now clears a session-less summary.
  - Without python3 the log is per file: a scope-wide pass doesn't clear other files' failures there; they need their own check. With neither `cksum` nor `date -r`, a changed file can't be told from an unchanged one and blocks as stale.
  - What a finished check leaves running keeps running, by design. Under GNU `timeout` (Linux without python3) a signalled hook doesn't end its check before the limit.
  - KitBench s69–s93 (s89 is a guard that passes before too); s22, s51, s72–s74 and s80 were revised for the new semantics.

### ADR-021: `install.sh --diff` previews by running the real upgrade on a scratch copy
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `--diff` had its own comparison code, separate from `--upgrade`. It compared directories at their top level only, so `hooks/lib` and nested skill files were invisible. It reported user-owned `tasks/` and `CODEBASE_MAP.md` as "modified" though the upgrade never touches them, and it couldn't tell an update from a kept edit or a conflict. Its "up to date" meant only "no new files". It said nothing about stale kit files or hook registrations, and it ignored `--local`, so it couldn't be tested.
- **Options**:
  - A) **Fix the separate comparison** to mirror the upgrade's rules. Two implementations of the same decisions, bound to drift.
  - B) **A dry-run flag threaded through the installer** — every write guarded. Exact, but it touches every copy site and is easy to break.
  - C) **Run the target version's own `--upgrade` on a scratch copy** of the project's kit-managed files, then compare the copy with the project.
- **Decision**: C. The preview is exactly what the upgrade does — same code, same decisions — and nothing in the project changes. The findings the upgrade can't fix on its own are shared by `--diff` and the `--upgrade` summary:
  - **stale** — files the install record says the kit put there, which the kit no longer ships;
  - **unregistered** — standard kit hooks missing from `.claude/settings.json`;
  - **dangling** — registrations whose script doesn't exist.

  `.claude/settings.json` is never modified.
- **Consequences**:
  - `--diff` needs python3 and copies the kit-managed paths plus root marker files to a temp dir (seconds, small).
  - It honors `--local`, `--version`, `--profile`, `--template`, `--wiki` and `--html`, exactly as `--upgrade` would.
  - `test-install.sh` checks that the upgrade after a preview changes exactly what the preview named.
- **Amended 2026-09-11 (ADR-023)**: the scratch copy follows symlinks and then drops any link left, so the scratch upgrade can't write outside it; the preview names kit paths that are symlinks. "Stale" now needs a `.kit-baseline` entry. The upgrade counts every file it creates, so the preview's "to add" equals its "added".
- **Amended 2026-09-30 (ADR-032)**: `--upgrade` now changes `.claude/settings.json` — only the kit's hook entries (and missing strict `ACK_*` env keys), after a backup. `--diff` shows it as an update of `.claude/settings.json` with one line per entry (`+` added, `~` updated, `=` your edited entry kept, `-` removed), and stops reporting hooks the upgrade will register as unregistered.

### ADR-020: commands.json — an absent key auto-detects, "" turns a check off, anything unknown is an error
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `.claude/commands.json` is the single source of truth for the quality gate, `/ship` and the qa-reviewer, but it had no schema. A typo such as `"typcheck"` was silently ignored — the declared check never ran and the gate guessed a different one. `""` and an absent key both meant "fall back to guessing", so a project couldn't say "we have no lint"; whatever the gate guessed then counted as the project's check. There was no way to set the per-edit time limit, the fast/full split was implicit, and `doctor.sh` only warned about a broken file.
- **Options**:
  - A) **Stay lenient** — ignore unknown keys. Keeps odd files working; keeps typos invisible.
  - B) **Strict, stdlib-only validation** in `lib/project-commands.sh`, shared by the gate, stop-gate and doctor — known keys plus `"//"` comments and the legacy `commands` wrapper; `""` means "off".
  - C) **A JSON Schema file with a validator.** Standard, but it adds a dependency for six keys.
- **Decision**: B.
  - Keys: `typecheck`, `lint` (fast — the per-edit gate), `test`, `build`, `smoke` (full — `/ship` and the qa-reviewer, never per edit), `timeout` (seconds for the per-edit check; `ACK_QUALITY_GATE_TIMEOUT` wins).
  - Absent → auto-detect. `""` → the check is off: the gate records `skipped (disabled)` — NOT verified, never passed, nothing guessed — and `/ship` / the qa-reviewer report the step as not applicable.
  - An unknown key, a non-string command, or a non-positive `timeout` is a config `error`: the gate blocks and `doctor.sh` fails, naming the problem.
- **Consequences**:
  - A file with keys the kit doesn't read (say `"format"`) now blocks code edits until they're removed or turned into `"//"` comments; the error message says so.
  - KitBench s66–s68; `test-install.sh` covers doctor on a mistyped and a valid file.
- **Amended 2026-09-11**: the file is read as `utf-8-sig`, so a BOM is accepted; a non-finite `timeout` (`NaN`, `Infinity`, `1e400`) is a config error like a non-positive one (KitBench s78, s79).
- **Amended 2026-09-11**: for TypeScript and C# the gate reads `typecheck`, then `lint`. `""` on one hands the edit to the other — to auto-detection when the other is absent — and only an edit whose applicable checks are all `""` is recorded as `skipped (disabled)`. The code always worked this way (it errs toward running a check); "nothing guessed" above overstated it for a single `""`.

### ADR-019: Quality-gate results are per file, scoped and hash-checked, with explicit statuses
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: The gate kept one record — the last run — and `stop-gate.sh` blocked only when it said `failed`. So a pass on `b.py` closed a failure on `a.py`; a file no check covers (`.rb`, `.cs`, a `.ts` without tsconfig) exited silently and left an older pass standing for unchecked code; a pass stayed valid after the file changed; a missing declared command (exit 127) read as a code failure, and a malformed `commands.json` was treated as "nothing declared", silently switching to a different check. Its "FAILED" message went to stderr at exit 0, which the hooks docs confirm only reaches the debug log — Claude never saw it.
- **Options**:
  - A) **Keep one record, add fields.** Small, but the overwrite problem is structural.
  - B) **One record per edited file, keyed by the check scope that covered it, with the file's content hash.** A scope-wide pass re-covers the files in its scope.
  - C) **Re-run every check at stop.** Always current, but slow at every turn end and duplicates the per-edit gate.
- **Decision**: B, in `lib/gate-state.sh`, with `.hook-state/quality-gate-state.json` (schema v2).
  - Verified = the scope's latest run passed **and** the file's sha256 is unchanged.
  - Statuses: `passed` · `failed` · `timeout` · `error` (exit 126/127, invalid `commands.json`) · `skipped` + reason (`unsupported-language`, `tool-unavailable`, `no-config`). `failed`, `timeout` and `error` block.
  - Stale files (changed after their check, or a check that never finished) are re-verified by `stop-gate.sh` through `quality-gate.sh` — one file per scope, at most 3 — rather than trusted or blocked blindly.
  - A skipped code file never counts as passed: Claude is told once, via PostToolUse `additionalContext`, that it is NOT verified; it is listed at stop without blocking. Docs, config and markup files, and files without an extension, aren't gated. `.sh` / `.bash` get `bash -n`.
  - `last_quality_gate.json` stays as a summary (latest run plus overall verdict and file lists) for `session-end.sh` and older readers; `stop-gate.sh` falls back to it only when no v2 state exists.
- **Consequences**:
  - A file stays blocked until its own check (or its scope's) passes; unrelated activity can no longer clear it.
  - Only Edit/Write/NotebookEdit edits are tracked; a file changed purely through Bash that Claude never edited is outside the gate, as before.
  - Stop can take up to three check runs longer when files went stale.
  - KitBench s54–s61; s54–s58, s60 and s61 fail against the previous hooks.
- **Amended 2026-09-11**: the state is written under a lock and read fail-closed; runs are numbered with start-time hash snapshots so a late pass can't cover content it didn't check — see ADR-022.

### ADR-018: Hook results are keyed by git worktree; checks run under a process-group time limit
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `CLAUDE_PROJECT_DIR` stays at the directory the session started in, even when Claude or an isolated subagent works in a git worktree; the hook payload's `cwd` follows. `quality-gate.sh` anchored its verdict to `CLAUDE_PROJECT_DIR`, so a subagent's failure in its worktree blocked the main checkout's stop — or its pass cleared a real failure there — and declared checks ran against the main checkout's code, not the worktree's. Every root walk-up tested `-d .git`, which is false in a worktree, where `.git` is a file. Checks also ran unbounded wherever GNU `timeout` is missing (stock macOS), and GNU `timeout` signals only the direct child: a hanging declared check took 30.3s and was then recorded as `passed`.
- **Options**:
  - A) **Key state by `agent_id`** (subagent vs main session). Cons: a main session that enters a worktree still mixes results; it doesn't change which tree the check runs against.
  - B) **Key state by git worktree** — a result for a file in *another worktree of the same repository* (same git common dir) goes to that worktree's `.hook-state/`; `stop-gate.sh` reads the state for the payload's `cwd`.
  - C) **Status quo**, relying only on the merge-back re-verify in `agent_docs/worktrees.md`.
- **Decision**: B, in a shared `lib/roots.sh` that also separates the package root (where a check runs) from the project root (where its result is stored).
  - Only same-repository worktrees move. A nested independent repo or a submodule keeps the project's state, where `stop-gate.sh` reads it.
  - Session-level metrics (`bash-budget.json`) stay in `CLAUDE_PROJECT_DIR/.hook-state/`, where `session-start.sh` resets and `session-end.sh` reads them.
  - Time limit: `lib/run-with-timeout.sh` starts the check in its own process group and on timeout sends the group SIGTERM, then SIGKILL, and exits 124. Fallbacks: GNU `timeout -k`, a perl alarm, and — only with none available — an unbounded run with a warning. A timeout is recorded as a new status, `timeout`, which blocks like `failed`. `ACK_QUALITY_GATE_TIMEOUT` sets the limit (default 30s).
- **Consequences**:
  - The main session's stop no longer sees a subagent worktree's gate result; the merge-back re-verify is what checks it. Scorecard metrics for edits made inside a worktree land in that worktree.
  - KitBench gains `steps`, `setup_commands`, `cwd`, `max_seconds` and `no_process`, plus s51 (worktree isolation), s52 (fix unblocks stop) and s53 (timeout kills the check). s51 and s53 fail against the previous hooks.
- **Amended 2026-09-11**: a session's stop checks every checkout it touched — its `cwd`, `CLAUDE_PROJECT_DIR`, and worktrees it stored results in — so a subagent's worktree result now blocks the session's stop too; see ADR-022.

### ADR-017: `--upgrade` updates kit-managed files against a per-file install baseline
- **Date**: 2026-09-11
- **Status**: accepted
- **Context**: `install.sh --upgrade` copied a kit file only when it was missing, while bumping `VERSION`. Measured 1.21.0 → 1.21.1: 17 kit-managed files stayed stale — 9 hooks including every SIGPIPE-fixed safety hook, 4 scripts, `CLAUDE.md`, skill files — and the log said only "No new files". That contradicted `--help` and the README ("kit-managed files are updated by `--upgrade`"), and every later fix would have missed existing installs the same way.
- **Options**:
  - A) **Overwrite every kit file.** Simple; silently destroys local edits to kit files.
  - B) **Stay add-only and document it.** Honest, but leaves every install on stale safety hooks.
  - C) **Three-way against a per-file baseline** — record the hash of what the kit installed at each path; on upgrade update untouched files, keep edited ones, and write the kit's version beside a file both sides changed.
- **Decision**: C.
  - New sidecar `.kit-baseline` (`sha256<TAB>path` lines plus a `#template` line), written on install and upgrade and listed in `.kit-manifest`, so uninstall removes it. `.kit-manifest` keeps its path-only format — `uninstall.sh` and `sync-manifest.sh` read it.
  - Per file: missing → added · equal to kit → unchanged · equal to baseline → updated · edited and kit unchanged → kept · edited and kit changed → kept, kit copy written to `<file>.kit-new` (conflict).
  - Installs from before the baseline existed can't tell an edit from an older kit file: changed files are replaced and the previous copies saved to `.kit-backup/<UTC stamp>/` (ignores itself in git).
  - User-owned paths stay seed-only: `tasks/`, `CODEBASE_MAP.md`, the overlays, `artifacts/`. `settings.json` is still not merged; its baseline is recorded for the later merge work.
  - `CLAUDE.md` keeps the template it was installed from (baseline `#template`, else its first-line heading), so auto-detection on today's tree can't swap it for another template.
  - Hashing uses `sha256sum`, then `shasum -a 256`, then `python3`. With none available every differing file takes the pre-baseline path (backup + replace).
- **Consequences**:
  - The upgrade log ends with `updated · added · unchanged · kept · conflicts`; a quiet log can no longer hide what changed.
  - A conflict is reported once: the baseline records the version offered, so later upgrades keep the file quietly until the kit changes it again.
  - `test-install.sh` covers each case plus a pre-baseline install; the same tests fail 10× against the previous installer.
  - `--diff` reporting of leftover files and missing or dangling settings registrations is left to a follow-up.
- **Amended 2026-09-11 (ADR-023)**: a file with no entry always takes the backup-and-replace path, whatever the record holds, and the log names the file and its backup. A kit copy never overwrites a `.kit-new` (it goes to `.kit-new.<n>`). An existing `CLAUDE.md` is never given an auto-detected template, and counts as the kit's only when it carries the kit's own sections; otherwise it's left untouched. An update writes a new file (temp + `mv`), so another hard link to a kit file keeps its content. With no hash tool `--upgrade` now stops before changing anything — "every differing file takes the pre-baseline path" above no longer holds.
- **Amended 2026-09-30 (ADR-032)**: the record also carries `#hook` header lines — one per `settings.json` entry the kit registered, with the hash of the entry as the kit wrote it. `settings.json` itself stays unrecorded when it is the project's; `--upgrade` now merges the kit's hook entries into it by owner.

### ADR-016: protect-changes scopes auth + build-config blocking by intent and profile
- **Date**: 2026-05-25
- **Status**: accepted
- **Context**: `protect-changes.sh` runs in the standard (default) profile and blocked every edit under any `*/auth/*` directory plus all build configs (tsconfig, next.config, tailwind.config, vite, webpack, Dockerfile, …). On a typical frontend that meant frequent `BLOCKED` prompts on presentational components (e.g. `components/auth/LoginForm.tsx`) and on routinely-edited config files — training users to set `CLAUDE_APPROVED=1` globally (which defeats the gate) or uninstall.
- **Options**:
  - A) **Status quo** — keep blanket blocking. Pros: maximal caution. Cons: false-positive fatigue erodes the gate's credibility; users bypass it wholesale.
  - B) **Drop auth + build-config protection entirely.** Pros: zero friction. Cons: loses genuine protection on two areas where a staff engineer most wants a pause.
  - C) **Scope by intent + profile** — keep auth-logic, dependency, migration, and CI blocking always; exclude presentational UI from the auth match; make build-config blocking opt-in per profile.
- **Decision**: C.
  - **Auth:** skip paths under `*/components/*` (UI, not auth logic). Backend auth logic (`src/auth/`, `lib/auth/`, `middleware/auth*`, `*/security/*`, `*/permissions/*`) still blocks.
  - **Build configs:** hard-block only when `ACK_PROTECT_BUILD_CONFIGS=1`. The strict profile sets it via `settings.json → env`; the standard profile emits a non-blocking heads-up instead.
  - Dependency manifests, migrations/schema, and CI workflows block unconditionally in every profile — unchanged.
- **Consequences**:
  - `protect-changes.sh` gains a `*/components/*` skip and the env gate; the header documents `ACK_PROTECT_BUILD_CONFIGS`.
  - The strict profile's settings add `"env": { "ACK_PROTECT_BUILD_CONFIGS": "1" }`. (Originally an embedded `generate_strict_settings()` heredoc in `install.sh`; later extracted to the committed `.claude/settings.strict.json`, generated from `settings.json` + the strict delta via `scripts/gen-strict-settings.sh` and drift-checked in CI.)
  - KitBench gains s23 (strict blocks build config), s24 (standard warns), s25 (UI component allowed); s06 (backend auth still blocks) unchanged.
  - README hooks table marks build-config blocking as strict-only.

### ADR-015: Skill catalog formalised as a four-layer resolution order using existing primitives
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: The kit had grown three overlapping but uncoordinated mechanisms for skill customization, plus one external distribution channel, with no documented precedence between them:

  1. `.claude/skills/<name>/SKILL.md` — the kit installs these; users sometimes hand-edit them, and a kit upgrade may stomp those edits.
  1. `.claude/skills/_shared/blocks/` + `.claude/skills/_templates/*.tmpl` + `scripts/build-skills.sh` — a build-time block-substitution system that only 3 of 25 core skills use today (code-quality-audit, testing-audit, dead-code-audit).
  1. `.claude/hooks/project/` — a per-system project-overlay slot for hooks; no analogous slot exists for skills.
  1. `.claude-plugin/plugin.json` — the external channel. Registers the kit as a Claude Code plugin marketplace entry. Community contributions ride this channel today but have no kit-local file location to land in.

  Two gaps emerged: (a) there is no formal precedence between user customization, third-party additions, and kit defaults; (b) there is no kit-local directory for third-party skills installed via the plugin marketplace or copied in by hand. The ADR closes both.

- **Options**:
  - A) **Status quo** — note the mechanisms exist, do nothing. Pros: zero work. Cons: project-tweaked skills get stomped on upgrade; no clear place for community extensions; new contributors have to read the install script to discover the precedence.
  - B) **Rename existing directories to enforce a hierarchy** — promote `_templates/` to a top-level `presets/`, create top-level `extensions/` and `overrides/` directories, document the precedence in the rename. Pros: tidy, top-down naming. Cons: disruptive rename for every installed project; breaks the `.tmpl` build pipeline by name; conflates build-time and runtime concerns.
  - C) **Ship a package-manager CLI** — `kit extension add <name>` / `kit preset add <name>` fetches from a registry. Pros: polished UX. Cons: enormous scope (registry, versioning, integrity, signature checks); duplicates what the Claude Code plugin marketplace already does; pulls the kit toward "we are a package manager".
  - D) **Document the four layers using existing primitives** — formalise `.claude/skills/<name>/SKILL.md` (project override) > `.claude/extensions/<name>/SKILL.md` (community, new sibling directory) > `.claude/skills/<name>/project/` (additive overlay) > `.claude/skills/<name>/SKILL.md` (kit core, when no Layer 1 override exists). Add `.claude/extensions/` as a new kit-managed slot. Update `scripts/validate-skills.sh` to warn on name collisions. Update `agent_docs/skills.md` with the resolution order. Pros: non-breaking; reuses existing primitives; respects the existing plugin marketplace integration. Cons: no familiar CLI; users have to `cp -r` to add an extension (or install a plugin).

- **Decision**: D. Rationale:
  - The kit's distribution model is `curl | bash` + the Claude Code plugin marketplace. Option C duplicates the marketplace's job. Option B is disruptive for every installed project and conflates build-time templates with runtime layers. Option A leaves the gap open. Option D captures the *conceptual* clarity (four layers, deterministic precedence, ownership boundaries) using directory names the kit already has muscle memory for, and adds only one new directory (`.claude/extensions/`).
  - **No new CLI surface.** Adding an extension is a `cp -r` or a plugin marketplace install. The kit's `validate-skills.sh` adds a name-collision warning so accidental shadowing surfaces. That's enough.
- **Sub-decisions**:
  - **Layer 2 directory is `.claude/extensions/`** — sibling to `.claude/skills/`, not nested under it. Reason: extensions are owned by third parties; nesting them under `skills/` would imply kit ownership. The flat sibling makes ownership unambiguous.
  - **Layer 3 (project overlay) is per-skill, not global.** `.claude/skills/quality-audit/project/` holds project-specific content the kit-managed `quality-audit` skill knows to look for. This pattern was already proven by `.claude/hooks/project/`.
  - **No field-level merging.** When Layer 1 overrides Layer 4, the entire SKILL.md is replaced; there's no "merge frontmatter, append sections" magic. Reason: field-merging makes the effective skill non-obvious and breaks the "read one file to see what runs" promise.
  - **The `.tmpl` / `_shared/blocks/` system stays.** It's not a fifth layer — it's a *build-time* mechanism for the kit's own core skills (Layer 4). Renaming `_templates/` to `presets/` would suggest otherwise and was rejected.
- **Consequences**:
  - 1 docs update: `agent_docs/skills.md → ## Extending the Kit` section documenting the four layers
  - 1 ADR (this one)
  - 1 follow-up improvement: create `.claude/extensions/` placeholder + README in the kit repo so it ships as a discoverable slot; update `install.sh` to preserve the directory across upgrades; update `scripts/validate-skills.sh` to warn on Layer 1 vs Layer 4 name collisions.
  - **Not now**: a registry / catalog of community extensions, a CLI for installing them. Both are deferred until demand surfaces.
  - **NOTE on numbering**: ADR-005..014 are reserved by sibling PRs. If merge order shifts, renumber to next free slot.

### ADR-013: `/tasks-to-linear` is one-way, dedupes by exact title, encodes blocked-by as a description blockquote
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: A task asked for a skill that pushes the agent's TaskList to Linear as discrete issues — turning the in-session plan into durable project-tracker entries without a manual round trip. Three contract questions had to be settled before writing the skill, because they shape every other detail:

  1. **Direction.** One-way (TaskList → Linear) or bidirectional (also pull Linear state back into TaskList)?
  2. **Dedupe.** How does the second run of the skill avoid recreating the same issue?
  3. **Relations.** Linear supports `blockedBy`/`blocks`/`relatedTo`, but the MCPs available in this project's workspace today do not expose those fields on create or edit. How is the dependency edge represented?

- **Options**:
  - **Direction**
    - A) One-way (TaskList → Linear), no reverse sync
    - B) Bidirectional with a tracked `linear_id` per task
  - **Dedupe**
    - C) Exact title match within the configured team
    - D) Track `linear_id` in task metadata and look up by ID
    - E) Hash of `title + first 200 chars of description`
  - **Relations**
    - F) Skip — drop the edge, since neither MCP exposes it
    - G) Encode as a Markdown blockquote prepended to the issue description (`> **Blocked by:** [CLA-XX](url) — reason.`)
    - H) Use a custom Linear label per relation (e.g. `blocked-by:<issue-id>`)
- **Decision**: A + C + G.
  - **A (one-way)** — Bidirectional sync is a different skill with different invariants (state reconciliation, conflict resolution, ordering). Bundling it would balloon the contract. A future `/linear-to-tasks` skill can close the loop without renegotiating this one.
  - **C (title match)** — D is correct in theory but requires writing into TaskList metadata, which the agent's task tool does not expose for arbitrary keys today. E is more robust against renames but unfriendly to debug ("why was this skipped?"). C is the simplest contract a human can verify by reading the report. Renames are documented as a known v1 limitation.
  - **G (blockquote)** — F drops information the user explicitly cares about. H clutters the label vocabulary and gives no visual cue in the issue itself. G shows the dependency at the top of every blocked issue, makes the edge visible everywhere in the Linear UI, and is automatically replaced once an MCP gains the relation field (the skill diff is local).
- **Sub-decisions**:
  - **State is applied via post-create bulk update.** Linear's `create` endpoint does not accept a state argument; the skill creates issues, then runs one `linear_bulk_update_issues` call to move them to the configured state (Todo by default per ADR-relevant memory entry).
  - **No per-task AI labelling in v1.** A single `default_labels` set applies to every issue in a run. Per-task labelling injects model judgment under the dedupe contract, makes runs non-deterministic, and obscures the report. Revisit if users request it.
  - **Memory entries override `.claude/linear.config.yaml`.** `feedback_linear_workspace.md` (workspace scope), `feedback_linear_issue_state.md` (Todo default), and `reference_linear_mcp_limitations.md` (relation workaround) are read at runtime and treated as overrides. The skill reports the conflict when config and memory disagree.
- **Consequences**:
  - 1 new skill: `.claude/skills/tasks-to-linear/SKILL.md`
  - 2 templates: `linear.config.example.yaml`, `report.md.tmpl`
  - `CODEBASE_MAP.md` lists the new skill
  - When MCPs gain `blockedBy` on `create_issue`, Phase 3 in the SKILL.md swaps the blockquote write for a relation set. Existing issues with blockquotes are left as-is — no migration script.
  - **NOTE on numbering**: ADR-005..012 are reserved by sibling PRs. If merge order shifts, renumber to next free slot.

### ADR-014: `/constitution` is interactive-first, additive-only, library-backed (no rule invention)
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: A task asked for a "constitution" skill that produces a project-tailored `golden-principles.yaml` — the "Golden Principles" pattern from OpenAI's harness-engineering article applied to the kit's audit pipeline. `/quality-audit` (ADR-011) reads the file; this new skill writes it. Three contract questions had to be settled, because they determine whether the audit pipeline downstream is trustworthy:

  1. **Authoring stance.** Interactive (dialogue per principle) or non-interactive (codebase-only inference)?
  2. **Re-run behaviour.** What happens when the file already exists?
  3. **Where do proposed `detect` rules come from?** Synthesised from codebase patterns, or drawn from a curated library?

- **Options**:
  - **Authoring stance**
    - A) Interactive-first (default), headless as an explicit `mode:headless` escape hatch
    - B) Non-interactive by default (infer everything), interactive only on flag
  - **Re-run behaviour**
    - C) Additive merge — propose only new categories, never edit existing entries
    - D) Replace — regenerate the file on each run, dropping hand-edited principles
    - E) Interactive replace — show diff, ask which entries to keep
  - **`detect` rule source**
    - F) Curated `principles-library.yaml` per language, lightly adapted to the detected stack
    - G) Synthesised from codebase scan — "I see this pattern, here's a `detect` rule for it"
    - H) Hybrid — library for known categories, synthesis for novel ones
- **Decision**: A + C + F.
  - **A (interactive-first)** — Following the principle from `office-hours` and the Core Rule pattern in `/quality-audit`, `/references-sync` and `/tasks-to-linear`: the agent must never write a rule the user hasn't seen. Quality rules drive audit-class skills downstream; silent invention propagates errors at scale. Headless mode exists for CI bootstrapping but accepts everything the library proposes — no judgment is delegated.
  - **C (additive merge)** — D would let the skill clobber hand-tuned principles, which is the worst possible failure mode for a file users will iterate on. E sounds good but creates a coupling problem: the user has to re-evaluate every existing entry on every run, turning a 30-second additive operation into a 10-minute review. C aligns with the "do one thing" principle — this skill *adds*; refining is a hand-edit job.
  - **F (curated library)** — G is tempting but identical in shape to the failure mode ADR-012 (the `/references-sync` curated-vs-heuristic-vs-summarisation decision) rejected for the same reason: synthesised `detect` patterns are brittle and fire on the wrong lines. H sounds balanced but introduces the synthesis failure mode through the back door. F gives the skill a stable, kit-maintained surface to draw from; users extend with `.claude/principles-library.local.yaml` (per-project) or upstream PRs to grow the shared library.
- **Sub-decisions**:
  - **Schema source of truth is `.claude/skills/quality-audit/templates/golden-principles.example.yaml`.** If the schema changes there, `/constitution`'s output must follow. The skill's docstring explicitly references that path; a future CI lint can reject schema drift between the two skills.
  - **Default file path is `.claude/golden-principles.yaml`**, not the repo root. `/quality-audit` resolves both, but `.claude/` is the kit-managed surface and avoids cluttering the project root. Users who prefer root can pass `path:./golden-principles.yaml`.
  - **5-question intake** (in `templates/intake-questions.md`) shapes *severity emphasis* in Phase 3, not the principle set itself. Selected principles still come from the library; the intake just tunes which ones surface and how harshly.
  - **CLAUDE.md pointer addition is opt-in.** On a brand-new file, the skill proposes adding a `## Quality Principles` section to CLAUDE.md — only with explicit user approval, never in headless mode. Following the same kit-managed-file discipline as `/harness-init`.
- **Consequences**:
  - 1 new skill: `.claude/skills/constitution/SKILL.md`
  - 2 templates: `templates/principles-library.yaml` (3 languages × 4–6 categories), `templates/intake-questions.md` (5 questions + severity-mapping)
  - `CODEBASE_MAP.md` lists the new skill
  - **Skill family is now closed**: `/harness-init` (scaffold `docs/`) → `/constitution` (write `golden-principles.yaml`) → `/quality-audit` (measure drift) → `/doc-gardening` (flag stale docs) → `/references-sync` (populate `docs/references/`) → `/tasks-to-linear` (mirror plans to tracker). Each link in the chain has one job; future improvements stay localised.
  - **NOTE on numbering**: ADR-005..013 are reserved by sibling PRs. If merge order shifts, renumber to next free slot.

### ADR-012: `/references-sync` skill ships curated known-sources list; refuses to auto-summarise READMEs
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: A task asked for a `/references-sync` skill that auto-generates `*-llms.txt` for project dependencies, modelled on OpenAI's `docs/references/` pattern. The user's own comment on the task clarified an important constraint: **scope is in-repo agent context, not SEO.** Google explicitly says `llms.txt` does not affect Search visibility. The skill must say so up-front so users don't deploy it expecting marketing wins.

  Two design questions emerged once the SEO scope was settled:

  1. **How does the skill know which packages have llms.txt?** Probing every dependency's homepage is slow, often 404s, and a poor first-run experience. A curated allowlist gives deterministic, fast behaviour at the cost of coverage.
  2. **What about packages without llms.txt?** Auto-summarising the README is tempting but produces stale, misleading reference docs — the same harm `/doc-gardening` is supposed to detect.
- **Options**:
  - A) **Curated `known-sources.yaml` + stub fallback** — ship a small registry (8–12 entries: Anthropic, OpenAI, Stripe, Vercel, etc.). Packages not in the registry get a manually-edited stub. Users extend with `.claude/known-sources.local.yaml`. Honest about coverage; no auto-summarisation.
  - B) **Heuristic discovery** — for each package, try `https://<homepage>/llms.txt`. Fast when it works, noisy when it doesn't. False positives are problematic — partial files, wrong content, 200 responses with marketing pages.
  - C) **Auto-summarise from README** — for any package, fetch the README and use the agent to extract an API summary. Produces real-looking content for every package — and is the most dangerous option because the agent will believe its own output.
- **Decision**: A (curated + stub). Rationale:
  - The curated list is a small, public, kit-maintained artefact. Upstream PRs from users grow it organically.
  - The stub fallback is **deliberately not autogenerated** — it forces the user to capture genuine project-specific knowledge instead of trusting an LLM summary. The kit's whole positioning is "disciplined staff engineer behaviour"; auto-summarisation contradicts that.
  - Heuristic discovery (option B) was rejected because llms.txt at `<homepage>/llms.txt` has no standardised location — too many false positives.
- **Sub-decisions**:
  - **`known-sources.yaml` is shipped with the skill, not at repo root.** Per-project overrides live in `.claude/known-sources.local.yaml`. The skill merges both at runtime.
  - **`status: verified` vs `speculative`** — kit ships entries as `speculative` until someone confirms the URL responds. PRs that flip a source to `verified` include a check date.
  - **30-day TTL on cached files** — refresh budget is non-trivial (each WebFetch costs tokens). Monthly recadence is recommended for `/loop`.
  - **Never auto-fetches transitive deps** — only direct dependencies. Transitive coverage would make `docs/references/` unmanageable.
  - **First-run CLAUDE.md update** — the skill proposes adding a `## Reference Docs` pointer section, but only if `docs/references/index.md` was just created and the section isn't already present. Idempotent on subsequent runs.
- **Consequences**:
  - 1 new skill: `.claude/skills/references-sync/SKILL.md`
  - 3 templates: `known-sources.yaml` (12 entries across npm/pypi), `package-fallback.md`, `references-index.md`
  - `CODEBASE_MAP.md` lists the new skill
  - `scripts/validate-skills.sh` adds `references-sync` to the audit-class allowlist (it follows the Default Behavior + Phase 1 Inventory conventions even though it writes files instead of producing a read-only report)
  - Pairs with `/harness-init` (scaffolds `docs/`) and `/doc-gardening` (flags stale references when packages are removed)
  - Future kit PRs can extend `known-sources.yaml` as more vendors publish llms.txt; the format is intentionally additive
  - **NOTE on numbering**: ADR-005..011 are reserved by sibling PRs. If merge order shifts, renumber to next free slot.

### ADR-004: Adopt three skill conventions from codex-complexity-optimizer (Core Rule, Default Behavior, Phase 1 Inventory)
- **Date**: 2026-05-18
- **Status**: accepted
- **Context**: The kit's 23 skills had inconsistent structure: Phase 1 named variously ("Scope" / "Scope & Inventory" / "Test Inventory" / etc.), no top-level ethical scope statement, and audit skills required users to specify what to audit instead of producing a report autonomously. While reviewing [codex-complexity-optimizer](https://github.com/Kappaemme-git/codex-complexity-optimizer) (728 stars, 3 days old), three patterns stood out as directly applicable to the kit's existing skill family.
- **Options**:
  - A) **Adopt three patterns** — Core Rule (all 23 skills), Default Behavior + Phase 1 Inventory naming (10 audit skills). Pure markdown changes, no new infrastructure.
  - B) **Adopt the whole complexity-optimizer skill** — drop in as a new skill. Maintenance burden (sync with upstream), overlaps with `performance-audit`.
  - C) **Take inspiration but redesign** — write new skill conventions from scratch. Higher quality bar, but unnecessary — the codex patterns are already well-shaped.
- **Decision**: A (three patterns). Rationale: small, mechanical, immediately useful, doesn't add an outsider skill to maintain. The Phase 1 Inventory framing ("candidates, not findings") solves a real problem we've seen — agents reporting scanner raw counts as final findings.
- **Sub-decisions**:
  - **Audit-class set is explicit (10 skills)**, not heuristic. Codifying which skills get Default Behavior + Phase 1 patterns by name list (`code-quality-audit`, `performance-audit`, `architecture-review`, etc.) avoids classifier drift in `validate-skills.sh`.
  - **Core Rule is universal** (all 23 skills). Even non-audit skills (debug, ship, lesson-refresh) benefit from a one-sentence "deal-breaker" anchor.
  - **Phase 1 framing is uniform text**, not skill-bespoke. Reduces drift, makes the convention scannable.
  - **Validator warns, doesn't fail.** v1 ships as advisory; can promote to fail-block in a future revision after the convention settles.
- **Consequences**:
  - 23 skill SKILL.md files modified (insert Core Rule)
  - 10 of those also got Default Behavior + Phase 1 Inventory framing
  - 3 .tmpl templates updated to match (otherwise `build-skills.sh` would overwrite the patches)
  - 3 new shared blocks created as documentation: `core-rule.md`, `default-behavior.md`, `inventory-framing.md`
  - `scripts/validate-skills.sh` gained 3 new checks (warnings only)
  - `agent_docs/skills.md` documents the conventions
  - Patcher script `/tmp/patch-skills.py` was used for the bulk migration; not committed (one-shot tooling)
  - Future skills should follow the conventions from inception — `skill-generator` skill updates the agent on how

### ADR-003: Hook-shift — move prompt-based discipline rules into deterministic lifecycle hooks
- **Date**: 2026-05-16
- **Status**: accepted
- **Context**: CLAUDE.md enforces "Verification (Mandatory Order)", "Session Boot (Tiered)", "Protected Changes (Approval Required)" via prompt. These depend on model goodwill — Claude can ignore, forget, or skip them. Inspired by Nader Dabit's "Agent Hooks: Deterministic Control for Agent Workflows" (2026-05-15), which argues: *"Use prompts for guidance. Use hooks for behavior that should run every time."* Mapped existing kit hooks against the canonical 6 lifecycle points and identified gaps: no SessionStart, no SessionEnd, no completion gate on Stop, minimal UserPromptSubmit.
- **Options**:
  - A) **Core 3** — Only the highest-leverage gaps: session-start, quality-gate, stop-gate. Skips PreToolUse architectural protection and SessionEnd audit. Lower risk, faster to ship.
  - B) **Full 6** — All six lifecycle points covered: session-start, prompt-router, protect-changes, quality-gate, stop-gate, session-end. Complete framework, larger change, requires `.hook-state/` directory and `.gitignore` update.
  - C) **Minimum (gate only)** — Just quality-gate + stop-gate. Solves the strongest Nader argument (completion gating) but leaves Tier 1 boot and audit as prompt-only.
- **Decision**: B (Full 6). Rationale: the kit's positioning is "disciplined staff engineer behavior" — partial coverage undermines the value prop. Completion gating without auto-context (session-start) leaves a gap where Claude skips Tier 1. Architectural protection (protect-changes) is the second-most-frequent prompt-rule violation per user reports. Once the `.hook-state/` infrastructure is in place, adding the remaining hooks is cheap.
- **Sub-decisions**:
  - **quality-gate profile**: enabled in both `standard` and `strict`. Rationale: deterministic verification is core, not optional. Users on broken test infra use the escape hatch.
  - **stop-gate behavior**: hard-block (exit 2) with `SKIP_QUALITY_GATE=1` env-var escape. Rationale: soft-warn defeats the purpose — completion would still depend on model reading stderr.
- **Consequences**:
  - 6 new hooks: `session-start.sh`, `prompt-router.sh`, `protect-changes.sh`, `quality-gate.sh`, `stop-gate.sh`, `session-end.sh`
  - New transient state directory: `.hook-state/` (gitignored, created on demand by quality-gate.sh)
  - New audit log: `reports/session-audit.log` (gitignored)
  - `CLAUDE.md` rules annotated with `(enforced via <hook>)` where the hook now covers them — prompt remains as documentation of intent
  - `protect-changes.sh` is opinionated about which paths are "architectural" (package.json, requirements.txt, pyproject.toml, Cargo.toml, go.mod, Gemfile, migrations/**, **/auth/**, **/security/**, Dockerfile, build configs, `.github/workflows/**`) — projects loosen the policy by removing the hook from `.claude/settings.json` PreToolUse and adding a custom replacement under `.claude/hooks/project/`. There is no auto-sourcing override mechanism; the swap is explicit in settings.
  - Existing prompt-based rules in `CLAUDE.md` are NOT removed — they continue to serve as documentation and as the source of truth for *why* the hooks exist
  - Upgrade path: `install.sh --upgrade` adds the 6 hooks without overwriting `CLAUDE.project.md` or project-specific hooks

### ADR-002: Squash-only merge
- **Date**: 2026-04-26
- **Status**: accepted
- **Context**: Past CHANGELOGs (v1.6.0–v1.7.2) showed every PR's bug-fix line *twice*. Each entry came from (1) the original `fix:`/`feat:` commit on the feature branch and (2) the merge commit GitHub creates on `--merge`, whose body auto-inherits the feature branch's HEAD commit subject. release-please's conventional-commits parser saw both and emitted two entries per PR.
- **Options**:
  - A) **Squash merge only** — single commit on `main` with PR title as subject. One changelog entry per PR. Loses intermediate branch commits (acceptable for this repo size).
  - B) **Rebase merge only** — replays each commit on `main` linearly. No merge commit pollution. But every "fix lint" / "address review" commit ends up in changelog separately.
  - C) **Keep merge + filter release-please** — config a regex to drop merge commits. Brittle, depends on release-please internals.
- **Decision**: A (squash only). Disabled `--enable-merge-commit` and `--enable-rebase-merge` at the GitHub repo level so the wrong strategy can't be selected by mistake.
- **Consequences**:
  - Future PRs must be merged with `gh pr merge --squash` (the only option GitHub now exposes).
  - release-please will produce one changelog entry per PR.
  - Past v1.6.x / 1.7.x duplicate entries remain — git history is immutable, fixing them isn't worth a force-push.
  - Documented in `agent_docs/conventions.md` under "Merging Pull Requests".
