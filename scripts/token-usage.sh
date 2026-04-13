#!/bin/bash
# Token usage and cost calculator for Drift Autopilot sessions
# Usage: ./scripts/token-usage.sh [--today|--session|--all]

MODE="${1:---today}"
LOG_DIR="$HOME/drift-self-improve-logs"

python3 -c "
import json, glob, os, sys
from datetime import datetime, date

log_dir = '$LOG_DIR'
mode = '$MODE'

logs = sorted(glob.glob(f'{log_dir}/session_autopilot_*.log'), key=os.path.getmtime, reverse=True)

if mode == '--session':
    logs = logs[:1]
elif mode == '--today':
    today = date.today().isoformat()
    logs = [l for l in logs if datetime.fromtimestamp(os.path.getmtime(l)).date().isoformat() == today]

total_in = total_out = cache_read = cache_write = 0
total_msgs = 0
session_count = len(logs)

for log in logs:
    for line in open(log):
        try:
            obj = json.loads(line)
            u = obj.get('message', {}).get('usage', {})
            if u:
                total_in += u.get('input_tokens', 0)
                total_out += u.get('output_tokens', 0)
                cache_read += u.get('cache_read_input_tokens', 0)
                cache_write += u.get('cache_creation_input_tokens', 0)
                total_msgs += 1
        except:
            pass

cost_in = total_in * 15 / 1_000_000
cost_cw = cache_write * 18.75 / 1_000_000
cost_cr = cache_read * 1.50 / 1_000_000
cost_out = total_out * 75 / 1_000_000
total_cost = cost_in + cost_cw + cost_cr + cost_out

cycle_count = 0
try:
    cycle_count = int(open(os.path.expanduser('~/drift-state/cycle-counter')).read().strip())
except:
    pass

print(f'=== Drift Autopilot Token Usage ({mode}) ===')
print(f'Sessions: {session_count}  Messages: {total_msgs:,}  Cycles: {cycle_count}')
print()
print(f'Tokens:')
print(f'  Input:       {total_in:,}')
print(f'  Cache write: {cache_write:,}')
print(f'  Cache read:  {cache_read:,}')
print(f'  Output:      {total_out:,}')
print()
print(f'Estimated Cost (Opus pricing):')
print(f'  Input:       \${cost_in:.2f}')
print(f'  Cache write: \${cost_cw:.2f}')
print(f'  Cache read:  \${cost_cr:.2f}')
print(f'  Output:      \${cost_out:.2f}')
print(f'  Total:       \${total_cost:.2f}')
if cycle_count > 0 and total_cost > 0:
    print(f'  Per cycle:   \${total_cost / cycle_count:.2f}')
"
