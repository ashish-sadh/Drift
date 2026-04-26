#!/bin/bash
# Hook: PostToolUse on Bash(git commit *)
# Fires on every commit. Enforces: DRAIN/PAUSE stop, feedback replies, bug
# comments. Maintains the commit-counter (only "real work" commits count;
# heartbeat/TestFlight/report/graphify housekeeping is filtered out).

set -e

SESSION_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "junior")

# 1. DRAIN/PAUSE — graceful stop after this commit. ONLY enforced on autopilot
#    sessions. Ground truth for "is this autopilot" is DRIFT_AUTONOMOUS=1, which
#    the watchdog exports before launching Claude. The cache-session-type file
#    is unreliable here because each autopilot spawn overwrites it and human
#    sessions inherit the stale "senior"/"junior" stamp.
DRIFT_STATE=$(cat "$HOME/drift-control.txt" 2>/dev/null | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
if [ "${DRIFT_AUTONOMOUS:-}" = "1" ] && { [ "$DRIFT_STATE" = "DRAIN" ] || [ "$DRIFT_STATE" = "PAUSE" ]; }; then
  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "${DRIFT_STATE} ACTIVE. This was your last commit. Push and exit now. Do NOT start new work."
  }
}
ENDJSON
  exit 0
fi

# 2. Update commit counter (filtered: skip housekeeping)
#
# What counts as "housekeeping" (does NOT advance the counter):
#   - Heartbeat snapshots (autopilot writes one every ~5 min)
#   - TestFlight build chore commits (release bookkeeping)
#   - Daily exec briefing PR merges (the report itself)
#   - Product review PR merges (the review itself)
#   - Graphify rebuild commits (knowledge-graph regen)
#   - Pure version bumps (CURRENT_PROJECT_VERSION)
#
# What counts as "real work" (advances the counter): bug fixes, sprint task
# completions, refactors, doc updates, infra changes — anything that
# represents a unit of substantive work.
#
# Why filter: previously cycle-counter advanced on EVERY commit, so a single
# planning session that did review + TestFlight + heartbeat would advance the
# counter by 6+ in 30 minutes — immediately re-triggering "review due"
# (interval 20). The 4061-cycle drift bug had the same root cause.

COUNTER_FILE="$HOME/drift-state/commit-counter"
SUBJECT=$(git log -1 --format=%s 2>/dev/null || echo "")

is_housekeeping() {
    case "$1" in
        "chore: heartbeat snapshot") return 0 ;;
        "chore: graphify rebuild")   return 0 ;;
        "chore: TestFlight build"*)  return 0 ;;
        chore:\ bump\ CURRENT_PROJECT_VERSION*) return 0 ;;
        chore:\ bump\ build\ to\ *)  return 0 ;;
        Daily\ Briefing*)            return 0 ;;
        docs\(reports\):\ daily\ exec\ briefing*) return 0 ;;
        review-cycle-*)              return 0 ;;
    esac
    return 1
}

COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
if is_housekeeping "$SUBJECT"; then
    SKIP_REASON="housekeeping commit — counter unchanged"
else
    COUNT=$((COUNT + 1))
    echo "$COUNT" > "$COUNTER_FILE"
    SKIP_REASON=""
fi

# 3. Build context injection based on session role
CONTEXT=""

# All roles: close bugs with a comment
CONTEXT="${CONTEXT}ALWAYS: When closing a bug Issue, reply with a comment: what was fixed + commit hash. Never close silently.\n\n"

# Senior + planning only: reply to admin report PR comments
if [[ "$SESSION_TYPE" == "senior" || "$SESSION_TYPE" == "planning" ]]; then
  CONTEXT="${CONTEXT}ALWAYS: If you see admin (ashish-sadh, nimisha-26) comments on report PRs that haven't been replied to, reply with what action was taken or will be taken. Every admin comment gets a response.\n\n"
fi

# All roles: P0 escalation
CONTEXT="${CONTEXT}P0 BUGS: If you encounter a P0 bug that's too complex for your current session, relabel it SENIOR: gh issue edit {N} --add-label SENIOR\n\n"

if [ -n "$SKIP_REASON" ]; then
    echo "Commit $COUNT (unchanged: $SKIP_REASON)."
else
    echo "Commit $COUNT."
fi

cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Commit $COUNT.\n\n${CONTEXT}"
  }
}
ENDJSON

exit 0
