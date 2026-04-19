#!/usr/bin/env bash
# Run PerToolReliabilityEval one tool per xcodebuild invocation.
#
# Why one-per-process: the ggml-metal backend accumulates residency-set state
# across ~10 inferences and then the next inference dies silently. Fresh
# xctest process per tool = fresh Metal state.
#
# Usage: bash scripts/per-tool-reliability.sh [tool ...]
#   With no args, runs all 5 tools. With args, runs only the listed tools.
#   Tool names: logFood editMeal logWeight markSupplement foodInfo

set -uo pipefail

cd "$(dirname "$0")/.."

ALL_TOOLS=(logFood editMeal logWeight markSupplement foodInfo)
TOOLS=("${@:-${ALL_TOOLS[@]}}")

SCHEME="DriftLLMEvalMacOS"
DEST='platform=macOS,arch=arm64'
LOG_DIR="/tmp/per-tool-reliability"
mkdir -p "$LOG_DIR"

echo "🔨 Building $SCHEME..."
xcodebuild build-for-testing \
    -project Drift.xcodeproj \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    > "$LOG_DIR/build.log" 2>&1
BUILD_STATUS=$?
if [ $BUILD_STATUS -ne 0 ]; then
    echo "❌ Build failed. Tail of $LOG_DIR/build.log:"
    tail -30 "$LOG_DIR/build.log"
    exit $BUILD_STATUS
fi
echo "✅ Build succeeded."

declare -a RESULTS
for tool in "${TOOLS[@]}"; do
    echo ""
    echo "▶️  Running testReliability_${tool}..."
    start=$(date +%s)
    xcodebuild test-without-building \
        -project Drift.xcodeproj \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -only-testing:"DriftLLMEvalMacOS/PerToolReliabilityEval/testReliability_${tool}" \
        > "$LOG_DIR/${tool}.log" 2>&1
    status=$?
    elapsed=$(( $(date +%s) - start ))
    line=$(grep '📊 PerToolReliabilityEval/' "$LOG_DIR/${tool}.log" | head -1)
    if [ -n "$line" ]; then
        echo "   ${line#*📊 } (${elapsed}s)"
        RESULTS+=("$line")
    else
        echo "   ❌ No score line — tail:"
        tail -5 "$LOG_DIR/${tool}.log"
        RESULTS+=("${tool}: NO RESULT")
    fi
    grep '   ❌' "$LOG_DIR/${tool}.log" | head -20
done

echo ""
echo "==================================="
echo "📊 Per-tool reliability summary"
echo "==================================="
for r in "${RESULTS[@]}"; do
    echo "$r"
done
