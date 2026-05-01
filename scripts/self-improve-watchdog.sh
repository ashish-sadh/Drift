#!/bin/bash
# Drift Control — Watchdog for Autopilot
# Manages autonomous Autopilot sessions. Restarts on crash/stall.
# Controlled via ~/drift-control.txt.
#
# Usage: ./scripts/self-improve-watchdog.sh
# Stop:  echo "STOP" > ~/drift-control.txt
# Pause: echo "PAUSE" > ~/drift-control.txt
# Drain: echo "DRAIN" > ~/drift-control.txt
# Run:   echo "RUN" > ~/drift-control.txt

set -euo pipefail

# shellcheck source=lib/atomic-write.sh
source "$(dirname "$0")/lib/atomic-write.sh"

# Kill any existing watchdog (prevent duplicates)
EXISTING=$(pgrep -f "self-improve-watchdog.sh" | grep -v $$ || true)
if [ -n "$EXISTING" ]; then
    echo "$EXISTING" | xargs kill 2>/dev/null || true
    sleep 1
fi

WORK_DIR="/Users/ashishsadh/workspace/Drift"
CONTROL_FILE="$HOME/drift-control.txt"
LOG_DIR="$HOME/drift-self-improve-logs"
WATCHDOG_LOG="$LOG_DIR/watchdog.log"
PID_FILE="$LOG_DIR/claude.pid"
CHECK_INTERVAL=60   # 1 minute — heartbeat: sprint refresh + health check
STALE_THRESHOLD=1800  # 30 minutes — no heartbeat/log output = definitely dead
# Per-session stall thresholds (no commits/progress before nudge)
STALL_PLANNING=3600  # 1 hour
STALL_SENIOR=1800    # 30 minutes
STALL_JUNIOR=1800    # 30 minutes
NUDGE_WAIT=300       # 5 minutes after nudge before killing
# Commit-rate stall: senior/junior that has produced 0 commits to main this long = stuck
COMMIT_STALL=10800   # 3 hours — genuinely-hard bugs sometimes take this long, but 0 commits past this is a tarpit
KILL_WAIT=10
CRASH_FILE="$HOME/drift-state/consecutive-crashes"
# Stable-run reset threshold (gbrain supervisor.ts pattern): if a session was
# alive for this long before crashing, treat it as a transient flake and
# reset the consecutive-crashes counter to 0. Prevents the "5-min flap" mode
# where 5 long-stable runs that each happened to crash at the end get
# escalated as if it were a broken config.
STABLE_RUN_THRESHOLD=300
MONITOR_PID=""

PROMPT="run autopilot"
CLAUDE_PID=""
SESSION_STARTED_AT=0
CURRENT_LOG=""

mkdir -p "$LOG_DIR"

# Ignore SIGPIPE — observed root cause of recurring watchdog deaths. Without
# this, any pipeline that loses its reader (file rotation, launchd stdout
# buffer issue, etc.) propagates SIGPIPE to the watchdog shell and bash exits
# with 141. Each watchdog death triggers its own signal handler which kills
# the active senior session — that's the "sessions dying every 2 min"
# pattern observed 2026-04-28 (5 watchdog respawns / hour).
trap '' PIPE

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    # Direct writes — no `tee` pipeline. Was: `echo "$msg" | tee -a "$LOG"`.
    # The pipeline was the SIGPIPE vector: launchd captures stdout into a
    # rotated file, and an unfortunate combination of buffering + rotation
    # would close tee's stdout reader, propagate SIGPIPE up to the script,
    # and kill the watchdog mid-cycle.
    echo "$msg" >> "$WATCHDOG_LOG"
    echo "$msg"
}

get_model() {
    local SESSION_TYPE="$1"
    local DEFAULT="$2"
    local CONFIG="$HOME/drift-state/model-config"
    if [[ -f "$CONFIG" ]]; then
        local OVERRIDE=$(grep "^${SESSION_TYPE}=" "$CONFIG" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
        [[ -n "$OVERRIDE" ]] && echo "$OVERRIDE" && return
    fi
    echo "$DEFAULT"
}

read_control() {
    if [[ -f "$CONTROL_FILE" ]]; then
        tr -d '[:space:]' < "$CONTROL_FILE" | tr '[:lower:]' '[:upper:]'
    else
        echo "RUN"
    fi
}

run_compliance() {
    local EXIT_REASON="${1:-normal}"  # normal | crash | stall
    local COMP_TYPE
    COMP_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "unknown")
    local COMP_MODEL
    COMP_MODEL=$(cat "$HOME/drift-state/last-model" 2>/dev/null || echo "unknown")
    "$WORK_DIR/scripts/session-compliance.sh" "$COMP_TYPE" "$COMP_MODEL" "$EXIT_REASON" 2>/dev/null || true
    log "Session compliance: $COMP_TYPE ($COMP_MODEL, $EXIT_REASON)"
}

cleanup_dirty_state() {
    cd "$WORK_DIR"
    # Abort interrupted merges/rebases
    git merge --abort 2>/dev/null || true
    git rebase --abort 2>/dev/null || true
    # Drop stashes left by crashed sessions
    git stash drop 2>/dev/null || true

    # Fix B: stale-branch sweep. If the prior session crashed mid-report-flow
    # (review/cycle-N or report/exec-DATE branch was created, work was done,
    # but `report-service.sh finish` never ran to switch back), HEAD is left
    # on the feature branch. Operator-mode sessions then accidentally land
    # commits on the stale branch instead of main. Switch back proactively.
    local CURRENT_BRANCH
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "main" ]]; then
        log "Stale branch: HEAD on $CURRENT_BRANCH (probably from a crashed report flow). Switching back to main."
        git checkout main 2>/dev/null || true
        git pull --ff-only origin main 2>/dev/null || true
    fi

    local DIRTY=$(git status --porcelain 2>/dev/null | head -20)
    if [[ -n "$DIRTY" ]]; then
        log "Dirty state after session exit. Discarding incomplete changes:"
        log "$DIRTY"
        git checkout . 2>/dev/null || true
        git clean -fd --exclude=.claude/ 2>/dev/null || true
        log "Working tree cleaned."
    fi

    # Remove stale in-progress labels — no session is running, nothing is in-progress
    # Sprint service atomically clears all in-progress (state file + GitHub labels)
    "$WORK_DIR/scripts/sprint-service.sh" clear 2>/dev/null || true
    log "Sprint service: cleared in-progress state"

    # Remove stale TestFlight authorization — a crashed session may have left this set
    # without completing the publish. Next session gets a fresh authorization flow.
    rm -f "$HOME/drift-state/testflight-publish-authorized"

    # Fix C: orphan WIP patch sweep. snapshot_wip_if_in_progress only cleans
    # patches when the current claim's tree goes empty. Patches for issues
    # that closed via `gh issue close` (bypassing cmd_done) or via watchdog
    # reconcile, OR claims that got unclaimed before commit, leak forever.
    # Observed 2026-04-28: 345.patch lingered for hours after #345 was
    # unclaimed without going through cmd_done. Sweep at startup: any patch
    # whose issue is closed → delete; any patch >7 days old → delete.
    local WIP_DIR="$HOME/drift-state/wip"
    if [[ -d "$WIP_DIR" ]]; then
        local now_ts
        now_ts=$(date +%s)
        for patch in "$WIP_DIR"/*.patch; do
            [[ -f "$patch" ]] || continue
            local num
            num=$(basename "$patch" .patch)
            [[ "$num" =~ ^[0-9]+$ ]] || continue
            local age_days
            age_days=$(( (now_ts - $(stat -f %m "$patch" 2>/dev/null || echo "$now_ts")) / 86400 ))
            if [[ "$age_days" -gt 7 ]]; then
                log "WIP cleanup: $patch is ${age_days}d old, removing."
                rm -f "$patch" "$WIP_DIR/${num}.untracked.tar.gz"
                continue
            fi
            local issue_state
            issue_state=$(gh issue view "$num" --json state --jq '.state' 2>/dev/null || echo "")
            if [[ "$issue_state" == "CLOSED" ]]; then
                log "WIP cleanup: #$num is CLOSED, removing $patch."
                rm -f "$patch" "$WIP_DIR/${num}.untracked.tar.gz"
            fi
        done
    fi
}

kill_claude() {
    if [[ -n "$CLAUDE_PID" ]] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
        log "Sending SIGTERM to claude (PID $CLAUDE_PID)..."
        kill "$CLAUDE_PID" 2>/dev/null || true
        local waited=0
        while kill -0 "$CLAUDE_PID" 2>/dev/null && (( waited < KILL_WAIT )); do
            sleep 1
            (( waited++ ))
        done
        if kill -0 "$CLAUDE_PID" 2>/dev/null; then
            log "SIGTERM didn't work, sending SIGKILL..."
            kill -9 "$CLAUDE_PID" 2>/dev/null || true
        fi
        log "Claude process stopped."
        stop_monitor
    fi
    CLAUDE_PID=""
}

MONITOR_PID_FILE="$LOG_DIR/monitor.pid"

start_monitor() {
    stop_monitor
    local ISSUE_NUM=$(cat "$HOME/drift-state/live-status-issue" 2>/dev/null || echo "")
    if [[ -z "$ISSUE_NUM" ]] || ! gh issue view "$ISSUE_NUM" --json state --jq '.state' 2>/dev/null | grep -q "OPEN"; then
        ISSUE_NUM=$(gh issue create --title "Drift Live Status" --label live-status --body "Starting..." --json number --jq '.number' 2>/dev/null || echo "")
        [[ -n "$ISSUE_NUM" ]] && echo "$ISSUE_NUM" > "$HOME/drift-state/live-status-issue"
    fi
    if [[ -n "$ISSUE_NUM" ]] && [[ -n "$CURRENT_LOG" ]]; then
        "$WORK_DIR/scripts/session-monitor.sh" "$CURRENT_LOG" "$ISSUE_NUM" &
        MONITOR_PID=$!
        echo "$MONITOR_PID" > "$MONITOR_PID_FILE"
        log "Monitor started (PID $MONITOR_PID, issue #$ISSUE_NUM)"
    fi
}

stop_monitor() {
    # Kill by PID variable first, then by PID file (survives watchdog restart)
    if [[ -n "$MONITOR_PID" ]] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null || true
    fi
    local SAVED_PID=$(cat "$MONITOR_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$SAVED_PID" ]] && kill -0 "$SAVED_PID" 2>/dev/null; then
        kill "$SAVED_PID" 2>/dev/null || true
    fi
    # Also kill any orphaned monitors
    pkill -f "session-monitor.sh" 2>/dev/null || true
    MONITOR_PID=""
    rm -f "$MONITOR_PID_FILE"
}

# Reconcile cadence stamps against what actually shipped on main. The
# planning/review/report gates all key off these stamps; a session that
# merges without going through the service script leaves its stamp stale
# and the gate fires forever. Idempotent — only bumps a stamp forward.
sync_stamps_from_main() {
    cd "$WORK_DIR" || return
    local SD="$HOME/drift-state"

    # Most recent review cycle merge → last-review-time
    local review_last
    review_last=$(git log origin/main --format='%ct' --grep='^review-cycle-' -1 2>/dev/null || echo "")
    if [[ -n "$review_last" ]]; then
        local review_stamp
        review_stamp=$(cat "$SD/last-review-time" 2>/dev/null || echo "0")
        if (( review_last > review_stamp )); then
            atomic_write "$SD/last-review-time" "$review_last"
            log "Self-heal: bumped last-review-time $review_stamp → $review_last (from merged review commit)"
        fi
    fi

    # Self-heal last-review-cycle: when the cycle stamp is missing, set it to
    # (cycle - INTERVAL) so the very next sprint planning session does the
    # review. Avoids the 3036-cycle drift failure mode permanently.
    local INTERVAL="${PRODUCT_REVIEW_CYCLE_INTERVAL:-20}"
    local cycle_now
    cycle_now=$(cat "$SD/cycle-counter" 2>/dev/null || echo "0")
    if [[ ! -s "$SD/last-review-cycle" ]] && (( cycle_now > 0 )); then
        local seed=$(( cycle_now - INTERVAL ))
        (( seed < 0 )) && seed=0
        atomic_write "$SD/last-review-cycle" "$seed"
        log "Self-heal: stamped last-review-cycle = $seed (cycle_now=$cycle_now, interval=$INTERVAL) so next planning does the review"
    fi

    # Most recent exec report merge → last-report-time. Matches the squash-
    # merge subject `Daily Briefing — YYYY-MM-DD` (with optional `chore:` prefix)
    # plus the legacy `report/exec-` merge-commit form.
    local exec_last
    exec_last=$(git log origin/main --format='%ct' --grep='Daily Briefing\|report/exec-' -1 2>/dev/null || echo "")
    if [[ -n "$exec_last" ]]; then
        local exec_stamp
        exec_stamp=$(cat "$SD/last-report-time" 2>/dev/null || echo "0")
        if (( exec_last > exec_stamp )); then
            atomic_write "$SD/last-report-time" "$exec_last"
            log "Self-heal: bumped last-report-time $exec_stamp → $exec_last (from merged exec commit)"
        fi
    fi

    # Planning issue closed since we last checked → last-planning-time
    local plan_issue
    plan_issue=$(cat "$SD/planning-issue" 2>/dev/null || echo "")
    if [[ -n "$plan_issue" ]]; then
        local plan_state
        plan_state=$(gh issue view "$plan_issue" --json state --jq '.state' 2>/dev/null || echo "")
        if [[ "$plan_state" == "CLOSED" ]]; then
            atomic_write "$SD/last-planning-time" "$(date +%s)"
            rm -f "$SD/planning-issue"
            log "Self-heal: planning Issue #$plan_issue is CLOSED — stamped last-planning-time and cleared tracking file"
        fi
    fi

    # Most recent TestFlight build commit → last-testflight-publish. Same
    # pattern as review/exec — the hook's step-5a stamp is fragile, we
    # derive from git instead.
    local tf_last
    tf_last=$(git log origin/main --format='%ct' --grep='^chore: TestFlight build' -1 2>/dev/null || echo "")
    if [[ -n "$tf_last" ]]; then
        local tf_stamp
        tf_stamp=$(cat "$SD/last-testflight-publish" 2>/dev/null || echo "0")
        if (( tf_last > tf_stamp )); then
            atomic_write "$SD/last-testflight-publish" "$tf_last"
            log "Self-heal: bumped last-testflight-publish $tf_stamp → $tf_last (from TestFlight commit)"
        fi
    fi
}

# Reconcile sprint-state.json against GitHub. If our local in_progress slot
# points to a task that's already CLOSED on GitHub, the session closed it
# without calling sprint-service.sh done — the slot stays stuck, blocking
# the next claim. Running `done` again is safe (idempotent on comment/close/
# label strip) and also applies the budget increment we missed.
reconcile_in_progress() {
    local SD="$HOME/drift-state"
    local STATE_FILE="$SD/sprint-state.json"
    [[ -f "$STATE_FILE" ]] || return
    local IN_PROGRESS
    IN_PROGRESS=$(jq -r '.in_progress // empty' "$STATE_FILE" 2>/dev/null || echo "")
    [[ -z "$IN_PROGRESS" || "$IN_PROGRESS" == "null" ]] && return

    local STATE
    STATE=$(gh issue view "$IN_PROGRESS" --json state --jq '.state' 2>/dev/null || echo "")
    if [[ "$STATE" == "CLOSED" ]]; then
        log "Self-heal: in_progress #$IN_PROGRESS is CLOSED on GitHub — reconciling via done"
        "$WORK_DIR/scripts/sprint-service.sh" done "$IN_PROGRESS" "reconcile" >/dev/null 2>&1 || true
    fi
}

# Stale-claim detection — flag issues claimed >threshold ago with no progress.
#
# "Progress" = either a commit referencing #N in its message, or any new
# comment on the issue, both since claim_started. If neither happened in
# the last hour (default), the claim is presumed stuck — auto-flag the
# issue with `needs-review` (which excludes it from `next --senior/junior`),
# comment, and unclaim locally so the next session can move on.
#
# Solves two failure modes:
#   1. Sessions getting stuck on impossible tasks (e.g. #469 telemetry
#      analysis with no telemetry). They thrash for an hour, get flagged,
#      human reviews, closes as wontfix.
#   2. Hung/wandering sessions that bypass the claim hook somehow — no
#      commits, no comments, just exploration → flagged.
#
# Threshold: DRIFT_CLAIM_STALE_THRESHOLD_SECS env var, default 5400 (90 min).
# Was 3600 (60 min) — bumped after #426 false-positive: session shipped 7
# real edits over 60 min, hit Anthropic API stream timeout right at the 1h
# mark, never committed, got auto-flagged at 61 min. Complex senior tasks
# (multi-file refactor, new tool with tests) legitimately need 60-90 min
# before first commit. The 90-min threshold gives breathing room while
# still catching genuinely stuck claims within 1.5h.
check_stale_claim() {
    local SD="$HOME/drift-state"
    local STATE_FILE="$SD/sprint-state.json"
    [[ -f "$STATE_FILE" ]] || return

    local NUM CLAIM_TS
    NUM=$(jq -r '.in_progress // empty' "$STATE_FILE" 2>/dev/null || echo "")
    [[ -z "$NUM" || "$NUM" == "null" ]] && return
    CLAIM_TS=$(jq -r '.claim_started // empty' "$STATE_FILE" 2>/dev/null || echo "")
    [[ -z "$CLAIM_TS" || "$CLAIM_TS" == "null" ]] && return  # legacy claim, skip

    local NOW AGE THRESHOLD
    NOW=$(date +%s)
    AGE=$(( NOW - CLAIM_TS ))
    THRESHOLD=${DRIFT_CLAIM_STALE_THRESHOLD_SECS:-5400}
    (( AGE < THRESHOLD )) && return

    # Any commit referencing #N in its message since claim_started?
    local COMMITS
    COMMITS=$(cd "$WORK_DIR" && git log --since="@$CLAIM_TS" --grep="#$NUM" --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COMMITS" -gt 0 ]]; then
        return
    fi

    # Any real edits in the working tree? — third progress signal alongside
    # commits + comments. A session 60 min into a multi-file change with no
    # commit yet should not be flagged. Filter out auto-managed paths so
    # heartbeat/graphify churn alone doesn't count as progress (those run
    # in the watchdog itself, unrelated to session work).
    # Bug history: #426 + #418 both lost real work because the auto-flag
    # fired despite legitimate file edits sitting in the working tree.
    local REAL_EDITS
    REAL_EDITS=$(cd "$WORK_DIR" && git status --porcelain 2>/dev/null \
        | grep -vE 'command-center/heartbeat\.json|graphify-out/|\.xcodeproj/' \
        | wc -l | tr -d ' ')
    if [[ "$REAL_EDITS" -gt 0 ]]; then
        return
    fi

    # Any new comment on the issue since claim_started? (RFC3339 → epoch via python)
    local LATEST_COMMENT_TS
    LATEST_COMMENT_TS=$(gh issue view "$NUM" --json comments \
        --jq '[.comments[].createdAt] | sort | last // ""' 2>/dev/null \
        | python3 -c "
import sys
from datetime import datetime
s = sys.stdin.read().strip().strip('\"')
if not s: print(0); sys.exit()
try:
    print(int(datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()))
except Exception:
    print(0)
" 2>/dev/null || echo "0")
    if [[ "$LATEST_COMMENT_TS" -gt "$CLAIM_TS" ]]; then
        return
    fi

    # Stale — flag it. `needs-review` is the only label needed: it gates
    # next --senior/junior so the queue stops returning this issue, and
    # signals "human, look at this" semantically. Earlier version also
    # added `blocked` but that was redundant decoration AND created an
    # atomicity bug — `gh issue edit --add-label X --add-label Y` is
    # atomic, so when `blocked` didn't exist in the repo the whole call
    # failed silently and `needs-review` never landed. (Observed 2026-04-26
    # on #449: 7 auto-flag attempts in 10h, none actually labeled.)
    log "Stale-claim: #$NUM claimed ${AGE}s ago (threshold ${THRESHOLD}s), no commits referencing #$NUM, no new comments. Auto-flagging."
    if ! gh issue edit "$NUM" --add-label needs-review 2>>"$HOME/drift-state/gh-errors.log"; then
        log "Stale-claim: WARN — failed to add needs-review label on #$NUM (see gh-errors.log)"
    fi
    gh issue comment "$NUM" --body "Auto-flagged stale claim — claimed for ${AGE}s with no commits referencing #${NUM} and no new activity. Review and unblock, close, or reassign." >/dev/null 2>&1 || true
    "$WORK_DIR/scripts/sprint-service.sh" unclaim "$NUM" >/dev/null 2>&1 || true
}

# Periodic WIP snapshot — every tick, if there's a claimed issue and the
# working tree has real edits, save the current diff to
# ~/drift-state/wip/<N>.patch (overwrite). On crash, session-compliance
# reads this file to label the issue resumable + post the recovery path.
# On clean exit (cmd_done), sprint-service.sh deletes the patch. Keeps
# WIP recoverable to within ~30 sec without git branch ceremony.
snapshot_wip_if_in_progress() {
    local SD="$HOME/drift-state"
    local STATE_FILE="$SD/sprint-state.json"
    [[ -f "$STATE_FILE" ]] || return

    local NUM
    NUM=$(jq -r '.in_progress // empty' "$STATE_FILE" 2>/dev/null || echo "")
    [[ -z "$NUM" || "$NUM" == "null" ]] && return

    # Design-doc work has no working-tree state to snapshot — the deliverable
    # is a PR with the doc, not local edits. Skip WIP capture entirely.
    # Also avoids the path-with-slash bug ("design/561" → wip/design/561.patch
    # whose subdir wasn't mkdir'd) that crash-looped the watchdog on 2026-05-01.
    [[ "$NUM" == */* ]] && return

    cd "$WORK_DIR" || return
    local REAL_EDITS
    # Tame grep's exit-1-on-no-match (which would propagate through pipefail
    # and kill the watchdog) by wrapping grep specifically with `|| true`.
    # Earlier defensive wrap `{ ... } || echo 0` produced "0\n0" because the
    # inner block had already printed "0" before failing — broke the
    # arithmetic test below.
    REAL_EDITS=$(git status --porcelain 2>/dev/null \
        | { grep -vE 'command-center/heartbeat\.json|graphify-out/|\.xcodeproj/' || true; } \
        | wc -l | tr -d ' ')
    if [[ "$REAL_EDITS" -eq 0 ]]; then
        # No real edits — remove any stale patch (issue was claimed, work
        # got committed since last tick, patch no longer reflects WIP)
        rm -f "$SD/wip/${NUM}.patch"
        return
    fi

    mkdir -p "$SD/wip"

    # Tracked changes → standard `git apply`-compatible patch (binary-safe).
    git diff HEAD --binary > "$SD/wip/${NUM}.patch.tmp" 2>/dev/null
    mv "$SD/wip/${NUM}.patch.tmp" "$SD/wip/${NUM}.patch"

    # Untracked files → tarball (git diff doesn't capture them). Filter out
    # noise paths the same way as the edit-detection above.
    local UNTRACKED
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null \
        | grep -vE 'command-center/heartbeat\.json|graphify-out/|\.xcodeproj/' || true)
    if [[ -n "$UNTRACKED" ]]; then
        echo "$UNTRACKED" | tar -czf "$SD/wip/${NUM}.untracked.tar.gz.tmp" -T - 2>/dev/null
        mv "$SD/wip/${NUM}.untracked.tar.gz.tmp" "$SD/wip/${NUM}.untracked.tar.gz"
    else
        rm -f "$SD/wip/${NUM}.untracked.tar.gz"
    fi
}

# Strip orphan in-progress labels — a closed issue should never carry
# in-progress (always wrong), and an open sprint-task we're not working on
# shouldn't either. Planning and design-doc issues have their own lifecycle
# so we only touch issues labeled sprint-task.
sweep_stale_in_progress_labels() {
    local SD="$HOME/drift-state"
    local current
    current=$(jq -r '.in_progress // empty' "$SD/sprint-state.json" 2>/dev/null || echo "")

    # Closed issues with in-progress — always stale
    local closed_stale
    closed_stale=$(gh issue list --state closed --label in-progress --limit 20 \
        --json number --jq '.[].number' 2>/dev/null || echo "")
    for num in $closed_stale; do
        [[ -n "$num" ]] || continue
        gh issue edit "$num" --remove-label in-progress >/dev/null 2>&1 \
            && log "Self-heal: stripped in-progress from closed #$num"
    done

    # Open sprint-tasks with in-progress that we're not working on
    local open_stale
    open_stale=$(gh issue list --state open --label in-progress --label sprint-task --limit 20 \
        --json number --jq '.[].number' 2>/dev/null || echo "")
    for num in $open_stale; do
        [[ -n "$num" ]] || continue
        # Re-read current right before strip — protects against the race where
        # a session claims #N during this sweep loop. Without this, the sweep
        # could strip a fresh claim using the stale `current` snapshot from
        # the top of the function. (User reported "issues get into in-progress
        # and then watchdog removes etc" — this race was a contributor.)
        local current_now
        current_now=$(jq -r '.in_progress // empty' "$SD/sprint-state.json" 2>/dev/null || echo "")
        if [[ "$num" != "$current_now" ]]; then
            gh issue edit "$num" --remove-label in-progress >/dev/null 2>&1 \
                && log "Self-heal: stripped orphan in-progress from open sprint-task #$num (current=${current_now:-none})"
        fi
    done
}

# Commit heartbeat.json on a hybrid schedule:
#   a) every 10 min if the file changed
#   b) immediately if main HEAD advanced via some other commit (piggyback —
#      since we're pushing anyway, ride along)
# Runs regardless of session liveness so the Pages view doesn't freeze mid-
# session. `git add <specific-file>` is scoped to heartbeat.json only; if
# the session races a push we just retry next tick.
commit_heartbeat_if_due() {
    local hb="$WORK_DIR/command-center/heartbeat.json"
    [[ -f "$hb" ]] || return

    cd "$WORK_DIR" || return

    local SD="$HOME/drift-state"
    local stamp_ts="$SD/last-heartbeat-commit"
    local stamp_head="$SD/last-heartbeat-head"

    local now
    now=$(date +%s)
    local last_commit
    last_commit=$(cat "$stamp_ts" 2>/dev/null || echo "0")
    local elapsed=$(( now - last_commit ))

    local cur_head last_head
    cur_head=$(git rev-parse HEAD 2>/dev/null || echo "")
    last_head=$(cat "$stamp_head" 2>/dev/null || echo "")

    local head_moved=0
    [[ -n "$last_head" && -n "$cur_head" && "$last_head" != "$cur_head" ]] && head_moved=1

    # Neither rule triggered — wait for the next tick.
    if (( elapsed < 600 )) && (( head_moved == 0 )); then
        [[ -n "$cur_head" ]] && echo "$cur_head" > "$stamp_head"
        return
    fi

    # Nothing actually changed in the file — just refresh stamps so we
    # don't keep retrying.
    if git diff --quiet -- command-center/heartbeat.json 2>/dev/null; then
        echo "$now" > "$stamp_ts"
        [[ -n "$cur_head" ]] && echo "$cur_head" > "$stamp_head"
        return
    fi

    git add command-center/heartbeat.json 2>/dev/null || return
    if git commit -m "chore: heartbeat snapshot" >/dev/null 2>&1; then
        if git push origin main >/dev/null 2>&1; then
            local new_head
            new_head=$(git rev-parse HEAD 2>/dev/null || echo "$cur_head")
            echo "$now" > "$stamp_ts"
            echo "$new_head" > "$stamp_head"
            log "Heartbeat snapshot committed + pushed (elapsed=${elapsed}s, piggyback=${head_moved})"
        else
            # Push failed (e.g. behind remote) — undo the commit so we retry cleanly next tick.
            git reset --soft HEAD~1 >/dev/null 2>&1 || true
            git reset -- command-center/heartbeat.json >/dev/null 2>&1 || true
        fi
    fi
}

refresh_compliance_cache() {
    local SD="$HOME/drift-state"
    cd "$WORK_DIR"

    # P0 bugs (all sessions care)
    gh issue list --state open --label P0 --json number,title \
        --jq '.[] | "#\(.number) \(.title)"' > "$SD/cache-p0-bugs" 2>/dev/null || true

    # Open bugs with screenshots (all sessions — must view before fixing)
    gh issue list --state open --label bug --json number,title,body \
        --jq '[.[] | select(.body | test("!\\["))] | .[] | "#\(.number) \(.title) — HAS SCREENSHOT"' \
        > "$SD/cache-bugs-with-screenshots" 2>/dev/null || true

    # P0 feature requests without sprint tasks (senior cares)
    gh issue list --state open --label feature-request --label P0 --json number,title \
        --jq '.[] | "#\(.number) \(.title)"' > "$SD/cache-p0-features" 2>/dev/null || true

    # Design doc PRs with comments needing reply (senior cares)
    gh pr list --label design-doc --state open --json number,title,comments \
        --jq '.[] | select(.comments > 0) | "#\(.number) \(.title) (\(.comments) comments)"' \
        > "$SD/cache-design-reviews" 2>/dev/null || true

    # Pending design docs — issues with design-doc label but no doc-ready (senior cares)
    gh issue list --state open --label design-doc --json number,title,labels \
        --jq '[.[] | select(.labels | map(.name) | index("doc-ready") | not)] | .[] | "#\(.number) \(.title)"' \
        > "$SD/cache-pending-designs" 2>/dev/null || true

    # Admin feedback on report PRs (senior/planning cares)
    gh pr list --label report --state all --json number,title,comments \
        --jq '.[] | select(.comments > 0) | "#\(.number) \(.title) (\(.comments) comments)"' \
        | head -5 > "$SD/cache-admin-feedback" 2>/dev/null || true

    # Design docs awaiting approval (doc-ready but NOT approved — DO NOT IMPLEMENT)
    gh issue list --state open --label design-doc --label doc-ready --json number,title,labels \
        --jq '[.[] | select(.labels | map(.name) | index("approved") | not)] | .[] | "#\(.number) \(.title)"' \
        > "$SD/cache-awaiting-approval" 2>/dev/null || true

    # Approved design docs NOT yet implementing (need task creation first)
    gh issue list --state open --label design-doc --label approved --json number,title,labels \
        --jq '[.[] | select(.labels | map(.name) | index("implementing") | not)] | .[] | "#\(.number) \(.title)"' \
        > "$SD/cache-approved-designs" 2>/dev/null || true

    # In-progress issues (for mark-in-progress hook to detect stale ones)
    gh issue list --state open --label in-progress --json number \
        --jq '.[].number' > "$SD/cache-in-progress" 2>/dev/null || true

    # Product focus
    gh issue list --state open --label product-focus --json body \
        --jq '.[0].body // empty' | head -1 > "$SD/cache-product-focus" 2>/dev/null || true
}

start_claude() {
    local MODEL="sonnet"
    local SESSION_TYPE="junior"
    local SESSION_PROMPT="$PROMPT"

    # Refresh sprint state (single source of truth for session type)
    log "Refreshing sprint state..."
    "$WORK_DIR/scripts/sprint-service.sh" refresh 2>/dev/null || log "Warning: sprint-service refresh failed, using stale state"

    # 0. Resume interrupted planning session (crash recovery — takes priority over all routing)
    local EXISTING_PLAN
    EXISTING_PLAN=$(cat "$HOME/drift-state/planning-issue" 2>/dev/null | tr -d '[:space:]' || true)
    if [[ -n "$EXISTING_PLAN" ]]; then
        local PLAN_STATE
        PLAN_STATE=$(gh issue view "$EXISTING_PLAN" --json state --jq '.state' 2>/dev/null || echo "CLOSED")
        if [[ "$PLAN_STATE" == "OPEN" ]]; then
            MODEL=$(get_model planning opus)
            SESSION_TYPE="planning"
            SESSION_PROMPT="run sprint planning — close Issue #$EXISTING_PLAN when done"
            log "Resuming interrupted planning (Issue #$EXISTING_PLAN) — $MODEL"
        fi
    fi

    if [[ "$SESSION_TYPE" != "planning" ]]; then
    # 1. Planning due?
    if "$WORK_DIR/scripts/sprint-service.sh" planning-due 2>/dev/null; then
        MODEL=$(get_model planning opus)
        SESSION_TYPE="planning"
        # NOTE: last-review-time is stamped by `report-service.sh finish` when a
        # product-review branch is actually merged — NOT here. Writing it at
        # session spawn made `cmd_review_due` believe a review was done every
        # time a planner started, and reviews silently stopped getting written
        # (710-cycle gap observed 2026-04-21).
        log "Sprint planning due — $MODEL"

        local CYCLE=$(cat "$HOME/drift-state/commit-counter" 2>/dev/null || echo "?")
        rm -f "$HOME/drift-state/planning-issue"
        local PLAN_ISSUE=$(gh issue create \
            --title "Sprint Planning — Cycle $CYCLE" \
            --label planning --label SENIOR --label in-progress \
            --body "## Planning Checklist
- [ ] Feedback drained — process-feedback.log reviewed, infra issues created
- [ ] Admin replies — responded to all admin comments on report PRs
- [ ] Product review — review-cycle-${CYCLE}.md PR merged to main
- [ ] Sprint tasks — 8+ sprint-task issues created
- [ ] Personas updated — appended \"What I learned\" to persona files
- [ ] Roadmap updated — applied agreed changes
- [ ] Sprint refreshed — scripts/sprint-service.sh refresh called" \
            --json number --jq '.number' 2>/dev/null || echo "")
        if [[ -n "$PLAN_ISSUE" ]]; then
            log "Created planning tracking Issue #$PLAN_ISSUE"
            echo "$PLAN_ISSUE" > "$HOME/drift-state/planning-issue"
            SESSION_PROMPT="run sprint planning — close Issue #$PLAN_ISSUE when done"
        else
            SESSION_PROMPT="run sprint planning"
        fi

    # 2. P0s, SENIOR tasks, or unhandled P1/P2 bugs? → senior session
    elif [[ "$("$WORK_DIR/scripts/sprint-service.sh" count --p0 2>/dev/null || echo 0)" -gt 0 ]] || \
         [[ "$("$WORK_DIR/scripts/sprint-service.sh" count --senior 2>/dev/null || echo 0)" -gt 0 ]] || \
         [[ "$("$WORK_DIR/scripts/sprint-service.sh" count --bugs 2>/dev/null || echo 0)" -gt 0 ]]; then
        MODEL=$(get_model senior opus)
        SESSION_TYPE="senior"
        SESSION_PROMPT="execute senior tasks and P0 bugs"
        log "P0/SENIOR/bug work available — $MODEL"

    # 3. Default: junior (sprint tasks → permanent tasks as fallback, 5-task budget enforced)
    else
        MODEL=$(get_model junior sonnet)
        SESSION_TYPE="junior"
        SESSION_PROMPT="execute junior tasks"
        log "No P0/SENIOR work — junior ($MODEL)"
    fi
    fi  # end if not resuming planning

    echo "$MODEL" > "$HOME/drift-state/last-model"
    echo "$SESSION_TYPE" > "$HOME/drift-state/cache-session-type"
    CURRENT_LOG="$LOG_DIR/session_${SESSION_TYPE}_$(date +%s).log"

    # Check rate limit before starting
    local RATE_MSG=$("$WORK_DIR/scripts/check-rate-limit.sh" 2>/dev/null)
    local RATE_EXIT=$?
    if [[ "$RATE_EXIT" -eq 2 ]]; then
        log "Rate limit critical: $RATE_MSG. Delaying 5 min."
        sleep 300
    elif [[ "$RATE_EXIT" -eq 1 ]]; then
        log "Rate limit warning: $RATE_MSG"
    fi

    # Refresh compliance cache (P0 cache used by compliance-check.sh hook)
    refresh_compliance_cache

    log "Starting autopilot ($SESSION_TYPE, model=$MODEL, log: $CURRENT_LOG)"
    cd "$WORK_DIR"

    # Seed the heartbeat at spawn so is_log_stale_seconds doesn't flag
    # "stale" based on the previous session's trailing stamp before the
    # new session has made its first tool call.
    date +%s > "$HOME/drift-state/session-heartbeat"

    # Opus gets Sonnet fallback for API overload. Sonnet gets no fallback.
    local FALLBACK=""
    [[ "$MODEL" == "opus" ]] && FALLBACK="--fallback-model sonnet"

    DRIFT_AUTONOMOUS=1 claude -p "$SESSION_PROMPT" \
        --dangerously-skip-permissions \
        --model "$MODEL" \
        $FALLBACK \
        --effort max \
        --disallowedTools advisor \
        --output-format stream-json \
        --verbose \
        > "$CURRENT_LOG" 2>&1 &
    CLAUDE_PID=$!
    echo "$CLAUDE_PID" > "$PID_FILE"
    # Stamp the spawn time for stable-run-reset crash recovery (gbrain pattern):
    # if a session ran for STABLE_RUN_THRESHOLD seconds before crashing, we
    # forgive prior crash history — distinguishes "broken config" (instant
    # crash, stays stuck) from "transient flake" (long stable run, then crash).
    SESSION_STARTED_AT=$(date +%s)
    log "Autopilot started with PID $CLAUDE_PID (model=$MODEL)"

    # Start Haiku monitor
    start_monitor
}

is_claude_alive() {
    [[ -n "$CLAUDE_PID" ]] && kill -0 "$CLAUDE_PID" 2>/dev/null
}

is_log_stale() {
    is_log_stale_seconds "$STALE_THRESHOLD"
}

is_log_stale_seconds() {
    local threshold=$1
    local now
    now=$(date +%s)

    # Primary signal: session-heartbeat — written by a PreToolUse hook on
    # every tool call. More reliable than log mtime because the stream-json
    # log buffer can go quiet for long generation bursts (writing a big
    # file, extended thinking) even when the session is actively working.
    local hb_file="$HOME/drift-state/session-heartbeat"
    if [[ -f "$hb_file" ]]; then
        local hb_ts
        hb_ts=$(cat "$hb_file" 2>/dev/null || echo "$now")
        local hb_age=$(( now - hb_ts ))
        if (( hb_age <= threshold )); then
            return 1  # heartbeat fresh — alive
        fi
    fi

    # Fallback: log mtime. Keeps the behaviour for sessions that haven't
    # stamped a heartbeat yet (startup, test runners that never reach the
    # first tool call).
    if [[ -z "$CURRENT_LOG" ]] || [[ ! -f "$CURRENT_LOG" ]]; then
        return 1
    fi
    local last_mod
    last_mod=$(stat -f %m "$CURRENT_LOG" 2>/dev/null || echo "$now")
    local age=$(( now - last_mod ))
    (( age > threshold ))
}

cleanup() {
    local state
    state=$(read_control)
    if [[ "$state" == "DRAIN" ]]; then
        log "Watchdog shutting down (signal received) — DRAIN active, leaving claude running."
    else
        log "Watchdog shutting down (signal received)..."
        kill_claude
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# Initialize control file if missing
if [[ ! -f "$CONTROL_FILE" ]]; then
    echo "RUN" > "$CONTROL_FILE"
fi

log "========================================="
log "Drift Control watchdog started"
log "Control file: $CONTROL_FILE"
log "Check interval: ${CHECK_INTERVAL}s"
log "========================================="

# Adopt existing claude process from PID file if still alive
if [[ -f "$PID_FILE" ]]; then
    SAVED_PID=$(cat "$PID_FILE")
    if kill -0 "$SAVED_PID" 2>/dev/null; then
        CLAUDE_PID="$SAVED_PID"
        CURRENT_LOG=$(ls -t "$LOG_DIR"/session_*.log 2>/dev/null | head -1)
        # Recover SESSION_STARTED_AT from the log file. Without this, the
        # stable-run-reset crash math computes `now - 0 = bogus huge number`
        # and logs e.g. "session age 1777186865s" (a 56-year-old session).
        # Strategy: parse the timestamp embedded in the log filename
        # (`session_{type}_{epoch}.log`); fall back to file mtime; fall back
        # to "now" if neither is available.
        if [[ -n "$CURRENT_LOG" ]]; then
            SESSION_STARTED_AT=$(echo "$CURRENT_LOG" | sed -nE 's|.*/session_[^_]+_([0-9]+)\.log$|\1|p')
            if [[ -z "$SESSION_STARTED_AT" ]]; then
                SESSION_STARTED_AT=$(stat -f %m "$CURRENT_LOG" 2>/dev/null || stat -c %Y "$CURRENT_LOG" 2>/dev/null || date +%s)
            fi
        else
            SESSION_STARTED_AT=$(date +%s)
        fi
        log "Adopted existing autopilot (PID $CLAUDE_PID, started $(($(date +%s) - SESSION_STARTED_AT))s ago, log: $CURRENT_LOG)"
    else
        log "Stale PID file (PID $SAVED_PID dead). Will start fresh."
        rm -f "$PID_FILE"
    fi
fi

# Initial start
STATE=$(read_control)
if [[ "$STATE" == "RUN" ]]; then
    if [[ -z "$CLAUDE_PID" ]]; then
        # Snapshot WIP BEFORE cleanup. If the prior watchdog died with a live
        # session that left uncommitted work in the tree, this is our only
        # chance to capture it — `cleanup_dirty_state` below will git-checkout
        # everything 5 lines later. Observed regression on #515: prior session
        # died, watchdog respawned via launchd, fired cleanup straight away,
        # the resumable patch only contained heartbeat.json + project.pbxproj
        # noise because the real code edits had been wiped.
        snapshot_wip_if_in_progress
        cleanup_dirty_state
        start_claude
    else
        log "Autopilot already running (adopted). Skipping initial start."
    fi
elif [[ "$STATE" == "PAUSE" ]]; then
    log "Control file says PAUSE — waiting..."
elif [[ "$STATE" == "STOP" ]]; then
    log "Control file says STOP — exiting."
    exit 0
elif [[ "$STATE" == "DRAIN" ]]; then
    log "Control file says DRAIN at startup."
    DRAIN_STALE=600
    if is_claude_alive; then
        log "DRAIN: waiting for session to finish (PID $CLAUDE_PID)..."
        while is_claude_alive; do
            sleep 60
            if is_log_stale_seconds "$DRAIN_STALE"; then
                log "DRAIN: no log output in ${DRAIN_STALE}s — killing stalled process."
                kill_claude
                run_compliance "stall"
                cleanup_dirty_state
                log "DRAIN: done. Exiting."
                exit 0
            fi
        done
        # Session finished naturally — check log for crash vs normal exit
        if [[ -n "$CURRENT_LOG" ]] && grep -q '"type":"result"' "$CURRENT_LOG" 2>/dev/null; then
            run_compliance "normal"
        else
            run_compliance "crash"
        fi
    fi
    cleanup_dirty_state
    log "DRAIN: done. Exiting."
    exit 0
fi

# Main watchdog loop
# Sleep in 30s chunks so we pick up control file changes quickly
# Full health check (stale log, restart) only every CHECK_INTERVAL
ELAPSED=0
while true; do
    sleep 30
    ELAPSED=$(( ELAPSED + 30 ))

    STATE=$(read_control)

    # Snapshot runs every tick regardless of state so the activity graph
    # keeps advancing even while paused — flatlining is then a signal
    # that nothing is running, not that the snapshot is stale. The commit
    # + push stays RUN-only (see commit_heartbeat_if_due) so paused time
    # doesn't spam the remote.
    "$WORK_DIR/scripts/heartbeat-snapshot.sh" 2>/dev/null || true

    # React to STOP/PAUSE/DRAIN immediately (every 30s)
    if [[ "$STATE" != "RUN" ]]; then
        log "Check cycle — control: $STATE, autopilot PID: ${CLAUDE_PID:-none}"
    fi

    # Skip full health check until CHECK_INTERVAL elapsed
    if [[ "$STATE" == "RUN" ]] && (( ELAPSED < CHECK_INTERVAL )); then
        continue
    fi
    ELAPSED=0

    if [[ "$STATE" == "RUN" ]]; then
        log "Check cycle — control: $STATE, autopilot PID: ${CLAUDE_PID:-none}"
    fi

    case "$STATE" in
        STOP)
            log "STOP requested. Shutting down."
            kill_claude
            exit 0
            ;;
        PAUSE)
            if is_claude_alive; then
                log "PAUSE requested. Waiting for graceful exit (pause-gate.sh hard-blocks claim)..."
                PAUSE_WAIT=0
                PAUSE_TIMEOUT=900
                while is_claude_alive && (( PAUSE_WAIT < PAUSE_TIMEOUT )); do
                    sleep 10
                    (( PAUSE_WAIT += 10 ))
                    if is_log_stale_seconds 120; then
                        log "PAUSE: session stalled (no output in 120s). Force killing."
                        break
                    fi
                done
                if is_claude_alive; then
                    log "PAUSE: graceful timeout (${PAUSE_TIMEOUT}s). Force killing."
                    kill_claude
                else
                    log "PAUSE: session exited gracefully."
                fi
            fi
            log "Paused. Waiting for RUN..."
            continue
            ;;
        DRAIN)
            log "DRAIN: waiting for current session to finish (pause-gate.sh hard-blocks new claims)."
            if is_claude_alive; then
                log "DRAIN: waiting for session to finish (PID $CLAUDE_PID)..."
                DRAIN_STALE=600
                while is_claude_alive; do
                    sleep 60
                    if is_log_stale_seconds "$DRAIN_STALE"; then
                        log "DRAIN: no log output in ${DRAIN_STALE}s — killing stalled process."
                        kill_claude
                        run_compliance "stall"
                        cleanup_dirty_state
                        log "DRAIN: killed stalled session. Exiting."
                        exit 0
                    fi
                done
                # Session finished naturally
                run_compliance "normal"
                cleanup_dirty_state
            else
                log "DRAIN: session already finished."
                cleanup_dirty_state
            fi
            log "DRAIN: done. Exiting."
            exit 0
            ;;
        RUN)
            # Reconcile state before touching anything else — catches stamps
            # that a prior session left stale, GitHub-closed tasks still
            # locking our in_progress slot, and orphan in-progress labels.
            sync_stamps_from_main
            reconcile_in_progress
            check_stale_claim
            snapshot_wip_if_in_progress
            sweep_stale_in_progress_labels
            commit_heartbeat_if_due
            # Check if autopilot is dead
            if ! is_claude_alive; then
                stop_monitor
                if [[ -n "$CURRENT_LOG" ]] && grep -q '"type":"result"' "$CURRENT_LOG" 2>/dev/null; then
                    log "Autopilot completed normally. Restarting..."
                    atomic_write "$CRASH_FILE" "0"
                    run_compliance "normal"
                else
                    # Stable-run reset: if the session was alive for at least
                    # STABLE_RUN_THRESHOLD seconds, this crash is most likely
                    # transient (network, simulator deadlock, etc.) — forgive
                    # prior crash history.
                    NOW=$(date +%s)
                    SESSION_AGE=$(( NOW - SESSION_STARTED_AT ))
                    PREV_CRASHES=$(cat "$CRASH_FILE" 2>/dev/null || echo "0")
                    if (( SESSION_AGE >= STABLE_RUN_THRESHOLD )) && (( PREV_CRASHES > 0 )); then
                        log "Stable-run reset: session ran ${SESSION_AGE}s before crash (≥ ${STABLE_RUN_THRESHOLD}s). Forgiving $PREV_CRASHES prior crash(es)."
                        PREV_CRASHES=0
                    fi
                    CRASHES=$((PREV_CRASHES + 1))
                    atomic_write "$CRASH_FILE" "$CRASHES"
                    log "Autopilot CRASHED (no result event, session age ${SESSION_AGE}s). Crash #$CRASHES. Restarting..."
                    run_compliance "crash"
                    if [[ "$CRASHES" -ge 3 ]]; then
                        log "WARNING: $CRASHES consecutive crashes. Backing off 5 min."
                        sleep 300
                    fi
                fi
                cleanup_dirty_state
                start_claude
            # Check if autopilot is stalled
            elif is_log_stale; then
                log "Autopilot stalled (log not updated in ${STALE_THRESHOLD}s). Restarting..."
                kill_claude
                run_compliance "stall"
                cleanup_dirty_state
                start_claude
            else
                log "Autopilot running normally (PID $CLAUDE_PID)."
                # Refresh sprint state + compliance cache every heartbeat
                "$WORK_DIR/scripts/sprint-service.sh" refresh 2>/dev/null || true
                refresh_compliance_cache

                # Mark TestFlight due when 3h elapsed — hook publishes on next commit
                _TF_LAST=$(cat "$HOME/drift-state/last-testflight-publish" 2>/dev/null || echo "0")
                _TF_ELAPSED=$(( $(date +%s) - _TF_LAST ))
                if [[ "$_TF_ELAPSED" -ge 10800 ]] && [[ ! -f "$HOME/drift-state/testflight-due" ]]; then
                    echo "$(date +%s)" > "$HOME/drift-state/testflight-due"
                    log "TestFlight publish due (${_TF_ELAPSED}s since last) — marked for next commit"
                fi

                # Check per-session stall threshold (no commits/progress)
                # Nudge first, then kill after NUDGE_WAIT seconds
                CURRENT_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "junior")
                case "$CURRENT_TYPE" in
                    planning) SESSION_STALL=$STALL_PLANNING ;;
                    senior)   SESSION_STALL=$STALL_SENIOR ;;
                    *)        SESSION_STALL=$STALL_JUNIOR ;;
                esac
                NUDGE_FILE="$HOME/drift-state/watchdog-nudge-${CLAUDE_PID}"
                if is_log_stale_seconds "$SESSION_STALL"; then
                    if [[ ! -f "$NUDGE_FILE" ]]; then
                        log "Session appears stalled (no output in ${SESSION_STALL}s, type=$CURRENT_TYPE) — giving ${NUDGE_WAIT}s before restart."
                        touch "$NUDGE_FILE"
                    elif is_log_stale_seconds $(( SESSION_STALL + NUDGE_WAIT )); then
                        log "Session still stalled after nudge window — killing and restarting."
                        rm -f "$NUDGE_FILE"
                        kill_claude
                        run_compliance "stall"
                        cleanup_dirty_state
                        start_claude
                    else
                        log "Nudge window active — waiting for session to respond (type=$CURRENT_TYPE)."
                    fi
                else
                    rm -f "$NUDGE_FILE" 2>/dev/null || true
                fi

                # Commit-rate stall: busy-but-unproductive sessions (tool calls but no
                # shipped work). Planning sessions exempt — they create issues, not commits.
                # Only kicks in after COMMIT_STALL (3h) so genuinely hard bug hunts still finish.
                if [[ "$CURRENT_TYPE" != "planning" ]] && [[ -n "$CURRENT_LOG" ]] && [[ -f "$CURRENT_LOG" ]]; then
                    # Log filename is session_{type}_{epoch}.log
                    SESSION_EPOCH=$(basename "$CURRENT_LOG" | sed -E 's/^session_[a-z]+_([0-9]+)\.log$/\1/')
                    if [[ "$SESSION_EPOCH" =~ ^[0-9]+$ ]]; then
                        SESSION_AGE=$(( $(date +%s) - SESSION_EPOCH ))
                        if (( SESSION_AGE > COMMIT_STALL )); then
                            COMMITS_SINCE_START=$(cd "$WORK_DIR" && git log --oneline --since="@$SESSION_EPOCH" main 2>/dev/null | wc -l | tr -d ' ')
                            if [[ "$COMMITS_SINCE_START" == "0" ]]; then
                                log "PRODUCTIVITY STALL: $CURRENT_TYPE session age ${SESSION_AGE}s, 0 commits since start. Killing for fresh restart."
                                kill_claude
                                run_compliance "stall"
                                cleanup_dirty_state
                                start_claude
                            fi
                        fi
                    fi
                fi
            fi
            ;;
        *)
            log "Unknown control state: $STATE — treating as RUN"
            ;;
    esac
done
