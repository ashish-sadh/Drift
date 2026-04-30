#!/bin/bash
# PreToolUse on Bash | Read | Grep | Glob — soft nudge to post a Plan comment
# within minutes of claim. Does NOT block; injects additionalContext that
# escalates from gentle reminder to "you're wandering" based on claim age.
#
# Why: sessions claim issues (e.g. #496) and silently work on them for 30+
# min with no Plan comment posted. From outside, indistinguishable from
# wandering. The existing require-plan-comment.sh blocks `git commit` if no
# Plan is posted, but if the session never reaches commit (crashes, gets
# distracted, hits API timeout), no friction at all. This hook adds early
# signal — every Bash/Read/Grep call past 5 min reminds the model.
#
# Cost: 1 file read + 1 cache check per call. ~1 `gh issue view` per claim
# (cached after first hit), so amortized cost is near-zero.
#
# Skips entirely when:
#   - DRIFT_AUTONOMOUS != 1 (humans free)
#   - session type is not senior/junior (planning bypasses)
#   - sprint-state.in_progress is null (no active claim)
#   - sprint-state.claim_started is unset (legacy claim)
#   - claim age < 5 min (orientation phase)
#   - Plan comment cached as posted

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
case "$TOOL_NAME" in
    Bash|Read|Grep|Glob) ;;
    *) exit 0 ;;
esac

# Only autopilot
[ "${DRIFT_AUTONOMOUS:-0}" = "1" ] || exit 0

# Only senior/junior
SESSION_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "")
case "$SESSION_TYPE" in
    senior|junior) ;;
    *) exit 0 ;;
esac

STATE_FILE="$HOME/drift-state/sprint-state.json"
[ -f "$STATE_FILE" ] || exit 0

NUM=$(jq -r '.in_progress // empty' "$STATE_FILE" 2>/dev/null || echo "")
CT=$(jq -r '.claim_started // empty' "$STATE_FILE" 2>/dev/null || echo "")
[ -z "$NUM" ] || [ "$NUM" = "null" ] && exit 0
[ -z "$CT" ] || [ "$CT" = "null" ] && exit 0

NOW=$(date +%s)
AGE_MIN=$(( (NOW - CT) / 60 ))
[ "$AGE_MIN" -lt 5 ] && exit 0

# Cache: once Plan was seen, skip the gh call until claim changes
CACHE_DIR="$HOME/drift-state/plan-posted"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/${NUM}"
if [ -f "$CACHE_FILE" ]; then exit 0; fi

# Single gh call per claim — same Plan regex as require-plan-comment.sh
HAS_PLAN=$(gh issue view "$NUM" --json comments --jq '.comments[].body' 2>/dev/null \
    | grep -ciE '^[[:space:]]*(plan|approach|investigation|progress|resolution)[[:space:]]*[:-]' \
    || echo "0")
if [ "$HAS_PLAN" -gt 0 ]; then
    touch "$CACHE_FILE"
    exit 0
fi

# Three escalation tiers — same gh issue comment recipe at every tier
RECIPE="gh issue comment $NUM --body 'Plan: <root cause> — <fix approach> — touches <files>'"
if [ "$AGE_MIN" -lt 10 ]; then
    MSG="FYI: ${AGE_MIN} min into #${NUM} with no Plan comment yet. Post one before continuing: ${RECIPE}. Skip if already posted."
elif [ "$AGE_MIN" -lt 15 ]; then
    MSG="POST PLAN NOW: ${AGE_MIN} min into #${NUM}, no Plan visible on the issue. Other sessions and humans can not see what you are doing. Run: ${RECIPE}"
else
    MSG="WANDERING ALERT: ${AGE_MIN} min into #${NUM} with no Plan. Post the Plan immediately OR run scripts/sprint-service.sh unclaim ${NUM} if you do not actually have one yet. Recipe: ${RECIPE}"
fi

cat <<ENDJSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"${MSG}"}}
ENDJSON
exit 0
