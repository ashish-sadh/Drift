#!/bin/bash

# Silent for non-autonomous (human) sessions — these hooks are autopilot-only.
[[ "${DRIFT_AUTONOMOUS:-0}" != "1" ]] && exit 0
# Hook: PostToolUse on Bash(git commit *)
# Runs the right tests on every commit, scoped to what changed:
#   - DriftCore swift test (~2s) — every commit (free)
#   - iOS xcodebuild test (~25s) — when iOS sources touched
#   - macOS LLM eval (~12 min) — when AI/prompt sources touched
# If any tier fails, posts a strong "TESTS FAILED" additionalContext so the
# next session turn surfaces the regression and can fix-and-recommit.

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR"

# Skip for planning sessions — they don't write code
SESSION_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "junior")
if [[ "$SESSION_TYPE" == "planning" ]]; then
  exit 0
fi

# Defer if a TestFlight archive is currently running. The pkill below would
# otherwise kill the long-running archive (5-10 min) and the publish fails.
# Tests will re-run on the next commit. (Build 178 lost 2 archives this way.)
if pgrep -f "xcodebuild.*archive" >/dev/null 2>&1; then
    echo "[coverage-gate] xcodebuild archive in progress — deferring tests" >&2
    exit 0
fi

# Singleton — only one coverage-gate at a time. Multiple commits landing
# within ~25s of each other would otherwise fork parallel test runs that
# all `pkill -9 -f xcodebuild` and fight for the simulator. Lock via mkdir
# (atomic on POSIX). If we can't acquire, defer; the running gate covers
# this commit's test surface anyway since we re-run swift test on every
# commit and the iOS / macOS-eval triggers are diff-scoped.
LOCK_DIR="/tmp/drift-coverage-gate.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[coverage-gate] another coverage-gate already running — deferring" >&2
    exit 0
fi
trap "rmdir '$LOCK_DIR' 2>/dev/null || true" EXIT

# Detect what changed in this commit. Used to scope iOS + macOS LLM eval.
CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")

# AI / prompt patterns — touch these and macOS LLM eval must rerun.
AI_PATTERN='DriftCore/Sources/DriftCore/AI/|DriftCore/Tests/DriftCoreTests/IntentClassifier|DriftLLMEvalMacOS/|Drift/Services/PhotoLogTool\.swift'

# iOS source patterns — touch these and iOS xcodebuild test must rerun.
# Drift/, DriftCore/, DriftWidget/, DriftIntents/, project.yml, .xcodeproj.
IOS_PATTERN='^(Drift/|DriftCore/Sources/|DriftCore/Tests/|DriftWidget/|DriftIntents/|project\.yml|Drift\.xcodeproj/)'

CHANGED_AI=$(echo "$CHANGED" | grep -E "$AI_PATTERN" || true)
CHANGED_IOS=$(echo "$CHANGED" | grep -E "$IOS_PATTERN" || true)

FAILURES=""

# ── Tier 0: DriftCore swift test (every commit, ~2s) ─────────────────────────
echo "[coverage-gate] swift test (DriftCore)..." >&2
SWIFT_OUT=$(cd DriftCore && swift test 2>&1)
SWIFT_RC=$?
if [ $SWIFT_RC -ne 0 ]; then
    FAILED=$(echo "$SWIFT_OUT" | grep -E "✘|error:" | head -10)
    FAILURES="${FAILURES}\n- DriftCore swift test FAILED:\n${FAILED}"
fi

# ── Tier 1: iOS xcodebuild test (when iOS sources touched, ~25s) ────────────
if [ -n "$CHANGED_IOS" ]; then
    echo "[coverage-gate] xcodebuild test (iOS — sources touched)..." >&2
    pkill -9 -f xcodebuild 2>/dev/null || true
    sleep 2
    xcodebuild test -project Drift.xcodeproj -scheme Drift \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        > /tmp/drift-ios-test.log 2>&1
    if [ $? -ne 0 ]; then
        FAILED_IOS=$(grep "✘" /tmp/drift-ios-test.log 2>/dev/null | head -8)
        FAILURES="${FAILURES}\n- iOS xcodebuild test FAILED:\n${FAILED_IOS}"
    fi
else
    echo "[coverage-gate] iOS test skipped — no iOS sources changed" >&2
fi

# ── Tier 3: macOS LLM eval (when AI/prompt touched, ~12 min) ────────────────
# This is slow but the only thing that catches LLM routing regressions before
# they hit TestFlight. Only fires when the diff actually touches AI code.
if [ -n "$CHANGED_AI" ]; then
    echo "[coverage-gate] macOS LLM eval (AI/prompt touched, ~12 min)..." >&2
    pkill -9 -f xcodebuild 2>/dev/null || true
    sleep 2
    xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS' \
        > /tmp/drift-macos-eval.log 2>&1
    if [ $? -ne 0 ]; then
        FAILED_LLM=$(grep -E "error:|✘" /tmp/drift-macos-eval.log 2>/dev/null | head -10)
        FAILURES="${FAILURES}\n- macOS LLM eval FAILED (likely tool-routing or multi-turn regression):\n${FAILED_LLM}"
    fi
else
    echo "[coverage-gate] macOS LLM eval skipped — no AI/prompt changes" >&2
fi

# ── Inject failure message if anything failed ────────────────────────────────
if [ -n "$FAILURES" ]; then
    cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "TESTS FAILED ON YOUR LAST COMMIT. Fix in next commit before claiming new work.\n\n${FAILURES}\n\nDo NOT skip. The session that ships a regression to TestFlight is the session that ate everyone's time."
  }
}
ENDJSON
else
    echo "[coverage-gate] all tiers green" >&2
fi

exit 0
