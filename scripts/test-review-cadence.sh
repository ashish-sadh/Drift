#!/bin/bash
# Tier 0 sanity tests for the wall-clock review cadence (cycle 10950).
# Verifies `report-service.sh review-due` and `sprint-service.sh planning-context`
# trigger off last-review-time, not cycle count.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORIG_HOME="$HOME"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"; export HOME="$ORIG_HOME"' EXIT

# Sandbox $HOME so tests don't clobber the real drift-state.
export HOME="$WORK_DIR"
mkdir -p "$HOME/drift-state"

PASS=0
FAIL=0

assert_eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label — expected '$expected' got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# ── report-service.sh review-due — wall-clock gate ────────────────────────────

echo "report-service.sh review-due:"

# 6 days ago → due (default 5-day interval)
echo $(( $(date +%s) - 6 * 86400 )) > "$HOME/drift-state/last-review-time"
echo "0" > "$HOME/drift-state/commit-counter"
echo "0" > "$HOME/drift-state/last-review-cycle"
if "$SCRIPT_DIR/report-service.sh" review-due > /dev/null 2>&1; then RC="due"; else RC="not-due"; fi
assert_eq "$RC" "due" "6 days ago → due"

# 4 days ago → not due
echo $(( $(date +%s) - 4 * 86400 )) > "$HOME/drift-state/last-review-time"
if "$SCRIPT_DIR/report-service.sh" review-due > /dev/null 2>&1; then RC="due"; else RC="not-due"; fi
assert_eq "$RC" "not-due" "4 days ago → not due"

# 5 days ago exactly → due (>= threshold)
echo $(( $(date +%s) - 5 * 86400 )) > "$HOME/drift-state/last-review-time"
if "$SCRIPT_DIR/report-service.sh" review-due > /dev/null 2>&1; then RC="due"; else RC="not-due"; fi
assert_eq "$RC" "due" "exactly 5 days ago → due"

# Fresh state (last-review-time=0) → due (NOW - 0 = NOW seconds, far above 5 days)
echo "0" > "$HOME/drift-state/last-review-time"
if "$SCRIPT_DIR/report-service.sh" review-due > /dev/null 2>&1; then RC="due"; else RC="not-due"; fi
assert_eq "$RC" "due" "fresh state (time=0) → due"

# Override interval to 7 days. 6 days ago → not due
PRODUCT_REVIEW_INTERVAL_DAYS=7 \
    bash -c "echo $(( $(date +%s) - 6 * 86400 )) > '$HOME/drift-state/last-review-time'; '$SCRIPT_DIR/report-service.sh' review-due > /dev/null 2>&1 && echo due || echo not-due" > /tmp/rc-test 2>&1
RC=$(cat /tmp/rc-test)
assert_eq "$RC" "not-due" "PRODUCT_REVIEW_INTERVAL_DAYS=7 + 6 days ago → not due"

# Cycle-count is now ignored — having 200 cycles past the legacy 20 doesn't fire.
echo $(( $(date +%s) - 1 * 86400 )) > "$HOME/drift-state/last-review-time"
echo "200" > "$HOME/drift-state/commit-counter"
echo "0" > "$HOME/drift-state/last-review-cycle"
if "$SCRIPT_DIR/report-service.sh" review-due > /dev/null 2>&1; then RC="due"; else RC="not-due"; fi
assert_eq "$RC" "not-due" "200 cycles past, 1 day ago → not due (cycle-count ignored)"

# ── sprint-service.sh planning-context — emits the right keys ─────────────────

echo
echo "sprint-service.sh planning-context:"

echo $(( $(date +%s) - 6 * 86400 )) > "$HOME/drift-state/last-review-time"
echo "47" > "$HOME/drift-state/commit-counter"
echo "30" > "$HOME/drift-state/last-review-cycle"
OUT=$("$SCRIPT_DIR/sprint-service.sh" planning-context 2>/dev/null)

assert_eq "$(echo "$OUT" | grep '^review_due=' | cut -d= -f2)" "true" "review_due=true at 6 days"
assert_eq "$(echo "$OUT" | grep '^days_since_last_review=' | cut -d= -f2)" "6" "days_since_last_review=6"
assert_eq "$(echo "$OUT" | grep '^review_interval_days=' | cut -d= -f2)" "5" "review_interval_days=5"
assert_eq "$(echo "$OUT" | grep '^cycles_since_last_review=' | cut -d= -f2)" "17" "cycles_since_last_review=17 (telemetry preserved)"
assert_eq "$(echo "$OUT" | grep '^cycle_count=' | cut -d= -f2)" "47" "cycle_count=47"
assert_eq "$(echo "$OUT" | grep '^last_review_cycle=' | cut -d= -f2)" "30" "last_review_cycle=30"

echo $(( $(date +%s) - 2 * 86400 )) > "$HOME/drift-state/last-review-time"
OUT=$("$SCRIPT_DIR/sprint-service.sh" planning-context 2>/dev/null)
assert_eq "$(echo "$OUT" | grep '^review_due=' | cut -d= -f2)" "false" "review_due=false at 2 days"
assert_eq "$(echo "$OUT" | grep '^days_since_last_review=' | cut -d= -f2)" "2" "days_since_last_review=2"

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
