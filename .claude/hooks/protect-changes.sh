#!/usr/bin/env bash
#
# protect-changes.sh — PreToolUse hook
#
# Blocks edits to architectural files (dependency manifests, migrations,
# auth/security paths) without explicit approval. Enforces CLAUDE.md
# "Protected Changes (Approval Required)" rule deterministically — prompt
# alone is not enough because the agent can decide to proceed silently.
#
# Distinct from protect-files.sh (which blocks secret-bearing files like
# .env and private keys). This hook is about *architectural* protection.
#
# Bypass: set CLAUDE_APPROVED=1 in the environment for the duration of the
# session, or pass it explicitly to the hook subshell. Reasoning behind the
# approval must be recorded in tasks/decisions.md (ADR template).
#
# Build configs (tsconfig, next.config, tailwind.config, Dockerfile, …) only
# hard-block when CCK_PROTECT_BUILD_CONFIGS=1 (set by the strict profile). In
# the standard profile they emit a non-blocking heads-up instead, since they are
# edited routinely. Dependency manifests, migrations, auth logic, and CI
# workflows always block regardless of profile.
#
# Bash: a package-manager command that adds a dependency blocks too — the
# manifest changes without an Edit (npm install|i|add <pkg>, pnpm add, yarn add,
# bun add, uv add, poetry add, cargo add, go get <module>, dotnet add package,
# composer require, bundle add). Restoring from a lockfile (npm install, npm ci,
# pnpm install, yarn) and global installs (-g) don't. `pip install <pkg>` gets
# a non-blocking note, since it may be a tool rather than a project dependency.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd || true)"
# Fail closed: a safety hook that can't load its library must block, not
# silently no-op. Empty HOOK_LIB → lib/ missing → exit 2.
if [ -z "$HOOK_LIB" ] || [ ! -f "$HOOK_LIB/json-parse.sh" ] || [ ! -f "$HOOK_LIB/shell-segments.sh" ]; then
  echo "BLOCKED: $(basename "$0") cannot load .claude/hooks/lib/ — refusing to run fail-open. Reinstall kit hooks (agent-code-kit init --upgrade)." >&2
  exit 2
fi
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/state-counter.sh"
source "$HOOK_LIB/shell-segments.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

TOOL_NAME=$(parse_json_field "tool_name")

case "$TOOL_NAME" in
  Edit|Write|NotebookEdit|Bash) ;;
  *) exit 0 ;;
esac

# block_change TARGET REASON — the reason goes to stderr: on exit 2 that is
# what Claude Code shows the agent.
block_change() {
  bump_counter "$ROOT/.hook-state/hook-firings.json" "protect-changes"
  cat <<EOF >&2
BLOCKED by protect-changes.sh: $1
Reason: $2

To proceed:
  1. Stop and present 2+ approaches with tradeoffs (per CLAUDE.md → Protected Changes)
  2. Record the decision in tasks/decisions.md using the ADR template
  3. Re-run with CLAUDE_APPROVED=1 in the environment

Projects can override this list via .claude/hooks/project/ (see hooks.md).
EOF
  exit 2
}

# advise MESSAGE — a note for Claude that doesn't block. Stderr at exit 0 only
# reaches the debug log; PreToolUse additionalContext on stdout reaches Claude.
advise() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$(json_str "$1")"
}

# first_arg FROM SKIP… — AT = the index in SH_W of the first word from FROM on
# that isn't an option or the value of an option listed in SKIP; -1 if none.
first_arg() {
  local k=$1 w skip
  shift
  AT=-1
  while [ "$k" -lt "${#SH_W[@]}" ]; do
    w=${SH_W[$k]}
    case "$w" in
      -*)
        for skip in "$@"; do
          if [ "$w" = "$skip" ]; then
            k=$((k + 1))
            break
          fi
        done
        ;;
      *)
        AT=$k
        return 0
        ;;
    esac
    k=$((k + 1))
  done
  return 0
}

# pkg_args FROM SKIP… — PKGS = how many words from FROM on name a package (not
# an option, not the value of an option in SKIP); GLOBAL=true on -g / --global.
pkg_args() {
  local k=$1 w skip
  shift
  PKGS=0
  GLOBAL=false
  while [ "$k" -lt "${#SH_W[@]}" ]; do
    w=${SH_W[$k]}
    k=$((k + 1))
    case "$w" in
      -g|--global|--location=global) GLOBAL=true ;;
      -*)
        for skip in "$@"; do
          if [ "$w" = "$skip" ]; then
            k=$((k + 1))
            break
          fi
        done
        ;;
      *) PKGS=$((PKGS + 1)) ;;
    esac
  done
  return 0
}

# pip_install FROM — DEP=pip when the pip install arguments from FROM on name a
# package; requirement files (-r), editable/local installs (-e ., ./pkg) don't.
pip_install() {
  local k=$1 w
  while [ "$k" -lt "${#SH_W[@]}" ]; do
    w=${SH_W[$k]}
    k=$((k + 1))
    case "$w" in
      -r|--requirement|-c|--constraint|-e|--editable|-t|--target|-i|--index-url|--extra-index-url|-f|--find-links|--prefix|--root|--src) k=$((k + 1)) ;;
      -*) ;;
      .|./*|../*|/*) ;;
      *) DEP=pip; return 0 ;;
    esac
  done
  return 0
}

# dependency_change — for the command in SH_W: DEP=add when it adds a project
# dependency, DEP=pip when it pip-installs a named package, else DEP="".
dependency_change() {
  local tool=${SH_W[0]##*/} sub
  DEP=""
  case "$tool" in
    npm)
      first_arg 1 --prefix -w --workspace
      if [ "$AT" -lt 0 ]; then return 0; fi
      case "${SH_W[$AT]}" in
        install|i|in|ins|inst|insta|instal|isnt|isnta|isntal|isntall|add)
          pkg_args $((AT + 1)) --prefix -w --workspace --registry --tag --omit --include
          if [ "$PKGS" -gt 0 ] && [ "$GLOBAL" = false ]; then DEP=add; fi
          ;;
      esac
      ;;
    pnpm|bun)
      first_arg 1 -C --dir -F --filter --cwd
      if [ "$AT" -lt 0 ]; then return 0; fi
      case "${SH_W[$AT]}" in
        add|a|install|i)
          pkg_args $((AT + 1)) -C --dir -F --filter --cwd --registry
          if [ "$PKGS" -gt 0 ] && [ "$GLOBAL" = false ]; then DEP=add; fi
          ;;
      esac
      ;;
    yarn)
      first_arg 1 --cwd
      if [ "$AT" -lt 0 ]; then return 0; fi
      sub=${SH_W[$AT]}
      if [ "$sub" = "workspace" ]; then  # yarn workspace <name> add <pkg>
        first_arg $((AT + 2)) --cwd
        if [ "$AT" -lt 0 ]; then return 0; fi
        sub=${SH_W[$AT]}
      fi
      if [ "$sub" = "add" ]; then
        pkg_args $((AT + 1)) --cwd
        if [ "$PKGS" -gt 0 ]; then DEP=add; fi
      fi
      ;;
    uv|poetry|cargo|bundle|composer|go)
      first_arg 1 --directory --project --manifest-path -d --working-dir -C
      if [ "$AT" -lt 0 ]; then return 0; fi
      sub=${SH_W[$AT]}
      case "$tool:$sub" in
        uv:add|poetry:add|cargo:add|bundle:add|composer:require|go:get)
          pkg_args $((AT + 1))
          if [ "$PKGS" -gt 0 ]; then DEP=add; fi
          ;;
        uv:pip)
          if [ "${SH_W[$((AT + 1))]-}" = "install" ]; then pip_install $((AT + 2)); fi
          ;;
      esac
      ;;
    dotnet)
      # dotnet add [<project>] package <name>
      first_arg 1
      if [ "$AT" -lt 0 ] || [ "${SH_W[$AT]}" != "add" ]; then return 0; fi
      if [ "${SH_W[$((AT + 1))]-}" = "package" ] || [ "${SH_W[$((AT + 2))]-}" = "package" ]; then DEP=add; fi
      ;;
    pip|pip3|pip3.*)
      first_arg 1
      if [ "$AT" -ge 0 ] && [ "${SH_W[$AT]}" = "install" ]; then pip_install $((AT + 1)); fi
      ;;
    python|python3|python3.*)
      if [ "${SH_W[1]-}" = "-m" ] && [ "${SH_W[3]-}" = "install" ]; then
        case "${SH_W[2]-}" in
          pip|pip3) pip_install 4 ;;
        esac
      fi
      ;;
  esac
  return 0
}

if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(parse_json_field "command")
  [ -z "$COMMAND" ] && exit 0

  # Escape hatch
  if [ "${CLAUDE_APPROVED:-0}" = "1" ]; then
    exit 0
  fi

  PIP_CMD=""
  shell_segments "$COMMAND"
  i=0
  while [ "$i" -lt "$SH_NSEG" ]; do
    sh_seg_command "$i"
    if [ "${#SH_W[@]}" -gt 0 ]; then
      dependency_change
      if [ "$DEP" = "add" ]; then
        block_change "${SH_W[*]}" "new dependency — adding a package requires explicit approval (CLAUDE.md → Protected Changes)"
      fi
      if [ "$DEP" = "pip" ]; then
        PIP_CMD="${SH_W[*]}"
      fi
    fi
    i=$((i + 1))
  done

  if [ -n "$PIP_CMD" ]; then
    advise "protect-changes: heads-up — '$PIP_CMD' installs a Python package. If the project will depend on it, that is a new dependency, a Protected Change per CLAUDE.md: get approval first, record it in tasks/decisions.md, and declare it in the project's manifest (pyproject.toml / requirements.txt) instead of installing it ad hoc."
  fi
  exit 0
fi

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0

# Escape hatch
if [ "${CLAUDE_APPROVED:-0}" = "1" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
# Normalise the path for prefix matching (strip leading ./ and leading slash for comparison)
NORM=$(echo "$FILE_PATH" | sed 's|^\./||')

BLOCKED=false
REASON=""

# Dependency manifests — adding/removing dependencies is a protected change
case "$BASENAME" in
  package.json|pyproject.toml|requirements.txt|requirements-*.txt|Pipfile|Gemfile|Cargo.toml|go.mod|composer.json|build.gradle|build.gradle.kts|pom.xml|*.csproj|*.fsproj|*.vbproj|Directory.Packages.props|packages.lock.json|packages.config)
    BLOCKED=true
    REASON="dependency manifest — new dependencies require explicit approval (CLAUDE.md → Protected Changes)"
    ;;
esac

# Migrations & schema files
if [ "$BLOCKED" = false ]; then
  case "$NORM" in
    */migrations/*|migrations/*|*/migrate/*|migrate/*|*/schema.sql|schema.sql|*/schema.prisma|schema.prisma)
      BLOCKED=true
      REASON="database migration/schema — confirm rollback plan and production impact"
      ;;
  esac
fi

# Auth / security paths. Presentational components under */components/* are UI,
# not auth logic — skip them so login forms / auth widgets don't trip the gate
# on every edit. Backend auth logic (src/auth/, lib/auth/, middleware)
# still blocks.
if [ "$BLOCKED" = false ]; then
  case "$NORM" in
    */components/*) ;; # presentational — not an auth-logic change
    */auth/*|auth/*|*/security/*|security/*|*/permissions/*|permissions/*|*/middleware/auth*|*/lib/auth/*)
      BLOCKED=true
      REASON="auth/security path — verify threat model and add tests before editing"
      ;;
  esac
fi

# Build system / core architecture configs (basename match). Blocking these is
# opt-in: the strict profile sets CCK_PROTECT_BUILD_CONFIGS=1, but in the standard
# profile they are edited routinely, so we advise without blocking.
if [ "$BLOCKED" = false ]; then
  case "$BASENAME" in
    Dockerfile|docker-compose.yml|docker-compose.yaml|Makefile|tsconfig.json|tsconfig.*.json|vite.config.ts|vite.config.js|next.config.js|next.config.mjs|next.config.ts|webpack.config.js|rollup.config.js|tailwind.config.js|tailwind.config.ts|Directory.Build.props|Directory.Build.targets|global.json|*.sln|*.slnx|nuget.config|NuGet.Config)
      if [ "${CCK_PROTECT_BUILD_CONFIGS:-0}" = "1" ]; then
        BLOCKED=true
        REASON="build config — core architecture change, requires plan and approval"
      else
        advise "protect-changes: heads-up — '$FILE_PATH' is a build config. Treat structural changes (toolchain, build target, module system) as a Protected Change per CLAUDE.md. Set CCK_PROTECT_BUILD_CONFIGS=1 (strict profile) to enforce a hard stop."
      fi
      ;;
  esac
fi

# CI workflows (path match — basename alone won't catch e.g. ci.yml under .github/workflows/)
if [ "$BLOCKED" = false ]; then
  case "$NORM" in
    .github/workflows/*.yml|.github/workflows/*.yaml|*/.github/workflows/*.yml|*/.github/workflows/*.yaml)
      BLOCKED=true
      REASON="CI workflow — pipeline change, requires plan and approval"
      ;;
  esac
fi

if [ "$BLOCKED" = true ]; then
  block_change "$FILE_PATH" "$REASON"
fi

exit 0
