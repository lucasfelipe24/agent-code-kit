#!/usr/bin/env bash
#
# agent-code-kit CLI — npm distribution entry point
#
# Usage:
#   npx @lucasfelipe23/agent-code-kit init                    # Fresh install in current directory
#   npx @lucasfelipe23/agent-code-kit init --upgrade          # Upgrade existing installation
#   npx @lucasfelipe23/agent-code-kit init --profile strict   # Install with strict profile
#   npx @lucasfelipe23/agent-code-kit init --template nextjs  # Install with stack template
#   npx @lucasfelipe23/agent-code-kit doctor                  # Health check
#   npx @lucasfelipe23/agent-code-kit convert [target]        # Export to other formats (or `import`)
#   npx @lucasfelipe23/agent-code-kit generate agents-md      # Generate AGENTS.md
#   npx @lucasfelipe23/agent-code-kit uninstall [--dry-run]   # Remove the kit's files
#

set -euo pipefail

# Resolve the kit root (where package files live)
KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'USAGE'
Agent Code Kit — Staff-engineer discipline for AI coding agents

Usage:
  agent-code-kit init [options]        Install kit into current directory
  agent-code-kit doctor                Check installation health
  agent-code-kit skills                List available /skill commands
  agent-code-kit convert [target]      Export (cursor|windsurf|aider|agents-md|skills|codex|all)
  agent-code-kit convert import        Import other tools' rules → tasks/imported-rules.md
  agent-code-kit generate agents-md    Generate AGENTS.md from project sources
  agent-code-kit uninstall [options]   Remove the kit's files from the current directory

Init options:
  --upgrade              Upgrade existing installation
  --profile <name>       Installation profile (minimal|standard|strict)
  --template <name>      Stack template (nextjs|node-api|python-fastapi|go|rust|django|dotnet)
  --dest <path>          Target directory (default: current directory)

Uninstall options:
  --dry-run              List what would be removed and kept; change nothing
  --keep-tasks           Keep tasks/ (plan, decisions, lessons, handoffs)
  --keep-project         Keep your overlay (CLAUDE.project.md, agent_docs/project/, .claude/hooks/project/)
  --force                Skip the confirmation prompt

Examples:
  npx @lucasfelipe23/agent-code-kit init
  npx @lucasfelipe23/agent-code-kit init --profile strict --template nextjs
  npx @lucasfelipe23/agent-code-kit init --upgrade
  npx @lucasfelipe23/agent-code-kit doctor
  npx @lucasfelipe23/agent-code-kit uninstall --dry-run
USAGE
}

CMD="${1:-}"

case "$CMD" in
  init)
    shift
    # Run install.sh with the kit as the source (skip git clone)
    export AGENT_CODE_KIT_LOCAL="$KIT_ROOT"
    bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" "$@"
    ;;
  doctor)
    if [ -f "./scripts/doctor.sh" ]; then
      bash ./scripts/doctor.sh
    else
      echo "Error: doctor.sh not found. Run 'agent-code-kit init' first."
      exit 1
    fi
    ;;
  skills)
    SKILLS_DIR="./.claude/skills"
    if [ ! -d "$SKILLS_DIR" ]; then
      echo "Error: .claude/skills/ not found. Run 'agent-code-kit init' first."
      exit 1
    fi
    count=0
    echo "Available skills — invoke any with /<name>:"
    echo ""
    for d in "$SKILLS_DIR"/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      case "$name" in _*) continue ;; esac   # skip _shared / _templates
      [ -f "$d/SKILL.md" ] || continue
      # One awk reads the frontmatter straight from the file: a `grep -m1` fed by
      # a pipe exits on its first match, and under pipefail the writer's SIGPIPE
      # ended this whole listing (set -e) before the count line — intermittently.
      desc="$(awk '/^---$/ { if (++fm == 2) exit; next } fm == 1 && /^description:/ { print; exit }' "$d/SKILL.md" | sed 's/^description:[[:space:]]*//;s/^["'\'']//;s/["'\'']$//')"
      printf '  /%-22s %s\n' "$name" "$desc"
      count=$((count + 1))
    done
    echo ""
    echo "$count skills. They also auto-load via Claude Code's semantic matching."
    ;;
  convert)
    shift
    if [ -f "./scripts/convert.sh" ]; then
      bash ./scripts/convert.sh "${1:-all}"
    else
      echo "Error: convert.sh not found. Run 'agent-code-kit init' first."
      exit 1
    fi
    ;;
  generate)
    shift
    TARGET="${1:-}"
    case "$TARGET" in
      agents-md)
        if [ -f "./scripts/gen-agents-md.sh" ]; then
          bash ./scripts/gen-agents-md.sh .
        else
          echo "Error: gen-agents-md.sh not found. Run 'agent-code-kit init' first."
          exit 1
        fi
        ;;
      *)
        echo "Unknown generate target: $TARGET"
        echo "Available: agents-md"
        exit 1
        ;;
    esac
    ;;
  uninstall)
    shift
    # Runs in the current directory; removes only what .kit-manifest lists.
    bash "$KIT_ROOT/uninstall.sh" "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  version|--version|-v)
    cat "$KIT_ROOT/VERSION" | tr -d '[:space:]' | sed 's/#.*//'
    echo ""
    ;;
  "")
    usage
    ;;
  *)
    echo "Unknown command: $CMD"
    echo ""
    usage
    exit 1
    ;;
esac
