# Contributing

Agent Code Kit is a solo project: outside issues and pull requests aren't accepted, and issues are turned off on the repository. Security reports go through [private vulnerability reporting](https://github.com/lucasfelipe24/agent-code-kit/security/advisories/new).

This file is for people working on the kit itself. What users see is [README.md](README.md) — it's also the package page on npm, so keep maintainer detail here instead. The release process is in [RELEASING.md](RELEASING.md).

## Workflow

Work on one short-lived branch per task, cut from an up-to-date `main`:

```bash
git switch main && git pull
git switch -c fix/short-description
# ... commit ...
git push -u origin fix/short-description
```

- **Conventional Commits.** Write commit messages as `feat:`, `fix:`, `docs:` and so on; the `conventional-commit` hook enforces it, and the changelog is built from them.
- **Squash and merge.** Open a pull request to `main`. Squash is the only merge option the repository allows, and the branch is deleted when it merges.
- **The PR title is the changelog line.** Squashing turns the title into the commit on `main`, so write it as a Conventional Commit.
- **Parallel work goes in worktrees**, one per branch, under `.claude/worktrees/` (git-ignored). See `agent_docs/worktrees.md`.

## Releases

release-please keeps a `chore(main): release X.Y.Z` pull request open with the version bump and changelog. Merging it tags the release, creates the GitHub release and publishes the package to npm.

- `fix:` makes a patch release and `feat:` a minor one. `docs:`, `chore:` and `test:` don't make a release on their own.
- **The npm page only changes when a release is published.** A README change reaches users with the next `fix:` or `feat:` release.

npm token setup, 2FA and recovering from a failed publish are covered in [RELEASING.md](RELEASING.md).

## Checks

Run what CI runs before opening a pull request. Each npm script is a thin alias for a `scripts/*.sh` file, so local runs and CI can't drift apart.

| Command | What it runs |
|---|---|
| `npm test` | KitBench, the install smoke test and the CLI smoke test |
| `npm run bench` | KitBench only: every hook scenario in `bench/scenarios/` |
| `npm run test:install` | Install → upgrade → uninstall on throwaway projects |
| `npm run test:cli` | Every `bin/cli.sh` subcommand, the way `npx` runs them |
| `npm run check` | All drift checks: manifest, scaffold, strict settings, `AGENTS.md`, skills |

CI also runs markdown lint, a link check and `scripts/check-counts.sh`.

## Counts

`scripts/check-counts.sh` holds the canonical numbers of skills, hooks, agents and KitBench scenarios. When you add or remove one, bump its `EXPECTED_*` value and update the numbers in README.md. The script also reads the README: keep the phrases "harness with N scenarios" and "N/N PASS" there.

## Maintenance scripts

These stay in this repository. `install.sh` doesn't copy them into projects, and `--upgrade` reports copies an older install left behind.

| Script | What it does |
|---|---|
| `scripts/run-bench.sh` | Runs KitBench — see [bench/README.md](bench/README.md) to add a scenario |
| `scripts/test-install.sh` | Smoke-tests install → upgrade → uninstall on throwaway projects |
| `scripts/test-cli.sh` | Smoke-tests the `bin/cli.sh` subcommands |
| `scripts/sync-manifest.sh` | Regenerates `.kit-manifest`; `--check` fails when it's stale |
| `scripts/gen-strict-settings.sh` | Regenerates `.claude/settings.strict.json` from `settings.json` plus the strict delta; `--check` fails when it's stale |
| `scripts/check-counts.sh` | Asserts the skill, hook, agent and scenario totals |
| `scripts/check-scaffold.sh` | Asserts `scaffold/` carries none of this repository's own state |
| `scripts/build-skills.sh` | Builds `SKILL.md` files from `.tmpl` templates and shared blocks |
| `scripts/gen-skill-docs.sh` | Generates the website's skill pages from the `SKILL.md` files |

## Dogfooding

The kit runs on itself: this repository's `CODEBASE_MAP.md` and `tasks/` describe the kit, not a template. New installs copy from `scaffold/` instead, and `scripts/check-scaffold.sh` keeps the two apart.
