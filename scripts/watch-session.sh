#!/bin/bash
# Live tail of the active autopilot session log, pretty-printed.
#
# Usage:
#   scripts/watch-session.sh             # tail latest session_*.log
#   scripts/watch-session.sh senior      # tail latest session_senior_*.log
#   scripts/watch-session.sh junior      # tail latest session_junior_*.log
#   scripts/watch-session.sh planning    # tail latest session_planning_*.log

set -euo pipefail

LOG_DIR="$HOME/drift-self-improve-logs"
TYPE="${1:-}"

if [ -n "$TYPE" ]; then
    LOG=$(ls -t "$LOG_DIR"/session_"$TYPE"_*.log 2>/dev/null | head -1)
else
    LOG=$(ls -t "$LOG_DIR"/session_*.log 2>/dev/null | head -1)
fi

if [ -z "$LOG" ]; then
    echo "No session log found in $LOG_DIR" >&2
    exit 1
fi

echo "Tailing: $LOG"
echo "(ctrl-c to stop)"
echo ""

tail -F -n 50 "$LOG" | python3 -c '
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if d.get("type") == "assistant":
            for c in d.get("message", {}).get("content", []):
                if c.get("type") == "text":
                    txt = c["text"].strip()
                    if txt: print("\n💬", txt[:600])
                elif c.get("type") == "thinking":
                    th = c["thinking"].strip()
                    if th: print("\n🧠", th[:400])
                elif c.get("type") == "tool_use":
                    n = c.get("name","?")
                    inp = c.get("input", {})
                    fp = inp.get("file_path","")
                    pat = inp.get("pattern","")
                    if n == "Bash":
                        desc = inp.get("description") or inp.get("command","")
                        print(f"  ⚙  Bash: {desc[:220]}")
                    elif n == "Read":
                        print(f"  📖 Read: {fp}")
                    elif n == "Edit":
                        print(f"  ✏️  Edit: {fp}")
                    elif n == "Write":
                        print(f"  📝 Write: {fp}")
                    elif n == "Grep":
                        print(f"  🔍 Grep: {pat[:120]}")
                    elif n == "Glob":
                        print(f"  🗂  Glob: {pat[:120]}")
                    elif n == "Agent":
                        print(f"  🤖 Agent: {inp.get('description','')[:120]}")
                    else:
                        print(f"  🔧 {n}")
        elif d.get("type") == "user":
            # Tool results — show truncated
            for c in d.get("message", {}).get("content", []):
                if c.get("type") == "tool_result":
                    content = c.get("content")
                    if isinstance(content, list):
                        for item in content:
                            if item.get("type") == "text":
                                t = item.get("text","").strip()
                                if t and len(t) < 400:
                                    print(f"     ↳ {t[:300]}")
                    elif isinstance(content, str) and len(content) < 400:
                        print(f"     ↳ {content[:300]}")
    except Exception:
        pass
    sys.stdout.flush()
'
