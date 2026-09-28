#!/usr/bin/env bash
#
# protect-files.sh — PreToolUse hook
# Blocks edits to sensitive files (secrets, credentials, lock files)
#
# Reads tool input from stdin (JSON with tool_name and tool_input)
#
# Bash: blocks a git command that would stage a protected file. `git add <path>`
# is checked by name; `git add -A / . / --all / <dir>` and `git commit -a`
# against what `git status --porcelain -uall` says they would stage. Lock files
# are exempt there — they are committed, just never hand-edited.
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

# Only check file-writing tools, and Bash for git commands that stage files
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit|Bash) ;;
  *) exit 0 ;;
esac

# check_path PATH — BLOCKED=true and REASON when PATH is a protected file.
# LOCK_FILE=true when it is protected only as a generated lock file.
check_path() {
  local BASENAME="${1##*/}" DIRNAME="."
  case "$1" in
    */*) DIRNAME="${1%/*}" ;;
  esac

  # Protected file patterns
  BLOCKED=false
  REASON=""
  LOCK_FILE=false

  case "$BASENAME" in
    .env|.env.local|.env.production|.env.staging|.env.development)
      BLOCKED=true
      REASON="Environment file with secrets"
      ;;
    .env.example|.env.template|.env.sample|.env.test)
      ;; # Allow these — they don't contain real secrets
    .env.*)
      BLOCKED=true
      REASON="Environment file with secrets"
      ;;
    credentials.json|service-account.json|serviceAccountKey.json)
      BLOCKED=true
      REASON="Credential file"
      ;;
    id_rsa|id_ed25519|id_ecdsa|*.pem|*.key)
      BLOCKED=true
      REASON="Private key file"
      ;;
    *.p12|*.pfx)
      BLOCKED=true
      REASON="Certificate file"
      ;;
    *.jks)
      BLOCKED=true
      REASON="Java keystore file"
      ;;
    firebase-adminsdk*.json)
      BLOCKED=true
      REASON="Firebase Admin SDK credential file"
      ;;
    google-services.json)
      BLOCKED=true
      REASON="Android Google services config"
      ;;
    GoogleService-Info.plist)
      BLOCKED=true
      REASON="iOS Google services config"
      ;;
    package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|poetry.lock|Cargo.lock|composer.lock|Pipfile.lock)
      BLOCKED=true
      REASON="Lock file (should be auto-generated)"
      LOCK_FILE=true
      ;;
  esac

  # Check directory patterns
  case "$DIRNAME" in
    */.ssh|*/.ssh/*|*/.gnupg|*/.gnupg/*|*/.aws|*/.aws/*)
      BLOCKED=true
      REASON="Sensitive config directory"
      LOCK_FILE=false
      ;;
  esac
  return 0
}

if [ "$TOOL_NAME" != "Bash" ]; then
  # Extract file path from tool input
  FILE_PATH=$(parse_json_field "file_path")
  [ -z "$FILE_PATH" ] && exit 0

  check_path "$FILE_PATH"

  if [ "$BLOCKED" = true ]; then
    bump_counter "$ROOT/.hook-state/hook-firings.json" "protect-files"
    # On exit 2 the agent sees stderr only — send the whole message there.
    exec 1>&2
    echo "BLOCKED: $REASON — $FILE_PATH"
    echo ""
    echo "If you need to modify this file, ask the user to do it manually"
    echo "or get explicit approval first."
    exit 2
  fi

  exit 0
fi

COMMAND=$(parse_json_field "command")
case "$COMMAND" in
  *git*) ;;
  *) exit 0 ;;
esac

# git runs in the command's working directory (plus any -C).
CMD_CWD=$(parse_json_field "cwd")
CMD_CWD="${CMD_CWD:-$ROOT}"

FOUND=""  # "  <path> — <reason>" lines

# note_path PATH — add PATH to FOUND when staging it would commit a protected
# file (lock files aside).
note_path() {
  check_path "./$1"
  if [ "$BLOCKED" = true ] && [ "$LOCK_FILE" = false ]; then
    case "$FOUND" in
      *"  $1 — "*) ;;
      *) FOUND="$FOUND  $1 — $REASON"$'\n' ;;
    esac
  fi
  return 0
}

# note_status DIR MODE [PATHSPEC…] — note the protected files among those
# `git status` lists as changed in DIR. MODE: all (untracked and tracked
# changes), tracked (tracked changes only — git commit -a, git add -u), or
# ignored (all, plus ignored files — git add -f).
note_status() {
  local dir=$1 mode=$2 line xy path
  shift 2
  local -a args
  args=(status --porcelain -uall)
  if [ "$mode" = "ignored" ]; then
    args+=(--ignored)
  fi
  while IFS= read -r line; do
    xy=${line:0:2}
    path=${line:3}
    case "$path" in
      *" -> "*) path=${path##* -> } ;;  # a rename: the new path
    esac
    path=${path#\"}
    path=${path%\"}
    case "$xy" in
      ' D'|'D '|DD) continue ;;  # a deletion stages no content
    esac
    if [ "$mode" = "tracked" ]; then
      case "${xy:1:1}" in
        M|T) ;;
        *) continue ;;
      esac
    fi
    note_path "$path"
  done < <(git --no-optional-locks -C "$dir" "${args[@]}" -- "$@" 2>/dev/null || true)
  return 0
}

shell_segments "$COMMAND"
i=0
while [ "$i" -lt "$SH_NSEG" ]; do
  if sh_git_segment "$i"; then
    DIR="$CMD_CWD"
    case "$SH_GIT_CWD" in
      "") ;;
      /*) DIR="$SH_GIT_CWD" ;;
      *) DIR="$DIR/$SH_GIT_CWD" ;;
    esac
    case "$SH_GIT_SUB" in
      add)
        ALL=false
        UPDATE=false
        FORCE=false
        DRY=false
        END=false
        PATHS=()
        for ARG in ${SH_GIT_ARGS[@]+"${SH_GIT_ARGS[@]}"}; do
          if [ "$END" = true ]; then
            PATHS+=("$ARG")
            continue
          fi
          case "$ARG" in
            --) END=true ;;
            --all|--no-ignore-removal) ALL=true ;;
            --update) UPDATE=true ;;
            --force) FORCE=true ;;
            --dry-run) DRY=true ;;
            --*) ;;
            -*)
              case "$ARG" in *A*) ALL=true ;; esac
              case "$ARG" in *u*) UPDATE=true ;; esac
              case "$ARG" in *f*) FORCE=true ;; esac
              case "$ARG" in *n*) DRY=true ;; esac
              ;;
            *) PATHS+=("$ARG") ;;
          esac
        done
        if [ "$DRY" = false ]; then
          for P in ${PATHS[@]+"${PATHS[@]}"}; do
            note_path "$P"
          done
          if [ "$ALL" = true ] || [ "$UPDATE" = true ] || [ "${#PATHS[@]}" -gt 0 ]; then
            MODE=all
            if [ "$UPDATE" = true ] && [ "$ALL" = false ]; then MODE=tracked; fi
            if [ "$FORCE" = true ]; then MODE=ignored; fi
            note_status "$DIR" "$MODE" ${PATHS[@]+"${PATHS[@]}"}
          fi
        fi
        ;;
      commit)
        sh_git_commit_parse
        for P in ${SH_COMMIT_PATHS[@]+"${SH_COMMIT_PATHS[@]}"}; do
          note_path "$P"
        done
        if [ "$SH_COMMIT_ALL" = 1 ] || [ "${#SH_COMMIT_PATHS[@]}" -gt 0 ]; then
          note_status "$DIR" tracked ${SH_COMMIT_PATHS[@]+"${SH_COMMIT_PATHS[@]}"}
        fi
        ;;
    esac
  fi
  i=$((i + 1))
done

if [ -n "$FOUND" ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "protect-files"
  # On exit 2 the agent sees stderr only — send the whole message there.
  exec 1>&2
  echo "BLOCKED: This command would stage protected file(s):"
  printf '%s' "$FOUND"
  echo ""
  echo "Stage files by name instead, and keep secrets out of git (.gitignore)."
  echo "If one of these must be committed, ask the user to do it manually"
  echo "or get explicit approval first."
  exit 2
fi

exit 0
