# Task Board

Track current and upcoming tasks here. The agent updates this file as work progresses.

The task under **In Progress** carries an `h3` heading — `session-start.sh` reads
the first one and injects it as the session's active task.

---

## In Progress

### README redesign in the readme-md-generator style; solo-maintainer repo

Goal: `README.md` and `README.pt-BR.md` use the layout of
[readme-md-generator](https://github.com/kefranabg/readme-md-generator) —
centered welcome title, a row of clickable badges, emoji section headings, the
demo near the top, then Prerequisites, Install, Usage, Run tests, Author, Show
your support and License — with the kit's current content. Done when
markdownlint, `check-counts.sh` and the link check pass, every badge URL
returns an image and every link returns 200 (checked, not assumed), and
GitHub's renderer shows both files correctly.

- [x] Repo settings: issues off (`has_issues=false`), PR creation limited to
  collaborators (`pull_request_creation_policy=collaborators_only`), private
  vulnerability reporting on — all confirmed through the API. Recorded as
  ADR-027.
- [x] The maintainer can still open pull requests under `collaborators_only`
  (one was opened after the change).
- [x] release-please can still open its PR under `collaborators_only`
  (the 1.22.4 release PR was opened after the change).
- [x] `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`: the
  `homepage` pointed at a GitHub Pages URL that returns 404 — now
  `https://github.com/lucasfelipe24/agent-code-kit#readme`.
- [x] `package.json` (Protected Change — the maintainer ran the edit): the same
  `homepage` fix, plus `"author": "Lucas Felipe"`. No `bugs` URL: issues are off.
- [x] `README.md`: header, badges (npm version, npm downloads, node >=18, CI,
  maintained, license, pt-BR), a short link bar, emoji headings; long
  reference tables in `<details>`; a "solo project" note where the
  Contributing section would be; Author; Show your support; License with the
  copyright line. Keeps the scenario-count phrases `check-counts.sh` reads.
- [x] `README.pt-BR.md`: the same layout and content, in Portuguese.
- [x] `CONTRIBUTING.md`: an opening line saying outside issues and pull
  requests aren't accepted.
- [x] Verify: markdownlint (0 issues), `check-counts.sh`, `npm run check`,
  16 URLs fetched (all 200 except npmjs.com's 403 to bots) and every badge's
  rendered text read, both files rendered through GitHub's markdown API.
- [x] After push: every `#` link in both READMEs matches an anchor id in
  GitHub's rendered HTML for the branch (9 per file).

---

## Up Next

- Nothing queued. Parked scope lives under **Not Now**.

---

## Done

Shipped releases are recorded in `CHANGELOG.md` — release-please generates it
from Conventional Commits, so this section only carries work that has landed on
`main` since the last cut.

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

Found while fixing the hook enforcement gaps, outside their scope:

- **doctor's placeholder count misses HTML-comment placeholders**, so an untouched `scaffold/CODEBASE_MAP.md` reads "appears filled in"; the dotnet map's `<App>`-style tokens aren't counted either. _(v1.22.2 field bugs)_
