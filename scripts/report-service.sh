#!/bin/bash
# Report service — owns exec briefing and product review report lifecycle
# Commands: daily-due, review-due, start-exec, start-review <cycle>, finish, last-exec, last-review

set -euo pipefail

# shellcheck source=lib/atomic-write.sh
source "$(dirname "$0")/lib/atomic-write.sh"

STATE_DIR="$HOME/drift-state"
mkdir -p "$STATE_DIR"

cmd_daily_due() {
    # exits 0 if exec report NOT yet filed (due), exits 1 if already done
    # Check 1: git log for report commit in last 24h
    if git log main --oneline --since="24 hours ago" 2>/dev/null | grep -qE "report.*exec-|exec-.*report|daily briefing|Daily Briefing"; then
        exit 1  # already done
    fi
    # Check 2: fallback — last-report-time file
    LAST=$(cat "$STATE_DIR/last-report-time" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    if [ $(( NOW - LAST )) -lt 86400 ]; then
        exit 1  # already done (within 24h)
    fi
    exit 0  # report due
}

cmd_review_due() {
    # exits 0 if product review IS due, exits 1 if not.
    #
    # Two gates, BOTH must pass:
    #   1. Commit-counter gap: at least PRODUCT_REVIEW_CYCLE_INTERVAL "real work"
    #      commits (default 20) since the last review. Only commits that
    #      survive the housekeeping filter in cycle-counter.sh count.
    #   2. Wall-clock floor: at least PRODUCT_REVIEW_MIN_HOURS (default 6) since
    #      last-review-time. Prevents a commit-storm from triggering a second
    #      review minutes after the first — matches planning's 6h cadence so
    #      reviews ride on planning naturally.
    #
    # Time-only fallback when commit-counter is missing.
    local INTERVAL="${PRODUCT_REVIEW_CYCLE_INTERVAL:-20}"
    local MIN_HOURS="${PRODUCT_REVIEW_MIN_HOURS:-6}"
    local MIN_SECONDS=$(( MIN_HOURS * 3600 ))

    local LAST_TIME
    LAST_TIME=$(cat "$STATE_DIR/last-review-time" 2>/dev/null || echo "0")
    local NOW
    NOW=$(date +%s)
    local SECONDS_SINCE=$(( NOW - LAST_TIME ))
    if [ "$SECONDS_SINCE" -lt "$MIN_SECONDS" ]; then
        exit 1  # too recent (wall-clock floor)
    fi

    local COUNT
    COUNT=$(cat "$STATE_DIR/commit-counter" 2>/dev/null || cat "$STATE_DIR/cycle-counter" 2>/dev/null || echo "0")
    local LAST_REVIEW_CYCLE
    LAST_REVIEW_CYCLE=$(cat "$STATE_DIR/last-review-cycle" 2>/dev/null || echo "0")

    if [ "$COUNT" -gt 0 ]; then
        local SINCE=$(( COUNT - LAST_REVIEW_CYCLE ))
        [ "$SINCE" -lt 0 ] && SINCE=0
        if [ "$SINCE" -ge "$INTERVAL" ]; then
            exit 0  # both gates passed: time floor + commit gap
        else
            exit 1  # commit gap not met
        fi
    fi

    # Fallback: counter unavailable — wall-clock floor already passed above,
    # also check git log to confirm no review committed in last 6h.
    if git log main --oneline --since="${MIN_HOURS} hours ago" 2>/dev/null | grep -qi "review-cycle"; then
        exit 1
    fi
    exit 0
}

cmd_start_exec() {
    TODAY=$(date +%Y-%m-%d)
    BRANCH="report/exec-$TODAY"

    # Check if branch already exists on remote
    if git ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q "$BRANCH"; then
        echo "Branch already exists — checkout and continue:"
        echo "  git checkout $BRANCH"
    else
        echo "Create exec report branch:"
        echo "  git checkout -b $BRANCH"
    fi
    echo ""
    echo "Expected filename: Docs/reports/exec-$TODAY.md"
    echo "Template: Use Docs/reports/EXEC-TEMPLATE.md"
}

cmd_start_review() {
    local CYCLE="${1:-}"
    if [ -z "$CYCLE" ]; then
        CYCLE=$(cat "$STATE_DIR/cycle-counter" 2>/dev/null || echo "0")
    fi
    BRANCH="review/cycle-$CYCLE"

    # Check if branch already exists on remote
    if git ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q "$BRANCH"; then
        echo "Branch already exists — checkout and continue:"
        echo "  git checkout $BRANCH"
    else
        echo "Create review branch:"
        echo "  git checkout -b $BRANCH"
    fi
    echo ""
    echo "Expected filename: Docs/reports/review-cycle-$CYCLE.md"
    echo "Template: Use Docs/reports/REVIEW-TEMPLATE.md"
}

cmd_finish() {
    # Merge current branch and return to main
    CURRENT_BRANCH=$(git branch --show-current)

    # Self-heal: Command Center filters reviews/execs by label=report — a missing
    # label hides the PR from the UI. Enforce it here so a slip at `gh pr create`
    # time can't surface as an invisible report.
    if echo "$CURRENT_BRANCH" | grep -q "^review/cycle-\|^report/exec-\|^report/.*exec"; then
        PR_INFO=$(gh pr view --json number,labels 2>/dev/null || echo "")
        if [ -n "$PR_INFO" ]; then
            PR_NUM=$(echo "$PR_INFO" | jq -r '.number // empty')
            HAS_LABEL=$(echo "$PR_INFO" | jq -r '[.labels[].name] | index("report") != null')
            if [ -n "$PR_NUM" ] && [ "$HAS_LABEL" = "false" ]; then
                gh pr edit "$PR_NUM" --add-label report >/dev/null 2>&1 \
                    && echo "Added missing 'report' label to PR #$PR_NUM"
            fi
        fi
    fi

    gh pr merge --squash --delete-branch 2>/dev/null || true
    git checkout main && git pull

    # Record timestamp based on branch type
    NOW=$(date +%s)
    if echo "$CURRENT_BRANCH" | grep -q "^report/exec-\|^report/.*exec"; then
        atomic_write "$STATE_DIR/last-report-time" "$NOW"
        echo "Recorded exec report time"
    elif echo "$CURRENT_BRANCH" | grep -q "^review/cycle-"; then
        atomic_write "$STATE_DIR/last-review-time" "$NOW"
        # last-review-cycle is the authoritative trigger going forward — extract
        # the cycle from the branch name (review/cycle-<N>) so a session that
        # reviewed cycle N marks itself as cycle N (not "now's cycle").
        local CYCLE
        CYCLE=$(echo "$CURRENT_BRANCH" | sed -E 's|^review/cycle-([0-9]+).*|\1|')
        if [ -n "$CYCLE" ] && [ "$CYCLE" != "$CURRENT_BRANCH" ]; then
            atomic_write "$STATE_DIR/last-review-cycle" "$CYCLE"
            echo "Recorded review time + cycle $CYCLE"
        else
            echo "Recorded review time (could not parse cycle from branch '$CURRENT_BRANCH')"
        fi
    fi
}

cmd_last_exec() {
    git log main --oneline 2>/dev/null | grep -iE "report.*exec-|exec-.*report|daily briefing|Daily Briefing" | head -1 || echo "No exec report found in git history"
}

cmd_last_review() {
    git log main --oneline 2>/dev/null | grep -i "review-cycle" | head -1 || echo "No review found in git history"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
    daily-due)      cmd_daily_due ;;
    review-due)     cmd_review_due ;;
    start-exec)     cmd_start_exec ;;
    start-review)   cmd_start_review "${1:-}" ;;
    finish)         cmd_finish ;;
    last-exec)      cmd_last_exec ;;
    last-review)    cmd_last_review ;;
    *)
        echo "Unknown command: $CMD" >&2
        echo "Commands: daily-due, review-due, start-exec, start-review <cycle>, finish, last-exec, last-review" >&2
        exit 1
        ;;
esac
