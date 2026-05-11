# Product Review — Cycle 9792 (2026-05-10)

## Executive Summary
The 32 cycles since the last review were a *quality-floor* sprint, not a flagship-feature sprint — and that was the right call. We landed the food-DB curation tenet (11,162 → 5,420, ceiling locked at 6,000 by a Tier-0 test), expanded `ChatPathSmokeTests` to cover the new analytical tools, fixed the user-reported "Refresh Food Database" freeze (#705), removed a TimeZone force-unwrap in the backup ring buffer (#715), and added production-schema round-trip backup coverage. Build 239 is on TestFlight. iCloud backup engine remains in flight but the surface (Settings → Backup row) has not landed — the multi-sprint senior thread is now overdue for visible shipping. Still zero traffic on Settings → Feedback ~3 days after publish.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 239 (TestFlight) | +4 builds since 235 |
| Tests | ~1253 iOS DriftTests + ~1253 macOS DriftCore (8s warm) + 160+ LLM eval | +ChatPathSmokeTests new flows, +production backup round-trip |
| Food DB | 5,420 | -5,742 (one-time USDA SR Legacy cleanup; ceiling locked at 6,000) |
| AI Tools | 35 (23 core + 12 insight) — 11 analytical engines | flat |
| Coverage | flat | new code shipped with tests |
| P0 Bugs Fixed | 1 (#705 DB refresh freeze) | +1 |
| Sprint Velocity | 4 closes in ~30h (#705, #707, #709, #715, #717) | moderate (last cycle: 9) |
| Open sprint-task queue | 40 | healthy (well below 60 triage threshold) |
| Open SENIOR queue | 8 | 7 of which are backup-thread or design-docs |

## What Shipped Since Last Review (cycle 9760 → 9792, ~30 hours)

User-visible:
- **Food DB curated to 5,420 from 11,162 (#717).** Build 217's USDA SR Legacy bulk import (11,162 entries, 3.7 MB) was diluting search relevance for the Indian-first entries that justify the app. Curation pass dropped 4,104 multi-comma-bulk + 1,638 verbose-USDA entries; hand-curated Indian-first and international cuisine retained. `FoodSearchGoldSet` regression: Indian 10/10, S-Indian 14/14, Ethiopian 8/8, Persian 5/5, Turkish 7/7, Snacks 8/8, West-African 9/10 (Chin Chin still present). New Tier-0 `FoodDBSizeTests` locks the ≤6,000 ceiling so future imports can't silently bloat. State.md scorecard now reads 5,420 not 11,072.
- **Food DB Refresh freeze fix (#705).** Friend-reported bug: the "Refresh Food Database" button in Settings froze the app with no feedback. Root cause: synchronous DB rebuild on the main thread. Fix: off-main with progress indicator + status feedback. First user-reported bug from the unblock window — turnaround was same-cycle.
- **Backup TimeZone force-unwrap removed (#715).** Active crash hunt for tenet #8 found a `TimeZone(identifier:)!` in the backup ring buffer's daily-key derivation. Replaced with a fallback; ring buffer no longer crashes on edge-case timezones.

Infra (operator-visible):
- **`FoodDBSizeTests` Tier-0 ceiling test** ensures the next session that ships a food import either keeps under 6,000 or fails CI explicitly. Process tenet #9 ("curated, not exhaustive") is now machine-enforced, not just doc-enforced.
- **Planning step 9a: food DB curation gate** (`603ae058`). Each planning cycle now reads `foods.json` line count, files/keeps a curation task if above ceiling, and rejects batch-import feature requests without a curation plan attached.
- **`ChatPathSmokeTests` expanded (#709).** Tier-0 deterministic chat-path coverage for `cycle_biomarker_correlation`, multi-intent splitting, and `food_timing_insight` — the analytical tools that shipped without end-to-end smoke last cycle.
- **`BackupService` production-schema round-trip test (`d97f8434`).** Real GRDB schema rows (food entries, weight, exercise, sleep, supplements) now round-trip through backup encode/decode with assertions. The Codable+array fix (#701) had a unit test; this one is the integration-shaped test that catches schema-drift regressions.
- **`qa-tester` subagent maintenance loop (#707).** Planning step 10 now reviews QA verdict comments on closed sprint-tasks looking for over-flagging, under-generating, and effective-pattern signals. Same sediment-and-prune rules as personas. Without this loop the subagent calcifies into rubber-stamp ceremony.
- **TestFlight builds 236, 237, 238, 239** all published cleanly. The publish path remains healthy — no new dark stretches.

## Competitive Analysis
- **MyFitnessPal:** GLP-1 Support (April 28, 2026) is now widely covered — medication type, dose, injection site, side effect tracking, integrated into the Today screen. ([Source — MyFitnessPal blog, Apr 28 2026](https://blog.myfitnesspal.com/glp-1-support-medication-tracking/), [Source — GlobeNewswire, Apr 28 2026](https://www.globenewswire.com/news-release/2026/04/28/3282728/0/en/MyFitnessPal-Launches-Comprehensive-GLP-1-Support-Helping-Users-Stay-Consistent-and-Build-Habits-Alongside-Medication-to-Maximize-Their-Experience.html)). Drift's `log_medication` (#580, GLP-1 design doc #574) already mirrors this with the supplement architecture. The Today screen redesign continues to draw complaints but MFP is holding the position. **Our edge:** ours is chat-callable. MFP requires going to a screen, navigating to medication, picking from a list. We can say "logged my injection."
- **MacroFactor:** April 2026 still the latest published Monthly (recipe-photo scanning, Workouts improvements, "Favorites" feature for saved foods). No May 2026 release notes surfaced yet. ([Source — MacroFactor April 2026 Monthly](https://macrofactor.com/mm-april-2026/)). MacroFactor "Favorites" overlaps our recent-foods quick-log (shipped earlier) — feature parity on the convenience pattern.
- **Whoop:** No new flagship release surfaced this cycle. Behavior Insights + cycle tracking remain separate views; our `cycle_biomarker_correlation` (#689) is still the first-mover on cross-domain in that lane.
- **Boostcamp:** Unchanged. Visual exercise content gap remains; our 960 exercises remain text-only. Exercise muscle-group icons (#697) still in queue.
- **Strong:** Unchanged.

## Product Designer Assessment

*Speaking as the Product Designer persona:*

### What's Working
- **The food-DB curation pass is the kind of work that's invisible-when-right and disastrous-when-wrong.** A user searching "paneer" was previously sifting through "Paneer, NS as to type, raw" alongside the dish entries; now they see the curated Indian-first results. Search ranking has been freed from the USDA noise floor. This advances tenet #5 (Indian food is the bar) and tenet #9 (curated, not exhaustive) simultaneously.
- **Same-cycle response to #705 reinforces the feedback loop we need.** A friend reported the freeze; we shipped the fix in the same cycle and added progress feedback. This is the loop the cycle 9760 review identified as fragile — first real test passed.
- **Tier-0 `FoodDBSizeTests` is a beautiful guardrail.** Future sessions can't silently bloat foods.json past 6,000 entries. Process tenets that get encoded as tests are the only ones that survive a year.

### What Concerns Me
- **iCloud backup *still* has no user-facing surface.** Engine work has been in flight for ~6 cycles. The cycle 9760 review explicitly called out: "Engine without surface = ineligible for dogfooding = no field validation." Two cycles later, #679 (Settings UI + restore picker + stale banner) is still pending. We are now 3 sprints into a feature that no user has seen. The principal engineer's preference for rigor is paying off in engine quality, but the designer's clock is past tolerance — until a friend can do a wipe-and-restore on a real device, we don't know if any of this works.
- **Settings → Feedback still at zero traffic 3 days post-publish.** PRs #649, #673, #702, #703, #719 all show `0 comments`. The activation lever shutoff (in-app "What's New" sheet declined) means we have *no* working signal channel right now. The one real bug (#705) came in via friend report, not Settings → Feedback. We need to confirm whether testers even *know* the row exists. Recommendation from 9760 was "DM friend testers directly" — has that happened? Without traffic, we keep shipping in the dark.
- **The proactive coaching narrative isn't reaching testers.** TestFlight notes (#710) was a queued task but the actual release-notes copy for builds 236-239 — did they read as a coaching narrative or as a build-number changelog? If the latter, we shipped the analytical tools and nobody noticed.

### My Recommendation
This sprint, the product moves are:
1. **iCloud backup SURFACE, end of story.** Settings → Backup row + restore picker (#679) must close this sprint. The senior queue has 4 backup-thread tasks open (#677, #678, #679, #708); they need to consolidate down to "shipped + dogfooded" not "engine ready + UI pending." This has been the recommendation for 2 sprints; honor it or admit we don't actually want to ship backup.
2. **Confirm friend-tester activation.** Either (a) human DMs the friend testers asking "did you see Settings → Feedback?" and reports back, OR (b) we ship a one-time dashboard prompt 7 days after install ("How's it going? Tap to send a quick note"). The patient default isn't working — we're collecting null signal.
3. **One curated cuisine ship (30 foods).** Now that the curation pass shipped, the food DB has *room*. Indian regional or Mediterranean — pick one and ship 30 hand-vetted entries. Tenet #5 needs an active commit, not just an inheritance from the old DB.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona:*

### Technical Health
- **The food-DB curation pass + Tier-0 ceiling test is a structural win.** 11,162 → 5,420 reduces install-size, cold-launch DB-init time, and search-ranking dilution all at once. The `FoodDBSizeTests` mechanism is the right pattern: encode the rule, fail the build. The next time a session reaches for a 1,000-row USDA dump, the test will block.
- **`ChatPathSmokeTests` expansion (#709) closes the cycle 9760 gap.** All 5 analytical/coaching paths shipped this cycle now have Tier-0 deterministic smoke coverage. We are no longer shipping chat behaviors blind to regression risk.
- **Active crash hunt (#715, tenet #8) found a real force-unwrap.** TimeZone force-unwraps in date-arithmetic paths are the exact class tenet #8 was added to catch. The hunt protocol is producing signal.
- **Production-schema round-trip backup test (`d97f8434`).** This is integration-shaped testing inside Tier-0 — round-tripping real GRDB rows through the backup encoder/decoder. It will catch schema-drift regressions that the per-field unit tests miss.

### Technical Debt
- **#568 (testPortionScaling_DecimalServings) — STILL on main, six reviews running.** The cycle 9760 recommendation was "fix or gate it within this cycle." No closure shipped. This is now a process failure, not a code failure — the test continues to erode the suite's signal-to-noise. **Force the issue this sprint:** session that picks #587 (still in queue) must `XCTSkipIf(ProcessInfo.processInfo.environment["DRIFT_SKIP_KNOWN_FAILURE"] != nil)` if not fixed by mid-cycle.
- **iCloud backup engine has expanded faster than the surface.** 7 implementation sub-issues, 2 hardening follow-ups (#700, #701, #687, #715), all engine-side. The surface (Settings UI, BGTaskScheduler integration, E2E dogfood) is still in queue. Engineering rigor has won; product velocity has lost.
- **Heartbeat noise on main remains unaddressed.** The cycle 9760 review flagged it; the cycle 9688 review flagged it (#642 was supposed to fix it via batching). The recent `git log --oneline -40` still shows ~30 heartbeats per real ship commit. Either the batching window is too short or the path isn't hitting it. This is not a P0, but it's a credibility hit when reading commit history.
- **qa-tester verdict effectiveness — still unaudited.** Cycle 9760 review recommended auditing the next 5-10 verdict blocks for whether they actually traced the code path. The maintenance loop (#707) shipped, but the AUDIT hasn't happened yet. If verdicts are rubber-stamped, the hook is theater.
- **Senior queue is 7 backup-thread tasks + 2 design-doc tasks.** That's a single-domain bottleneck. If the backup senior gets stuck for any reason, the senior queue grinds. Non-backup senior work is starving.

### My Recommendation
This sprint, the engineering moves are:
1. **Land iCloud backup user-facing surface (#679) and dogfood end-to-end (#708).** Close the multi-sprint thread. If this slips again, the next sprint should be a *consolidation* sprint where we stop adding backup work and start using what we built.
2. **Resolve #568 within this cycle.** Pick one: (a) fix the decimal-serving rounding, or (b) `XCTSkipIf` behind `DRIFT_SKIP_KNOWN_FAILURE` env var. Six reviews of "still open" is unacceptable.
3. **Run the qa-tester verdict audit promised last cycle.** Read 5-10 recent verdict blocks. Check whether scenarios actually trace the code path (look for commit hashes on "BUG FIXED", file:line on "WORKS AS UPDATED") or rubber-stamp. If rubber-stamping is the failure mode, tighten the hook.
4. **Diversify senior queue.** File 2-3 non-backup SENIOR tasks (e.g., chat-pipeline depth, analytical-tool refinement) so a stuck backup senior doesn't grind the queue.

## The Debate

**Designer:** The cycle 9760 sprint did the quality-floor work it promised — Tier-0 smoke for analytical tools shipped, crash hunt produced signal, curation pass landed, friend-reported bug closed same cycle. The story now is: *we have the engine; we don't have the surface.* iCloud backup is the headline play, and we've been one decision-stroke away from shipping it for two sprints. This sprint, the only thing that matters is the Settings → Backup row landing. Everything else is secondary.

**Engineer:** Agreed on the priority. I'd add three quality-floor items that must NOT slip again: (a) #568 resolution — six reviews of "still open" means our discipline is broken, not just the test; (b) qa-tester verdict audit — we shipped the loop, we haven't audited the output; (c) senior queue diversification — single-domain backlog is fragile. None of these are big tasks, but each has slipped one cycle. They slip again, we have a culture problem.

**Designer:** Fair on all three. Sequence: backup surface ships first (it's the headline), then the three quality items in parallel, then one cuisine ship if budget allows. If budget doesn't allow the cuisine, fine — but the backup surface and the three quality items are not optional.

**Engineer:** Agreed. One process ask: the qa-scope: declaration on new sprint-task bodies (cycle 9760 ask) — has that landed? If not, this sprint's new tasks must enforce it. Otherwise we lose the discipline before it's a habit.

**Agreed Direction:** **Surface-and-discipline sprint.** Backup user-facing surface ships (#679) + E2E dogfood (#708) closes. #568 resolved (fix or gate). qa-tester verdict audit run. Senior queue gets 2-3 non-backup SENIOR tasks filed. One curated cuisine ship if budget allows. All new tasks declare qa-scope.

## Decisions for Human

1. **iCloud backup surface — what's blocking #679?** The cycle 9760 review recommended it ship this sprint. It did not. Is the design unclear, the senior queue saturated, or something else? Without unblocking, the entire backup thread sits inert.
   - **(a) Pick up #679 in this sprint with explicit "this must close" mandate.**
   - **(b) Cut scope: ship just "Back up now" button (no restore UI), defer restore to next sprint.**
   - **(c) Pause backup work entirely and shift senior queue elsewhere.**
   - Recommendation: (a). Engine is too rigorous to leave dark.

2. **#568 — six reviews of "still open" is enough.** Pick:
   - **(a) Fix the decimal-serving rounding (engineering preference).**
   - **(b) `XCTSkipIf(ProcessInfo.processInfo.environment["DRIFT_SKIP_KNOWN_FAILURE"] != nil)` and document as known edge case.**
   - Recommendation: (b) if not closed by mid-cycle. The test is not load-bearing; the noise is.

3. **Friend-tester activation.** 3 days post-publish, zero Settings → Feedback traffic. Options unchanged from cycle 9760:
   - **(a) Direct DM friend testers asking about the row.**
   - **(b) Add one-time dashboard "How's it going?" prompt 7 days post-install.**
   - **(c) Keep waiting.**
   - Recommendation: (a) this sprint. Without it, we ship blind.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
