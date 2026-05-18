#!/bin/bash
# is-clean-state.sh — the "complete unit of work" gate.
#
# Exit 0 iff main is in a publishable / claimable state. The rule: every
# triggered action (TestFlight publish, next-task claim) calls this first
# and skips quietly when it returns nonzero. The point is NEVER to gate
# work — only to gate user-visible side effects (releases, claims that
# would inherit a broken state).
#
# Checks (all must pass):
#   1. git status --porcelain is empty (working tree clean)
#   2. HEAD's associated issue has <verifier_verdict decision="PASS"/> in comments
#      (skipped if HEAD commit doesn't reference an issue — e.g., chore commits
#      from bumps, docs, infra)
#   3. ~/drift-state/in-progress-issue is empty or its issue is closed
#   4. Tier-0 tests pass on HEAD (cached for 5 min in /tmp/drift-mcp_tier0_cache.json)
#
# Flags:
#   --report   emit JSON to stdout describing each check's status
#
# Usage:
#   is-clean-state.sh && /testflight-publish
#   is-clean-state.sh --report  # for the MCP tool

set -e

REPORT=0
[ "${1:-}" = "--report" ] && REPORT=1

DIRTY_REASONS=()
CHECKS_JSON=""

add_check() {
    local name="$1"
    local pass="$2"
    local detail="${3:-}"
    if [ "$pass" = "false" ]; then
        DIRTY_REASONS+=("$name: $detail")
    fi
    if [ -n "$CHECKS_JSON" ]; then
        CHECKS_JSON+=","
    fi
    CHECKS_JSON+="\"$name\":{\"pass\":$pass"
    if [ -n "$detail" ]; then
        # crude json escape
        escaped=$(echo "$detail" | sed 's/"/\\"/g')
        CHECKS_JSON+=",\"detail\":\"$escaped\""
    fi
    CHECKS_JSON+="}"
}

# === Check 1: working tree clean ===
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    add_check "working_tree" "true"
else
    PORCELAIN=$(git status --porcelain | head -3 | tr '\n' '|')
    add_check "working_tree" "false" "uncommitted: $PORCELAIN"
fi

# === Check 2: HEAD's issue has PASS verdict ===
HEAD_SUBJECT=$(git log -1 --format=%s 2>/dev/null || echo "")
# Try to extract issue ref like "(#123)" or "fixes #123"
ISSUE_REF=$(echo "$HEAD_SUBJECT" | grep -oE "#[0-9]+" | head -1 | tr -d '#' || true)
if [ -z "$ISSUE_REF" ]; then
    # No issue ref → can't check verdict; treat as PASS (chore/docs/infra commits)
    add_check "head_verdict" "true" "no issue ref in HEAD subject; treated as PASS"
else
    COMMENTS=$(gh issue view "$ISSUE_REF" --json comments --jq '.comments[].body' 2>/dev/null || echo "")
    if echo "$COMMENTS" | grep -q '<verifier_verdict[^>]*decision="PASS"'; then
        add_check "head_verdict" "true" "issue #$ISSUE_REF has PASS verdict"
    else
        add_check "head_verdict" "false" "issue #$ISSUE_REF has no PASS verdict"
    fi
fi

# === Check 3: no claim in flight ===
IN_PROGRESS_FILE="$HOME/drift-state/in-progress-issue"
if [ ! -f "$IN_PROGRESS_FILE" ] || [ -z "$(cat "$IN_PROGRESS_FILE" 2>/dev/null)" ]; then
    add_check "no_claim_in_flight" "true"
else
    IN_PROGRESS_ISSUE=$(cat "$IN_PROGRESS_FILE")
    STATE=$(gh issue view "$IN_PROGRESS_ISSUE" --json state --jq .state 2>/dev/null || echo "UNKNOWN")
    if [ "$STATE" = "CLOSED" ]; then
        add_check "no_claim_in_flight" "true" "stale file references closed #$IN_PROGRESS_ISSUE"
    else
        add_check "no_claim_in_flight" "false" "session has #$IN_PROGRESS_ISSUE claimed"
    fi
fi

# === Check 4: tier-0 tests pass (cached) ===
CACHE_FILE="/tmp/drift-mcp_tier0_cache.json"
CACHE_TTL=300
NOW=$(date +%s)
USE_CACHE=0
if [ -f "$CACHE_FILE" ]; then
    CACHED_AT=$(grep -oE '"at":[0-9]+' "$CACHE_FILE" 2>/dev/null | head -1 | cut -d: -f2 || echo "0")
    AGE=$((NOW - CACHED_AT))
    if [ $AGE -lt $CACHE_TTL ]; then
        USE_CACHE=1
        CACHED_PASSING=$(grep -oE '"passing":(true|false)' "$CACHE_FILE" | head -1 | cut -d: -f2 || echo "false")
        if [ "$CACHED_PASSING" = "true" ]; then
            add_check "tier0_tests" "true" "cached pass (${AGE}s old)"
        else
            add_check "tier0_tests" "false" "cached fail (${AGE}s old)"
        fi
    fi
fi

if [ $USE_CACHE -eq 0 ]; then
    if (cd "$(dirname "$0")/../DriftCore" && swift test --quiet > /tmp/drift-mcp_tier0_run.log 2>&1); then
        echo "{\"at\":$NOW,\"passing\":true}" > "$CACHE_FILE"
        add_check "tier0_tests" "true" "ran swift test, passed"
    else
        echo "{\"at\":$NOW,\"passing\":false}" > "$CACHE_FILE"
        TAIL=$(tail -3 /tmp/drift-mcp_tier0_run.log 2>/dev/null | tr '\n' '|' || echo "")
        add_check "tier0_tests" "false" "swift test failed: $TAIL"
    fi
fi

if [ $REPORT -eq 1 ]; then
    DIRTY_JSON=""
    for r in "${DIRTY_REASONS[@]}"; do
        if [ -n "$DIRTY_JSON" ]; then DIRTY_JSON+=","; fi
        escaped=$(echo "$r" | sed 's/"/\\"/g')
        DIRTY_JSON+="\"$escaped\""
    done
    echo "{\"checks\":{$CHECKS_JSON},\"dirty_reasons\":[$DIRTY_JSON]}"
fi

# Exit 0 if no dirty reasons; 1 otherwise
if [ ${#DIRTY_REASONS[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
