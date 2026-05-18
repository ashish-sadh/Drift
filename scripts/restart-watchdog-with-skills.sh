#!/bin/bash
# Restart the Drift watchdog with DRIFT_USE_SKILLS=1.
#
# Use this after a clean DRAIN (when watchdog has exited between sessions).
# Safety check: refuses to start if a watchdog is already running.
#
# Usage:
#   echo DRAIN > ~/drift-control.txt          # graceful stop
#   # wait for "self-improve-watchdog.sh" process to exit (pgrep check)
#   scripts/restart-watchdog-with-skills.sh   # start fresh with new env
#
# Rollback (return to legacy harness):
#   echo DRAIN > ~/drift-control.txt
#   # wait for exit
#   scripts/restart-watchdog-with-skills.sh --legacy

set -e

WORK_DIR="/Users/ashishsadh/workspace/Drift"
WATCHDOG="$WORK_DIR/scripts/self-improve-watchdog.sh"

# Safety: refuse if watchdog is running
if pgrep -f "self-improve-watchdog.sh" > /dev/null; then
    echo "ERROR: a watchdog is already running. Drain it first:"
    echo "  echo DRAIN > ~/drift-control.txt"
    echo "  # wait for: pgrep -f self-improve-watchdog.sh  to return nothing"
    exit 1
fi

# Determine mode
USE_SKILLS=1
if [ "${1:-}" = "--legacy" ]; then
    USE_SKILLS=0
fi

# Set RUN before spawning so the watchdog doesn't immediately drain again
echo "RUN" > "$HOME/drift-control.txt"

# Spawn watchdog with the desired env
echo "Starting watchdog with DRIFT_USE_SKILLS=$USE_SKILLS"
nohup env DRIFT_USE_SKILLS=$USE_SKILLS "$WATCHDOG" > "$HOME/drift-self-improve-logs/watchdog-restart.log" 2>&1 &
WD_PID=$!
echo "Watchdog PID: $WD_PID"
echo "Logs: tail -f $HOME/drift-self-improve-logs/watchdog.log"
