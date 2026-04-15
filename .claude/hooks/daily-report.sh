#!/bin/bash
# Hook: PostToolUse on Bash(git commit *)
# Once per day (24h): injects exec report generation instructions.

set -e

# Only for autonomous sessions
DRIFT_CONTROL=$(cat "$HOME/drift-control.txt" 2>/dev/null | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
if [ "$DRIFT_CONTROL" != "RUN" ]; then
  exit 0
fi

LAST_REPORT_FILE="$HOME/drift-state/last-report-time"
MIN_INTERVAL=86400  # 24 hours in seconds

NOW=$(date +%s)
LAST_REPORT=$(cat "$LAST_REPORT_FILE" 2>/dev/null || echo "0")
ELAPSED=$((NOW - LAST_REPORT))

if [ "$ELAPSED" -lt "$MIN_INTERVAL" ]; then
  REMAINING=$(( (MIN_INTERVAL - ELAPSED) / 3600 ))
  echo "Exec report: ${REMAINING}h until next report."
  exit 0
fi

TODAY=$(date +%Y-%m-%d)

cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "DAILY EXEC BRIEFING REQUIRED. Generate now.\n\nIMPORTANT: Write for leadership who have 30 seconds. User-visible language only. No commit hashes. No file names.\n\n1. Gather data: build number (project.yml), test count, coverage, food count, git log --since='24 hours ago', roadmap phase, risks\n\n2. Write Docs/reports/exec-${TODAY}.md using Docs/reports/EXEC-TEMPLATE.md — every section required. Filename MUST be exec-{DATE}.md.\n\n3. Open PR and merge immediately:\n   git checkout -b report/exec-${TODAY}\n   git add Docs/reports/exec-${TODAY}.md && git commit -m 'report: daily briefing ${TODAY}' && git push -u origin report/exec-${TODAY}\n   gh pr create --title 'Daily Briefing — ${TODAY}' --label report --body 'Executive briefing.'\n   gh pr merge --squash --delete-branch && git checkout main && git pull\n\n4. echo \$(date +%s) > ~/drift-state/last-report-time\n\nDo this NOW. Do NOT skip."
  }
}
ENDJSON

exit 0
