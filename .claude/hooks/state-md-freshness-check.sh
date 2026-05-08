#!/bin/bash
# Warns (never blocks) when Docs/state.md build counter lags project.yml by more than 1.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"

# Extract CURRENT_PROJECT_VERSION from project.yml (first match)
PROJECT_BUILD=$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_DIR/project.yml" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)

# Extract build number from Docs/state.md "Build N" in the Numbers section
STATE_BUILD=$(grep -oE 'Build [0-9]+' "$PROJECT_DIR/Docs/state.md" 2>/dev/null | head -1 | grep -oE '[0-9]+')

if [[ -z "$PROJECT_BUILD" || -z "$STATE_BUILD" ]]; then
  exit 0
fi

DIFF=$(( PROJECT_BUILD - STATE_BUILD ))
if (( DIFF > 1 )); then
  echo -e "\033[33m⚠ state.md is stale: build $STATE_BUILD vs project.yml build $PROJECT_BUILD ($DIFF builds behind). Refresh Docs/state.md before next planning cycle.\033[0m" >&2
fi

exit 0
