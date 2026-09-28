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
# are exempt there — they are committed, just never hand-edited. Both are
# checked in the directory git runs in: after a resolvable `cd <dir>` earlier in
# the same (sub)shell, and with a resolvable `-C <dir>`. Staging fails closed when
# a cwd-changing shell construct or a pathspec file cannot be resolved safely.
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

# git runs in the command's working directory, moved by any earlier cd (plus -C).
CMD_CWD=$(parse_json_field "cwd")
CMD_CWD="${CMD_CWD:-$ROOT}"

# Where each `cd` moved its (sub)shell: CD_SCOPES[k] (an SH_SEG_SCOPE) → CD_DIRS[k].
CD_SCOPES=()
CD_DIRS=()
CD_UNKNOWN=()

# seg_dir SCOPE — SEG_DIR = the directory a command in SCOPE runs in: the last
# known cd of that scope or of the nearest enclosing one, else the command's cwd.
# SEG_DIR_KNOWN=0 when an unmodelled cwd mutation means staging must fail closed.
seg_dir() {
  local scope=$1 k
  SEG_DIR_KNOWN=1
  while :; do
    k=${#CD_SCOPES[@]}
    while [ "$k" -gt 0 ]; do
      k=$((k - 1))
      if [ "${CD_SCOPES[$k]}" = "$scope" ]; then
        SEG_DIR=${CD_DIRS[$k]}
        [ "${CD_UNKNOWN[$k]-0}" = 1 ] && SEG_DIR_KNOWN=0
        return 0
      fi
    done
    if [ -z "$scope" ]; then
      SEG_DIR=$CMD_CWD
      return 0
    fi
    scope=${scope%/*}
  done
}

# cd_to FROM SCOPE — record where the `cd` in SH_W, run in FROM, moves SCOPE.
# A target the hook can't know ($VAR, $(…), `cd -`) marks the scope unknown;
# a later staging command then blocks rather than assuming the prior directory.
cd_to() {
  local k=1 n=${#SH_W[@]} target unknown=0
  while [ "$k" -lt "$n" ]; do
    case "${SH_W[$k]}" in
      --) k=$((k + 1)); break ;;
      -?*) ;;  # -L, -P, -e, -@
      *) break ;;
    esac
    k=$((k + 1))
  done
  if [ "$k" -ge "$n" ]; then
    target=${HOME-}
  else
    target=${SH_W[$k]}
  fi
  case "$target" in
    '~') target=${HOME-} ;;
    '~/'*) target=${HOME-}/${target:2} ;;
  esac
  case "$target" in
    ''|-|*'$'*|*'`'*|'~'*) unknown=1 ;;
    /*) ;;
    *) target=$1/$target ;;
  esac
  if [ "$unknown" = 0 ] && [ ! -d "$target" ]; then unknown=1; fi
  CD_SCOPES+=("$2")
  if [ "$unknown" = 1 ]; then
    CD_DIRS+=("$1")
    CD_UNKNOWN+=(1)
  else
    CD_DIRS+=("$target")
    CD_UNKNOWN+=(0)
  fi
  return 0
}

FOUND=""  # "  <path> — <reason>" lines
UNSAFE=""

unsafe_stage() {
  [ -n "$UNSAFE" ] || UNSAFE=$1
  return 0
}

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
# Function bodies and pushd/popd can change the caller's cwd, but the lightweight
# lexer does not execute shell semantics. If a later staging command exists,
# fail closed rather than claim its cwd is known.
DYNAMIC_CWD=0
i=0
while [ "$i" -lt "$SH_NSEG" ]; do
  sh_seg_words "$i"
  case " ${SH_W[*]-} " in
    *" function "*|*" pushd "*|*" popd "*) DYNAMIC_CWD=1 ;;
  esac
  i=$((i + 1))
done
i=0
while [ "$i" -lt "$SH_NSEG" ]; do
  seg_dir "${SH_SEG_SCOPE[$i]-}"
  sh_seg_command "$i"
  if [ "${SH_W[0]-}" = "cd" ]; then
    cd_to "$SEG_DIR" "${SH_SEG_SCOPE[$i]-}"
  fi
  if sh_git_segment "$i"; then
    DIR="$SEG_DIR"
    GIT_CWD_DYNAMIC=0
    case "$SH_GIT_CWD" in
      "") ;;
      *'$'*|*'`'*) GIT_CWD_DYNAMIC=1 ;;
      /*) DIR="$SH_GIT_CWD" ;;
      *) DIR="$DIR/$SH_GIT_CWD" ;;
    esac
    # Only staging commands fail closed on a directory the hook can't resolve;
    # a read-only `git -C "$dir" status` / `log` stays allowed.
    case "$SH_GIT_SUB" in
      add|commit)
        if [ "$DYNAMIC_CWD" = 1 ] || [ "$SEG_DIR_KNOWN" = 0 ]; then
          unsafe_stage "the command changes git's working directory in a way the safety hook cannot resolve"
        elif [ "$GIT_CWD_DYNAMIC" = 1 ]; then
          unsafe_stage "git -C uses a dynamic directory the safety hook cannot resolve"
        fi
        ;;
    esac
    case "$SH_GIT_SUB" in
      add)
        ALL=false
        UPDATE=false
        FORCE=false
        DRY=false
        END=false
        PATHSPEC_FILE=""
        PATHSPEC_NUL=false
        PATHS=()
        SKIP_NEXT_PATHSPEC=false
        for ARG in ${SH_GIT_ARGS[@]+"${SH_GIT_ARGS[@]}"}; do
          if [ "$SKIP_NEXT_PATHSPEC" = true ]; then
            SKIP_NEXT_PATHSPEC=false
            continue
          fi
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
            --pathspec-from-file=*) PATHSPEC_FILE=${ARG#--pathspec-from-file=} ;;
            --pathspec-from-file) SKIP_NEXT_PATHSPEC=true ;;
            --pathspec-file-nul) PATHSPEC_NUL=true ;;
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
        # A separated pathspec-file value is the next argument; recover it from
        # the original argv. Any dynamic, missing, unreadable, or NUL-delimited
        # file fails closed instead of staging paths the hook never inspected.
        k=0
        while [ "$k" -lt "${#SH_GIT_ARGS[@]}" ]; do
          if [ "${SH_GIT_ARGS[$k]}" = "--pathspec-from-file" ]; then
            k=$((k + 1)); PATHSPEC_FILE=${SH_GIT_ARGS[$k]-}
          fi
          k=$((k + 1))
        done
        if [ -n "$PATHSPEC_FILE" ]; then
          case "$PATHSPEC_FILE" in
            -|*'$'*|*'`'*|*'$('*|'') unsafe_stage "git add uses a dynamic or stdin pathspec file" ;;
            /*) PS_FILE=$PATHSPEC_FILE ;;
            *) PS_FILE=$DIR/$PATHSPEC_FILE ;;
          esac
          if [ "$PATHSPEC_NUL" = true ]; then
            unsafe_stage "NUL-delimited pathspec files cannot be inspected safely by this bash hook"
          elif [ -z "${PS_FILE-}" ] || [ ! -f "$PS_FILE" ] || [ ! -r "$PS_FILE" ] || [ -L "$PS_FILE" ]; then
            unsafe_stage "git add pathspec file is missing, unreadable, or a symlink"
          else
            while IFS= read -r P || [ -n "$P" ]; do
              [ -n "$P" ] && PATHS+=("$P")
            done < "$PS_FILE"
          fi
        fi
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

if [ -n "$UNSAFE" ]; then
  bump_counter "$ROOT/.hook-state/hook-firings.json" "protect-files"
  exec 1>&2
  echo "BLOCKED: $UNSAFE."
  echo "Use literal directories and pathspecs, or stage safe files by name."
  exit 2
fi

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
