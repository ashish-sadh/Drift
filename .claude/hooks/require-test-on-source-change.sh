#!/bin/bash

# Silent for non-autonomous (human) sessions — these hooks are autopilot-only.
[[ "${DRIFT_AUTONOMOUS:-0}" != "1" ]] && exit 0
# Hook: PreToolUse on Bash(git commit *)
# Blocks commits that change production source without staging an
# accompanying test. The calorie-overlay feature (#669) shipped with 4
# Preferences-toggle unit tests but zero data-flow tests, and three
# successive bugs slipped through (computed-property-on-@Observable,
# faint opacity, sort-order-mismatch query window). A staged-test
# requirement on source-touching commits raises the floor without
# slowing pure-refactor work.
#
# Source patterns (require a test):
#   Drift/Views/        Drift/ViewModels/      Drift/Services/
#   DriftCore/Sources/DriftCore/Domain/
#   DriftCore/Sources/DriftCore/AI/
#   DriftCore/Sources/DriftCore/Persistence/
#
# Test patterns (satisfy the requirement):
#   DriftTests/                                 (Tier 1)
#   DriftCore/Tests/DriftCoreTests/             (Tier 0)
#   DriftLLMEvalMacOS/                          (Tier 2/3)
#
# Opt-out: include `[no-test]` in the commit message for legitimate
# non-testable changes (typo, comment-only edit, doc, asset). Use
# sparingly — the marker leaves a grep-able audit trail.

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only fire on git commit
echo "$COMMAND" | grep -qE '(^|[^a-zA-Z])git[[:space:]]+commit([[:space:]]|$)' || exit 0

# Honor opt-out marker in commit message
if echo "$COMMAND" | grep -qF "[no-test]"; then
    exit 0
fi

# Get staged files (the explicit-paths form `git commit -- a b c` or anything
# already staged via add). Use --cached for index contents.
STAGED=$(git diff --cached --name-only 2>/dev/null || echo "")
[ -z "$STAGED" ] && exit 0

SOURCE_RE='^(Drift/Views/|Drift/ViewModels/|Drift/Services/|DriftCore/Sources/DriftCore/(Domain|AI|Persistence)/)'
TEST_RE='^(DriftTests/|DriftCore/Tests/DriftCoreTests/|DriftLLMEvalMacOS/)'

SOURCE_FILES=$(echo "$STAGED" | grep -E "$SOURCE_RE" || true)
TEST_FILES=$(echo "$STAGED" | grep -E "$TEST_RE" || true)

# No source files staged — nothing to check.
[ -z "$SOURCE_FILES" ] && exit 0

# Source staged but no test staged — block.
if [ -z "$TEST_FILES" ]; then
    cat >&2 <<EOF
BLOCKED (require-test-on-source-change): staging production source without a test.

Staged source:
$(echo "$SOURCE_FILES" | sed 's/^/  /')

A test in one of these locations must also be staged:
  DriftTests/                                  (Tier 1, iOS-bound)
  DriftCore/Tests/DriftCoreTests/              (Tier 0, pure logic — preferred)
  DriftLLMEvalMacOS/                           (Tier 2/3, LLM eval)

Why: the calorie overlay (#669) had 4 preferences-toggle unit tests but
zero data-flow tests, and three bugs slipped through into shipped code.
Requiring a staged test alongside source changes catches the failure
modes that pure-logic unit tests miss.

If this is a legitimate non-testable change (typo, comment, doc, asset),
add [no-test] to your commit message. Use sparingly — it's auditable.
EOF
    exit 2
fi

exit 0
