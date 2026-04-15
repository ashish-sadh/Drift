#!/bin/bash
# Hook: PostToolUse on Bash
# Nags if gh issue close is used without --comment.

set -e

TOOL_INPUT="${TOOL_INPUT:-}"

# Only trigger on gh issue close commands
echo "$TOOL_INPUT" | grep -q "gh issue close" || exit 0

# Check if --comment is included
if ! echo "$TOOL_INPUT" | grep -q "\-\-comment"; then
  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "WARNING: You closed an issue without --comment. Every issue closure MUST include a comment with what was fixed/done + commit hash. Reopen and close properly: gh issue close N --comment 'Fixed: ... (commit abc123)'"
  }
}
ENDJSON
fi

exit 0
