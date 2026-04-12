#!/bin/bash
# Hook: PostToolUse on Bash(git commit *)
# Tracks cycle count. Every 10th commit, injects product review reminder.

set -e

COUNTER_FILE="$HOME/drift-state/cycle-counter"
LAST_REVIEW_FILE="$HOME/drift-state/last-review-cycle"

# Initialize or read counter
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Check if product review is due (every 10th cycle)
LAST_REVIEW=$(cat "$LAST_REVIEW_FILE" 2>/dev/null || echo "0")
SINCE_REVIEW=$((COUNT - LAST_REVIEW))

if [ "$SINCE_REVIEW" -ge 10 ]; then
  # Inject product review reminder as additional context
  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "PRODUCT REVIEW REQUIRED (cycle $COUNT, last review at cycle $LAST_REVIEW). Pause feature work now.\n\n1. PRODUCT DESIGNER persona (2yr each at MyFitnessPal, Whoop, MacroFactor, Strong, Boostcamp):\n   - Read Docs/roadmap.md, Docs/state.md, git log --oneline -20\n   - Web search: what are Boostcamp, MyFitnessPal, Whoop, Strong, MacroFactor doing now?\n   - Write review: strengths, gaps vs competitors, new ideas, proposed roadmap changes\n\n2. PRINCIPAL ENGINEER persona (10yr each Amazon, Google):\n   - Review proposals for technical sustainability and sequencing\n   - Push back on scope creep, ground in current stack (SwiftUI, GRDB, on-device LLM)\n   - Ensure architecture supports ambition without over-engineering\n\n3. Both agree → update Docs/roadmap.md, log to Docs/product-review-log.md with today's date\n4. Update ~/drift-state/last-review-cycle with current cycle number\n5. Resume the loop"
  }
}
ENDJSON
else
  NEXT_REVIEW=$((LAST_REVIEW + 10))
  echo "Cycle $COUNT committed. Next product review at cycle $NEXT_REVIEW."
fi

exit 0
