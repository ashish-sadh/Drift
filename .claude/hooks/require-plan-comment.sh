#!/bin/bash
# Hook: PreToolUse on Bash(git commit *)
#
# Enforces program.md's "post a plan comment before every implementation"
# rule that was previously documented but never gated. Audit showed only
# 15% of recent closed sprint-tasks had plan comments — sessions skipped
# this and the harness never noticed.
#
# This hook BLOCKS `git commit` when:
#   - The session is autopilot (DRIFT_AUTONOMOUS=1), AND
#   - sprint-state.json has an in-progress issue, AND
#   - That issue has no comment starting with Plan:/Approach:/Investigation:/
#     Progress:/Resolution: (case-insensitive), AND
#   - The issue isn't a planning issue (planning IS the plan), AND
#   - The issue isn't a P0 emergency (per program.md exception).
#
# Escape hatch: set DRIFT_SKIP_PLAN_COMMENT=1 if you posted the plan in
# the issue body rather than a comment, or for one-off cases the rule
# shouldn't apply to.

set -e

# 1. Only gate autopilot. Humans aren't subject to this discipline.
[[ "${DRIFT_AUTONOMOUS:-0}" != "1" ]] && exit 0

# 2. Explicit escape hatch.
[[ "${DRIFT_SKIP_PLAN_COMMENT:-0}" == "1" ]] && exit 0

STATE_FILE="$HOME/drift-state/sprint-state.json"
[ -f "$STATE_FILE" ] || exit 0

# 3. Read in_progress from local state. If null/empty, the commit isn't
#    tied to a claimed task (heartbeat, chore, planning checkpoint, etc.).
NUM=$(python3 -c "
import json, sys
try:
    d = json.load(open('$STATE_FILE'))
    ip = d.get('in_progress')
    print(ip if ip else '')
except Exception:
    print('')
" 2>/dev/null)
[ -z "$NUM" ] && exit 0

# 4. Check labels — skip planning + P0/emergency.
LABELS=$(gh issue view "$NUM" --json labels --jq '[.labels[].name] | join(",")' 2>/dev/null || echo "")
case ",$LABELS," in
    *,planning,*) exit 0 ;;
esac
if [[ ",$LABELS," == *",P0,"* ]] && [[ ",$LABELS," == *",emergency,"* ]]; then
    exit 0
fi

# 5. Look for a plan-style comment.
COMMENTS_BODY=$(gh issue view "$NUM" --json comments --jq '.comments[].body' 2>/dev/null || echo "")
if echo "$COMMENTS_BODY" | grep -qiE '^[[:space:]]*(plan|approach|investigation|progress|resolution)[[:space:]]*[:-]'; then
    exit 0
fi

# 6. No plan-style comment found — block.
cat >&2 <<EOF
BLOCKED: Issue #$NUM has no plan comment yet.

Per program.md, sessions must post a plan comment before implementing.
The plan should describe: root cause + fix approach + files to change.

Post one now, then retry the commit:

    gh issue comment $NUM --body "Plan: <root cause> — <fix approach> — touches <files>"

Accepted comment prefixes (case-insensitive):
    Plan:   Approach:   Investigation:   Progress:   Resolution:

Escape hatches (use only when the rule genuinely shouldn't apply):
    - Set DRIFT_SKIP_PLAN_COMMENT=1 for this commit
    - Add the 'planning' label to the issue (planning IS the plan)
    - Add 'emergency' + 'P0' labels (per program.md exception)
EOF
exit 2
