# Product Review — Cycle 10262 (2026-05-13)

## Executive Summary
The ~411 cycles since cycle 9851 (24h elapsed) were the **Apple Foundation Models breakthrough sprint**. Four of five FM Quick Wins from design-666/665 shipped (#744 CompositeFoodEntry, #745 WorkoutEntry, #748 nutrition label OCR migration, #749 lab report hybrid regex+FM extraction). GLP-1 implementation began (#751 Medication data model + #752 log_medication AI tool). The cycle 9851 review's discipline asks all landed: heartbeat noise root-caused and shipped (#758 — routed to side branch), Dashboard 7-day Feedback activation banner shipped (#759), #568 confirmed already-closed (procedural loop broken via #757, the original fix shipped 2026-05-03 via #571). 12 closes in 24h — strongest single-cycle velocity in any review. **One blocker:** TestFlight build 243 archive failed yesterday 20:23 PDT (DriftCore compile interrupted); none of this sprint's work has reached testers yet.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 242 published / 243 archive-failed | TestFlight blocked on 243 |
| Tests | ~1253 iOS DriftTests + ~1253 macOS DriftCore (+47 new FoodLogIntentExtractor tests) + 160+ LLM eval | +47 from FM extractor suite |
| Food DB | 5,420 | flat (no cuisine ship this cycle — see designer concern) |
| AI Tools | 35 (23 core + 12 insight) — 12 analytical engines | flat |
| Coverage | flat | new code shipped with tests (47 FoodLogIntentExtractor tests) |
| P0 Bugs Fixed | 0 | no new P0s — health is good |
| Sprint Velocity | 12 closes in 24h | strongest single-cycle (vs 23 in 36h last review = 0.64/h vs 0.50/h) |
| Open sprint-task queue | 50 | healthy (well below 60 triage threshold) |
| Open SENIOR queue | 12 | mostly design-impl + 4 held design docs |

## What Shipped Since Last Review (cycle 9851 → 10262, ~24 hours)

User-visible:
- **Apple FM extraction — 4 of 5 Quick Wins (#744, #745, #748, #749).** Composite food entries ("paneer butter masala with rice and naan" → 3 separate FoodEntry rows), workout entries (unified extraction across food + workout intents), nutrition label OCR migrated from regex to @Generable, and lab report hybrid (regex primary + FM gap-filler for non-matching panel formats). This is the largest single-cycle pipeline architectural shift since the DriftCore extraction. Only QW1 (Unified FoodLogIntent extraction, #743) remains open in the design-666 set.
- **GLP-1 medication impl — 2 of 3 design-impl tasks (#751, #752).** Medication + MedicationLog data model with GRDB migration, log_medication AI tool wired into chat. Settings tab + weight chart vertical marker (#753) remains the last gap.
- **Dashboard 7-day Feedback activation banner (#759).** One-time post-install banner pointing users to Settings → Feedback after 7 days. This is the third-cycle activation lever after both DM-friends and dashboard-prompt were recommended in 9760 + 9792 + 9851; banner finally shipped.

Infra (operator-visible):
- **Heartbeat noise root-cause + fix (#758).** The cycle 9760/9792/9851 recurring complaint — ~30+ heartbeat commits per ship commit polluting main — is closed. Heartbeats now route to a side branch (`272d8293`). Three reviews of "still flagged" become zero.
- **#568 procedural loop closed (#757).** The fix actually shipped 2026-05-03 via `9a5b06ea` (#571 cup-to-gram gold-set update); cycle 9851's "7 reviews open" flag was reading a stale GitHub state. Manual verification reran the test (6/6 pass) and confirmed `FoodLoggingGoldSetTests` 19/19 green. Discipline crisis was a state-tracking crisis.
- **harness: design-doc PRs auto-merge after CI green** (carryover from 9851 — landing the deferred FM/GLP-1 docs onto main this cycle is what unlocked the impl tasks).

Items still open (carryover):
- **#708 iCloud backup E2E dogfood — STILL open (cycle 9760 issue).** Surface shipped 6 days ago; no friend-tester has run wipe-and-restore. The engine-without-surface anti-pattern that cycle 9760 named has been replaced with surface-without-dogfood. Cycle 9851 said "must close this sprint" — it didn't.
- **TestFlight build 243 archive failed yesterday.** Error: "BUILD INTERRUPTED during DriftCore compile" (different from the recurring iOS 26.4 SDK issue from April). This means none of the FM milestones, GLP-1 data model, or activation banner are on TestFlight yet. **Risk of repeating the 17-build dark stretch if not diagnosed this sprint.**

## Competitive Analysis
- **Apple Foundation Models (platform):** Drift's FM extraction push (4 surfaces migrated this sprint) is well-timed — Apple's on-device LLM access via FoundationModels framework is the differentiating platform move competitors haven't matched. MFP/MacroFactor still cloud-backed. ([Source — Apple Machine Learning Research, FM updates](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates))
- **MyFitnessPal:** No major release surfaced for May 2026 (last data: April GLP-1 launch + Today redesign window). Drift's GLP-1 impl push this cycle (#751/#752) is positioned to close the parity gap before MFP iterates. ([Source — Hoot Fitness comparison, 2026](https://www.hootfitness.com/blog/macrofactor-vs.-myfitnesspal-vs.-hoot-the-definitive-2026-review))
- **MacroFactor:** Apple Health write integration announced as their next major release for the Workouts app (Jan 2026 launch). They write to Apple Health; Drift already reads from Apple Health *and* writes for weight/workouts. Parity here, not lagging. ([Source — MacroFactor Workouts Jan 2026](https://macrofactor.com/mm-jan-2026/))
- **Whoop:** WHOOP 5.0 (Healthspan, ECG, BP) unchanged from last review. Our cross-domain analytical engines (12 now) remain the differentiation lane.
- **Boostcamp:** Unchanged. Muscle-group icons (#697) still queued.
- **Strong:** Unchanged.

## Product Designer Assessment

*Speaking as the Product Designer persona (read Docs/personas/product-designer.md first):*

### What's Working
- **Apple FM extraction is a *huge* product surface upgrade.** Composite food entries ("paneer butter masala with rice and naan" → 3 rows) was the single largest UX gap in chat-first logging — users had to manually split multi-component meals. We just shipped the platform-native fix in 24h. Nutrition label OCR + lab report hybrid extraction widen the photo-log surface to cover the long tail (formats regex couldn't handle). This is the kind of platform-leverage move that justifies the on-device, privacy-first identity — Apple did the model work, Drift integrates the framework.
- **GLP-1 impl is moving fast.** Data model + AI tool shipped same-cycle as the design doc landed on main. From design-doc-merged to first-impl-tasks-closed = same sprint. The mechanical pipeline from 9851 (designs land → planning files impl tasks → senior claims) is producing real velocity.
- **The 7-day Feedback banner is *finally* live (#759).** Three reviews of "DM friends or build the prompt" — we built the prompt. It's not the perfect lever (passive banner < active DM), but it's a concrete change vs the previous null state. Field signal in 7-14 days will tell us if the banner trips users into clicking through to Settings → Feedback.

### What Concerns Me
- **Build 243 didn't archive — testers see *nothing* from this sprint.** The FM milestones, GLP-1 data model, activation banner — all sitting on main, none on TestFlight. Most recent build testers have is 242 (May 11, protein_consistency_vs_recovery). If the DriftCore compile interruption isn't a one-off, we're walking into a second 17-build dark stretch. **This is a P0 for tomorrow.** The "TestFlight reach is part of the product" tenet from cycle 9441 wasn't a one-time pep talk; it's a standing measure of what users see.
- **#708 backup E2E dogfood is still open and now nobody is talking about it.** Cycle 9760 flagged it. Cycle 9792 flagged it. Cycle 9851 said "must close this sprint." This sprint didn't even mention it. Surfaces have shipped (Settings → Backup + restore picker), but nobody has wiped a real device and restored. We're carrying a feature that *looks* shipped but is un-validated. This isn't a discipline issue with the queue — it's a question that needs the human or a friend tester to *do the thing*, and we keep filing it as a sprint-task instead of escalating it as "human action required."
- **No cuisine ship this sprint.** Tenet #5 ("Indian food is the bar") demands an active commit each cycle. Food DB has been at 5,420 since the curation pass landed; ceiling is 6,000. We have headroom. #691 (South Indian regional), #761 (East Asian home cooking), #727 (Mediterranean / Levantine) all queued. None claimed. The reason: senior queue was all design-impl this cycle. *But cuisine ships are JUNIOR work* — junior queue had bandwidth and didn't pick them. This is a junior-routing issue.
- **The dashboard banner just shipped — it will not produce signal until tomorrow at earliest.** The activation question doesn't close with the banner shipping. It closes when *traffic appears*. Right now: still zero feedback entries.

### My Recommendation
This sprint, the product moves are:
1. **Unblock TestFlight build 243 (P0).** Diagnose the DriftCore compile interruption — `xcodebuild archive` log analysis, retry, narrow to specific change. Don't let yesterday's stalled archive become this week's dark stretch. **Standing rule revisit:** "no consecutive failed-archive days" should escalate to P0 senior task automatically (it didn't this cycle).
2. **Escalate #708 backup E2E dogfood as human action.** Move from sprint-task to a single line in the daily exec report: "Backup E2E dogfood: human runs wipe-and-restore today." Stop filing it as a sprint task; the friction is human availability, not engineering time.
3. **Ship one cuisine (#761 East Asian or #691 South Indian).** Pick one, claim it on junior queue, ship 30 hand-vetted foods. Tenet #5 has shipped zero cuisine in this cycle's 24 hours.
4. **Finish the FM Quick Wins (#743 QW1).** One open out of five. The unified FoodLogIntent extraction closes the chat-side of the FM pipeline. With it shipped, design-666 moves from "implementing" to "validate-and-close."
5. **Friend-tester ping check.** Banner is live — has anyone seen it? If TestFlight unblocks today, build 243 ships with the banner. Then we wait 7 days. But: human DM in parallel ("did you see the banner?") doubles the signal velocity.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (read Docs/personas/principal-engineer.md first):*

### Technical Health
- **FM extractor architecture landed cleanly.** Four pipeline surfaces (#744/#745/#748/#749) migrated to Apple Foundation Models with @Generable schemas. 47 new tests in `FoodLogIntentExtractorTests` covering bridge correctness, multi-food propagation, gold-set regex baseline parity, async flag-off equivalence. The flag-off path proves we can ship the FM extractor *behind* a feature flag and verify regression-free against the regex baseline — this is the right de-risk pattern for a platform-API integration. Build of DriftCore is green; FM tests all pass.
- **GLP-1 impl took the "mirror pattern" template cleanly.** Medication + MedicationLog mirror Supplement + SupplementLog; log_medication AI tool mirrors mark_supplement. Pattern reuse compresses senior task time. Same as the 12-engine analytical-tool template — once a pattern is mechanized, the Nth instance is cheap.
- **Heartbeat root-cause was a real diagnostic, not a re-verify.** #758 found that batching landed but heartbeat *snapshots* were still going to main on a separate path. The fix (route to side branch) eliminates the noise source rather than throttling it. This is the right shape — three reviews of "still flagged" closed by one diagnostic that didn't accept the prior fix at face value.
- **The #568 closure mechanism is interesting.** A test that was actually-closed for 10 days was running through "still open" review entries until #757 reran it manually and confirmed. **Lesson: never carry forward a "still open" claim about a test failure without rerunning the test in the planning cycle.** The review's `Tests` scorecard line should include a "known-failing-but-tracked" count that requires verification.

### Technical Debt
- **TestFlight archive interruption (build 243) — uninvestigated as of this review.** "BUILD INTERRUPTED during DriftCore compile" is concerning because DriftCore tests pass locally (47 new tests green this cycle). Either: (a) intermittent xcodebuild concurrency issue, (b) something in the FM-extractor file additions trips an iOS-target-only build path, or (c) the archive runner is wedged. **No diagnostic task filed yet.** Filing this cycle as the highest-priority P0.
- **#708 backup E2E dogfood — third cycle running.** The engineering rigor (atomic restore, ring buffer, integrity validation, allowlist+NSNull hardening) is in place. The validation gap is *non-engineering* — a human or friend-tester needs to physically wipe a device. We've been filing it as a sprint-task because that's our queue mechanism; the right escalation is daily-exec-report ask or a `human-action` label, not another sprint-task. This is a process-mismatch where the work item type doesn't fit the work.
- **47 new tests in `FoodLogIntentExtractorTests` — but the FM extractor is behind a flag (`asyncParse_flagOffMatchesSync_*` tests).** When does the flag flip? If the flag-on path doesn't have eval coverage yet (Tier 3 LLM eval against actual Foundation Models calls), shipping with flag-off is a fine de-risk *for now* — but the cutover plan needs to exist. **File: "FM extractor flag-on eval gate" as a follow-up sprint-task.**
- **Senior queue still concentrated in design-impl (5 of 12 open SENIOR are design-impl-* tasks).** Cycle 9851 said "file 2-3 non-design-impl SENIOR tasks." This cycle: filed `cross_domain_pattern_detector` (#739) and `protein_consistency_vs_recovery` (#730) before review — both closed already. Need to file more non-design-impl SENIOR work this cycle to keep the queue diverse.
- **Heartbeat noise side-branch routing is *operationally* correct, but does it self-document?** A new contributor (or future-me) seeing the side branch should understand at first read that this is operational state, not history. Worth adding a `command-center/README.md` note pointing to the side branch and why.

### My Recommendation
This sprint, the engineering moves are:
1. **P0: Diagnose TestFlight build 243 archive failure today.** Read the xcodebuild log, identify the interruption point, retry. If it's intermittent, add archive retry with backoff. If it's a real compile error, fix and re-bump.
2. **File FM extractor flag-on eval gate.** Tier 3 `DriftLLMEvalMacOS` test that runs the actual Foundation Models call against the same fixture rows the flag-off tests cover. Cutover criterion: ≥95% parity with regex baseline on the 47-case fixture, ≥98% on critical food-name cases.
3. **Escalate #708 to daily-exec-report as `human-action` not sprint-task.** Stop filing it; start asking for it.
4. **File 2-3 non-design-impl SENIOR tasks this cycle.** Chat-pipeline depth or analytical-tool refinement. Same ask as 9851; needs reinforcement.
5. **Add "known-failing-test verification" to product review template.** Anything carried forward as "test X is open" must be re-run in the planning cycle. Stale GitHub state should not be load-bearing for review entries.

## The Debate

**Designer:** Two things are tied this cycle. The first is the FM extraction shipping — 4 of 5 Quick Wins in 24 hours is a genuinely large product upgrade that uses platform leverage we couldn't replicate ourselves. The second is the TestFlight blockage — testers see *none of it*. The product team's biggest win is invisible to the people we're building for. Until 243 ships, this is a 50% review.

**Engineer:** Agreed. I'd add three things. (a) The #568 procedural loop closure was actually a state-tracking failure — we carried "still open" for 7 reviews because nobody re-ran the test. Bug in our review template, not our code. (b) FM extractor is behind a feature flag, which is correct now, but the cutover plan doesn't exist yet — file the Tier 3 eval gate before we forget. (c) Backup E2E dogfood is *not* an engineering problem; it's a human-action problem we keep filing as engineering.

**Designer:** Agreed on all three. The FM cutover plan especially — if we ship the flag-on path without eval coverage, the next review will be us explaining why a regression slipped. On #708: I'll stop asking for it in reviews. Move it to the human-action list in daily exec reports. If the human or a friend wipes a device this week, we mark it done.

**Engineer:** One pending discipline ask: cycle 9851 said "post-prompt-refresh cross-stage eval gate" — #766 was filed but not closed. Verify it's actually getting applied to the next prompt refresh, not just sitting in the queue as a template.

**Designer:** Fair. The danger sign is review recommendations becoming a checklist instead of a steering wheel — if we file a task and it sits, the recommendation didn't move the product. Both #708 and #766 are now in that bucket; #759 (banner) just broke out of it.

**Agreed Direction:** **Unblock-and-validate sprint.** TestFlight 243 diagnostic (P0). FM extractor cutover plan (flag-on eval gate). Finish FM Quick Wins (#743). Begin GLP-1 last impl (#753). One cuisine ship (#691 or #761). Escalate #708 to human-action in daily exec. Verify #766 cross-stage eval gate is applied to the next prompt-audit task. All new tasks declare `qa-scope`.

## Decisions for Human

1. **TestFlight build 243 archive failure — investigation priority.**
   - **(a) (Recommended) File P0 senior task today; diagnose xcodebuild log; one-shot fix or retry.**
   - **(b) Wait one more attempt cycle; the watchdog will retry every 3h.**
   - **(c) Accept the dark window; build 244 next cycle.**
   - Recommendation: (a). Each failed-archive day compounds; the 17-build dark stretch (cycle 8799 cliff) started with one ignored interruption.

2. **#708 iCloud backup E2E dogfood — three cycles of "still open."**
   - **(a) (Recommended) Human runs wipe-and-restore this week on a real device; report in daily exec.**
   - **(b) Synthetic dogfood — UITest that simulates wipe + restore (lower-fidelity).**
   - **(c) Friend tester runs it (riskier — real data loss if restore fails).**
   - Recommendation: (a). Stop filing as sprint-task; ask once in daily exec; close once run.

3. **FM extractor flag-off → flag-on cutover.**
   - **(a) (Recommended) Build Tier 3 eval gate first (`DriftLLMEvalMacOS` against actual FM calls), flip flag when ≥95% parity with regex baseline.**
   - **(b) Flip the flag now; eval coverage as follow-up.**
   - **(c) Keep flag-off indefinitely; FM extractor as a "second opinion" layer.**
   - Recommendation: (a). Eval-before-cutover is the standing principle from cycle 8666's "telemetry-dependent task" lesson.

4. **Settings → Feedback activation — banner just shipped (#759).**
   - **(a) Wait 7-14 days for banner signal; no further action.**
   - **(b) (Recommended) Human DMs 3-5 friend testers in parallel asking "did the banner appear?"**
   - **(c) Build a second activation lever (in-chat prompt, push notification CTA).**
   - Recommendation: (b). Banner is passive; one human ping doubles the signal velocity without burning another sprint.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
