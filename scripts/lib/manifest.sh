#!/usr/bin/env bash
#
# manifest.sh — shared manifest primitives for Agent Code Kit.
#
# `.kit-manifest` is the record of which files the kit ships into a user's
# project. This library is the single home for the read/write/enumerate logic
# that used to be reimplemented across install.sh, scripts/sync-manifest.sh, and
# uninstall.sh.
#
# Consumers:
#   - scripts/sync-manifest.sh  — sources this to enumerate + write the repo copy
#   - install.sh                — sources this (from the cloned/--local source,
#                                 after the source tree is available) to write
#                                 the per-project manifest
#   - uninstall.sh              — does NOT source this: it runs standalone via
#                                 `curl … | bash` with no library beside it, so
#                                 it reads the `.kit-manifest` *artifact* this
#                                 code produces (the same single source) with a
#                                 trivial inline read.
#
# Source it, then call the functions:  . "<dir>/scripts/lib/manifest.sh"
#

# Guard against double-sourcing (install.sh also defines MANIFEST_FILE).
if [ -n "${_ACK_MANIFEST_LIB_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi
_ACK_MANIFEST_LIB_LOADED=1

MANIFEST_FILE=".kit-manifest"

# KIT_USER_SCRIPTS — the scripts/*.sh files install.sh ships into a project.
# Everything else under scripts/ is kit-maintainer tooling (tests, CI drift
# checks, generators) that only runs inside this repo: it reads bench/,
# scaffold/, package.json, .claude/skills/_templates/, ../web or this library,
# none of which a project gets. package.json `files` lists the same set for the
# npm tarball; scripts/test-install.sh fails if the two drift.
KIT_USER_SCRIPTS="convert.sh doctor.sh gen-agents-md.sh lesson-graph.sh lesson-resurface.sh migrate-lessons.sh note.sh statusline.sh validate-skills.sh validate.sh"

# manifest_write <dest_dir> — write the entries in the MANIFEST_ENTRIES array to
# <dest_dir>/.kit-manifest, sorted and de-duplicated. No-op if the array is empty.
# Writes atomically (temp + mv). LC_ALL=C makes collation byte-deterministic
# across macOS (BSD) and Linux.
manifest_write() {
  local dest="$1"
  [ "${#MANIFEST_ENTRIES[@]}" -gt 0 ] || return 0
  local tmp
  tmp=$(mktemp "$dest/.kit-manifest.XXXXXX" 2>/dev/null) || tmp=$(mktemp)
  printf '%s\n' "${MANIFEST_ENTRIES[@]}" | LC_ALL=C sort -u > "$tmp"
  mv "$tmp" "$dest/$MANIFEST_FILE"
}

# manifest_read <manifest_path> — emit the manifest's entries, one per line,
# skipping blank lines. Used to drive manifest-based operations.
manifest_read() {
  local path="$1"
  [ -f "$path" ] || return 0
  grep -v '^[[:space:]]*$' "$path" || true
}

# kit_manifest_entries — emit the exact set of paths install.sh ships under the
# default (standard) profile, relative to the current directory (caller cd's to
# the kit root first). Order doesn't matter — callers sort. Same inclusion rule
# as install.sh's unconditional manifest_add calls: conditional payloads
# (WIKI.md, ARTIFACTS.md, DESIGN.md, harness docs, extensions/README.md) are
# excluded so the manifest reflects the default install.
kit_manifest_entries() {
  local entries=() f d base s

  # --- Top-level files (always shipped) ---------------------------------
  local top
  for top in CLAUDE.md CODEBASE_MAP.md VERSION .kit-manifest; do
    [ -f "$top" ] && entries+=("$top")
  done

  # --- agent_docs/ (.md files, exclude project overlay folder) ----------
  if [ -d agent_docs ]; then
    for f in agent_docs/*.md; do
      [ -f "$f" ] && entries+=("$f")
    done
  fi

  # --- scripts/ (the user-facing set only — see KIT_USER_SCRIPTS) --------
  for s in $KIT_USER_SCRIPTS; do
    [ -f "scripts/$s" ] && entries+=("scripts/$s")
  done

  # --- tasks/ — only the default top-level files (lessons/specs are dynamic)
  if [ -d tasks ]; then
    for f in tasks/decisions.md tasks/handoff.md tasks/todo.md; do
      [ -f "$f" ] && entries+=("$f")
    done
    # Lessons template + index ship; per-day lesson files are user-owned.
    if [ -d tasks/lessons ]; then
      for f in tasks/lessons/_TEMPLATE.md tasks/lessons/_index.md; do
        [ -f "$f" ] && entries+=("$f")
      done
    fi
  fi

  # --- .claude/agents/ --------------------------------------------------
  if [ -d .claude/agents ]; then
    for f in .claude/agents/*.md; do
      [ -f "$f" ] && entries+=("$f")
    done
  fi

  # --- .claude/hooks/ (all *.sh + lib dir) ------------------------------
  if [ -d .claude/hooks ]; then
    for f in .claude/hooks/*.sh; do
      [ -f "$f" ] && entries+=("$f")
    done
    [ -d .claude/hooks/lib ] && entries+=(".claude/hooks/lib")
  fi

  # --- .claude/settings.json --------------------------------------------
  [ -f .claude/settings.json ] && entries+=(".claude/settings.json")

  # --- .claude/skills/ (each skill dir, exclude _shared/_templates) -----
  if [ -d .claude/skills ]; then
    for d in .claude/skills/*/; do
      [ -d "$d" ] || continue
      base=$(basename "$d")
      case "$base" in
        _*) continue ;;
      esac
      entries+=(".claude/skills/$base")
    done
  fi

  [ "${#entries[@]}" -gt 0 ] && printf '%s\n' "${entries[@]}"
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
