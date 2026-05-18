#!/bin/bash
# Wrapper for launchd to invoke /testflight-publish via Claude CLI.
#
# launchd plists don't easily support quoted multi-token args, so this
# wrapper handles the invocation. Keep it minimal — no logic.

set -e

cd /Users/ashishsadh/workspace/Drift

# Make sure the state dirs exist (first run creates them)
mkdir -p "$HOME/drift-state/launchd"

# Set env that the skill expects
export DRIFT_AUTONOMOUS=1
export DRIFT_SESSION_TYPE=testflight
export DRIFT_USE_SKILLS=1

# Invoke headlessly. Haiku is the cheaper model — the recipe is deterministic.
# --dangerously-skip-permissions: launchd-managed, no human at terminal.
exec claude -p "/testflight-publish" \
  --dangerously-skip-permissions \
  --model haiku \
  --output-format text
