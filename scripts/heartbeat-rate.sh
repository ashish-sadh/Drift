#!/bin/bash
# Measure heartbeat-commits-per-real-commit ratio on main over a window.
# Was: #758. The watchdog used to land `chore: heartbeat snapshot` commits
# on main (~5 per real commit at the historical rate); that's been moved
# to the `heartbeat-data` side branch, so on a healthy repo this ratio
# trends to 0 over time.
#
# Usage:
#   scripts/heartbeat-rate.sh [WINDOW_HOURS=24] [TARGET=3]
#
# Exit codes:
#   0  ratio ≤ TARGET   (acceptable noise)
#   1  ratio > TARGET   (regression — heartbeats are landing on main again)
#   2  no real commits in the window (can't compute; treat as inconclusive)

set -euo pipefail

WINDOW_HOURS="${1:-24}"
TARGET="${2:-3}"

NOW=$(date +%s)
SINCE=$(( NOW - WINDOW_HOURS * 3600 ))

# git log --since accepts a "@<epoch>" form on modern git.
HEARTBEATS=$(git log --since="@$SINCE" --pretty=format:"%s" 2>/dev/null \
    | grep -c "^chore: heartbeat snapshot$" || true)
TOTAL=$(git log --since="@$SINCE" --pretty=format:"%s" 2>/dev/null \
    | wc -l | tr -d ' ')
REAL=$(( TOTAL - HEARTBEATS ))

if (( REAL == 0 )); then
    printf "heartbeat-rate: %d heartbeats / 0 real commits in last %dh — inconclusive\n" \
        "$HEARTBEATS" "$WINDOW_HOURS"
    exit 2
fi

# Integer ratio with 2 decimal places (avoid bc dependency).
RATIO_X100=$(( (HEARTBEATS * 100) / REAL ))
TARGET_X100=$(( TARGET * 100 ))

printf "heartbeat-rate: %d heartbeats / %d real commits in last %dh — ratio: %d.%02d (target ≤ %d)\n" \
    "$HEARTBEATS" "$REAL" "$WINDOW_HOURS" \
    "$(( RATIO_X100 / 100 ))" "$(( RATIO_X100 % 100 ))" "$TARGET"

if (( RATIO_X100 <= TARGET_X100 )); then
    exit 0
else
    exit 1
fi
