#!/bin/bash
# Live session monitor for Drift Control.
# Reads the current session log, extracts recent activity, updates a GitHub Issue.
# No LLM needed — just parses the stream-json log directly.
#
# Usage: ./scripts/session-monitor.sh <session-log-path> <issue-number>

set -uo pipefail

CURRENT_LOG="$1"
ISSUE_NUM="$2"
INTERVAL=60  # 1 minute between updates

while true; do
    sleep "$INTERVAL"

    [[ ! -f "$CURRENT_LOG" ]] && continue

    # Extract recent activity from stream-json log
    RECENT=$(tail -30 "$CURRENT_LOG" | python3 -c "
import sys, json
lines = []
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'assistant':
            for c in d.get('message', {}).get('content', []):
                if c.get('type') == 'text':
                    lines.append(c['text'][:120])
                elif c.get('type') == 'tool_use':
                    name = c.get('name', '?')
                    inp = c.get('input', {})
                    if name == 'Bash':
                        lines.append(f'Running: {inp.get(\"command\",\"\")[:80]}')
                    elif name == 'Read':
                        lines.append(f'Reading: {inp.get(\"file_path\",\"\").split(\"/\")[-1]}')
                    elif name == 'Edit':
                        lines.append(f'Editing: {inp.get(\"file_path\",\"\").split(\"/\")[-1]}')
                    elif name == 'Agent':
                        lines.append(f'Agent: {inp.get(\"description\",\"\")[:60]}')
                    else:
                        lines.append(f'{name}')
    except:
        pass
# Show last 5 meaningful actions
for l in lines[-5:]:
    print(l)
" 2>/dev/null)

    [[ -z "$RECENT" ]] && continue

    MODEL=$(cat ~/drift-state/last-model 2>/dev/null || echo "?")
    CYCLE=$(cat ~/drift-state/cycle-counter 2>/dev/null || echo "?")
    SESSION_TYPE=$(basename "$CURRENT_LOG" | sed 's/session_\([a-z]*\)_.*/\1/')
    LOG_LINES=$(wc -l < "$CURRENT_LOG" | tr -d ' ')

    BODY="**Model:** ${MODEL} | **Type:** ${SESSION_TYPE} | **Cycle:** ${CYCLE} | **Log:** ${LOG_LINES} lines | **Updated:** $(date '+%H:%M:%S')

\`\`\`
${RECENT}
\`\`\`"

    gh issue edit "$ISSUE_NUM" --body "$BODY" 2>/dev/null || true
done
