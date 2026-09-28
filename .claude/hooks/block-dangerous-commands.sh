#!/usr/bin/env bash
#
# block-dangerous-commands.sh — PreToolUse hook
# Blocks destructive shell commands that are hard to reverse
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
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

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(parse_json_field "command")
[ -z "$COMMAND" ] && exit 0

BLOCKED=false
REASON=""

# Destructive file operations — catch rm -rf, rm -r -f, rm --recursive --force, etc.
# The optional (--\s+)? handles the POSIX end-of-options separator (e.g. rm -rf -- /)
RM_RECURSIVE='rm\s+(-[a-zA-Z]*r[a-zA-Z]*\s+(-[a-zA-Z]+\s+)*|-r\s+-f\s+|-f\s+-r\s+|--recursive\s+(-f\s+|--force\s+)?|-r\s+--force\s+)(--\s+)?'

# Absolute system directories that must never be recursively deleted. Deeper,
# project-local paths (e.g. /home/u/app/node_modules, /tmp/build) stay allowed —
# only the catastrophic roots and system trees are blocked.
RM_SYS_DIRS='etc|usr|var|bin|sbin|lib|lib64|opt|boot|dev|proc|sys|root|srv|System|Library|Applications|private|Network|Volumes|cores'

# rm -rf /   or   rm -rf /*   (whole filesystem)
if grep -qE "${RM_RECURSIVE}/(\\*|[[:space:]]*($|[;&|]))" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on root directory"
fi

# rm -rf /etc , /usr/local , sudo rm -rf /etc/nginx — any system path
if grep -qE "${RM_RECURSIVE}/(${RM_SYS_DIRS})(/|[[:space:]]|[;&|]|$)" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on a system directory"
fi

# Whole home directory: ~ , ~/Documents , \$HOME , /home/<user> , /Users/<user>.
# Deeper paths (~/proj/dist, /home/u/app/node_modules) remain allowed.
if grep -qE "${RM_RECURSIVE}(~|\\\$HOME|\\\$\{HOME\})(/[^/[:space:];&|]+)?([[:space:]]|[;&|]|$)" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on home directory"
fi

if grep -qE "${RM_RECURSIVE}/(home|Users)(/[^/[:space:];&|]+)?([[:space:]]|[;&|]|$)" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on home directory"
fi

if grep -qE "${RM_RECURSIVE}\\.\s*($|[;&|])" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete on current directory"
fi

if grep -qE "${RM_RECURSIVE}\\*" <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive delete with wildcard"
fi

# --no-preserve-root exists only to defeat rm's built-in root guard
if grep -qE -- '--no-preserve-root' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="rm --no-preserve-root bypasses root protection"
fi

# Git history destruction
if grep -qE 'git\s+reset\s+--hard' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="git reset --hard discards all uncommitted changes"
fi

if grep -qE 'git\s+clean\s+(-[a-zA-Z]*f[a-zA-Z]*d|-[a-zA-Z]*d[a-zA-Z]*f|-[a-zA-Z]*f\s+-[a-zA-Z]*d|-[a-zA-Z]*d\s+-[a-zA-Z]*f)' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="git clean -fd permanently deletes untracked files"
fi

# Database destruction
if grep -qiE 'DROP\s+(TABLE|DATABASE|SCHEMA)\b' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="SQL DROP statement — destructive database operation"
fi

if grep -qiE 'TRUNCATE\s+TABLE\b' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="SQL TRUNCATE — deletes all rows permanently"
fi

# Docker destruction
if grep -qE 'docker\s+system\s+prune\s+-a' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Docker system prune -a removes all unused images and containers"
fi

# chmod/chown -R on the filesystem root or a system directory. Recursive perms
# on app/home paths (/srv/app, /var/www, /home/u/app) stay allowed — those are
# routine for deploys and were false-positives under the old `.*\s+/` matcher.
if grep -qE '(chmod|chown)\s+-R\s+([^;&|]*\s)?/((etc|usr|bin|sbin|lib|lib64|boot|dev|proc|sys|root|System|Library)(/|[[:space:]]|[;&|]|$)|[[:space:]]*($|[;&|]))' <<< "$COMMAND"; then
  BLOCKED=true
  REASON="Recursive permission change on a system directory"
fi

# Skipping the project's git hooks: --no-verify on any git command (commit, push,
# merge, rebase, cherry-pick, am …), and -n on git commit, where it means
# --no-verify. On git push -n is --dry-run, which stays allowed. Also
# `git -c core.hooksPath=<dir>` (or --config-env) on a command that runs hooks:
# it swaps the project's hooks for another directory — /dev/null skips them all.
# Checked per command (lib/shell-segments.sh), so a commit message or an echo
# that mentions --no-verify doesn't match.
case "$COMMAND" in
  *git*)
    shell_segments "$COMMAND"
    SEG=0
    while [ "$SEG" -lt "$SH_NSEG" ]; do
      if sh_git_segment "$SEG"; then
        if [ "$SH_GIT_SUB" = "commit" ]; then
          sh_git_commit_parse
          if [ "$SH_COMMIT_NOVERIFY" = 1 ]; then
            BLOCKED=true
            REASON="git commit --no-verify (-n) skips the project's git hooks (pre-commit, commit-msg)"
          fi
        else
          for ARG in ${SH_GIT_ARGS[@]+"${SH_GIT_ARGS[@]}"}; do
            if [ "$ARG" = "--" ]; then
              break
            fi
            if [ "$ARG" = "--no-verify" ]; then
              BLOCKED=true
              REASON="git $SH_GIT_SUB --no-verify skips the project's git hooks"
            fi
          done
        fi
        case "$SH_GIT_SUB" in
          commit|push|merge|pull|rebase|cherry-pick|revert|am)
            # Git also accepts config through GIT_CONFIG_COUNT/KEY_n/VALUE_n
            # environment assignments. Treat a core.hooksPath key exactly like
            # `git -c core.hooksPath=…`; dynamic values fail closed.
            sh_seg_words "$SEG"
            CFG_COUNT=""
            for WORD in ${SH_W[@]+"${SH_W[@]}"}; do
              case "$WORD" in
                GIT_CONFIG_COUNT=*) CFG_COUNT=${WORD#*=} ;;
                GIT_CONFIG_KEY_[0-9]*=*)
                  KEY=${WORD#*=}
                  if [ "$(printf '%s' "$KEY" | tr '[:upper:]' '[:lower:]')" = "core.hookspath" ]; then
                    BLOCKED=true
                    REASON="Git environment configuration replaces the project's hooks — like --no-verify, it skips them"
                  fi
                  ;;
              esac
            done
            case "$CFG_COUNT" in
              ''|*[!0-9]*) ;;
              *)
                IDX=0
                while [ "$IDX" -lt "$CFG_COUNT" ]; do
                  KEY_VAR="GIT_CONFIG_KEY_$IDX"
                  KEY=${!KEY_VAR-}
                  if [ -n "$KEY" ] && [ "$(printf '%s' "$KEY" | tr '[:upper:]' '[:lower:]')" = "core.hookspath" ]; then
                    BLOCKED=true
                    REASON="Git environment configuration replaces the project's hooks — like --no-verify, it skips them"
                  fi
                  IDX=$((IDX + 1))
                done
                ;;
            esac
            # The same variables may be inherited by the hook process rather
            # than written inline in the command. Inspect names/keys only; never
            # print config values.
            case "${GIT_CONFIG_COUNT-}" in
              ''|*[!0-9]*) ;;
              *)
                IDX=0
                while [ "$IDX" -lt "$GIT_CONFIG_COUNT" ]; do
                  KEY_VAR="GIT_CONFIG_KEY_$IDX"
                  KEY=${!KEY_VAR-}
                  if [ -n "$KEY" ] && [ "$(printf '%s' "$KEY" | tr '[:upper:]' '[:lower:]')" = "core.hookspath" ]; then
                    BLOCKED=true
                    REASON="Git environment configuration replaces the project's hooks — like --no-verify, it skips them"
                  fi
                  IDX=$((IDX + 1))
                done
                ;;
            esac
            for CFG in ${SH_GIT_CONFIG[@]+"${SH_GIT_CONFIG[@]}"}; do
              # Config keys are case-insensitive (core.hookspath works too).
              case "$(printf '%s' "${CFG%%=*}" | tr '[:upper:]' '[:lower:]')" in
                core.hookspath)
                  BLOCKED=true
                  REASON="git -c core.hooksPath=… $SH_GIT_SUB replaces the project's git hooks — like --no-verify, it skips them"
                  ;;
              esac
            done
            ;;
        esac
      fi
      SEG=$((SEG + 1))
    done
    ;;
esac

if [ "$BLOCKED" = true ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "block-dangerous-commands"
  # On exit 2 the agent sees stderr only — send the whole message there.
  exec 1>&2
  echo "BLOCKED: $REASON"
  echo ""
  echo "Command: $COMMAND"
  echo ""
  echo "This command is potentially destructive and hard to reverse."
  echo "Get explicit approval from the user before running it."
  exit 2
fi

exit 0
