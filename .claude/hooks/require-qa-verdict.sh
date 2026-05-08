#!/bin/bash

# Silent for non-autonomous (human) sessions — these hooks are autopilot-only.
[[ "${DRIFT_AUTONOMOUS:-0}" != "1" ]] && exit 0
# Hook: PreToolUse on Bash(git commit *)
# When a sprint task touches UI / VM / Service / Domain / AI / Persistence
# code, require a QA-verdict comment from the senior session on the claimed
# issue. The qa-tester subagent generates scenarios; the senior must verdict
# each one before commit. Pairs with require-test-on-source-change.sh — that
# hook ensures a test is staged; this hook ensures the test was driven by
# adversarial trace, not just "what's easy to test."
#
# Block conditions:
#   1. Staging source AND no test (handled by require-test-on-source-change.sh)
#   2. Staging source AND no QA-verdict comment in last 60 min (this hook)
#   3. Staging source AND QA-verdict has unchecked scenarios (this hook)
#
# Skip conditions:
#   - [no-test] marker → also skip QA (consistent with other hook)
#   - [no-qa] marker → explicit opt-out, audit trail visible in git log
#   - in_progress is null → not a claimed task, this is loose work
#   - Issue has design-doc / report label → different lifecycle, QA TBD
#
# Format expected on the issue (most recent comment by the session):
#   ## QA scenarios (qa-tester)
#   - [x] Scenario: ...
#     Verdict: BUG FIXED (commit-hash) | WORKS AS UPDATED (file:line) |
#             WORKS AS-IS (line N) | NOT APPLICABLE (reason)
#   - [x] Scenario: ...
#     Verdict: ...

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only fire on git commit
echo "$COMMAND" | grep -qE '(^|[^a-zA-Z])git[[:space:]]+commit([[:space:]]|$)' || exit 0

# Honor opt-outs
if echo "$COMMAND" | grep -qF "[no-test]"; then exit 0; fi
if echo "$COMMAND" | grep -qF "[no-qa]"; then exit 0; fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null || echo "")
[ -z "$STAGED" ] && exit 0

SOURCE_RE='^(Drift/Views/|Drift/ViewModels/|Drift/Services/|DriftCore/Sources/DriftCore/(Domain|AI|Persistence)/)'
SOURCE_FILES=$(echo "$STAGED" | grep -E "$SOURCE_RE" || true)
[ -z "$SOURCE_FILES" ] && exit 0

# Get current claimed issue
STATE_FILE="$HOME/drift-state/sprint-state.json"
[ -f "$STATE_FILE" ] || exit 0
IN_PROGRESS=$(jq -r '.in_progress // empty' "$STATE_FILE" 2>/dev/null || echo "")
[ -z "$IN_PROGRESS" ] || [ "$IN_PROGRESS" = "null" ] && exit 0

# Skip design-doc / report tasks (different lifecycle)
LABELS=$(gh issue view "$IN_PROGRESS" --json labels --jq '[.labels[].name]' 2>/dev/null || echo "[]")
if echo "$LABELS" | jq -e 'index("design-doc") != null' >/dev/null 2>&1; then exit 0; fi
if echo "$LABELS" | jq -e 'index("report") != null' >/dev/null 2>&1; then exit 0; fi

# Find a recent comment containing the QA-verdict block
# (last 60 min, by anyone — the autopilot session posts as ashish-sadh)
SIXTY_MIN_AGO=$(date -u -v-60M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                || date -u -d '60 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                || echo "1970-01-01T00:00:00Z")
COMMENTS_JSON=$(gh issue view "$IN_PROGRESS" --json comments \
    --jq "[.comments[] | select(.createdAt > \"$SIXTY_MIN_AGO\") | .body]" 2>/dev/null || echo "[]")

# Look for the verdict block header in any recent comment
VERDICT_BODY=$(echo "$COMMENTS_JSON" | jq -r '.[]' | grep -A 200 '## QA scenarios' | head -200 || true)

if [ -z "$VERDICT_BODY" ]; then
    cat >&2 <<EOF
BLOCKED (require-qa-verdict): no QA-verdict comment on issue #$IN_PROGRESS in the last 60 min.

This commit stages source changes:
$(echo "$SOURCE_FILES" | sed 's/^/  /')

Before committing UI / VM / Service / Domain / AI / Persistence code:

  1. Invoke the qa-tester subagent with the diff and issue body:
     Task({ subagent_type: "qa-tester", prompt: "<diff summary + issue context>" })
  2. Receive scenario checklist. For each scenario:
     - Read the actual code path it would touch
     - Assume it's broken; trace through the worst case
     - If you find a bug, FIX IT (don't just write a test that hides it)
     - Write the test that locks the now-correct behavior
  3. Reply on the issue with the verdicts:
       ## QA scenarios (qa-tester)
       - [x] Scenario: ...
         Verdict: BUG FIXED (<commit-hash>) | WORKS AS UPDATED (<file:line>)
                  | WORKS AS-IS (line N) | NOT APPLICABLE (<reason>)
  4. Re-run the commit — this hook will see the verdict block and pass.

Opt-out: include [no-qa] in the commit message. Use only for cases where
adversarial QA genuinely doesn't apply (small refactor, doc-only logic
change). Auditable via git log --grep '\[no-qa\]'.
EOF
    exit 2
fi

# Check for unchecked scenarios in the verdict block
if echo "$VERDICT_BODY" | grep -qE '^\s*-\s*\[\s*\]\s*Scenario'; then
    cat >&2 <<EOF
BLOCKED (require-qa-verdict): unchecked QA scenario(s) on issue #$IN_PROGRESS.

The verdict block has scenarios marked [ ] that haven't been resolved:

$(echo "$VERDICT_BODY" | grep -B1 -A2 '^\s*-\s*\[\s*\]\s*Scenario' | head -30 | sed 's/^/  /')

Each scenario needs a Verdict line in the format:
  - [x] Scenario: ...
    Verdict: BUG FIXED (<commit>) | WORKS AS UPDATED (<file:line>)
             | WORKS AS-IS (line N) | NOT APPLICABLE (<reason>)

Re-edit the issue comment, mark each [x] with its verdict, then retry.
EOF
    exit 2
fi

exit 0
