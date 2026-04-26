#!/bin/bash
# Hook: PreToolUse on Bash | Read | Grep | Glob — block tools on autopilot
# senior/junior sessions until they've claimed an issue.
#
# Why: sessions were running `next --senior` (read-only) instead of
# `next --senior --claim`, then reading top issue's body and self-directing
# into work without ever tagging in-progress on GitHub. Bash-only gate was
# bypassed by sessions using Read/Grep/Glob to investigate source code
# pre-claim (observed sessions 98525, 25394, 33806 — all wandered, none
# claimed).
#
# Fires when:
#   - DRIFT_AUTONOMOUS=1 (autopilot)
#   - session type is senior or junior (planning bypasses; humans bypass)
#   - sprint-state.in_progress is null (nothing claimed yet)
#
# Bash allowlist (orient-only commands):
#   - scripts/sprint-service.sh ...      (the way to claim + status)
#   - gh issue view / gh issue comment   (read specific issue, post questions)
#   - cat ~/drift-state/* / cat docs (MEMORY/program/CLAUDE/roadmap.md)
#   - ls, pwd, echo
#   NOTE: `gh issue list` removed from allowlist — use `sprint-service.sh status`.
#         Browsing the queue beyond what `next` returns invites freelancing.
#
# Read allowlist (orient-only paths):
#   - Docs/**                            (project docs)
#   - *.md at repo root                  (CLAUDE.md, README.md, program.md)
#   - scripts/**                         (debugging the harness itself)
#   - .claude/**                         (debugging hooks themselves)
#   - ~/drift-state/**                   (state inspection)
#   - ~/.claude/**/memory/**             (memory files)
#
# Grep + Glob: blocked entirely pre-claim. Sessions explore the codebase
# *after* claiming.

set -e

# Read stdin JSON (PreToolUse contract — see pause-gate.sh:6-7).
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only gate the tools we care about.
case "$TOOL_NAME" in
    Bash|Read|Grep|Glob) ;;
    *) exit 0 ;;
esac

# Only autopilot
[ "${DRIFT_AUTONOMOUS:-0}" = "1" ] || exit 0

# Only senior/junior — planning works off a planning issue directly
SESSION_TYPE=$(cat "$HOME/drift-state/cache-session-type" 2>/dev/null || echo "")
case "$SESSION_TYPE" in
    senior|junior) ;;
    *) exit 0 ;;
esac

# Already claimed? exit 0.
STATE_FILE="$HOME/drift-state/sprint-state.json"
[ -f "$STATE_FILE" ] || exit 0
IN_PROGRESS=$(python3 -c "
import json
try:
    d = json.load(open('$STATE_FILE'))
    print(d.get('in_progress') or '')
except Exception:
    print('')
" 2>/dev/null)
[ -n "$IN_PROGRESS" ] && exit 0

# in_progress is null — gate the tool.

case "$TOOL_NAME" in
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
        [ -z "$COMMAND" ] && exit 0
        ALLOW='(scripts/sprint-service\.sh|gh issue view|gh issue comment|gh pr list|cat .*drift-state|cat .*MEMORY\.md|cat .*program\.md|cat .*CLAUDE\.md|cat .*roadmap\.md|^[[:space:]]*ls( |$)|^[[:space:]]*pwd|^[[:space:]]*echo)'
        if echo "$COMMAND" | grep -qE "$ALLOW"; then
            exit 0
        fi
        cat >&2 <<'EOF'
BLOCKED (Bash): Claim an issue before running this command.

    TASK=$(scripts/sprint-service.sh next --senior --claim)   # or --junior
    echo "$TASK"

If `next` returns "none", exit cleanly — don't backfill from your own ideas.

Allowed pre-claim Bash:
  - scripts/sprint-service.sh ...       (status/next/claim/count)
  - gh issue view N / gh issue comment  (specific issue read or comment)
  - cat ~/drift-state/* / cat MEMORY.md / cat program.md / cat CLAUDE.md / cat roadmap.md
  - ls / pwd / echo

Browse the queue with `sprint-service.sh status`, NOT `gh issue list`.
EOF
        exit 2
        ;;
    Read)
        FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
        [ -z "$FP" ] && exit 0
        # Read allowlist — paths we permit pre-claim
        case "$FP" in
            */Docs/*) exit 0 ;;
            */CLAUDE.md|*/README.md|*/program.md|*/MEMORY.md|*/roadmap.md) exit 0 ;;
            */scripts/*) exit 0 ;;
            */.claude/*) exit 0 ;;
            */drift-state/*) exit 0 ;;
            */.claude/projects/*/memory/*) exit 0 ;;
        esac
        cat >&2 <<EOF
BLOCKED (Read): Claim an issue before reading source files.

You're trying to Read: $FP

Pre-claim, you can only read:
  - Docs/**                          (project docs)
  - CLAUDE.md / README.md / program.md / MEMORY.md / roadmap.md
  - scripts/** / .claude/**          (harness)
  - ~/drift-state/**                 (state)
  - ~/.claude/projects/**/memory/**  (memory)

For source files, claim first:
    TASK=\$(scripts/sprint-service.sh next --senior --claim)

If \`next\` returned a task, claim it. Don't investigate multiple
candidates pre-claim — that's the wandering anti-pattern.
EOF
        exit 2
        ;;
    Grep|Glob)
        cat >&2 <<EOF
BLOCKED ($TOOL_NAME): Claim an issue before searching the codebase.

    TASK=\$(scripts/sprint-service.sh next --senior --claim)

Pre-claim, use Read on Docs/CLAUDE.md/program.md/MEMORY.md or
\`gh issue view N\` to orient. Code search is post-claim.
EOF
        exit 2
        ;;
esac
exit 0
