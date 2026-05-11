# Decisions Log

Append-only record of non-obvious decisions: architecture changes, harness rules, design tenets that emerged from a real incident, performance/correctness tradeoffs that future readers should know about.

**The bar (read this before appending):** *"would a future session reading the diff still ask **why was it done this way?**"* — if yes, append. If the diff explains itself, don't.

**What goes here:**
- Architectural calls (e.g. "regress on raw weights, not EMA")
- Harness/process rules that came from a real incident (e.g. "raise stale-claim threshold to 90min after #426 false flag")
- Cross-cutting design choices (e.g. "Source: line required on sprint-tasks")
- Reversals (e.g. "replaced crashed/<N> branches with patch files — branch ceremony was too heavy")

**What does NOT go here:**
- Bug fixes — commit message + Resolution comment is enough
- Feature ships — changelog/releases.json captures these
- Code style / refactor for cleanliness — live in CLAUDE.md tenets, no per-decision noise
- Routine planning decomposition — sprint-task bodies capture this
- Test additions — diff is self-explanatory
- "I did X" without a *why* — every entry must have a reason future-you couldn't reconstruct from the diff alone

**Who appends:**
- **Anyone** with a real decision — senior, junior, planning, human. After closing the issue (or as part of closing).
- **Planning** is the editor: step 6 sweeps for missed entries from significant commits AND prunes the file (remove entries that didn't meet the bar, consolidate duplicates, archive entries >30 days that are now common knowledge).

**Format:**
- Most recent at the top
- One section per decision: `### <slug> — <one-line summary>`
- 1–3 sentences for the body. Lead with the *why*. Link the commit hash.
- Group by date heading: `## YYYY-MM-DD`

---

## 2026-05-10

### food-db-curated-not-exhaustive — ≤6,000 entry ceiling, batch imports rejected
Build 217 USDA Phase 2 bulk import (`af3f50e9`, +7,556 entries) took foods.json to 11,162 (3.7 MB). SR Legacy is research-grade noise: "Beans, snap, raw, NS as to color", 50+ variants of one canonical food, industrial-ingredient strings. The food DB is a UX surface that ships *embedded* — bulk grows install size, slows cold-launch DB-init, dilutes search ranking for the Indian-food-first entries that justify the app's existence. New tenet (#9 in product focus): **curated, not exhaustive**. Planning step 9a now reads `wc -l foods.json` each cycle, files/keeps a curation task if above ceiling, and rejects batch-import feature requests without a curation plan attached. Each new entry must justify itself: high-frequency search miss, unique nutrition profile, regional gap users actually eat. The one-time pass (#717, `1e222ec6`) dropped 5,742 multi-comma-bulk + verbose-USDA entries to land at 5,420; new Tier-0 `FoodDBSizeTests` locks the ceiling so future imports can't silently bloat. Commits `603ae058`, `1e222ec6`.

### qa-tester subagent gets its own maintenance loop in planning step 10
The `qa-tester` subagent (added 2026-05-08) is itself a piece of harness that drifts: over-flagging means sessions stop trusting the verdicts; under-generating means real bugs slip through. Planning step 10 now also reviews the last 5–10 closed sprint-tasks' QA-verdict comments looking for: (a) >40% `NOT APPLICABLE` across multiple issues → tighten generators; (b) post-shipped bugs filed within 7 days that no QA scenario flagged → identify missing failure category, add generator; (c) scenarios that caught real bugs across 2+ cycles → promote into stable generators block. Same sediment-and-prune rules as personas (durable in 2+ cycles → into generators; >30 days unsedimented → delete; ≤200 lines). Without this loop the subagent calcifies and either gets ignored or becomes noise. Commit `1474a33b`.

---

## 2026-05-08

### qa-tester subagent + verdict hook — adversarial pass before commit on UI/data-flow changes
Calorie overlay (#669) shipped 4 unit tests but 3 bugs slipped through (empty data, sort-order mismatch, @Observable computed-property gotcha) — all three were scenarios a halfway-decent QA pass would have flagged. New senior protocol step before any commit touching `Drift/Views|ViewModels|Services` or `DriftCore/Sources/{Domain,AI,Persistence}`: invoke `qa-tester` subagent → it returns a markdown checklist of failure scenarios → senior must trace each through actual code paths and either fix or prove handled, then post `## QA scenarios (qa-tester)` block on the issue with one verdict per scenario. `require-qa-verdict.sh` PreToolUse hook blocks the commit if the latest issue comment lacks the verdict block or any scenario remains unchecked. The point is to collapse the multi-commit iteration into one shipping commit by *assuming the code is broken until traced*, not to write more tests after the fact. Commit `d427f870`.

### require-test-on-source-change hook — every source commit ships with a test
Companion to QA pass: `require-test-on-source-change.sh` PreToolUse hook blocks any commit that stages files under `Drift/Views|ViewModels|Services` or `DriftCore/Sources/DriftCore/{Domain,AI,Persistence}` without ALSO staging a test under `DriftCoreTests`, `DriftTests`, or `DriftLLMEvalMacOS`. Edge case (pure typo/comment/asset, genuinely untestable) → include `[no-test]` in the commit message; auditable, use sparingly. Driven by the same #669 calorie-overlay incident — the data-flow bugs would have been caught by even a basic data-flow test, not just the preferences-toggle tests that did ship. Commit `ba46cfa9`.

### backup-allowlist-must-mirror-real-keys — string-typed UserDefaults dictionary is silent data loss waiting to happen
`PreferencesBackup.allowlist` was hand-curated against the conceptual list of preferences the team thought was being persisted; multiple production keys (weightGoal, tdeeConfig, custom_exercises, etc.) didn't match the allowlist string-for-string and were silently dropped from backups for weeks. Two follow-on fixes: (a) #700 — the allowlist must be derived from or explicitly verified against `Preferences.swift` keys; an audit script (`scripts/preferences-allowlist-audit.sh` if it doesn't exist yet, file an issue) should fail CI when they diverge; (b) #701 — `Codable Data` and array-typed preferences (e.g. weightGoal, custom exercises) need first-class round-tripping in the backup encoder/decoder, not "primitive types only" string matching. General lesson: any string-keyed allowlist over a moving target is a silent-data-loss vector — either generate it from the source of truth or verify equality with a test. Commits `791f287a`, `cb87668c`.

## 2026-05-07

### launch-watchdog-budget — defer notification + widget refresh, do not await before syncComplete
After #620 (GLP-1 weekly slot) + #627 (protein adherence 4-of-7), `NotificationService.refreshScheduledAlerts()` issues ~35 DB fetches per launch (5 BehaviorInsight alerts × 7-day windows + medication + GLP-1). Adding HealthKit sync + weight trend + TDEE puts cold launch within iOS's ~20s watchdog kill. New rule: any work that doesn't gate first frame goes in `Task { @MainActor in ... }`, not awaited inline in `DriftApp.task`. Notifications fire on schedule and widget pushes are fire-and-forget — neither gates UI. Commit `36f0cb12`.

### gh-search-index-bypass — sprint listings use REST list, not search
GitHub's `?labels=X` REST calls route through the search index, which had >27-min propagation lag on 2026-05-07 — newly-filed P0 bugs were invisible to both `sprint-service.sh refresh` and the command-center for almost half an hour. Both code paths now do unfiltered fetches (`state=open per_page=100` etc.) and filter client-side. Pattern: when correctness depends on seeing an issue right after it was created/labeled, never depend on `--search` or `?q=label:`. Commits `607c1398`, `e4e757a5`.

---

## 2026-04-28

### remove-db-matching-from-ai — AI workflows trust LLM output directly, no local DB second-guess
Removed `PhotoLogTool.applyDBMatching`, the `log_food` preHook DB lookup paths, and `PhotoLogMatcher.matchFood`. Multiple P0 bugs (#522, #524, #525) traced to DB second-guessing correct AI output — case-sensitive lookups, fuzzy false positives, silent-failure UX when user input doesn't look like a food name. Vision models trained on food photos beat string-distance; AI macros are within ~10-15%, within self-reported noise floor. DB remains for explicit user search (food_info tool), barcode scan, and manual entry. Commit `f97cf10`.

### photo-log-provider-fallback-chain — FallbackVisionClient tries Anthropic→OpenAI→Gemini on transient failures
Single-provider photo log meant any transient API failure (rate limit, 5xx, timeout) blocked the feature entirely. New `FallbackVisionClient` actor tries providers in order, advancing on transient errors and aborting immediately on permanent ones (401, malformed, offline). Keys fetched lazily so biometrics only prompt for the provider actually needed. Provider name appended to chat summary when fallback was used. Commit `866c074`.

### remote-byok-chat — cloud chat shares Photo Log key, no separate setup
`AIBackendType` gained `.remote`; `LocalAIService.useRemoteBackend()` accepts an apiKey from the iOS shell (DriftCore never touches Keychain). Cloud chat reuses Photo Log's `CloudVisionKey` entry + provider/model preference — once Photo Log is configured, chat is free. `Preferences.preferredAIBackend` defaults to `.llamaCpp` (privacy-first); the in-chat cpu/cloud toggle only renders when both backends are available so it can never be a no-op. `RemoteLLMBackend` now ships native parsers for Anthropic / OpenAI / Gemini SSE (text + tool calls), with categorized errors (`auth | rateLimited | quotaExceeded | transient | malformed`) so the chat layer can decide whether to auto-fallback to local (transient only) or surface a retry CTA. Photo conversational flow (`propose_meal` + `ProposedMealCardView`) deferred to a follow-up — the prompt protocol is baked into `IntentClassifier.remotePrompt`, but the inline-card UI + photo attachment are not yet wired. Issue #515.

## 2026-04-27

### simpler-snapshot-than-branches — patch files replace `crashed/<N>` branches
Crashed sessions now preserve WIP as `~/drift-state/wip/<N>.patch` (+ `.untracked.tar.gz` for new files), updated every 30s by the watchdog. Replaces the earlier `crashed/<N>-<ts>` branch model (`0abd0e9`). Reasoning: branch ceremony was too heavy — remote branches accumulated, recovery required PR/merge, multi-step protocol. Patch files give 1-line `git apply` recovery. Tradeoff accepted: local-only (drift-state has no remote) — if the machine dies the work is gone, which is true regardless. Latest commit: see `chore: hook-generated updates` cluster around 08:11–08:13 PDT.

### file-edit signal on stale-claim — work-in-progress no longer flagged
`check_stale_claim` now treats real file edits in working tree (filtered: not heartbeat/graphify/xcodeproj) as a third progress signal alongside commits + comments. Was: 60-min auto-flag on #426 fired despite 7 real edits sitting in working tree because session hit Anthropic API stream timeout right before its first commit. Combined with the threshold raise to 90min, false-positive rate should drop sharply.

### stale-claim threshold 60min → 90min
Multi-file senior tasks (new tool + tests + registration) legitimately need 60–90 min before first commit. The 60-min threshold was catching #426/#418-style work falsely. Override via `DRIFT_CLAIM_STALE_THRESHOLD_SECS` env var. Doesn't fully solve API-timeout work loss (the WIP-patch system above does that).

## 2026-04-26

### regress-on-raw-weights — slope/surplus/projection no longer use EMA series
`WeightTrendCalculator` used to do linear regression on EMA-smoothed values. For users with a recent regime change (gained-then-losing), the EMA lags actual weight by weeks; regressing on it measures the EMA *catching up*, not the user's actual rate. Reported as "+1870 kcal surplus" on a real user who was clearly losing. Now: regression on raw filtered weights, with two-window endpoint method (`avg of first 7-day window` vs `avg of last 7-day window`) for noise reduction. Adaptive widen to 42-day window when slope is below 0.5 lbs/wk threshold. Commit `e25afe3`.

### time-weighted EMA — display "Trend Weight" no longer cadence-dependent
EMA was entry-indexed (`α = 0.1` per entry). For weekly weighers, ~13 entries in 90 days meant the seed weight kept ~25% influence — Trend Weight stuck near old regime forever. Now: `α = 1 − 0.5^(Δt/halfLife)` where `halfLife` is in days (default 14). A daily and weekly weigher with the same actual trajectory now produce the same Trend Weight. Commit `e25afe3`.

### iOS test runner — `-skip-testing` not `-only-testing` for the bundle filter
`xcodebuild test -only-testing:DriftTests` silently dropped 1211 of 1249 tests in Xcode 26 — only XCTest classes get included with bundle-level `-only-testing`; Swift Testing (`@Test`) functions are bypassed unless filtered by full test ID. All operational hooks/scripts/CLAUDE.md migrated to `-skip-testing:DriftLLMEvalTests` which includes both frameworks. Autopilot had been shipping commits saying "All tests pass" while running 3% of the iOS suite. Commit `84a6e1a`.

### hard gate on Bash|Read|Grep|Glob until claim
Sessions were running `next --senior` (read-only) instead of `next --senior --claim`, then self-directing into work from the issue body without ever tagging in-progress. Initial Bash-only gate was bypassed via Read/Grep tools. Extended hook to gate all four PreToolUse tools, with a tight orient-only allowlist (`sprint-service.sh`, `gh issue view`, `cat docs`, `ls/pwd/echo`). After claim: full freedom. Commit `a26780e`.

### plan-comment required before commit (autopilot only)
Documented discipline ("post a Plan: comment before implementing") was at ~15% compliance. Auto-flag fires on `git commit` if the in-progress issue has no comment matching `^(Plan|Approach|Investigation|Progress|Resolution)\s*[:\-]`. Commit `ebff0c3`, fixed for stdin-JSON in `8d90f11`.

### `Source:` line required on every new sprint-task
Planning's old order ("P0 → product focus → admin feedback → roadmap → parity gaps") didn't track *which* source a task came from. Tasks could be created without mapping to anything. Now every body must include a `Source:` reference (one of: `campaign-<slug>`, `review-cycle-<N>`, `P0-<short>`, `feedback-<note>`, `roadmap-<item>`). Goal ≥90%. If planning can't map most new work to a source it's freelancing — flag and don't invent. Commit `cc8485d`.

### hooks defer pkill when xcodebuild archive is running
`coverage-gate.sh` (post-commit) and `preflight-check.sh` ran `pkill -9 -f xcodebuild` before their own xcodebuild test. While a TestFlight archive (5–10min) was running, a parallel session commit would kill the archive. Build 178 failed twice this way. All sites now `pgrep -f "xcodebuild.*archive"` and defer if found. Commit `58d90bb`.

### Design tenets in CLAUDE.md (philosophy, not procedure)
Sessions had no prescriptive philosophy doc — only the 4-line Color Philosophy. Added 10 tenets covering: AI chat as showstopper, privacy-first, goal-aware color, Indian food bar, friend feedback over telemetry, DriftCore-by-default, one-tier-per-test-file, no compat shims, three-lines-before-abstraction, build-test-after-every-change. Tenets, not patterns/file paths — survive folder moves. Commit `a690d43`.

---

*Older decisions live in commit messages, `Docs/refactor/`, `Docs/audits/`. This file starts here.*
