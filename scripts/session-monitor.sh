#!/bin/bash
# Haiku-powered live session monitor for Drift Control.
# Reads the current session log, summarizes via Haiku, updates a GitHub Issue.
# Launched and managed by the watchdog.
#
# Usage: ./scripts/session-monitor.sh <session-log-path> <issue-number>

set -uo pipefail

CURRENT_LOG="$1"
ISSUE_NUM="$2"
INTERVAL=120  # 2 minutes between updates

while true; do
    sleep "$INTERVAL"

    # Skip if log doesn't exist or is empty
    [[ ! -f "$CURRENT_LOG" ]] && continue

    # Extract recent activity from stream-json log
    RECENT=$(tail -20 "$CURRENT_LOG" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'assistant':
            for c in d.get('message', {}).get('content', []):
                if c.get('type') == 'text':
                    print('AI:', c['text'][:150])
                elif c.get('type') == 'tool_use':
                    inp = str(c.get('input', {}))[:80]
                    print(f'Tool: {c[\"name\"]} — {inp}')
    except:
        pass
" 2>/dev/null)

    [[ -z "$RECENT" ]] && continue

    MODEL=$(cat ~/drift-state/last-model 2>/dev/null || echo "?")
    CYCLE=$(cat ~/drift-state/cycle-counter 2>/dev/null || echo "?")
    SESSION_TYPE=$(basename "$CURRENT_LOG" | sed 's/session_\([a-z]*\)_.*/\1/')

    # Summarize via Haiku
    SUMMARY=$(echo "$RECENT" | claude -p \
        "You are a concise status reporter. Summarize in 2-3 sentences what this autopilot session is currently doing. Be specific: mention the issue number if visible, the task type, and the current action. No preamble." \
        --model haiku --output-format text --bare 2>/dev/null || echo "Unable to generate summary")

    # Update the GitHub Issue
    BODY="**Model:** ${MODEL} | **Type:** ${SESSION_TYPE} | **Cycle:** ${CYCLE} | **Updated:** $(date '+%Y-%m-%d %H:%M:%S')

${SUMMARY}"

    gh issue edit "$ISSUE_NUM" --body "$BODY" 2>/dev/null || true
done
