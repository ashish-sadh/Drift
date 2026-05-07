# Product Review — Cycle 9441 (2026-05-07)

## Executive Summary
The reliability + delivery sprint shipped. TestFlight is unblocked — builds 224, 225, 226 published in the last 18 hours, ending the 17-build dark stretch. The "proactive coach" triad is now live in users' hands (protein adherence, glucose spike, workout consistency), Settings → Feedback row finally shipped after 12-cycle deferral, and a launch-watchdog crash was caught and fixed before it bit testers. Next bottleneck moves from delivery to user signal: with feedback now wired, the question is whether anyone actually uses it.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 226 in project.yml / 226 on TestFlight | ✅ caught up; gap closed from 17 → 0 |
| Tests | ~1219 iOS + 714 macOS DriftCore (8s warm) | flat |
| Food DB | 11,072 | +30 East Asian (#623), +30 Caribbean (#622), +30 Indian protein (#621) since #62 |
| AI Tools | 34 (23 core + 11 insight) — 10 analytical engines | flat |
| Coverage | ExerciseService 67%, TDEEEstimator 55% | flat (no regressions) |
| P0 Bugs Fixed | 3 (#650 photo logging, #651 recipe builder, launch crash) | +3 |
| Sprint Velocity | ~10 features shipped of ~15 since cycle 8999 | high; ~67% |
| Open sprint-task queue | 10 | healthy (well below 60-task triage threshold) |

## What Shipped Since Last Review (cycle 8999 → 9441, ~30 hours)

User-visible:
- **TestFlight published 3 builds (224, 225, 226).** First public deliveries since 2026-04-26 — every feature merged in the prior 17-build dark window is now in testers' hands.
- **Glucose spike alert on dashboard (#631)** — Surfaces a card when blood glucose rises sharply after a meal. Third proactive card in the triad.
- **Macro rings polish (#628)** — Goal-aware fill color (green = under target for weight loss, red = over), tap-for-tooltip showing consumed/target/remaining/% per macro, smooth fill animation.
- **Food diary collapsible meal sections (#629)** — Breakfast/lunch/dinner/snack groupings, tap to expand/collapse.
- **Food diary inline edit (#630)** — Edit-in-context-menu for any logged entry.
- **Settings → Feedback (#617)** — Mailto-prefilled with device + build info; alert fallback if no mail client.
- **GLP-1 weekly dose reminder (#620)** — Weekly nudge on injection day if no dose logged in 7 days; user-toggleable in Settings.
- **Per-stage elapsed indicator in chat typing hint (#618)** — After 0.5s, typing indicator reveals "(1.2s)" so users see the AI is still working.
- **Compound lift form cues (#624)** — Top 20 lifts now have form/instruction cards.
- **Photo logging fix (#650)** — Extract JSON object from AI response (was using whole string and failing).
- **Recipe builder bypass for single confirmed items (#651)** — Single-item meals skip the multi-item recipe builder.

Infra (operator-visible, not tester-visible):
- **TestFlight hook hardening (#640, #641)** — Hook respects `session-type=human` and `testflight-archive-failed` flag; stops bumping `CURRENT_PROJECT_VERSION` while archive is broken.
- **Heartbeat commit batching (#642)** — Stop polluting `git log` with per-minute heartbeat snapshots.
- **State.md pre-commit freshness hook (#643)** — Warns when build counter lags project.yml.
- **State.md refresh to build 220 (#644), then 224 (#645).**
- **Releases.json gap reconciliation (#646)** — Builds 219, 220 backfilled.
- **Command Center bypass GitHub search index (e4e757a)** — Sprint listings now use REST list calls; no longer affected by 27-min search index lag.
- **Launch watchdog deferral (`36f0cb12`)** — `NotificationService.refreshScheduledAlerts()` + widget refresh deferred via `Task { @MainActor }` so iOS launch budget shrinks. Caught before it bit users.

## Competitive Analysis
- **MyFitnessPal:** April 2026 GLP-1 medication tracking + custom reminders is now in shipping (Premium feature). Their *coming soon* list mentions side-effect tracking — that's a future fight. Our GLP-1 logging is shipped; weekly reminder shipped this cycle (#620). MFP's Today tab redesign continues to attract user complaints.
- **Whoop:** Behavior Insights live (5+ "yes" + 5+ "no" logs in 90 days → habit-to-recovery correlation). Advanced Labs Uploads launched — biomarker × WHOOP data integration. Both directly compete with our analytical-tools strategy.
- **MacroFactor:** April 2026 release adds **photo recipe scanning from cookbooks** (snap → ingredient pre-fill). Recipe creation depth is now their differentiator. Their Workouts app continues to expand.
- **Boostcamp:** Unchanged. Still gold standard for exercise visual presentation; we're still text-only on 960 exercises.
- **Strong:** Unchanged. Minimalist workout logging.

## Product Designer Assessment

### What's Working
- **The reliability + delivery sprint thesis was correct.** The cycle 8999 review's debate ended with "stop building features users can't see"; one cycle later, every feature merged since 2026-04-26 is in testers' hands. Three builds in 18 hours after a 17-build dark stretch — the queue was full of real value, the constraint was always the publish path.
- **The "proactive coach" identity is now coherent in production, not just on paper.** Protein adherence + glucose spike + workout consistency cards render together on dashboard. A tester opening build 226 sees a recognizably different app from build 203 — Drift now tells them what to look at, not just lets them log.
- **Settings → Feedback finally shipped.** 12-cycle deferral closed. The mailto prefill (device + build + feedback) means every report has the metadata triage needs. Combined with the launch crash fix, the next 7 days should produce the first real user signal in 6 cycles.

### What Concerns Me
- **Zero TestFlight feedback since the publish window opened.** Builds 224, 225, 226 have shipped to TestFlight in the last 18 hours; no comments on any report PR (#649, #639, #637, #613, #599 all show 0 comments). It is too early to draw a conclusion, but the structural risk remains: if testers don't open the app, "shipped" is still "invisible." Settings → Feedback alone isn't enough — we need a reason for testers to come back.
- **No "what changed" in-app changelog.** We just shipped 17 builds of work in 3 builds. Testers have no signal of what to look for. MacroFactor and MFP both surface release notes inline. A first-launch sheet listing "new since you last opened: 17 features, 3 fixes" would make the rapid catch-up feel like a milestone, not just code.
- **Photo logging + recipe builder bugs (#650, #651) suggest the chat path has shipped-then-broke regressions.** Both were fixed quickly, but they're surface-level bugs in flows we treat as showcase features. We're not running enough end-to-end smoke tests on the chat path before publish — every TestFlight build deserves a 5-minute "log a meal, then a photo, then ask analytical question" walkthrough that catches these before testers do.

### My Recommendation
Two product moves this sprint:
1. **Build the in-app "what's new" sheet.** First-launch on a fresh install, plus a "see what's new" entry in Settings. Pulls from `command-center/releases.json` so it stays current automatically. The 3-build catch-up is the moment to surface; if we don't, the rapid delivery feels invisible.
2. **Pre-publish smoke checklist as a doc.** Not automation — just a 5-line markdown checklist someone runs before a TestFlight build: log a food via chat, attach a photo, ask an analytical question, edit a meal, navigate via chat. Two of the last 3 publishes shipped a chat regression that a 5-minute walkthrough would have caught. The discipline matters more than the tooling.

## Principal Engineer Assessment

### Technical Health
- **Test suite is fast and growing.** 714 macOS DriftCore tests at ~8s warm + ~1219 iOS at ~25s + ~160 LLM eval. The pure-logic Tier-0 split is delivering — every commit since the migration runs the gold set fast enough to catch regressions before they ship.
- **Build pipeline is healthy.** TestFlight gap closed. `CURRENT_PROJECT_VERSION` no longer bumps on failed archives. State.md drift is now a pre-commit warning, not a review-cycle finding.
- **Launch budget is now bounded.** `36f0cb12` moved notification + widget refresh out of the awaited launch path. iOS watchdog has ~20s; we were creeping past that with 5 BehaviorInsight alerts × 7-day windows + medication + GLP-1 + HealthKit + weight trend + TDEE. The fix lands before testers hit it.

### Technical Debt
- **AIChatView at 400+ lines is now the binding refactor decision.** The next chat feature touch should extract a `ChatViewModel` — defer-by-default until a real feature forces it (per cycle 8938 rule). Ticket #647 already shipped the first extraction; subsequent extractions should ride on feature work.
- **GitHub search index lag is now load-bearing infra.** Two recent fixes (sprint-service.sh refresh, command-center) bypass `?labels=X` REST calls because the search index propagation is unreliable. This is a vendor problem we cannot fix; the right pattern is "fetch unfiltered, filter client-side" anywhere correctness depends on seeing a just-created issue.
- **Heartbeat commits are still landing (b8cb442e, 9b680028, etc.) despite #642's batching.** Either the batching window is too short or there's a separate code path. Verify the next 24 hours of `git log` show <1 heartbeat per real commit; if not, file a follow-up.
- **Two test failures listed in roadmap as still-open: #568 (testPortionScaling_DecimalServings).** This has been on main across 4 reviews. Either fix it or close it as known-failing with an environment-gate. Long-running known failures are noise that mask real regressions.
- **No automated E2E smoke before publish.** The Designer's "5-minute walkthrough" recommendation lands here too — a deterministic Tier-1 test that walks a meal log, photo log, edit, navigate, and analytical query would have caught #650/#651 before publish. The cost is one new test class; the value is every future publish.

### My Recommendation
Two engineering moves this sprint:
1. **Verify heartbeat batching landed correctly.** Check `git log --oneline -50` after 24 more hours. If heartbeat commits still exceed real commits, fix the gap. The batching was not what we asked for.
2. **Ship the chat smoke test.** A Tier-1 `ChatPathSmokeTests.swift` — meal logged via chat, photo log card rendered, edit_meal works, navigate switches tab, analytical query returns non-empty. ~60-line test, runs in ~3s. Catches #650/#651-class regressions at commit time, not at TestFlight time.

## The Debate

**Designer:** TestFlight is unblocked, the queue is small, and the proactive triad is live. The next sprint should be about activation, not more features. Build the "what's new" sheet, ship a smoke checklist, and let the user signal drive the next cycle. Premature feature work right now wastes the signal we're finally about to get.

**Engineer:** Agree on the activation theme, but I want to pin a quality floor before we scale activation. Two regressions shipped this cycle (#650, #651) on chat — our most-marketed surface. If we activate testers and they hit a chat bug on first try, the "what's new" sheet just amplifies the pain. Smoke test first, then activation.

**Designer:** Fair. Sequence: smoke test PR ships first, activation work ships second, in same sprint. Both are small. The "what's new" sheet is ~half a day; the smoke test is ~half a day. We can do both this sprint and still have headroom for one analytical-tool ship if activation signal arrives early.

**Engineer:** Agreed. One additional ask: every new sprint task this cycle must include either (a) a smoke-test acceptance criterion if it touches chat, or (b) a "no impact on chat path" assertion if it doesn't. We can't keep shipping chat regressions on flagship features.

**Agreed Direction:** Activation + quality floor sprint. Ship the chat smoke test (eng), the "what's new" sheet (product), tighten heartbeat batching (infra). Hold feature work to two analytical tools or food DB additions max — let user signal from #617 drive the next cycle's direction.

## Decisions for Human

1. **The proactive triad is live. Should we surface it in TestFlight release notes?** Currently shipped silently — testers see new dashboard cards but no "Drift now coaches you" framing. Options:
   - **(a) Add a one-line release notes lead** — "New: Drift now alerts you when protein adherence drops, glucose spikes after meals, or workout consistency stalls." Visible in TestFlight UI.
   - **(b) Build the in-app "what's new" sheet** — Higher cost, higher impact (forces tester eyes on the new value).
   - Recommendation: (a) immediately for next build, (b) as the activation sprint deliverable.

2. **Are #568 (testPortionScaling_DecimalServings) and #587 still active failures?** They've been listed as open across 4 reviews. If they're real, fix them. If they're known-failing edge cases, gate behind an environment variable so they stop showing as "test failure on main." A perpetual-known-failure on main slowly eats trust in the test suite as a quality signal.

3. **First TestFlight feedback is about to arrive.** Should we set up a single triage channel (Slack? GitHub Discussions? Just the Issue tracker?) so user reports don't fragment across email + GitHub? Settings → Feedback uses mailto, so email is the default — but inbox archaeology is fragile.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
