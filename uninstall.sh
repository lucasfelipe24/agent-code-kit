#!/usr/bin/env bash
#
# Agent Code Kit — Uninstaller
#
# Usage:
#   ./uninstall.sh              # Interactive — shows what will be removed, asks for confirmation
#   ./uninstall.sh --dry-run    # Show what would be removed without deleting anything
#   ./uninstall.sh --force      # Remove everything without confirmation
#   ./uninstall.sh --keep-tasks # Keep tasks/ directory (lessons, decisions, handoffs)
#

set -euo pipefail

DEST="$(pwd)"
DRY_RUN=false
FORCE=false
KEEP_TASKS=false
KEEP_WIKI=false
KEEP_ARTIFACTS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --keep-tasks|-k)
      KEEP_TASKS=true
      shift
      ;;
    --keep-project|-p)
      shift
      ;;
    --keep-wiki)
      KEEP_WIKI=true
      shift
      ;;
    --keep-artifacts)
      KEEP_ARTIFACTS=true
      shift
      ;;
    --help|-h)
      echo "Usage: uninstall.sh [--dry-run] [--force] [--keep-tasks] [--keep-project] [--keep-wiki] [--keep-artifacts]"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n       Show what would be removed without deleting"
      echo "  --force, -f         Remove without confirmation"
      echo "  --keep-tasks, -k    Keep tasks/ directory (lessons, decisions, handoffs)"
      echo "  --keep-project, -p  Accepted and ignored: the project's own overlay files are never removed now"
      echo "  --keep-wiki         Keep WIKI.md, raw-sources/, and wiki/ (knowledge wiki module data)"
      echo "  --keep-artifacts    Keep ARTIFACTS.md and artifacts/ (HTML artifacts module data)"
      echo "  --help, -h          Show this help"
      exit 0
      ;;
    *)
      error "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

echo ""
echo "  Agent Code Kit — Uninstaller"
echo "  =============================="
echo ""

# --- Detect what was installed ---

FILES_TO_REMOVE=()
DIRS_TO_REMOVE=()
# What the optional modules seeded, as the installer wrote it (install.sh
# create_wiki_index / create_wiki_log; the wiki test in test-install.sh fails if the two drift).
WIKI_SEED_INDEX='# Wiki Index

Last updated: —
Sources: 0 | Wiki pages: 0

## Summaries

## Entities

## Concepts

## Analyses'
WIKI_SEED_LOG='# Wiki Log'
MODULE_TO_REMOVE=()
MODULE_DIRS=()

# Read the install manifest — the single record of what install.sh actually
# shipped (scripts/lib/manifest.sh writes it). The path-based detection below is
# coarse (whole directories); the manifest sweep at the end backstops it against
# drift, so a file type a future kit version adds can't survive uninstall just
# because this script's hardcoded paths weren't updated. Captured up front
# because .kit-manifest is itself removed during uninstall.
KIT_MANIFEST_ENTRIES=()
if [ -f "$DEST/.kit-manifest" ]; then
  while IFS= read -r _entry; do
    [ -n "$_entry" ] && KIT_MANIFEST_ENTRIES+=("$_entry")
  done < "$DEST/.kit-manifest"
fi
# A record without a manifest (the manifest was deleted): the record lists every
# file the kit wrote, one by one, so it takes the manifest's place — never the
# whole-folder fallbacks.
if [ "${#KIT_MANIFEST_ENTRIES[@]}" -eq 0 ] && [ -f "$DEST/.kit-baseline" ]; then
  while IFS= read -r _entry; do
    [ -n "$_entry" ] && KIT_MANIFEST_ENTRIES+=("$_entry")
  done < <(awk -F'\t' '/^#/ { next } NF >= 2 { print $2 }' "$DEST/.kit-baseline")
fi
# The kit shares scripts/, agent_docs/ and .claude/{hooks,skills,agents}/ with
# the project. With a manifest, only its entries are removed there (the backstop
# at the end picks them up) and a directory goes only once it's empty. An
# install from before the manifest can't tell the two apart, so those
# directories are still removed whole — the listing below shows them first.
HAVE_MANIFEST=false
[ "${#KIT_MANIFEST_ENTRIES[@]}" -gt 0 ] && HAVE_MANIFEST=true
SHARED_DIRS="agent_docs scripts .claude/hooks .claude/skills .claude/agents"

# baseline_hash <path> — the hash .kit-baseline records for <path>, if any.
baseline_hash() {
  awk -F'\t' -v p="$1" '$2 == p { print $1; exit }' "$DEST/.kit-baseline" 2>/dev/null
}

# file_hash <file> — same tool order as install.sh, so the hashes compare.
file_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
  else
    return 1
  fi
}

# >>> ack-ownership
# What the install record (.kit-baseline) says about a path — facts only. Install,
# upgrade and uninstall each apply their own policy to the answer. This block is
# copied verbatim into uninstall.sh and scripts/doctor.sh, which run standalone
# (curl | bash, or shipped alone into a project) and cannot source this library;
# scripts/test-install.sh fails when the three copies differ. Edit it here, then
# re-copy it. bash 3.2 compatible; LC_ALL=C keeps the awk byte-exact.

# ack_file_hash <file> — sha256, same tool order as install.sh's file_hash; empty
# when there is no tool or the file can't be read.
ack_file_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || true
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1" 2>/dev/null || true
  fi
  return 0
}

# ack_record_files <dest> — how many file entries .kit-baseline holds. `#` header
# lines (#template, #complete) are not files; CRs from a Windows checkout are
# ignored.
ack_record_files() {
  [ -f "$1/.kit-baseline" ] || { echo 0; return 0; }
  LC_ALL=C awk -F'\t' '{ gsub(/\r/, "") } /^#/ { next } $1 != "" && $2 != "" { n++ } END { print n + 0 }' "$1/.kit-baseline"
}

# ack_record_hash <dest> <rel> — the hash the record holds for <rel>, if any.
ack_record_hash() {
  [ -f "$1/.kit-baseline" ] || return 0
  LC_ALL=C awk -F'\t' -v p="$2" '{ gsub(/\r/, "") } /^#/ { next } $2 == p { print $1; exit }' "$1/.kit-baseline"
}

# ack_owner <dest> <rel> — one word:
#   absent      nothing at <rel>, not even a link
#   kit         the record has <rel> and the file still has that hash
#   kit-edited  recorded, but the file changed since
#   unverified  recorded, but it can't be hashed (no tool, a directory, a
#               dangling or unreadable link)
#   unrecorded  the record has file entries, none for <rel>
#   no-record   no .kit-baseline, or one with no file entry (ADR-023's case)
ack_owner() {
  local dest="$1" rel="$2" p want got
  p="$dest/$rel"
  if [ ! -e "$p" ] && [ ! -L "$p" ]; then echo absent; return 0; fi
  if [ "$(ack_record_files "$dest")" -eq 0 ]; then echo no-record; return 0; fi
  want=$(ack_record_hash "$dest" "$rel")
  if [ -z "$want" ]; then echo unrecorded; return 0; fi
  if [ ! -f "$p" ]; then echo unverified; return 0; fi
  got=$(ack_file_hash "$p")
  if [ -z "$got" ]; then echo unverified; return 0; fi
  if [ "$got" = "$want" ]; then echo kit; else echo kit-edited; fi
}

# ack_record_complete <dest> — true when the record carries a `#complete` header:
# it was written by a run that left it listing every file the kit put there.
ack_record_complete() {
  [ -f "$1/.kit-baseline" ] || return 1
  LC_ALL=C awk -F'\t' '{ gsub(/\r/, "") } $1 == "#complete" { f = 1 } END { exit f ? 0 : 1 }' "$1/.kit-baseline"
}

# ack_prior_install <dest> — did the kit run here before? A manifest, a record, or
# a CLAUDE.md that carries the kit's `## Session Boot`.
ack_prior_install() {
  [ -f "$1/.kit-manifest" ] && return 0
  [ -f "$1/.kit-baseline" ] && return 0
  [ -f "$1/CLAUDE.md" ] || return 1
  LC_ALL=C awk '/^## Session Boot/ { f = 1 } END { exit f ? 0 : 1 }' "$1/CLAUDE.md"
}
# <<< ack-ownership

# The kit tree this script runs from (the npm package or a clone) holds the
# scaffold and templates the installer copied, so a project file can be checked
# against the kit's copy. Empty when that tree isn't here (piped from curl).
KIT_SRC=""
[ -n "${BASH_SOURCE[0]:-}" ] && KIT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -d "$KIT_SRC/scaffold/tasks" ] && command -v cmp >/dev/null 2>&1 || KIT_SRC=""
# Run from the kit's own tree, every file "matches" itself: compare nothing.
[ "$KIT_SRC" -ef "$DEST" ] && KIT_SRC=""

# same_as_kit <file> <kit-relative path> — is <file> still the kit's copy, byte
# for byte?
same_as_kit() {
  [ -n "$KIT_SRC" ] && [ -f "$KIT_SRC/$2" ] && cmp -s "$1" "$KIT_SRC/$2"
}

# map_is_template — is CODEBASE_MAP.md still one of the kit's templates, as
# installed? Once filled in it's the project's. Unknown without the kit tree,
# so it stays.
map_is_template() {
  local t
  [ -n "$KIT_SRC" ] || return 1
  for t in "$KIT_SRC"/scaffold/CODEBASE_MAP.md "$KIT_SRC"/examples/*/CODEBASE_MAP.md; do
    same_as_kit "$DEST/CODEBASE_MAP.md" "${t#"$KIT_SRC"/}" && return 0
  done
  return 1
}

# kit_leftover <path> — a file an older kit version wrote and nobody changed
# since: .kit-baseline records it with the file's current hash, though the
# manifest no longer lists it (an upgrade reported it as no longer shipped).
kit_leftover() {
  local want got
  want=$(baseline_hash "$1")
  [ -n "$want" ] || return 1
  got=$(file_hash "$DEST/$1") || return 1
  [ "$got" = "$want" ]
}

# manifest_covers <path> — is <path> a manifest entry, inside a directory entry,
# or a .kit-new copy an upgrade wrote next to one?
manifest_covers() {
  local e
  for e in ${KIT_MANIFEST_ENTRIES[@]+"${KIT_MANIFEST_ENTRIES[@]}"}; do
    case "$1" in "$e"|"$e"/*|"$e".kit-new|"$e".kit-new.*) return 0 ;; esac
  done
  return 1
}

# Files uninstall kept, by why. PROJECT_OWN holds the ones the record doesn't
# list: the kit never installed them.
PROJECT_OWN=()
KEPT_EDITED=()
KEPT_UNVERIFIED=()

# record_backed <path> — does the installer record this path in .kit-baseline?
# agent_docs/, scripts/, .claude/, WIKI.md, ARTIFACTS.md and CLAUDE.md are.
# VERSION, CODEBASE_MAP.md, CLAUDE.project.md and tasks/ are not, and keep their
# own rules below; the overlay folders are compared with the kit's copies.
record_backed() {
  case "$1" in
    agent_docs/project/*|.claude/hooks/project/*) return 1 ;;
    agent_docs/*|scripts/*|.claude/*|WIKI.md|ARTIFACTS.md|CLAUDE.md) return 0 ;;
  esac
  return 1
}

# may_remove <path> — may uninstall delete this recorded file? Only one the
# record says the kit wrote and nobody has changed since. A file the record
# doesn't list is the project's, however the manifest came to list it. Anything
# kept is noted under its reason. With no record at all (an install from before
# .kit-baseline) the kit's word is all there is, so a prior install's files go as
# they always did; in a project the kit never entered, nothing does.
may_remove() {
  case "$(ack_owner "$DEST" "$1")" in
    kit) return 0 ;;
    absent) return 1 ;;
    kit-edited) KEPT_EDITED+=("$1") ;;
    unverified) KEPT_UNVERIFIED+=("$1") ;;
    unrecorded) PROJECT_OWN+=("$1") ;;
    *)
      # No record: the kit's word (the manifest) is all there is. CLAUDE.md is the
      # kit's only if it still carries the kit's `## Session Boot`.
      if ack_prior_install "$DEST"; then
        if [ "$1" != CLAUDE.md ] || grep -q '^## Session Boot' "$DEST/CLAUDE.md" 2>/dev/null; then
          return 0
        fi
      fi
      PROJECT_OWN+=("$1")
      ;;
  esac
  return 1
}

# Files in the shared directories the manifest doesn't list: an older kit
# version's untouched leftovers are removed; everything else is the project's
# own and stays. The overlay directories are handled on their own
# (compared with the kit's copies).
LEFTOVERS_TO_REMOVE=()
if [ "$HAVE_MANIFEST" = true ]; then
  for _dir in $SHARED_DIRS; do
    [ -d "$DEST/$_dir" ] || continue
    while IFS= read -r _f; do
      _rel="${_f#"$DEST"/}"
      case "$_rel" in agent_docs/project/*|.claude/hooks/project/*) continue ;; esac
      manifest_covers "$_rel" && continue
      if kit_leftover "$_rel"; then
        LEFTOVERS_TO_REMOVE+=("$_rel")
      else
        PROJECT_OWN+=("$_rel")
      fi
    done < <(find "$DEST/$_dir" -type f ! -name .DS_Store | LC_ALL=C sort)
  done
fi

# An install from before .kit-baseline left no record of what it wrote, so nothing
# can be checked against one. Whatever goes is moved to .kit-backup/ first.
NO_RECORD=false
if [ "$(ack_record_files "$DEST")" -eq 0 ] && ack_prior_install "$DEST"; then
  NO_RECORD=true
fi

# Did the kit ever run here? Without a manifest, a record or its CLAUDE.md, the
# shared folders (scripts/, .claude/hooks/, wiki/, artifacts/ ...) are the project's
# own, and the whole-folder fallbacks below stay out of them — an install that
# aborted before writing anything leaves exactly this.
KIT_HERE=false
ack_prior_install "$DEST" && KIT_HERE=true

# module_here <file> — is this optional module's marker file the kit's? A wiki/ or
# artifacts/ folder with no such file is the project's own.
module_here() {
  case "$(ack_owner "$DEST" "$1")" in absent|unrecorded) return 1 ;; esac
  [ "$KIT_HERE" = true ]
}

# Root files
if [ -f "$DEST/VERSION" ]; then
  # Recorded and unchanged: the kit's. Not recorded (before R1 nothing recorded
  # VERSION): the kit's only if the manifest lists it and it still reads as the
  # kit's release-please line — a project's own VERSION stays.
  case "$(ack_owner "$DEST" VERSION)" in
    kit) FILES_TO_REMOVE+=("VERSION") ;;
    kit-edited) KEPT_EDITED+=("VERSION") ;;
    unverified) KEPT_UNVERIFIED+=("VERSION") ;;
    *)
      if manifest_covers VERSION && awk 'NR == 1 && /^[0-9]+\.[0-9]+\.[0-9]+ # x-release-please-version[ \t\r]*$/ { f = 1 } END { exit f ? 0 : 1 }' "$DEST/VERSION"; then
        FILES_TO_REMOVE+=("VERSION")
      else
        PROJECT_OWN+=("VERSION")
      fi
      ;;
  esac
fi
[ -f "$DEST/.kit-manifest" ] && FILES_TO_REMOVE+=(".kit-manifest")
[ -f "$DEST/.kit-baseline" ] && FILES_TO_REMOVE+=(".kit-baseline")
if [ -f "$DEST/CLAUDE.md" ] && may_remove "CLAUDE.md"; then
  FILES_TO_REMOVE+=("CLAUDE.md")
fi
if [ -f "$DEST/CODEBASE_MAP.md" ]; then
  if map_is_template; then
    FILES_TO_REMOVE+=("CODEBASE_MAP.md")
  else
    PROJECT_OWN+=("CODEBASE_MAP.md")
  fi
fi

# Project overlay files — the project's own. CLAUDE.project.md goes only while it
# is still the kit's template, byte for byte (so only with the kit tree at hand);
# the project/ folders hold the project's files, which stay, and the folder goes
# only when it is empty. --keep-project is accepted and does nothing now.
OVERLAY_DIRS=()
if [ -f "$DEST/CLAUDE.project.md" ]; then
  if same_as_kit "$DEST/CLAUDE.project.md" "CLAUDE.project.md"; then
    FILES_TO_REMOVE+=("CLAUDE.project.md")
  else
    PROJECT_OWN+=("CLAUDE.project.md")
  fi
fi
for _d in agent_docs/project .claude/hooks/project; do
  [ -d "$DEST/$_d" ] || continue
  OVERLAY_DIRS+=("$_d")
  while IFS= read -r _f; do
    _rel="${_f#"$DEST"/}"
    # the templates the kit ships in these folders go while still the kit's copy
    if same_as_kit "$_f" "$_rel"; then MODULE_TO_REMOVE+=("$_rel"); else PROJECT_OWN+=("$_rel"); fi
  done < <(find "$DEST/$_d" \( -type f -o -type l \) ! -name .DS_Store | LC_ALL=C sort)
done

# Directories (shared ones only without a manifest — see HAVE_MANIFEST)
if [ -d "$DEST/agent_docs" ] && [ "$HAVE_MANIFEST" = false ] && [ "$KIT_HERE" = true ]; then
  if [ -d "$DEST/agent_docs/project" ]; then
    # Remove kit files only, preserve project/ subdirectory
    DIRS_TO_REMOVE+=("agent_docs/*.md")
  else
    DIRS_TO_REMOVE+=("agent_docs/")
  fi
fi
[ -d "$DEST/scripts" ] && [ "$HAVE_MANIFEST" = false ] && [ "$KIT_HERE" = true ] && DIRS_TO_REMOVE+=("scripts/")

# tasks/ — the project's plans, lessons and decisions, and sometimes its own
# code (a task-queue package is called tasks/ too). Never removed as a whole: a
# file goes only when the record says the kit wrote it, or when it is still
# byte for byte the kit's scaffold copy (the installer doesn't record scaffold
# files yet). Anything else stays, listed. Without the kit tree (piped from curl)
# a scaffold file can't be told from an edit, so it stays.
TASKS_TO_REMOVE=()
if [ -d "$DEST/tasks" ]; then
  if [ "$KEEP_TASKS" = true ]; then
    warn "Keeping tasks/ (--keep-tasks)"
  else
    while IFS= read -r _f; do
      _rel="${_f#"$DEST"/}"
      if [ "$(ack_owner "$DEST" "$_rel")" = kit ] || same_as_kit "$_f" "scaffold/$_rel"; then
        TASKS_TO_REMOVE+=("$_rel")
      elif [ -n "$KIT_SRC" ] && [ -f "$KIT_SRC/scaffold/$_rel" ]; then
        KEPT_EDITED+=("$_rel")
      else
        PROJECT_OWN+=("$_rel")
      fi
    done < <(find "$DEST/tasks" \( -type f -o -type l \) ! -name .DS_Store | LC_ALL=C sort)
  fi
fi

# Wiki module (optional, installed via --wiki) — may contain user data
WIKI_PRESENT=false
if [ -f "$DEST/WIKI.md" ] && module_here WIKI.md; then
  WIKI_PRESENT=true
fi
if [ "$WIKI_PRESENT" = true ]; then
  if [ "$KEEP_WIKI" = true ]; then
    warn "Keeping WIKI.md, wiki/, raw-sources/ (--keep-wiki)"
  else
    # Never removed whole: the wiki index and log go while they are still what the
    # installer wrote, WIKI.md when it is the kit's; every page, raw source and
    # anything else stays, listed.
    if [ -f "$DEST/WIKI.md" ] && may_remove "WIKI.md"; then FILES_TO_REMOVE+=("WIKI.md"); fi
    for _d in wiki raw-sources; do
      [ -d "$DEST/$_d" ] || continue
      MODULE_DIRS+=("$_d")
      while IFS= read -r _f; do
        _rel="${_f#"$DEST"/}"
        if { [ "$_rel" = wiki/index.md ] && [ "$(cat "$_f")" = "$WIKI_SEED_INDEX" ]; } \
           || { [ "$_rel" = wiki/log.md ] && [ "$(cat "$_f")" = "$WIKI_SEED_LOG" ]; }; then
          MODULE_TO_REMOVE+=("$_rel")
        else
          PROJECT_OWN+=("$_rel")
        fi
      done < <(find "$DEST/$_d" \( -type f -o -type l \) ! -name .DS_Store | LC_ALL=C sort)
    done
  fi
fi

# HTML artifacts module (optional, installed via --html) — may contain user data
ARTIFACTS_PRESENT=false
if [ -f "$DEST/ARTIFACTS.md" ] && module_here ARTIFACTS.md; then
  ARTIFACTS_PRESENT=true
fi
if [ "$ARTIFACTS_PRESENT" = true ]; then
  if [ "$KEEP_ARTIFACTS" = true ]; then
    warn "Keeping ARTIFACTS.md, artifacts/ (--keep-artifacts)"
  else
    # Never removed whole: the two seed templates go while byte-identical to the
    # kit's (so only with the kit tree at hand), ARTIFACTS.md when it is the kit's;
    # every artifact and anything else stays, listed.
    if [ -f "$DEST/ARTIFACTS.md" ] && may_remove "ARTIFACTS.md"; then FILES_TO_REMOVE+=("ARTIFACTS.md"); fi
    if [ -d "$DEST/artifacts" ]; then
      MODULE_DIRS+=("artifacts")
      while IFS= read -r _f; do
        _rel="${_f#"$DEST"/}"
        case "$_rel" in
          artifacts/index.html|artifacts/design-system.html)
            if same_as_kit "$_f" "html-module/templates/${_rel#artifacts/}"; then
              MODULE_TO_REMOVE+=("$_rel"); continue
            fi ;;
        esac
        PROJECT_OWN+=("$_rel")
      done < <(find "$DEST/artifacts" \( -type f -o -type l \) ! -name .DS_Store | LC_ALL=C sort)
    fi
  fi
fi

# .claude/ subdirectories (shared ones only without a manifest — see HAVE_MANIFEST)
CLAUDE_DIRS_TO_REMOVE=()
if [ -d "$DEST/.claude/hooks" ] && [ "$HAVE_MANIFEST" = false ] && [ "$KIT_HERE" = true ]; then
  if [ -d "$DEST/.claude/hooks/project" ]; then
    # Remove kit hooks only, preserve project/ subdirectory
    CLAUDE_DIRS_TO_REMOVE+=(".claude/hooks/*.sh")
  else
    CLAUDE_DIRS_TO_REMOVE+=(".claude/hooks/")
  fi
fi
[ -d "$DEST/.claude/agents" ] && [ "$HAVE_MANIFEST" = false ] && [ "$KIT_HERE" = true ] && CLAUDE_DIRS_TO_REMOVE+=(".claude/agents/")
[ -d "$DEST/.claude/skills" ] && [ "$HAVE_MANIFEST" = false ] && [ "$KIT_HERE" = true ] && CLAUDE_DIRS_TO_REMOVE+=(".claude/skills/")

CLAUDE_FILES_TO_REMOVE=()
if [ -f "$DEST/.claude/settings.json" ] && may_remove ".claude/settings.json"; then
  CLAUDE_FILES_TO_REMOVE+=(".claude/settings.json")
fi
# Kit owns only extensions/README.md; user-installed extensions are preserved.
if [ -f "$DEST/.claude/extensions/README.md" ] && may_remove ".claude/extensions/README.md"; then
  CLAUDE_FILES_TO_REMOVE+=(".claude/extensions/README.md")
fi

# --- Manifest backstop set ---
# Anything the manifest recorded that the coarse path-based detection above does
# NOT already cover (drift: files a kit version ships but this script's hardcoded
# paths don't remove — e.g. .claude/*.example templates). Honors the --keep-*
# groups. Computed here so it shows in --dry-run and is removed for real alike.
manifest_entry_covered() {
  local p="$1" r pre ext
  for r in ${FILES_TO_REMOVE[@]+"${FILES_TO_REMOVE[@]}"} ${CLAUDE_FILES_TO_REMOVE[@]+"${CLAUDE_FILES_TO_REMOVE[@]}"}; do
    [ "$p" = "$r" ] && return 0
  done
  for r in ${DIRS_TO_REMOVE[@]+"${DIRS_TO_REMOVE[@]}"} ${CLAUDE_DIRS_TO_REMOVE[@]+"${CLAUDE_DIRS_TO_REMOVE[@]}"}; do
    case "$r" in
      */\*.sh|*/\*.md)
        # A glob entry (e.g. .claude/hooks/*.sh, matched as a whole)
        # covers only DIRECT children matching the pattern — NOT subdirs such as
        # the manifest's .claude/hooks/lib, which the backstop must still remove.
        pre="${r%/*}"; ext="${r##*.}"
        case "$p" in
          "$pre"/*/*) ;;                 # deeper than a direct child — not covered
          "$pre"/*.$ext) return 0 ;;     # direct child with the pattern's extension
        esac
        ;;
      *)
        # A whole-directory entry covers everything beneath it.
        pre="${r%/}"
        case "$p" in "$pre"/*) return 0 ;; esac
        ;;
    esac
  done
  return 1
}

BACKSTOP_TO_REMOVE=()
BACKSTOP_DIRS=()
for _entry in ${KIT_MANIFEST_ENTRIES[@]+"${KIT_MANIFEST_ENTRIES[@]}"}; do
  case "$_entry" in
    # decided above, file by file
    tasks|tasks/*) continue ;;
    # decided above, where each one's own rules apply
    WIKI.md|ARTIFACTS.md|CLAUDE.md|VERSION|.claude/settings.json|.claude/extensions/README.md) continue ;;
    CODEBASE_MAP.md) map_is_template || continue ;;
  esac
  # .kit-new copies an upgrade left next to a kit file go with it.
  for _new in "$DEST/$_entry".kit-new "$DEST/$_entry".kit-new.*; do
    if [ -e "$_new" ] && ! manifest_entry_covered "${_new#"$DEST"/}"; then
      BACKSTOP_TO_REMOVE+=("${_new#"$DEST"/}")
    fi
  done
  [ -e "$DEST/$_entry" ] || [ -L "$DEST/$_entry" ] || continue
  manifest_entry_covered "$_entry" && continue
  if ! record_backed "$_entry"; then
    BACKSTOP_TO_REMOVE+=("$_entry")
  elif [ -d "$DEST/$_entry" ] && [ ! -L "$DEST/$_entry" ]; then
    # A directory entry (a skill, hooks/lib): its files go one by one, each only
    # if the kit wrote it. When every file qualifies, the directory goes whole.
    _kept_here=0
    _ok_here=()
    while IFS= read -r _f; do
      _rel="${_f#"$DEST"/}"
      manifest_entry_covered "$_rel" && continue
      if may_remove "$_rel"; then _ok_here+=("$_rel"); else _kept_here=$((_kept_here + 1)); fi
    done < <(find "$DEST/$_entry" \( -type f -o -type l \) ! -name .DS_Store | LC_ALL=C sort)
    if [ "$_kept_here" -eq 0 ]; then
      BACKSTOP_TO_REMOVE+=("$_entry")
    else
      BACKSTOP_DIRS+=("$_entry")
      BACKSTOP_TO_REMOVE+=(${_ok_here[@]+"${_ok_here[@]}"})
    fi
  elif may_remove "$_entry"; then
    BACKSTOP_TO_REMOVE+=("$_entry")
  fi
done

# --- Nothing to remove? ---

TOTAL=$(( ${#FILES_TO_REMOVE[@]} + ${#DIRS_TO_REMOVE[@]} + ${#CLAUDE_DIRS_TO_REMOVE[@]} + ${#CLAUDE_FILES_TO_REMOVE[@]} + ${#BACKSTOP_TO_REMOVE[@]} + ${#LEFTOVERS_TO_REMOVE[@]} + ${#TASKS_TO_REMOVE[@]} + ${#MODULE_TO_REMOVE[@]} ))

if [ "$TOTAL" -eq 0 ]; then
  info "No Agent Code Kit files found in $(pwd)"
  echo "  Nothing to remove."
  echo ""
  exit 0
fi

# --- Show what will be removed ---

echo -e "  ${CYAN}Files to remove:${NC}"
echo ""

if [ ${#FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${FILES_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f"
  done
fi

if [ ${#DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${DIRS_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $d"
  done
fi

if [ ${#CLAUDE_DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${CLAUDE_DIRS_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $d"
  done
fi

if [ ${#CLAUDE_FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${CLAUDE_FILES_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f"
  done
fi

if [ ${#BACKSTOP_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${BACKSTOP_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f ${DIM}(manifest)${NC}"
  done
fi
if [ ${#LEFTOVERS_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${LEFTOVERS_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f ${DIM}(left by an older kit version, unchanged)${NC}"
  done
fi

if [ ${#TASKS_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${TASKS_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f ${DIM}(kit scaffold, unchanged)${NC}"
  done
fi
if [ ${#MODULE_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${MODULE_TO_REMOVE[@]}"; do
    echo -e "    ${RED}✕${NC} $f ${DIM}(kit seed, unchanged)${NC}"
  done
fi

if [ ${#PROJECT_OWN[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${CYAN}Kept — the kit didn't install these:${NC}"
  echo ""
  for f in "${PROJECT_OWN[@]}"; do
    echo -e "    ${GREEN}✓${NC} $f"
  done
fi
if [ ${#KEPT_EDITED[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${CYAN}Kept — edited since the install:${NC}"
  echo ""
  for f in "${KEPT_EDITED[@]}"; do
    echo -e "    ${GREEN}✓${NC} $f"
  done
fi
if [ ${#KEPT_UNVERIFIED[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${CYAN}Kept — can't be checked (no hash tool, or unreadable):${NC}"
  echo ""
  for f in "${KEPT_UNVERIFIED[@]}"; do
    echo -e "    ${GREEN}✓${NC} $f"
  done
fi

if [ "$NO_RECORD" = true ]; then
  echo ""
  warn "No install record (.kit-baseline): the kit's files can't be told from yours by content. Everything listed above is saved to .kit-backup/ before it goes."
fi

# Check if .claude/ will be empty after removal
CLAUDE_WILL_BE_EMPTY=false
if [ -d "$DEST/.claude" ]; then
  # Count items that will remain in .claude/ after removal
  REMAINING=0
  for item in "$DEST/.claude/"*; do
    [ -e "$item" ] || continue
    basename=$(basename "$item")
    # Skip items we're removing
    case "$basename" in
      hooks|agents|skills)
        # Only the kit's files leave these; the project's own keep them.
        for _own in ${PROJECT_OWN[@]+"${PROJECT_OWN[@]}"} ${KEPT_EDITED[@]+"${KEPT_EDITED[@]}"} ${KEPT_UNVERIFIED[@]+"${KEPT_UNVERIFIED[@]}"}; do
          case "$_own" in ".claude/$basename"/*) REMAINING=$((REMAINING + 1)); break ;; esac
        done
        continue
        ;;
      settings.json)
        # It leaves only when the kit wrote it and it is still as written.
        for _own in ${PROJECT_OWN[@]+"${PROJECT_OWN[@]}"} ${KEPT_EDITED[@]+"${KEPT_EDITED[@]}"} ${KEPT_UNVERIFIED[@]+"${KEPT_UNVERIFIED[@]}"}; do
          [ "$_own" = ".claude/settings.json" ] && { REMAINING=$((REMAINING + 1)); break; }
        done
        continue
        ;;
      settings.local.json) REMAINING=$((REMAINING + 1)); continue ;;
      .DS_Store) continue ;;
      extensions)
        # kit owns only extensions/README.md; count as remaining only if the
        # user installed their own extensions under it.
        [ -n "$(ls -A "$item" 2>/dev/null | grep -vx 'README.md')" ] && REMAINING=$((REMAINING + 1))
        continue
        ;;
      *)
        # A .claude/ item the manifest backstop will remove doesn't count as remaining.
        _rel=".claude/$basename"; _covered=0
        for _b in ${BACKSTOP_TO_REMOVE[@]+"${BACKSTOP_TO_REMOVE[@]}"}; do
          case "$_b" in "$_rel"|"$_rel"/*) _covered=1; break ;; esac
        done
        [ "$_covered" -eq 1 ] || REMAINING=$((REMAINING + 1))
        ;;
    esac
  done
  if [ "$REMAINING" -eq 0 ]; then
    CLAUDE_WILL_BE_EMPTY=true
    echo -e "    ${DIM}(will also remove empty .claude/ directory)${NC}"
  fi
fi

echo ""

# A settings.json that stays may still register kit hooks that are about to go.
for _f in ${KEPT_EDITED[@]+"${KEPT_EDITED[@]}"}; do
  if [ "$_f" = ".claude/settings.json" ]; then
    warn ".claude/settings.json stays (edited since the install) but may still register kit hooks that are removed — each fails on every matching event; delete those entries"
    echo ""
    break
  fi
done

# --- Dry run exits here ---

if [ "$DRY_RUN" = true ]; then
  info "Dry run — nothing was removed"
  echo ""
  exit 0
fi

# --- Confirm ---

if [ "$FORCE" != true ]; then
  read -p "  Remove all listed files? (y/N) " -n 1 -r < /dev/tty
  echo ""
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Cancelled."
    echo ""
    exit 0
  fi
fi

# --- Remove ---

REMOVED=0
BACKED_UP=0

# With no install record, save every path about to go — a link as a link, never
# followed — under .kit-backup/<UTC stamp>/ before anything is deleted.
if [ "$NO_RECORD" = true ]; then
  _stamp=".kit-backup/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$DEST/$_stamp"
  [ -f "$DEST/.kit-backup/.gitignore" ] || printf '*\n!.gitignore\n' > "$DEST/.kit-backup/.gitignore"
  for _p in ${FILES_TO_REMOVE[@]+"${FILES_TO_REMOVE[@]}"} ${DIRS_TO_REMOVE[@]+"${DIRS_TO_REMOVE[@]}"} \
            ${CLAUDE_DIRS_TO_REMOVE[@]+"${CLAUDE_DIRS_TO_REMOVE[@]}"} ${CLAUDE_FILES_TO_REMOVE[@]+"${CLAUDE_FILES_TO_REMOVE[@]}"} \
            ${BACKSTOP_TO_REMOVE[@]+"${BACKSTOP_TO_REMOVE[@]}"} ${LEFTOVERS_TO_REMOVE[@]+"${LEFTOVERS_TO_REMOVE[@]}"} \
            ${TASKS_TO_REMOVE[@]+"${TASKS_TO_REMOVE[@]}"}; do
    # a glob entry (agent_docs/*.md) expands to its files
    case "$_p" in
      *\**) set -- "$DEST"/$_p ;;
      *) set -- "$DEST/${_p%/}" ;;
    esac
    for _src in "$@"; do
      [ -e "$_src" ] || [ -L "$_src" ] || continue
      _rel="${_src#"$DEST"/}"
      mkdir -p "$DEST/$_stamp/$(dirname "$_rel")"
      if cp -a "$_src" "$DEST/$_stamp/$_rel"; then
        BACKED_UP=$((BACKED_UP + 1))
      else
        echo -e "  ${RED}[error]${NC} could not save $_rel to $_stamp/ — stopping before anything is removed" >&2
        exit 1
      fi
    done
  done
  ok "Saved $BACKED_UP path(s) to $_stamp/"
fi

# Root files
if [ ${#FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${FILES_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f"
    REMOVED=$((REMOVED + 1))
  done
fi

# Directories
if [ ${#DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${DIRS_TO_REMOVE[@]}"; do
    case "$d" in
      *\*.md|*\*.sh)
        # Glob pattern — remove matching files, then try to rmdir the parent
        local_dir="${d%/*}"
        rm -f "$DEST/"$d 2>/dev/null
        rmdir "$DEST/$local_dir" 2>/dev/null || true
        ok "Removed kit files from $local_dir/"
        REMOVED=$((REMOVED + 1))
        ;;
      *)
        # no trailing slash: on a link, rm takes the link and never its target
        rm -rf "${DEST:?}/${d%/}"
        ok "Removed $d"
        REMOVED=$((REMOVED + 1))
        ;;
    esac
  done
fi

# .claude/ subdirectories
if [ ${#CLAUDE_DIRS_TO_REMOVE[@]} -gt 0 ]; then
  for d in "${CLAUDE_DIRS_TO_REMOVE[@]}"; do
    case "$d" in
      *\*.sh)
        # Glob pattern — remove matching files, then try to rmdir the parent
        local_dir="${d%/*}"
        rm -f "$DEST/"$d 2>/dev/null
        rmdir "$DEST/$local_dir" 2>/dev/null || true
        ok "Removed kit files from $local_dir/"
        REMOVED=$((REMOVED + 1))
        ;;
      *)
        # no trailing slash: on a link, rm takes the link and never its target
        rm -rf "${DEST:?}/${d%/}"
        ok "Removed $d"
        REMOVED=$((REMOVED + 1))
        ;;
    esac
  done
fi

# .claude/ files
if [ ${#CLAUDE_FILES_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${CLAUDE_FILES_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f"
    REMOVED=$((REMOVED + 1))
  done
fi

# Manifest backstop — remove drift the path-based detection above didn't cover.
if [ ${#BACKSTOP_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${BACKSTOP_TO_REMOVE[@]}"; do
    rm -rf "${DEST:?}/${f:?}"
    ok "Removed $f (manifest)"
    REMOVED=$((REMOVED + 1))
    # Tidy an immediate parent dir the sweep may have emptied (e.g. a new top-level dir).
    _parent="${f%/*}"
    [ "$_parent" != "$f" ] && rmdir "$DEST/$_parent" 2>/dev/null || true
  done
fi
if [ ${#LEFTOVERS_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${LEFTOVERS_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f (older kit version)"
    REMOVED=$((REMOVED + 1))
  done
fi

# tasks/: the scaffold files go, then whatever directories that emptied.
if [ ${#TASKS_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${TASKS_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f"
    REMOVED=$((REMOVED + 1))
  done
  if [ -d "$DEST/tasks" ]; then
    find "$DEST/tasks" -name .DS_Store -delete 2>/dev/null || true
    find "$DEST/tasks" -depth -type d -exec rmdir {} + 2>/dev/null || true
  fi
fi

# Module seeds: the files go, then whatever folders that emptied — and the
# project/ overlay folders when nothing of the project's is in them.
if [ ${#MODULE_TO_REMOVE[@]} -gt 0 ]; then
  for f in "${MODULE_TO_REMOVE[@]}"; do
    rm -f "$DEST/$f"
    ok "Removed $f"
    REMOVED=$((REMOVED + 1))
  done
fi
for _d in ${MODULE_DIRS[@]+"${MODULE_DIRS[@]}"} ${OVERLAY_DIRS[@]+"${OVERLAY_DIRS[@]}"}; do
  [ -d "$DEST/$_d" ] || continue
  find "$DEST/$_d" -name .DS_Store -delete 2>/dev/null || true
  find "$DEST/$_d" -depth -type d -exec rmdir {} + 2>/dev/null || true
done

# A directory entry that kept some files goes only as far as it is empty.
for _d in ${BACKSTOP_DIRS[@]+"${BACKSTOP_DIRS[@]}"}; do
  [ -d "$DEST/$_d" ] || continue
  find "$DEST/$_d" -name .DS_Store -delete 2>/dev/null || true
  find "$DEST/$_d" -depth -type d -exec rmdir {} + 2>/dev/null || true
done

# Shared directories go once the kit's files are out, and only if nothing is left.
for _dir in .claude/hooks/lib .claude/hooks .claude/skills .claude/agents scripts agent_docs; do
  [ -d "$DEST/$_dir" ] || continue
  rm -f "$DEST/$_dir/.DS_Store"
  rmdir "$DEST/$_dir" 2>/dev/null && ok "Removed empty $_dir/" || true
done

# Remove the extensions/ slot only if it's now empty (user extensions preserved).
if [ -d "$DEST/.claude/extensions" ]; then
  rm -f "$DEST/.claude/extensions/.DS_Store"
  rmdir "$DEST/.claude/extensions" 2>/dev/null && ok "Removed empty .claude/extensions/" || true
fi

# Clean up empty .claude/ directory
if [ "$CLAUDE_WILL_BE_EMPTY" = true ] && [ -d "$DEST/.claude" ]; then
  # Remove .DS_Store if it's the only thing left
  rm -f "$DEST/.claude/.DS_Store"
  rmdir "$DEST/.claude" 2>/dev/null && ok "Removed empty .claude/" || true
fi

echo ""
echo "  Agent Code Kit has been removed."
_kept=$(( ${#PROJECT_OWN[@]} + ${#KEPT_EDITED[@]} + ${#KEPT_UNVERIFIED[@]} ))
if [ "$_kept" -gt 0 ]; then
  echo "  Kept $_kept file(s) that are yours or that you changed (listed above)."
fi
[ "$NO_RECORD" = true ] && echo "  saved $BACKED_UP path(s) to $_stamp/ before removing them"
echo "  removed $REMOVED · kept $_kept (edited ${#KEPT_EDITED[@]}, yours ${#PROJECT_OWN[@]}, unverified ${#KEPT_UNVERIFIED[@]})"
echo ""
echo "  Note: Your .gitignore was not modified."
echo "  You may want to remove kit-related entries manually."
echo ""
