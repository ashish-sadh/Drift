# Drift — Claude Code Instructions

## The App
Drift is an AI-first local health tracker. AI chat is the showstopper — the primary way users interact. Every data entry should be doable through conversation. Traditional UI exists for visual analytics and as a fallback.

**Dual-model:** SmolLM (360M) does heavy lifting with hardcoded harness. Gemma 4 (2B) uplifts with intelligence — smart tool calling, multi-turn, cross-domain reasoning. Privacy-first: everything on-device, no cloud, no accounts.

## Two Operating Modes

### Mode 1: Human-Shepherded (default)
Human drives feature work. Read `Docs/sprint.md` for current tickets. Build, test, commit per ticket.

### Mode 2: Autonomous Self-Improvement
Human says "run self-improvement" or "never stop". Read `program.md` and follow it exactly. It has steering notes, startup/recovery, LOOP FOREVER cycle, and logging.

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
| `Docs/roadmap.md` | Product phases |
| `Docs/testing.md` | How to run tests, eval harness |
| `Docs/develop.md` | Dev setup, architecture, adding features |
| `Docs/human-reported-bugs.md` | User bug reports — fix these first |
| `Docs/improvement-log.md` | Loop cycle log |
| `program.md` | Autonomous loop program |

## Rules
- Build and test after every change
- All 729+ tests must pass before committing
- Don't publish TestFlight unless the user says "publish"
- No MacroFactor references anywhere
- Privacy-first: everything local, no cloud, no analytics
- Run `xcodegen generate` after changing project.yml or adding new files
- Run eval harness after any AI change

## Color Philosophy (Goal-Aware)
- Green (Theme.deficit) = aligned with goal direction
- Red (Theme.surplus) = against goal
- Default: assume losing weight

## Build & Test
```bash
cd /Users/ashishsadh/workspace/Drift

# Build
xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Test (all 729+)
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Check failures
xcodebuild test ... 2>&1 | grep "✘"  # empty = all pass

# AI eval harness only
xcodebuild test ... -only-testing:'DriftTests/AIEvalHarness'
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
