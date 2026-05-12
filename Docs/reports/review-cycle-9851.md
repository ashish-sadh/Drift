# Product Review — Cycle 9851 (2026-05-12)

## Executive Summary
The 59 cycles since the last review were the *surface-ships* sprint we kept promising. iCloud backup landed end-to-end across three PRs (#677 BackupService + ubiquity container, #678 BGTaskScheduler nightly job, #679 Settings UI + restore picker + stale banner + first-launch prompt) — the multi-sprint engine-without-surface anti-pattern is closed. Three design docs landed on main as planning groundwork (GLP-1 #574, FM lab extraction #665, FM use-case audit #666) with 11 impl tasks filed across them, queuing the next two sprints. Build 243 is on TestFlight (+4 since last review). Still zero Settings → Feedback traffic — the activation channel remains dark.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 243 (TestFlight) | +4 builds since 239 |
| Tests | ~1253 iOS DriftTests + ~1253 macOS DriftCore (8s warm) + 160+ LLM eval | flat (no big test additions this cycle) |
| Food DB | 5,420 | flat (ceiling locked at 6,000 by FoodDBSizeTests) |
| AI Tools | 35 (23 core + 12 insight) — 11 analytical engines + 1 new (protein_consistency_vs_recovery) = 12 | +1 (#730) |
| Coverage | flat | new code shipped with tests |
| P0 Bugs Fixed | 0 | no new P0s |
| Sprint Velocity | 23 closes in ~36h | strong (last cycle: 4 in 30h) |
| Open sprint-task queue | 50 | healthy (well below 60 triage threshold) |
| Open SENIOR queue | 14 | mostly design-impl tasks from 3 new design docs |

## What Shipped Since Last Review (cycle 9792 → 9851, ~36 hours)

User-visible:
- **iCloud backup — full end-to-end surface (#677, #678, #679).** Settings → Backup row, restore picker, stale-banner, first-launch prompt, BGTaskScheduler nightly job. The multi-sprint backup thread is finally shippable. Entitlements were reverted once (#677 → `65d44192`) when the provisioning profile lagged; re-landed cleanly. Testers can now configure backup, see backup state, and restore from a friend's device.
- **`protein_consistency_vs_recovery` analytical tool (#730).** Twelfth analytical insight engine. Pattern-detects whether the user's protein-adherence days correlate with their HealthKit recovery scores — exactly the cross-domain "AI health coach" positioning we need over Whoop's separate-view approach.
- **Cycle 9794 LLM prompt refresh (#735).** Five failure clusters from the deterministic gold set drove targeted few-shot example additions to Stage 1/3 prompts. Build 241 + 242 carry the improved routing.
- **TestFlight builds 240, 241, 242, 243** all published cleanly. The publish path is consistently healthy across the multi-cycle window.

Infra (operator-visible):
- **Three design docs landed on main: GLP-1 medication tracking (#574), Apple FM lab extraction (#665) + raw eval report, Apple FM use-case audit (#666).** Planning step 4 now decomposes each into 2-5 impl sprint-tasks; 11 design-impl-* tasks queued across them. The `design-impl-N` label routes them and the design issues stay open with `implementing` label until impl closes.
- **`scripts/design-service.sh approved-not-started` and planning step 4 wiring (`0422d922`).** Approved design docs no longer sit indefinitely — planning files the impl tasks every cycle. Five prior design docs (including #574/#665) had stalled at "approved+doc-ready" for 3-11 days each; new gate prevents that.
- **Harness: 1-task-per-session enforced + design-doc PRs auto-merge (`a00a81c2`).** Sessions were running 10+ tasks each, context bloated past task 5, output quality dropped. New rule: senior + junior exit after 1 commit, watchdog respawns within 60s. Design-doc PRs auto-merge after CI green (the doc *is* the deliverable; no human gate needed beyond the doc-ready label flow).
- **Active crash hunt cycle 9794 (#723).** Found and fixed force-unwraps in recent chat/analytical/backup code — tenet #8 continues to produce signal.
- **qa-tester verdict audit (#722) — closed.** Audit ran, findings appended to `qa-tester.md` Learnings section as cycle 9792 promised. The maintenance loop is doing what we said it would.
- **Sleep-food correlation tightened (#736).** Acceptance-driven QA polish on the analytical tool that shipped pre-cycle.

Items completed but flagged as deferred from cycle 9792 recommendations:
- **iCloud backup surface — DONE this cycle.** Cycle 9792 said "must close this sprint." It did.
- **qa-tester verdict audit — DONE this cycle (#722).**
- **Senior queue diversification — DONE this cycle (#730).** Non-backup analytical tool shipped.
- **#568 testPortionScaling_DecimalServings — STILL OPEN (7 reviews running).** No closure shipped. This is now a senior-discipline issue, not a code issue.

## Competitive Analysis
- **MyFitnessPal:** No major May 2026 release surfaced beyond the April GLP-1 / Today redesign window. Our `log_medication` (shipped via #580 plus #574 design doc now driving deeper impl tasks #751/#752/#753) is positioned to add chat-callable medication logging — MFP still requires screen navigation. ([Source — MyFitnessPal blog, Apr 28 2026](https://blog.myfitnesspal.com/glp-1-support-medication-tracking/))
- **MacroFactor:** April 2026 still the latest Monthly (recipe-photo scanning, Workouts improvements, "Favorites"). Their photo-scanning is cloud-backed; ours is BYOK on-demand. ([Source — MacroFactor April 2026 Monthly](https://macrofactor.com/mm-april-2026/))
- **Whoop:** WHOOP 5.0 (Healthspan, ECG, BP Insights) launched but is sensor-hardware-bound. Our `protein_consistency_vs_recovery` (#730) and `cross_domain_pattern_detector` (#739) lean into analytical depth on already-collected data — the lane Whoop's separate panels don't cover. ([Source — Whoop newsroom Apr 2026](https://www.whoop.com/newsroom))
- **Boostcamp:** Unchanged. Visual exercise content gap remains; #697 muscle-group icons still queued.
- **Strong:** Unchanged.

## Product Designer Assessment

*Speaking as the Product Designer persona:*

### What's Working
- **iCloud backup finally shipped end-to-end.** Six cycles of engine work translated to a Settings → Backup row, a restore picker, a stale-banner, and a first-launch prompt all landing in one sprint. The designer-rage from cycle 9792 ("we are 3 sprints into a feature no user has seen") is resolved. Now dogfood it: a friend wipes their device and restores. Until that runs, "shipped" means "shipped in code"; field validation is still missing.
- **Three design docs in one cycle is healthy product velocity.** GLP-1 (#574), Apple FM lab extraction (#665), and FM use-case audit (#666) all landed on main with implementation plans. Planning now files impl tasks for each — the design-to-impl pipeline is no longer leaky. This is the rare case where doing more *process* unlocked more product.
- **`protein_consistency_vs_recovery` is the right analytical tool to ship at this moment.** It pattern-detects whether your protein-adherence streaks correlate with recovery scores. That's the kind of "your data is telling you something" coach moment Whoop's separate Recovery and Habits panels never produce. Twelve analytical engines on-device is now a genuine differentiation surface.

### What Concerns Me
- **Settings → Feedback still at zero traffic, 5 days post-publish.** The recommendation from both cycle 9760 and 9792 was "DM friend testers directly OR add a dashboard activation prompt." Neither happened. The channel is structurally load-bearing — without it, every cycle ships in the dark. We have 23 closes in 36 hours and *no idea* if any of them moved the needle for actual testers. This is the longest-standing un-acted-on review recommendation. Either commit to one of the activation paths this sprint, or admit we're optimizing for what we can ship rather than what users want.
- **iCloud backup is shipped but un-dogfooded.** Cycle 9760's lesson was "engine without surface = unshipped." The corollary applies: "surface without dogfood = un-validated." #708 (E2E dogfood — wipe-and-restore on real device) is still open. The human or a friend tester needs to actually do the wipe-and-restore this sprint, not next sprint. If the restore doesn't work, we shipped a feature that *looks* like backup but doesn't backup.
- **No coaching-narrative release notes.** Build 240-243 all shipped — what did the release notes say? If the answer is "the changelog," then the analytical-tool depth we've been building (12 engines now) is invisible to testers. The product moves from "data logger" to "AI health coach" only if testers *believe* the coaching narrative. Release notes for the next 2 builds should lead with "Drift now coaches you across 12 dimensions," not enumerate the tools.

### My Recommendation
This sprint, the product moves are:
1. **Friend-tester activation, finally.** Either (a) human DMs the 3-5 friend testers asking "did you see Settings → Feedback?" and reports back, OR (b) we ship a dashboard one-time "How's it going?" prompt 7 days after install. The patient wait isn't working. Three sprints of zero traffic is enough signal.
2. **iCloud backup E2E dogfood (#708).** One friend, one wipe, one restore. If it works, the multi-sprint backup thread *actually* closes. If it doesn't, we have a P0 that's hiding behind "shipped in code."
3. **One curated cuisine ship (30 foods).** The food DB has room (5,420 / 6,000 ceiling). Indian regional or East Asian — pick one and ship 30 hand-vetted entries. Tenet #5 needs an active commit each cycle.
4. **Begin GLP-1 impl push.** Design doc #574 has three impl tasks (#751 data model, #752 log_medication AI tool, #753 Settings tab + weight chart marker). One full sprint covers all three. Match MFP's April release on chat-callable depth.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona:*

### Technical Health
- **Backup engine is sound and now has a surface.** BackupService + ubiquity container + BGTaskScheduler + Settings UI + restore picker. The rigor (atomic restore, ring buffer, integrity validation, allowlist+NSNull hardening, production-schema round-trip test from cycle 9792) paid off; the surface task closed cleanly because the engine was ready. This is the pattern: rigor first, surface when the engine holds.
- **Three design docs landing in 36 hours is *process* working as designed.** The recent planning-step-4 wiring (`0422d922`) and `design-service.sh approved-not-started` gate are doing exactly what they should: surfacing approved-but-not-started designs so impl tasks get filed. Five docs had stalled 3-11 days each at this gate; now they don't.
- **1-task-per-session + design-doc auto-merge (`a00a81c2`)** is the right discipline. Sessions running 10 tasks were a known context-bloat antipattern — we'd lost output quality past task 5. Exit-and-respawn within 60s is the cheaper path. Design-doc PRs auto-merging removes a 1-3 hour human-gate latency that was contributing to the design-stall pattern.
- **`protein_consistency_vs_recovery` followed the analytical-tool template cleanly.** Engine + tests + eval cases + registration in the same PR. The pattern is now solidly mechanized — adding the 13th and 14th tools should be cheap.

### Technical Debt
- **#568 (testPortionScaling_DecimalServings) — STILL on main, SEVEN reviews running.** Cycle 9760: "fix or gate it within this cycle." Cycle 9792: "Six reviews of 'still open' is unacceptable. Pick (a) fix or (b) `XCTSkipIf`." Cycle 9851: same recommendation, same status. The test continues to erode signal-to-noise. **This sprint, the very first senior task that picks #587 from the queue must `XCTSkipIf` it if not fixed by mid-cycle.** Process failure is now the primary failure mode here.
- **Senior queue is 11 design-impl tasks + 3 misc.** Single-domain bottleneck has been replaced by single-domain bottleneck. Three different design-doc impls (GLP-1 / FM lab extraction / FM use-case audit), each with 2-5 sub-tasks, means a single stuck senior can't grind the queue — but the *next* sprint will look like 14 design-impl tasks competing for 3 senior slots. **File 2-3 non-design-impl SENIOR tasks** so the queue has feature-work breathing room.
- **Heartbeat noise on main: still ~30+ heartbeats per real ship commit.** Cycle 9688, 9760, 9792 all flagged it. #642 (batching) was supposed to fix it. The batching landed; the noise persists. Either the batching window is wrong, the path is bypassed, or there's a second source. **File a sprint-task this cycle to investigate root cause** — not "verify the fix" again, but a fresh diagnostic.
- **iCloud backup E2E dogfood (#708) — still open after the surface shipped.** Engineer rigor without designer validation is half a ship. The test that matters now is: wipe a real device, restore from iCloud, verify all domains came back. Until #708 closes, backup is technically debt — we're carrying a feature we haven't proven works in the field.
- **No regression eval ran on the cycle 9794 prompt refresh (#735) yet.** Five failure clusters were addressed with few-shot additions to Stage 1/3. The gold set ran against the *changed* prompts (the closure required it) but no cross-stage eval audited downstream effects. Add a "post-prompt-refresh eval" gate to the LLM-prompt-audit sprint-task template.

### My Recommendation
This sprint, the engineering moves are:
1. **#568 — close it this cycle. No exceptions.** Pick (a) fix the decimal-serving rounding or (b) `XCTSkipIf(ProcessInfo.processInfo.environment["DRIFT_SKIP_KNOWN_FAILURE"] != nil)`. Seven reviews of "still open" is a discipline crisis, not a code crisis.
2. **iCloud backup E2E dogfood (#708) — must close this sprint.** Wipe-and-restore on real device. If it works, the multi-sprint thread *actually* closes. If it doesn't, we have a P0 that the surface PR masked.
3. **Heartbeat noise root-cause diagnostic.** Sprint-task: identify why ~30+ heartbeats per ship commit still appear despite #642 batching. Could be wrong window, second source, or a race. Don't re-verify; diagnose.
4. **Diversify senior queue with 2-3 non-design-impl tasks.** Pure design-impl backlog has the same fragility as the all-backup queue did. Chat-pipeline depth or analytical-tool refinement.
5. **Add post-prompt-refresh eval gate.** Standing rule: LLM prompt audit tasks must run BOTH the changed gold-set AND the full IntentClassifier + DomainExtractor cross-stage eval to catch downstream effects.

## The Debate

**Designer:** The headline this cycle is iCloud backup finally shipped end-to-end — three PRs in two days. That closes the multi-sprint thread that's been embarrassing us. Plus the design-impl pipeline is unstalled (#574, #665, #666 all landed with impl plans). I'd say this sprint is the strongest in months. But the *user* layer is still the gap: zero feedback traffic, no dogfood validation on backup, no coaching narrative in release notes. We ship faster than we validate.

**Engineer:** Agreed on velocity. I'd add four discipline items that have all slipped one or more cycles: (a) #568 still open after seven reviews — this is now a culture problem; (b) #708 E2E dogfood is the missing half-ship on backup; (c) heartbeat noise *still* not root-caused after #642; (d) senior queue is all design-impl — needs diversification. Each of these is small. None is hard. They keep slipping because we prefer building new things to closing what we built.

**Designer:** Fair. Sequence: backup E2E dogfood and friend-tester activation are the user-layer must-do's. #568 + heartbeat diagnostic + senior diversification are the engineering must-do's. One cuisine ship and starting GLP-1 impl if budget allows.

**Engineer:** Agreed. One process ask: the cycle 9792 ask that new sprint-tasks declare `qa-scope:` — has that landed in practice? If not enforced, we lose the discipline before it's a habit. Verify by spot-checking 5 recent sprint-task bodies.

**Agreed Direction:** **Validate-and-discipline sprint.** Backup E2E dogfood (#708) closes. Friend-tester activation finally happens (DM OR dashboard prompt). #568 resolved (fix or `XCTSkipIf`). Heartbeat noise root-cause diagnostic filed. 2-3 non-design-impl SENIOR tasks filed. One cuisine ship (30 hand-vetted foods). GLP-1 impl push begins (data model + AI tool). Coaching-narrative release notes for next 2 builds. All new tasks declare `qa-scope`.

## Decisions for Human

1. **Friend-tester activation — the third review in a row.** Settings → Feedback has zero traffic 5 days post-publish. Both cycle 9760 and 9792 recommended action; neither happened. Pick:
   - **(a) Human DMs 3-5 friend testers this week asking "did you see Settings → Feedback?"**
   - **(b) Ship a dashboard one-time "How's it going?" prompt 7 days post-install.**
   - **(c) Keep waiting — accept we're shipping in the dark.**
   - Recommendation: (a) this sprint. Three sprints of null signal is enough.

2. **iCloud backup E2E dogfood (#708) — who runs it?** Surface shipped, dogfood didn't:
   - **(a) Human wipes one device, restores, reports.**
   - **(b) Friend tester runs the wipe-and-restore (riskier — if restore fails, real data loss).**
   - **(c) Synthetic dogfood — a test that simulates wipe-and-restore on simulator (lower-fidelity but safer).**
   - Recommendation: (a). The friend-tester option is too risky pre-validation; the synthetic option doesn't test ubiquity container.

3. **#568 testPortionScaling_DecimalServings — seven reviews running.** Pick:
   - **(a) Fix the decimal-serving rounding (engineering preference).**
   - **(b) `XCTSkipIf(ProcessInfo.processInfo.environment["DRIFT_SKIP_KNOWN_FAILURE"] != nil)` and document as known edge case.**
   - Recommendation: (b) by mid-cycle if not fixed. Seven cycles of noise is enough.

4. **Heartbeat noise — investigate or accept?** Still ~30+ heartbeats per ship commit despite #642 batching landing. Pick:
   - **(a) File a fresh diagnostic sprint-task (not a re-verify) — find the root cause this cycle.**
   - **(b) Accept the noise; move on; the commit history is operational-only.**
   - Recommendation: (a). Three reviews of the same complaint without diagnosis is process drift.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
