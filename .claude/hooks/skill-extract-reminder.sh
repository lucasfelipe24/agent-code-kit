#!/usr/bin/env bash
#
# skill-extract-reminder.sh — UserPromptSubmit hook
# Reminds Claude to consider skill extraction at each prompt
#
# NOT enabled by default. To enable, add to .claude/settings.json:
#
#   "UserPromptSubmit": [
#     {
#       "hooks": [
#         {
#           "type": "command",
#           "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/skill-extract-reminder.sh"
#         }
#       ]
#     }
#   ]
#

set -euo pipefail

# Read stdin (required by hook protocol)
cat > /dev/null

# Provide context reminder via hookSpecificOutput.additionalContext — a top-level
# additionalContext is not in Claude Code's schema and never reaches the model.
# The text is a constant, so it needs no escaping (see lib/json-parse.sh →
# hook_context for dynamic text).
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"If you discovered something non-obvious during this task (undocumented behavior, tricky workaround, framework quirk), consider extracting it as a skill. Use /skill-extractor or check .claude/skills/skill-extractor/SKILL.md for the process."}}
EOF
