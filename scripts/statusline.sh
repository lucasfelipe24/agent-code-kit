#!/usr/bin/env bash
#
# statusline.sh — Claude Code status line script
#
# Shows: model | git branch | context usage | session cost
#
# Setup: Add to .claude/settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "./scripts/statusline.sh"
#   }
#
# Input: Claude Code's status line JSON via stdin. Fields read:
#   model.display_name (falls back to model.id), context_window.used_percentage,
#   cost.total_cost_usd
#

# Don't use set -e — missing fields shouldn't crash the script
set -uo pipefail

INPUT=$(cat)

# python3 fallback: walk a dotted path (argv[1]) into d, None if any key is missing
PY_GET="import sys,json;from functools import reduce;d=reduce(lambda a,k:a.get(k) if isinstance(a,dict) else None,sys.argv[1].split('.'),json.load(sys.stdin))"

# grep fallback: print the input from the last parent key of a dotted path on, so
# the leaf is matched inside its own object. Prints nothing if a parent is absent.
json_scope() {
  local rest="$INPUT" path="$1" parent
  while [[ "$path" == *.* ]]; do
    parent="${path%%.*}"
    [[ "$rest" == *"\"$parent\""* ]] || return 0
    rest="${rest#*\"$parent\"}"
    path="${path#*.}"
  done
  echo "$rest"
}

# JSON parser: tries jq, then python3, then grep fallback. Takes a dotted path.
json_str() {
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r ".${1} // empty" 2>/dev/null || echo ""
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "$PY_GET;print(d if d is not None else '')" "$1" 2>/dev/null || echo ""
  else
    json_scope "$1" | grep -oE "\"${1##*.}\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|null)" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//;s/.*:[[:space:]]*null$//' || echo ""
  fi
}
json_num() {
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r ".${1} // empty" 2>/dev/null | sed 's/\..*//' || echo ""
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "$PY_GET;print(int(d) if d is not None else '')" "$1" 2>/dev/null || echo ""
  else
    json_scope "$1" | grep -oE "\"${1##*.}\"[[:space:]]*:[[:space:]]*([0-9.]+|null)" | head -1 | sed 's/.*:[[:space:]]*//;s/^null$//' | sed 's/\..*//' || echo ""
  fi
}
json_float() {
  if command -v jq &>/dev/null; then
    echo "$INPUT" | jq -r ".${1} // empty" 2>/dev/null || echo ""
  elif command -v python3 &>/dev/null; then
    echo "$INPUT" | python3 -c "$PY_GET;print(d if d is not None else '')" "$1" 2>/dev/null || echo ""
  else
    json_scope "$1" | grep -oE "\"${1##*.}\"[[:space:]]*:[[:space:]]*([0-9.]+|null)" | head -1 | sed 's/.*:[[:space:]]*//;s/^null$//' || echo ""
  fi
}

# Parse fields
MODEL=$(json_str "model.display_name")
[ -z "$MODEL" ] && MODEL=$(json_str "model.id" | sed 's/claude-//')
MODEL=$(echo "$MODEL" | cut -c1-20)
PCT=$(json_num "context_window.used_percentage")
COST=$(json_float "cost.total_cost_usd")

# Git branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "?")

# Context percentage
CTX="?"
if [ -n "$PCT" ] && [ "$PCT" -ge 0 ] 2>/dev/null; then
  # Progress bar (10 chars) — clamp to valid range
  FILLED=$(( PCT / 10 ))
  [ "$FILLED" -lt 0 ] && FILLED=0
  [ "$FILLED" -gt 10 ] && FILLED=10
  EMPTY=$(( 10 - FILLED ))
  BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done

  CTX="${BAR} ${PCT}%"
fi

# Format cost
COST_FMT=""
if [ -n "$COST" ]; then
  # total_cost_usd is an unrounded float; LC_ALL=C keeps "." as the decimal
  # separator under locales like pt_BR, where printf would reject "1.24"
  COST_FMT=$(LC_ALL=C printf '$%.2f' "$COST" 2>/dev/null) || COST_FMT=""
fi

# Output
OUTPUT="${MODEL:-?} | ${BRANCH} | ${CTX}"
[ -n "$COST_FMT" ] && OUTPUT="$OUTPUT | $COST_FMT"
echo "$OUTPUT"
