# KitBench

Reproducible eval harness for the kit's behavioural claims.

The kit makes deterministic-enforcement promises (e.g. *"protected changes are blocked"*, *"completion is gated on quality"*, *"Tier 1 boot context is injected"*). KitBench turns those promises into pass/fail scenarios so they can be verified on every PR — no LLM, no network, no hand-waving.

## Run it

```bash
./scripts/run-bench.sh                  # all scenarios
./scripts/run-bench.sh --scenario s01   # one
./scripts/run-bench.sh --filter protect # name contains
./scripts/run-bench.sh --verbose        # print stdout/stderr per scenario
./scripts/run-bench.sh --json           # machine-readable summary
```

Exit codes: `0` all pass, `1` one or more fail, `2` runner error.

Each scenario runs in a **fresh temp directory** — no shared state between scenarios.

## What's covered

| # | Scenario | What it asserts |
|---|---|---|
| s01 | `protect-files-blocks-env` | Edit to `.env` → exit 2 |
| s02 | `protect-files-blocks-composer-lock` | Edit to `composer.lock` → exit 2 *(regression: lock-file bug from v1.10.0 review)* |
| s03 | `protect-changes-blocks-package-json` | Edit to `package.json` → exit 2 |
| s04 | `protect-changes-allows-with-claude-approved` | `CLAUDE_APPROVED=1` + edit `package.json` → exit 0 |
| s05 | `protect-changes-blocks-ci-workflow` | Edit `.github/workflows/ci.yml` → exit 2 *(regression: basename-with-slash bug)* |
| s06 | `protect-changes-blocks-auth-path` | Edit `src/auth/login.ts` → exit 2 |
| s07 | `quality-gate-passes-on-good-py` | Valid `.py` → state status `passed` |
| s08 | `quality-gate-fails-on-broken-py` | Syntax-error `.py` → state status `failed` *(regression: `EXIT_CODE=$?` after `\|\| true` bug)* |
| s09 | `stop-gate-blocks-on-failed-state` | Failed state → exit 2 |
| s10 | `stop-gate-allows-on-passed-state` | Passed state → exit 0 |
| s11 | `stop-gate-bypassed-with-skip-env` | `SKIP_QUALITY_GATE=1` + failed state → exit 0 |
| s12 | `prompt-router-injects-on-auth-inflection` | "authentication" → `hookSpecificOutput.additionalContext` non-empty *(regression: word-boundary bug)* |
| s13 | `prompt-router-quiet-on-neutral` | Neutral prompt → empty stdout |
| s14 | `session-start-injects-tier1` | Outputs `hookSpecificOutput` JSON (`hookEventName: SessionStart`) whose `additionalContext` references `CODEBASE_MAP.md` |
| s15 | `session-end-writes-audit-line` | Appends one line to `reports/session-audit.log` |
| s16 | `session-start-working-tree-silent-on-clean` | Working Tree block stays out of `hookSpecificOutput.additionalContext` on a fresh-checkout (no `.git`) session — silent-on-clean guarantee |
| s17 | `lesson-resurface-smoke` | `scripts/lesson-resurface.sh` emits the pointer for an archived lesson matching the query vocabulary AND does NOT leak the lesson body's sentinel phrases — pointer-only contract |
| s18 | `journal-fold-creates-handoff` | `.claude/hooks/journal-fold.sh` folds a `/note`-populated `.hook-state/session-journal.md` (with findings + decisions) into `tasks/handoff-<session-id>.md` at session end |
| s19 | `journal-fold-folds-agent-handoff` | `journal-fold.sh` folds a non-empty `.hook-state/agent-handoff.md` (the inter-agent scratchpad) into `tasks/handoff-<session-id>.md` even with no journal present |
| s20 | `subagent-pre-logs-invocation` | `subagent-pre.sh` (PreToolUse on Task) appends an open telemetry row to `.hook-state/agent-invocations.jsonl` |
| s21 | `subagent-post-closes-invocation` | `subagent-post.sh` (PostToolUse on Task) closes the latest open telemetry row with `finished_at` + `duration_seconds` |
| s22 | `session-start-prior-session-verdict-kept` | A prior session's failing verdict doesn't block a new session's stop, and `session-start.sh` keeps it — the prior session's own stop still blocks *(multi-step)* |
| s23 | `protect-changes-build-config-blocks-in-strict` | `CCK_PROTECT_BUILD_CONFIGS=1` + edit `tsconfig.json` → exit 2 |
| s24 | `protect-changes-build-config-warns-in-standard` | Edit `tsconfig.json` without the env → exit 0, advice as PreToolUse `additionalContext` on stdout (no block) |
| s25 | `protect-changes-allows-ui-component` | Edit `src/components/auth/LoginForm.tsx` → not blocked (UI ≠ auth logic) |
| s26 | `block-dangerous-rm-system-path` | `sudo rm -rf /etc/nginx` → exit 2 (system path) |
| s27 | `block-dangerous-rm-no-preserve-root` | `rm -rf --no-preserve-root /` → exit 2 |
| s28 | `block-dangerous-allows-project-rm` | `rm -rf node_modules dist` → exit 0 (project-local, allowed) |
| s29 | `block-dangerous-chmod-system` | `chmod -R 777 /etc` → exit 2 (system path) |
| s30 | `block-dangerous-allows-chown-app` | `chown -R deploy:deploy /srv/app` → exit 0 (app path, allowed) |
| s31 | `branch-protect-blocks-push-u-main` | `git push -u origin main` → exit 2 |
| s32 | `branch-protect-blocks-refspec-dest-main` | `git push origin feature:main` → exit 2 (refspec destination is `main`) |
| s33 | `branch-protect-blocks-git-c-push-main` | `git -c color.ui=always push origin main` → exit 2 (`-c` flag can't smuggle past the matcher) |
| s34 | `branch-protect-allows-feature-branch` | `git push -u origin feat/search` → exit 0 (feature branch, allowed) |
| s35 | `conventional-commit-blocks-am-badmsg` | `git commit -am "updated stuff"` → exit 2 (non-conventional message) |
| s36 | `conventional-commit-allows-am-goodmsg` | `git commit -am "feat: add search endpoint"` → exit 0 (conventional message) |
| s37 | `loop-detect-blocks-on-repeated-edit` | Repeated `Edit` to `src/foo.ts` (pre-seeded loop log) → exit 2 |
| s38 | `loop-detect-quiet-on-first-edit` | First `Edit` to `src/bar.ts` → exit 0 (no loop yet) |
| s39 | `mcp-gate-blocks-unlisted-server` | Allowlist present, `mcp__github__*` not listed → exit 2 (blocked) |
| s40 | `mcp-gate-allows-listed-server` | `github` on the allowlist → `mcp__github__*` exit 0 (allowed) |
| s41 | `mcp-gate-inert-without-allowlist` | No allowlist file → exit 0, only the untrusted-input reminder fires |
| s42 | `quality-gate-uses-declared-lint-fail` | `.claude/commands.json` declares `lint: false` → gate runs it, records `failed` |
| s43 | `quality-gate-uses-declared-lint-pass` | `.claude/commands.json` declares `lint: true` → gate runs it, records `passed` |
| s44 | `journal-fold-redacts-secrets` | `journal-fold.sh` masks secret values (`api_key=…`, `Bearer …`) before folding notes into the durable `tasks/handoff-*.md`, leaving prose intact |
| s45 | `notify-waiting-noops-when-unconfigured` | No notifier configured → exit 0, nothing sent |
| s46 | `notify-waiting-handles-empty-payload` | Empty Notification payload → exit 0, no crash |
| s47 | `notify-waiting-ntfy-remote-configured` | `ntfy` topic configured → the remote notifier is selected |
| s48 | `notify-waiting-pushover-remote-configured` | Pushover credentials configured → the remote notifier is selected |
| s49 | `session-start-top-rules-clean` | Top Rules inject the rule itself, not the `AUTO-GENERATED` marker comments around it |
| s50 | `session-start-no-top-rules` | Empty Top Rules section → no "Top rules" block in the `hookSpecificOutput` context, not the "*No top rules yet*" placeholder |
| s51 | `quality-gate-worktree-isolation` | A broken edit inside a git worktree is stored in that worktree (not the main checkout) and still blocks the session's stop from either checkout; another session's stop is allowed *(multi-step, real `git worktree add`)* |
| s52 | `quality-gate-fix-unblocks-stop` | Broken edit → stop blocked → file fixed → gate passes → stop allowed *(multi-step)* |
| s53 | `quality-gate-timeout-kills-check` | A hanging declared check is killed at `CCK_QUALITY_GATE_TIMEOUT` together with its background child → status `timeout`, no process left running |
| s54 | `quality-gate-unrelated-pass-keeps-failure` | `a.py` fails, then `b.py` passes → the verdict stays `failed` and stop is blocked on `a.py` *(multi-step)* |
| s55 | `stop-gate-reverifies-stale-file` | A passing file changes without an Edit → stop re-runs its check: broken content blocks, fixed content is allowed *(multi-step)* |
| s56 | `compaction-keeps-failing-verdict` | `session-start` with `source: compact` keeps the per-file state → a failing file still blocks stop *(multi-step)* |
| s57 | `quality-gate-missing-declared-command-errors` | Declared lint isn't installed (exit 127) → status `error`, not `failed`, and stop is blocked *(multi-step)* |
| s58 | `quality-gate-unsupported-file-unverified` | `.rb` after a passing `.py` → recorded `skipped`, Claude told it is NOT verified, listed in `unverified_files`, stop names it without blocking *(multi-step)* |
| s59 | `quality-gate-docs-edit-not-gated` | A Markdown-only edit records nothing and never blocks *(multi-step)* |
| s60 | `quality-gate-shell-syntax` | A broken `.sh` fails `bash -n` |
| s61 | `quality-gate-invalid-commands-json-errors` | Malformed `commands.json` → status `error` and stop blocked; once fixed, stop re-verifies with the declared check and allows *(multi-step)* |
| s62 | `quality-gate-dotnet-build` | `.cs` edit builds the nearest `.csproj` (fake `dotnet` on PATH): good passes, broken fails and blocks stop *(multi-step)* |
| s63 | `quality-gate-dotnet-declared-command` | A declared `typecheck` runs for `.cs` edits instead of the gate's own `dotnet build` |
| s64 | `quality-gate-dotnet-missing-skipped` | No `dotnet` on PATH → `.cs` edit `skipped` (tool-unavailable), reported as NOT verified, never passed *(multi-step)* |
| s65 | `protect-changes-blocks-csproj` | Edit to a `.csproj` → exit 2 (dependency manifest) |
| s66 | `quality-gate-commands-json-unknown-key` | A mistyped key (`typcheck`) in `commands.json` → config `error` naming the key, stop blocked *(multi-step)* |
| s67 | `quality-gate-declared-check-disabled` | `lint: ""` → edit recorded `skipped` (disabled), NOT verified — no guessed check runs |
| s68 | `quality-gate-declared-timeout` | `timeout` in `commands.json` cuts off a slow declared check → status `timeout` |
| s69 | `stop-gate-worktree-cwd-keeps-main-failure` | A failure in the main checkout still blocks a stop whose `cwd` is a git worktree — stop-gate checks `CLAUDE_PROJECT_DIR`'s state and the worktree's *(multi-step, real `git worktree add`)* |
| s70 | `quality-gate-late-pass-keeps-newer-failure` | A slow scope-wide check that passes after a later run of its scope failed doesn't overwrite that failure or re-hash the broken file as verified |
| s71 | `quality-gate-concurrent-runs-keep-every-record` | Twelve concurrent gate runs on broken files → all twelve failures recorded (locked state, unique temp files) and listed at stop |
| s72 | `stop-gate-unreadable-state-blocks` | A torn `quality-gate-state.json` blocks stop with reset instructions instead of reading as empty; a later gate run exits 2 saying it can't record *(multi-step)* |
| s73 | `stop-gate-broken-python3-still-blocks` | A `python3` stub that exits 1 counts as absent: the jq / bash readers see the failed summary and stop is blocked *(multi-step)* |
| s74 | `quality-gate-leftover-process-bounded` | A declared check that exits but leaves a process holding its output: the hook returns within the limit (output goes to a file) |
| s75 | `stop-gate-non-ascii-path-blocks` | A failing file under `Çalışma proj/` with `PYTHONIOENCODING=ascii` still blocks — UTF-8 helper I/O, helper failures fail closed *(multi-step)* |
| s76 | `quality-gate-declared-command-skips-outside-file` | A declared command doesn't verify `../sibling/util.py`: files outside the project root are auto-detected, fail and block *(multi-step)* |
| s77 | `quality-gate-perl-timeout-kills-group` | No python3 / `timeout` on PATH: the perl fallback kills the check's whole process group at the limit → `timeout`, no process left |
| s78 | `quality-gate-commands-json-infinite-timeout` | `"timeout": Infinity` in `commands.json` → config `error`, not a silent 30s default |
| s79 | `quality-gate-commands-json-bom` | A `commands.json` saved with a UTF-8 BOM is valid: the declared lint runs |
| s80 | `quality-gate-unrecorded-result-blocks` | The gate state can't be written → the run is `error`, the hook exits 2 so Claude hears it, and stop blocks on the file until a result is recorded *(multi-step)* |
| s81 | `quality-gate-broken-python3-skips-py` | A `python3` stub and no ruff: a valid `.py` edit is `skipped (tool-unavailable)` — NOT verified, never failed — and stop isn't blocked *(multi-step)* |
| s82 | `quality-gate-unwritable-state-dir-blocks` | A read-only `.hook-state`: the gate exits 2 saying the result can't be recorded, notes the file outside the project, and stop blocks *(multi-step)* |
| s83 | `quality-gate-unrecordable-noted-outside-project` | Nothing can be created in the project: an unedited project stops fine; an edit is noted in `$TMPDIR` and blocks stop *(multi-step)* |
| s84 | `stop-gate-no-python-keeps-every-failure` | No python3 and no jq: `a.sh` fails, `b.sh` passes → stop still blocks on `a.sh` (plain per-file log) *(multi-step)* |
| s85 | `stop-gate-no-python-reverifies-stale-file` | No python3: a passing file changed without an Edit is re-verified at stop — broken blocks, fixed is allowed *(multi-step)* |
| s86 | `stop-gate-no-python-per-file-state-fail-closed` | A per-file state that needs python3, read without it: blocks the session it holds records for, not a later session *(multi-step)* |
| s87 | `stop-gate-sees-edits-in-other-worktrees` | The session edits a file in another git worktree by absolute path: its stop (cwd = main) blocks on it; another session's doesn't *(multi-step)* |
| s88 | `stop-gate-renamed-file-keeps-scope-failure` | A scope-wide declared check fails, then the file is renamed: the failure still blocks stop |
| s89 | `stop-gate-deleted-file-clears-file-check` | A per-file check's failure goes away with the deleted file (guard for s88) |
| s90 | `session-start-keeps-other-sessions-failures` | Session B's SessionStart keeps session A's failure: B's stop is allowed, A's is blocked *(multi-step)* |
| s91 | `quality-gate-leftover-not-waited-for` | A finished check leaves a SIGTERM-ignoring process: the hook doesn't wait out a kill grace (the group is killed only on timeout) |
| s92 | `quality-gate-sigterm-ends-check` | SIGTERM to the gate mid-check ends the check and leaves no output file; stop re-verifies the run |
| s93 | `stop-gate-reverify-budget` | Two stale files, a 3s check, `CCK_STOP_REVERIFY_BUDGET=2`: re-verification stops at the budget and both files block *(multi-step)* |
| s94 | `stop-gate-no-python-mixed-sessions-fail-closed` | Without python3 or jq, a failing record with no session (or `"-"`) alongside another session's passing record still blocks *(multi-step)* |
| s95 | `session-start-clears-pre-v2-summary` | A pre-v2 `last_quality_gate.json` (no session_id) doesn't block a fresh session's first stop *(multi-step)* |
| s96 | `quality-gate-sigterm-spares-caller` | SIGTERM to the gate ends only the check: the caller's process group, which the hook shares, survives *(multi-step)* |
| s97 | `branch-protect-blocks-force-push` | `git push --force origin feat/search` → exit 2, reason on stderr |
| s98 | `branch-protect-blocks-push-head-on-main` | `git push origin HEAD` on `main` → exit 2, reason on stderr |
| s99 | `branch-protect-blocks-bare-push-on-main` | Bare `git push` on `main` → exit 2, reason on stderr |
| s100 | `conventional-commit-allows-breaking-and-revert` | `feat!:`, `feat(api)!:` and `revert:` → exit 0 (were rejected) |
| s101 | `conventional-commit-blocks-heredoc-badmsg` | Heredoc message (`-m "$(cat <<'EOF' …)"`) with a non-conventional subject → exit 2 (was never checked) |
| s102 | `conventional-commit-allows-heredoc-goodmsg` | Heredoc with a conventional subject and quotes/backticks in the body → exit 0 |
| s103 | `conventional-commit-checks-message-file` | `git commit -F <file>` checks the file's first line; a missing file is allowed |
| s104 | `conventional-commit-blocks-git-global-options` | `git -c k=v commit` / `git -C dir commit` with a bad message → exit 2 |
| s105 | `conventional-commit-ignores-quoted-mention` | Text that only mentions a commit (`echo 'git commit …'`) → exit 0 (was a false positive) |
| s106 | `branch-protect-blocks-plus-refspec-force` | `git push origin +main` → exit 2 (a `+` refspec is a force push) |
| s107 | `branch-protect-blocks-full-ref-dest-main` | `git push origin HEAD:refs/heads/main` → exit 2 |
| s108 | `branch-protect-blocks-mirror` | `git push --mirror` → exit 2 |
| s109 | `branch-protect-allows-main-outside-push` | Feature-branch push followed by `gh pr create --base main` → exit 0 (was a false positive) |
| s110 | `branch-protect-controls-still-block` | `-f`, a plain push to `main` and a push inside `bash -c` still → exit 2 |
| s111 | `block-dangerous-blocks-commit-no-verify` | `git commit --no-verify` / `-n` → exit 2 |
| s112 | `block-dangerous-blocks-push-no-verify` | `git push --no-verify` → exit 2 |
| s113 | `block-dangerous-blocks-no-verify-merge-rebase-cherry-pick` | `--no-verify` on merge, rebase and cherry-pick → exit 2 |
| s114 | `block-dangerous-allows-push-dry-run` | `git push -n` (dry run) and `--no-verify` inside a message → exit 0 |
| s115 | `protect-changes-blocks-npm-install-pkg` | `npm install lodash` → exit 2 unless approved |
| s116 | `protect-changes-blocks-package-manager-adds` | `pnpm/yarn/bun add`, `uv/poetry add`, `cargo add`, `go get`, `dotnet add package`, `composer require`, `bundle add` → exit 2 |
| s117 | `protect-changes-allows-restores-and-globals` | Lockfile restores, `-g` installs, `pip install -r`/`-e .` and mentions → exit 0 |
| s118 | `protect-changes-pip-install-advises` | `pip install <pkg>` → exit 0 with PreToolUse `additionalContext` advice |
| s119 | `protect-changes-bash-allows-with-claude-approved` | `CLAUDE_APPROVED=1` lets a package-manager add through, as for edits (s04) |
| s120 | `protect-files-blocks-git-add-env` | `git add .env` → exit 2 |
| s121 | `protect-files-allows-git-add-example-and-lockfile` | `git add .env.example`, a lock file, or a mere mention → exit 0 |
| s122 | `protect-files-blocks-git-add-all-with-env` | `git add -A` / `.` / `--all` with an un-ignored `.env` → exit 2, naming the file |
| s123 | `protect-files-allows-git-add-all-when-env-ignored` | `git add -A` when `.gitignore` excludes `.env` → exit 0 |
| s124 | `protect-files-blocks-commit-a-tracked-env` | `git commit -a` with a modified tracked `.env` → exit 2 |
| s130 | `secret-scan-warning-reaches-claude` | Secret warning is PostToolUse `additionalContext` JSON (was plain stdout, never seen) |
| s131 | `secret-scan-no-python-still-reaches-claude` | Without python3/jq the warning is still one valid `additionalContext` JSON object |
| s132 | `unicode-scan-warning-reaches-claude` | Invisible-Unicode warning is PostToolUse `additionalContext` JSON |
| s133 | `loop-detect-warning-reaches-claude` | The 4th-edit warning is PostToolUse `additionalContext` JSON; the 6th-edit block (s37) is unchanged |
| s134 | `glob-guidance-nudge-reaches-claude` | The path nudge is PreToolUse `additionalContext` JSON — one object even when two patterns match |
| s135 | `bash-budget-warning-reaches-claude` | The Bash output budget warning is PostToolUse `additionalContext` JSON |
| s136 | `read-budget-warning-reaches-claude` | The file-read budget warning is PostToolUse `additionalContext` JSON |
| s137 | `session-start-compact-context-reaches-claude` | The post-compaction context is `hookSpecificOutput` (a top-level `additionalContext` never reached the model) |
| s138 | `session-start-no-python-keeps-lines` | Without python3/jq the context stays one valid JSON object with its line breaks |
| s139 | `session-start-quiet-with-nothing-to-say` | Nothing to inject → no output at all, not an empty `hookSpecificOutput` |
| s140 | `prompt-router-quiet-without-prompt` | A payload with no prompt → no output, exit 0 |
| s141 | `skill-extract-reminder-reaches-claude` | The reminder is `hookSpecificOutput` for UserPromptSubmit (was a top-level `additionalContext`) |
| s142 | `branch-protect-blocks-push-all` | `git push --all` / `--branches` → exit 2 (pushes main/master too) |
| s143 | `branch-protect-allows-tags-and-all-mention` | Pushing tags, or text that only mentions `git push --all`, → exit 0 |
| s144 | `block-dangerous-blocks-hookspath-override` | `git -c core.hooksPath=…` / `--config-env` on commit, push, merge, rebase or cherry-pick → exit 2 |
| s145 | `block-dangerous-allows-other-git-config` | Other `git -c` settings and `core.hooksPath` inside a commit message → exit 0 |
| s146 | `protect-files-blocks-git-add-after-cd` | `cd sub && git add …` checks paths relative to `sub` and blocks a protected file |
| s147 | `protect-files-blocks-git-add-after-cd-into-nested-repo` | `cd` into a nested repo then `git add .` with `.env` → exit 2 |
| s148 | `protect-files-blocks-git-add-after-cd-below-non-repo-root` | Non-git project root, `cd app && git add .` in a nested repo with `.env` → exit 2 |
| s149 | `protect-files-allows-git-add-outside-cd-scope` | Subshell `cd`, `cd ..`, and safe files use the effective directory correctly |
| s150 | `skill-compliance-reminder-reaches-claude` | Strict-profile reminder is PostToolUse `additionalContext` JSON (was invisible plain stdout) |
| s151 | `prompt-router-broken-python3-still-routes` | Broken python3 stub falls back and still routes a domain prompt |
| s152 | `prompt-router-broken-python3-quiet-on-neutral` | Broken python3 + no jq + neutral prompt → no output |
| s153 | `prompt-router-git-checkout-not-billing` | Git checkout/checkouts, `striped`, and “in charge of” do not inject Billing context |
| s154 | `prompt-router-store-checkout-is-billing` | Store checkout, cart, Stripe and surcharge still inject Billing context |
| s155 | `protect-changes-blocks-ef-core-and-alembic-migrations` | EF Core `Migrations/` / `*ModelSnapshot.cs` and Alembic `alembic/versions/` → exit 2 |
| s156 | `protect-changes-migrations-guard` | Django, Knex and Rails migrations still block; neighbouring safe files are allowed |
| s157 | `glob-guidance-nudges-ef-core-alembic-and-root-migrations` | EF Core, Alembic and root-level migrations receive the one-shot migration nudge |
| s158 | `glob-guidance-migrations-guard` | Django and Rails still receive the nudge; a neighbouring DbContext does not |
| s159 | `block-dangerous-blocks-hookspath-env-config` | Inline or inherited `GIT_CONFIG_KEY_n=core.hooksPath` on a hook-running Git command → exit 2; unrelated config stays allowed |
| s160 | `protect-files-blocks-pathspec-files-and-unknown-cwd` | Pathspec files and unresolved cwd-changing shell constructs fail closed; literal safe paths remain allowed |

Every blocking scenario for `protect-files`, `block-dangerous-commands`, `branch-protect`, `conventional-commit` and `loop-detect` asserts `stdout_empty` and `stderr_starts_with: "BLOCKED"`: on exit 2 Claude Code feeds the agent stderr, so a reason written to stdout never reaches it.

## Add a scenario

Drop a JSON file in `bench/scenarios/sNN-<name>.json`:

```json
{
  "name": "sNN-short-descriptive-slug",
  "hook": ".claude/hooks/<your-hook>.sh",
  "setup_files": {
    "<relpath inside temp dir>": "<file content>"
  },
  "env": { "VAR": "value" },
  "payload": { "tool_name": "Edit", "tool_input": { "file_path": "{TMPROOT}/x" } },
  "expect": {
    "exit_code": 2,
    "stderr_contains": ["BLOCKED"],
    "stderr_starts_with": "BLOCKED",
    "stdout_contains": [],
    "stdout_not_contains": [],
    "stdout_empty": false,
    "stderr_not_contains": [],
    "state": [
      { "file": ".hook-state/<state>.json", "field": "status", "equals": "failed" }
    ],
    "file_grew": ["reports/session-audit.log"]
  },
  "notes": "Optional human-readable context — especially useful for regression scenarios."
}
```

Variables, substituted in `payload`, `env` values, `setup_files` contents and `setup_commands`:
- `{TMPROOT}` — the per-scenario temp directory (e.g. for absolute paths inside payload)
- `{KIT_ROOT}` — the kit checkout root

All `expect.*` keys are optional. The minimum useful assertion is `exit_code`. Two more exist for bounded runs: `max_seconds` (the hook returned within N seconds) and `no_process` (no process whose command line matches these `pgrep -f` patterns is still running).

### Multi-step scenarios

When behavior spans several hook runs — a failed gate blocking stop until the file is fixed — replace the top-level `hook` / `payload` / `env` / `expect` with a `steps` list of them. Steps share one workdir and run in order; each can add `setup_files` (written just before it runs) and `cwd` (relative to the workdir). `setup_commands` run once in the workdir before the first step, for what files can't express:

```json
{
  "name": "sNN-short-descriptive-slug",
  "setup_commands": ["git init -q ."],
  "steps": [
    {
      "hook": ".claude/hooks/quality-gate.sh",
      "setup_files": { "src/app.py": "def hello(\n" },
      "payload": { "tool_name": "Edit", "tool_input": { "file_path": "{TMPROOT}/src/app.py" } },
      "expect": { "exit_code": 0 }
    },
    { "hook": ".claude/hooks/stop-gate.sh", "payload": {}, "expect": { "exit_code": 2 } }
  ]
}
```

Failures are reported per step (`step 2: exit_code: want 2, got 0`). A multi-step scenario's top-level `env` applies to every step (a step's own `env` wins), and `{PATH}` in an env value expands to the runner's `PATH` — so `"PATH": "{TMPROOT}/bin:{PATH}"` puts a fake tool from `setup_files` ahead of the real one (make it executable in `setup_commands`).

## What it deliberately does not do

- **No LLM-graded evals.** Hooks are deterministic shell scripts; their behaviour is grounded in exit codes and state-file content. LLM grading would re-introduce non-determinism.
- **No session replay.** The harness invokes hooks directly — one, or a short `steps` sequence — not a full Claude Code session.
- **No cross-tool coverage.** Adapters for Cursor/Codex/Devin are out of scope.
- **No remote scoreboard.** The bench prints results to stdout; CI's check status is the scoreboard.

## Why this exists

The kit's commitment is *"deterministic enforcement"* (ADR-003). Without a bench, that commitment is a vibe. KitBench turns the commitment into a contract — and every PR that touches a hook re-asserts it.

Past bugs that KitBench would have caught (and that several scenarios above directly regression-cover):

- v1.10.0: `composer.lock` slipped through `protect-files` (s02)
- v1.10.0: `EXIT_CODE=$?` after `|| true` always reported "passed" (s08)
- v1.10.0: basename-only match missed `.github/workflows/ci.yml` (s05)
- v1.10.0: word-boundary regex in `prompt-router.sh` rejected "authentication" (s12)
