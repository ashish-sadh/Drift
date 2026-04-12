# Drift — Claude Code Instructions

## The App
Drift is an AI-first local health tracker. AI chat is the showstopper — the primary way users interact. Every data entry should be doable through conversation. Traditional UI exists for visual analytics and as a fallback.

**Dual-model:** SmolLM (360M) does heavy lifting with hardcoded harness. Gemma 4 (2B) uplifts with intelligence — smart tool calling, multi-turn, cross-domain reasoning. Privacy-first: everything on-device, no cloud, no accounts.

## Two Operating Modes

### Mode 1: Human-Shepherded (default)
Human drives feature work. Read `Docs/sprint.md` for current tickets. Build, test, commit per ticket. You can publish TestFlight anytime.

### Mode 2: Manual Autonomous Loop
Human says "run self-improvement" or "run code-improvement" in a single claude session. Read the corresponding program and follow it exactly:
- `program.md` — feature work, AI chat, UI, bugs, food DB
- `code-improvement.md` — refactoring only, no behavior changes

These run in the foreground. Human can Ctrl+C to stop. All hooks apply except TestFlight (human controls publishing).

### Mode 3: Drift Control (Watchdog-Managed)
Fully autonomous background operation. The watchdog (`scripts/self-improve-watchdog.sh`) manages everything — starts claude sessions, restarts on failure, alternates between self-improvement and code-improvement, enforces TestFlight publishing every 3 hours with pre-flight checks. Start with "start improvement" or `echo "RUN" > ~/drift-control.txt`.

### Drift Control (Watchdog + Hooks)

A background watchdog (`scripts/self-improve-watchdog.sh`) runs autonomous loops, alternating between self-improvement and code-improvement. Controlled via `~/drift-control.txt`. Hooks in `.claude/settings.json` enforce quality.

#### Control Commands

| User says | You do | What happens |
|-----------|--------|-------------|
| "start improvement" / "run improvement" | `echo "RUN" > ~/drift-control.txt && cd /Users/ashishsadh/workspace/Drift && nohup ./scripts/self-improve-watchdog.sh > /dev/null 2>&1 &` | Watchdog starts, sets _Override: CONTINUE in both programs, launches claude session |
| "stop improvement" / "stop drift control" | `echo "STOP" > ~/drift-control.txt` | Kills current session immediately, watchdog exits |
| "pause improvement" | `echo "PAUSE" > ~/drift-control.txt` | Kills current session, watchdog stays alive waiting for RUN |
| "graceful stop" / "drain" / "finish and stop" | `echo "DRAIN" > ~/drift-control.txt` | Sets _Override: STOP in both programs, waits for current cycle to finish (polls every 60s), kills if stale 10min, then exits |
| "resume" (after pause) | `echo "RUN" > ~/drift-control.txt` | Watchdog resumes, sets overrides back to CONTINUE, starts next session |
| "status" / "is improvement running?" | `cat ~/drift-control.txt && cat .claude/cycle-counter && ps aux \| grep 'claude.*self-improvement\|claude.*code-improvement' \| grep -v grep` | Shows control state, cycle count, running processes |

The watchdog polls the control file every 30 seconds for fast response.

#### Enforced Hooks (automatic, cannot be skipped)

| Hook | When | What |
|------|------|------|
| **Read-before-edit** | Every Edit/Write of .swift files | Blocks editing files not yet Read in the session |
| **Cycle counter** | Every git commit | Counts cycles. Every 10th: injects product review with two personas |
| **Coverage gate** | Every 5th commit | Runs full coverage check. If dropped: forces test-writing cycle |
| **TestFlight check** | Every git commit | If 3+ hours since last publish: injects mandatory publish instructions |
| **TestFlight guard** | Every xcodebuild archive | Blocks unless authorized by 3-hour hook |
| **Pre-flight checklist** | Before archive (after guard passes) | Runs: clean build → full tests → AI eval → clean git. Blocks if any fail |
| **Clean state on stop** | Session ending | Blocks stop if uncommitted changes or unpushed commits |
| **Session start** | Session beginning | Shows cycle count, last review, next review due |

#### Monitoring

```bash
# Watchdog events
tail -f ~/drift-self-improve-logs/watchdog.log

# Current session output
tail -f ~/drift-self-improve-logs/session_*.log

# Cycle count + review status
cat ~/drift-state/cycle-counter && cat ~/drift-state/last-review-cycle

# Last TestFlight publish
date -r $(cat ~/drift-state/last-testflight-publish) 2>/dev/null || echo "Never published"

# Coverage snapshot
cat ~/drift-state/last-coverage-snapshot
```

#### Lifecycle of a Full Run
1. `echo "RUN" > ~/drift-control.txt` + start watchdog
2. Watchdog launches `claude -p "run self-improvement" --dangerously-skip-permissions --model opus --effort max`
3. Claude reads roadmap, sprint, bugs → picks work → builds, tests, commits, pushes
4. Hooks fire on each commit: cycle counter, coverage (every 5th), TestFlight (every 3hr)
5. Every 10th cycle: product review (Product Designer + Principal Engineer personas, web research)
6. If session dies/stalls: watchdog restarts with next prompt (alternates self-improvement ↔ code-improvement)
7. `echo "DRAIN" > ~/drift-control.txt` → finishes current cycle, stops cleanly
8. Everything committed and pushed (enforced by Stop hook)

## Doc Map
| Doc | What it is |
|-----|-----------|
| `Docs/ai-parity.md` | **AI chat vs UI feature gap** — what to build next |
| `Docs/failing-queries.md` | **Failing queries** — real queries that don't work, fix systematically |
| `Docs/architecture.md` | AI-first dual-model architecture |
| `Docs/sprint.md` | Current sprint (close parity gaps) |
| `Docs/state.md` | Current build, test count, features |
| `Docs/tools.md` | Service → tool mapping (10 JSON tools) |
| `Docs/backlog.md` | Long-term tickets (organized by AI gaps) |
| `Docs/roadmap.md` | **Product roadmap** — unified, domain-sectioned, read every cycle |
| `Docs/product-review-log.md` | Periodic product + engineering reviews (every 10 cycles) |
| `Docs/testing.md` | How to run tests, eval harness |
| `Docs/develop.md` | Dev setup, architecture, adding features |
| `Docs/human-reported-bugs.md` | User bug reports — fix these first |
| `Docs/improvement-log.md` | Loop cycle log |
| `Docs/principles/` | Code quality reference cards (Clean Code, Design Patterns, DDD, SwiftUI) |
| `program.md` | Autonomous loop program |
| `code-improvement.md` | Code quality autonomous loop |

## Rules
- Build and test after every change
- All 729+ unit tests (DriftTests) must pass before committing
- Run LLM eval lite after AI changes; deep eval only when asked
- TestFlight is auto-published every 3 hours via hook (`.claude/hooks/testflight-check.sh`). The hook injects publish instructions after a commit when 3+ hours have passed. Follow the instructions when they appear. Never publish more frequently than every 3 hours.
- No MacroFactor references anywhere
- Privacy-first: everything local, no cloud, no analytics
- Run `xcodegen generate` after changing project.yml or adding new files
- Run eval harness after any AI change
- Run coverage check after writing tests: `./scripts/coverage-check.sh`
- Coverage targets: **80%** for pure logic/calculators, **50%** for services/viewmodels/database
- Write tests for any new service or logic code before committing

## Color Philosophy (Goal-Aware)
- Green (Theme.deficit) = aligned with goal direction
- Red (Theme.surplus) = against goal
- Default: assume losing weight

## Build & Test

**CRITICAL: Never run multiple `xcodebuild test` in parallel.** They fight for the simulator and deadlock. Always kill stale processes first.

```bash
cd /Users/ashishsadh/workspace/Drift

# Build
xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Unit tests (729+ fast tests, ~10s) — ALWAYS kill stale processes first
pkill -9 -f xcodebuild 2>/dev/null; sleep 2
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftTests

# LLM eval lite (3 queries per model, ~2 min) — run after AI changes
pkill -9 -f xcodebuild 2>/dev/null; sleep 2
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftLLMEvalTests 2>&1 | grep -E "📊|❌|✔|✘|passed|failed"

# LLM eval deep PARALLEL (40 queries x 3 models, ~10 min) — only when asked, run in background
pkill -9 -f xcodebuild 2>/dev/null; sleep 2
DRIFT_DEEP_EVAL=1 xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:'DriftLLMEvalTests/ParallelLLMEval'

# LLM eval deep SEQUENTIAL (100+ queries per model, ~25 min each) — full eval
pkill -9 -f xcodebuild 2>/dev/null; sleep 2
DRIFT_DEEP_EVAL=1 xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftLLMEvalTests

# Check failures
xcodebuild test ... 2>&1 | grep "✘"  # empty = all pass

# AI eval harness only (intent detection, no LLM)
xcodebuild test ... -only-testing:'DriftTests/AIEvalHarness'

# Coverage check (run after tests with coverage enabled)
rm -rf /tmp/DriftCoverage.xcresult
pkill -9 -f xcodebuild 2>/dev/null; sleep 2
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftTests -enableCodeCoverage YES -resultBundlePath /tmp/DriftCoverage.xcresult
./scripts/coverage-check.sh
```

## TestFlight
```bash
# 1. Bump CURRENT_PROJECT_VERSION in project.yml
# 2. xcodegen generate
# 3. Archive
xcodebuild archive -project Drift.xcodeproj -scheme Drift -destination 'generic/platform=iOS' -archivePath /tmp/Drift.xcarchive DEVELOPMENT_TEAM=ZJ5H5XH82A CODE_SIGN_STYLE=Automatic
# 4. Export + Upload
xcodebuild -exportArchive -archivePath /tmp/Drift.xcarchive -exportPath /tmp/DriftExport -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates -authenticationKeyPath "/Users/ashishsadh/important-ashisadh/key for apple app/AuthKey_623N7AD6BJ.p8" -authenticationKeyID 623N7AD6BJ -authenticationKeyIssuerID ad762446-bede-4bcd-9776-a3613c669447
```

## Working Directory
`/Users/ashishsadh/workspace/Drift` (was renamed from Calibrate).
