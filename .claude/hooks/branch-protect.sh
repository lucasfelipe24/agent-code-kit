#!/usr/bin/env bash
#
# branch-protect.sh — PreToolUse hook
# Blocks direct pushes to main/master branch
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#
# Only the arguments of a `git push` that runs as a command are inspected (see
# lib/shell-segments.sh): `git push -u origin feat/x && gh pr create --base
# main` pushes a feature branch, and is allowed.
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

bump_branch_block() {
  bump_counter "$ROOT/.hook-state/hook-firings.json" "branch-protect"
}

# block_protected REASON — on exit 2 the agent sees stderr only, so the whole
# message goes there.
block_protected() {
  bump_branch_block
  exec 1>&2
  echo "BLOCKED: $1"
  echo ""
  echo "Create a feature branch and open a PR instead:"
  echo "  git checkout -b feat/your-feature"
  echo "  git push -u origin feat/your-feature"
  exit 2
}

TOOL_NAME=$(parse_json_field "tool_name")

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(parse_json_field "command")
[ -z "$COMMAND" ] && exit 0

# Only a push can reach a protected branch
case "$COMMAND" in
  *push*) ;;
  *) exit 0 ;;
esac

shell_segments "$COMMAND"
i=0
while [ "$i" -lt "$SH_NSEG" ]; do
  # `git push`, possibly preceded by global options (git -c key=val push,
  # git -C dir push) — sh_git_segment skips those.
  if ! sh_git_segment "$i" || [ "$SH_GIT_SUB" != "push" ]; then
    i=$((i + 1))
    continue
  fi

  FORCE=false
  LEASE=false
  MIRROR=false
  TAGS=false
  REMOTE_SEEN=false
  REFSPECS=0
  PROTECTED=false
  HEAD_REF=false
  k=0
  n=${#SH_GIT_ARGS[@]}
  while [ "$k" -lt "$n" ]; do
    ARG=${SH_GIT_ARGS[$k]}
    k=$((k + 1))
    case "$ARG" in
      --force) FORCE=true ;;
      --force-with-lease|--force-with-lease=*) LEASE=true ;;
      --mirror) MIRROR=true ;;
      --tags) TAGS=true ;;
      --repo|--receive-pack|--exec|--push-option) k=$((k + 1)) ;;
      --*) ;;
      -?*)
        # Short options cluster (-f, -uf); -o takes a value.
        OPTS=${ARG#-}
        while [ -n "$OPTS" ]; do
          case "${OPTS:0:1}" in
            f) FORCE=true ;;
            o)
              if [ -z "${OPTS:1}" ]; then k=$((k + 1)); fi
              break
              ;;
          esac
          OPTS=${OPTS:1}
        done
        ;;
      *)
        # The first positional is the remote; the rest are refspecs.
        if [ "$REMOTE_SEEN" = false ]; then
          REMOTE_SEEN=true
          continue
        fi
        REFSPECS=$((REFSPECS + 1))
        SPEC=$ARG
        # +<refspec> force-updates that ref, like --force
        case "$SPEC" in
          +*) FORCE=true; SPEC=${SPEC#+} ;;
        esac
        # The destination: after the colon (HEAD:main, feat:main, :main deletes
        # main), else the ref itself (main). `main:feature` pushes TO feature.
        case "$SPEC" in
          *:*) DEST=${SPEC#*:} ;;
          HEAD) HEAD_REF=true; DEST="" ;;
          *) DEST=$SPEC ;;
        esac
        DEST=${DEST#refs/heads/}
        case "$DEST" in
          main|master) PROTECTED=true ;;
        esac
        ;;
    esac
  done

  # Force push (check first — always block regardless of branch). Allow
  # --force-with-lease (safer alternative) but block --force, -f and +<refspec>.
  if [ "$FORCE" = true ] && [ "$LEASE" = false ]; then
    bump_branch_block
    # On exit 2 the agent sees stderr only — send the whole message there.
    exec 1>&2
    echo "BLOCKED: Force push detected"
    echo ""
    echo "Force pushing can overwrite remote history (--force, -f and a +<refspec> all force)."
    echo "Consider using --force-with-lease for a safer alternative,"
    echo "or get explicit approval from the user before force pushing."
    exit 2
  fi

  # --mirror makes every remote ref match the local ones: main/master included,
  # force-updated, and deleted if missing locally.
  if [ "$MIRROR" = true ]; then
    block_protected "git push --mirror overwrites every remote branch, main/master included"
  fi

  # A refspec whose destination is main/master
  if [ "$PROTECTED" = true ]; then
    block_protected "Direct push to main/master branch"
  fi

  # `git push <remote> HEAD`, or a bare `git push` / `git push origin` (no
  # refspec: the current branch goes to its upstream), resolve to the current
  # branch — blocked when that is main/master.
  if [ "$HEAD_REF" = true ] || { [ "$REFSPECS" = 0 ] && [ "$TAGS" = false ]; }; then
    CURRENT_BRANCH=$(git ${SH_GIT_CWD:+-C "$SH_GIT_CWD"} branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
      if [ "$HEAD_REF" = true ]; then
        block_protected "'git push <remote> HEAD' resolves to protected branch '$CURRENT_BRANCH'"
      fi
      block_protected "You are on '$CURRENT_BRANCH' — bare 'git push' would push to protected branch"
    fi
    # Cannot determine the branch (or it isn't protected): allow the push
  fi

  i=$((i + 1))
done

exit 0
