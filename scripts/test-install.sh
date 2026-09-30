#!/usr/bin/env bash
#
# test-install.sh — smoke test for install.sh / uninstall.sh on a throwaway project.
#
# Exercises the code path that actually mutates a user's filesystem — fresh
# install, --upgrade idempotency, and clean uninstall — and asserts the
# results. The hooks have KitBench; this gives the installer the same kind of
# contract. CI runs it on ubuntu + macOS; runs locally too.
#
# Exit codes: 0 all assertions passed · 1 one or more failed
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILS=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILS=$((FAILS + 1)); }
rel() { local p="${1#"$TMP"/}"; echo "${p#"${STMP:-}"/}"; }
assert_file()   { [ -f "$1" ] && pass "exists: $(rel "$1")"     || fail "missing file: $(rel "$1")"; }
assert_dir()    { [ -d "$1" ] && pass "exists: $(rel "$1")/"    || fail "missing dir: $(rel "$1")"; }
assert_absent() { [ ! -e "$1" ] && pass "absent: $(rel "$1")"   || fail "should be absent: $(rel "$1")"; }
# Validate JSON with whatever the box has — same fallback order as doctor.sh.
json_valid() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$1" 2>/dev/null
  else
    return 0  # no validator available — treat as valid rather than fail the suite
  fi
}
# Same hash tool order as install.sh's file_hash.
hash_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
  fi
}
# set_baseline <project> <rel> <hash> — pretend the kit last installed <hash> at <rel>.
set_baseline() {
  awk -F'\t' -v OFS='\t' -v p="$2" -v h="$3" '$2 == p { $1 = h } { print }' "$1/.kit-baseline" > "$1/.kit-baseline.tmp" \
    && mv "$1/.kit-baseline.tmp" "$1/.kit-baseline"
}
# upgrade_summary <log> — the "Upgrade summary:" line with colors stripped.
upgrade_summary() {
  sed "s/$(printf '\033')\[[0-9;]*m//g" "$1" | grep 'Upgrade summary' || true
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-install-test.XXXXXX")"
STMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-strict-test.XXXXXX")"
GTMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-generic-test.XXXXXX")"
DTMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-dotnet-test.XXXXXX")"
XTMP="$(mktemp -d "${TMPDIR:-/tmp}/ack-safety-test.XXXXXX")"
trap 'rm -rf "$TMP" "$STMP" "$GTMP" "$DTMP" "$XTMP"' EXIT
# Make it look like a Node project so a template auto-detects (node-api),
# and so we can assert the user's own files survive uninstall.
echo '{"name":"fixture","version":"1.0.0"}' > "$TMP/package.json"

echo "== fresh install =="
if ! ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$TMP/.install.log" 2>&1 ); then
  echo "install.sh failed:"; cat "$TMP/.install.log"; exit 1
fi
assert_file "$TMP/CLAUDE.md"
assert_file "$TMP/CODEBASE_MAP.md"
assert_file "$TMP/.claude/settings.json"
assert_file "$TMP/.kit-manifest"
HOOKS=$(find "$TMP/.claude/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
[ "$HOOKS" -ge 18 ] && pass "hooks installed ($HOOKS)" || fail "too few hooks ($HOOKS, expected >=18)"
assert_dir "$TMP/.claude/skills"
# Regression: build-only assets must NOT ship to user projects
assert_absent "$TMP/.claude/skills/_shared"
assert_absent "$TMP/.claude/skills/_templates"

echo "== scripts (user-facing only) =="
# Kit-maintainer scripts used to ship too. In a project, sync-manifest.sh then
# sourced a scripts/lib/ that never ships, failed, and still exited 0.
. "$KIT_ROOT/scripts/lib/manifest.sh"
WANT_SCRIPTS=$(printf '%s\n' $KIT_USER_SCRIPTS | LC_ALL=C sort)
GOT_SCRIPTS=$(cd "$TMP/scripts" && ls -1 *.sh | LC_ALL=C sort)
[ "$GOT_SCRIPTS" = "$WANT_SCRIPTS" ] && pass "scripts/ holds exactly KIT_USER_SCRIPTS" || fail "scripts/ is not KIT_USER_SCRIPTS: $(echo $GOT_SCRIPTS)"
GOT_MANIFEST=$(grep '^scripts/' "$TMP/.kit-manifest" | sed 's#^scripts/##' | LC_ALL=C sort)
[ "$GOT_MANIFEST" = "$WANT_SCRIPTS" ] && pass ".kit-manifest lists the same scripts" || fail ".kit-manifest scripts differ: $(echo $GOT_MANIFEST)"
for s in build-skills.sh run-bench.sh sync-manifest.sh test-install.sh; do
  assert_absent "$TMP/scripts/$s"
done
# npx installs copy from the npm tarball, so `files` must carry the same set.
GOT_PACKAGE=$(grep -oE '"scripts/[a-z-]+\.sh"' "$KIT_ROOT/package.json" | tr -d '"' | sed 's#^scripts/##' | LC_ALL=C sort)
[ "$GOT_PACKAGE" = "$WANT_SCRIPTS" ] && pass "package.json files ships the same scripts" || fail "package.json files scripts differ: $(echo $GOT_PACKAGE)"
LONE="$TMP/.lone"
mkdir -p "$LONE/scripts" && cp "$KIT_ROOT/scripts/sync-manifest.sh" "$LONE/scripts/"
if bash "$LONE/scripts/sync-manifest.sh" --check >/dev/null 2>&1; then
  fail "sync-manifest.sh --check exits 0 without scripts/lib/manifest.sh"
else
  pass "sync-manifest.sh fails loudly without its library"
fi
rm -rf "$LONE"

echo "== task scaffold (no kit-internal state) =="
# The kit dogfoods itself, so its own tasks/ carries a live board, 15 ADRs, real
# lessons and a spike spec. A fresh project must get scaffold/tasks/, not that.
assert_file "$TMP/tasks/todo.md"
assert_file "$TMP/tasks/decisions.md"
assert_file "$TMP/tasks/handoff.md"
assert_file "$TMP/tasks/lessons/_index.md"
assert_file "$TMP/tasks/lessons/_TEMPLATE.md"
assert_absent "$TMP/tasks/specs"
LESSONS=$(find "$TMP/tasks/lessons" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
[ "$LESSONS" -eq 3 ] && pass "lessons scaffold is 3 files" || fail "expected 3 scaffold lessons, got $LESSONS"
LEAK=$(grep -rlE 'CLA-[0-9]|TAN-[0-9]|release-please cut' "$TMP/tasks" 2>/dev/null || true)
[ -z "$LEAK" ] && pass "no kit-internal state in tasks/" || fail "kit-internal state leaked into tasks/: $LEAK"
ADRS=$(grep -cE '^### ADR-[0-9]' "$TMP/tasks/decisions.md" || true)
[ "$ADRS" -eq 1 ] && pass "decisions.md ships only the ADR-001 example" || fail "decisions.md carries $ADRS ADRs (expected the 1 example)"

echo "== package contents (files field) =="
# package.json `files` supersedes .npmignore, so a wholesale ".claude/" entry
# silently shipped the maintainer's settings.local.json to every npm user.
if command -v npm >/dev/null 2>&1; then
  PACK=$(cd "$KIT_ROOT" && npm pack --dry-run 2>&1)
  if [[ "$PACK" == *"settings.local.json"* ]]; then
    fail "npm tarball would ship .claude/settings.local.json"
  else
    pass "npm tarball excludes settings.local.json"
  fi
  if [[ "$PACK" == *" tasks/"* ]]; then
    fail "npm tarball would ship the kit's own tasks/"
  else
    pass "npm tarball ships scaffold/tasks/, not the kit's own tasks/"
  fi
else
  pass "npm unavailable — package-contents check skipped"
fi

echo "== generic template (no stack detected) =="
# GTMP has no package.json/go.mod/Cargo.toml, so auto-detection finds nothing and
# install falls back to the generic map. That fallback used to be this repo's own
# CODEBASE_MAP.md, which describes AgentCodeKit — the first file CLAUDE.md tells
# the agent to read for orientation.
# GTMP also has a scripts/ of its own, which takes the "Skipped scripts/" path —
# that used to record every *.sh in it as a kit file. Its test-install.sh shares
# a kit-maintainer script's name but was never the kit's — no leftover warning.
mkdir -p "$GTMP/scripts" && echo 'echo deploy' > "$GTMP/scripts/deploy.sh"
echo 'echo own tests' > "$GTMP/scripts/test-install.sh"
if ( cd "$GTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$GTMP/.install.log" 2>&1 ); then
  pass "generic install ran clean"
else
  fail "generic install failed"; tail -8 "$GTMP/.install.log"
fi
if cmp -s "$GTMP/CODEBASE_MAP.md" "$KIT_ROOT/CODEBASE_MAP.md"; then
  fail "generic install shipped this repo's own CODEBASE_MAP.md"
else
  pass "generic install ships a blank map, not this repo's own"
fi
KITREF=$(grep -c 'AgentCodeKit' "$GTMP/CODEBASE_MAP.md" || true)
[ "${KITREF:-0}" = "0" ] && pass "installed map does not mention AgentCodeKit" || fail "installed map mentions AgentCodeKit ${KITREF}×"
if grep -qxF 'scripts/deploy.sh' "$GTMP/.kit-manifest"; then
  fail "the project's own scripts/deploy.sh was recorded as a kit file"
else
  pass "the project's own scripts stay out of .kit-manifest"
fi
GENERIC_LOG=$(cat "$GTMP/.install.log")
[[ "$GENERIC_LOG" != *"No longer shipped"* ]] && pass "first install doesn't call the project's own test-install.sh a leftover" || fail "first install reported the project's own test-install.sh as a kit leftover"

echo "== upgrade: install from before .kit-baseline, stack added since =="
# Without a baseline a local edit can't be told from an older kit file: changed
# files are replaced and the previous copies backed up. CLAUDE.md must stay on the
# template it came from even though a package.json now auto-detects as node-api.
rm -f "$GTMP/.kit-baseline"
echo '{"name":"late-node","version":"1.0.0"}' > "$GTMP/package.json"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$GTMP/.claude/hooks/secret-scan.sh"
if ( cd "$GTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$GTMP/.upgrade.log" 2>&1 ); then
  pass "upgrade of a pre-baseline install ran clean"
else
  fail "upgrade of a pre-baseline install failed"; tail -8 "$GTMP/.upgrade.log"
fi
cmp -s "$KIT_ROOT/.claude/hooks/secret-scan.sh" "$GTMP/.claude/hooks/secret-scan.sh" \
  && pass "stale hook updated" || fail "stale hook left in place: .claude/hooks/secret-scan.sh"
BACKUP=$(find "$GTMP/.kit-backup" -type f -name secret-scan.sh 2>/dev/null | head -n 1)
if [ -n "$BACKUP" ] && grep -q 'an older kit version' "$BACKUP"; then
  pass "previous copy kept in .kit-backup/"
else
  fail "no backup of the replaced hook under .kit-backup/"
fi
cmp -s "$KIT_ROOT/CLAUDE.md" "$GTMP/CLAUDE.md" \
  && pass "CLAUDE.md stays on the generic template" || fail "upgrade swapped CLAUDE.md for another template"
grep -q "^#template	generic$" "$GTMP/.kit-baseline" 2>/dev/null \
  && pass "baseline written, template recorded" || fail ".kit-baseline missing or template not recorded"

echo "== .NET template auto-detection =="
echo 'Microsoft Visual Studio Solution File, Format Version 12.00' > "$DTMP/App.sln"
if ( cd "$DTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$DTMP/.install.log" 2>&1 ); then
  pass "install into a .sln project ran clean"
else
  fail "install into a .sln project failed"; tail -8 "$DTMP/.install.log"
fi
cmp -s "$KIT_ROOT/examples/dotnet/CLAUDE.md" "$DTMP/CLAUDE.md" \
  && pass "a .sln project gets the dotnet template" || fail "a .sln project did not get the dotnet template"

echo "== doctor =="
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor.log" 2>&1 ); then
  pass "doctor reports healthy"
else
  fail "doctor reported a failure"; tail -8 "$TMP/.doctor.log"
fi
# A mistyped commands.json key is a config error the gate blocks on — doctor must
# fail on it too, naming the key, and pass once the file is valid.
printf '{"typcheck": "true"}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor2.log" 2>&1 ); then
  fail "doctor passed a commands.json with an unknown key"
elif grep -q 'unknown key "typcheck"' "$TMP/.doctor2.log"; then
  pass "doctor fails on a mistyped commands.json key, naming it"
else
  fail "doctor failed without naming the unknown key"; tail -5 "$TMP/.doctor2.log"
fi
printf '{"lint": "true", "timeout": 60}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor3.log" 2>&1 ); then
  pass "doctor passes a valid commands.json"
else
  fail "doctor failed on a valid commands.json"; tail -5 "$TMP/.doctor3.log"
fi
# A UTF-8 BOM (some editors add one) still makes a valid file; a non-finite
# timeout does not — the gate would silently fall back to 30s.
printf '\357\273\277{"lint": "true"}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor5.log" 2>&1 ); then
  pass "doctor passes a commands.json saved with a UTF-8 BOM"
else
  fail "doctor failed on a commands.json saved with a UTF-8 BOM"; tail -5 "$TMP/.doctor5.log"
fi
printf '{"lint": "true", "timeout": Infinity}\n' > "$TMP/.claude/commands.json"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor6.log" 2>&1 ); then
  fail "doctor passed a commands.json with an infinite timeout"
elif grep -q '"timeout" must be a positive number' "$TMP/.doctor6.log"; then
  pass "doctor fails on a non-finite commands.json timeout, naming it"
else
  fail "doctor failed without naming the timeout"; tail -5 "$TMP/.doctor6.log"
fi
rm -f "$TMP/.claude/commands.json"
# Doctor checks behavior, not just files: the fresh install's run drove
# the installed hooks through block → compaction → fix → worktree isolation.
for check in "Broken code is caught and blocks completion" "The failing verdict survives a compaction" \
             "Fixing the code lifts the block" \
             "A git worktree's result is stored in that worktree and still blocks the session's stop"; do
  grep -qF "$check" "$TMP/.doctor.log" && pass "doctor self-test: $check" || fail "doctor self-test missing: $check"
done
# A stop-gate that never blocks must fail doctor, even though every file exists.
cp "$TMP/.claude/hooks/stop-gate.sh" "$TMP/.stop-gate.bak"
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$TMP/.claude/hooks/stop-gate.sh"
if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor4.log" 2>&1 ); then
  fail "doctor passed with a stop-gate that never blocks"
elif grep -q 'Broken code was not blocked' "$TMP/.doctor4.log"; then
  pass "doctor fails an install whose stop-gate never blocks"
else
  fail "doctor failed, but not on the broken stop-gate"; tail -5 "$TMP/.doctor4.log"
fi
cp "$TMP/.stop-gate.bak" "$TMP/.claude/hooks/stop-gate.sh"
# The behavior checks drive the hook scripts directly, so doctor must also read how
# settings.json wires them — an unwired or bypassed gate used to read healthy.
if command -v python3 >/dev/null 2>&1; then
  grep -qF "stop-gate.sh runs on Stop" "$TMP/.doctor.log" && grep -qF "quality-gate.sh runs after Edit and Write" "$TMP/.doctor.log" \
    && pass "doctor confirms both gates are wired" || fail "doctor did not report the gates' wiring"
  cp "$TMP/.claude/settings.json" "$TMP/.settings.bak"
  settings_edit() {  # <python statement on d (settings) and h (its hooks)>
    python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); h=d.setdefault("hooks",{}); exec(sys.argv[2]); json.dump(d,open(p,"w"),indent=2)' \
      "$TMP/.claude/settings.json" "$1"
  }
  doctor_expect_fail() {  # <log> <expected text> <label>
    if ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/$1" 2>&1 ); then
      fail "doctor passed: $3"
    elif grep -qF "$2" "$TMP/$1"; then
      pass "doctor fails: $3"
    else
      fail "doctor failed, but not on: $3"; tail -5 "$TMP/$1"
    fi
    cp "$TMP/.settings.bak" "$TMP/.claude/settings.json"
  }
  settings_edit 'h["SessionEnd"] = h.get("SessionEnd", []) + h.pop("Stop", [])'
  doctor_expect_fail .doctor5.log "stop-gate.sh is not registered under Stop" "stop-gate wired to SessionEnd instead of Stop"
  settings_edit 'h["PostToolUse"] = [e for e in h.get("PostToolUse", []) if "quality-gate.sh" not in json.dumps(e)]'
  doctor_expect_fail .doctor6.log "quality-gate.sh is not registered under PostToolUse" "quality-gate removed from PostToolUse"
  settings_edit 'd.setdefault("env", {})["SKIP_QUALITY_GATE"] = "1"'
  ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor7.log" 2>&1 ) || true
  grep -qF "The quality gate is bypassed in .claude/settings" "$TMP/.doctor7.log" \
    && pass "doctor warns when settings.json bypasses the gate" || fail "doctor did not warn about the settings.json bypass"
  cp "$TMP/.settings.bak" "$TMP/.claude/settings.json"
  # Prefix rename (ADR-029): doctor renames former-prefix env keys in both
  # settings files to ACK_* — values kept, an ACK_ key already set wins, a backup
  # first, no value ever printed — and names exported former-prefix variables by
  # their ACK_ target only. The former prefix is built at runtime (no residue).
  L=$(printf '\103\103\113_')
  settings_edit "d.setdefault('env', {}).update({'${L}PROTECT_BUILD_CONFIGS': '1', '${L}NOTIFY_NTFY_URL': 'https://ntfy.sh/topic-sentinel-7f3', 'ACK_QUALITY_GATE_TIMEOUT': '45', '${L}QUALITY_GATE_TIMEOUT': '99'})"
  printf '{"env":{"%sNOTIFY_PUSHOVER_TOKEN":"token-sentinel-9d2"}}\n' "$L" > "$TMP/.claude/settings.local.json"
  ( cd "$TMP" && env "${L}STOP_REVERIFY_BUDGET=77" bash ./scripts/doctor.sh >"$TMP/.doctor10.log" 2>&1 ) || true
  if python3 - "$TMP" "$L" <<'PY'
import json, sys
root, old = sys.argv[1], sys.argv[2]
s = json.load(open(root + "/.claude/settings.json"))["env"]
l = json.load(open(root + "/.claude/settings.local.json"))["env"]
ok = (s.get("ACK_PROTECT_BUILD_CONFIGS") == "1"
      and s.get("ACK_NOTIFY_NTFY_URL") == "https://ntfy.sh/topic-sentinel-7f3"
      and s.get("ACK_QUALITY_GATE_TIMEOUT") == "45"
      and l.get("ACK_NOTIFY_PUSHOVER_TOKEN") == "token-sentinel-9d2"
      and not any(k.startswith(old) for k in list(s) + list(l)))
sys.exit(0 if ok else 1)
PY
  then
    pass "doctor renamed former-prefix keys in settings.json and settings.local.json, values kept, ACK_ wins a conflict"
  else
    fail "doctor did not migrate the former-prefix settings keys correctly"
  fi
  grep -qF ".claude/settings.json: renamed 2 key(s) to ACK_* (1 superseded" "$TMP/.doctor10.log" \
    && grep -qF ".claude/settings.local.json: renamed 1 key(s) to ACK_*" "$TMP/.doctor10.log" \
    && pass "doctor reports each migrated file with counts" || fail "doctor's migration report is missing"
  ls "$TMP/.hook-state/"settings.json.*.bak >/dev/null 2>&1 && ls "$TMP/.hook-state/"settings.local.json.*.bak >/dev/null 2>&1 \
    && grep -qF "${L}NOTIFY_NTFY_URL" "$TMP/.hook-state/"settings.json.*.bak \
    && pass "doctor backed up both settings files into .hook-state/ before rewriting" || fail "doctor wrote no backup of the original settings"
  if grep -qF -e "topic-sentinel-7f3" -e "token-sentinel-9d2" -e "$L" "$TMP/.doctor10.log"; then
    fail "doctor output leaked a setting value or the former prefix"
  else
    pass "doctor output shows no setting value and no former-prefix name"
  fi
  grep -qF "rename them to: ACK_STOP_REVERIFY_BUDGET" "$TMP/.doctor10.log" \
    && pass "doctor names an exported former-prefix variable by its ACK_ target" || fail "doctor did not report the exported former-prefix variable"
  ( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor11.log" 2>&1 ) || true
  grep -qF "key(s) to ACK_*" "$TMP/.doctor11.log" \
    && fail "a second doctor run migrated again" || pass "a second doctor run finds nothing to migrate"
  cp "$TMP/.settings.bak" "$TMP/.claude/settings.json"; rm -f "$TMP/.settings.bak" "$TMP/.claude/settings.local.json"
fi
# Brackets in code are INI sections or indexing, not placeholders; a template's
# [does X for Y] in prose still is one.
cp "$TMP/CODEBASE_MAP.md" "$TMP/.map.bak"
printf '# Map\n\nSettings live in the `[Config]` and `[Cache]` sections of app.ini.\n\n```ini\n[Config]\nkey = value\n```\n' > "$TMP/CODEBASE_MAP.md"
( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor8.log" 2>&1 ) || true
grep -qF "CODEBASE_MAP.md appears filled in" "$TMP/.doctor8.log" \
  && pass "doctor ignores brackets inside code in CODEBASE_MAP.md" || fail "doctor counted brackets inside code as placeholders"
printf 'A .NET [web API / web app] that [does X for Y].\n' >> "$TMP/CODEBASE_MAP.md"
( cd "$TMP" && bash ./scripts/doctor.sh >"$TMP/.doctor9.log" 2>&1 ) || true
grep -qF "CODEBASE_MAP.md has ~1 unfilled placeholder(s)" "$TMP/.doctor9.log" \
  && pass "doctor still flags a placeholder in prose" || fail "doctor missed a placeholder in prose"
cp "$TMP/.map.bak" "$TMP/CODEBASE_MAP.md"; rm -f "$TMP/.map.bak"

echo "== upgrade (idempotent) =="
# Plant a kit-maintainer script the way an earlier install left it (file +
# manifest entry): upgrade must report it, keep it, and drop it from the manifest.
cp "$KIT_ROOT/scripts/run-bench.sh" "$TMP/scripts/"
echo "scripts/run-bench.sh" >> "$TMP/.kit-manifest"
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade.log" 2>&1 ); then
  pass "upgrade ran clean"
else
  fail "upgrade failed"; tail -8 "$TMP/.upgrade.log"
fi
assert_file "$TMP/CLAUDE.md"
assert_file "$TMP/.kit-baseline"
SUMMARY=$(upgrade_summary "$TMP/.upgrade.log")
[[ "$SUMMARY" == *" 0 updated · 0 added · "*" · 0 kept (local edits) · 0 conflicts"* ]] \
  && pass "re-upgrading a fresh install changes nothing" || fail "re-upgrade of a fresh install: ${SUMMARY:-no summary line}"
UPGRADE_LOG=$(cat "$TMP/.upgrade.log")
[[ "$UPGRADE_LOG" == *"scripts/run-bench.sh"* ]] && pass "upgrade reports leftover scripts/run-bench.sh" || fail "upgrade did not report leftover scripts/run-bench.sh"
assert_file "$TMP/scripts/run-bench.sh"
if grep -qxF 'scripts/run-bench.sh' "$TMP/.kit-manifest"; then
  fail "leftover scripts/run-bench.sh is still in .kit-manifest"
else
  pass "leftover scripts/run-bench.sh dropped from .kit-manifest"
fi
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --diff >"$TMP/.diff0.log" 2>&1 ) \
   && grep -q 'Your installation is up to date' "$TMP/.diff0.log"; then
  pass "--diff on a current install: up to date"
else
  fail "--diff on a current install did not report up to date"; tail -12 "$TMP/.diff0.log"
fi

echo "== upgrade: kit changes land, local edits survive =="
# --upgrade used to copy only MISSING files, so a file a release changed was never
# updated while VERSION was bumped. Each case below is set up against the baseline.
H1=".claude/hooks/block-dangerous-commands.sh"          # kit changed it, you didn't → updated
H2=".claude/hooks/secret-scan.sh"                       # you edited it, kit didn't  → kept
H3=".claude/hooks/branch-protect.sh"                    # both changed it            → conflict
S1=".claude/skills/debug/references/error-patterns.md" # nested skill file          → updated
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$TMP/$H1"
set_baseline "$TMP" "$H1" "$(hash_of "$TMP/$H1")"
printf 'an older kit version\n' > "$TMP/$S1"
set_baseline "$TMP" "$S1" "$(hash_of "$TMP/$S1")"
echo '# my local tweak' >> "$TMP/$H2"
echo '# my local tweak' >> "$TMP/$H3"
set_baseline "$TMP" "$H3" "$(hash_of "$TMP/package.json")"  # the kit last shipped something else here
echo '- [ ] my own task' >> "$TMP/tasks/todo.md"
echo '## My module' >> "$TMP/CODEBASE_MAP.md"
cp "$TMP/tasks/todo.md" "$TMP/.todo.before"
cp "$TMP/CODEBASE_MAP.md" "$TMP/.map.before"
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade2.log" 2>&1 ); then
  pass "upgrade over an edited install ran clean"
else
  fail "upgrade over an edited install failed"; tail -8 "$TMP/.upgrade2.log"
fi
cmp -s "$KIT_ROOT/$H1" "$TMP/$H1" && pass "kit-changed hook updated" || fail "kit-changed hook left stale: $H1"
cmp -s "$KIT_ROOT/$S1" "$TMP/$S1" && pass "nested skill file updated" || fail "nested skill file left stale: $S1"
grep -q 'my local tweak' "$TMP/$H2" && pass "locally edited hook kept" || fail "local edit overwritten: $H2"
assert_absent "$TMP/$H2.kit-new"
grep -q 'my local tweak' "$TMP/$H3" && pass "conflicting hook kept" || fail "local edit overwritten on conflict: $H3"
cmp -s "$KIT_ROOT/$H3" "$TMP/$H3.kit-new" && pass "conflict: kit version saved as .kit-new" || fail "conflict: no .kit-new for $H3"
cmp -s "$TMP/.todo.before" "$TMP/tasks/todo.md" && pass "tasks/todo.md untouched" || fail "upgrade modified tasks/todo.md"
cmp -s "$TMP/.map.before" "$TMP/CODEBASE_MAP.md" && pass "CODEBASE_MAP.md untouched" || fail "upgrade modified CODEBASE_MAP.md"
cmp -s "$KIT_ROOT/examples/node-api/CLAUDE.md" "$TMP/CLAUDE.md" \
  && pass "CLAUDE.md still on its node-api template" || fail "CLAUDE.md drifted off its node-api template"
assert_absent "$TMP/.kit-backup"  # every file had a baseline entry — nothing needed a backup
SUMMARY=$(upgrade_summary "$TMP/.upgrade2.log")
[[ "$SUMMARY" == *" 2 updated · "* && "$SUMMARY" == *" 1 kept (local edits) · 1 conflicts"* ]] \
  && pass "summary reports 2 updated · 1 kept · 1 conflict" || fail "summary: ${SUMMARY:-no summary line}"
# A conflict is reported once: the next upgrade keeps the file quietly unless the
# kit changes it again.
( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade3.log" 2>&1 ) || fail "third upgrade failed"
SUMMARY=$(upgrade_summary "$TMP/.upgrade3.log")
[[ "$SUMMARY" == *" 0 updated · "* && "$SUMMARY" == *" 2 kept (local edits) · 0 conflicts"* ]] \
  && pass "next upgrade: conflict settles to kept" || fail "next upgrade summary: ${SUMMARY:-no summary line}"

echo "== upgrade preview (--diff) and what --upgrade can't fix =="
# --diff runs the real upgrade on a scratch copy, so its plan is exactly what
# --upgrade does. Set up one case of each kind, preview, check that nothing
# changed, then upgrade and check that the preview was right.
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$TMP/$H1"
set_baseline "$TMP" "$H1" "$(hash_of "$TMP/$H1")"
# A template the installer used to overwrite outside the per-file logic: preview
# and upgrade summary must count it the same way (the first real 1.21.0 → HEAD
# preview said "29 to update" while the upgrade said "28 updated").
EX=".claude/commands.json.example"
printf '{"//": "an older example"}\n' > "$TMP/$EX"
set_baseline "$TMP" "$EX" "$(hash_of "$TMP/$EX")"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/.claude/hooks/retired-hook.sh"
printf '%s\t%s\n' "$(hash_of "$TMP/.claude/hooks/retired-hook.sh")" ".claude/hooks/retired-hook.sh" >> "$TMP/.kit-baseline"
python3 - "$TMP/.claude/settings.json" "$(printf '\103\103\113_')" <<'PY'
import json, sys
f = sys.argv[1]
d = json.load(open(f))
d.setdefault("env", {})[sys.argv[2] + "PROTECT_BUILD_CONFIGS"] = "1"  # former prefix (ADR-029)
for groups in d["hooks"].values():
    for g in groups:
        g["hooks"] = [h for h in g["hooks"] if "secret-scan.sh" not in h.get("command", "")]
d["hooks"].setdefault("PostToolUse", []).append(
    {"matcher": "Edit", "hooks": [{"type": "command", "command": ".claude/hooks/ghost.sh"}]})
json.dump(d, open(f, "w"), indent=2)
PY
BASELINE_BEFORE=$(hash_of "$TMP/.kit-baseline")
SETTINGS_BEFORE=$(hash_of "$TMP/.claude/settings.json")
if ( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --diff >"$TMP/.diff.log" 2>&1 ); then
  pass "--diff ran clean"
else
  fail "--diff failed"; tail -8 "$TMP/.diff.log"
fi
PREVIEW=$(sed "s/$(printf '\033')\[[0-9;]*m//g" "$TMP/.diff.log")
[[ "$PREVIEW" == *"Will be updated (2)"* && "$PREVIEW" == *"~ $H1"* && "$PREVIEW" == *"~ $EX"* ]] \
  && pass "--diff: the kit-changed hook and example will be updated" || fail "--diff did not plan exactly the updates of $H1 and $EX"
[[ "$PREVIEW" == *"Kept (2)"*"$H2"* ]] && pass "--diff: locally edited hooks are kept" || fail "--diff did not list the kept hooks"
for needle in "retired-hook.sh" ".claude/hooks/secret-scan.sh" ".claude/hooks/ghost.sh" "former configuration prefix"; do
  [[ "$PREVIEW" == *"$needle"* ]] && pass "--diff reports $needle" || fail "--diff does not mention $needle"
done
if grep -q 'an older kit version' "$TMP/$H1" && [ "$(hash_of "$TMP/.kit-baseline")" = "$BASELINE_BEFORE" ] \
   && [ ! -e "$TMP/.kit-backup" ] && [ ! -e "$TMP/$H1.kit-new" ]; then
  pass "--diff changed nothing in the project"
else
  fail "--diff modified the project"
fi
( cd "$TMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$TMP/.upgrade4.log" 2>&1 ) || fail "upgrade after the preview failed"
cmp -s "$KIT_ROOT/$H1" "$TMP/$H1" && cmp -s "$KIT_ROOT/$EX" "$TMP/$EX" \
  && pass "the previewed updates were applied" || fail "a previewed update was not applied"
[[ "$(upgrade_summary "$TMP/.upgrade4.log")" == *" 2 updated · 0 added · "* ]] \
  && pass "--upgrade counts exactly the 2 updates --diff previewed" || fail "upgrade summary differs from the preview: $(upgrade_summary "$TMP/.upgrade4.log")"
UPGRADE4=$(sed "s/$(printf '\033')\[[0-9;]*m//g" "$TMP/.upgrade4.log")
for needle in "retired-hook.sh" ".claude/hooks/secret-scan.sh" ".claude/hooks/ghost.sh" "former configuration prefix"; do
  [[ "$UPGRADE4" == *"$needle"* ]] && pass "--upgrade reports $needle" || fail "--upgrade does not report $needle"
done
[ "$(hash_of "$TMP/.claude/settings.json")" = "$SETTINGS_BEFORE" ] \
  && pass "--upgrade left .claude/settings.json untouched" || fail "--upgrade modified .claude/settings.json"

echo "== uninstall --force =="
if ! ( cd "$TMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$TMP/.uninstall.log" 2>&1 ); then
  fail "uninstall.sh errored"; tail -8 "$TMP/.uninstall.log"
fi
assert_absent "$TMP/CLAUDE.md"
assert_absent "$TMP/.kit-manifest"
assert_absent "$TMP/.kit-baseline"
# The upgrade tests above edited secret-scan.sh, branch-protect.sh and
# settings.json on purpose, and uninstall keeps a kit file edited since the
# install (F9). Everything else the kit wrote is gone: the manifest backstop
# sweeps what the path-based detection misses (e.g. .claude/*.example).
KEPT_HOOKS=$(cd "$TMP/.claude/hooks" 2>/dev/null && ls -1 | tr '\n' ' ')
[ "$KEPT_HOOKS" = "branch-protect.sh secret-scan.sh " ] && pass "only the two hooks edited since the install remain" \
  || fail "hooks left after uninstall: ${KEPT_HOOKS:-none}"
assert_file "$TMP/.claude/settings.json"
assert_absent "$TMP/.claude/mcp-allowlist.txt.example"
assert_absent "$TMP/.claude/skills"
assert_absent "$TMP/.claude/agents"
# the user's own file must survive
assert_file "$TMP/package.json"

# --- uninstall removes only what the kit installed ----------------------------
# .kit-manifest lists exactly the kit's files, but uninstall deleted scripts/,
# agent_docs/ and .claude/{hooks,skills,agents}/ whole — the project's own
# scripts, skills, agents and hooks with them — and removed a CLAUDE.md the
# installer had kept because it was the project's own.
echo "== uninstall keeps the project's own files =="
UTMP="$XTMP/own-files"
mkdir -p "$UTMP"
echo '{"name":"own-files","version":"1.0.0"}' > "$UTMP/package.json"
( cd "$UTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$UTMP/.install.log" 2>&1 ) \
  || { fail "install for the own-files check failed"; tail -8 "$UTMP/.install.log"; }
# Straight after install, tasks/ and CODEBASE_MAP.md are the kit's scaffold: no
# "your data" warning (the scaffold's example Top Rule used to trigger one).
FRESH_PREVIEW=$( cd "$UTMP" && bash "$KIT_ROOT/uninstall.sh" --dry-run 2>&1 | sed "s/$(printf '\033')\[[0-9;]*m//g" )
[[ "$FRESH_PREVIEW" != *"contains your"* ]] && pass "a fresh tasks/ isn't flagged as your data" \
  || fail "a fresh install's tasks/ is flagged as your data"
[[ "$FRESH_PREVIEW" == *"✕ CODEBASE_MAP.md"* ]] && pass "an unfilled CODEBASE_MAP.md is listed for removal" \
  || fail "an unfilled CODEBASE_MAP.md isn't listed for removal"
OWN_FILES="scripts/deploy.sh agent_docs/runbook.md .claude/hooks/my-hook.sh .claude/skills/my-skill/SKILL.md .claude/agents/my-agent.md"
for f in $OWN_FILES; do
  mkdir -p "$UTMP/$(dirname "$f")"
  echo "# the project's own" > "$UTMP/$f"
done
# A CLAUDE.md the installer kept: .kit-manifest still lists it, but .kit-baseline
# — what the kit actually wrote — doesn't.
echo "# the project's own rules" > "$UTMP/CLAUDE.md"
grep -v "$(printf '\t')CLAUDE.md\$" "$UTMP/.kit-baseline" > "$UTMP/.kit-baseline.tmp" \
  && mv "$UTMP/.kit-baseline.tmp" "$UTMP/.kit-baseline"
# The project fills in its map and writes a plan: both are its data now.
echo "- the project's own entry" >> "$UTMP/CODEBASE_MAP.md"
echo "- [ ] the project's own task" >> "$UTMP/tasks/todo.md"
# Files an older kit version wrote that the manifest no longer lists: one left
# as the kit wrote it goes; one the project edited since stays.
for f in .claude/hooks/old-kit-hook.sh scripts/old-kit-script.sh; do
  echo "# written by an older kit" > "$UTMP/$f"
  printf '%s\t%s\n' "$(hash_of "$UTMP/$f")" "$f" >> "$UTMP/.kit-baseline"
done
echo "# edited by the project" >> "$UTMP/scripts/old-kit-script.sh"
if ( cd "$UTMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$UTMP/.uninstall.log" 2>&1 ); then
  pass "uninstall ran clean"
else
  fail "uninstall errored"; tail -8 "$UTMP/.uninstall.log"
fi
UNINSTALL_LOG=$(sed "s/$(printf '\033')\[[0-9;]*m//g" "$UTMP/.uninstall.log")
[[ "$UNINSTALL_LOG" == *"✓ tasks/todo.md"* ]] && pass "an edited tasks/todo.md is listed as kept" \
  || fail "an edited tasks/todo.md isn't listed as kept"
for f in $OWN_FILES CLAUDE.md CODEBASE_MAP.md package.json scripts/old-kit-script.sh; do
  [ -f "$UTMP/$f" ] && pass "kept the project's $f" || fail "removed the project's $f"
done
for f in scripts/doctor.sh agent_docs/workflow.md .claude/hooks/quality-gate.sh .claude/hooks/lib \
         .claude/hooks/old-kit-hook.sh .claude/skills/debug .claude/agents/planner.md \
         .claude/settings.json .kit-manifest .kit-baseline; do
  [ ! -e "$UTMP/$f" ] && pass "removed the kit's $f" || fail "left the kit's $f"
done

# --- F4: tasks/ may be a Python package, a task queue's folder ----------------
echo "== uninstall never removes tasks/ as a whole =="
TTMP="$XTMP/tasks-own"
mkdir -p "$TTMP"
echo '{"name":"tasks-own","version":"1.0.0"}' > "$TTMP/package.json"
( cd "$TTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$TTMP/.install.log" 2>&1 ) \
  || { fail "install for the tasks/ check failed"; tail -8 "$TTMP/.install.log"; }
echo "# the project's own worker" > "$TTMP/tasks/celery.py"
mkdir -p "$TTMP/tasks/jobs"
echo "# the project's own job" > "$TTMP/tasks/jobs/nightly.py"
echo "- [ ] the project's own task" >> "$TTMP/tasks/todo.md"
( cd "$TTMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$TTMP/.uninstall.log" 2>&1 ) \
  && pass "uninstall ran clean" || { fail "uninstall errored"; tail -8 "$TTMP/.uninstall.log"; }
for f in tasks/celery.py tasks/jobs/nightly.py tasks/todo.md; do
  [ -f "$TTMP/$f" ] && pass "kept the project's $f" || fail "removed the project's $f"
done
for f in tasks/decisions.md tasks/handoff.md tasks/lessons/_index.md tasks/lessons/_TEMPLATE.md; do
  [ ! -e "$TTMP/$f" ] && pass "removed the untouched scaffold $f" || fail "left the untouched scaffold $f"
done
[ ! -d "$TTMP/tasks/lessons" ] && pass "removed the emptied tasks/lessons/" || fail "left an empty tasks/lessons/"

# --- S4: an install from before .kit-baseline -------------------------------
echo "== uninstall with no install record saves before it removes =="
NTMP="$XTMP/no-record"
mkdir -p "$NTMP" "$NTMP/elsewhere"
echo '{"name":"no-record","version":"1.0.0"}' > "$NTMP/package.json"
( cd "$NTMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$NTMP/.install.log" 2>&1 ) \
  || { fail "install for the no-record check failed"; tail -8 "$NTMP/.install.log"; }
rm -f "$NTMP/.kit-baseline"
echo "# the target of a link" > "$NTMP/elsewhere/target.md"
rm -rf "$NTMP/.claude/skills/debug"
ln -s ../../elsewhere "$NTMP/.claude/skills/debug"
( cd "$NTMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$NTMP/.uninstall.log" 2>&1 ) \
  && pass "uninstall ran clean" || { fail "uninstall errored"; tail -8 "$NTMP/.uninstall.log"; }
NB=$(find "$NTMP/.kit-backup" -mindepth 1 -maxdepth 1 -type d | head -1)
[ -n "$NB" ] && pass "a .kit-backup/ stamp exists" || fail "no .kit-backup/ stamp"
[ -f "$NB/.claude/hooks/quality-gate.sh" ] && pass "a removed kit hook was saved first" || fail "the hook wasn't saved"
[ -f "$NB/CLAUDE.md" ] && pass "CLAUDE.md was saved first" || fail "CLAUDE.md wasn't saved"
[ -L "$NB/.claude/skills/debug" ] && pass "a link was saved as a link" || fail "the link wasn't saved as a link"
[ -f "$NTMP/elsewhere/target.md" ] && pass "the link target is untouched" || fail "the link target was touched"
[ ! -e "$NTMP/.claude/hooks/quality-gate.sh" ] && pass "the kit hook is gone from the project" || fail "the kit hook is still there"
# A CLAUDE.md without the kit's Session Boot is the project's.
NTMP2="$XTMP/no-record-own"
mkdir -p "$NTMP2"
echo '{"name":"no-record-own","version":"1.0.0"}' > "$NTMP2/package.json"
( cd "$NTMP2" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$NTMP2/.install.log" 2>&1 )
rm -f "$NTMP2/.kit-baseline"
echo "# the project's own rules" > "$NTMP2/CLAUDE.md"
( cd "$NTMP2" && bash "$KIT_ROOT/uninstall.sh" --force >"$NTMP2/.uninstall.log" 2>&1 )
[ -f "$NTMP2/CLAUDE.md" ] && grep -q "own rules" "$NTMP2/CLAUDE.md" && pass "a CLAUDE.md without Session Boot stays" \
  || fail "a CLAUDE.md without Session Boot was removed"

# --- a project the kit never entered (an install that aborted before writing) --
echo "== uninstall leaves a project the kit never entered alone =="
VTMP="$XTMP/never-entered"
mkdir -p "$VTMP/scripts" "$VTMP/agent_docs" "$VTMP/.claude/hooks" "$VTMP/.claude/agents" "$VTMP/.claude/skills/mine" \
         "$VTMP/wiki/pages" "$VTMP/artifacts" "$VTMP/raw-sources"
echo '{"name":"never-entered","version":"1.0.0"}' > "$VTMP/package.json"
NE_FILES="scripts/deploy.sh agent_docs/runbook.md .claude/hooks/mine.sh .claude/agents/mine.md .claude/skills/mine/SKILL.md wiki/pages/a.md artifacts/report.html raw-sources/paper.txt"
for f in $NE_FILES; do echo "# the project's own" > "$VTMP/$f"; done
( cd "$VTMP" && bash "$KIT_ROOT/uninstall.sh" --force >"$VTMP/.uninstall.log" 2>&1 ) \
  && pass "uninstall ran clean" || { fail "uninstall errored"; tail -8 "$VTMP/.uninstall.log"; }
for f in $NE_FILES; do
  [ -f "$VTMP/$f" ] && pass "kept the project's $f" || fail "removed the project's $f"
done

# --- review findings on PR A ---------------------------------------------------
echo "== uninstall: modules, a missing manifest, links, odd names, curl =="
inst() {  # <dir> [install flags] — a fresh install into <dir>
  local d="$1"; shift
  mkdir -p "$d"; echo '{"name":"t","version":"1.0.0"}' > "$d/package.json"
  ( cd "$d" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" "$@" >"$d/.install.log" 2>&1 ) \
    || { fail "install into $d failed"; tail -6 "$d/.install.log"; }
}
uninst() { ( cd "$1" && bash "$KIT_ROOT/uninstall.sh" --force >"$1/.uninstall.log" 2>&1 ) \
  && pass "uninstall ran clean" || { fail "uninstall errored"; tail -6 "$1/.uninstall.log"; }; }

# The optional modules go with a round trip.
MTMP="$XTMP/modules"; inst "$MTMP" --wiki --html; uninst "$MTMP"
for f in WIKI.md ARTIFACTS.md wiki artifacts raw-sources; do
  [ ! -e "$MTMP/$f" ] && pass "the kit's $f is gone" || fail "the kit's $f was left"
done
grep -q 'command not found' "$MTMP/.uninstall.log" && fail "uninstall calls a function before defining it" || pass "no undefined function"

# A wiki/ or artifacts/ the kit never installed is the project's.
OTMP="$XTMP/own-modules"; inst "$OTMP"
mkdir -p "$OTMP/wiki" "$OTMP/artifacts"; echo x > "$OTMP/wiki/Home.md"; echo x > "$OTMP/artifacts/app.tar"
uninst "$OTMP"
[ -f "$OTMP/wiki/Home.md" ] && [ -f "$OTMP/artifacts/app.tar" ] && pass "a project's own wiki/ and artifacts/ stay" \
  || fail "a project's own wiki/ or artifacts/ was removed"

# The manifest is gone but the record is there: the record decides, file by file.
RTMP="$XTMP/no-manifest"; inst "$RTMP"; rm -f "$RTMP/.kit-manifest"
echo x > "$RTMP/scripts/mine.sh"; echo x > "$RTMP/.claude/hooks/myhook.sh"; echo x > "$RTMP/agent_docs/mynotes.md"
uninst "$RTMP"
for f in scripts/mine.sh .claude/hooks/myhook.sh agent_docs/mynotes.md; do
  [ -f "$RTMP/$f" ] && pass "kept the project's $f" || fail "removed the project's $f"
done
[ ! -e "$RTMP/scripts/doctor.sh" ] && [ ! -e "$RTMP/.kit-baseline" ] && pass "the kit's files and its record are gone" \
  || fail "the kit's files or record were left"

# A linked folder is taken as a link; what it points at is never touched.
LTMP="$XTMP/links"; inst "$LTMP"
mkdir -p "$LTMP/../shared-proj" "$LTMP/../shared-scripts"
echo x > "$LTMP/../shared-proj/team-rules.md"; echo x > "$LTMP/../shared-scripts/precious.sh"
rm -rf "$LTMP/agent_docs/project"; ln -s ../../shared-proj "$LTMP/agent_docs/project"
uninst "$LTMP"
[ -f "$XTMP/shared-proj/team-rules.md" ] && pass "a linked agent_docs/project target is untouched" || fail "a linked agent_docs/project target was wiped"
LTMP2="$XTMP/links-norecord"; inst "$LTMP2"; rm -f "$LTMP2/.kit-baseline"
rm -rf "$LTMP2/scripts"; ln -s ../shared-scripts "$LTMP2/scripts"
uninst "$LTMP2"
[ -f "$XTMP/shared-scripts/precious.sh" ] && pass "a linked scripts/ target is untouched (no record)" || fail "a linked scripts/ target was wiped"

# The backup covers names with spaces.
BTMP="$XTMP/spaces"; inst "$BTMP"; rm -f "$BTMP/.kit-baseline"
mkdir -p "$BTMP/.claude/skills/my skill"; echo x > "$BTMP/.claude/skills/my skill/SKILL.md"
printf '%s\n' ".claude/skills/my skill" >> "$BTMP/.kit-manifest"
uninst "$BTMP"
BS=$(find "$BTMP/.kit-backup" -mindepth 1 -maxdepth 1 -type d | head -1)
[ -f "$BS/.claude/skills/my skill/SKILL.md" ] && pass "a name with a space was saved before removal" || fail "a name with a space wasn't saved"

# curl | bash has no script path.
CTMP="$XTMP/curl"; inst "$CTMP"
if ( cd "$CTMP" && cat "$KIT_ROOT/uninstall.sh" | bash -s -- --dry-run >"$CTMP/.curl.log" 2>&1 ); then
  pass "uninstall piped through bash runs"
else
  fail "uninstall piped through bash errored"; tail -4 "$CTMP/.curl.log"
fi

# --- strict profile: install path is otherwise never exercised ----------------
echo "== strict profile install =="
echo '{"name":"fixture-strict","version":"1.0.0"}' > "$STMP/package.json"
if ( cd "$STMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --profile strict >"$STMP/.install.log" 2>&1 ); then
  pass "strict install ran clean"
else
  fail "strict install failed"; tail -8 "$STMP/.install.log"
fi
STRICT_SETTINGS="$STMP/.claude/settings.json"
assert_file "$STRICT_SETTINGS"
if json_valid "$STRICT_SETTINGS"; then
  pass "strict settings.json is valid JSON"
else
  fail "strict settings.json is INVALID JSON"
fi
# The strict delta: 5 opt-in hooks + the build-config hard-block flag.
for needle in skill-extract-reminder.sh auto-lint.sh auto-format.sh skill-compliance.sh notify-waiting.sh ACK_PROTECT_BUILD_CONFIGS; do
  grep -q "$needle" "$STRICT_SETTINGS" && pass "strict enables $needle" || fail "strict missing $needle"
done
# Every hook command is anchored at the project root, so it still resolves after
# the agent cd's into a subdirectory, and the subagent hooks match the Agent tool
# as well as the older Task.
settings_problems() {  # <settings.json>
  python3 - "$1" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
for event, groups in d["hooks"].items():
    for g in groups:
        for h in g["hooks"]:
            cmd = h["command"]
            if not cmd.startswith('"$CLAUDE_PROJECT_DIR"/.claude/hooks/'):
                print(f"{event}: relative command {cmd}")
            if "subagent-" in cmd:
                for tool in ("Agent", "Task"):
                    if not re.fullmatch(g.get("matcher", ""), tool):
                        print(f"{event}: {cmd} doesn't match {tool}")
PY
}
if command -v python3 >/dev/null 2>&1; then
  for s in standard:"$KIT_ROOT/.claude/settings.json" strict:"$STRICT_SETTINGS"; do
    problems=$(settings_problems "${s#*:}")
    [ -z "$problems" ] && pass "${s%%:*} settings: hook commands anchored, subagent hooks match Agent" \
      || fail "${s%%:*} settings: $problems"
  done
fi

echo "== strict upgrade (idempotent) =="
if ( cd "$STMP" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --profile strict --upgrade >"$STMP/.upgrade.log" 2>&1 ); then
  pass "strict upgrade ran clean"
else
  fail "strict upgrade failed"; tail -8 "$STMP/.upgrade.log"
fi
json_valid "$STRICT_SETTINGS" && pass "strict settings.json still valid after upgrade" || fail "strict settings.json broke on upgrade"

# --- upgrade safety: each case gets its own project under $XTMP ---------------
# kit <project> <log> [args…] — run this kit's install.sh in <project>.
kit() {
  local p="$1" log="$2"; shift 2
  ( cd "$p" && bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" "$@" >"$p/$log" 2>&1 < /dev/null )
}
# fresh <project> [args…] — a project with a fresh install of this kit.
fresh() {
  local p="$1"; shift
  mkdir -p "$p" && kit "$p" .install.log "$@"
}
# snap <dir> — every file (not following links) with its checksum; logs excluded.
snap() { find "$1" -type f ! -name '.*.log' -exec cksum {} + | LC_ALL=C sort; }
strip_log() { sed "s/$(printf '\033')\[[0-9;]*m//g" "$1"; }
# preview_counts <log> / upgrade_counts <log> — "updates adds conflicts"
preview_counts() {
  strip_log "$1" | awk '/ to update · / { print $1, $5, $9 } /Your installation is up to date/ { print 0, 0, 0 }'
}
upgrade_counts() { strip_log "$1" | awk '/Upgrade summary:/ { print $3, $6, $17 }'; }
# same_counts <project> <diff log> <upgrade log> <label>
same_counts() {
  local a b
  a=$(preview_counts "$1/$2"); b=$(upgrade_counts "$1/$3")
  if [ -n "$a" ] && [ "$a" = "$b" ]; then
    pass "$4: --diff and --upgrade agree ($a — updates adds conflicts)"
  else
    fail "$4: --diff said '${a:-?}', --upgrade did '${b:-?}' (updates adds conflicts)"
  fi
}

echo "== --diff never writes through a symlink =="
# The preview's scratch copy used to keep symlinks, so its upgrade wrote through
# .claude/hooks into the shared target — replacing an edit, with the backup left
# in the scratch dir and deleted.
P="$XTMP/linked"; SHARED="$XTMP/shared-hooks"
fresh "$P"
rm -f "$P/.kit-baseline"  # an install from before the record: changed files get replaced
mkdir -p "$SHARED" && mv "$P/.claude/hooks/"* "$SHARED/" && rmdir "$P/.claude/hooks" && ln -s "$SHARED" "$P/.claude/hooks"
echo '# my shared edit' >> "$SHARED/stop-gate.sh"
SHARED_BEFORE=$(snap "$SHARED"); PROJECT_BEFORE=$(snap "$P")
kit "$P" .diff.log --diff || fail "--diff failed on a symlinked .claude/hooks"
[ "$(snap "$SHARED")" = "$SHARED_BEFORE" ] && grep -q 'my shared edit' "$SHARED/stop-gate.sh" \
  && pass "--diff left the link's target untouched" || fail "--diff wrote through .claude/hooks into its target"
[ "$(snap "$P")" = "$PROJECT_BEFORE" ] && pass "--diff changed nothing in the project" || fail "--diff modified the project"
grep -q '.claude/hooks is a symlink — --upgrade writes through it' "$P/.diff.log" \
  && pass "--diff names the symlink --upgrade will write through" || fail "--diff does not mention the .claude/hooks symlink"
kit "$P" .upgrade.log --upgrade || fail "upgrade through a symlinked .claude/hooks failed"
same_counts "$P" .diff.log .upgrade.log "symlinked .claude/hooks"

echo "== --diff with CLAUDE.md -> AGENTS.md =="
P="$XTMP/agents-link"
fresh "$P"
rm -f "$P/.kit-baseline"
printf '# CLAUDE.md\n\nan older kit version\n' > "$P/AGENTS.md"
rm -f "$P/CLAUDE.md" && ln -s AGENTS.md "$P/CLAUDE.md"
kit "$P" .diff.log --diff || fail "--diff failed with CLAUDE.md -> AGENTS.md"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed with CLAUDE.md -> AGENTS.md"
same_counts "$P" .diff.log .upgrade.log "CLAUDE.md -> AGENTS.md"
if grep -q '^ *~ AGENTS.md' <<<"$(strip_log "$P/.diff.log")"; then
  fail "--diff plans an update of AGENTS.md, which --upgrade never touches by that name"
else
  pass "--diff plans only the CLAUDE.md update"
fi

echo "== upgrade: a file with no entry in the record is replaced, with a backup =="
# The project had its own scripts/validate.sh; install skipped the existing
# scripts/, so .kit-baseline has no entry for it. A file without an entry can be
# a local edit, an older kit file or the project's own and they can't be told
# apart, so the kit's version lands and the previous copy is kept and named.
P="$XTMP/own-script"
mkdir -p "$P/scripts" && echo 'echo my own validate' > "$P/scripts/validate.sh"
cp "$P/scripts/validate.sh" "$XTMP/own-validate.sh"
fresh "$P"
# A record that isn't marked complete (ADR-023's case); the marked one is next.
grep -v '^#complete' "$P/.kit-baseline" > "$P/.kit-baseline.tmp" && mv "$P/.kit-baseline.tmp" "$P/.kit-baseline"
kit "$P" .diff.log --diff || fail "--diff failed with an own scripts/validate.sh"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed with an own scripts/validate.sh"
cmp -s "$KIT_ROOT/scripts/validate.sh" "$P/scripts/validate.sh" && pass "the kit's scripts/validate.sh lands" \
  || fail "scripts/validate.sh was not updated"
OWN_BACKUP=$(find "$P/.kit-backup" -type f -name validate.sh 2>/dev/null | head -n 1)
[ -n "$OWN_BACKUP" ] && cmp -s "$XTMP/own-validate.sh" "$OWN_BACKUP" && pass "the previous copy is in .kit-backup/" \
  || fail "no backup of the replaced scripts/validate.sh"
grep -q "the install record doesn't list it; your copy is in .kit-backup/" "$P/.upgrade.log" \
  && pass "the log names the file and where its copy went" || fail "the log doesn't name the backup"
same_counts "$P" .diff.log .upgrade.log "a file with no entry in the record"
kit "$P" .upgrade2.log --upgrade || fail "second upgrade failed"
[[ "$(upgrade_counts "$P/.upgrade2.log")" == "0 0 0" ]] && pass "the next upgrade is quiet" \
  || fail "next upgrade: $(upgrade_counts "$P/.upgrade2.log")"

echo "== upgrade: under a complete record a file with no entry is the project's (ADR-030) =="
P="$XTMP/own-script-complete"
mkdir -p "$P/scripts/lib" "$P/.claude/agents" && echo 'echo my own validate' > "$P/scripts/validate.sh"
echo '# my own reviewer' > "$P/.claude/agents/code-reviewer.md"
OWN_BEFORE=$(cd "$P" && cksum scripts/validate.sh .claude/agents/code-reviewer.md)
fresh "$P"
ack_record_complete "$P" && pass "a first install marks the record complete" || fail "a first install left the record unmarked"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
[ "$OWN_BEFORE" = "$(cd "$P" && cksum scripts/validate.sh .claude/agents/code-reviewer.md)" ] \
  && pass "the project's own files are byte-identical after --upgrade" || fail "--upgrade changed the project's own files"
[ ! -d "$P/.kit-backup" ] && pass "nothing was replaced, so no backup" || fail "a backup was made"
same_counts "$P" .diff.log .upgrade.log "the project's own files under a complete record"
[[ "$(strip_log "$P/.upgrade.log")" == *"2 yours"* ]] && pass "the summary counts them as yours" || fail "no '2 yours' in the summary"
awk -F'\t' '$2 == "scripts/validate.sh" { f = 1 } END { exit !f }' "$P/.kit-baseline" && fail "the record took the project's validate.sh" || pass "the record still omits validate.sh"
grep -qxF "scripts/validate.sh" "$P/.kit-manifest" && fail "the manifest lists the project's validate.sh" || pass "the manifest omits validate.sh"
ack_record_complete "$P" && pass "the upgrade keeps the record complete" || fail "the upgrade dropped #complete"
kit "$P" .upgrade2.log --upgrade || fail "second upgrade failed"
[[ "$(upgrade_counts "$P/.upgrade2.log")" == "0 0 0" ]] && pass "the next upgrade is quiet" || fail "next upgrade: $(upgrade_counts "$P/.upgrade2.log")"

echo "== a plain run never marks a record it didn't complete =="
P="$XTMP/plain-unmarked"
fresh "$P"
grep -v '^#complete' "$P/.kit-baseline" > "$P/.kit-baseline.tmp" && mv "$P/.kit-baseline.tmp" "$P/.kit-baseline"
kit "$P" .again.log --profile minimal
ack_record_complete "$P" && fail "a plain run marked an unmarked record complete" || pass "a plain run leaves an unmarked record unmarked"
kit "$P" .up.log --upgrade
ack_record_complete "$P" && pass "an --upgrade then marks it" || fail "an --upgrade left the record unmarked"

echo "== a first install cut short is completed by the next --upgrade =="
P="$XTMP/cut-short"
mkdir -p "$P/.claude" && echo '{"name":"cs","version":"1.0.0"}' > "$P/package.json"
: > "$P/.claude/agents"    # a regular file where a folder belongs: the run stops at the agents
kit "$P" .install.log && fail "the install should have stopped at .claude/agents" || pass "the install stopped partway"
[ -f "$P/.kit-baseline" ] && pass "the interrupted run left a record" || fail "no record after an interrupted run"
ack_record_complete "$P" && fail "an interrupted run marked the record complete" || pass "the interrupted record is not marked"
rm -f "$P/.claude/agents"
kit "$P" .upgrade.log --upgrade && pass "the next --upgrade ran clean" || { fail "the next --upgrade failed"; tail -5 "$P/.upgrade.log"; }
[ -z "$(find "$P" -name '*.kit-new*')" ] && pass "no .kit-new was written" || fail "a .kit-new was written"
[ -f "$P/.claude/agents/planner.md" ] && ack_record_complete "$P" && pass "the upgrade completed the install and marked the record" || fail "the install wasn't completed"

echo "== the stale report never calls the project's own files the kit's =="
# Older installs recorded every existing script and skill in .kit-manifest, so a
# pre-baseline --diff told users to remove their own files.
P="$XTMP/own-listed"
mkdir -p "$P/scripts" "$P/.claude/skills/my-own-skill"
echo 'echo deploy' > "$P/scripts/deploy.sh"; echo '# mine' > "$P/.claude/skills/my-own-skill/SKILL.md"
fresh "$P"
stale_list() {  # <log> — the items of the "remove them" section
  strip_log "$1" | awk '/remove them if nothing uses them/ { f = 1; next } f && /^ +- / { print; next } { f = 0 }'
}
# With .kit-baseline: install skipped the existing .claude/skills/, but .kit-manifest lists my-own-skill.
kit "$P" .diff.log --diff || fail "--diff failed"
[[ "$(stale_list "$P/.diff.log")" != *my-own-skill* ]] && pass "baseline install: own skill not called stale" \
  || fail "baseline install: --diff says to remove the project's own .claude/skills/my-own-skill"
# Without it (an install from before the record), as 1.21.0 left the manifest:
rm -f "$P/.kit-baseline"
printf 'scripts/deploy.sh\n.claude/skills/my-own-skill\n' >> "$P/.kit-manifest"
kit "$P" .diff2.log --diff || fail "--diff failed"
STALE=$(stale_list "$P/.diff2.log")
[[ "$STALE" != *deploy.sh* && "$STALE" != *my-own-skill* ]] && pass "pre-baseline install: own files not called stale" \
  || fail "pre-baseline install: --diff says to remove the project's own files: $(echo $STALE)"
grep -q 'may be your own' "$P/.diff2.log" && grep -q 'scripts/deploy.sh' "$P/.diff2.log" \
  && pass "pre-baseline install: listed paths shown, hedged" || fail "pre-baseline install: listed paths not shown with hedged wording"

echo "== upgrade keeps CLAUDE.md's own template =="
# A generic install from before .kit-baseline, retitled by the user, then the
# project gains a package.json: the upgrade used to auto-detect node-api, replace
# CLAUDE.md and record #template node-api for good.
P="$XTMP/retitled"
fresh "$P"
rm -f "$P/.kit-baseline"
awk 'NR == 1 { $0 = "# CLAUDE.md — Acme Billing" } { print }' "$P/CLAUDE.md" > "$P/CLAUDE.md.tmp" && mv "$P/CLAUDE.md.tmp" "$P/CLAUDE.md"
echo '- Acme rule: never touch the ledger' >> "$P/CLAUDE.md"
cp "$P/CLAUDE.md" "$XTMP/retitled-claude.md"
echo '{"name":"acme","version":"1.0.0"}' > "$P/package.json"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
cmp -s "$XTMP/retitled-claude.md" "$P/CLAUDE.md" && pass "a CLAUDE.md of unknown template is left untouched" \
  || fail "upgrade replaced a retitled CLAUDE.md ($(head -n 1 "$P/CLAUDE.md"))"
grep -q 'Auto-detected template' "$P/.upgrade.log" && fail "upgrade auto-detected a template for an existing CLAUDE.md" \
  || pass "no template auto-detected for an existing CLAUDE.md"
grep -q '^#template' "$P/.kit-baseline" && fail ".kit-baseline records a template: $(grep '^#template' "$P/.kit-baseline")" \
  || pass "no template recorded for it"
grep -q 'CLAUDE.md left untouched' "$P/.upgrade.log" && grep -q 'CLAUDE.md left untouched' "$P/.diff.log" \
  && pass "--diff and --upgrade both say why CLAUDE.md is untouched" || fail "CLAUDE.md skipped silently"
same_counts "$P" .diff.log .upgrade.log "retitled CLAUDE.md"

echo "== --upgrade counts every file it creates =="
P="$XTMP/add-wiki"
fresh "$P"
kit "$P" .diff.log --wiki --diff || fail "--wiki --diff failed"
kit "$P" .upgrade.log --wiki --upgrade || fail "--wiki --upgrade failed"
[ "$(preview_counts "$P/.diff.log" | awk '{ print $2 }')" -gt 0 ] 2>/dev/null && pass "adding --wiki adds files" || fail "adding --wiki added nothing"
same_counts "$P" .diff.log .upgrade.log "standard, then --wiki"
P="$XTMP/add-standard"
fresh "$P" --profile minimal
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
same_counts "$P" .diff.log .upgrade.log "minimal, then standard"
kit "$P" .diff2.log --diff && grep -q 'Your installation is up to date' "$P/.diff2.log" \
  && pass "minimal, then standard: next --diff is up to date" || fail "minimal, then standard: next --diff is not up to date"

echo "== --diff with a relative --local path =="
# The preview's nested run works from its scratch dir, where ../ack-kit is gone.
P="$XTMP/relative"
ln -s "$KIT_ROOT" "$XTMP/ack-kit"
fresh "$P"
if ( cd "$P" && bash ../ack-kit/install.sh --local ../ack-kit --diff >"$P/.diff.log" 2>&1 < /dev/null ) \
   && grep -q 'Your installation is up to date' "$P/.diff.log"; then
  pass "--diff works with --local ../ack-kit"
else
  fail "--diff with a relative --local failed"; tail -3 "$P/.diff.log"
fi

echo "== --upgrade and --diff refuse to run without a hash tool =="
# An upgrade without one replaced files but recorded no hashes, leaving stale
# baseline entries that caused false conflicts later.
SHIM="$XTMP/nohash-bin"; mkdir -p "$SHIM"
OLDIFS=$IFS; IFS=:
for d in $PATH; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    n=${f##*/}
    case "$n" in sha256sum|shasum*|python|python3*) continue ;; esac
    [ -x "$f" ] && [ ! -e "$SHIM/$n" ] && ln -s "$f" "$SHIM/$n"
  done
done
IFS=$OLDIFS
P="$XTMP/nohash"
fresh "$P"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/secret-scan.sh"
BEFORE=$(snap "$P")
if ( cd "$P" && env PATH="$SHIM" bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --upgrade >"$P/.upgrade.log" 2>&1 < /dev/null ); then
  fail "--upgrade ran without a hash tool"
else
  pass "--upgrade stops without a hash tool"
fi
grep -q 'No sha256 tool found' "$P/.upgrade.log" && pass "it says why" || fail "no message about the missing hash tool";
[ "$(snap "$P")" = "$BEFORE" ] && pass "nothing in the project changed" || fail "--upgrade without a hash tool changed the project"
( cd "$P" && env PATH="$SHIM" bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" --diff >"$P/.diff.log" 2>&1 < /dev/null ) \
  && fail "--diff ran without a hash tool" || pass "--diff stops without a hash tool"
P="$XTMP/nohash-fresh"; mkdir -p "$P"
if ( cd "$P" && env PATH="$SHIM" bash "$KIT_ROOT/install.sh" --local "$KIT_ROOT" >"$P/.install.log" 2>&1 < /dev/null ); then
  pass "a fresh install still works without a hash tool"
else
  fail "a fresh install failed without a hash tool"; tail -3 "$P/.install.log"
fi
assert_absent "$P/.kit-baseline"
grep -q '.kit-baseline not written' "$P/.install.log" && pass "it warns that no baseline was written" || fail "no warning about the missing baseline"

echo "== a waiting .kit-new is never overwritten =="
P="$XTMP/kit-new"
fresh "$P"
echo '# my local tweak' >> "$P/$H3"
set_baseline "$P" "$H3" "$(hash_of "$P/VERSION")"  # the kit last shipped something else here
echo 'my half-done merge' > "$P/$H3.kit-new"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "upgrade failed"
grep -q 'my half-done merge' "$P/$H3.kit-new" && pass "the earlier .kit-new is untouched" || fail "upgrade overwrote $H3.kit-new"
cmp -s "$KIT_ROOT/$H3" "$P/$H3.kit-new.1" && pass "the kit's version went to .kit-new.1" || fail "no $H3.kit-new.1 with the kit's version"
grep -q "$H3.kit-new.1" "$P/.upgrade.log" && pass "the upgrade names .kit-new.1" || fail "the upgrade doesn't say where the kit's version went"
same_counts "$P" .diff.log .upgrade.log "earlier .kit-new"

echo "== a plain re-run over an older install doesn't freeze kit files =="
# Such a re-run records only the two or three files it copied. Reading that as
# "the kit wrote everything it lists" would leave every other kit file behind.
P="$XTMP/rerun-partial"
fresh "$P"
rm -f "$P/.kit-baseline"  # an install from before the record
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/secret-scan.sh"
printf '# an older kit version\n' > "$P/agent_docs/hooks.md"
kit "$P" .rerun.log --profile minimal || fail "a plain re-run failed"
kit "$P" .upgrade.log --upgrade || fail "the upgrade after the re-run failed"
cmp -s "$KIT_ROOT/.claude/hooks/secret-scan.sh" "$P/.claude/hooks/secret-scan.sh" \
  && cmp -s "$KIT_ROOT/agent_docs/hooks.md" "$P/agent_docs/hooks.md" \
  && pass "the kit's own files are updated" || fail "kit files were left behind after a partial record"
[ -z "$(find "$P" -name '*.kit-new*')" ] && pass "no .kit-new was written for them" \
  || fail "the upgrade wrote .kit-new files for the kit's own files"
kit "$P" .upgrade2.log --upgrade || fail "the second upgrade failed"
[[ "$(upgrade_counts "$P/.upgrade2.log")" == "0 0 0" ]] && pass "and the next upgrade is quiet" \
  || fail "next upgrade: $(upgrade_counts "$P/.upgrade2.log")"

echo "== a module the record doesn't list is updated too =="
# With .kit-baseline gone, the record lists neither WIKI.md nor ARTIFACTS.md.
P="$XTMP/module-cover"
fresh "$P" --wiki --html
rm -f "$P/.kit-baseline"
printf '# an older kit version\n' > "$P/WIKI.md"
printf '# an older kit version\n' > "$P/ARTIFACTS.md"
kit "$P" .upgrade1.log --upgrade || fail "the plain upgrade failed"
kit "$P" .upgrade2.log --upgrade --wiki --html || fail "the module upgrade failed"
cmp -s "$KIT_ROOT/WIKI.md" "$P/WIKI.md" && cmp -s "$KIT_ROOT/ARTIFACTS.md" "$P/ARTIFACTS.md" \
  && pass "module files are updated" || fail "module files were left behind"
[ -z "$(find "$P" -maxdepth 1 -name '*.kit-new*')" ] && pass "no .kit-new for them either" \
  || fail "the upgrade wrote .kit-new files for module files"

echo "== a plain --upgrade keeps the installed modules =="
MODULE_ENTRIES="WIKI.md ARTIFACTS.md .claude/agents/wiki-maintainer.md"
for d in "$KIT_ROOT"/wiki-module/.claude/skills/*/; do
  MODULE_ENTRIES="$MODULE_ENTRIES .claude/skills/$(basename "$d")"
done
# missing_modules <project> — the module entries its .kit-manifest doesn't list.
missing_modules() {
  local e out=""
  for e in $MODULE_ENTRIES; do
    grep -qxF "$e" "$1/.kit-manifest" || out="$out $e"
  done
  echo "$out"
}
P="$XTMP/keep-modules"
fresh "$P" --wiki --html
kit "$P" .upgrade.log --upgrade || fail "the plain upgrade failed"
grep -q 'Keeping installed modules: wiki, html' "$P/.upgrade.log" \
  && pass "the upgrade says it keeps wiki and html" || fail "the upgrade didn't say it keeps the modules"
[ -z "$(missing_modules "$P")" ] && pass ".kit-manifest still lists every module file" \
  || fail "the plain upgrade dropped from .kit-manifest:$(missing_modules "$P")"
( cd "$P" && bash ./scripts/doctor.sh >"$P/.doctor.log" 2>&1 )
grep -q 'knowledge wiki module active' "$P/.doctor.log" && grep -q 'HTML artifacts module active' "$P/.doctor.log" \
  && pass "doctor still reports both modules" || fail "doctor lost a module after the upgrade"
# An upgrade from before the fix already stripped them from the manifest; the
# schema files it left on disk bring the modules back.
grep -vxF -f <(printf '%s\n' $MODULE_ENTRIES) "$P/.kit-manifest" > "$P/.kit-manifest.tmp"
mv "$P/.kit-manifest.tmp" "$P/.kit-manifest"
kit "$P" .upgrade2.log --upgrade || fail "the upgrade over a stripped manifest failed"
[ -z "$(missing_modules "$P")" ] && pass "a manifest an older upgrade stripped gets the modules back" \
  || fail "still missing from .kit-manifest:$(missing_modules "$P")"
P="$XTMP/own-wiki"
fresh "$P"
printf '# Team wiki\n' > "$P/WIKI.md"
kit "$P" .upgrade.log --upgrade || fail "the upgrade with a WIKI.md of your own failed"
if grep -qxF WIKI.md "$P/.kit-manifest" || [ -d "$P/wiki" ] || [ "$(head -n 1 "$P/WIKI.md")" != "# Team wiki" ]; then
  fail "a WIKI.md of your own turned the wiki module on"
else
  pass "a WIKI.md of your own doesn't turn the wiki module on"
fi

echo "== a CLAUDE.md the kit never wrote is never replaced =="
# Claude Code's /init writes a CLAUDE.md whose first line is "# CLAUDE.md" too,
# so a first line alone used to "identify" it as the kit's generic template.
P="$XTMP/init-claude"
fresh "$P"
rm -f "$P/.kit-baseline"
printf '# CLAUDE.md\n\nThis file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.\n\n## My own rules\n' > "$P/CLAUDE.md"
cp "$P/CLAUDE.md" "$XTMP/init-claude.md"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "the upgrade failed"
cmp -s "$XTMP/init-claude.md" "$P/CLAUDE.md" && pass "a CLAUDE.md written by /init survives the upgrade" \
  || fail "the upgrade replaced a CLAUDE.md the kit never wrote"
grep -q "none of the kit's sections" "$P/.upgrade.log" && grep -q "none of the kit's sections" "$P/.diff.log" \
  && pass "--diff and --upgrade both say why" || fail "neither run says why CLAUDE.md was left alone"
same_counts "$P" .diff.log .upgrade.log "a CLAUDE.md of the user's own"

echo "== a broken *.sh link of your own doesn't stop the upgrade =="
# chmod +x over .claude/hooks/*.sh and scripts/*.sh used to take the run down
# halfway, every time, while --diff reported success.
P="$XTMP/dangling-own"
fresh "$P"
ln -s ../../nowhere.sh "$P/.claude/hooks/zz-mine.sh"
ln -s ../nowhere.sh "$P/scripts/zz-mine.sh"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/secret-scan.sh"
set_baseline "$P" ".claude/hooks/secret-scan.sh" "$(hash_of "$P/.claude/hooks/secret-scan.sh")"
kit "$P" .diff.log --diff || fail "--diff failed"
kit "$P" .upgrade.log --upgrade || fail "the upgrade stopped on a broken *.sh link"
grep -q 'Upgrade complete' "$P/.upgrade.log" && pass "the upgrade ran to the end" || fail "the upgrade stopped halfway"
cmp -s "$KIT_ROOT/.claude/hooks/secret-scan.sh" "$P/.claude/hooks/secret-scan.sh" && pass "and did its work" \
  || fail "the upgrade didn't update the hook"
same_counts "$P" .diff.log .upgrade.log "a broken *.sh link of your own"

echo "== an upgrade doesn't write through a hard link =="
# Writing into the existing file reached every other name for that inode, so an
# edit the user had made through their own path was lost from both.
P="$XTMP/hardlink"
fresh "$P"
rm -f "$P/.kit-baseline"
printf '#!/usr/bin/env bash\n# an older kit version\n' > "$P/.claude/hooks/auto-format.sh"
mkdir -p "$P/tools" && ln "$P/.claude/hooks/auto-format.sh" "$P/tools/fmt.sh"
echo '# my edit through tools/fmt.sh' >> "$P/tools/fmt.sh"
kit "$P" .upgrade.log --upgrade || fail "the upgrade failed"
grep -q 'my edit through tools/fmt.sh' "$P/tools/fmt.sh" && pass "the user's other name for the file keeps its content" \
  || fail "the upgrade wrote through a hard link"
cmp -s "$KIT_ROOT/.claude/hooks/auto-format.sh" "$P/.claude/hooks/auto-format.sh" && pass "the kit file is updated" \
  || fail "the kit file was left stale"

echo "== .NET below the root =="
P="$XTMP/dotnet-nested"
mkdir -p "$P/src/App" && echo '<Project Sdk="Microsoft.NET.Sdk" />' > "$P/src/App/App.csproj"
fresh "$P"
cmp -s "$KIT_ROOT/examples/dotnet/CLAUDE.md" "$P/CLAUDE.md" && pass "src/App/App.csproj gets the dotnet template" \
  || fail "src/App/App.csproj did not get the dotnet template ($(head -n 1 "$P/CLAUDE.md"))"
P="$XTMP/dotnet-node"
mkdir -p "$P/src/App" && echo '<Project Sdk="Microsoft.NET.Sdk" />' > "$P/src/App/App.csproj"
echo '{"name":"front","version":"1.0.0"}' > "$P/package.json"
fresh "$P"
cmp -s "$KIT_ROOT/examples/node-api/CLAUDE.md" "$P/CLAUDE.md" && pass "a root package.json still wins over a nested .csproj" \
  || fail "a nested .csproj overrode the root package.json"

echo "== ownership classifier =="
# ack_owner reports what .kit-baseline says about a path; install, upgrade and
# uninstall each apply their own policy to the answer. The block lives in three
# files because uninstall.sh and doctor.sh run standalone and cannot source lib/.
ack_block() { sed -n '/^# >>> ack-ownership$/,/^# <<< ack-ownership$/p' "$1"; }
ack_block "$KIT_ROOT/scripts/lib/manifest.sh" > "$XTMP/ack.lib"
ack_block "$KIT_ROOT/uninstall.sh" > "$XTMP/ack.uninstall"
ack_block "$KIT_ROOT/scripts/doctor.sh" > "$XTMP/ack.doctor"
[ -s "$XTMP/ack.lib" ] && pass "manifest.sh carries the ownership block" || fail "no ownership block in scripts/lib/manifest.sh"
cmp -s "$XTMP/ack.lib" "$XTMP/ack.uninstall" && pass "uninstall.sh's copy is identical" || fail "uninstall.sh's ownership block differs from scripts/lib/manifest.sh"
cmp -s "$XTMP/ack.lib" "$XTMP/ack.doctor" && pass "doctor.sh's copy is identical" || fail "scripts/doctor.sh's ownership block differs from scripts/lib/manifest.sh"

# owner_is <label> <want> <dest> <rel> — one classifier answer.
owner_is() {
  local got
  got=$(ack_owner "$3" "$4")
  [ "$got" = "$2" ] && pass "$1 → $2" || fail "$1: expected $2, got $got"
}
P="$XTMP/own"
fresh "$P"
owner_is "an untouched kit hook" kit "$P" .claude/hooks/protect-files.sh
owner_is "nothing there" absent "$P" .claude/hooks/never-shipped.sh
cp "$P/.claude/hooks/protect-files.sh" "$XTMP/protect-files.orig"
echo '# my edit' >> "$P/.claude/hooks/protect-files.sh"
owner_is "a kit hook edited since the install" kit-edited "$P" .claude/hooks/protect-files.sh
mv "$XTMP/protect-files.orig" "$P/.claude/hooks/protect-files.sh"
echo 'mine' > "$P/.claude/agents/my-agent.md"
owner_is "the project's own agent beside the kit's" unrecorded "$P" .claude/agents/my-agent.md
mkdir -p "$P/.claude/skills/debug-copy"
printf '%s\t%s\n' "$(hash_of "$P/CLAUDE.md")" .claude/skills/debug-copy >> "$P/.kit-baseline"
owner_is "a directory the record lists as a path" unverified "$P" .claude/skills/debug-copy
ln -s ../../CLAUDE.md "$P/.claude/agents/link.md"
printf '%s\t%s\n' "$(hash_of "$P/CLAUDE.md")" .claude/agents/link.md >> "$P/.kit-baseline"
owner_is "a recorded link to a file" kit "$P" .claude/agents/link.md
ln -s nowhere "$P/.claude/agents/dangling.md"
owner_is "an unrecorded dangling link" unrecorded "$P" .claude/agents/dangling.md
printf '%s\t%s\n' "$(hash_of "$P/CLAUDE.md")" .claude/agents/dangling.md >> "$P/.kit-baseline"
owner_is "a recorded dangling link" unverified "$P" .claude/agents/dangling.md
printf '#template\tfoo\n' >> "$P/.kit-baseline"
echo 'mine' > "$P/foo"
owner_is "a # header line never names a file" unrecorded "$P" foo
sed 's/$/\r/' "$P/.kit-baseline" > "$XTMP/own.crlf" && cp "$XTMP/own.crlf" "$P/.kit-baseline"
owner_is "a record written with CRLF" kit "$P" .claude/hooks/protect-files.sh
if ( PATH="$SHIM" ack_owner "$P" .claude/hooks/protect-files.sh >"$XTMP/own.nohash" ); then
  [ "$(cat "$XTMP/own.nohash")" = unverified ] && pass "no hash tool → unverified" || fail "no hash tool: expected unverified, got $(cat "$XTMP/own.nohash")"
else
  fail "ack_owner failed without a hash tool"
fi

# The realistic case: a project that already had its own agent at a kit path.
P="$XTMP/own-brownfield"
mkdir -p "$P/.claude/agents" && echo 'mine' > "$P/.claude/agents/code-reviewer.md"
kit "$P" .install.log
owner_is "the project's code-reviewer.md under a real install's record" unrecorded "$P" .claude/agents/code-reviewer.md
rm "$P/.kit-baseline"
owner_is "the same install with .kit-baseline removed" no-record "$P" .claude/agents/code-reviewer.md
printf '#template\tnode-api\n' > "$P/.kit-baseline"
owner_is "a record holding only #template" no-record "$P" .claude/agents/code-reviewer.md

P="$XTMP/own-flags"
fresh "$P"
ack_record_complete "$P" && pass "a first install marks the record complete" || fail "a fresh record is not marked complete"
grep -v '^#complete' "$P/.kit-baseline" > "$P/.kit-baseline.tmp" && mv "$P/.kit-baseline.tmp" "$P/.kit-baseline"
ack_record_complete "$P" && fail "a record without #complete reads as complete" || pass "a record without #complete is not complete"
printf '#complete\t1\n' >> "$P/.kit-baseline"
ack_record_complete "$P" && pass "#complete marks the record" || fail "#complete was not read"
sed 's/$/\r/' "$P/.kit-baseline" > "$XTMP/flags.crlf" && cp "$XTMP/flags.crlf" "$P/.kit-baseline"
ack_record_complete "$P" && pass "#complete is read from a CRLF record" || fail "#complete lost to CRLF"
ack_prior_install "$P" && pass "a project with a record is a prior install" || fail "a recorded project reads as first install"
P="$XTMP/own-empty"; mkdir -p "$P"
ack_prior_install "$P" && fail "an empty project reads as a prior install" || pass "an empty project is a first install"
printf '# My rules\n' > "$P/CLAUDE.md"
ack_prior_install "$P" && fail "a plain CLAUDE.md reads as a prior install" || pass "a CLAUDE.md without the kit's Session Boot is not"
printf '# CLAUDE.md\n\n## Session Boot\n' > "$P/CLAUDE.md"
ack_prior_install "$P" && pass "a CLAUDE.md with Session Boot is a prior install" || fail "Session Boot not recognised"

echo "== the premise: a fresh install records every file it writes into a shared folder =="
# Ownership reads absence from the record as "the project's". That only holds if
# the installer records everything it copies, in every profile and module. The
# check does not use the classifier, so it can fail on its own.
premise_unrecorded() {
  local proj="$1" f
  ( cd "$proj" && find agent_docs scripts .claude/hooks .claude/agents .claude/skills .claude/extensions \
      .claude/settings.json .claude/mcp-allowlist.txt.example .claude/commands.json.example WIKI.md ARTIFACTS.md \
      -type f 2>/dev/null | grep -v '/project/' | LC_ALL=C sort ) | while IFS= read -r f; do
    LC_ALL=C awk -F'\t' -v p="$f" '!/^#/ && $2 == p { found = 1 } END { exit found ? 0 : 1 }' "$proj/.kit-baseline" || echo "$f"
  done
}
for spec in "standard:" "minimal:--profile minimal" "strict:--profile strict" "modules:--wiki --html"; do
  name=${spec%%:*}; args=${spec#*:}
  P="$XTMP/premise-$name"
  # shellcheck disable=SC2086
  fresh "$P" $args
  missing=$(premise_unrecorded "$P")
  [ -z "$missing" ] && pass "$name install: every shared-folder file is in the record" \
    || fail "$name install left files out of the record: $(echo $missing)"
done

echo "== uninstall keeps what the record doesn't list (N1) =="
# init skips .claude/hooks, agents, skills and settings.json when they exist, but
# v1.23.0 still writes the project's own files into .kit-manifest. Uninstall must
# not read that as "the kit installed these": the project comes back as it was.
strip_ansi() { sed "s/$(printf '\033')\[[0-9;]*m//g"; }
P="$XTMP/un-brownfield"
mkdir -p "$P/.claude/hooks" "$P/.claude/agents" "$P/.claude/skills/my-skill"
printf '{"hooks":{}}\n' > "$P/.claude/settings.json"
printf '#!/usr/bin/env bash\nexit 0\n' > "$P/.claude/hooks/my-hook.sh"
echo 'mine' > "$P/.claude/agents/my-agent.md"
echo 'mine' > "$P/.claude/skills/my-skill/SKILL.md"
echo 'mine' > "$P/.claude/settings.local.json"
BEFORE=$(snap "$P")
kit "$P" .install.log
for f in .claude/settings.json .claude/hooks/my-hook.sh .claude/agents/my-agent.md .claude/skills/my-skill; do
  grep -qxF "$f" "$P/.kit-manifest" || echo "$f" >> "$P/.kit-manifest"   # as v1.23.0 wrote them
done
PREVIEW=$( cd "$P" && bash "$KIT_ROOT/uninstall.sh" --dry-run 2>&1 | strip_ansi )
for f in .claude/settings.json .claude/hooks/my-hook.sh .claude/agents/my-agent.md .claude/skills/my-skill; do
  case "$PREVIEW" in *"✕ $f"*) fail "--dry-run lists the project's $f for removal" ;; *) pass "--dry-run leaves $f alone" ;; esac
done
case "$PREVIEW" in *"will also remove empty .claude/"*) fail "--dry-run announces removing a .claude/ that holds project files" ;; *) pass "--dry-run keeps .claude/" ;; esac
( cd "$P" && bash "$KIT_ROOT/uninstall.sh" --force >"$P/.uninstall.log" 2>&1 ) && pass "uninstall ran clean" || { fail "uninstall errored"; tail -8 "$P/.uninstall.log"; }
AFTER=$(snap "$P")
[ "$BEFORE" = "$AFTER" ] && pass "every file is back as it was before the install (nothing lost, nothing left)" \
  || fail "the project differs after install + uninstall: $(diff <(echo "$BEFORE") <(echo "$AFTER") | head -6 | tr '\n' ' ')"
UN_TEXT=$(strip_ansi < "$P/.uninstall.log")
grep -qE 'removed [0-9]+ · kept [0-9]+ \(edited [0-9]+, yours [0-9]+, unverified [0-9]+\)' <<< "$UN_TEXT" \
  && pass "uninstall ends with removed / kept counts" || fail "no removed / kept summary line"

echo "== uninstall keeps a kit file edited since the install (F9) =="
P="$XTMP/un-edited"
fresh "$P"
echo '# my own rule' >> "$P/CLAUDE.md"
echo ' ' >> "$P/.claude/settings.json"
( cd "$P" && bash "$KIT_ROOT/uninstall.sh" --force >"$P/.uninstall.log" 2>&1 ) && pass "uninstall ran clean" || fail "uninstall errored"
grep -q '# my own rule' "$P/CLAUDE.md" 2>/dev/null && pass "an edited CLAUDE.md survives" || fail "an edited CLAUDE.md was removed"
assert_file "$P/.claude/settings.json"
assert_absent "$P/.claude/hooks/protect-files.sh"
UN_TEXT=$(strip_ansi < "$P/.uninstall.log")
grep -q 'edited' <<< "$UN_TEXT" && pass "the log says what was kept as edited" || fail "no mention of the kept edited files"
grep -qE 'settings.json.*(hook|register)' <<< "$UN_TEXT" \
  && pass "a kept settings.json is flagged: it still registers hooks that were removed" || fail "no warning about the kept settings.json"

echo "== uninstall never touches settings.json in a project the kit never entered =="
P="$XTMP/un-never"
mkdir -p "$P/.claude" && printf '{"permissions":{}}\n' > "$P/.claude/settings.json"
( cd "$P" && bash "$KIT_ROOT/uninstall.sh" --force >"$P/.uninstall.log" 2>&1 ) && pass "uninstall ran clean" || fail "uninstall errored"
assert_file "$P/.claude/settings.json"

# --- S5: a plain install into a project that already has these folders --------
echo "== init in a brownfield project installs the kit beside the project's files =="
BF="$XTMP/bf-init"
mkdir -p "$BF/.claude/hooks/lib" "$BF/.claude/agents" "$BF/.claude/skills/my-skill" "$BF/.claude/skills/debug" "$BF/scripts" "$BF/agent_docs"
echo '{"name":"bf","version":"1.0.0"}' > "$BF/package.json"
printf '{"permissions":{"allow":[]}}\n' > "$BF/.claude/settings.json"
echo '#!/bin/sh' > "$BF/.claude/hooks/my-hook.sh"
echo '# mine' > "$BF/.claude/hooks/lib/common.sh"
echo '# mine' > "$BF/.claude/agents/code-reviewer.md"
echo '# mine' > "$BF/.claude/skills/my-skill/SKILL.md"
echo '# mine' > "$BF/.claude/skills/debug/SKILL.md"
echo 'echo mine' > "$BF/scripts/validate.sh"
echo '# mine' > "$BF/agent_docs/workflow.md"
BF_OWN=".claude/settings.json .claude/hooks/my-hook.sh .claude/hooks/lib/common.sh .claude/agents/code-reviewer.md .claude/skills/my-skill/SKILL.md .claude/skills/debug/SKILL.md scripts/validate.sh agent_docs/workflow.md"
BF_BEFORE=$(cd "$BF" && for f in $BF_OWN; do cksum "$f"; done)
kit "$BF" .install.log && pass "brownfield install ran clean" || { fail "brownfield install failed"; tail -6 "$BF/.install.log"; }
BF_AFTER=$(cd "$BF" && for f in $BF_OWN; do cksum "$f"; done)
[ "$BF_BEFORE" = "$BF_AFTER" ] && pass "the project's files are byte-identical" || fail "a project file changed"
for f in .claude/hooks/quality-gate.sh .claude/hooks/secret-scan.sh .claude/agents/planner.md .claude/skills/review-pipeline/SKILL.md \
         scripts/doctor.sh agent_docs/debugging.md; do
  [ -f "$BF/$f" ] && pass "the kit's $f was installed" || fail "the kit's $f is missing"
done
[ -f "$BF/.claude/hooks/lib/hook-lib.sh" ] || [ -n "$(ls "$BF/.claude/hooks/lib" | grep -v '^common.sh$')" ] \
  && pass "the kit's hooks/lib files were installed beside the project's" || fail "no kit file in hooks/lib"
for f in $BF_OWN; do
  grep -qxF "$f" "$BF/.kit-manifest" && fail "the manifest lists the project's $f" || pass "the manifest omits the project's $f"
  awk -F'\t' -v p="$f" '$2 == p { f = 1 } END { exit !f }' "$BF/.kit-baseline" && fail "the record lists the project's $f" || pass "the record omits the project's $f"
done
grep -qxF ".claude/hooks/lib" "$BF/.kit-manifest" && pass "hooks/lib stays in the manifest" || fail "hooks/lib left the manifest"
[ -x "$BF/.claude/hooks/quality-gate.sh" ] && pass "a kit hook is executable" || fail "a kit hook isn't executable"
[ ! -x "$BF/.claude/hooks/my-hook.sh" ] && pass "the project's hook keeps its mode" || fail "the project's hook was made executable"
BF_LOG=$(strip_log "$BF/.install.log")
[[ "$BF_LOG" == *"kept"*"existing"* ]] && pass "the log says what was kept" || fail "the log doesn't say what was kept"
# A second plain run (minimal: a full one needs a terminal, F7) changes nothing and keeps hooks/lib listed.
BF_SNAP=$(snap "$BF" | grep -v "\.kit-manifest\|\.kit-baseline")
kit "$BF" .install2.log --profile minimal && pass "a re-run ran clean" || fail "the re-run failed"
BF_SNAP2=$(snap "$BF" | grep -v "\.kit-manifest\|\.kit-baseline")
[ "$BF_SNAP" = "$BF_SNAP2" ] && pass "a re-run changes no file" || fail "a re-run changed files: $(diff <(echo "$BF_SNAP") <(echo "$BF_SNAP2") | head -4 | tr '\n' ' ')"
grep -qxF ".claude/hooks/lib" "$BF/.kit-manifest" && pass "a re-run keeps hooks/lib in the manifest (F12)" || fail "a re-run dropped hooks/lib (F12)"
# An edited .example survives a plain re-run.
echo "// mine" >> "$BF/.claude/commands.json.example"
kit "$BF" .install3.log --profile minimal
grep -q '// mine' "$BF/.claude/commands.json.example" && pass "an edited .example survives a re-run" || fail "a re-run overwrote an edited .example"
# --upgrade agrees with init on a skill of the project's named like a kit skill.
kit "$BF" .up.log --upgrade && pass "--upgrade beside the brownfield files ran clean" || fail "--upgrade failed"
[ "$(ls -A "$BF/.claude/skills/debug")" = "SKILL.md" ] && pass "--upgrade mixed no kit file into the project's own skill" \
  || fail "--upgrade put kit files into the project's skill: $(ls -A "$BF/.claude/skills/debug" | tr '\n' ' ')"
[ "$(cat "$BF/.claude/agents/code-reviewer.md")" = "# mine" ] && pass "--upgrade kept the project's code-reviewer.md" || fail "--upgrade replaced code-reviewer.md"

# --- S6: tasks/ that is the project's own, or kit-shaped ----------------------
echo "== init: a foreign tasks/ is left alone, a kit-shaped one is completed =="
TF="$XTMP/tasks-foreign"; mkdir -p "$TF/tasks"
echo '{"name":"tf","version":"1.0.0"}' > "$TF/package.json"; echo "# worker" > "$TF/tasks/celery.py"
kit "$TF" .install.log && pass "install beside a foreign tasks/ ran clean" || { fail "install failed"; tail -6 "$TF/.install.log"; }
TF_LS=$(ls -A "$TF/tasks")
[ "$TF_LS" = "celery.py" ] && pass "a foreign tasks/ got no kit file" || fail "a foreign tasks/ holds: $TF_LS"
grep -q '^tasks/' "$TF/.kit-manifest" && fail "the manifest lists a foreign tasks/" || pass "the manifest omits a foreign tasks/"
TF_LOG=$(strip_log "$TF/.install.log")
[[ "$TF_LOG" == *"tasks/"*"board"* ]] && pass "the log says the task board wasn't installed" || fail "no word about the task board"
TK="$XTMP/tasks-shaped"; mkdir -p "$TK/tasks"
echo '{"name":"tk","version":"1.0.0"}' > "$TK/package.json"; echo "- [ ] the project's plan" > "$TK/tasks/todo.md"
kit "$TK" .install.log && pass "install beside a kit-shaped tasks/ ran clean" || fail "install failed"
[ "$(cat "$TK/tasks/todo.md")" = "- [ ] the project's plan" ] && pass "the project's todo.md is untouched" || fail "todo.md was changed"
for f in tasks/decisions.md tasks/handoff.md tasks/lessons/_index.md; do
  [ -f "$TK/$f" ] && pass "the missing scaffold $f was seeded" || fail "$f wasn't seeded"
done
awk -F'\t' '$2 == "tasks/todo.md" { f = 1 } END { exit !f }' "$TK/.kit-baseline" && fail "the record lists the project's todo.md" || pass "the record omits the project's todo.md"
awk -F'\t' '$2 == "tasks/decisions.md" { f = 1 } END { exit !f }' "$TK/.kit-baseline" && pass "a seeded scaffold file is recorded" || fail "a seeded file isn't recorded"

# --- S8: VERSION is the kit's only when the record or the old manifest says so ---
echo "== VERSION: a project's own survives init, --upgrade, --diff and uninstall =="
VP="$XTMP/version-own"; mkdir -p "$VP"
echo '{"name":"vp","version":"1.0.0"}' > "$VP/package.json"; echo "3.4.0" > "$VP/VERSION"
kit "$VP" .install.log && pass "init beside a project VERSION ran clean" || fail "init failed"
[ "$(cat "$VP/VERSION")" = "3.4.0" ] && pass "init left the project's VERSION" || fail "init overwrote VERSION"
grep -qxF VERSION "$VP/.kit-manifest" && fail "the manifest lists the project's VERSION" || pass "the manifest omits the project's VERSION"
[[ "$(strip_log "$VP/.install.log")" == *"VERSION is your project"* ]] && pass "init says VERSION is the project's" || fail "no VERSION warning"
kit "$VP" .up.log --upgrade
[ "$(cat "$VP/VERSION")" = "3.4.0" ] && pass "--upgrade left the project's VERSION" || fail "--upgrade overwrote VERSION"
kit "$VP" .diff.log --diff
[[ "$(strip_log "$VP/.diff.log")" == *"Installed: unknown"* ]] && pass "--diff shows the installed version as unknown" || fail "--diff shows the project's VERSION as the kit's"
( cd "$VP" && bash "$KIT_ROOT/uninstall.sh" --force >"$VP/.uninstall.log" 2>&1 )
[ "$(cat "$VP/VERSION" 2>/dev/null)" = "3.4.0" ] && pass "uninstall kept the project's VERSION" || fail "uninstall removed the project's VERSION"

echo "== VERSION: the kit's own is written, recorded and removed =="
VG="$XTMP/version-kit"; fresh "$VG"
awk -F'\t' '$2 == "VERSION" { f = 1 } END { exit !f }' "$VG/.kit-baseline" && pass "a greenfield VERSION is recorded" || fail "VERSION isn't recorded"
( cd "$VG" && bash "$KIT_ROOT/uninstall.sh" --force >"$VG/.uninstall.log" 2>&1 )
[ ! -e "$VG/VERSION" ] && pass "uninstall removed the kit's VERSION" || fail "uninstall left the kit's VERSION"

echo "== VERSION: an install from before R1 (unrecorded, listed, kit line) is updated =="
VL="$XTMP/version-legacy"; fresh "$VL"
grep -v "$(printf '\t')VERSION\$" "$VL/.kit-baseline" > "$VL/.kit-baseline.tmp" && mv "$VL/.kit-baseline.tmp" "$VL/.kit-baseline"
echo "1.0.0 # x-release-please-version" > "$VL/VERSION"
kit "$VL" .up.log --upgrade
cmp -s "$KIT_ROOT/VERSION" "$VL/VERSION" && pass "a pre-R1 VERSION is updated" || fail "a pre-R1 VERSION was left behind"
awk -F'\t' '$2 == "VERSION" { f = 1 } END { exit !f }' "$VL/.kit-baseline" && pass "and now recorded" || fail "and still unrecorded"

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "install-test: ALL PASS"
else
  echo "install-test: $FAILS FAIL"
  exit 1
fi
