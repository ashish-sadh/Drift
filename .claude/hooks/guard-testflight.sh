#!/bin/bash
# Hook: PreToolUse on Bash
# Two gates for TestFlight — ONLY enforced on autonomous loop sessions (DRIFT_AUTONOMOUS=1).
# Human sessions can publish freely.

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only gate ACTUAL xcodebuild invocations. Match `xcodebuild <archive|-exportArchive>`
# anywhere in the command, including compound shell expressions like:
#   pkill -9 -f xcodebuild; sleep 2; xcodebuild archive ...
# which the prior FIRST_WORD-only check missed (sessions started chaining
# pkill+xcodebuild per CLAUDE.md guidance, slipping past the gate entirely).
# Anchored to a delimiter or start-of-line so a shell-quoted "xcodebuild archive"
# inside a grep/echo/cat doesn't false-positive.
#
# Pattern: (start | ; | && | || | & | newline | spaces) followed by optional
# path prefix, then `xcodebuild`, then whitespace, then archive | -exportArchive.
SUBCMD=""
if echo "$COMMAND" | grep -qE '(^|[;&|]| && | \|\| )[[:space:]]*([^[:space:];&|]*\/)?xcodebuild[[:space:]]+archive([[:space:]]|$)'; then
    SUBCMD="archive"
elif echo "$COMMAND" | grep -qE '(^|[;&|]| && | \|\| )[[:space:]]*([^[:space:];&|]*\/)?xcodebuild[[:space:]]+-exportArchive([[:space:]]|$)'; then
    SUBCMD="-exportArchive"
else
    exit 0
fi

# Human sessions can always publish
DRIFT_CONTROL=$(cat "$HOME/drift-control.txt" 2>/dev/null | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
if [ "$DRIFT_CONTROL" != "RUN" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
FLAG_FILE="$HOME/drift-state/testflight-publish-authorized"

# Gate 1: Authorization check (autonomous only)
if [ ! -f "$FLAG_FILE" ]; then
  echo "BLOCKED: Autonomous session — TestFlight publishing only allowed when triggered by the 3-hour hook." >&2
  exit 2
fi

# Gate 2: Pre-flight checklist (only for archive, not export)
if [ "$SUBCMD" = "archive" ]; then
  exec "$PROJECT_DIR/.claude/hooks/preflight-check.sh"
fi

exit 0
