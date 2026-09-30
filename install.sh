#!/usr/bin/env bash
#
# Agent Code Kit — Quick Setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/install.sh | bash
#
#   Or clone and run locally:
#   ./install.sh [--template nextjs|node-api|python-fastapi|go|rust|django|dotnet] [--profile minimal|standard|strict]
#

set -euo pipefail

REPO="https://github.com/lucasfelipe24/agent-code-kit.git"
TEMPLATE=""
PROFILE="standard"
UPGRADE=false
DIFF_MODE=false
GITIGNORE=false
WIKI=false
HTML=false
TARGET_VERSION=""
LOCAL_SOURCE=false
DEST="$(pwd)"
CLONE_DIR=""
MANIFEST_FILE=".kit-manifest"
MANIFEST_ENTRIES=()
# .kit-baseline — "<sha256><TAB><path>" for every kit file this installer wrote,
# i.e. what the kit last put at each path. --upgrade compares against it to tell
# an untouched kit file (safe to update) from a locally edited one (kept, reported).
BASELINE_FILE=".kit-baseline"
BASELINE_ENTRIES=()
KIT_TEMPLATE_USED=""
TEMPLATE_EXPLICIT=false
CLAUDE_MD_UNKNOWN=false
UP_ADDED=0
UP_UPDATED=0
UP_UNCHANGED=0
UP_BACKED_UP=0
YOURS_FILES=()
PRIOR_INSTALL=true
RECORD_WAS_MARKED=false
INSTALL_WRITING=false
KEPT_FILES=()
CONFLICT_FILES=()
BACKUP_DIR=""
PLAN_DIR=""
PREVIEW_LOG=""

# Track a file in the manifest (kit-managed). manifest_write() is provided by
# scripts/lib/manifest.sh, sourced once the kit source tree is available below.
manifest_add() {
  MANIFEST_ENTRIES+=("$1")
}

# manifest_drop <rel> — take <rel> back out: it turned out to be the project's.
manifest_drop() {
  local e keep=()
  for e in ${MANIFEST_ENTRIES[@]+"${MANIFEST_ENTRIES[@]}"}; do
    [ "$e" = "$1" ] || keep+=("$e")
  done
  MANIFEST_ENTRIES=(${keep[@]+"${keep[@]}"})
}

# Create wiki index.md template
create_wiki_index() {
  cat > "$1" << 'WIKIEOF'
# Wiki Index

Last updated: —
Sources: 0 | Wiki pages: 0

## Summaries

## Entities

## Concepts

## Analyses
WIKIEOF
}

# Create wiki log.md template
create_wiki_log() {
  cat > "$1" << 'WIKIEOF'
# Wiki Log
WIKIEOF
}

# Check if a path is a project overlay (never touched by kit)
is_project_overlay() {
  local path="$1"
  case "$path" in
    *.project.*|*/project/*|*/project) return 0 ;;
    *) return 1 ;;
  esac
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

# --- Upgrade preview (--diff) ---

# kit_attention_report <dest> <kit_dir> — what an upgrade can't fix on its own,
# one tab-separated line per finding:
#   stale<TAB><path>         .kit-baseline says the kit wrote it; the kit no
#                            longer ships it
#   listed<TAB><path>        an install from before .kit-baseline listed it in
#                            .kit-manifest and the kit no longer ships it — that
#                            list also took in the project's own files, so it
#                            may be the user's (never called stale)
#   unregistered<TAB><hook>  a standard-profile kit hook .claude/settings.json
#                            doesn't register — it never runs
#   dangling<TAB><path>      .claude/settings.json runs a hook script that exists
#                            neither in the project nor in the kit
#   optin<TAB><count>        strict-profile hooks available but not registered
kit_attention_report() {
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$1" "$2" <<'PY' 2>/dev/null || true
import json, os, re, sys

dest, kit = sys.argv[1], sys.argv[2]
HOOK_RE = re.compile(r"\.claude/hooks/[A-Za-z0-9_./-]+?\.sh")

def read_paths(name, fields):
    found = set()
    try:
        with open(os.path.join(dest, name)) as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if parts[0] and not parts[0].startswith("#") and len(parts) == fields:
                    found.add(parts[-1])
    except OSError:
        pass
    return found

# Only .kit-baseline shows what the kit actually wrote. Without it, fall back to
# .kit-manifest, hedged: older installs recorded the project's own files there too.
baseline = read_paths(".kit-baseline", 2)
recorded, kind = (baseline, "stale") if baseline else (read_paths(".kit-manifest", 1), "listed")

def shipped(rel):
    candidates = [rel]
    if rel.startswith((".claude/skills/", ".claude/agents/")):
        candidates.append("wiki-module/" + rel)
    return any(os.path.exists(os.path.join(kit, c)) for c in candidates)

for rel in sorted(recorded):
    if not rel.startswith((".claude/hooks/", "scripts/", ".claude/agents/", ".claude/skills/", "agent_docs/")):
        continue
    if rel.startswith((".claude/hooks/project/", "agent_docs/project/")):
        continue
    if os.path.exists(os.path.join(dest, rel)) and not shipped(rel):
        print(f"{kind}\t{rel}")

def registered(path):
    try:
        with open(path) as fh:
            d = json.load(fh)
    except (OSError, ValueError):
        return None
    found = set()
    for groups in (d.get("hooks") or {}).values():
        for g in groups or []:
            for h in g.get("hooks") or []:
                found.update(HOOK_RE.findall(str(h.get("command", ""))))
    return found

local = registered(os.path.join(dest, ".claude", "settings.json"))
standard = registered(os.path.join(kit, ".claude", "settings.json")) or set()
strict = registered(os.path.join(kit, ".claude", "settings.strict.json")) or set()
if local is not None:
    for h in sorted(standard - local):
        print(f"unregistered\t{h}")
    for h in sorted(local):
        if not os.path.exists(os.path.join(dest, h)) and not os.path.exists(os.path.join(kit, h)):
            print(f"dangling\t{h}")
    optin = (strict - standard) - local
    if optin:
        print(f"optin\t{len(optin)}")

# Env keys under the kit's former configuration prefix (ADR-029), which the
# hooks now ignore. Names are counted, never printed with values. The prefix is
# built from character codes so the tracked tree never spells it.
legacy = "".join(map(chr, (67, 67, 75, 95)))
count = 0
for name in ("settings.json", "settings.local.json"):
    try:
        with open(os.path.join(dest, ".claude", name)) as fh:
            env = json.load(fh).get("env") or {}
    except (OSError, ValueError, AttributeError):
        continue
    if isinstance(env, dict):
        count += sum(1 for k in env if isinstance(k, str) and k.startswith(legacy))
if count:
    print(f"legacy\t{count}")
PY
}

# print_attention <dest> <kit_dir> — kit_attention_report for a person. Sets
# ATTENTION_COUNT to the number of findings that need action ("listed" paths
# may be the project's own, so they are shown but not counted).
ATTENTION_COUNT=0
print_attention() {
  local report kind value stale="" listed="" unreg="" dangling="" optin="" legacy=""
  ATTENTION_COUNT=0
  report=$(kit_attention_report "$1" "$2")
  [ -n "$report" ] || return 0
  while IFS=$'\t' read -r kind value; do
    case "$kind" in
      stale)        stale="${stale}       - ${value}"$'\n';       ATTENTION_COUNT=$((ATTENTION_COUNT + 1)) ;;
      listed)       listed="${listed}       - ${value}"$'\n' ;;
      unregistered) unreg="${unreg}       - ${value}"$'\n';       ATTENTION_COUNT=$((ATTENTION_COUNT + 1)) ;;
      dangling)     dangling="${dangling}       - ${value}"$'\n'; ATTENTION_COUNT=$((ATTENTION_COUNT + 1)) ;;
      optin)        optin="$value" ;;
      legacy)       legacy="$value";                          ATTENTION_COUNT=$((ATTENTION_COUNT + 1)) ;;
    esac
  done <<<"$report"
  if [ -n "$stale" ]; then
    echo ""
    warn "The kit no longer ships these, though the install record says it put them here — remove them if nothing uses them:"
    printf '%s' "$stale"
  fi
  if [ -n "$listed" ]; then
    echo ""
    info "The kit doesn't ship these paths, which an older install listed in .kit-manifest. That list also took in files the project already had, so they may be your own — check before removing anything:"
    printf '%s' "$listed"
  fi
  if [ -n "$unreg" ]; then
    echo ""
    warn "Kit hooks not registered in .claude/settings.json — they never run until you add them (see the kit's .claude/settings.json):"
    printf '%s' "$unreg"
  fi
  if [ -n "$dangling" ]; then
    echo ""
    warn ".claude/settings.json runs hook scripts that don't exist — each one fails on every matching event:"
    printf '%s' "$dangling"
  fi
  if [ -n "$optin" ]; then
    echo ""
    info "$optin opt-in hook(s) from the strict profile are available but not registered (see the kit's .claude/settings.strict.json)."
  fi
  if [ -n "$legacy" ]; then
    echo ""
    warn "$legacy key(s) in .claude/settings*.json use the kit's former configuration prefix, which the hooks now ignore — run ./scripts/doctor.sh to rename them to ACK_* (values are kept)."
  fi
  return 0
}

# _plan_compare <dest> <plan_dir> — how the upgraded scratch copy differs from
# the project: add / update / conflict lines, then backups<TAB><count>. A
# conflict whose kit copy went to <file>.kit-new.<n> (an earlier .kit-new is
# still there) carries that name as a third field.
_plan_compare() {
  python3 - "$1" "$2" <<'PY'
import filecmp, os, re, sys

dest, plan = sys.argv[1], sys.argv[2]
BOOKKEEPING = {".kit-baseline", ".kit-manifest", "VERSION"}
KIT_NEW = re.compile(r"^(.+)\.kit-new(\.[0-9]+)?$")
backups = 0
for root, dirs, files in os.walk(plan):
    rel_root = os.path.relpath(root, plan)
    in_backup = rel_root == ".kit-backup" or rel_root.startswith(".kit-backup" + os.sep)
    for name in sorted(files):
        rel = os.path.normpath(os.path.join(rel_root, name))
        mine = os.path.join(dest, rel)
        if in_backup:
            if name != ".gitignore" and not os.path.exists(mine):
                backups += 1
            continue
        if rel in BOOKKEEPING:
            continue
        theirs = os.path.join(plan, rel)
        kit_new = KIT_NEW.match(rel)
        if kit_new:
            if not (os.path.isfile(mine) and filecmp.cmp(theirs, mine, shallow=False)):
                print("conflict\t" + kit_new.group(1) + ("\t" + rel if kit_new.group(2) else ""))
        elif not os.path.isfile(mine):
            print("add\t" + rel)
        elif not filecmp.cmp(theirs, mine, shallow=False):
            print("update\t" + rel)
print(f"backups\t{backups}")
PY
}

# plan_copy <src> <dest> — copy into --diff's scratch dir, following symlinks.
# GNU cp stops at a broken link; the rest is still copied, and what's missing
# shows up as an addition.
plan_copy() {
  cp -RLp "$1" "$2" || warn "Couldn't fully copy ${1#"$DEST"/} for the preview (a broken symlink inside it?) — what's missing may show as an addition"
}

# _kit_symlinks <dest> — every symlink among the paths --upgrade writes to (the
# path itself, or the top-most link below it), as path<TAB>resolved target.
_kit_symlinks() {
  python3 - "$1" <<'PY'
import os, sys

dest = sys.argv[1]
WALK = ["agent_docs", "tasks", "scripts", ".claude/hooks", ".claude/agents", ".claude/skills", ".claude/extensions"]
ONLY = ["CLAUDE.md", "CODEBASE_MAP.md", "CLAUDE.project.md", "WIKI.md", "ARTIFACTS.md", ".claude",
        ".claude/settings.json", ".claude/mcp-allowlist.txt.example", ".claude/commands.json.example",
        "wiki", "wiki/index.md", "wiki/log.md", "artifacts", "artifacts/index.html", "artifacts/design-system.html"]
for rel in ONLY + WALK:
    full = os.path.join(dest, rel)
    if os.path.islink(full):
        print(rel + "\t" + os.path.realpath(full))
    elif rel in WALK and os.path.isdir(full):
        for root, dirs, files in os.walk(full):
            for name in sorted(dirs + files):
                path = os.path.join(root, name)
                if os.path.islink(path):
                    print(os.path.relpath(path, dest) + "\t" + os.path.realpath(path))
PY
}

# preview_list <marker> <color> <title> <newline-separated items>
preview_list() {
  local item
  [ -n "$4" ] || return 0
  echo ""
  echo -e "  $3"
  while IFS= read -r item; do
    if [ -n "$item" ]; then
      echo -e "    ${2}${1}${NC} $item"
    fi
  done <<<"$4"
}

# run_diff — preview what --upgrade would do, without changing anything. The
# upgrade itself runs on a scratch copy of the project's kit-managed files (plus
# the root files template detection reads), and the copy is compared with the
# project — so the preview is exactly what the upgrade would do: same code, same
# decisions. Then what an upgrade can't fix: stale kit files, hook registrations.
run_diff() {
  local p f rows log added updated conflicts kept kind new n_add n_upd n_conf n_kept n_back installed latest
  echo ""
  echo "  Agent Code Kit — Upgrade preview (read-only)"
  echo "  ============================================="
  echo ""
  if [ -z "$CLONE_DIR" ]; then
    CLONE_DIR=$(mktemp -d)
    if [ -n "$TARGET_VERSION" ]; then
      case "$TARGET_VERSION" in
        v*) ;;
        *) TARGET_VERSION="v$TARGET_VERSION" ;;
      esac
      info "Downloading Agent Code Kit ($TARGET_VERSION)..."
      git clone --quiet --depth 1 --branch "$TARGET_VERSION" "$REPO" "$CLONE_DIR" 2>/dev/null || error "Version $TARGET_VERSION not found"
    else
      info "Downloading latest Agent Code Kit..."
      git clone --quiet --depth 1 "$REPO" "$CLONE_DIR" 2>/dev/null || error "Failed to clone repository"
    fi
  else
    info "Using local kit source: $CLONE_DIR"
  fi
  command -v python3 >/dev/null 2>&1 || error "--diff needs python3 to compare the planned upgrade with your project"

  installed="not installed"; latest="unknown"
  # Sourced here too: --diff runs before the main flow loads the library.
  . "$CLONE_DIR/scripts/lib/manifest.sh"
  if [ -f "$DEST/VERSION" ]; then
    if version_is_kit; then
      installed="v$(sed 's/ *#.*//' "$DEST/VERSION" | tr -d '[:space:]')"
    else
      installed="unknown (VERSION is your project's)"
    fi
  fi
  [ -f "$CLONE_DIR/VERSION" ] && latest="v$(sed 's/ *#.*//' "$CLONE_DIR/VERSION" | tr -d '[:space:]')"
  echo -e "  Installed: ${YELLOW}${installed}${NC}   Kit: ${GREEN}${latest}${NC}"

  PLAN_DIR=$(mktemp -d)
  PREVIEW_LOG=$(mktemp)
  # The copy dereferences symlinks (-L): a linked path arrives as a real copy of
  # its target, so the scratch upgrade can't write through a link into the
  # project or anywhere else.
  for p in CLAUDE.md CODEBASE_MAP.md CLAUDE.project.md VERSION .kit-manifest .kit-baseline WIKI.md ARTIFACTS.md \
           agent_docs tasks scripts \
           package.json go.mod Cargo.toml manage.py requirements.txt pyproject.toml Pipfile setup.py global.json; do
    if [ -e "$DEST/$p" ]; then
      plan_copy "$DEST/$p" "$PLAN_DIR/"
    fi
  done
  # Root marker files, and any kit copies still waiting beside root kit files
  for f in "$DEST"/next.config.* "$DEST"/*.sln "$DEST"/*.slnx "$DEST"/*.csproj "$DEST"/*.kit-new*; do
    if [ -f "$f" ]; then
      plan_copy "$f" "$PLAN_DIR/"
    fi
  done
  while IFS= read -r f; do  # .NET projects below the root, for template detection
    if [ -n "$f" ] && [ -f "$f" ]; then
      mkdir -p "$PLAN_DIR/$(dirname "${f#"$DEST"/}")"
      plan_copy "$f" "$PLAN_DIR/${f#"$DEST"/}"
    fi
  done <<<"$(find_dotnet_markers "$DEST")"
  if [ -d "$DEST/.claude" ]; then
    mkdir -p "$PLAN_DIR/.claude"
    for p in hooks agents skills extensions settings.json mcp-allowlist.txt.example commands.json.example; do
      if [ -e "$DEST/.claude/$p" ]; then
        plan_copy "$DEST/.claude/$p" "$PLAN_DIR/.claude/"
      fi
    done
    for f in "$DEST"/.claude/*.kit-new*; do
      if [ -f "$f" ]; then
        plan_copy "$f" "$PLAN_DIR/.claude/"
      fi
    done
  fi
  for p in wiki artifacts; do  # the optional modules seed a couple of files here
    if [ -d "$DEST/$p" ]; then
      mkdir -p "$PLAN_DIR/$p"
      for f in "$DEST/$p"/*.md "$DEST/$p"/*.html; do
        if [ -f "$f" ]; then
          plan_copy "$f" "$PLAN_DIR/$p/"
        fi
      done
    fi
  done
  # A broken link survives -L (BSD cp copies it as a link): drop every link, so
  # nothing in the scratch copy can lead outside it. The path then reads as
  # missing, as it does to the real upgrade.
  find "$PLAN_DIR" -type l -exec rm -f {} +

  set -- --local "$CLONE_DIR" --upgrade --profile "$PROFILE"
  if [ "$TEMPLATE_EXPLICIT" = true ]; then set -- "$@" --template "$TEMPLATE"; fi
  if [ "$WIKI" = true ]; then set -- "$@" --wiki; fi
  if [ "$HTML" = true ]; then set -- "$@" --html; fi
  if ! ( cd "$PLAN_DIR" && bash "$CLONE_DIR/install.sh" "$@" ) >"$PREVIEW_LOG" 2>&1; then
    tail -8 "$PREVIEW_LOG"
    error "The preview upgrade failed on the scratch copy — nothing in your project was changed"
  fi

  rows=$(_plan_compare "$DEST" "$PLAN_DIR")
  log=$(sed "s/$(printf '\033')\[[0-9;]*m//g" "$PREVIEW_LOG")
  added=$(awk -F'\t' '$1 == "add" { print $2 }' <<<"$rows")
  updated=$(awk -F'\t' '$1 == "update" { print $2 }' <<<"$rows")
  n_back=$(awk -F'\t' '$1 == "backups" { print $2 }' <<<"$rows")
  kept=$(awk '/Kept with your local edits/ { f = 1; next } f && /^ +- / { sub(/^ +- /, ""); print; next } { f = 0 }' <<<"$log")
  conflicts=""
  while IFS=$'\t' read -r kind f new; do
    [ "$kind" = conflict ] || continue
    if [ -n "$new" ]; then
      f="$f (kit copy → $new — an earlier .kit-new is still there)"
    fi
    conflicts="${conflicts}${f}"$'\n'
  done <<<"$rows"
  n_add=$(grep -c . <<<"$added" || true)
  n_upd=$(grep -c . <<<"$updated" || true)
  n_conf=$(grep -c . <<<"$conflicts" || true)
  n_kept=$(grep -c . <<<"$kept" || true)

  preview_list "~" "$YELLOW" "Will be updated ($n_upd) — kit files you haven't edited:" "$updated"
  preview_list "+" "$GREEN" "Will be added ($n_add):" "$added"
  preview_list "!" "$RED" "Conflicts ($n_conf) — your copy is kept; the kit's copy will be written beside it as <file>.kit-new:" "$conflicts"
  preview_list "=" "$DIM" "Kept ($n_kept) — they carry your own edits and the kit has no newer version, unless noted:" "$kept"
  if [ "${n_back:-0}" -gt 0 ]; then
    echo ""
    echo "  $n_back of these predate the install record — their current copies will be saved to .kit-backup/ first."
  fi
  if [[ "$log" == *"CLAUDE.md left untouched"* ]]; then
    echo ""
    warn "$(sed -n 's/^\[warn\]  \(CLAUDE.md left untouched.*\)/\1/p' <<<"$log")"
  fi
  while IFS=$'\t' read -r p f; do
    if [ -n "$p" ]; then
      echo ""
      warn "$p is a symlink — --upgrade writes through it to $f (this preview worked on a copy)"
    fi
  done <<<"$(_kit_symlinks "$DEST")"
  print_attention "$DEST" "$CLONE_DIR"

  echo ""
  echo "  ============================================="
  if [ $((n_add + n_upd + n_conf + ATTENTION_COUNT)) -eq 0 ]; then
    echo "  Your installation is up to date."
  else
    echo "  $n_upd to update · $n_add to add · $n_conf conflicts · $ATTENTION_COUNT to review by hand"
    if [ $((n_add + n_upd + n_conf)) -gt 0 ]; then
      echo "  Run install.sh --upgrade to apply the changes above."
    fi
    echo "  --upgrade never changes .claude/settings.json or your project files (tasks/, CODEBASE_MAP.md, overlays)."
  fi
  echo ""
}

# user_script_names — the scripts/*.sh names install.sh ships: KIT_USER_SCRIPTS
# from scripts/lib/manifest.sh. The rest of scripts/ is kit-maintainer tooling
# that only runs inside the kit repo. A --version clone of a kit that predates
# the list falls back to every script, as that kit shipped.
user_script_names() {
  if [ -n "${KIT_USER_SCRIPTS:-}" ]; then
    echo "$KIT_USER_SCRIPTS"
    return 0
  fi
  local f
  for f in "$CLONE_DIR/scripts/"*.sh; do
    [ -f "$f" ] && basename "$f"
  done
  return 0
}

# note_added <path>… — count, on --upgrade, a file created outside upgrade_file
# (a fresh directory, a seeded scaffold, a module file) — every file under a
# directory — so the summary's "added" matches what --diff says it will add.
note_added() {
  [ "$UPGRADE" = true ] || return 0
  local p n
  for p in "$@"; do
    if [ -d "$p" ]; then
      n=$(find "$p" -type f | wc -l | tr -d ' ')
      UP_ADDED=$((UP_ADDED + n))
    elif [ -f "$p" ]; then
      UP_ADDED=$((UP_ADDED + 1))
    fi
  done
  return 0
}

# Copy a single file if it doesn't exist. Returns 0 if copied, 1 if skipped.
copy_if_new() {
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    ok "Added $label"
    return 0
  fi
  return 1
}

# --- Plain-install helpers (a project that already has these folders) ---
#
# A plain install (no --upgrade) never overwrites and never skips a whole folder
# because it exists: each kit file is placed on its own, by what the install
# record (.kit-baseline) says about the path (ack_owner, scripts/lib/manifest.sh):
#   absent                           → copied, recorded, listed in the manifest
#   kit / kit-edited                 → already the kit's: listed, left as it is
#   no-record, listed by the old
#   manifest                         → an install from before the record: the kit's
#   anything else                    → the project's: untouched, unlisted, reported
# The manifest and the record then name only what the kit owns (N1).
INIT_INSTALLED=0
INIT_KEPT=()
INSTALL_OURS=false

# prev_manifest_lists <rel> — did the manifest the previous run left list <rel>,
# or a folder entry that holds it (.claude/hooks/lib, a skill)?
prev_manifest_lists() {
  [ -f "$DEST/$MANIFEST_FILE" ] || return 1
  awk -v p="$1" '$0 == p || index(p, $0 "/") == 1 { f = 1 } END { exit f ? 0 : 1 }' "$DEST/$MANIFEST_FILE"
}

# version_is_kit — is $DEST/VERSION the kit's? Missing: it will be written. Recorded
# and unchanged: yes; recorded and edited: no. Not recorded (nothing before R1
# recorded VERSION): the kit's only if the old manifest lists it and it still reads
# as the kit's own release-please line; a project's VERSION is its own.
version_is_kit() {
  case "$(ack_owner "$DEST" VERSION)" in
    absent|kit) return 0 ;;
    kit-edited) return 1 ;;
  esac
  prev_manifest_lists VERSION || return 1
  awk 'NR == 1 && /^[0-9]+\.[0-9]+\.[0-9]+ # x-release-please-version[ \t\r]*$/ { f = 1 } END { exit f ? 0 : 1 }' "$DEST/VERSION"
}

# install_file <src> <rel> [nomanifest] — place one kit file (see above). Sets
# INSTALL_OURS to whether the kit owns <rel> afterwards.
install_file() {
  local src="$1" rel="$2" st
  INSTALL_OURS=false
  st=$(ack_owner "$DEST" "$rel")
  case "$st" in
    absent)
      mkdir -p "$(dirname "$DEST/$rel")"
      cp "$src" "$DEST/$rel"
      case "$rel" in *.sh) chmod +x "$DEST/$rel" 2>/dev/null || true ;; esac
      baseline_record "$src" "$rel"
      note_added "$DEST/$rel"
      INIT_INSTALLED=$((INIT_INSTALLED + 1))
      INSTALL_OURS=true
      ;;
    kit|kit-edited) INSTALL_OURS=true ;;
    no-record) prev_manifest_lists "$rel" && INSTALL_OURS=true ;;
  esac
  if [ "$INSTALL_OURS" = true ]; then
    [ "${3:-}" = nomanifest ] || manifest_add "$rel"
  else
    INIT_KEPT+=("$rel")
  fi
  return 0
}

# install_tree <src_dir> <rel_dir> <manifest entry> [always] — a folder of kit
# files (a skill, hooks/lib) into a project that has the folder already. When some
# file in it is the kit's, each kit file is placed on its own; a folder where none
# is belongs to the project (a skill of its own named like a kit skill) and gets
# no kit file mixed in. `always` skips that test: hooks/lib must be installed
# whatever else sits in it (the hooks fail closed without it).
install_tree() {
  local src_dir="${1%/}" rel_dir="$2" entry="$3" f rel any=false st
  if [ -d "$DEST/$rel_dir" ] && [ "${4:-}" != always ]; then
    while IFS= read -r f; do
      rel="$rel_dir/${f#"$src_dir"/}"
      st=$(ack_owner "$DEST" "$rel")
      case "$st" in
        kit|kit-edited) any=true ;;
        no-record) prev_manifest_lists "$rel" && any=true ;;
      esac
    done < <(find "$src_dir" -type f ! -name .DS_Store | LC_ALL=C sort)
    if [ "$any" = false ]; then
      INIT_KEPT+=("$rel_dir/ (a folder of your own that shares the kit's name)")
      return 0
    fi
  fi
  while IFS= read -r f; do
    install_file "$f" "$rel_dir/${f#"$src_dir"/}" nomanifest
  done < <(find "$src_dir" -type f ! -name .DS_Store | LC_ALL=C sort)
  # The folder entry stands for the files the kit owns in it; uninstall checks
  # each one against the record, so the project's own files in there stay.
  manifest_add "$entry"
  return 0
}

# Copy new files from src_dir into dest_dir (non-recursive, never overwrites).
# For user-owned scaffolds (tasks/): the kit seeds them once, the project owns
# them after that. Skips project overlay files. Tracks installed files in manifest.
seed_dir() {
  local src_dir="$1" dest_dir="$2" pattern="${3:-*}" label="$4"
  local added=0
  mkdir -p "$dest_dir"
  for src_file in "$src_dir"/$pattern; do
    [ -f "$src_file" ] || continue
    local basename
    basename=$(basename "$src_file")
    # Skip project overlay files
    if is_project_overlay "$basename"; then
      continue
    fi
    manifest_add "$label/$basename"
    if [ ! -f "$dest_dir/$basename" ]; then
      cp "$src_file" "$dest_dir/$basename"
      note_added "$dest_dir/$basename"
      added=$((added + 1))
      ok "Added $label/$basename"
    fi
  done
  if [ "$added" -eq 0 ]; then
    info "No new files in $label/"
  fi
  return 0
}

# --- Upgrade helpers ---

# hash_tool — the sha256 tool file_hash uses; empty when there's none.
hash_tool() {
  local t
  for t in sha256sum shasum python3; do
    if command -v "$t" >/dev/null 2>&1; then
      echo "$t"
      return 0
    fi
  done
  return 0
}

# file_hash <path> — sha256 of a file; empty when no hashing tool exists.
file_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
  fi
}

# baseline_lookup <rel> — the hash the kit last installed at <rel>, from the
# .kit-baseline the previous run left (rewritten only at the end of this run).
baseline_lookup() {
  [ -f "$DEST/$BASELINE_FILE" ] || return 0
  awk -F'\t' -v p="$1" '!/^#/ && $2 == p { print $1; exit }' "$DEST/$BASELINE_FILE"
}

# baseline_template — the template the previous run recorded for CLAUDE.md.
baseline_template() {
  [ -f "$DEST/$BASELINE_FILE" ] || return 0
  awk -F'\t' '$1 == "#template" { print $2; exit }' "$DEST/$BASELINE_FILE"
}

# baseline_record <src> <rel> — record that the kit's <src> now sits at <rel>.
baseline_record() {
  local h
  h=$(file_hash "$1")
  if [ -n "$h" ]; then
    BASELINE_ENTRIES+=("$h"$'\t'"$2")
  fi
}

# baseline_record_tree <src_dir> <rel_dir> — baseline_record every file in a tree.
baseline_record_tree() {
  local src_dir="${1%/}" rel_dir="$2" f
  while IFS= read -r f; do
    baseline_record "$f" "$rel_dir/${f#"$src_dir"/}"
  done < <(find "$src_dir" -type f ! -name .DS_Store)
}

# backup_file <rel> — copy <rel> into this run's .kit-backup/<UTC stamp>/ before
# it is overwritten. The .kit-backup/ directory ignores itself in git.
backup_file() {
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR=".kit-backup/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$DEST/$BACKUP_DIR"
    [ -f "$DEST/.kit-backup/.gitignore" ] || printf '*\n!.gitignore\n' > "$DEST/.kit-backup/.gitignore"
  fi
  mkdir -p "$DEST/$BACKUP_DIR/$(dirname "$1")"
  cp -p "$DEST/$1" "$DEST/$BACKUP_DIR/$1"
}

# replace_file <src> <dest> — write <src> over <dest> as a new file: a temp file
# in the same directory, then mv. Another hard link to the old file keeps the
# old content, and a read-only file is replaced instead of stopping the run (it
# stays read-only). A symlink is written through to its target, as cp did.
replace_file() {
  local src="$1" dest="$2" link tmp
  while [ -L "$dest" ] && [ -e "$dest" ]; do
    link=$(readlink "$dest")
    case "$link" in
      /*) dest="$link" ;;
      *) dest="$(dirname "$dest")/$link" ;;
    esac
  done
  tmp="$(dirname "$dest")/.kit-tmp.$$.${RANDOM:-0}"
  cp "$src" "$tmp" || { rm -f "$tmp"; return 1; }
  if [ -e "$dest" ] && [ -x "$dest" ]; then
    chmod +x "$tmp"
  fi
  if [ -e "$dest" ] && [ ! -w "$dest" ]; then
    chmod a-w "$tmp"
  fi
  mv -f "$tmp" "$dest"
}

# write_kit_new <src> <rel> — put the kit's copy beside <rel> for the user to
# merge. Never overwrites: if <rel>.kit-new (or .kit-new.<n>) already holds
# exactly this copy, nothing is written and KIT_NEW is that file with
# KIT_NEW_PENDING=true; otherwise the copy goes to the first free name of
# <rel>.kit-new, <rel>.kit-new.1, … and KIT_NEW is that name.
KIT_NEW=""
KIT_NEW_PENDING=false
write_kit_new() {
  local src="$1" rel="$2" f n=1
  KIT_NEW_PENDING=false
  for f in "$DEST/$rel.kit-new" "$DEST/$rel".kit-new.[0-9]*; do
    if [ -f "$f" ] && cmp -s "$src" "$f"; then
      KIT_NEW="${f#"$DEST"/}"
      KIT_NEW_PENDING=true
      return 0
    fi
  done
  KIT_NEW="$rel.kit-new"
  while [ -e "$DEST/$KIT_NEW" ] || [ -L "$DEST/$KIT_NEW" ]; do
    KIT_NEW="$rel.kit-new.$n"
    n=$((n + 1))
  done
  cp "$src" "$DEST/$KIT_NEW"
}

# upgrade_file <src> <rel> — bring one kit-managed file up to date:
#   missing                            → added
#   local == kit                       → unchanged
#   no baseline entry (an install from → updated, previous copy backed up: a
#   before .kit-baseline, a module        local edit, an older kit file and a
#   added since, a file of your own       file of the user's own can't be told
#   at a kit path)                        apart, so the copy is kept
#   local == baseline                  → untouched since install → updated
#   local != baseline, kit == baseline → edited locally, kit unchanged → kept
#   local != baseline, kit != baseline → conflict: kept, kit copy → <rel>.kit-new
# A kit copy already waiting in a .kit-new is not written again; the file counts
# as kept until it's merged. Writes go through replace_file.
upgrade_file() {
  local src="$1" rel="$2" dest="$DEST/$2" base src_hash local_hash
  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    baseline_record "$src" "$rel"
    UP_ADDED=$((UP_ADDED + 1))
    ok "Added $rel"
    return 0
  fi
  if cmp -s "$src" "$dest"; then
    baseline_record "$src" "$rel"
    UP_UNCHANGED=$((UP_UNCHANGED + 1))
    return 0
  fi
  base=$(baseline_lookup "$rel")
  src_hash=$(file_hash "$src")
  local_hash=$(file_hash "$dest")
  if [ -z "$base" ] && { [ "$RECORD_WAS_MARKED" = true ] || [ "$PRIOR_INSTALL" = false ]; }; then
    # ADR-030: the record is complete (or the kit was never here), so a file it
    # doesn't list is the project's own — kept, not listed, not recorded.
    manifest_drop "$rel"
    YOURS_FILES+=("$rel")
  elif [ -z "$base" ]; then
    backup_file "$rel"
    replace_file "$src" "$dest"
    baseline_record "$src" "$rel"
    UP_UPDATED=$((UP_UPDATED + 1))
    UP_BACKED_UP=$((UP_BACKED_UP + 1))
    ok "Updated $rel — the install record doesn't list it; your copy is in $BACKUP_DIR/$rel"
  elif [ "$local_hash" = "$base" ]; then
    replace_file "$src" "$dest"
    baseline_record "$src" "$rel"
    UP_UPDATED=$((UP_UPDATED + 1))
    ok "Updated $rel"
  elif [ "$src_hash" = "$base" ]; then
    # Baseline entry carries over unchanged (baseline_write keeps old entries).
    KEPT_FILES+=("$rel")
  else
    write_kit_new "$src" "$rel"
    # Record the version offered, so the next upgrade stays quiet unless the kit
    # changes this file again.
    baseline_record "$src" "$rel"
    if [ "$KIT_NEW_PENDING" = true ]; then
      KEPT_FILES+=("$rel (the kit's version is waiting in $KIT_NEW)")
    elif [ "$KIT_NEW" = "$rel.kit-new" ]; then
      CONFLICT_FILES+=("$rel")
      warn "Conflict: $rel has local edits and a kit update — kit version saved as $KIT_NEW"
    else
      CONFLICT_FILES+=("$rel (kit version in $KIT_NEW — an earlier .kit-new is still there)")
      warn "Conflict: $rel has local edits and a kit update — kit version saved as $KIT_NEW (an earlier $rel.kit-new is still there, not overwritten)"
    fi
  fi
}

# upgrade_tree <src_dir> <rel_dir> — upgrade_file every file in a tree (skills).
upgrade_tree() {
  local src_dir="${1%/}" rel_dir="$2" f
  while IFS= read -r f; do
    upgrade_file "$f" "$rel_dir/${f#"$src_dir"/}"
  done < <(find "$src_dir" -type f ! -name .DS_Store)
}

# upgrade_dir <src_dir> <dest_dir> <pattern> <label> — upgrade_file each matching
# file (non-recursive). Skips project overlay files. Tracks files in the manifest.
upgrade_dir() {
  local src_dir="$1" dest_dir="$2" pattern="${3:-*}" label="$4"
  local src_file basename
  mkdir -p "$dest_dir"
  for src_file in "$src_dir"/$pattern; do
    [ -f "$src_file" ] || continue
    basename=$(basename "$src_file")
    # Skip project overlay files
    if is_project_overlay "$basename"; then
      continue
    fi
    manifest_add "$label/$basename"
    upgrade_file "$src_file" "$label/$basename"
  done
  return 0
}

# kit_claude_md <file> — <file> has the kit's own CLAUDE.md structure: every kit
# template carries a "## Session Boot" section. The first line alone proves
# nothing — Claude Code's /init also starts a CLAUDE.md with "# CLAUDE.md".
kit_claude_md() {
  grep -q '^## Session Boot' "$1" 2>/dev/null
}

# installed_template — the template the existing CLAUDE.md came from: the one
# .kit-baseline records, else inferred from its heading (each template names its
# stack on line 1). "generic" = the root CLAUDE.md; empty = unknown.
installed_template() {
  local t head1 d
  t=$(baseline_template)
  if [ -z "$t" ] && [ -f "$DEST/CLAUDE.md" ] && kit_claude_md "$DEST/CLAUDE.md"; then
    head1=$(head -n 1 "$DEST/CLAUDE.md")
    if [ "$head1" = "$(head -n 1 "$CLONE_DIR/CLAUDE.md")" ]; then
      t="generic"
    fi
    for d in "$CLONE_DIR"/examples/*/; do
      if [ -f "${d}CLAUDE.md" ] && [ "$head1" = "$(head -n 1 "${d}CLAUDE.md")" ]; then
        t=$(basename "$d")
      fi
    done
  fi
  # A recorded template the kit no longer ships is as good as unknown.
  if [ -n "$t" ] && [ "$t" != "generic" ] && [ ! -f "$CLONE_DIR/examples/$t/CLAUDE.md" ]; then
    t=""
  fi
  echo "$t"
}

# baseline_write — merge this run's records over the previous .kit-baseline (a
# path this run didn't touch keeps its old entry) and write it atomically.
baseline_write() {
  local old="$DEST/$BASELINE_FILE" tmp template="$KIT_TEMPLATE_USED"
  if [ "$NO_HASH" = true ]; then
    warn "No sha256 tool found (sha256sum, shasum or python3) — .kit-baseline not written. Install one before --upgrade; the first upgrade then replaces changed kit files and backs up the previous copies."
    return 0
  fi
  if [ -z "$template" ]; then
    template=$(baseline_template)
  fi
  tmp=$(mktemp "$DEST/.kit-baseline.XXXXXX" 2>/dev/null) || tmp=$(mktemp)
  {
    # #complete (ADR-030): every kit path is recorded or known to be the project's.
    # A first install, any --upgrade, and a plain run over an already-marked record
    # leave it so; a plain run over an unmarked or missing record does not, and an
    # interrupted run never does.
    if [ "${1:-}" != partial ] && { [ "$UPGRADE" = true ] || [ "$PRIOR_INSTALL" = false ] || [ "$RECORD_WAS_MARKED" = true ]; }; then
      printf '#complete\t1\n'
    fi
    if [ -n "$template" ]; then
      printf '#template\t%s\n' "$template"
    fi
    {
      if [ "${#BASELINE_ENTRIES[@]}" -gt 0 ]; then
        printf '%s\n' "${BASELINE_ENTRIES[@]}"
      fi
      if [ -f "$old" ]; then
        awk '!/^#/' "$old"
      fi
    } | awk -F'\t' 'NF == 2 && !seen[$2]++' | LC_ALL=C sort -t "$(printf '\t')" -k2,2
  } > "$tmp"
  mv "$tmp" "$DEST/$BASELINE_FILE"
}

# print_upgrade_summary — what --upgrade did, so a quiet log can never hide files
# that were updated, kept with local edits, or left in conflict.
print_upgrade_summary() {
  local f
  echo ""
  echo -e "  Upgrade summary: ${GREEN}${UP_UPDATED} updated${NC} · ${GREEN}${UP_ADDED} added${NC} · ${UP_UNCHANGED} unchanged · ${YELLOW}${#KEPT_FILES[@]} kept (local edits)${NC} · ${RED}${#CONFLICT_FILES[@]} conflicts${NC} · ${#YOURS_FILES[@]} yours"
  if [ "$UP_BACKED_UP" -gt 0 ]; then
    echo "  $UP_BACKED_UP replaced file(s) predate the install record — previous copies are in $BACKUP_DIR/"
  fi
  if [ "${#CONFLICT_FILES[@]}" -gt 0 ]; then
    echo ""
    warn "Conflicts — your copy is kept and the kit's is beside it. Merge <file>.kit-new into <file>, then delete the .kit-new:"
    for f in "${CONFLICT_FILES[@]}"; do
      echo "       - $f"
    done
  fi
  if [ "${#KEPT_FILES[@]}" -gt 0 ]; then
    echo ""
    info "Kept with your local edits (the kit has no newer version of these, unless noted):"
    for f in "${KEPT_FILES[@]}"; do
      echo "       - $f"
    done
  fi
  if [ "${#YOURS_FILES[@]}" -gt 0 ]; then
    echo ""
    info "Yours — the kit has a file at these paths but its version isn't installed (delete yours and re-run to get the kit's):"
    for f in "${YOURS_FILES[@]}"; do
      echo "       - $f"
    done
  fi
  print_attention "$DEST" "$CLONE_DIR"
}

cleanup() {
  local rc=$?
  # A real run that failed midway: write what it did as an unmarked record, so the
  # next --upgrade completes it (ADR-023) instead of finding unrecorded kit files.
  if [ "$rc" -ne 0 ] && [ "$INSTALL_WRITING" = true ] && [ "$NO_HASH" != true ]; then
    [ -f "$DEST/$MANIFEST_FILE" ] || manifest_write "$DEST" 2>/dev/null || true
    baseline_write partial 2>/dev/null || true
  fi
  # Only clean up if we cloned to a temp directory (not --local mode)
  if [ "$LOCAL_SOURCE" = false ] && [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
    rm -rf "$CLONE_DIR"
  fi
  # --diff's scratch copy and its log
  if [ -n "$PLAN_DIR" ]; then rm -rf "$PLAN_DIR"; fi
  if [ -n "$PREVIEW_LOG" ]; then rm -f "$PREVIEW_LOG"; fi
}
trap cleanup EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template|-t)
      [ $# -ge 2 ] || error "--template requires an argument"
      TEMPLATE="$2"
      TEMPLATE_EXPLICIT=true
      shift 2
      ;;
    --profile|-p)
      [ $# -ge 2 ] || error "--profile requires an argument"
      PROFILE="$2"
      shift 2
      ;;
    --upgrade|-u)
      UPGRADE=true
      shift
      ;;
    --diff|-d)
      DIFF_MODE=true
      shift
      ;;
    --gitignore|-g)
      GITIGNORE=true
      shift
      ;;
    --wiki)
      WIKI=true
      shift
      ;;
    --html)
      HTML=true
      shift
      ;;
    --version|-v)
      [ $# -ge 2 ] || error "--version requires an argument"
      TARGET_VERSION="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: install.sh [--template nextjs|node-api|python-fastapi|go|rust|django|dotnet] [--profile minimal|standard|strict] [--upgrade] [--diff]"
      echo ""
      echo "Options:"
      echo "  --template, -t   Use a stack-specific template (nextjs, node-api, python-fastapi, go, rust, django, dotnet)"
      echo "  --profile, -p    Installation profile (default: standard)"
      echo "                     minimal  — hooks only, no CLAUDE.md or docs"
      echo "                     standard — full kit with default hooks"
      echo "                     strict   — full kit with all hooks enabled"
      echo "  --upgrade, -u    Update kit-managed files; ones you edited are kept and reported (project files untouched)"
      echo "  --diff, -d       Preview what --upgrade would change (read-only): updates, additions, conflicts, stale kit files, hook registrations"
      echo "  --gitignore, -g  Add kit files to .gitignore (keep kit local, don't push to repo)"
      echo "  --wiki           Add knowledge wiki module (personal knowledge base)"
      echo "  --html           Add HTML artifacts module (specs, reports, PR writeups as HTML)"
      echo "  --version, -v    Install a specific version (e.g., --version v1.0.0)"
      echo "  --help, -h       Show this help"
      echo ""
      echo "To uninstall: ./uninstall.sh (or curl -fsSL .../uninstall.sh | bash)"
      exit 0
      ;;
    --local)
      [ $# -ge 2 ] || error "--local requires a path argument"
      # Absolute, so --diff's nested run still finds the kit from its scratch dir.
      CLONE_DIR="$(cd "$2" 2>/dev/null && pwd)" || error "--local: not a directory: $2"
      LOCAL_SOURCE=true
      shift 2
      ;;
    *)
      error "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

# Validate template if provided
if [ -n "$TEMPLATE" ]; then
  case "$TEMPLATE" in
    nextjs|node-api|python-fastapi|go|rust|django|dotnet) ;;
    *) error "Unknown template: $TEMPLATE. Options: nextjs, node-api, python-fastapi, go, rust, django, dotnet" ;;
  esac
fi

# Validate profile
case "$PROFILE" in
  minimal|standard|strict) ;;
  *) error "Unknown profile: $PROFILE. Options: minimal, standard, strict" ;;
esac

# The upgrade decides every file by its sha256 against .kit-baseline. Without a
# hash tool it can't, so --upgrade and --diff stop before anything changes. A
# fresh install still works; it just can't write the record — its first upgrade
# is then treated like one from an install that predates .kit-baseline.
NO_HASH=false
if [ -z "$(hash_tool)" ]; then
  if [ "$UPGRADE" = true ] || [ "$DIFF_MODE" = true ]; then
    error "No sha256 tool found (sha256sum, shasum or python3) — --upgrade compares every kit file by hash and can't run without one. Nothing was changed."
  fi
  NO_HASH=true
fi

# find_dotnet_markers <dest> — *.sln / *.slnx / *.csproj up to 3 levels down,
# skipping VCS, dependency and build output directories. (Output captured whole:
# a pipe into head would kill find with SIGPIPE under pipefail.)
find_dotnet_markers() {
  find "$1" -maxdepth 3 \( -name .git -o -name node_modules -o -name bin -o -name obj \) -prune \
    -o -type f \( -name '*.sln' -o -name '*.slnx' -o -name '*.csproj' \) -print 2>/dev/null || true
}

# Auto-detect template if not specified
auto_detect_template() {
  local dest="$1"
  # Next.js
  for f in "next.config.js" "next.config.mjs" "next.config.ts"; do
    [ -f "$dest/$f" ] && echo "nextjs" && return
  done
  # Go
  [ -f "$dest/go.mod" ] && echo "go" && return
  # Rust
  [ -f "$dest/Cargo.toml" ] && echo "rust" && return
  # .NET — a solution, a project, or an SDK pin at the root (ahead of Node: a
  # .NET repo often carries a package.json for front-end tooling)
  for f in "$dest"/*.sln "$dest"/*.slnx "$dest"/*.csproj "$dest/global.json"; do
    [ -f "$f" ] && echo "dotnet" && return
  done
  # Django (manage.py, or Django pinned in requirements) — before generic Python
  if [ -f "$dest/manage.py" ] || { [ -f "$dest/requirements.txt" ] && grep -qiE '^django([=<>!~ ]|$)' "$dest/requirements.txt" 2>/dev/null; }; then
    echo "django" && return
  fi
  # Python (FastAPI / generic)
  for f in "requirements.txt" "pyproject.toml" "Pipfile" "setup.py"; do
    [ -f "$dest/$f" ] && echo "python-fastapi" && return
  done
  # Node API (package.json exists but no next.config)
  [ -f "$dest/package.json" ] && echo "node-api" && return
  # .NET with its solution or projects below the root (src/App/App.csproj) —
  # only when no root marker matched
  [ -n "$(find_dotnet_markers "$dest")" ] && echo "dotnet" && return
  echo ""
}

# (Not in --diff mode: the preview's own upgrade run decides the template. Not on
# --upgrade either: an existing CLAUDE.md keeps its own template — see below.)
if [ -z "$TEMPLATE" ] && [ "$PROFILE" != "minimal" ] && [ "$DIFF_MODE" = false ] && [ "$UPGRADE" = false ]; then
  DETECTED_TEMPLATE=$(auto_detect_template "$DEST")
  if [ -n "$DETECTED_TEMPLATE" ]; then
    TEMPLATE="$DETECTED_TEMPLATE"
    info "Auto-detected template: $TEMPLATE"
  fi
fi

# Warn if minimal + template (template is ignored for minimal)
if [ "$PROFILE" = "minimal" ] && [ -n "$TEMPLATE" ]; then
  warn "Template is ignored with minimal profile (no CLAUDE.md or docs installed)"
  TEMPLATE=""
fi

# Diff mode — compare and exit (no changes made)
if [ "$DIFF_MODE" = true ]; then
  run_diff
  exit 0
fi

echo ""
echo "  Agent Code Kit Installer"
echo "  ========================="
echo "  Profile: $PROFILE"
if [ -n "$TARGET_VERSION" ]; then
  echo "  Version: $TARGET_VERSION"
fi
echo ""

# Check for existing files (skip for minimal — it doesn't copy these)
if [ "$UPGRADE" = true ]; then
  info "Upgrade mode — kit-managed files are updated; ones you edited are kept and reported; project files (tasks/, CODEBASE_MAP.md, overlays) are left alone"
else
  EXISTING=()
  if [ "$PROFILE" != "minimal" ]; then
    [ -f "$DEST/CLAUDE.md" ] && EXISTING+=("CLAUDE.md")
    [ -f "$DEST/CODEBASE_MAP.md" ] && EXISTING+=("CODEBASE_MAP.md")
  fi

  if [ ${#EXISTING[@]} -gt 0 ]; then
    warn "These files already exist and will be SKIPPED:"
    for f in ${EXISTING[@]+"${EXISTING[@]}"}; do
      echo "       - $f"
    done
    echo ""
    if [ ! -e /dev/tty ]; then
      error "Non-interactive environment detected. Use --upgrade to skip confirmation."
    fi
    read -p "  Continue? (y/N) " -n 1 -r < /dev/tty
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      info "Cancelled."
      exit 0
    fi
  fi
fi

# Clone to temp directory
# Use local source if provided (npx mode), otherwise clone from git
if [ -n "$CLONE_DIR" ]; then
  info "Using local kit source: $CLONE_DIR"
else
  CLONE_DIR=$(mktemp -d)
  if [ -n "$TARGET_VERSION" ]; then
    # Ensure version tag has v prefix
    case "$TARGET_VERSION" in
      v*) ;;
      *) TARGET_VERSION="v$TARGET_VERSION" ;;
    esac
    info "Downloading Agent Code Kit ($TARGET_VERSION)..."
    git clone --quiet --depth 1 --branch "$TARGET_VERSION" "$REPO" "$CLONE_DIR" 2>/dev/null || error "Version $TARGET_VERSION not found. Check available versions at https://github.com/lucasfelipe24/agent-code-kit/releases"
  else
    info "Downloading Agent Code Kit (latest)..."
    git clone --quiet --depth 1 "$REPO" "$CLONE_DIR" 2>/dev/null || error "Failed to clone repository"
  fi
fi

# Source the shared manifest library from the kit source (single home for the
# manifest write logic — same code scripts/sync-manifest.sh uses). It only ships
# with the kit source, so it's available here regardless of curl|bash vs npx.
if [ -f "$CLONE_DIR/scripts/lib/manifest.sh" ]; then
  . "$CLONE_DIR/scripts/lib/manifest.sh"
else
  error "Missing scripts/lib/manifest.sh in the kit source — cannot write the manifest"
fi

# Read version from downloaded kit
KIT_VERSION="unknown"
if [ -f "$CLONE_DIR/VERSION" ]; then
  KIT_VERSION=$(cat "$CLONE_DIR/VERSION" | sed 's/ *#.*//' | tr -d '[:space:]')
fi

# On --upgrade an existing CLAUDE.md keeps the template it came from — never one
# auto-detected from today's tree (a generic install that later gained a
# package.json would otherwise be swapped for node-api). The template is the one
# .kit-baseline records, else the one its first line names; when neither says,
# CLAUDE.md is left alone. --template still wins. A missing CLAUDE.md is created
# from the recorded template, else an auto-detected one.
if [ "$UPGRADE" = true ] && [ "$TEMPLATE_EXPLICIT" = false ] && [ "$PROFILE" != "minimal" ]; then
  if [ -f "$DEST/CLAUDE.md" ]; then
    INSTALLED_TEMPLATE=$(installed_template)
    if [ -n "$INSTALLED_TEMPLATE" ]; then
      info "Keeping installed template: $INSTALLED_TEMPLATE"
      TEMPLATE="$INSTALLED_TEMPLATE"
    else
      CLAUDE_MD_UNKNOWN=true
      if [ ! -f "$DEST/CODEBASE_MAP.md" ]; then
        TEMPLATE=$(auto_detect_template "$DEST")  # only picks the map to create
      fi
      if kit_claude_md "$DEST/CLAUDE.md"; then
        warn "CLAUDE.md left untouched: can't tell which kit template it came from (its first line matches none, and .kit-baseline records none). Pass --template <name> to upgrade it to a stack template, or merge the kit's CLAUDE.md by hand."
      else
        warn "CLAUDE.md left untouched: it has none of the kit's sections, so the kit never wrote it — one from /init or your own. Pass --template <name> to replace it with a kit template (your copy is backed up first)."
      fi
    fi
  else
    TEMPLATE=$(baseline_template)
    if [ -z "$TEMPLATE" ] || { [ "$TEMPLATE" != "generic" ] && [ ! -f "$CLONE_DIR/examples/$TEMPLATE/CLAUDE.md" ]; }; then
      TEMPLATE=$(auto_detect_template "$DEST")
      if [ -n "$TEMPLATE" ]; then
        info "Auto-detected template: $TEMPLATE"
      fi
    fi
  fi
  [ "$TEMPLATE" = "generic" ] && TEMPLATE=""
fi

# On --upgrade the optional modules an earlier install added stay installed, as
# the template does. Without --wiki / --html a plain --upgrade used to drop their
# files from .kit-manifest: the files stayed, but doctor stopped calling them a
# module and later upgrades stopped updating them. A module is installed when the
# previous .kit-manifest lists its schema file — or, for a manifest such an
# upgrade already stripped, when that file is on disk and opens with the kit's
# own heading (a WIKI.md of the project's own doesn't count).
module_installed() {
  [ -f "$DEST/$MANIFEST_FILE" ] || return 1
  grep -qxF "$1" "$DEST/$MANIFEST_FILE" && return 0
  [ -f "$DEST/$1" ] && [ "$(head -n 1 "$DEST/$1" | tr -d '\r')" = "$(head -n 1 "$CLONE_DIR/$1" 2>/dev/null)" ]
}
if [ "$UPGRADE" = true ] && [ "$PROFILE" != "minimal" ]; then
  KEPT_MODULES=""
  if [ "$WIKI" = false ] && module_installed "WIKI.md"; then
    WIKI=true
    KEPT_MODULES="wiki"
  fi
  if [ "$HTML" = false ] && module_installed "ARTIFACTS.md"; then
    HTML=true
    KEPT_MODULES="${KEPT_MODULES:+$KEPT_MODULES, }html"
  fi
  if [ -n "$KEPT_MODULES" ]; then
    info "Keeping installed modules: $KEPT_MODULES"
  fi
fi

# Determine source for CLAUDE.md and CODEBASE_MAP.md
if [ -n "$TEMPLATE" ]; then
  SRC_CLAUDE="$CLONE_DIR/examples/$TEMPLATE/CLAUDE.md"
  SRC_MAP="$CLONE_DIR/examples/$TEMPLATE/CODEBASE_MAP.md"
  info "Using template: $TEMPLATE"
else
  SRC_CLAUDE="$CLONE_DIR/CLAUDE.md"
  # scaffold/CODEBASE_MAP.md — a blank, stack-agnostic map to fill in. This
  # repo's own CODEBASE_MAP.md describes AgentCodeKit, so shipping it as the
  # fallback told the agent it was working on the kit.
  SRC_MAP="$CLONE_DIR/scaffold/CODEBASE_MAP.md"
  info "Using generic template"
fi

# Safety hooks source their library and fail closed without it. A file of the
# project's own where a kit library file belongs would be sourced in its place, so
# stop before anything is written rather than install hooks that block every edit.
if [ "$UPGRADE" != true ] && [ -d "$CLONE_DIR/.claude/hooks/lib" ] && [ -d "$DEST/.claude/hooks/lib" ]; then
  for f in "$CLONE_DIR/.claude/hooks/lib/"*.sh; do
    [ -f "$f" ] || continue
    rel=".claude/hooks/lib/$(basename "$f")"
    case "$(ack_owner "$DEST" "$rel")" in
      absent|kit|kit-edited) ;;
      no-record) prev_manifest_lists "$rel" || error "$rel exists and isn't the kit's — the kit's hooks would source it and fail. Rename or move it, then run the install again. Nothing was written." ;;
      *) error "$rel exists and isn't the kit's — the kit's hooks would source it and fail. Rename or move it, then run the install again. Nothing was written." ;;
    esac
  done
fi

# What the record says before this run touches anything.
ack_prior_install "$DEST" || PRIOR_INSTALL=false
ack_record_complete "$DEST" && RECORD_WAS_MARKED=true
INSTALL_WRITING=true

# Copy VERSION file (always, all profiles) — unless the project has its own.
VERSION_OURS=true
if [ -f "$DEST/VERSION" ] && ! version_is_kit; then
  VERSION_OURS=false
fi
if [ "$VERSION_OURS" = true ]; then
  cp "$CLONE_DIR/VERSION" "$DEST/VERSION"
  baseline_record "$CLONE_DIR/VERSION" "VERSION"
  manifest_add "VERSION"
else
  warn "VERSION is your project's — the kit's version isn't recorded here until the kit folder moves out of the root"
  if [ "$UPGRADE" = true ]; then YOURS_FILES+=("VERSION"); else INIT_KEPT+=("VERSION"); fi
fi

# --- Profile: standard and strict get docs, tasks, scripts ---
if [ "$PROFILE" != "minimal" ]; then

  # Copy CLAUDE.md
  if [ ! -f "$DEST/CLAUDE.md" ]; then
    manifest_add "CLAUDE.md"
    cp "$SRC_CLAUDE" "$DEST/CLAUDE.md"
    baseline_record "$SRC_CLAUDE" "CLAUDE.md"
    note_added "$DEST/CLAUDE.md"
    KIT_TEMPLATE_USED="${TEMPLATE:-generic}"
    ok "Created CLAUDE.md"
  elif [ "$UPGRADE" = true ] && [ "$CLAUDE_MD_UNKNOWN" = true ]; then
    manifest_add "CLAUDE.md"
    :  # template unknown — left untouched, reported above
  elif [ "$UPGRADE" = true ]; then
    manifest_add "CLAUDE.md"
    upgrade_file "$SRC_CLAUDE" "CLAUDE.md"
    KIT_TEMPLATE_USED="${TEMPLATE:-generic}"
  else
    warn "Skipped CLAUDE.md (already exists)"
    # Listed only when the kit wrote it: the project's own CLAUDE.md is not ours.
    case "$(ack_owner "$DEST" CLAUDE.md)" in
      kit|kit-edited) manifest_add "CLAUDE.md" ;;
      no-record) if prev_manifest_lists CLAUDE.md && kit_claude_md "$DEST/CLAUDE.md"; then manifest_add "CLAUDE.md"; fi ;;
    esac
  fi

  # Copy CODEBASE_MAP.md
  manifest_add "CODEBASE_MAP.md"
  if [ ! -f "$DEST/CODEBASE_MAP.md" ]; then
    cp "$SRC_MAP" "$DEST/CODEBASE_MAP.md"
    note_added "$DEST/CODEBASE_MAP.md"
    ok "Created CODEBASE_MAP.md"
  else
    warn "Skipped CODEBASE_MAP.md (already exists)"
  fi

  # Create project overlay template (never overwritten)
  if [ ! -f "$DEST/CLAUDE.project.md" ]; then
    if [ -f "$CLONE_DIR/CLAUDE.project.md" ]; then
      cp "$CLONE_DIR/CLAUDE.project.md" "$DEST/CLAUDE.project.md"
      note_added "$DEST/CLAUDE.project.md"
      ok "Created CLAUDE.project.md (project overlay — customize for your project)"
    fi
  else
    info "Kept CLAUDE.project.md (project overlay)"
  fi

  # Copy agent_docs/
  if [ ! -d "$DEST/agent_docs" ]; then
    cp -r "$CLONE_DIR/agent_docs" "$DEST/agent_docs"
    note_added "$DEST/agent_docs"
    ok "Created agent_docs/"
    # Track all copied files in manifest + baseline
    for f in "$CLONE_DIR/agent_docs/"*.md; do
      [ -f "$f" ] || continue
      manifest_add "agent_docs/$(basename "$f")"
      baseline_record "$f" "agent_docs/$(basename "$f")"
    done
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$CLONE_DIR/agent_docs" "$DEST/agent_docs" "*.md" "agent_docs"
  else
    for f in "$CLONE_DIR/agent_docs/"*.md; do
      [ -f "$f" ] || continue
      is_project_overlay "$(basename "$f")" && continue
      install_file "$f" "agent_docs/$(basename "$f")"
    done
  fi

  # Create agent_docs/project/ overlay directory
  if [ ! -d "$DEST/agent_docs/project" ]; then
    mkdir -p "$DEST/agent_docs/project"
    ok "Created agent_docs/project/ (project-specific docs go here)"
  fi

  # Copy tasks/ from scaffold/tasks/ — the pristine board, ADR log, handoff
  # template and starter lessons. Never from this repo's own tasks/, which holds
  # the kit's live task board, its 15 ADRs and its real lessons; shipping those
  # hands every new project someone else's project state.
  # A folder called tasks/ that is the project's own code (a task queue's package)
  # gets nothing from the board. A kit-shaped one — empty, or holding a scaffold
  # name (todo.md, decisions.md, handoff.md, lessons/) — is completed file by
  # file and never overwritten.
  TASKS_SHAPED=true
  if [ -d "$DEST/tasks" ] && [ -n "$(ls -A "$DEST/tasks")" ]; then
    TASKS_SHAPED=false
    for f in todo.md decisions.md handoff.md lessons; do
      [ -e "$DEST/tasks/$f" ] && TASKS_SHAPED=true
    done
  fi
  if [ "$TASKS_SHAPED" = false ]; then
    INIT_KEPT+=("tasks/ (holds your own files, so the task board wasn't installed)")
    [ "$UPGRADE" = true ] && warn "tasks/ holds your own files — the task board wasn't installed"
  elif [ ! -d "$DEST/tasks" ]; then
    cp -r "$CLONE_DIR/scaffold/tasks" "$DEST/tasks"
    note_added "$DEST/tasks"
    ok "Created tasks/"
    baseline_record_tree "$CLONE_DIR/scaffold/tasks" "tasks"
    while IFS= read -r f; do
      manifest_add "tasks/${f#"$CLONE_DIR"/scaffold/tasks/}"
    done < <(find "$CLONE_DIR/scaffold/tasks" -type f -name '*.md' | LC_ALL=C sort)
  else
    while IFS= read -r f; do
      install_file "$f" "tasks/${f#"$CLONE_DIR"/scaffold/tasks/}"
    done < <(find "$CLONE_DIR/scaffold/tasks" -type f ! -name .DS_Store | LC_ALL=C sort)
  fi

  # Legacy detection: old single-file tasks/lessons.md
  # Inform the user there is a migration path; never auto-migrate (user data).
  if [ -f "$DEST/tasks/lessons.md" ]; then
    warn "Detected legacy tasks/lessons.md (old single-file format)"
    warn "Run ./scripts/migrate-lessons.sh to convert it to the new per-file structure"
  fi

  # Copy scripts — the user-facing ones only (see user_script_names)
  if [ ! -d "$DEST/scripts" ]; then
    mkdir -p "$DEST/scripts"
    for kit_script in $(user_script_names); do
      [ -f "$CLONE_DIR/scripts/$kit_script" ] || continue
      cp "$CLONE_DIR/scripts/$kit_script" "$DEST/scripts/"
      manifest_add "scripts/$kit_script"
      baseline_record "$CLONE_DIR/scripts/$kit_script" "scripts/$kit_script"
    done
    chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
    note_added "$DEST/scripts"
    SCRIPT_COUNT=$(ls -1 "$DEST/scripts/"*.sh 2>/dev/null | wc -l | tr -d ' ')
    ok "Created scripts/ ($SCRIPT_COUNT scripts)"
  elif [ "$UPGRADE" = true ]; then
    for kit_script in $(user_script_names); do
      [ -f "$CLONE_DIR/scripts/$kit_script" ] || continue
      manifest_add "scripts/$kit_script"
      upgrade_file "$CLONE_DIR/scripts/$kit_script" "scripts/$kit_script"
    done
    chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true  # a broken link among them fails chmod
  else
    # The project's own scripts/ stays; the kit's scripts go in beside it.
    for kit_script in $(user_script_names); do
      [ -f "$CLONE_DIR/scripts/$kit_script" ] || continue
      install_file "$CLONE_DIR/scripts/$kit_script" "scripts/$kit_script"
    done
  fi

  # Earlier installs also copied the kit-maintainer scripts. Report any still
  # here, never delete them: they're in the user's tree and may be kept on
  # purpose. With a previous manifest, only names it lists count — a same-named
  # script of the user's own was never the kit's. Without one, only an upgrade
  # implies an earlier kit install put them there.
  RETIRED_SCRIPTS=""
  for kit_script in build-skills.sh check-counts.sh check-scaffold.sh gen-skill-docs.sh gen-strict-settings.sh run-bench.sh sync-manifest.sh test-cli.sh test-install.sh; do
    [ -f "$DEST/scripts/$kit_script" ] || continue
    if [ -f "$DEST/$MANIFEST_FILE" ]; then
      grep -qxF "scripts/$kit_script" "$DEST/$MANIFEST_FILE" || continue
    elif [ "$UPGRADE" != true ]; then
      continue
    fi
    RETIRED_SCRIPTS="$RETIRED_SCRIPTS scripts/$kit_script"
  done
  if [ -n "$RETIRED_SCRIPTS" ]; then
    warn "No longer shipped (kit-maintainer only, they don't run outside the kit repo):$RETIRED_SCRIPTS"
    warn "Delete them unless you use them yourself — install.sh leaves them in place"
  fi

fi

# Copy hooks
if [ ! -d "$DEST/.claude/hooks" ]; then
  mkdir -p "$DEST/.claude/hooks"
  for f in "$CLONE_DIR/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    cp "$f" "$DEST/.claude/hooks/"
    manifest_add ".claude/hooks/$(basename "$f")"
    baseline_record "$f" ".claude/hooks/$(basename "$f")"
  done
  # Copy shared hook library. Safety hooks fail closed without it,
  # so a silent miss would block every Edit/Bash. Hard-error instead of || true.
  if [ -d "$CLONE_DIR/.claude/hooks/lib" ]; then
    mkdir -p "$DEST/.claude/hooks/lib"
    cp "$CLONE_DIR/.claude/hooks/lib/"*.sh "$DEST/.claude/hooks/lib/" || error "Failed to copy hook library (.claude/hooks/lib/) — safety hooks would not run"
    manifest_add ".claude/hooks/lib"
    for f in "$CLONE_DIR/.claude/hooks/lib/"*.sh; do
      baseline_record "$f" ".claude/hooks/lib/$(basename "$f")"
    done
  fi
  chmod +x "$DEST/.claude/hooks/"*.sh 2>/dev/null || true
  note_added "$DEST/.claude/hooks"
  HOOK_COUNT=$(ls -1 "$DEST/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
  ok "Created .claude/hooks/ ($HOOK_COUNT hooks)"
elif [ "$UPGRADE" = true ]; then
  upgrade_dir "$CLONE_DIR/.claude/hooks" "$DEST/.claude/hooks" "*.sh" ".claude/hooks"
  # Also upgrade hook library (lib/ is not caught by *.sh glob)
  if [ -d "$CLONE_DIR/.claude/hooks/lib" ]; then
    mkdir -p "$DEST/.claude/hooks/lib"
    for lib_file in "$CLONE_DIR/.claude/hooks/lib/"*.sh; do
      [ -f "$lib_file" ] || continue
      upgrade_file "$lib_file" ".claude/hooks/lib/$(basename "$lib_file")"
    done
    manifest_add ".claude/hooks/lib"
  fi
  chmod +x "$DEST/.claude/hooks/"*.sh 2>/dev/null || true  # a broken link among them fails chmod
else
  for f in "$CLONE_DIR/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    install_file "$f" ".claude/hooks/$(basename "$f")"
  done
  # Safety hooks fail closed without their library, so it goes in too (F12).
  if [ -d "$CLONE_DIR/.claude/hooks/lib" ]; then
    install_tree "$CLONE_DIR/.claude/hooks/lib" ".claude/hooks/lib" ".claude/hooks/lib" always
  fi
fi

# Create project hooks overlay directory
if [ ! -d "$DEST/.claude/hooks/project" ]; then
  mkdir -p "$DEST/.claude/hooks/project"
  ok "Created .claude/hooks/project/ (project-specific hooks go here)"
fi

# --- Profile: standard and strict get agents and skills ---
if [ "$PROFILE" != "minimal" ]; then

  # Copy agents
  if [ ! -d "$DEST/.claude/agents" ]; then
    mkdir -p "$DEST/.claude/agents"
    for f in "$CLONE_DIR/.claude/agents/"*.md; do
      [ -f "$f" ] || continue
      cp "$f" "$DEST/.claude/agents/"
      manifest_add ".claude/agents/$(basename "$f")"
      baseline_record "$f" ".claude/agents/$(basename "$f")"
    done
    note_added "$DEST/.claude/agents"
    AGENT_COUNT=$(ls -1 "$DEST/.claude/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
    ok "Created .claude/agents/ ($AGENT_COUNT agents)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_dir "$CLONE_DIR/.claude/agents" "$DEST/.claude/agents" "*.md" ".claude/agents"
  else
    for f in "$CLONE_DIR/.claude/agents/"*.md; do
      [ -f "$f" ] || continue
      install_file "$f" ".claude/agents/$(basename "$f")"
    done
  fi

  # Copy skills
  if [ ! -d "$DEST/.claude/skills" ]; then
    mkdir -p "$DEST/.claude/skills"
    # Skip build-only assets (_shared/, _templates/) — end users don't run
    # build-skills.sh, and sync-manifest.sh excludes _* so shipping them would
    # also break the manifest --check.
    for f in "$CLONE_DIR/.claude/skills/"*; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in _*) continue ;; esac
      cp -r "$f" "$DEST/.claude/skills/"
    done
    note_added "$DEST/.claude/skills"
    SKILL_COUNT=$(find "$DEST/.claude/skills" -mindepth 1 -maxdepth 1 -type d ! -name "_*" 2>/dev/null | wc -l | tr -d ' ')
    ok "Created .claude/skills/ ($SKILL_COUNT skills)"
    # Track skill files in manifest + baseline
    for skill_dir in "$DEST/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      case "$local_name" in _*) continue ;; esac
      manifest_add ".claude/skills/$local_name"
      if [ -d "$CLONE_DIR/.claude/skills/$local_name" ]; then
        baseline_record_tree "$CLONE_DIR/.claude/skills/$local_name" ".claude/skills/$local_name"
      fi
    done
  elif [ "$UPGRADE" = true ]; then
    # Skills have subdirectories (references/, resources/) — upgrade every file
    for skill_dir in "$CLONE_DIR/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      case "$local_name" in _*) continue ;; esac
      manifest_add ".claude/skills/$local_name"
      upgrade_tree "$skill_dir" ".claude/skills/$local_name"
    done
  else
    for skill_dir in "$CLONE_DIR/.claude/skills/"*/; do
      [ -d "$skill_dir" ] || continue
      local_name=$(basename "$skill_dir")
      case "$local_name" in _*) continue ;; esac
      install_tree "$skill_dir" ".claude/skills/$local_name" ".claude/skills/$local_name"
    done
  fi

  # Community extensions slot — kit creates the directory + README only.
  # Anything users put under .claude/extensions/<name>/ survives kit upgrades.
  # See agent_docs/skills.md → Extending the Kit and ADR-015.
  if [ ! -d "$DEST/.claude/extensions" ]; then
    mkdir -p "$DEST/.claude/extensions"
    if [ -f "$CLONE_DIR/.claude/extensions/README.md" ]; then
      cp "$CLONE_DIR/.claude/extensions/README.md" "$DEST/.claude/extensions/README.md"
      note_added "$DEST/.claude/extensions/README.md"
      manifest_add ".claude/extensions/README.md"
      baseline_record "$CLONE_DIR/.claude/extensions/README.md" ".claude/extensions/README.md"
    fi
    ok "Created .claude/extensions/ (community extensions slot)"
  elif [ "$UPGRADE" = true ]; then
    # Refresh only the README; never touch user-installed extensions
    if [ -f "$CLONE_DIR/.claude/extensions/README.md" ]; then
      upgrade_file "$CLONE_DIR/.claude/extensions/README.md" ".claude/extensions/README.md"
      manifest_add ".claude/extensions/README.md"
    fi
  else
    [ -f "$CLONE_DIR/.claude/extensions/README.md" ] && install_file "$CLONE_DIR/.claude/extensions/README.md" ".claude/extensions/README.md"
  fi

fi

# Copy settings.json (hooks + permissions config)
if [ ! -f "$DEST/.claude/settings.json" ] || [ "$UPGRADE" = true ]; then
  manifest_add ".claude/settings.json"
else
  # Listed only when the kit wrote it; the project's own settings.json is not ours.
  case "$(ack_owner "$DEST" .claude/settings.json)" in
    kit|kit-edited) manifest_add ".claude/settings.json" ;;
    no-record) if prev_manifest_lists .claude/settings.json; then manifest_add ".claude/settings.json"; fi ;;
  esac
fi
if [ ! -f "$DEST/.claude/settings.json" ]; then
  if [ "$PROFILE" = "strict" ]; then
    cp "$CLONE_DIR/.claude/settings.strict.json" "$DEST/.claude/settings.json"
    baseline_record "$CLONE_DIR/.claude/settings.strict.json" ".claude/settings.json"
    ok "Created .claude/settings.json (strict — all hooks enabled)"
  else
    cp "$CLONE_DIR/.claude/settings.json" "$DEST/.claude/settings.json"
    baseline_record "$CLONE_DIR/.claude/settings.json" ".claude/settings.json"
    ok "Created .claude/settings.json (hooks + permissions config)"
  fi
  note_added "$DEST/.claude/settings.json"
elif [ "$UPGRADE" = true ]; then
  warn "Kept .claude/settings.json (not auto-merged — review new hooks manually)"
else
  warn "Skipped .claude/settings.json (already exists)"
fi

# Copy the MCP allowlist template (mcp-gate.sh is inert until the real file exists)
if [ -f "$CLONE_DIR/.claude/mcp-allowlist.txt.example" ]; then
  if [ "$UPGRADE" = true ]; then
    manifest_add ".claude/mcp-allowlist.txt.example"
    upgrade_file "$CLONE_DIR/.claude/mcp-allowlist.txt.example" ".claude/mcp-allowlist.txt.example"
  else
    install_file "$CLONE_DIR/.claude/mcp-allowlist.txt.example" ".claude/mcp-allowlist.txt.example"
  fi
fi

# Copy the project-commands template (quality-gate / ship use it when the real
# .claude/commands.json exists; absent → auto-detection, unchanged behavior)
if [ -f "$CLONE_DIR/.claude/commands.json.example" ]; then
  if [ "$UPGRADE" = true ]; then
    manifest_add ".claude/commands.json.example"
    upgrade_file "$CLONE_DIR/.claude/commands.json.example" ".claude/commands.json.example"
  else
    install_file "$CLONE_DIR/.claude/commands.json.example" ".claude/commands.json.example"
  fi
fi

# --- Knowledge wiki module (optional) ---
if [ "$WIKI" = true ] && [ "$PROFILE" != "minimal" ]; then
  # Copy WIKI.md schema
  manifest_add "WIKI.md"
  if [ ! -f "$DEST/WIKI.md" ]; then
    cp "$CLONE_DIR/WIKI.md" "$DEST/WIKI.md"
    note_added "$DEST/WIKI.md"
    baseline_record "$CLONE_DIR/WIKI.md" "WIKI.md"
    ok "Created WIKI.md (knowledge wiki schema)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_file "$CLONE_DIR/WIKI.md" "WIKI.md"
  else
    warn "Skipped WIKI.md (already exists)"
  fi

  # Scaffold vault directories
  if [ ! -d "$DEST/raw-sources" ]; then
    mkdir -p "$DEST/raw-sources"
    ok "Created raw-sources/ (drop articles, PDFs, transcripts here)"
  fi

  if [ ! -d "$DEST/wiki" ]; then
    mkdir -p "$DEST/wiki/summaries" "$DEST/wiki/entities" "$DEST/wiki/concepts"
    create_wiki_index "$DEST/wiki/index.md"
    create_wiki_log "$DEST/wiki/log.md"
    note_added "$DEST/wiki/index.md" "$DEST/wiki/log.md"
    ok "Created wiki/ (Claude-maintained knowledge base)"
  else
    # Ensure subdirectories exist
    mkdir -p "$DEST/wiki/summaries" "$DEST/wiki/entities" "$DEST/wiki/concepts"
    if [ ! -f "$DEST/wiki/index.md" ]; then
      create_wiki_index "$DEST/wiki/index.md"
      note_added "$DEST/wiki/index.md"
    fi
    if [ ! -f "$DEST/wiki/log.md" ]; then
      create_wiki_log "$DEST/wiki/log.md"
      note_added "$DEST/wiki/log.md"
    fi
  fi

  # Copy wiki skills
  for skill_dir in "$CLONE_DIR/wiki-module/.claude/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    local_name=$(basename "$skill_dir")
    manifest_add ".claude/skills/$local_name"
    if [ ! -d "$DEST/.claude/skills/$local_name" ]; then
      cp -r "$skill_dir" "$DEST/.claude/skills/$local_name"
      note_added "$DEST/.claude/skills/$local_name"
      baseline_record_tree "$skill_dir" ".claude/skills/$local_name"
    elif [ "$UPGRADE" = true ]; then
      upgrade_tree "$skill_dir" ".claude/skills/$local_name"
    fi
  done

  # Copy wiki agent
  for agent_file in "$CLONE_DIR/wiki-module/.claude/agents/"*.md; do
    [ -f "$agent_file" ] || continue
    local_name=$(basename "$agent_file")
    manifest_add ".claude/agents/$local_name"
    if [ ! -f "$DEST/.claude/agents/$local_name" ]; then
      cp "$agent_file" "$DEST/.claude/agents/$local_name"
      note_added "$DEST/.claude/agents/$local_name"
      baseline_record "$agent_file" ".claude/agents/$local_name"
    elif [ "$UPGRADE" = true ]; then
      upgrade_file "$agent_file" ".claude/agents/$local_name"
    fi
  done

  WIKI_SKILLS=$(ls -1d "$CLONE_DIR/wiki-module/.claude/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
  ok "Added wiki module ($WIKI_SKILLS skills, 1 agent)"
fi

# --- HTML artifacts module (optional) ---
if [ "$HTML" = true ] && [ "$PROFILE" != "minimal" ]; then
  # Copy ARTIFACTS.md schema
  manifest_add "ARTIFACTS.md"
  if [ ! -f "$DEST/ARTIFACTS.md" ]; then
    cp "$CLONE_DIR/ARTIFACTS.md" "$DEST/ARTIFACTS.md"
    note_added "$DEST/ARTIFACTS.md"
    baseline_record "$CLONE_DIR/ARTIFACTS.md" "ARTIFACTS.md"
    ok "Created ARTIFACTS.md (HTML artifact conventions)"
  elif [ "$UPGRADE" = true ]; then
    upgrade_file "$CLONE_DIR/ARTIFACTS.md" "ARTIFACTS.md"
  else
    warn "Skipped ARTIFACTS.md (already exists)"
  fi

  # Scaffold artifacts/ directory with design-system.html and index.html
  if [ ! -d "$DEST/artifacts" ]; then
    mkdir -p "$DEST/artifacts"
    cp "$CLONE_DIR/html-module/templates/design-system.html" "$DEST/artifacts/design-system.html"
    cp "$CLONE_DIR/html-module/templates/index.html" "$DEST/artifacts/index.html"
    note_added "$DEST/artifacts"
    ok "Created artifacts/ (design-system.html + index.html)"
  else
    # Add the reference files only if missing — never overwrite user-edited tokens
    for f in design-system.html index.html; do
      if [ ! -f "$DEST/artifacts/$f" ]; then
        cp "$CLONE_DIR/html-module/templates/$f" "$DEST/artifacts/$f"
        note_added "$DEST/artifacts/$f"
      fi
    done
  fi
fi

# Write manifest + baseline (the baseline is a kit file too — uninstall removes it)
manifest_add "$MANIFEST_FILE"
manifest_add "$BASELINE_FILE"
manifest_write "$DEST"
baseline_write

# --- Add kit files to .gitignore if requested ---
if [ "$GITIGNORE" = true ]; then
  GITIGNORE_FILE="$DEST/.gitignore"
  MARKER="# Agent Code Kit (local-only)"

  # Check if we already added kit entries
  if [ -f "$GITIGNORE_FILE" ] && grep -qF "$MARKER" "$GITIGNORE_FILE"; then
    warn ".gitignore already has Agent Code Kit entries — skipping"
  else
    {
      echo ""
      echo "$MARKER"
      [ "$VERSION_OURS" = true ] && echo "VERSION"
      echo ".kit-manifest"
      echo "CLAUDE.md"
      echo "CLAUDE.project.md"
      echo "CODEBASE_MAP.md"
      echo "agent_docs/"
      echo "tasks/"
      echo "scripts/"
      echo ".claude/"
      if [ "$WIKI" = true ]; then
        echo "WIKI.md"
        echo "raw-sources/"
        echo "wiki/"
      fi
      if [ "$HTML" = true ]; then
        echo "ARTIFACTS.md"
        echo "artifacts/"
      fi
    } >> "$GITIGNORE_FILE"
    ok "Added kit files to .gitignore (kit stays local, won't be pushed)"
  fi
fi

if [ "$UPGRADE" != true ] && [ "${#INIT_KEPT[@]}" -gt 0 ]; then
  echo ""
  info "Installed $INIT_INSTALLED file(s) · kept ${#INIT_KEPT[@]} existing (yours, not touched, not listed in the manifest):"
  for f in "${INIT_KEPT[@]}"; do
    echo "       - $f"
  done
fi

echo ""
if [ "$UPGRADE" = true ]; then
  echo "  Upgrade complete! (v${KIT_VERSION}, $PROFILE profile)"
  print_upgrade_summary
  echo ""
  echo "  Next steps:"
  if [ "${#CONFLICT_FILES[@]}" -gt 0 ]; then
    echo "  - Resolve the conflicts above (merge each <file>.kit-new, then delete it)"
  fi
  if [ "$ATTENTION_COUNT" -gt 0 ]; then
    echo "  - Handle the stale files / hook registrations listed above (--upgrade never edits .claude/settings.json)"
  fi
  echo "  - Start a Claude Code session"
elif [ "$PROFILE" = "minimal" ]; then
  echo "  Done! (v${KIT_VERSION}, $PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Review .claude/settings.json to enable/disable hooks"
  echo "  2. Start a Claude Code session"
else
  echo "  Done! (v${KIT_VERSION}, $PROFILE profile)"
  echo ""
  echo "  Next steps:"
  echo "  1. Fill in CODEBASE_MAP.md with your project details"
  echo "  2. Customize CLAUDE.project.md with project-specific rules"
  _own_validate=false
  for f in ${INIT_KEPT[@]+"${INIT_KEPT[@]}"}; do
    [ "$f" = "scripts/validate.sh" ] && _own_validate=true
  done
  if [ "$_own_validate" = false ]; then
    echo "  3. Run ./scripts/validate.sh to check for unfilled placeholders"
  else
    echo "  3. (skipped) ./scripts/validate.sh is yours, not the kit's"
  fi
  echo "  4. Review .claude/settings.json to enable/disable hooks"
  echo "  5. Start a Claude Code session"
  if [ "$WIKI" = true ]; then
    echo ""
    echo "  Wiki module:"
    echo "  - Add source files to raw-sources/ (articles, PDFs, transcripts)"
    echo "  - Run /wiki-ingest to process them into the wiki"
    echo "  - Run /wiki-briefing for a daily summary"
    echo "  - Run /wiki-lint for periodic health checks"
    echo "  - Open the project folder in your markdown editor to browse the wiki"
  fi
  if [ "$HTML" = true ]; then
    echo ""
    echo "  HTML artifacts module:"
    echo "  - Edit artifacts/design-system.html tokens to match your project's taste"
    echo "  - Ask Claude to produce specs, reports, PR writeups, or editors as HTML"
    echo "  - New artifacts land in artifacts/ and auto-link from artifacts/index.html"
    echo "  - Open artifacts/<file>.html in a browser to view, share via S3/CDN"
  fi
fi
echo ""
