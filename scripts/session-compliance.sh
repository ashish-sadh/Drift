#!/bin/bash
# session-compliance.sh — called after every session exit (clean or crash)
# Writes last-session-summary.md and appends to Obsidian session log.
# Must be called BEFORE cleanup_dirty_state so in-progress state is still readable.
#
# Usage: session-compliance.sh <session-type> <model> <exit-reason>
#   exit-reason: normal | crash | stall

set -uo pipefail

WORK_DIR="/Users/ashishsadh/workspace/Drift"
STATE_DIR="$HOME/drift-state"
OBSIDIAN_DIR="$HOME/drift-knowledge"
FEEDBACK_LOG="$STATE_DIR/process-feedback.log"
STATE_FILE="$STATE_DIR/sprint-state.json"

mkdir -p "$STATE_DIR" "$OBSIDIAN_DIR/Sessions"

SESSION_TYPE="${1:-unknown}"
MODEL="${2:-unknown}"
EXIT_REASON="${3:-normal}"

TS=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

# Close overhead tracking issue (created by session-start.sh hook at session start)
OVERHEAD_N=$(cat "$STATE_DIR/current-overhead-issue" 2>/dev/null | tr -d '[:space:]')
if [[ -n "$OVERHEAD_N" ]] && [[ "$OVERHEAD_N" =~ ^[0-9]+$ ]]; then
    LAST_COMMIT=$(cd "$WORK_DIR" && git rev-parse HEAD 2>/dev/null || echo "no-commit")
    gh issue comment "$OVERHEAD_N" \
      --body "Session ended ($EXIT_REASON). Last commit: $LAST_COMMIT" 2>/dev/null || true
    gh issue close "$OVERHEAD_N" 2>/dev/null || true
    rm -f "$STATE_DIR/current-overhead-issue"
elif [[ -n "$OVERHEAD_N" ]]; then
    echo "[$TS] session-compliance: WARNING invalid overhead issue number '$OVERHEAD_N' — skipping close" >&2
    rm -f "$STATE_DIR/current-overhead-issue"
fi

# Recent commits from this session (last 2 hours)
COMMITS=$(cd "$WORK_DIR" && git log --oneline --since="2 hours ago" 2>/dev/null | head -10 || true)

# Currently claimed in-progress task — readable before cleanup_dirty_state clears it
INTERRUPTED=$(python3 - "$STATE_FILE" 2>/dev/null <<'PYEOF' || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    ip = d.get("in_progress")
    if ip:
        title = next((t["title"] for t in d.get("tasks", []) if t["number"] == ip), "")
        print(f"#{ip} {title}")
except json.JSONDecodeError as e:
    print(f"WARNING: state file corrupted ({e}) — interrupted task unknown", file=sys.stderr)
except Exception:
    pass
PYEOF
)

# Numeric-only version for git branch naming etc.
INTERRUPTED_NUM=$(echo "$INTERRUPTED" | grep -oE '^#[0-9]+' | tr -d '#')

# Preserve uncommitted work on crash/stall — write it to a `crashed/<N>-<ts>`
# branch and label the issue with `resumable` so the next senior session
# (or a human) can pick up where the crashed session left off. Without this,
# session-compliance + cleanup_dirty_state combo wipes legitimate work just
# because the session got an API stream timeout or hit a budget edge before
# it could commit. (Observed 2026-04-27: #426 lost SleepFoodCorrelationTool
# + 6 file edits; #418 lost FoodTimingInsightTool. Both were genuine work
# 60 min in, killed by Anthropic API stream idle timeout.)
if [[ "$EXIT_REASON" == "crash" || "$EXIT_REASON" == "stall" ]] && [[ -n "$INTERRUPTED_NUM" ]]; then
    cd "$WORK_DIR" || true
    # Filter out auto-managed paths so heartbeat/graphify churn alone doesn't
    # trigger preservation. We only care about real session work.
    DIRTY_REAL=$(git status --porcelain 2>/dev/null | grep -vE 'command-center/heartbeat\.json|graphify-out/' || true)
    if [[ -n "$DIRTY_REAL" ]]; then
        CRASH_BRANCH="crashed/${INTERRUPTED_NUM}-$(date +%s)"
        echo "[$TS] session-compliance: preserving WIP for #${INTERRUPTED_NUM} on $CRASH_BRANCH"
        if git checkout -b "$CRASH_BRANCH" 2>/dev/null \
           && git add -A 2>/dev/null \
           && git -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
              commit --no-verify -m "WIP: crashed session work for #${INTERRUPTED_NUM}

Auto-preserved by session-compliance.sh ($EXIT_REASON exit).
Session: $SESSION_TYPE ($MODEL)
Time: $TS

Recover: git checkout $CRASH_BRANCH" 2>/dev/null \
           && git push origin "$CRASH_BRANCH" 2>/dev/null; then
            gh issue edit "$INTERRUPTED_NUM" --add-label resumable 2>>"$STATE_DIR/gh-errors.log" || true
            gh issue comment "$INTERRUPTED_NUM" \
              --body "Resumable: crashed session WIP preserved on branch \`$CRASH_BRANCH\`. Next session can \`git checkout $CRASH_BRANCH\` to continue, then merge back via PR. Crash exit reason: \`$EXIT_REASON\`." \
              2>>"$STATE_DIR/gh-errors.log" || true
            echo "[$TS] session-compliance: preserved + labeled #${INTERRUPTED_NUM} resumable"
        else
            echo "[$TS] session-compliance: WARN failed to preserve crashed work for #${INTERRUPTED_NUM}" >&2
        fi
        # Always return to main so cleanup_dirty_state operates on the right branch
        git checkout main 2>/dev/null || true
    fi
fi

# Write last-session-summary.md (next session reads this at startup)
SUMMARY_FILE="$STATE_DIR/last-session-summary.md"
cat > "$SUMMARY_FILE" <<EOF
# Last Session Summary

**Session type:** $SESSION_TYPE
**Model:** $MODEL
**Ended:** $TS
**Exit reason:** $EXIT_REASON

## Recent Commits (this session)

${COMMITS:-None recorded}

## Interrupted Task

${INTERRUPTED:-None}
EOF

# Append to Obsidian session log
OBSIDIAN_SESSION="$OBSIDIAN_DIR/Sessions/$TODAY.md"
if [[ ! -f "$OBSIDIAN_SESSION" ]]; then
    printf "# Sessions — %s\n" "$TODAY" > "$OBSIDIAN_SESSION"
fi

cat >> "$OBSIDIAN_SESSION" <<EOF

## $SESSION_TYPE ($MODEL) — $TS — exit: $EXIT_REASON

### Commits
${COMMITS:-none}

### Interrupted
${INTERRUPTED:-none}

---
EOF

# Log abnormal exits to process-feedback (planning session drains this)
if [[ "$EXIT_REASON" == "crash" ]] || [[ "$EXIT_REASON" == "stall" ]]; then
    echo "$TS | compliance | $SESSION_TYPE ($MODEL) exited via $EXIT_REASON — interrupted: ${INTERRUPTED:-none}" >> "$FEEDBACK_LOG" 2>/dev/null || true
fi

echo "[$TS] session-compliance: $SESSION_TYPE ($MODEL, $EXIT_REASON) — summary written"
