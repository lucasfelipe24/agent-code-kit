#!/usr/bin/env bash
#
# check-prefix-residue.sh — fail when the kit's former configuration prefix
# appears in any tracked file's path or content (ADR-029). Every kit variable,
# temp file and marker is ACK_ / ack- now; the only code that still recognises
# the former prefix (doctor's migration, the gate-marker and export-marker
# carry-over, the upgrade notice) builds it from character codes, so this check
# needs no allowlist — and doesn't match itself.
#
# Untracked files are out of scope by design. Run by sync-manifest.sh --check,
# which CI's Manifest Sync job and `npm run check` both call.
#
# Exit codes: 0 clean · 1 residue found · 2 self-test failed (the check itself
# would miss residue)
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT" || exit 2

needle=$(printf '\143\143\153')   # matched case-insensitively

# Self-test: mixed-case forms of both the variable and the file prefix must hit.
for probe in "x$(printf '\103\103\113')_TIMEOUT" "/tmp/$(printf '\143\103\153')-gate-1"; do
  if ! grep -qiF -e "$needle" <<< "$probe"; then
    echo "check-prefix-residue: self-test failed — the pattern misses a known form" >&2
    exit 2
  fi
done

content=$(git grep -n -I -i -F -e "$needle" -- . 2>/dev/null || true)
paths=$(git ls-files | grep -i -F -e "$needle" || true)

if [ -n "$content$paths" ]; then
  echo "The kit's former configuration prefix is back in tracked files (ADR-029):" >&2
  [ -n "$paths" ] && printf '%s\n' "$paths" | sed 's/^/  path: /' >&2
  [ -n "$content" ] && printf '%s\n' "$content" | sed 's/^/  /' >&2
  echo "Use ACK_ / ack- names. Code that must recognise the former prefix builds it from character codes." >&2
  exit 1
fi
echo "No former-prefix residue in tracked paths or content."
exit 0
