#!/usr/bin/env bash
#
# json-parse.sh — Shared JSON parsing for Agent Code Kit hooks
#
# Usage: source this file after reading INPUT from stdin.
#
#   INPUT=$(cat)
#   HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
#   source "$HOOK_LIB/json-parse.sh"
#
#   TOOL_NAME=$(parse_json_field "tool_name")
#   FILE_PATH=$(parse_json_field "file_path")
#
#
# Security contract:
# - INPUT is expected to be one Claude hook JSON object. Invalid JSON, non-object
#   JSON, or missing fields produce empty output.
# - Lookup prefers .tool_input.<field>, then the top-level .<field>. A key present
#   in tool_input wins even when its value is null (which yields empty). Values
#   render as text: strings and numbers as-is, booleans as true/false, objects and
#   arrays as compact single-line JSON; null yields empty. The jq and python3 paths
#   apply identical rules (they agree on every value hook inputs carry; only the
#   rendering of unusual numeric literals — e.g. 1e3, trailing zeros — can differ,
#   and hook fields never hold those). The no-parser regex fallback resolves string
#   values only (non-string values yield empty).
# - Field names must be simple keys: [A-Za-z_][A-Za-z0-9_]*. Do not pass jq
#   filters, dotted paths, shell fragments, or user-controlled expressions.
# - parse_json_field never evaluates field names as code; parser-specific queries
#   receive the field as data.
# - The bash fallback parses a JSON string value, including JSON escapes. It is
#   intentionally strict: malformed input or a non-string value yields empty.

# Requires INPUT to be set by the calling script
: "${INPUT:?json-parse.sh: INPUT variable must be set before sourcing}"

# shellcheck source=python3.sh
source "$(dirname "${BASH_SOURCE[0]}")/python3.sh"

# json_str STRING — STRING as the body of a JSON string, for hooks that build JSON
# without python3: control characters dropped, tabs and newlines as spaces,
# backslashes and quotes escaped.
json_str() {
  printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013\014\016-\037' | LC_ALL=C tr '\t\n\r' '   ' \
    | LC_ALL=C sed 's/\\/\\\\/g; s/"/\\"/g'
}

# hook_context EVENT MESSAGE — tell Claude MESSAGE without blocking: prints
# {"hookSpecificOutput":{"hookEventName":EVENT,"additionalContext":MESSAGE}} on
# stdout, for a hook that then exits 0. EVENT must be the event the hook runs on
# (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, …): Claude Code
# rejects a hookSpecificOutput for another event, and a top-level
# {"additionalContext": ...} is not in its schema. Stderr at exit 0 only reaches
# the debug log, and so does plain stdout for tool events. Uses python3 when it
# runs; otherwise escapes in bash: control characters dropped, tabs and
# newlines kept as \t and \n.
hook_context() {
  local out="" tab
  if python3_usable; then
    out=$(printf '%s' "$2" | PYTHONIOENCODING=utf-8:surrogateescape PYTHONUTF8=1 python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": sys.argv[1], "additionalContext": sys.stdin.read()}}, separators=(",", ":")))
' "$1" 2>/dev/null) || out=""
  fi
  if [ -z "$out" ]; then
    tab=$(printf '\t')
    out="{\"hookSpecificOutput\":{\"hookEventName\":\"$1\",\"additionalContext\":\"$(printf '%s' "$2" \
      | LC_ALL=C tr -d '\000-\010\013-\037' \
      | LC_ALL=C sed 's/\\/\\\\/g; s/"/\\"/g; s/'"$tab"'/\\t/g' \
      | LC_ALL=C awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')\"}}"
  fi
  printf '%s\n' "$out"
}

# _json_bash_string_field FIELD — parse a top-level string without jq/python.
# JSON object keys before FIELD are skipped, then the string value is decoded.
# Bash strings cannot contain NUL, so \u0000 is dropped. Non-ASCII \uXXXX stays
# as its escape spelling; hook routing still sees all ordinary ASCII words.
_json_bash_string_field() {
  local field=$1 s=$INPUT n i=0 c start key value esc hex code ch
  n=${#s}
  while [ "$i" -lt "$n" ]; do
    c=${s:i:1}
    if [ "$c" != '"' ]; then i=$((i + 1)); continue; fi
    i=$((i + 1)); key=""; esc=0
    while [ "$i" -lt "$n" ]; do
      c=${s:i:1}; i=$((i + 1))
      if [ "$esc" = 1 ]; then key+=$c; esc=0; continue; fi
      case "$c" in '\') esc=1 ;; '"') break ;; *) key+=$c ;; esac
    done
    [ "$c" = '"' ] || return 0
    while [ "$i" -lt "$n" ] && [[ "${s:i:1}" == [[:space:]] ]]; do i=$((i + 1)); done
    [ "${s:i:1}" = ':' ] || continue
    i=$((i + 1))
    while [ "$i" -lt "$n" ] && [[ "${s:i:1}" == [[:space:]] ]]; do i=$((i + 1)); done
    if [ "$key" != "$field" ]; then continue; fi
    [ "${s:i:1}" = '"' ] || return 0
    i=$((i + 1)); value=""
    while [ "$i" -lt "$n" ]; do
      c=${s:i:1}; i=$((i + 1))
      case "$c" in
        '"') printf '%s' "$value"; return 0 ;;
        '\')
          [ "$i" -lt "$n" ] || return 0
          esc=${s:i:1}; i=$((i + 1))
          case "$esc" in
            '"'|'\'|'/') value+=$esc ;;
            b) value+=$'\b' ;; f) value+=$'\f' ;; n) value+=$'\n' ;;
            r) value+=$'\r' ;; t) value+=$'\t' ;;
            u)
              [ $((i + 4)) -le "$n" ] || return 0
              hex=${s:i:4}; i=$((i + 4))
              [[ "$hex" =~ ^[0-9A-Fa-f]{4}$ ]] || return 0
              code=$((16#$hex))
              if [ "$code" -eq 0 ]; then :
              elif [ "$code" -le 127 ]; then
                printf -v ch "\\$(printf '%03o' "$code")"; value+=$ch
              else value+="\\u$hex"; fi
              ;;
            *) return 0 ;;
          esac
          ;;
        $'\n'|$'\r') return 0 ;;
        *) value+=$c ;;
      esac
    done
    return 0
  done
}

parse_json_field() {
  local field="${1:-}"

  if ! [[ "$field" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    return 0
  fi

  if command -v jq &>/dev/null; then
    # Mirror the python3 path exactly: a key present in tool_input wins (even if
    # null → empty), else fall back to the top-level key. Render booleans as
    # true/false and objects/arrays as compact JSON; null/missing → empty. Avoid
    # `//`, whose null/false-coalescing would mask false values and leak nulls
    # through to the top-level lookup.
    printf '%s' "$INPUT" | jq -r --arg field "$field" '
      if type != "object" then empty
      else
        (if (.tool_input | type) == "object" and (.tool_input | has($field)) then .tool_input
         elif has($field) then .
         else null end) as $src
        | if $src == null then empty
          else ($src[$field]) as $v
            | if   $v == null               then empty
              elif ($v | type) == "boolean" then (if $v then "true" else "false" end)
              elif ($v | type) == "object" or ($v | type) == "array" then ($v | tojson)
              else ($v | tostring) end
          end
      end' 2>/dev/null || true
  elif python3_usable; then
    printf '%s' "$INPUT" | python3 -c '
import json
import sys

field = sys.argv[1]
try:
    data = json.load(sys.stdin)
    if not isinstance(data, dict):
        sys.exit(0)
    tool_input = data.get("tool_input")
    if isinstance(tool_input, dict) and field in tool_input:
        value = tool_input.get(field)
    else:
        value = data.get(field, "")
    if value is None:
        sys.exit(0)
    if isinstance(value, bool):
        sys.stdout.write("true" if value else "false")
    elif isinstance(value, (dict, list)):
        sys.stdout.write(json.dumps(value, separators=(",", ":")))
    else:
        sys.stdout.write(str(value))
except (json.JSONDecodeError, OSError, TypeError):
    pass
' "$field" 2>/dev/null || true
  else
    _json_bash_string_field "$field"
  fi
}
