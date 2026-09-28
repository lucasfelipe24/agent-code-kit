#!/usr/bin/env bash
#
# test-cli.sh — smoke test for bin/cli.sh, the npx entry point.
#
# test-install.sh exercises install.sh directly; this drives the CLI wrapper the
# way `npx @lucasfelipe23/agent-code-kit <cmd>` does, so every subcommand
# (init, doctor, skills, convert, generate agents-md, uninstall, --version) runs at least
# once and a broken subcommand fails the suite. CI runs it on ubuntu + macOS.
#
# Exit codes: 0 all assertions passed · 1 one or more failed
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$KIT_ROOT/bin/cli.sh"
FAILS=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILS=$((FAILS + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-cli-test.XXXXXX")"
STMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-cli-strict.XXXXXX")"
trap 'rm -rf "$TMP" "$STMP"' EXIT

# --- version (no install needed) --------------------------------------------
echo "== version =="
EXPECTED_VERSION="$(sed 's/ *#.*//' "$KIT_ROOT/VERSION" | tr -d '[:space:]')"
for flag in --version version -v; do
  got="$(bash "$CLI" "$flag" 2>/dev/null | tr -d '[:space:]')"
  [ "$got" = "$EXPECTED_VERSION" ] && pass "$flag -> $got" || fail "$flag -> '$got' (expected '$EXPECTED_VERSION')"
done

# --- help / unknown command --------------------------------------------------
echo "== help / unknown =="
CLI_HELP=$(bash "$CLI" --help 2>/dev/null || true)
grep -q "Usage:" <<< "$CLI_HELP" && pass "--help prints usage" || fail "--help missing usage"
if bash "$CLI" definitely-not-a-command >/dev/null 2>&1; then
  fail "unknown command exited 0"
else
  pass "unknown command exits non-zero"
fi

# --- subcommands that need an install must fail cleanly BEFORE init ----------
echo "== pre-install error paths =="
( cd "$TMP" && bash "$CLI" doctor >/dev/null 2>&1 ) && fail "doctor exited 0 with no install" || pass "doctor fails before init"
( cd "$TMP" && bash "$CLI" skills >/dev/null 2>&1 ) && fail "skills exited 0 with no install" || pass "skills fails before init"

# --- init (standard) — must match a direct install.sh run -------------------
echo "== init =="
echo '{"name":"cli-fixture","version":"1.0.0"}' > "$TMP/package.json"
if ( cd "$TMP" && bash "$CLI" init >"$TMP/.init.log" 2>&1 ); then
  pass "init ran clean"
else
  fail "init failed"; tail -8 "$TMP/.init.log"
fi
for f in CLAUDE.md .claude/settings.json .kit-manifest scripts/doctor.sh; do
  [ -e "$TMP/$f" ] && pass "init created $f" || fail "init missing $f"
done
[ -d "$TMP/.claude/skills" ] && pass "init created .claude/skills/" || fail "init missing skills dir"

# --- doctor (healthy install → exit 0) --------------------------------------
echo "== doctor =="
( cd "$TMP" && bash "$CLI" doctor >/dev/null 2>&1 ) && pass "doctor healthy after init" || fail "doctor failed on healthy install"

# --- skills (lists a count matching the installed skill dirs) ---------------
echo "== skills =="
skills_out="$( cd "$TMP" && bash "$CLI" skills 2>/dev/null )"
cli_count="$(printf '%s\n' "$skills_out" | grep -oE '[0-9]+ skills' | grep -oE '[0-9]+' | head -1)"
dir_count=0
for d in "$TMP/.claude/skills"/*/; do
  [ -d "$d" ] || continue
  case "$(basename "$d")" in _*) continue ;; esac
  [ -f "${d}SKILL.md" ] && dir_count=$((dir_count + 1))
done
if [ -n "$cli_count" ] && [ "$cli_count" -gt 0 ] && [ "$cli_count" = "$dir_count" ]; then
  pass "skills lists $cli_count (matches installed dirs)"
else
  fail "skills count '$cli_count' != installed dir count '$dir_count'"
fi

# --- generate agents-md → non-empty AGENTS.md -------------------------------
echo "== generate agents-md =="
( cd "$TMP" && bash "$CLI" generate agents-md >/dev/null 2>&1 ) && pass "generate agents-md ran" || fail "generate agents-md failed"
[ -s "$TMP/AGENTS.md" ] && pass "AGENTS.md is non-empty" || fail "AGENTS.md missing/empty"

# --- nested AGENTS.md: mirror module CLAUDE.md, never write into a nested checkout
# A Claude Code worktree (.claude/worktrees/<name>/, .git file), a submodule (.git
# file) and a nested clone (.git dir) are other checkouts with their own root
# CLAUDE.md — mirroring into them leaves a spurious AGENTS.md diff in each.
echo "== generate agents-md: nested checkouts skipped =="
mkdir -p "$TMP/src/api" "$TMP/.claude/worktrees/wt" "$TMP/libs/sub" "$TMP/vendor/lib/.git"
printf '# api rules\n' > "$TMP/src/api/CLAUDE.md"
printf 'gitdir: /elsewhere/.git/worktrees/wt\n' > "$TMP/.claude/worktrees/wt/.git"
printf 'gitdir: ../../.git/modules/sub\n' > "$TMP/libs/sub/.git"
for d in .claude/worktrees/wt libs/sub vendor/lib; do printf '# CLAUDE.md\n' > "$TMP/$d/CLAUDE.md"; done
( cd "$TMP" && bash "$CLI" generate agents-md >/dev/null 2>&1 ) && pass "generate agents-md ran with nested checkouts" || fail "generate agents-md failed with nested checkouts"
grep -q 'GENERATED from src/api/CLAUDE.md' "$TMP/src/api/AGENTS.md" 2>/dev/null \
  && pass "src/api/CLAUDE.md mirrored to src/api/AGENTS.md" || fail "src/api/AGENTS.md not generated"
[ ! -e "$TMP/.claude/worktrees/wt/AGENTS.md" ] && pass "no AGENTS.md written into .claude/worktrees/wt" || fail "AGENTS.md written into the .claude/worktrees/wt worktree"
[ ! -e "$TMP/libs/sub/AGENTS.md" ] && pass "no AGENTS.md written into a submodule (.git file)" || fail "AGENTS.md written into the libs/sub submodule"
[ ! -e "$TMP/vendor/lib/AGENTS.md" ] && pass "no AGENTS.md written into a nested clone (.git dir)" || fail "AGENTS.md written into the vendor/lib nested clone"
# Same tree, target passed as an absolute path with a trailing slash: GNU find
# joins it without doubling the slash, so every $DEST-relative trim must still hold.
rm -f "$TMP/AGENTS.md" "$TMP/src/api/AGENTS.md"
bash "$TMP/scripts/gen-agents-md.sh" "$TMP/" >/dev/null 2>&1 && pass "gen-agents-md.sh ran on a trailing-slash target" || fail "gen-agents-md.sh failed on a trailing-slash target"
root_agents_header="$(head -1 "$TMP/AGENTS.md" 2>/dev/null || true)"
grep -q '^<!-- GENERATED FILE' <<< "$root_agents_header" \
  && pass "trailing slash: root AGENTS.md is the generated one" || fail "trailing slash: root AGENTS.md is not the generated file (a CLAUDE.md copy?)"
grep -q 'GENERATED from src/api/CLAUDE.md' "$TMP/src/api/AGENTS.md" 2>/dev/null \
  && pass "trailing slash: src/api/CLAUDE.md mirrored to src/api/AGENTS.md" || fail "trailing slash: src/api/AGENTS.md missing or mislabelled"
for d in .claude/worktrees/wt libs/sub vendor/lib; do
  [ ! -e "$TMP/$d/AGENTS.md" ] && pass "trailing slash: no AGENTS.md written into $d" || fail "trailing slash: AGENTS.md written into $d"
done
rm -rf "$TMP/src" "$TMP/.claude/worktrees" "$TMP/libs" "$TMP/vendor"

# --- convert codex → AGENTS.md + .agents/skills/ ----------------------------
echo "== convert codex =="
( cd "$TMP" && bash "$CLI" convert codex >/dev/null 2>&1 ) && pass "convert codex ran" || fail "convert codex failed"
[ -s "$TMP/AGENTS.md" ] && pass "convert produced non-empty AGENTS.md" || fail "convert AGENTS.md missing/empty"
[ -d "$TMP/.agents/skills" ] && pass "convert produced .agents/skills/" || fail ".agents/skills/ missing"
# Prefix rename (ADR-029): a skill exported under the former marker is still the
# converter's to sweep, a user's own skill (no marker) is kept, and only the ACK
# marker is written. The former marker name is built at runtime (no residue).
OLD_MARKER=".$(printf '\143\143\153')-generated"
mkdir -p "$TMP/.agents/skills/retired-skill" "$TMP/.agents/skills/my-own-skill"
: > "$TMP/.agents/skills/retired-skill/$OLD_MARKER"
printf '# mine\n' > "$TMP/.agents/skills/my-own-skill/SKILL.md"
( cd "$TMP" && bash "$CLI" convert codex >/dev/null 2>&1 ) && pass "convert codex re-ran over a former-marker export" || fail "convert codex failed on re-run"
[ ! -e "$TMP/.agents/skills/retired-skill" ] && pass "convert swept a skill exported under the former marker" || fail "convert kept a stale former-marker export"
[ -f "$TMP/.agents/skills/my-own-skill/SKILL.md" ] && pass "convert kept the user's own unmarked skill" || fail "convert removed a user-authored skill"
LEFT_MARKERS=$(find "$TMP/.agents/skills" -name "$OLD_MARKER" 2>/dev/null)
[ -z "$LEFT_MARKERS" ] && pass "no former marker remains under .agents/skills" || fail "a former marker survived the conversion"
[ -f "$TMP/.agents/skills/debug/.ack-generated" ] && pass "exported skills carry the .ack-generated marker" || fail "exported skill lacks .ack-generated"
rm -rf "$TMP/.agents/skills/my-own-skill"

# --- uninstall: --dry-run changes nothing; --force removes the kit only ------
echo "== uninstall =="
( cd "$TMP" && bash "$CLI" uninstall --dry-run >/dev/null 2>&1 ) && pass "uninstall --dry-run ran" || fail "uninstall --dry-run failed"
[ -e "$TMP/CLAUDE.md" ] && pass "--dry-run left CLAUDE.md in place" || fail "--dry-run removed CLAUDE.md"
if ( cd "$TMP" && bash "$CLI" uninstall --force >"$TMP/.uninstall.log" 2>&1 ); then
  pass "uninstall --force ran clean"
else
  fail "uninstall --force failed"; tail -8 "$TMP/.uninstall.log"
fi
for f in CLAUDE.md .claude/settings.json .kit-manifest scripts/doctor.sh; do
  [ ! -e "$TMP/$f" ] && pass "uninstall removed $f" || fail "uninstall left $f"
done
[ -f "$TMP/package.json" ] && pass "uninstall kept the project's package.json" || fail "uninstall removed package.json"

# --- flag pass-through: init --profile strict reaches install.sh ------------
echo "== init --profile strict (flag pass-through) =="
echo '{"name":"cli-strict","version":"1.0.0"}' > "$STMP/package.json"
if ( cd "$STMP" && bash "$CLI" init --profile strict >"$STMP/.init.log" 2>&1 ); then
  pass "init --profile strict ran clean"
else
  fail "init --profile strict failed"; tail -8 "$STMP/.init.log"
fi
grep -q skill-extract-reminder.sh "$STMP/.claude/settings.json" 2>/dev/null \
  && pass "strict flag reached install.sh (strict-only hook present)" \
  || fail "strict flag not honored via CLI"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "cli-test: ALL PASS"
else
  echo "cli-test: $FAILS FAIL"
  exit 1
fi
