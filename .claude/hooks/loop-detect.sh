#!/usr/bin/env bash
#
# loop-detect.sh — PostToolUse hook
# Detects agent edit loops: same file edited 4+ times without progress
#
# Tracks recent Edit/Write actions in a temp file and warns or blocks
# when the same file is being repeatedly edited. The warning (4 edits) reaches
# Claude as PostToolUse additionalContext on stdout, at exit 0; the block
# (6 edits) exits 2 with its message on stderr.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
source "$HOOK_LIB/json-parse.sh"

TOOL_NAME=$(parse_json_field "tool_name")

# Only track file-editing tools
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(parse_json_field "file_path")
[ -z "$FILE_PATH" ] && exit 0

# Track edits in a project-scoped state file keyed by session id. $PPID is NOT
# stable across separately-spawned PostToolUse hooks — each invocation got its
# own track file, so the counter never accumulated and the guard never fired.
# CLAUDE_PROJECT_DIR + session_id are stable for the life of a session.
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_ID=$(parse_json_field "session_id")
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
TRACK_FILE="$STATE_DIR/loop-detect-${SESSION_ID:-session}.log"

# Append current edit
echo "$FILE_PATH" >> "$TRACK_FILE"

# Count recent edits to this file (last 10 entries)
RECENT_EDITS=$(tail -10 "$TRACK_FILE" 2>/dev/null | grep -cF "$FILE_PATH" || echo "0")

if [ "$RECENT_EDITS" -ge 6 ]; then
  # Second warning: block the action. On exit 2 the agent sees stderr only —
  # send the whole message there.
  exec 1>&2
  echo "BLOCKED: $FILE_PATH has been edited $RECENT_EDITS times in recent actions."
  echo ""
  echo "This looks like an edit loop. Stop and:"
  echo "  1. Re-read the original goal"
  echo "  2. Re-read the file to understand current state"
  echo "  3. Ask the user for guidance if stuck"
  echo ""
  echo "Do NOT continue editing the same file repeatedly."
  exit 2
elif [ "$RECENT_EDITS" -ge 4 ]; then
  # First warning: let it through but warn. At exit 0 Claude sees only
  # additionalContext JSON on stdout — plain stdout and stderr go to the debug log.
  hook_context PostToolUse "WARNING: $FILE_PATH has been edited $RECENT_EDITS times in recent actions.

You may be in an edit loop. Consider:
  - Re-reading the file to check current state
  - Re-reading the original goal
  - Trying a different approach"
  exit 0
fi

exit 0
