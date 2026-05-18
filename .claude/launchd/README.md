# launchd plists — alternative scheduling, NOT currently active

The TestFlight publish plist (`com.drift.testflight-publish.plist`) was the original Phase 5 design. It's **no longer the canonical scheduling path** — instead, the watchdog (`scripts/self-improve-watchdog.sh:start_claude`) checks `is-clean-state.sh` + `last-testflight-publish` stamp at the top of each session-spawn decision and slots `/testflight-publish` as the next session when due.

## Why we switched

Launchd is fire-and-forget — it would spawn `/testflight-publish` even if a senior session was mid-`xcodebuild test`. That risks:

1. **Simulator deadlock.** CLAUDE.md explicit rule: "Never run multiple `xcodebuild test` in parallel." Archive uses `-destination 'generic/platform=iOS'` so doesn't strictly need the simulator, but it shares the Xcode build-products dir.
2. **Main-branch commit race.** TestFlight ends with `git commit + push`; a parallel senior session might commit-and-push in the same window.
3. **PAUSE/DRAIN bypass.** Launchd would publish even during a human takeover that wrote `DRAIN` to `~/drift-control.txt`.

The watchdog already serializes one claude session at a time and respects PAUSE/DRAIN. Slotting `/testflight-publish` into that queue solves all three concerns for free.

## When to load the launchd plist

Only if you want TestFlight publishes to be *fully independent* of the autopilot loop — e.g., the watchdog is intentionally stopped but you still want a builds-every-3h cadence. In that case:

```bash
launchctl load ~/Library/LaunchAgents/com.drift.testflight-publish.plist
# Verify:
launchctl list | grep testflight
# Status:
tail -50 ~/drift-state/launchd/testflight-publish.stdout.log
```

## Unloading

```bash
launchctl unload ~/Library/LaunchAgents/com.drift.testflight-publish.plist
rm ~/Library/LaunchAgents/com.drift.testflight-publish.plist
```
