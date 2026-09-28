#!/usr/bin/env bash
#
# Agent Code Kit — Doctor
# Checks the health of your Agent Code Kit installation.
#
# Usage: ./scripts/doctor.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARN=$((WARN + 1)); }
info() { echo -e "  ${BLUE}—${NC} $1"; }

# Prints how the gates are wired in .claude/settings.json + settings.local.json
# (Claude Code merges both): qg=ok|missing, sg=ok|missing, and bypass=<VAR> for
# an env bypass. Never fails, so it is safe under `set -e`.
_doctor_gate_wiring() {
  python3 - <<'PY' || true
import json, os, re

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

cfgs = [c for c in (load(".claude/settings.json"), load(".claude/settings.local.json")) if isinstance(c, dict)]

def wired(event, script, tool=None):
    for cfg in cfgs:
        hooks = cfg.get("hooks")
        if not isinstance(hooks, dict):
            continue
        for entry in hooks.get(event) or []:
            if not isinstance(entry, dict):
                continue
            matcher = entry.get("matcher") or ""
            if tool is not None and matcher not in ("", "*"):
                try:
                    if not re.fullmatch(matcher, tool):
                        continue
                except re.error:
                    continue
            for hook in entry.get("hooks") or []:
                if isinstance(hook, dict) and script in str(hook.get("command", "")):
                    return True
    return False

out = []
if os.path.isfile(".claude/hooks/quality-gate.sh"):
    ok = wired("PostToolUse", "quality-gate.sh", "Edit") and wired("PostToolUse", "quality-gate.sh", "Write")
    out.append("qg=ok" if ok else "qg=missing")
if os.path.isfile(".claude/hooks/stop-gate.sh"):
    out.append("sg=ok" if wired("Stop", "stop-gate.sh") else "sg=missing")
for cfg in cfgs:
    env = cfg.get("env")
    for var in ("SKIP_QUALITY_GATE", "CLAUDE_SKIP_QUALITY_GATE"):
        if isinstance(env, dict) and str(env.get(var, "")) == "1":
            out.append("bypass=" + var)
print(" ".join(out))
PY
}

# _doctor_migrate_prefix <former prefix> — rename env keys under the former
# prefix to ACK_* in .claude/settings.json and settings.local.json. Per changed
# file prints migrated<TAB>file<TAB>renamed<TAB>superseded<TAB>backup, or
# error<TAB>file. Never prints a value. The backup goes to .hook-state/ (which the
# hooks keep git-ignored), mode 600, because settings.local.json may hold tokens.
_doctor_migrate_prefix() {
  python3 - "$1" <<'PY' || true
import json, os, shutil, sys, tempfile, time

old = sys.argv[1]
for path in (".claude/settings.json", ".claude/settings.local.json"):
    if not os.path.isfile(path) or os.path.islink(path):
        continue
    try:
        with open(path) as fh:
            data = json.load(fh)
    except Exception:
        print(f"error\t{path}")
        continue
    env = data.get("env") if isinstance(data, dict) else None
    if not isinstance(env, dict) or not any(k.startswith(old) for k in env):
        continue
    new_env, moved, dropped = {}, 0, 0
    for key, value in env.items():
        if key.startswith(old):
            target = "ACK_" + key[len(old):]
            if target in env:
                dropped += 1
                continue
            new_env[target] = value
            moved += 1
        else:
            new_env[key] = value
    data["env"] = new_env
    tmp = None
    try:
        os.makedirs(".hook-state", exist_ok=True)
        ignore = os.path.join(".hook-state", ".gitignore")
        if not os.path.exists(ignore):
            with open(ignore, "w") as fh:
                fh.write("*\n!.gitignore\n")
        backup = os.path.join(".hook-state", f"{os.path.basename(path)}.{time.strftime('%Y%m%d%H%M%S')}.bak")
        shutil.copyfile(path, backup)
        os.chmod(backup, 0o600)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings.", suffix=".tmp")
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        shutil.copymode(path, tmp)
        os.replace(tmp, path)
    except Exception:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)
        print(f"error\t{path}")
        continue
    print(f"migrated\t{path}\t{moved}\t{dropped}\t{backup}")
PY
}

echo ""
echo "  Agent Code Kit — Doctor"
echo "  ========================"
echo ""

# --- 1. Core files ---
echo "  Core files"
echo "  ----------"

for file in CLAUDE.md CODEBASE_MAP.md; do
  if [ -f "$file" ]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi
done

# Manifest
if [ -f ".kit-manifest" ]; then
  pass ".kit-manifest exists (kit-managed files tracked)"
else
  warn ".kit-manifest missing (run install.sh --upgrade to generate)"
fi

# AGENTS.md freshness — generated from CLAUDE.md/CODEBASE_MAP/conventions; warn
# (non-destructive, mtime-based) if a source is newer than the generated file.
if [ -f "AGENTS.md" ]; then
  AGENTS_STALE=0
  for src in CLAUDE.md CLAUDE.project.md CODEBASE_MAP.md agent_docs/conventions.md; do
    [ -f "$src" ] || continue
    [ "$src" -nt "AGENTS.md" ] && AGENTS_STALE=1
  done
  if [ "$AGENTS_STALE" -eq 1 ]; then
    warn "AGENTS.md may be stale (a source file is newer) — run ./scripts/gen-agents-md.sh"
  else
    pass "AGENTS.md is up to date with its sources"
  fi
fi

# Instruction-file size budget — keep CLAUDE.md thin (the kit's thesis) and
# AGENTS.md under Codex's 32 KiB truncation point. Non-blocking.
check_instruction_size() {  # file budget_kib label
  [ -f "$1" ] || return 0
  local bytes budget
  bytes=$(wc -c < "$1" | tr -d ' ')
  budget=$(( $2 * 1024 ))
  if [ "$bytes" -gt "$budget" ]; then
    warn "$3 is ${bytes}B (over ${2} KiB budget) — keep instruction files lean (CLAUDE.md → Session Boot Tiered; on-demand harness)"
  else
    pass "$3 within size budget (${bytes}B / ${2} KiB)"
  fi
}
check_instruction_size CLAUDE.md 24 "CLAUDE.md"
check_instruction_size AGENTS.md 32 "AGENTS.md"

# Project command manifest — optional single source of truth for the quality gate,
# /ship and the qa-reviewer. A broken or mistyped file is a config error: the gate
# blocks on it rather than silently switching to a guessed check, so doctor fails
# too. Same validator the gate uses (.claude/hooks/lib/project-commands.sh).
if [ -f ".claude/commands.json" ] && command -v python3 >/dev/null 2>&1; then
  if [ -f ".claude/hooks/lib/project-commands.sh" ]; then
    # shellcheck source=/dev/null
    . ".claude/hooks/lib/project-commands.sh"
    CMD_ERR=$(project_commands_error ".")
  elif python3 -c "import json,sys; d=json.load(open('.claude/commands.json')); sys.exit(0 if isinstance(d,dict) else 1)" 2>/dev/null; then
    CMD_ERR=""
  else
    CMD_ERR=".claude/commands.json is not a valid JSON object"
  fi
  if [ -n "$CMD_ERR" ]; then
    fail "$CMD_ERR — the quality gate blocks until it is fixed"
  else
    pass ".claude/commands.json is valid (declared commands in effect)"
  fi
fi

if [ -d "agent_docs" ]; then
  pass "agent_docs/ exists"
  EXPECTED_DOCS=(workflow.md debugging.md testing.md conventions.md subagents.md hooks.md auto-mode.md skills.md contracts.md prompting.md architecture-language.md)
  for doc in "${EXPECTED_DOCS[@]}"; do
    if [ ! -f "agent_docs/$doc" ]; then
      warn "agent_docs/$doc missing"
    fi
  done
else
  fail "agent_docs/ missing"
fi

if [ -d "tasks" ]; then
  pass "tasks/ exists"

  # tasks/lessons/ should be a directory (per-file lessons structure)
  if [ -d "tasks/lessons" ]; then
    pass "tasks/lessons/ is a directory (per-file lessons)"
    [ -f "tasks/lessons/_index.md" ] || warn "tasks/lessons/_index.md missing (Top Rules + lesson index)"
    [ -f "tasks/lessons/_TEMPLATE.md" ] || warn "tasks/lessons/_TEMPLATE.md missing (lesson template)"
  elif [ -f "tasks/lessons" ]; then
    fail "tasks/lessons is a file but should be a directory (per-file structure)"
  else
    warn "tasks/lessons/ missing (run install.sh --upgrade to scaffold)"
  fi

  # Legacy single-file lessons.md (pre-migration)
  if [ -f "tasks/lessons.md" ]; then
    warn "tasks/lessons.md is the legacy single-file format — run scripts/migrate-lessons.sh to convert"
  fi
else
  fail "tasks/ missing"
fi

echo ""

# --- 2. Hooks ---
echo "  Hooks"
echo "  -----"

if [ -d ".claude/hooks" ]; then
  pass ".claude/hooks/ exists"

  HOOK_FILES=(.claude/hooks/*.sh)
  if [ -e "${HOOK_FILES[0]}" ]; then
    for hook in "${HOOK_FILES[@]}"; do
      basename=$(basename "$hook")
      if [ -x "$hook" ]; then
        pass "$basename is executable"
      else
        fail "$basename is NOT executable (run: chmod +x $hook)"
      fi
    done
  else
    warn "No hook files found in .claude/hooks/"
  fi
else
  fail ".claude/hooks/ missing"
fi

echo ""

# --- 3. Settings ---
echo "  Settings"
echo "  --------"

if [ -f ".claude/settings.json" ]; then
  pass ".claude/settings.json exists"

  # Validate JSON
  if command -v python3 &>/dev/null; then
    if python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
      pass "settings.json is valid JSON"
    else
      fail "settings.json is INVALID JSON"
    fi
  elif command -v node &>/dev/null; then
    if node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'))" 2>/dev/null; then
      pass "settings.json is valid JSON"
    else
      fail "settings.json is INVALID JSON"
    fi
  else
    warn "Cannot validate JSON (no python3 or node found)"
  fi

  # Configuration prefix rename (ADR-029): every kit variable is ACK_* now and
  # the former names are ignored. Rename them in .claude/settings.json and
  # settings.local.json (backup first, values untouched and never printed; an
  # ACK_ key already set wins), and point out exported ones, which only the user
  # can rename. The former prefix is built from character codes so the tracked
  # tree never spells it.
  LEGACY_ENV_PREFIX=$(printf '\103\103\113_')
  if command -v python3 >/dev/null 2>&1; then
    while IFS=$'\t' read -r kind file moved dropped backup; do
      case "$kind" in
        migrated)
          note=""
          if [ "$dropped" != "0" ]; then note=" ($dropped superseded by an ACK_ key already set)"; fi
          warn "$file: renamed $moved key(s) to ACK_*$note — backup in $backup; restart Claude Code to apply" ;;
        error)
          fail "$file: couldn't migrate the former-prefix keys to ACK_* (unreadable JSON or write failed) — the file is unchanged" ;;
      esac
    done < <(_doctor_migrate_prefix "$LEGACY_ENV_PREFIX")
  fi
  LEGACY_TARGETS=""
  while IFS= read -r var; do
    case "$var" in "$LEGACY_ENV_PREFIX"*) LEGACY_TARGETS="$LEGACY_TARGETS ACK_${var#"$LEGACY_ENV_PREFIX"}" ;; esac
  done < <(compgen -e)
  if [ -n "$LEGACY_TARGETS" ]; then
    warn "This shell exports variable(s) under the kit's former prefix, which the hooks ignore — rename them to:$LEGACY_TARGETS (shell profile, CI), then restart Claude Code"
  fi
  OLD_PY_CACHE="${TMPDIR:-/tmp}/$(printf '\143\143\153')-python3-usable"
  if [ -f "$OLD_PY_CACHE" ] && [ ! -L "$OLD_PY_CACHE" ] && [ -O "$OLD_PY_CACHE" ]; then
    rm -f "$OLD_PY_CACHE"
  fi

  # Check for orphan hooks (hook files not referenced in settings.json).
  # Opt-in hooks ship enabled only in the strict profile, so they're
  # intentionally absent from the standard settings.json — not orphans.
  # Keep in sync with the profile table in agent_docs/hooks.md.
  if [ -d ".claude/hooks" ]; then
    SETTINGS_CONTENT=$(cat .claude/settings.json)
    # Opt-in hooks are wired by the strict profile only. Derive the set from
    # settings.strict.json wherever it is present, so this cannot drift from
    # gen-strict-settings.sh the way the literal list did when notify-waiting.sh
    # shipped and doctor started calling it an orphan. The literal below is the
    # fallback for standard installs, which do not carry the strict file.
    OPT_IN_HOOKS=" auto-lint.sh auto-format.sh skill-compliance.sh skill-extract-reminder.sh notify-waiting.sh "
    if [ -f ".claude/settings.strict.json" ]; then
      STRICT_CONTENT=$(cat .claude/settings.strict.json)
      DERIVED=" "
      for hook in .claude/hooks/*.sh; do
        [ -f "$hook" ] || continue
        hook_base=$(basename "$hook")
        if [[ "$STRICT_CONTENT" == *"$hook_base"* ]] && [[ "$SETTINGS_CONTENT" != *"$hook_base"* ]]; then
          DERIVED="$DERIVED$hook_base "
        fi
      done
      [ "$DERIVED" != " " ] && OPT_IN_HOOKS="$DERIVED"
    fi
    for hook in .claude/hooks/*.sh; do
      [ -f "$hook" ] || continue
      basename=$(basename "$hook")
      # Substring-test in-process. Piping a variable into a quiet grep under
      # `set -o pipefail` lets the writer's exit status become the pipeline's,
      # which flipped wired hooks to phantom "orphan" warnings.
      if [[ "$SETTINGS_CONTENT" == *"$basename"* ]]; then
        pass "$basename is referenced in settings.json"
      elif [[ "$OPT_IN_HOOKS" == *" $basename "* ]]; then
        info "$basename is opt-in, not in standard profile (enable per agent_docs/hooks.md)"
      else
        warn "$basename exists but is NOT in settings.json (orphan hook)"
      fi
    done
  fi

  # Gate wiring. A file name appearing in settings.json doesn't mean the hook
  # runs on the right event, and the Behavior checks below drive the scripts
  # directly, so they can't see a gate that Claude Code never calls.
  if [ -f ".claude/hooks/quality-gate.sh" ] || [ -f ".claude/hooks/stop-gate.sh" ]; then
    if command -v python3 >/dev/null 2>&1; then
      WIRING=$(_doctor_gate_wiring 2>/dev/null)
      if [[ "$WIRING" == *"qg=ok"* ]]; then
        pass "quality-gate.sh runs after Edit and Write (PostToolUse)"
      elif [[ "$WIRING" == *"qg=missing"* ]]; then
        fail "quality-gate.sh is not registered under PostToolUse for Edit and Write — edits are never checked"
      fi
      if [[ "$WIRING" == *"sg=ok"* ]]; then
        pass "stop-gate.sh runs on Stop"
      elif [[ "$WIRING" == *"sg=missing"* ]]; then
        fail "stop-gate.sh is not registered under Stop — a failing check never blocks completion"
      fi
      if [[ "$WIRING" == *"bypass="* ]]; then
        warn "The quality gate is bypassed in .claude/settings*.json (env SKIP_QUALITY_GATE) — every session skips it"
      fi
    else
      info "Gate wiring not checked (python3 needed to read settings.json)"
    fi
    if [ "${SKIP_QUALITY_GATE:-0}" = "1" ] || [ "${CLAUDE_SKIP_QUALITY_GATE:-0}" = "1" ]; then
      warn "SKIP_QUALITY_GATE is set in this shell — sessions started from it skip the quality gate"
    fi
  fi
else
  fail ".claude/settings.json missing"
fi

echo ""

# --- 4. CODEBASE_MAP placeholders ---
echo "  CODEBASE_MAP"
echo "  ------------"

if [ -f "CODEBASE_MAP.md" ]; then
  # Count lines that still hold a [placeholder] — brackets that don't open a
  # markdown link [text](url). Code is skipped: fenced blocks and `inline spans`
  # carry literal brackets (INI sections like `[Config]`, array indexing), never
  # placeholders. No "]" inside a bracket expression — BSD awk misreads it.
  REAL_PLACEHOLDERS=$(awk '
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      gsub(/\[[^[(]*\]\(/, "", line)
      if (line ~ /\[.+\]/) n++
    }
    END { print n + 0 }
  ' CODEBASE_MAP.md 2>/dev/null || true)
  REAL_PLACEHOLDERS=${REAL_PLACEHOLDERS:-0}
  REAL_PLACEHOLDERS=$(echo "$REAL_PLACEHOLDERS" | tr -d '[:space:]')

  if [ "$REAL_PLACEHOLDERS" -gt 0 ] 2>/dev/null; then
    warn "CODEBASE_MAP.md has ~$REAL_PLACEHOLDERS unfilled placeholder(s) — run ./scripts/validate.sh for details"
  else
    pass "CODEBASE_MAP.md appears filled in"
  fi
else
  info "Skipped (CODEBASE_MAP.md not found)"
fi

echo ""

# --- 5. Agents & Skills ---
echo "  Agents & Skills"
echo "  ---------------"

if [ -d ".claude/agents" ]; then
  AGENT_COUNT=$(ls -1 .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  pass ".claude/agents/ exists ($AGENT_COUNT agents)"
else
  warn ".claude/agents/ missing"
fi

if [ -d ".claude/skills" ]; then
  SKILL_COUNT=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  pass ".claude/skills/ exists ($SKILL_COUNT skills)"

  # Run skill validator if available
  if [ -f "scripts/validate-skills.sh" ] && [ -x "scripts/validate-skills.sh" ]; then
    if scripts/validate-skills.sh .claude/skills >/dev/null 2>&1; then
      pass "All skills pass validation"
    else
      warn "Some skills have issues — run ./scripts/validate-skills.sh for details"
    fi
  fi
else
  warn ".claude/skills/ missing"
fi

echo ""

# --- 6. Project Overlay ---
echo "  Project Overlay"
echo "  ---------------"

if [ -f "CLAUDE.project.md" ]; then
  pass "CLAUDE.project.md exists (project overlay active)"
else
  info "CLAUDE.project.md not found (optional — create for project-specific rules)"
fi

if [ -d "agent_docs/project" ]; then
  PROJECT_DOC_COUNT=$(ls -1 agent_docs/project/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$PROJECT_DOC_COUNT" -gt 0 ]; then
    pass "agent_docs/project/ has $PROJECT_DOC_COUNT doc(s)"
  else
    info "agent_docs/project/ exists but is empty"
  fi
else
  info "agent_docs/project/ not found (optional — create for project-specific docs)"
fi

if [ -d ".claude/hooks/project" ]; then
  # find is pipefail-safe when no matches (unlike ls glob)
  PROJECT_HOOK_COUNT=$(find .claude/hooks/project -maxdepth 1 -type f -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$PROJECT_HOOK_COUNT" -gt 0 ]; then
    pass ".claude/hooks/project/ has $PROJECT_HOOK_COUNT hook(s)"
    # Check executability
    for hook in .claude/hooks/project/*.sh; do
      [ -f "$hook" ] || continue
      if [ ! -x "$hook" ]; then
        fail "$(basename "$hook") in project hooks is NOT executable"
      fi
    done
  else
    info ".claude/hooks/project/ exists but is empty"
  fi
else
  info ".claude/hooks/project/ not found (optional — create for project-specific hooks)"
fi

echo ""

# --- 7. Optional Modules ---
echo "  Optional Modules"
echo "  ----------------"

# A module counts as installed when .kit-manifest lists its schema file --
# install.sh records it there only under --wiki / --html. The file existing on
# its own is not enough: a repo can carry WIKI.md or ARTIFACTS.md as a source
# template it ships rather than a module it runs, and warning about the vault
# directories in that case is how a real warning gets trained away.
module_installed() {
  [ -f ".kit-manifest" ] || return 1
  grep -qxF "$1" ".kit-manifest"
}

# Knowledge Wiki module
if module_installed "WIKI.md"; then
  pass "WIKI.md exists (knowledge wiki module active)"
  if [ -d "raw-sources" ]; then
    RAW_COUNT=$(find raw-sources -mindepth 1 -type f ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
    pass "raw-sources/ exists ($RAW_COUNT source file(s))"
  else
    warn "raw-sources/ missing (WIKI.md is present — expected the source directory)"
  fi
  if [ -d "wiki" ]; then
    WIKI_PAGE_COUNT=0
    for sub in summaries entities concepts; do
      [ -d "wiki/$sub" ] || continue
      SUB_COUNT=$(find "wiki/$sub" -mindepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
      WIKI_PAGE_COUNT=$((WIKI_PAGE_COUNT + SUB_COUNT))
    done
    pass "wiki/ exists ($WIKI_PAGE_COUNT wiki page(s))"
    [ -f "wiki/index.md" ] || warn "wiki/index.md missing (catalog)"
    [ -f "wiki/log.md" ]   || warn "wiki/log.md missing (activity log)"
  else
    warn "wiki/ missing (WIKI.md is present — expected the vault directory)"
  fi
elif [ -f "WIKI.md" ]; then
  info "WIKI.md present but not a tracked module — source template, not an install (add with --wiki)"
else
  info "Wiki module not installed (optional — install with --wiki)"
fi

# HTML Artifacts module
if module_installed "ARTIFACTS.md"; then
  pass "ARTIFACTS.md exists (HTML artifacts module active)"
  if [ -d "artifacts" ]; then
    if [ -f "artifacts/design-system.html" ]; then
      pass "artifacts/design-system.html exists (token reference)"
    else
      fail "artifacts/design-system.html missing — artifacts will drift in style"
    fi
    if [ -f "artifacts/index.html" ]; then
      pass "artifacts/index.html exists (catalog)"
    else
      warn "artifacts/index.html missing (catalog page)"
    fi
    ART_COUNT=$(find artifacts -mindepth 1 -maxdepth 1 -type f -name "*.html" \
      ! -name "design-system.html" ! -name "index.html" 2>/dev/null | wc -l | tr -d ' ')
    info "artifacts/ has $ART_COUNT generated artifact(s) beyond the reference files"
  else
    warn "artifacts/ missing (ARTIFACTS.md is present — expected the output directory)"
  fi
elif [ -f "ARTIFACTS.md" ]; then
  info "ARTIFACTS.md present but not a tracked module — source template, not an install (add with --html)"
else
  info "HTML Artifacts module not installed (optional — install with --html)"
fi

echo ""

# --- 8. Behavior ---
# Files existing isn't the same as the gate working. Drive the INSTALLED hooks
# against a scratch project the way Claude Code would, and check the outcomes:
# broken code blocks completion, the verdict survives a compaction, fixing the
# code lifts the block, and a git worktree's result stays in that worktree.
echo "  Behavior (installed hooks, scratch project)"
echo "  -------------------------------------------"

HOOKS_DIR="$PWD/.claude/hooks"
if ! command -v python3 >/dev/null 2>&1; then
  info "Skipped — python3 is needed to read the hooks' state"
elif [ ! -f "$HOOKS_DIR/quality-gate.sh" ] || [ ! -f "$HOOKS_DIR/stop-gate.sh" ]; then
  warn "Skipped — quality-gate.sh / stop-gate.sh not installed"
else
  BT=$(mktemp -d "${TMPDIR:-/tmp}/ack-doctor.XXXXXX")
  trap 'rm -rf "$BT"' EXIT
  # A bypass left on in this shell must not fake a result.
  bt_edit() {  # <project> <file> — what Claude Code sends after an Edit
    printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$2" \
      | CLAUDE_PROJECT_DIR="$1" env -u SKIP_QUALITY_GATE -u CLAUDE_SKIP_QUALITY_GATE \
        bash "$HOOKS_DIR/quality-gate.sh" >/dev/null 2>&1 || true
  }
  bt_stop() {  # <project> <cwd> — prints stop-gate's exit code
    local rc=0
    printf '{"cwd":"%s"}' "$2" \
      | CLAUDE_PROJECT_DIR="$1" env -u SKIP_QUALITY_GATE -u CLAUDE_SKIP_QUALITY_GATE \
        bash "$HOOKS_DIR/stop-gate.sh" >/dev/null 2>&1 || rc=$?
    echo "$rc"
  }
  bt_status() {  # <project> — the gate's recorded status
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' \
      "$1/.hook-state/last_quality_gate.json" 2>/dev/null || echo "none"
  }

  P="$BT/project"
  mkdir -p "$P/src"
  echo '{}' > "$P/package.json"
  printf 'def broken(:\n' > "$P/src/app.py"
  bt_edit "$P" "$P/src/app.py"
  BT_STATUS=$(bt_status "$P"); BT_RC=$(bt_stop "$P" "$P")
  if [ "$BT_STATUS" = "failed" ] && [ "$BT_RC" = "2" ]; then
    pass "Broken code is caught and blocks completion"
  else
    fail "Broken code was not blocked (gate recorded '$BT_STATUS', stop-gate exit $BT_RC) — the quality gate is not protecting completion"
  fi

  if [ -f "$HOOKS_DIR/session-start.sh" ]; then
    printf '{"source":"compact","session_id":"ack-doctor"}' \
      | CLAUDE_PROJECT_DIR="$P" bash "$HOOKS_DIR/session-start.sh" >/dev/null 2>&1 || true
    BT_RC=$(bt_stop "$P" "$P")
    if [ "$BT_RC" = "2" ]; then
      pass "The failing verdict survives a compaction"
    else
      fail "A compaction cleared the failing verdict (stop-gate exit $BT_RC)"
    fi
  fi

  printf 'def fixed():\n    return 1\n' > "$P/src/app.py"
  bt_edit "$P" "$P/src/app.py"
  BT_STATUS=$(bt_status "$P"); BT_RC=$(bt_stop "$P" "$P")
  if [ "$BT_STATUS" = "passed" ] && [ "$BT_RC" = "0" ]; then
    pass "Fixing the code lifts the block"
  else
    fail "Fixing the code did not lift the block (gate recorded '$BT_STATUS', stop-gate exit $BT_RC)"
  fi

  # Worktree isolation — global git hooks and commit signing are switched off so
  # the scratch commit can't be blocked by the user's own git setup.
  R="$BT/repo"; W="$BT/wt"
  if command -v git >/dev/null 2>&1 && mkdir -p "$R" && ( cd "$R" && git init -q . \
       && git -c user.name=ack-doctor -c user.email=ack-doctor@example.invalid \
            -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m init \
       && git worktree add -q -b ack-doctor-wt "$W" ) >/dev/null 2>&1; then
    mkdir -p "$W/src"
    printf 'def broken(:\n' > "$W/src/app.py"
    bt_edit "$R" "$W/src/app.py"
    MAIN_RC=$(bt_stop "$R" "$R"); WT_RC=$(bt_stop "$R" "$W")
    # Stored in the worktree, not the main checkout — and still the session's:
    # its stop blocks from either checkout.
    BT_WHERE="main checkout"
    if [ -f "$W/.hook-state/last_quality_gate.json" ] && [ ! -f "$R/.hook-state/last_quality_gate.json" ]; then
      BT_WHERE="worktree"
    fi
    if [ "$BT_WHERE" = "worktree" ] && [ "$MAIN_RC" = "2" ] && [ "$WT_RC" = "2" ]; then
      pass "A git worktree's result is stored in that worktree and still blocks the session's stop"
    else
      fail "Worktree results misplaced or lost (stored in the $BT_WHERE, main-checkout stop exit $MAIN_RC, worktree stop exit $WT_RC; want worktree, 2 and 2)"
    fi
  else
    info "Worktree isolation not checked (git missing, or the scratch worktree couldn't be created)"
  fi
fi

echo ""

# --- Summary ---
echo "  Summary"
echo "  -------"
echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "  Some checks failed. Fix the issues above and run doctor again."
  exit 1
else
  echo "  Installation looks healthy!"
fi
echo ""
