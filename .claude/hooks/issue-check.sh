#!/bin/bash
# Hook: PreToolUse on Bash(git commit *)
# Every commit: checks for open bug issues and surfaces them.
# Flags bugs that have screenshots so engineers know to view them.

set -e

# Query open bugs — include body to detect screenshots
# Exclude needs-review and design-doc issues from bug list
BUGS=$(gh issue list --state open --label bug --json number,title,labels,body --jq '[.[] | select((.labels | map(.name) | index("needs-review") | not) and (.labels | map(.name) | index("design-doc") | not))] | .[] | "#\(.number) \(.title) [\(.labels | map(.name) | join(","))]\(if (.body | test("!\\[")) then " 📸 HAS SCREENSHOT" else "" end)"' 2>/dev/null || echo "")

if [ -z "$BUGS" ]; then
  exit 0  # No bugs, proceed
fi

BUG_COUNT=$(echo "$BUGS" | wc -l | tr -d ' ')

cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "OPEN BUGS (${BUG_COUNT}):\n${BUGS}\n\nP0 bugs must be fixed before other work. Bugs marked 📸 have screenshots — download and VIEW the image before fixing."
  }
}
ENDJSON

exit 0
