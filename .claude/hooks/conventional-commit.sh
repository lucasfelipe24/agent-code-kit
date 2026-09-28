#!/usr/bin/env bash
#
# conventional-commit.sh — PreToolUse hook
# Validates commit messages follow conventional commit format
#
# Format: <type>[(scope)][!]: <description>   (! marks a breaking change)
# Types: feat, fix, refactor, test, docs, chore, perf, ci, build, style, revert
#
# The subject is the first non-empty line of the message, wherever it comes
# from: -m / --message (a heredoc included — `-m "$(cat <<'EOF' … EOF)"` is how
# Claude Code writes commits), or -F / --file (a file that exists; `-F -` reads
# the heredoc or here-string fed to it). Only a `git … commit` that runs as a
# command counts — `git -c k=v commit` and `git -C dir commit` included, a
# quoted mention such as `echo 'git commit -m "x"'` not.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"
source "$HOOK_LIB/shell-segments.sh"

TOOL_NAME=$(parse_json_field "tool_name")

# Only check Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(parse_json_field "command")
[ -z "$COMMAND" ] && exit 0

# Only check git commit commands
case "$COMMAND" in
  *git*commit*) ;;
  *) exit 0 ;;
esac

# Relative -F paths resolve against the command's working directory.
CMD_CWD=$(parse_json_field "cwd")
CMD_CWD="${CMD_CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"

# first_line — the first non-empty line of stdin (git drops leading blank lines)
first_line() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *[![:space:]]*) printf '%s' "$line"; return 0 ;;
    esac
  done
  return 0
}

# Validate conventional commit format
VALID_TYPES="feat|fix|refactor|test|docs|chore|perf|ci|build|style|revert"

shell_segments "$COMMAND"
i=0
while [ "$i" -lt "$SH_NSEG" ]; do
  if sh_git_segment "$i" && [ "$SH_GIT_SUB" = "commit" ]; then
    sh_git_commit_parse
    FIRST_LINE=""
    CHECK=false
    if [ "$SH_COMMIT_HAS_MSG" = 1 ]; then
      FIRST_LINE=$(first_line <<< "$SH_COMMIT_MSG")
      CHECK=true
    elif [ "$SH_COMMIT_HAS_FILE" = 1 ]; then
      if [ "$SH_COMMIT_FILE" = "-" ]; then
        # -F - reads stdin: check the heredoc or here-string that feeds it
        if [ -n "${SH_SEG_STDIN[$i]+x}" ]; then
          FIRST_LINE=$(first_line <<< "${SH_SEG_STDIN[$i]}")
          CHECK=true
        fi
      else
        DIR="$CMD_CWD"
        case "$SH_GIT_CWD" in
          "") ;;
          /*) DIR="$SH_GIT_CWD" ;;
          *) DIR="$DIR/$SH_GIT_CWD" ;;
        esac
        MSG_FILE="$SH_COMMIT_FILE"
        case "$MSG_FILE" in
          /*) ;;
          *) MSG_FILE="$DIR/$MSG_FILE" ;;
        esac
        # A file that doesn't exist can't be checked; git itself will refuse it.
        if [ -f "$MSG_FILE" ] && [ -r "$MSG_FILE" ]; then
          FIRST_LINE=$(first_line < "$MSG_FILE")
          CHECK=true
        fi
      fi
    fi
    # No -m / -F (editor, --no-edit, -C <commit>): nothing to check here.
    if [ "$CHECK" = true ] && ! grep -qE "^($VALID_TYPES)(\(.+\))?!?: .+" <<< "$FIRST_LINE"; then
      # On exit 2 the agent sees stderr only — send the whole message there.
      exec 1>&2
      echo "BLOCKED: Commit message doesn't follow conventional commit format"
      echo ""
      echo "  Got:      $FIRST_LINE"
      echo "  Expected: <type>[(scope)][!]: <description>"
      echo ""
      echo "  Valid types: feat, fix, refactor, test, docs, chore, perf, ci, build, style, revert"
      echo ""
      echo "  Examples:"
      echo "    feat: add user search endpoint"
      echo "    fix: handle null response from auth API"
      echo "    refactor(auth): simplify token validation"
      echo "    feat(api)!: remove the v1 routes   (! marks a breaking change)"
      exit 2
    fi
  fi
  i=$((i + 1))
done

exit 0
