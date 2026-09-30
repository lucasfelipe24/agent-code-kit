<p align="center">
  <img src="assets/logo.png" alt="Agent Code Kit logo" width="160">
</p>

<h1 align="center">Welcome to Agent Code Kit 👋</h1>

<p align="center">
  <a href="https://www.npmjs.com/package/@lucasfelipe23/agent-code-kit">
    <img alt="npm version" src="https://img.shields.io/npm/v/@lucasfelipe23/agent-code-kit.svg">
  </a>
  <a href="https://www.npmjs.com/package/@lucasfelipe23/agent-code-kit">
    <img alt="npm downloads" src="https://img.shields.io/npm/dm/@lucasfelipe23/agent-code-kit.svg?color=blue">
  </a>
  <a href="#prerequisites">
    <img alt="node version" src="https://img.shields.io/node/v/@lucasfelipe23/agent-code-kit.svg">
  </a>
  <a href="https://github.com/lucasfelipe24/agent-code-kit/actions/workflows/validate.yml">
    <img alt="CI" src="https://github.com/lucasfelipe24/agent-code-kit/actions/workflows/validate.yml/badge.svg">
  </a>
  <a href="https://github.com/lucasfelipe24/agent-code-kit/graphs/commit-activity">
    <img alt="Maintained" src="https://img.shields.io/badge/Maintained%3F-yes-green.svg">
  </a>
  <a href="LICENSE">
    <img alt="License: MIT" src="https://img.shields.io/github/license/lucasfelipe24/agent-code-kit">
  </a>
  <a href="README.pt-BR.md">
    <img alt="Leia em português" src="https://img.shields.io/badge/lang-pt--BR-green">
  </a>
</p>

> **Guardrails for Claude Code.** It plans before it codes, stays inside the scope you approved, and can't call a task done while a check is failing.

<p align="center">
  <a href="#-demo">Demo</a> ·
  <a href="#-quick-start">Quick start</a> ·
  <a href="#-how-it-works">How it works</a> ·
  <a href="#-workflows">Workflows</a> ·
  <a href="#-skills-and-agents">Skills</a> ·
  <a href="#-configuration">Configuration</a> ·
  <a href="#-faq">FAQ</a>
</p>

```bash
npx @lucasfelipe23/agent-code-kit init
```

## ✨ Demo

Ask for "Add a search feature to the users page" without the kit, and you get three new packages, a refactored users module you didn't ask for, and a broken build nobody checked.

With the kit:

```text
You:    Add a search feature to the users page

Claude: I've read CODEBASE_MAP.md — the page is app/(dashboard)/users/page.tsx and
        the data comes from src/services/user.service.ts. This touches 3 files,
        so here's the plan:

        1. Handle a search param in users/page.tsx
        2. Add searchUsers() to user.service.ts
        3. Add a search input component (new file)

        Should I proceed?

You:    Yes

Claude: [implements, then runs]
        tsc --noEmit ✓   eslint ✓   npm test ✓   opened the page, search works ✓
        Done — all checks passed.
```

## 🤔 Why

Claude Code is capable, but eager. Left alone, it will:

- start editing before it understands your codebase
- "improve" files you never asked it to touch
- add a dependency or change your schema without asking
- say "done" without running a single check
- repeat the mistake you corrected yesterday

A prompt that says "don't do that" helps — until the model skips it. Agent Code Kit ships the rules **and** the enforcement behind them.

| | A hand-written `CLAUDE.md` | With the kit |
|---|---|---|
| **Rules** | Whatever you remembered to write | A tested workflow: plan, confirm, implement, verify |
| **When Claude forgets a rule** | Nothing happens | A hook blocks the action and tells Claude why |
| **"Done"** | Whenever Claude says so | Blocked while the typecheck or lint of any edited file is failing |
| **Dependencies, schema, auth** | Up to the model | Stopped until you approve; your choice is recorded as a decision |
| **Your corrections** | Gone when the session ends | Saved as lessons; the most important load in every session |
| **After a compaction or a new session** | Claude starts over | The active plan, top lessons and your notes come back on their own |
| **Reviews, audits, releases** | A new prompt each time | 37 skills and 6 subagents, each with a fixed process |

**It's a good fit if you** use Claude Code on a real codebase — new or one you've had for years — and you're responsible for what it ships; want the same rules for everyone on the team, committed with the code; or let Claude run on its own for longer stretches (auto mode, `/loop`) and need limits it can't talk its way past.

**It's probably not worth it if** you only use Claude Code for one-off scripts, or you're on Windows without WSL.

## 🚀 Quick start

### Prerequisites

- [Claude Code](https://code.claude.com/docs)
- Node.js 18 or later
- bash — macOS, Linux, or WSL on Windows

### Install

Run this in your project root:

```bash
npx @lucasfelipe23/agent-code-kit init
```

The installer detects your stack and picks a matching [template](#stack-templates).

<details>
<summary>Prefer not to use Node.js? Install with curl</summary>

The installer runs straight from GitHub (it needs git and bash):

```bash
curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/install.sh | bash
```

Pass the same options after `bash -s --`, for example `| bash -s -- --profile strict`, or `--version v1.22.3` for a specific release.

</details>

### Usage

1. **Describe your project** in `CODEBASE_MAP.md`: what it does, where things live, how to run it. Claude reads it at the start of every session, so the better it is, the better Claude works. `./scripts/validate.sh` lists the placeholders you haven't filled in.

2. **Check the install:**

   ```bash
   npx @lucasfelipe23/agent-code-kit doctor
   ```

   Doctor checks the files and settings, then runs a self-test of the hooks in a scratch project.

3. **Start Claude Code** as usual. There's no new command to learn — the rules and hooks are already active.

## 🧩 How it works

The kit adds four layers to your project:

| Layer | What it is | What it does |
|---|---|---|
| **Rules** | `CLAUDE.md` | A fixed workflow — plan, confirm, implement, verify — that Claude follows in every session |
| **Guardrails** | 28 hooks that Claude Code runs on each action | Block what the rules forbid: editing secrets, pushing to `main`, finishing while a check fails |
| **Skills & agents** | 37 skills and 6 subagents | Audits, debugging, reviews and releases — run when you ask |
| **Memory** | `tasks/` | The plan, decisions, lessons and handoffs that carry over between sessions |

Rules are advice. Hooks are enforcement: they run outside the model, on every matching action, whether or not it remembers the rule.

## 🎁 Features

Everything the kit adds, and what each part is for:

| Feature | What you get | Why it helps |
|---|---|---|
| [**Workflow rules**](#-the-rules) | `CLAUDE.md`: plan first, scope discipline, protected changes, verification, lessons | Claude works the same way in every session, on every machine |
| [**Guardrails**](#-guardrails) | 28 hooks — 23 on by default, 5 opt-in | The rules hold even when the model forgets them |
| [**Session automation**](#-a-session-with-the-kit) | Context put back at every start and after every compaction; a handoff saved at the end | No re-explaining the task after a `/clear` or a compaction |
| [**Workflows**](#-workflows) | Skills that chain from idea to pull request | A known path for features, bugs, reviews and releases |
| [**Skills**](#-skills-and-agents) | 37 slash commands for planning, debugging, audits, reviews, releases and reports | A repeatable process instead of an improvised prompt |
| [**Subagents**](#-skills-and-agents) | 6 specialists: code review, security, QA, planning, adversarial review, dead code | A second opinion with a narrow brief and its own context |
| [**Project memory**](#files-the-kit-writes-as-you-work) | `tasks/`: plan, decisions, lessons, handoffs, specs, reviews, reports | Decisions and corrections outlast the session and live in git with the code |
| [**Guides**](#guides-and-commands) | 12 guides in `agent_docs/`, read only when a task needs them | Deep guidance without paying for it in every prompt |
| [**Stack templates**](#stack-templates) | 7 stacks, detected at install | Stack rules and a pre-filled project map from day one |
| [**Optional modules**](#optional-modules) | Knowledge wiki, HTML artifacts, a local-only install | Add only what you use |
| [**Other AI tools**](#-other-ai-tools) | Export to Cursor, Windsurf, Aider, Codex and `AGENTS.md` | One set of rules across your tools |
| [**Safe upgrades**](#-upgrade) | A per-file install record, previews, `.kit-new` copies and backups | Upgrades update only untouched kit files; uninstall removes only what the kit wrote |
| [**Tested**](#-run-tests) | A regression harness run on Linux and macOS | Every guardrail is checked on every change to the kit |

### All hooks

<details>
<summary>The 28 hooks, what triggers them and what they do</summary>

**Block** — stop the action and tell Claude why

| Hook | Runs | What it does |
|---|---|---|
| `protect-files` | Before edits and `git add` | Blocks `.env` files, credentials, private keys and lock files — editing them or staging them |
| `protect-changes` | Before edits and shell commands | Blocks dependency manifests, migrations, auth code, CI workflows and dependency installs until you approve |
| `branch-protect` | Before shell commands | Blocks pushes to `main`/`master` and force pushes |
| `block-dangerous-commands` | Before shell commands | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE` and similar |
| `conventional-commit` | Before shell commands | Blocks commit messages that don't follow Conventional Commits |
| `mcp-gate` | Before MCP tool calls | Blocks MCP servers that aren't on `.claude/mcp-allowlist.txt` (off until you create it) |
| `stop-gate` | When Claude tries to finish | Blocks while an edited file's check is failing, timed out or older than the file |
| `loop-detect` | After edits | Warns when the same file shows up 4 times in the last 10 edits, and blocks at the 6th |

**Check** — run after each edit and report back

| Hook | Runs | What it does |
|---|---|---|
| `quality-gate` | After edits | Runs the file's typecheck, lint or syntax check and records the result for `stop-gate` |
| `secret-scan` | After edits | Warns about secrets written into a file: API keys, tokens, private keys, passwords |
| `unicode-scan` | After edits | Warns about invisible Unicode that can hide code |

**Context** — give Claude the right information at the right time

| Hook | Runs | What it does |
|---|---|---|
| `session-start` | At session start and after a compaction | Points Claude to the project map, the top lessons, the active task and the branch; after a compaction, also the task contract and the `/note` journal |
| `prompt-router` | On each prompt | Adds a rule reminder when you mention auth, billing, migrations, deploys or dependencies |
| `glob-guidance` | Before edits | The first edit to a test or migration file brings the guidance for that kind of file |
| `bash-budget`, `read-budget` | After shell commands and file reads | Warns once when the session's output passes a token budget |
| `journal-fold` | At session end | Saves the `/note` journal and the subagent handoff to `tasks/handoff-<session>.md` |

**Observe** — record what happened, for `/scorecard`

| Hook | Runs | What it does |
|---|---|---|
| `session-end` | At session end | Writes a scorecard line to `.hook-state/session-audit.log` |
| `subagent-pre`, `subagent-post` | Around each subagent | Log which agent ran and for how long |
| `tool-failure-observe` | After a failed tool call | Counts failures per tool |
| `stop-failure-observe` | When a turn ends on an API error | Records rate limits and server errors |
| `task-complete-notify` | When Claude finishes | Sends a desktop notification (macOS, Linux) |

**Opt-in** — on in the strict profile, or add them yourself

| Hook | Runs | What it does |
|---|---|---|
| `auto-format` | After edits | Runs your formatter |
| `auto-lint` | After edits | Runs your linter |
| `skill-compliance` | After edits | Reminds Claude to check the active skills' checklists |
| `skill-extract-reminder` | On each prompt | Reminds Claude to turn something new it learned into a skill |
| `notify-waiting` | When Claude is waiting for you | Sends a push notification (ntfy or Pushover) |

</details>

### How a project is organized

```text
your-project/
├── CLAUDE.md            # the workflow rules (the kit's)
├── CLAUDE.project.md    # your own rules; they override the kit's
├── CODEBASE_MAP.md      # your project map, read every session
├── agent_docs/          # guides Claude reads on demand; project/ is yours
├── .claude/
│   ├── settings.json    # which hooks run; allow and deny lists for commands
│   ├── hooks/           # the 28 hooks; project/ is yours
│   ├── skills/          # the 37 skills
│   ├── agents/          # the 6 subagents
│   └── extensions/      # skills from other authors
├── scripts/             # doctor, validate, statusline, convert and other helpers
├── tasks/               # plan, decisions, lessons, handoffs, specs, reports
└── .hook-state/         # the hooks' working state (ignored by git)
```

### Files the kit writes as you work

| File | Written by | What it's for |
|---|---|---|
| `tasks/todo.md` | Claude, when it plans | The plan of record: the current task, its steps, and "Not Now" for everything out of scope |
| `tasks/decisions.md` | Claude, after you approve a protected change | Architecture decisions (ADRs), with the options you weighed |
| `tasks/lessons/` | Claude, after you correct it | One lesson per file; `_index.md` holds the top rules loaded every session, and `/lesson-refresh` moves stale ones to `_archive/` |
| `tasks/handoff-<session>.md` | `journal-fold`, at session end | Where the next session picks up |
| `tasks/specs/<date>-<name>/` | `/shape-spec` | Spec, decisions and references for a feature that spans sessions |
| `tasks/*_CONTRACT.md` | You or Claude | A task's completion criteria, checked by `qa-reviewer` |
| `tasks/reviews/` | `/review-pipeline` | The merged review report |
| `tasks/pulses/`, `tasks/retros/` | `/pulse`, `/retro` | Periodic reports that build into a timeline |
| `golden-principles.yaml` | `/constitution` | Your coding principles, which `/quality-audit` checks |
| `docs/` | `/harness-init`, `/quality-audit`, `/references-sync` | Architecture docs, the quality score and local copies of library docs |
| `.hook-state/` | The hooks | Session state: gate results, the verification ledger, the session log, the `/note` journal, budgets |
| `.kit-manifest`, `.kit-baseline` | The installer | What the kit installed, so upgrades and uninstall touch only its files |
| `<file>.kit-new`, `.kit-backup/` | `--upgrade`, `uninstall` | The kit's newer version of a file you edited; copies saved before a replace or a removal |

### Guides and commands

<details>
<summary>The 12 guides in <code>agent_docs/</code></summary>

| Guide | Covers |
|---|---|
| `workflow.md` | Task lifecycle, goal reframing, the plan template, session strategy, context hygiene |
| `debugging.md` | The debugging protocol: evidence before a fix |
| `testing.md` | What and how to test |
| `conventions.md` | Code conventions and matching the existing style |
| `hooks.md` | Every hook, the profiles, and how to write your own |
| `skills.md` | Using skills and extending them |
| `subagents.md` | When and how to hand work to a subagent |
| `worktrees.md` | Isolating parallel agents that edit files |
| `auto-mode.md` | Running unattended safely, and when to stop and ask |
| `contracts.md` | Completion criteria for a task |
| `prompting.md` | Prompting and bias awareness |
| `architecture-language.md` | The vocabulary behind `/deepening-review` and `/interface-design` |

</details>

Every command runs as `npx @lucasfelipe23/agent-code-kit <command>`:

| Command | What it does |
|---|---|
| `init` | Installs the kit; `--upgrade`, `--diff`, `--profile`, `--template`, `--wiki`, `--html` and `--gitignore` change how |
| `doctor` | Checks the files, the settings and the hook wiring, then self-tests the hooks |
| `skills` | Lists the skills from the terminal |
| `convert <tool>` | Exports the rules to another AI tool |
| `generate agents-md` | Writes a portable `AGENTS.md` |
| `uninstall` | Removes what the kit installed, after you confirm |

## 📏 The rules

`CLAUDE.md` gives Claude a workflow to follow in every session:

| Rule | What Claude does |
|---|---|
| **Plan first** | For changes across 3+ files, restates your request as a goal it can check ("fix the bug" → "write a test that reproduces it, then make it pass"), writes a plan to `tasks/todo.md` and waits for your go-ahead |
| **Scope discipline** | Touches only what the task needs, matches the style of the files it edits, and logs anything else it notices under "Not Now" |
| **Protected changes** | Stops before new dependencies, schema, API, auth or build changes; presents options and records your choice as a decision |
| **Verification** | Runs typecheck, lint, tests and a smoke test, in that order, before calling a task done — and when it processes a batch, reports how many items failed or were skipped |
| **Lessons** | When you correct it, writes a lesson to `tasks/lessons/` and reviews the top rules at the start of each session |
| **Tiered context** | Loads the project map every session, the plan and handoff only when continuing, and lessons and decisions only when relevant |
| **After a compaction** | Re-reads the plan, the files it was editing and your notes before it writes another line |
| **Model per phase** | Plans and debugs with the most capable model, implements with a faster one |
| **Model vs code** | Leaves deterministic work — parsing, retries, format conversions, lookups — to code instead of the model |

Put your own rules in `CLAUDE.project.md` — they override the kit's.

## 🚧 Guardrails

Hooks are shell scripts Claude Code runs at fixed points: before a tool call, after an edit, when Claude tries to finish. A blocking hook stops the action and tells Claude why.

| Hook | What it blocks |
|---|---|
| `protect-files` | Edits to `.env` files, credentials, private keys and lock files |
| `protect-changes` | Edits to dependency manifests, migrations, auth code and CI workflows until you've approved the change |
| `branch-protect` | Pushes to `main`/`master`, and force pushes |
| `block-dangerous-commands` | `rm -rf /`, `git reset --hard`, `DROP TABLE` and similar |
| `conventional-commit` | Commit messages that don't follow [Conventional Commits](https://www.conventionalcommits.org/) |
| `quality-gate` + `stop-gate` | Finishing while the typecheck, lint or syntax check of an edited file is failing |
| `mcp-gate` | Calls to MCP servers that aren't on your allowlist (off until you create `.claude/mcp-allowlist.txt`) |

The default profile turns on 23 of the 28 hooks. The ones not listed above watch instead of block: they warn about secrets and invisible Unicode in edits, spot edit loops and oversized tool output, re-inject your plan after a context compaction, and keep a session log for `/scorecard`. After install, `agent_docs/hooks.md` describes every hook and how to write your own.

The hooks are tested — see [Run tests](#-run-tests).

## 🔁 A session with the kit

What runs, and when, without you typing a command:

| When | What happens |
|---|---|
| **The session starts** | Claude gets pointers to your project map, the top lessons, the active task in `tasks/todo.md` and the current branch |
| **You send a prompt** | Mention auth, billing, a migration, a deploy or a new dependency, and Claude gets a short reminder of the rules that apply |
| **Before an edit** | Secrets, lock files and unapproved protected changes are blocked; the first edit to a test or migration file brings up the guidance for that kind of file |
| **Before a shell command** | Pushes to `main`, destructive commands, dependency installs and commit messages are checked |
| **After an edit** | The file's typecheck or lint runs and the result is recorded; the edit is scanned for secrets and invisible Unicode; a 4th edit to the same file warns of a loop, a 6th is blocked |
| **Claude tries to finish** | Blocked while any edited file's check is failing, timed out or older than the file |
| **The context is compacted** | The active task, top lessons, any task contract and your `/note` entries are put back |
| **The session ends** | A scorecard line is written for `/scorecard`, and your `/note` entries are saved to `tasks/handoff-<session>.md` for the next session |

## 🧭 Workflows

The skills are built to chain. Some common paths:

**Build a feature**

1. `/office-hours` — pin down what to build and why, while the idea is still fuzzy.
2. `/shape-spec` — create a spec folder, when the work will span several sessions.
3. Ask for the change. Claude restates it as a goal it can check, writes the plan to `tasks/todo.md` and waits for your go-ahead.
4. Claude implements; every edit is checked as it's made.
5. `/review-pipeline` — parallel audits over the diff, before you merge.
6. `/ship` — tests, changelog, clean commits and the pull request.

`/feature-cycle` runs steps 2–6 in one go and stops at the first failed gate.

**Fix a bug** — `/debug` gathers evidence and finds the root cause before touching code, writes a test that reproduces the bug, then makes it pass.

**Review a change** — `/review-pipeline` runs several audits over the diff in parallel and merges their findings into one report. When you want someone to try to break the change, ask for the `devils-advocate` agent.

**Work across sessions** — The plan in `tasks/todo.md` and the decisions in `tasks/decisions.md` outlast any session. `/note` saves a finding or decision mid-session: it survives a compaction and is saved to a handoff when the session ends, so the next one picks up where you stopped.

**Adopt it in an existing project**

1. Run `init`. Your own `CLAUDE.md`, `.claude/settings.json`, hooks, agents and scripts stay as they are, and the installer lists what it left alone.
2. Kept your own `settings.json`? Register the kit's hooks in it — `doctor` fails until you do.
3. Kept your own `CLAUDE.md`? Move your rules into `CLAUDE.project.md` to switch on the kit's (see the [FAQ](#-faq)).
4. Fill in `CODEBASE_MAP.md`. `/constitution` can infer your coding principles from the existing code into `golden-principles.yaml`, and `/quality-audit` then checks the code against them.

**Keep an eye on it**

| When | Skill | What it tells you |
|---|---|---|
| Weekly | `/pulse` | What shipped, broke and was learned, saved to `tasks/pulses/` as a timeline |
| Weekly | `/retro` | How the work went: sessions, volume, hotspots, what to change |
| Any time | `/scorecard` | Session numbers: gate pass rate, blocks fired, output budget |
| Every few weeks | `/lesson-refresh` | Which lessons to keep, sharpen, promote or archive |

## 🧰 Skills and agents

Skills are commands you run in Claude Code with `/name`. Some good ones to start with:

| Skill | What it does |
|---|---|
| `/capabilities` | Shows everything the kit makes available in this project |
| `/debug` | Finds the root cause before touching code, then adds a regression test |
| `/review-pipeline` | Runs several audits over your diff in parallel and merges the findings into one report |
| `/ship` | Tests, changelog, clean commits and a pull request |
| `/office-hours` | Clarifies what to build and why, before any code |

<details>
<summary>All 37 skills</summary>

**Plan**

| Skill | What it does |
|---|---|
| `/office-hours` | Clarifies what to build and why, before any code |
| `/shape-spec` | Creates a spec folder for a feature that spans several sessions |
| `/interface-design` | Has parallel subagents design competing interfaces, then compares them |
| `/feature-cycle` | Runs spec → plan → build → verify → review → ship end to end, stopping at any failed gate |

**Build and debug**

| Skill | What it does |
|---|---|
| `/debug` | Finds the root cause before touching code, then adds a regression test |
| `/ui-component-builder` | Builds a UI component with accessibility, loading/empty/error states and responsive layout |
| `/refactoring-guide` | Plans a refactoring step by step, with the risk of each step |
| `/web-read` | Turns a web page into clean markdown, using fewer tokens than a raw fetch |

**Review and audit**

| Skill | What it does |
|---|---|
| `/review-pipeline` | Runs several audits over your diff in parallel and merges the findings into one report |
| `/code-quality-audit` | Code smells, error handling and maintainability |
| `/architecture-review` | Module boundaries, dependencies and SOLID |
| `/deepening-review` | Finds shallow, pass-through modules and works through the one you pick |
| `/performance-audit` | Startup, rendering, memory and I/O bottlenecks |
| `/testing-audit` | Test coverage, quality and flaky tests |
| `/dead-code-audit` | Unused functions, imports and files |
| `/dependency-audit` | Vulnerabilities, outdated versions, licenses and bloat |
| `/accessibility-audit` | WCAG 2.2 AA compliance |
| `/design-review` | Visual consistency and responsive behavior of a built UI |
| `/documentation-audit` | Comment, API doc and README quality |
| `/doc-gardening` | Docs that have drifted from the code |
| `/mcp-audit` | Your MCP servers against the allowlist, with their risks |
| `/quality-audit` | Your code against your `golden-principles.yaml` |
| `/project-health-report` | A whole-project snapshot across all of the above |

**Ship**

| Skill | What it does |
|---|---|
| `/ship` | Tests, changelog, clean commits and a pull request |
| `/verification-status` | Which checks ran for the current task, plus the manual ones still owed |

**Memory and reports**

| Skill | What it does |
|---|---|
| `/note` | Saves a finding or decision so it survives a context compaction |
| `/lesson-refresh` | Reviews `tasks/lessons/`: keep, update, promote or archive each lesson |
| `/lesson-resurface` | Finds archived lessons related to the current task |
| `/pulse` | What shipped, broke and was learned over a period |
| `/retro` | A weekly retrospective |
| `/scorecard` | Session numbers: gate pass rate, blocks fired, output budget |

**Project setup**

| Skill | What it does |
|---|---|
| `/constitution` | Writes your project's `golden-principles.yaml` |
| `/harness-init` | Scaffolds a `docs/` structure (architecture, plans, quality score) |
| `/references-sync` | Pulls library docs into `docs/references/` so Claude reads them locally |
| `/skill-generator` | Generates skills tailored to your stack |
| `/skill-extractor` | Turns something learned in a session into a reusable skill |

</details>

List them from the terminal with `npx @lucasfelipe23/agent-code-kit skills`. The optional wiki module adds `/wiki-ingest`, `/wiki-lint` and `/wiki-briefing`.

**Subagents** Claude can hand work to:

| Agent | What it does |
|---|---|
| `code-reviewer` | Reviews for correctness, maintainability and performance |
| `security-reviewer` | Looks for vulnerabilities |
| `qa-reviewer` | Checks a task against its completion criteria, with evidence |
| `planner` | Turns a task into an implementation plan |
| `devils-advocate` | Tries to break a change: hidden assumptions, inputs that fail it |
| `dead-code-remover` | Removes code it has verified is unused |

## 📦 What gets installed

Everything goes into your project directory, where you can read and edit it. Nothing is installed globally.

| Path | What it is | Upgrades |
|---|---|---|
| `CLAUDE.md` | The workflow rules | Updated, unless you've edited it |
| `CLAUDE.project.md` | Your project's own rules | Never touched |
| `CODEBASE_MAP.md` | Your project's map — fill it in | Never touched |
| `agent_docs/` | Guides Claude reads when relevant: workflow, debugging, testing, hooks | Updated, except `agent_docs/project/` (yours) |
| `.claude/hooks/` | The 28 hook scripts | Updated, except `.claude/hooks/project/` (yours) |
| `.claude/skills/`, `.claude/agents/` | Skills and subagents | Updated |
| `.claude/settings.json` | Which hooks run, and allow/deny lists for commands | Never touched |
| `tasks/` | Plan, decisions, lessons and handoffs — Claude writes here as it works | Never touched |
| `scripts/` | `doctor.sh`, `statusline.sh`, `convert.sh` and other helpers | Updated |
| `.kit-manifest`, `.kit-baseline` | What the kit installed, so upgrades and uninstall touch only its files | Rewritten |

If your project already has a `CLAUDE.md` or `CODEBASE_MAP.md`, the installer keeps yours and asks before continuing.

## 🔧 Configuration

### Profiles

```bash
npx @lucasfelipe23/agent-code-kit init --profile strict
```

| Profile | What you get |
|---|---|
| `standard` (default) | Rules, docs, skills, agents and 23 hooks |
| `minimal` | Hooks only — no `CLAUDE.md` or docs |
| `strict` | Standard, plus the 5 opt-in hooks (auto-lint, auto-format, skill-compliance, skill-extract-reminder, notify-waiting); edits to build configs also need approval |

### Stack templates

Each template adds stack-specific rules to `CLAUDE.md` and a pre-filled `CODEBASE_MAP.md`. The installer picks one from your project files (`next.config.*`, `go.mod`, `Cargo.toml`, `*.sln`/`*.csproj`, `manage.py`, `requirements.txt`, `package.json`); choose one yourself with `--template <name>`.

| Template | Stack | Adds rules for |
|---|---|---|
| `nextjs` | Next.js 16, App Router, Prisma, Tailwind | Server vs client components, build verification |
| `node-api` | Express, TypeScript, Knex.js | Layered architecture, API design |
| `python-fastapi` | FastAPI, SQLAlchemy 2.0, Pydantic v2 | Async patterns, dependency injection, Alembic |
| `django` | Django (+ DRF) | Fat models, migration discipline, N+1 queries |
| `go` | Go modules | Error wrapping, context propagation, `-race` tests |
| `rust` | Cargo | `Result`/`?` over `unwrap`, clippy `-D warnings`, `unsafe` gating |
| `dotnet` | C#, ASP.NET Core, EF Core | Nullable references, `CancellationToken`, EF migrations |

### Optional modules

| Flag | Adds |
|---|---|
| `--wiki` | A knowledge wiki Claude builds from sources you add, with `/wiki-ingest`, `/wiki-lint` and `/wiki-briefing` |
| `--html` | Conventions for writing specs, plans and reports as HTML pages instead of markdown |
| `--gitignore` | Adds the kit's files to `.gitignore`, to keep the kit local instead of committing it |

<details>
<summary>Tell the checks how to run</summary>

By default the quality gate detects your typecheck and lint commands. To set them yourself, copy `.claude/commands.json.example` to `.claude/commands.json`:

```json
{
  "typecheck": "pnpm -w typecheck",
  "lint": "pnpm -w lint",
  "test": "pnpm -w test",
  "build": "pnpm -w build"
}
```

`typecheck` and `lint` run after every edit, so keep them fast. `test` and `build` run only for `/ship` and reviews.

</details>

<details>
<summary>Turn a hook on or off</summary>

Hooks are listed in `.claude/settings.json`: remove an entry to turn that hook off. `agent_docs/hooks.md` shows how to add the opt-in ones. The same file holds the allow and deny lists for commands — test runners and linters are allowed; `curl`, `wget`, reading `.env` and `npm publish` are denied.

</details>

<details>
<summary>Status line</summary>

`scripts/statusline.sh` shows the model, branch, context use and session cost at the bottom of Claude Code. Add it to `.claude/settings.json` ([status line docs](https://code.claude.com/docs/en/statusline)):

```json
{
  "statusLine": {
    "type": "command",
    "command": "./scripts/statusline.sh"
  }
}
```

```text
Opus | feat/search | ███████░░░ 78% | $1.24
```

</details>

## 🔄 Upgrade

```bash
npx @lucasfelipe23/agent-code-kit@latest init --upgrade
```

- Kit files you haven't edited are updated.
- Kit files you've edited are kept. If the kit changed them too, its version is saved next to yours as `<file>.kit-new` for you to merge.
- A file of your own at a path the kit also uses (your `scripts/validate.sh`, your `.claude/agents/code-reviewer.md`) stays as it is when the install record is marked complete, which every first install and every `--upgrade` does. The summary lists them as "yours". Delete yours and re-run to get the kit's version. An install from before the record replaces such a file and keeps the previous copy in `.kit-backup/`.
- Your files — `CODEBASE_MAP.md`, `CLAUDE.project.md`, `tasks/`, `.claude/settings.json` and the `project/` folders — are never touched.

Add `--diff` to preview an upgrade: it runs on a scratch copy and reports what would change, without writing to your project. To install a specific version, put it in the package name: `npx @lucasfelipe23/agent-code-kit@1.22.2 init`.

## 🧹 Uninstall

```bash
npx @lucasfelipe23/agent-code-kit uninstall --dry-run   # list what would be removed and kept
npx @lucasfelipe23/agent-code-kit uninstall             # remove, after you confirm
```

Only files the install record (`.kit-baseline`) lists, and that you haven't edited since, are removed. A kit file you changed stays and is listed as kept, and so does a file the record doesn't list, even when `.kit-manifest` names it. Files you added to shared folders like `scripts/` or `.claude/skills/` stay, and so does `CODEBASE_MAP.md` once you've filled it in. Inside `tasks/`, only the untouched scaffold files go; anything you edited or added stays, and so does the folder (a `tasks/` of your own code is safe). Your overlay (`CLAUDE.project.md` and the `project/` folders) is removed by default, so keep it with `--keep-project`; `--keep-tasks` keeps all of `tasks/`.

Installed with curl? `curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/uninstall.sh | bash -s -- --dry-run` works the same way, except that it can't compare files with the kit's own copies, so it always keeps `CODEBASE_MAP.md` and every file in `tasks/`.

## 🔌 Other AI tools

The rules travel to other tools; the hooks don't, because they depend on Claude Code's hook system.

| Command | Writes |
|---|---|
| `npx @lucasfelipe23/agent-code-kit convert cursor` | `.cursor/rules/` |
| `npx @lucasfelipe23/agent-code-kit convert windsurf` | `.windsurf/rules/` |
| `npx @lucasfelipe23/agent-code-kit convert aider` | `CONVENTIONS.md` and `.aider.conf.yml` |
| `npx @lucasfelipe23/agent-code-kit convert agents-md` | [`AGENTS.md`](https://agents.md/), read by Codex, Copilot, Jules and others |
| `npx @lucasfelipe23/agent-code-kit convert skills` | The skills in `.agents/skills/`, read by Codex, Zed and Amp |
| `npx @lucasfelipe23/agent-code-kit convert codex` | `AGENTS.md` plus the skills in `.agents/skills/` |
| `npx @lucasfelipe23/agent-code-kit convert all` | All of the above |

Already have rules for another tool? `convert import` gathers them into `tasks/imported-rules.md` for you to review and move into `CLAUDE.project.md`.

## 🤖 Auto mode and /loop

Claude Code's auto mode approves routine actions without asking. The kit is what makes that safe: its blocking hooks and deny list run before auto mode's classifier, and the classifier can only add restrictions, never lift them. The same holds for unattended `/loop` runs. After install, see `agent_docs/auto-mode.md`.

## ❓ FAQ

<details>
<summary><b>Will it overwrite my <code>CLAUDE.md</code>?</b></summary>

No. If you already have one, the installer keeps it and asks before continuing. To adopt the kit's rules later, move yours into `CLAUDE.project.md`, delete `CLAUDE.md` and run `npx @lucasfelipe23/agent-code-kit init --upgrade`.

</details>

<details>
<summary><b>Does it send my code anywhere?</b></summary>

No. The kit's hooks and scripts run locally and don't phone home. The only network call they make is an optional push notification when Claude is waiting for you (ntfy or Pushover), off unless you set it up.

</details>

<details>
<summary><b>A check is failing for a reason unrelated to my task. Is Claude stuck?</b></summary>

Set `SKIP_QUALITY_GATE=1` to let it finish. Use it for broken infrastructure, not to skip a real failure.

</details>

<details>
<summary><b>Should I commit the kit's files?</b></summary>

Committing them gives everyone on the team the same rules, hooks and memory. To keep the kit to yourself, install with `--gitignore`.

</details>

<details>
<summary><b>Does it work on Windows?</b></summary>

Through WSL. The installer and the hooks are bash scripts.

</details>

## 🧪 Run tests

The hooks are tested. The kit's repository runs a regression harness with 158 scenarios — each blocking behavior plus tests for past bugs — on every change. From a clone of the repository:

```bash
npm test        # KitBench hook scenarios, then the install/uninstall and CLI tests
npm run check   # manifest, scaffold, strict-settings, AGENTS.md and skill checks
```

```text
KitBench
  s01-protect-files-blocks-env              PASS
  s31-branch-protect-blocks-push-u-main     PASS
  s52-quality-gate-fix-unblocks-stop        PASS
  ...
  158/158 PASS  0 FAIL
```

## 👤 Author

**Lucas Felipe**

- GitHub: [@lucasfelipe24](https://github.com/lucasfelipe24)

## 🤝 Contributing

Agent Code Kit is a solo project: it's built and maintained by one person, so it doesn't take outside issues or pull requests. Found a security problem? Report it privately through [GitHub's vulnerability reporting](https://github.com/lucasfelipe24/agent-code-kit/security/advisories/new).

## Show your support

Give a ⭐️ if this project helped you!

## 📝 License

Copyright © 2026 [Lucas Felipe](https://github.com/lucasfelipe24).<br />
This project is [MIT](LICENSE) licensed.
