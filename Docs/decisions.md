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

## 2026-04-28

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
