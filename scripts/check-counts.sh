#!/usr/bin/env bash
#
# check-counts.sh — assert the kit's live skill/hook/agent totals match the
# declared canonical counts, and that both READMEs agree with the tree.
#
# This is the single declared source for "how many X the kit ships". Bump the
# EXPECTED_* values below when you add or remove a skill/hook/agent; CI fails
# loudly if the tree drifts from them, so counts stated in hand-edited docs
# (README, tasks/todo.md, CHANGELOG) can't silently rot the way tasks/todo.md's
# "30 skills" did. (The web side regenerates lib/skills-data.ts from the same
# tree, so it tracks the count automatically — this guards the kit's own docs.)
#
# README.md and README.pt-BR.md are checked against the tree too: every count
# they state, every hook, skill and guide they must name, and the line-for-line
# structure the two translations share.
#
# Usage:
#   ./scripts/check-counts.sh          # print the totals and assert they match
#
# Exit codes: 0 all counts match · 1 one or more drifted
#

set -uo pipefail

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT_ROOT"

# --- Canonical counts — bump when you add/remove a skill/hook/agent ----------
EXPECTED_CORE_SKILLS=37
EXPECTED_WIKI_SKILLS=3
EXPECTED_HOOKS=28
EXPECTED_DEFAULT_HOOKS=23   # wired in .claude/settings.json; the rest are opt-in
EXPECTED_AGENTS=6
EXPECTED_GUIDES=12
EXPECTED_STACKS=7
EXPECTED_BENCH_SCENARIOS=158

fails=0
check() { # label expected actual
  if [ "$2" = "$3" ]; then
    echo "  ✓ $1: $3"
  else
    echo "  ✗ $1: expected $2, tree has $3 — bump EXPECTED_* in scripts/check-counts.sh and update the docs/CHANGELOG that state this count" >&2
    fails=$((fails + 1))
  fi
}

# Core skills: .claude/skills/<name>/ excluding build-only _shared / _templates.
core_skills=$(find .claude/skills -mindepth 1 -maxdepth 1 -type d ! -name '_*' 2>/dev/null | wc -l | tr -d ' ')
# Wiki-module skills (shipped only with --wiki).
wiki_skills=$(find wiki-module/.claude/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
# Top-level hook scripts (lib/ helpers and project/ overlay excluded).
hooks=$(find .claude/hooks -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
# Hooks the standard settings.json wires, each counted once; the others are opt-in.
default_hooks=$(grep -oE 'hooks/[A-Za-z0-9_-]+\.sh' .claude/settings.json 2>/dev/null | LC_ALL=C sort -u | wc -l | tr -d ' ')
optin_hooks=$((hooks - default_hooks))
# Subagents.
agents=$(find .claude/agents -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
# Guides Claude reads on demand.
guides=$(find agent_docs -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
# Stack templates.
stacks=$(find examples -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
# KitBench scenarios — README states this total, and bench/README.md tables them.
scenarios=$(find bench/scenarios -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "  Kit inventory counts"
echo "  ===================="
check "core skills" "$EXPECTED_CORE_SKILLS" "$core_skills"
check "wiki skills" "$EXPECTED_WIKI_SKILLS" "$wiki_skills"
check "hooks"       "$EXPECTED_HOOKS"       "$hooks"
check "hooks on by default" "$EXPECTED_DEFAULT_HOOKS" "$default_hooks"
check "agents"      "$EXPECTED_AGENTS"      "$agents"
check "guides"      "$EXPECTED_GUIDES"      "$guides"
check "stack templates" "$EXPECTED_STACKS"  "$stacks"
check "bench scenarios" "$EXPECTED_BENCH_SCENARIOS" "$scenarios"

# --- README.md and README.pt-BR.md --------------------------------------------
# Both READMEs state these counts many times and name every hook, skill and
# guide. check() above doesn't read them, which let "50 scenarios" outlive 18
# new ones. Each problem is reported with the file it's in.
doc_fails=0
doc_fail() { # file message
  echo "  ✗ $1: $2" >&2
  doc_fails=$((doc_fails + 1))
}

# count_claims FILE LABEL ERE ALLOWED... — every match of ERE starts with a
# number, and that number must be one of ALLOWED.
count_claims() {
  local file=$1 label=$2 ere=$3 n a ok
  shift 3
  while read -r n; do
    ok=false
    for a in "$@"; do
      [ "$n" = "$a" ] && ok=true
    done
    $ok || doc_fail "$file" "states $n in a $label count; the tree has $*"
  done < <(grep -oE "$ere" "$file" | grep -oE '^[0-9]+')
}

# names_listed FILE LABEL BEFORE AFTER NAME... — the file must contain each
# NAME wrapped as `BEFORE NAME AFTER` in inline code.
names_listed() {
  local file=$1 label=$2 before=$3 after=$4 text name
  shift 4
  text=$(cat "$file")
  for name in "$@"; do
    [[ $text == *"\`$before$name$after\`"* ]] || doc_fail "$file" "doesn't list the $label \`$before$name$after\`"
  done
}

hook_names=()
for f in .claude/hooks/*.sh; do
  f=${f##*/}; hook_names+=("${f%.sh}")
done
skill_names=()
for d in .claude/skills/*/; do
  d=${d%/}; d=${d##*/}
  case "$d" in _*) continue ;; esac
  skill_names+=("$d")
done
guide_names=()
for f in agent_docs/*.md; do
  guide_names+=("${f##*/}")
done

for readme in README.md README.pt-BR.md; do
  if [ ! -f "$readme" ]; then
    doc_fail "$readme" "missing"
    continue
  fi
  before=$doc_fails

  count_claims "$readme" "hook"     '[0-9]+ hooks'                              "$hooks" "$default_hooks" "$optin_hooks"
  count_claims "$readme" "hook"     '[0-9]+ (hook scripts|scripts de hook)'     "$hooks"
  count_claims "$readme" "default-hook" '[0-9]+ (on by default|ligados por padrão)' "$default_hooks"
  count_claims "$readme" "default-hook" '[0-9]+ (of the|dos) [0-9]+ hooks'     "$default_hooks"
  count_claims "$readme" "opt-in hook"  '[0-9]+ (opt-in|opcionais|hooks opcionais)' "$optin_hooks"
  count_claims "$readme" "skill"    '[0-9]+ skills'                             "$core_skills"
  count_claims "$readme" "subagent" '[0-9]+ subagent(s|es)'                     "$agents"
  count_claims "$readme" "guide"    '[0-9]+ (guides|guias)'                     "$guides"
  count_claims "$readme" "stack"    '[0-9]+ stacks'                             "$stacks"

  # The scenario total, in the prose and in the sample run.
  text=$(cat "$readme")
  re_prose='(harness with|harness de regressão com) ([0-9]+)'
  re_run='([0-9]+)/([0-9]+) PASS'
  if [[ $text =~ $re_prose ]]; then
    [ "${BASH_REMATCH[2]}" = "$scenarios" ] || doc_fail "$readme" "states ${BASH_REMATCH[2]} scenarios; the tree has $scenarios"
  else
    doc_fail "$readme" "doesn't state the scenario total"
  fi
  if [[ $text =~ $re_run ]]; then
    [ "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}" = "$scenarios/$scenarios" ] || doc_fail "$readme" "sample run says ${BASH_REMATCH[1]}/${BASH_REMATCH[2]} PASS; the tree has $scenarios/$scenarios"
  else
    doc_fail "$readme" "has no sample run"
  fi

  names_listed "$readme" "hook"  ""  "" "${hook_names[@]}"
  names_listed "$readme" "skill" "/" "" "${skill_names[@]}"
  names_listed "$readme" "guide" ""  "" "${guide_names[@]}"

  [ "$doc_fails" = "$before" ] && echo "  ✓ $readme: counts, hooks, skills and guides match the tree"
done

# The two READMEs are translations kept line for line: the same line holds the
# same kind of Markdown (heading level, table row and its columns, list item,
# fence, HTML tag, blank, text) and the same numbers. A section added to one
# file only, or a count changed in one, shows up here.
shape() { # file — one line per input line: its Markdown shape and its numbers
  awk '{
    s = "text"
    if ($0 ~ /^```/) s = "fence"
    else if ($0 ~ /^#+ /) { match($0, /^#+/); s = "h" RLENGTH }
    else if ($0 ~ /^\|/) { t = $0; s = "row" gsub(/\|/, "", t) }
    else if ($0 ~ /^ *[0-9]+\. /) s = "ol"
    else if ($0 ~ /^ *- /) s = "ul"
    else if ($0 ~ /^</) s = "tag"
    else if ($0 ~ /^$/) s = "blank"
    n = $0; gsub(/[^0-9]+/, " ", n); gsub(/^ +| +$/, "", n)
    print s " [" n "]"
  }' "$1"
}
if [ -f README.md ] && [ -f README.pt-BR.md ]; then
  shape_diff=$(diff <(shape README.md) <(shape README.pt-BR.md))
  if [ -n "$shape_diff" ]; then
    doc_fail "README.pt-BR.md" "is out of step with README.md from line ${shape_diff%%[!0-9]*} (diff: ${shape_diff%%$'\n'*})"
  else
    echo "  ✓ README.md and README.pt-BR.md match line for line"
  fi
fi
fails=$((fails + doc_fails))
echo ""

if [ "$fails" -gt 0 ]; then
  echo "  $fails count(s) drifted from the declared canonical totals." >&2
  exit 1
fi
echo "  All counts match the declared canonical totals."
exit 0
