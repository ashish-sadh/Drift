#!/bin/bash
# Hook: SessionStart
# Injects cycle state and roadmap reminder on session startup.

COUNTER_FILE="$HOME/drift-state/cycle-counter"
LAST_REVIEW_FILE="$HOME/drift-state/last-review-cycle"

COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
LAST_REVIEW=$(cat "$LAST_REVIEW_FILE" 2>/dev/null || echo "0")
NEXT_REVIEW=$((LAST_REVIEW + 10))

echo "=== Drift Loop State ==="
echo "Cycle count: $COUNT"
echo "Last product review: cycle $LAST_REVIEW"
echo "Next product review due: cycle $NEXT_REVIEW"
echo "Read Docs/roadmap.md first to understand product direction."
echo "REMINDER: Mark your target issue in-progress BEFORE starting work: gh issue edit {N} --add-label in-progress"

# Surface pending design-doc issues
DESIGN_DOCS=$(gh issue list --state open --label design-doc --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null || true)
if [ -n "$DESIGN_DOCS" ]; then
  DESIGN_COUNT=$(echo "$DESIGN_DOCS" | wc -l | tr -d ' ')
  echo ""
  echo "⚠ PENDING DESIGN DOCS ($DESIGN_COUNT):"
  echo "$DESIGN_DOCS"
  echo "Senior sessions: write/revise these BEFORE sprint-tasks. Use Docs/designs/TEMPLATE.md."
fi

echo "========================"

exit 0
