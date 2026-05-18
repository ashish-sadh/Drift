#!/bin/bash
# require-done-when.sh — PreToolUse hook.
#
# Blocks `sprint-service.sh claim` (or the MCP equivalent) on an issue whose
# body lacks a <done_when> block. Without the block, the senior/junior session
# has no ground truth to plan against and the verifier has no criteria to
# score against — claiming such an issue would mean the session inherits the
# planning miss.
#
# Shadow mode: when DRIFT_REQUIRE_DONE_WHEN_ENFORCE=0 (default), the hook
# logs warnings to ~/drift-state/require-done-when.log but does NOT block.
# Flip to enforce mode in Phase 4 of the migration after Done-When blocks
# have been backfilled on existing pending tasks.
#
# Hook contract:
#   - matcher: Bash (we sniff for sprint-service.sh claim / drift_sprint_claim)
#   - exit 0: allow
#   - exit 1: warn (non-blocking)
#   - exit 2 with message on stderr: block (only in enforce mode)

set -e

# Silent for non-autonomous (human) sessions
[ "${DRIFT_AUTONOMOUS:-0}" != "1" ] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only interested in claim attempts via bash
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# Pattern: sprint-service.sh ... claim ... <number>
if ! echo "$COMMAND" | grep -qE "sprint-service\.sh.*claim"; then
    exit 0
fi

# Extract the issue number — last numeric token in the command
ISSUE=$(echo "$COMMAND" | grep -oE '[0-9]+' | tail -1)
if [ -z "$ISSUE" ]; then
    exit 0
fi

# Check the issue body for a <done_when> or <progress_when> block
BODY=$(gh issue view "$ISSUE" --json body --jq .body 2>/dev/null || echo "")
if echo "$BODY" | grep -qE "<(done_when|progress_when)"; then
    exit 0
fi

# Log + decide based on enforce flag
LOG="$HOME/drift-state/require-done-when.log"
mkdir -p "$(dirname "$LOG")"
TS=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TS  issue #$ISSUE — missing <done_when> block; command: $COMMAND" >> "$LOG"

if [ "${DRIFT_REQUIRE_DONE_WHEN_ENFORCE:-0}" = "1" ]; then
    cat >&2 <<EOF
[require-done-when] BLOCKED: issue #$ISSUE has no <done_when> block in its body.

The Done-When contract is required before claim. Either:
  1. Edit the issue body to add a <done_when threshold="..."> block, OR
  2. Label this issue 'needs-done-when' and re-run planning to backfill.

See Docs/refactor/harness-rewrite-2026-05-18.md for the XML format.
EOF
    exit 2
else
    # Shadow mode: warn, don't block
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "[require-done-when shadow] issue #$ISSUE missing <done_when> block. Currently warn-only; will block when DRIFT_REQUIRE_DONE_WHEN_ENFORCE=1."
  }
}
EOF
    exit 0
fi
