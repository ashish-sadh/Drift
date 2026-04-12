#!/bin/bash
# Hook: Stop
# Blocks session from ending if there are uncommitted changes or unpushed commits.
# Forces the model to commit and push before stopping.

set -e

cd "${CLAUDE_PROJECT_DIR:-.}"

# Check for uncommitted changes (staged or unstaged)
DIRTY=$(git status --porcelain 2>/dev/null | grep -v '^??' | head -5)
UNTRACKED=$(git status --porcelain 2>/dev/null | grep '^??' | grep -v '.claude/' | head -5)

# Check for unpushed commits
UNPUSHED=$(git log --oneline @{upstream}..HEAD 2>/dev/null | head -5)

ISSUES=""

if [ -n "$DIRTY" ]; then
  ISSUES="${ISSUES}Uncommitted changes:\n${DIRTY}\n\n"
fi

if [ -n "$UNTRACKED" ]; then
  ISSUES="${ISSUES}Untracked files (outside .claude/):\n${UNTRACKED}\n\n"
fi

if [ -n "$UNPUSHED" ]; then
  ISSUES="${ISSUES}Unpushed commits:\n${UNPUSHED}\n\n"
fi

if [ -n "$ISSUES" ]; then
  echo -e "BLOCKED: Cannot stop with dirty state.\n\n${ISSUES}Commit all changes and push before stopping." >&2
  exit 2
fi

exit 0
