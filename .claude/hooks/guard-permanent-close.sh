#!/bin/bash

# Silent for non-autonomous (human) sessions — these hooks are autopilot-only.
[[ "${DRIFT_AUTONOMOUS:-0}" != "1" ]] && exit 0
# Hook: PreToolUse on Bash(gh issue close *)
# Blocks closing issues that have a multi-stage lifecycle:
#   - permanent-task: must stay open forever (recurring work)
#   - design-doc:     must stay open until impl tasks complete
#                     (doc-ready → approved → implementing → close)
# Note: this hook only sees Claude's *own* gh issue close calls. Internal
# closes from sprint-service.sh subprocess are invisible — those are guarded
# inside cmd_done itself (see permanent-task + design-doc branches there).

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

NUM=$(echo "$COMMAND" | grep -oE 'gh issue close [0-9]+' | grep -oE '[0-9]+$' | head -1)
[ -z "$NUM" ] && exit 0

LABELS=$(gh issue view "$NUM" --json labels --jq '[.labels[].name]' 2>/dev/null || echo "[]")
IS_PERM=$(echo "$LABELS" | jq -r 'index("permanent-task") != null' 2>/dev/null || echo "false")
IS_DESIGN_DOC=$(echo "$LABELS" | jq -r 'index("design-doc") != null' 2>/dev/null || echo "false")

if [ "$IS_PERM" = "true" ]; then
    echo "BLOCKED: Issue #$NUM is a permanent-task — NEVER close it. Use: scripts/sprint-service.sh session-done $NUM" >&2
    exit 2
fi
if [ "$IS_DESIGN_DOC" = "true" ]; then
    echo "BLOCKED: Issue #$NUM is a design-doc — close only after all impl tasks complete." >&2
    echo "  Lifecycle: doc-ready → human adds 'approved' → senior creates impl tasks (adds 'implementing') → impl tasks close → THEN close design issue." >&2
    echo "  If the doc is filed: gh issue edit $NUM --add-label doc-ready  (don't close)." >&2
    echo "  If all impl-$NUM tasks are closed: scripts/design-service.sh check-complete $NUM (will tell you the right close command)." >&2
    exit 2
fi
exit 0
