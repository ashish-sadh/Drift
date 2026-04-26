#!/bin/bash
# Hook: PreToolUse on Bash — block bash commands on autopilot
# senior/junior sessions until they've claimed an issue.
#
# Why: sessions were running `next --senior` (read-only) instead of
# `next --senior --claim`, then reading the top issue's body and
# self-directing into work without ever tagging in-progress on
# GitHub. Result: dashboards lie, audits show no claimed work, and
# the discipline of "claim → work → close" silently degrades.
# (Observed cycle 7591 on #469 — session did 35 ops, all reads/searches,
#  never called --claim or --done.)
#
# This hook ONLY fires when:
#   - DRIFT_AUTONOMOUS=1 (autopilot)
#   - session type is senior or junior (planning bypasses; humans bypass)
#   - sprint-state.in_progress is null (nothing claimed yet)
#
# Allowed pre-claim commands (everything else blocks):
#   - scripts/sprint-service.sh ...      (the way to claim)
#   - gh issue view/list/comment         (read-only orientation; comments OK)
#   - cat ~/drift-state/* / cat MEMORY.md / cat program.md / cat CLAUDE.md
#   - ls, pwd, echo                      (filesystem orientation)
#
# Read tool stays unrestricted — sessions can read source files for
# context. The point is: don't *do* anything until you've claimed.

set -e

# Read stdin JSON (PreToolUse contract — see pause-gate.sh:6-7 for proven pattern).
# Earlier version of this hook read TOOL_INPUT env var which is never set in PreToolUse,
# causing it to block every Bash call. Always read stdin.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Empty command (parse failure / non-Bash event) — fail open
[ -z "$COMMAND" ] && exit 0

# Only autopilot
[ "${DRIFT_AUTONOMOUS:-0}" = "1" ] || exit 0

# Only senior/junior — planning works off a planning issue directly
SESSION_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "")
case "$SESSION_TYPE" in
    senior|junior) ;;
    *) exit 0 ;;
esac

# Already claimed? exit 0.
STATE_FILE="$HOME/drift-state/sprint-state.json"
[ -f "$STATE_FILE" ] || exit 0
IN_PROGRESS=$(python3 -c "
import json
try:
    d = json.load(open('$STATE_FILE'))
    print(d.get('in_progress') or '')
except Exception:
    print('')
" 2>/dev/null)
[ -n "$IN_PROGRESS" ] && exit 0

# in_progress is null — gate the command.

# Allowlist (regex). ANY match → allow.
ALLOW='(scripts/sprint-service\.sh|gh issue view|gh issue list|gh issue comment|gh pr list|cat .*drift-state|cat .*MEMORY\.md|cat .*program\.md|cat .*CLAUDE\.md|cat .*roadmap\.md|^[[:space:]]*ls( |$)|^[[:space:]]*pwd|^[[:space:]]*echo)'

if echo "$COMMAND" | grep -qE "$ALLOW"; then
    exit 0
fi

# Block.
cat >&2 <<'EOF'
BLOCKED: Claim an issue before running this command.

Run this first:

    TASK=$(scripts/sprint-service.sh next --senior --claim)   # or --junior
    echo "$TASK"

The --claim flag is what tags the issue 'in-progress' on GitHub. Without
it, your work has no audit trail and the dashboard shows nothing in
flight.

If `next` returns "none", exit cleanly — don't backfill from your own
ideas. Backfill is planning's job.

Allowed pre-claim commands (orientation only):
  - scripts/sprint-service.sh ...       (status/next/claim/count)
  - gh issue view N / gh issue list     (read top of queue)
  - gh issue comment                    (questions/clarifications OK)
  - cat ~/drift-state/* / cat MEMORY.md / cat program.md / cat CLAUDE.md
  - ls / pwd / echo

Anything else (find, grep via shell, swift test, build, edit) requires
a claim first.
EOF
exit 2
