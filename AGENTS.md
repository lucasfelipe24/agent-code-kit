<!-- GENERATED FILE — do not edit directly -->
<!-- Regenerate with: ./scripts/gen-agents-md.sh -->
<!-- Source of truth: CLAUDE.md + CLAUDE.project.md -->

# AGENTS.md

## Project Overview

AgentCodeKit is a drop-in starter template that enforces disciplined software engineering practices on Claude Code. It transforms agent behavior from "eager intern" to "staff engineer" through structured workflows: Plan → Confirm → Implement → Verify.

Developers using Claude Code and similar agents often get inconsistent results — the agent skips planning, makes silent assumptions, drifts in scope, or stops before tasks are truly complete. This kit provides the guardrails (rules, hooks, skills, templates) to make agent behavior predictable and high-quality across any project.

## Tech Stack

- **Shell scripts** (bash) — hooks, install script, utilities
- **Markdown** — all rules, guides, templates, skills
- **JSON** — Claude Code settings configuration
- No runtime dependencies — this is a configuration kit, not a library

## Key Commands

| Action | Command |
|--------|---------|
| Install | `curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/install.sh \| bash` |
| Install with template | `curl -fsSL ... \| bash -s -- --template nextjs` |
| Uninstall | `curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/uninstall.sh \| bash` |
| Validate CODEBASE_MAP | `./scripts/validate.sh CODEBASE_MAP.md` |
| Lint markdown | `markdownlint .` |
| Repo consistency checks | `npm run check` |
| Tests (KitBench + install/CLI smoke) | `npm test` |
| Installation health | `./scripts/doctor.sh` |

---

## Workflow

- Plan before implementing. For tasks touching 3+ files, write a plan first.
- Verify every task: typecheck, lint, test, smoke test — in that order.
- Touch only files directly required by the task. No opportunistic refactoring.
- State assumptions explicitly. If 2+ valid approaches exist, present them.

## Protected Changes (Approval Required)

Stop and request approval before:
- New dependencies
- Database schema changes
- API contract changes
- Auth / permission logic
- Build system or core architecture changes

## Code Conventions

- Group by feature/domain, not by type.
- Names describe **what**, not **how**. Booleans: `is`, `has`, `should` prefix.
- Comments explain **why**, not **what**. No commented-out code.
- Fail fast — don't swallow errors. Handle them at the right level.
- Group imports: stdlib → external → internal. No circular imports.
- One logical change per commit. Message explains **why**, diff shows **what**.

## Architecture

AgentCodeKit is not a runtime application — it's a **configuration system** that layers on top of Claude Code CLI. It works through four mechanisms:

1. **Advisory rules** (`CLAUDE.md` → `agent_docs/`) — instructions the agent reads and follows. Can be conditionally loaded based on task type. Enforced by agent compliance, not technically.

2. **Deterministic hooks** (`.claude/hooks/`) — shell scripts wired to eight lifecycle events: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, Stop, StopFailure, SessionEnd (plus the opt-in Notification hook). These **cannot be bypassed** by the agent. Exit code 2 blocks the action (PreToolUse) or completion (Stop). Quality-gate records a per-file, session-scoped result in `.hook-state/quality-gate-state.json` (summary in `last_quality_gate.json`; a plain `quality-gate-files.tsv` log without a usable python3); stop-gate reads it and blocks while any edited file failed, timed out, errored or went stale (ADR-019, ADR-022). Audit log: `.hook-state/session-audit.log`. The directory is self-gitignored.

3. **Knowledge accumulation** (`tasks/lessons/` + `.claude/skills/`) — the agent learns from corrections (one lesson per file, with YAML frontmatter) and discoveries (skills) across sessions.

4. **Project overlay** (`CLAUDE.project.md` + `*/project/`) — a separation between kit-managed files (upgradeable) and project-specific customizations (never touched by kit). This allows projects to add stack-specific rules, hooks, and docs without merge conflicts during `--upgrade`.

Key design principle: CLAUDE.md acts as a **logical directory** — it contains minimal rules and conditional pointers to detailed guides. The agent reads only what's relevant to the current task, avoiding context bloat.

---

## Directory Structure

```text
.
├── CLAUDE.md                      # Core agent instructions (kit-managed)
├── CLAUDE.project.md              # Project-specific overlay (never touched by kit)
├── CODEBASE_MAP.md                # This repo's own map (installs get scaffold/ or examples/<template>/)
├── DESIGN.md                      # Design system template (optional, for UI projects)
├── WIKI.md                        # Knowledge-wiki conventions (installed by --wiki)
├── ARTIFACTS.md                   # HTML-artifact conventions (installed by --html)
├── AGENTS.md                      # Cross-tool rules — generated by scripts/gen-agents-md.sh, never hand-edited
├── README.md / README.pt-BR.md    # User docs (English / Portuguese)
├── CHANGELOG.md                   # Generated by release-please from Conventional Commits
├── CONTRIBUTING.md                # Solo project: no outside issues/PRs (ADR-027); squash-only; local checks
├── RELEASING.md                   # Release process; npm publishing is opt-in (ADR-028)
├── VERSION                        # Kit version, bumped by release-please
├── .kit-manifest                  # Tracks kit-managed files (auto-generated)
├── install.sh                     # One-line installer
├── uninstall.sh                   # Clean removal of all kit files
│
├── .github/workflows/             # validate.yml (CI checks), release.yml (release-please + opt-in npm publish), pages.yml (docs site → GitHub Pages)
├── .claude-plugin/                # Claude Code plugin marketplace entry (plugin.json, marketplace.json — ADR-009)
├── html-module/templates/         # --html: design-system.html + index.html seeded into a project's artifacts/
├── wiki-module/.claude/           # --wiki: wiki-maintainer agent + wiki-briefing / wiki-ingest / wiki-lint skills
├── artifacts/                     # Local HTML artifacts (specs, reports) — gitignored in this repo
│
├── agent_docs/                    # Agent behavior guides (read conditionally)
│   ├── workflow.md                # Task lifecycle, planning, session strategy
│   ├── debugging.md               # 4-step debug protocol
│   ├── testing.md                 # Test strategy & patterns
│   ├── conventions.md             # Code style & git hygiene
│   ├── subagents.md               # When/how to use subagents
│   ├── worktrees.md               # Worktree isolation for parallel file-mutating agents
│   ├── hooks.md                   # Hook system guide
│   ├── skills.md                  # Skill extraction & cleanup
│   ├── contracts.md               # Task contract system
│   ├── prompting.md               # Bias awareness & neutral prompting
│   ├── architecture-language.md   # Vocabulary for /deepening-review and /interface-design
│   ├── auto-mode.md               # Safe autonomy — when to stop and ask in auto mode / /loop
│   └── project/                   # Project-specific docs (never touched by kit)
│       ├── mission.md             # Product mission and audience (optional template)
│       ├── tech-stack.md          # Technology choices with rationale (optional template)
│       └── roadmap.md             # Current priorities and milestones (optional template)
│
├── tasks/                         # Session state & tracking (this repo's own; a fresh install gets scaffold/tasks/)
│   ├── todo.md                    # Current task board
│   ├── lessons/                   # Self-improvement log (one file per lesson)
│   │   ├── _index.md              #   Top Rules + per-lesson links
│   │   ├── _TEMPLATE.md           #   Template for new lessons
│   │   ├── <YYYY-MM-DD>-<slug>.md #   One file per lesson
│   │   └── _archive/              #   Archived lessons — out of _index.md, still found by /lesson-resurface
│   ├── specs/                     # Feature / spike spec folders (/shape-spec)
│   ├── decisions.md               # Architecture Decision Records
│   └── handoff.md                 # Session handoff template
│
├── .claude/                       # Claude Code configuration
│   ├── settings.json              # Hooks & permissions
│   ├── settings.strict.json       # Strict profile — generated from settings.json by scripts/gen-strict-settings.sh
│   ├── mcp-allowlist.txt.example  # Template: trusted MCP servers for mcp-gate.sh
│   ├── commands.json.example      # Template: declared typecheck/lint/test/build/smoke
│   ├── agents/                    # Custom agent definitions
│   │   ├── code-reviewer.md       # Code review agent
│   │   ├── security-reviewer.md   # Security review agent
│   │   ├── planner.md             # Implementation planning agent
│   │   ├── qa-reviewer.md         # Evidence-based QA verification agent
│   │   ├── dead-code-remover.md   # Dead code removal agent
│   │   └── devils-advocate.md     # Adversarial reviewer — ranked falsification list, not a checklist pass
│   ├── hooks/                     # Deterministic shell script hooks
│   │   ├── session-start.sh       # SessionStart: inject Tier 1 context pointers
│   │   ├── prompt-router.sh       # UserPromptSubmit: domain-keyword context injection
│   │   ├── protect-files.sh       # PreToolUse: block edits to secret files
│   │   ├── protect-changes.sh     # PreToolUse: block architectural changes w/o CLAUDE_APPROVED=1
│   │   ├── branch-protect.sh      # PreToolUse: block push to main/force push
│   │   ├── block-dangerous-commands.sh  # PreToolUse: block destructive commands
│   │   ├── conventional-commit.sh # PreToolUse: enforce commit message format
│   │   ├── glob-guidance.sh       # PreToolUse (Edit/Write): one-shot path nudge (tests, migrations)
│   │   ├── mcp-gate.sh            # PreToolUse (mcp__.*): allowlist gate + untrusted-input reminder
│   │   ├── subagent-pre.sh        # PreToolUse (Task|Agent): log subagent invocation
│   │   ├── secret-scan.sh         # PostToolUse: detect secrets in code
│   │   ├── unicode-scan.sh        # PostToolUse: detect invisible Unicode (Glassworm)
│   │   ├── loop-detect.sh         # PostToolUse: edit loop detection
│   │   ├── quality-gate.sh        # PostToolUse: run typecheck/lint, write .hook-state/
│   │   ├── bash-budget.sh         # PostToolUse (Bash): estimate cumulative output token cost, one-shot warn at threshold
│   │   ├── read-budget.sh         # PostToolUse (Read): estimate cumulative file-read token cost, one-shot warn at threshold
│   │   ├── subagent-post.sh       # PostToolUse (Task|Agent): fold subagent handoff summary
│   │   ├── tool-failure-observe.sh # PostToolUseFailure: count failed tool calls (scorecard)
│   │   ├── stop-failure-observe.sh # StopFailure: count turn-ending API errors (scorecard)
│   │   ├── stop-gate.sh           # Stop: block completion while any edited file's check failed, timed out, errored or went stale
│   │   ├── task-complete-notify.sh # Stop: desktop notification on success
│   │   ├── session-end.sh         # SessionEnd: append audit line to .hook-state/session-audit.log
│   │   ├── journal-fold.sh        # SessionEnd: fold /note journal findings into handoff
│   │   ├── auto-lint.sh           # PostToolUse: auto-lint after edits (opt-in)
│   │   ├── auto-format.sh         # PostToolUse: auto-format after edits (opt-in)
│   │   ├── skill-compliance.sh    # PostToolUse: skill checklist compliance (opt-in)
│   │   ├── skill-extract-reminder.sh  # UserPromptSubmit: skill extraction reminder (opt-in)
│   │   ├── notify-waiting.sh      # Notification: out-of-terminal ping when agent is waiting (opt-in)
│   │   ├── lib/                    # Shared hook library (json-parse — incl. hook_context for hookSpecificOutput JSON, state-counter, project-commands, redact-secrets, roots — package/worktree/state roots, run-with-timeout, gate-state — per-file gate results, python3 — usable-python3 probe, shell-segments — splits a Bash command into the shell commands it runs, for the Bash policy hooks)
│   │   └── project/               # Project-specific hooks (never touched by kit)
│   ├── extensions/                # Community / third-party skills (Layer 2 — see agent_docs/skills.md)
│   │   └── README.md              #   Kit creates the dir + README; never touches contents
│   └── skills/                    # Reusable knowledge (Layer 4 — kit-core skills)
│       ├── _shared/               # Shared template blocks
│       │   └── blocks/            # Reusable content blocks (preamble, scope, etc.)
│       ├── _templates/            # .tmpl skill templates (source of truth)
│       ├── skill-extractor/       # Meta-skill for extracting knowledge
│       ├── skill-generator/       # Meta-skill for generating project skills
│       ├── capabilities/          # Onboarding briefing — skills, agents, hooks and modules read live from disk
│       ├── code-quality-audit/    # Code smells & error handling audit
│       ├── performance-audit/     # Bottleneck & rendering analysis
│       ├── architecture-review/   # SOLID & module boundary review
│       ├── deepening-review/      # Depth/seam paradigm — interactive candidate grilling
│       ├── interface-design/      # Design It Twice — parallel competing interfaces
│       ├── testing-audit/         # Test coverage & quality audit
│       ├── dead-code-audit/       # Unused code detection
│       ├── refactoring-guide/     # Fowler-based refactoring plans
│       ├── accessibility-audit/   # WCAG 2.2 AA compliance
│       ├── dependency-audit/      # Vulnerability & license checks
│       ├── mcp-audit/             # MCP server trust audit (reconcile config vs allowlist)
│       ├── documentation-audit/   # Doc quality & sync audit
│       ├── doc-gardening/         # Drift detection between docs/ and current code
│       ├── quality-audit/         # golden-principles.yaml drift audit → docs/QUALITY_SCORE.md
│       ├── references-sync/       # Sync llms.txt-style dependency refs into docs/references/
│       ├── web-read/              # Clean markdown from a web page via the Defuddle CLI (fewer tokens than WebFetch)
│       ├── constitution/          # Author/extend golden-principles.yaml interactively (pairs with /quality-audit)
│       ├── project-health-report/ # Comprehensive health report (breadth-first, scoring)
│       ├── review-pipeline/       # Parallel multi-audit review with dedupe (PR-scope)
│       ├── lesson-refresh/        # Periodic refresh of tasks/lessons/ (keep/update/encode/archive)
│       ├── lesson-resurface/      # Archived/superseded lessons matching the task's tags — paths only, never bodies
│       ├── note/                  # Mid-session journal (finding/decision/summary) that survives compaction
│       ├── pulse/                 # Time-windowed outcome report saved to tasks/pulses/
│       ├── ship/                  # Deployment pipeline
│       ├── verification-status/   # Render the per-task verification ledger; record smoke test + silent-failure counts
│       ├── scorecard/             # Windowed scorecard from .hook-state/session-audit.log (schema_version 2 metrics)
│       ├── harness-init/          # Scaffold OpenAI-style docs/ harness structure (idempotent)
│       ├── retro/                 # Sprint retrospective & analytics
│       ├── office-hours/          # Pre-coding product validation
│       ├── feature-cycle/         # End-to-end spec → plan → implement → verify → review → ship orchestrator
│       ├── debug/                 # Root-cause debugging
│       ├── design-review/         # UI design consistency review
│       ├── ui-component-builder/  # Production-ready UI component generator (a11y, states, responsive)
│       └── shape-spec/            # Feature spec folder creation
│
├── bin/                           # npm distribution entry point
│   ├── agent-code-kit.js         # Node.js entry point for npx
│   └── cli.sh                     # Shell CLI implementation
├── package.json                   # npm package definition
│
├── scripts/                       # Utility scripts
│   ├── validate.sh                # Validates CODEBASE_MAP completeness
│   ├── statusline.sh              # Terminal status line
│   ├── doctor.sh                  # Installation health checker
│   ├── convert.sh                 # Export CLAUDE.md discipline + agents to each tool's native rules (.cursor/rules, .windsurf/rules, CONVENTIONS.md+.aider.conf.yml, AGENTS.md)
│   ├── validate-skills.sh         # Validates skill directory structure
│   ├── gen-skill-docs.sh          # Generates the docs site's pages (web/content/docs) from READMEs, skills, agents, modules, guides; --check fails on drift
│   ├── gen-agents-md.sh           # Generates cross-tool AGENTS.md from kit sources
│   ├── build-skills.sh            # Builds SKILL.md from .tmpl templates + shared blocks
│   ├── lesson-graph.sh            # Parses typed lesson frontmatter (supersedes/applies_to/contradicts/related_decisions); validates the graph and rewrites the auto sections in tasks/lessons/_index.md
│   ├── lesson-resurface.sh        # Deterministic frontmatter scan + scoring behind /lesson-resurface (lessons + _archive/)
│   ├── migrate-lessons.sh         # Converts a legacy single-file tasks/lessons.md into per-lesson files
│   ├── note.sh                    # Appends a tagged journal line for /note
│   ├── sync-manifest.sh           # Regenerates .kit-manifest from the tree; --check fails on drift (CI, npm run check)
│   ├── gen-strict-settings.sh     # Derives .claude/settings.strict.json from settings.json; --check fails on drift
│   ├── check-scaffold.sh          # Asserts scaffold/tasks/ is clean and its shared templates match tasks/
│   ├── check-counts.sh            # Asserts live skill/hook/agent totals match the declared counts
│   ├── run-bench.sh               # KitBench runner — executes every scenario in bench/scenarios/ in an isolated temp dir
│   ├── test-install.sh            # Smoke test for install.sh / uninstall.sh on a throwaway project
│   ├── test-cli.sh                # Smoke test for bin/cli.sh, the npx entry point
│   ├── check-prefix-residue.sh    # Fails on the former configuration prefix in any tracked path/content (ADR-029); run by sync-manifest.sh --check
│   └── lib/manifest.sh            # Shared .kit-manifest primitives (install, uninstall, sync-manifest)
│
├── bench/                         # KitBench — reproducible eval harness for the kit's deterministic-enforcement claims
│   ├── README.md                  # Corpus overview, how to add scenarios
│   └── scenarios/                 # JSON scenarios (one per file: name, hook, setup_files, env, payload, expect)
│
├── scaffold/                      # What a fresh install writes into a project
│   ├── CODEBASE_MAP.md            # Blank stack-agnostic map — the no-template fallback
│   └── tasks/                     # Pristine board, ADR log, handoff template, starter lessons
│
├── web/                           # Docs site — Fumadocs, static export to GitHub Pages (ADR-036); own package.json, never shipped
│   ├── DESIGN.md                  # The site's design source of truth
│   ├── app/[lang]/                # Landing ((home)/) and docs routes, en + pt-BR
│   ├── components/landing/        # Landing sections (command box, transcript, loop, skill index)
│   └── content/docs/              # index.mdx + meta.json by hand; everything else generated (gitignored)
│
└── examples/                      # Stack-specific templates
    ├── nextjs/                    # Next.js 16 + App Router
    ├── node-api/                  # Express + TypeScript
    ├── python-fastapi/            # FastAPI + SQLAlchemy
    ├── django/                    # Django (+ DRF)
    ├── go/                        # Go modules, stdlib-first
    ├── rust/                      # Cargo, edition-pinned
    └── dotnet/                    # C# / ASP.NET Core, EF Core
```
