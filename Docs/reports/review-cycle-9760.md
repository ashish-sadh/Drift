# Product Review — Cycle 9760 (2026-05-09)

## Executive Summary
Two sprints worth of work landed since cycle 9441 (~30 wall-clock hours): iCloud backup feature reached near-shipping (Sections B/C/D + ring buffer pruning + Codable+array support), three analytical/coaching capabilities shipped (cycle×biomarker correlation, multi-intent splitting, smart meal reminders from median timing), and two harness rules went live that change how every future commit ships (qa-tester adversarial pass, require-test-on-source-change). TestFlight build 235 is public; the publish path is healthy. Next bottleneck moves from delivery and analytical breadth to **shipping iCloud backup** (the in-progress senior thread) plus first real friend-feedback signal — Settings → Feedback has been live for ~30h with zero traffic, which is data of its own.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 235 (TestFlight) / 234 baseline | +9 builds since 226 |
| Tests | ~1253 iOS DriftTests + ~1253 macOS DriftCore (8s warm) + 160+ LLM eval | +34 iOS / +539 macOS since 9441 (DriftCore expansion) |
| Food DB | 11,072 | flat (no enrichment this cycle) |
| AI Tools | 35 (23 core + 12 insight) — 11 analytical engines | +1 (cycle_biomarker_correlation #689) |
| Coverage | ExerciseService 67%, TDEEEstimator 55%, BackupService new+covered | flat on services; new code shipped with tests |
| P0 Bugs Fixed | 4 (#684 Send Feedback, #685 launch trace, #686 splash animation, #699 ring tooltip) | +4 |
| Sprint Velocity | 9 closes in ~30h vs 10 last cycle | high |
| Open sprint-task queue | 33 | healthy (well below 60 triage threshold) |

## What Shipped Since Last Review (cycle 9441 → 9760, ~30 hours)

User-visible:
- **iCloud backup engine — Sections B/C/D + ring buffer (#674, #675, #676).** `.driftbackup` zip (snapshot + manifest), atomic restore + integrity validation, 7 daily + 4 weekly pruning. `BackupRingBuffer` + `BackupInfo` types. App now has the durable-restore foundation for device migration.
- **Codable Data + array preferences in backup (#701).** weightGoal, tdeeConfig, custom_exercises, and other Codable/[String]/[String:String] preferences now round-trip cleanly through backup encoder/decoder.
- **Backup allowlist hardening (#700).** Silent-data-loss fix: PreferencesBackup.allowlist now mirrors actual `Preferences.swift` keys instead of a divergent hand-curated list. Two follow-on bugs from this fix: NSNull/non-primitive filtering on restore (#687).
- **`cycle_biomarker_correlation` analytical tool (#689).** First cross-domain insight tying menstrual phase to biomarkers (iron, vitamin D, ferritin). Unique vs Whoop — their cycle and biomarker panels are separate.
- **Multi-intent chat splitting (#688).** "Log lunch and update weight" now executes both tools sequentially in one turn. Tier-2 deterministic eval shipped alongside.
- **Smart meal reminder notifications (#690).** Notification body uses the user's median meal time, not the trigger time — "Did you log lunch around 12:30?" instead of "Did you log lunch around 13:47?".
- **Macro ring tooltip readable + dismissable on overflow (#699).** P0 UI bug — overflow text was unreadable and trapped the user.
- **Splash animation + progressive launch status (#686).** P0 perceived-latency improvement — testers see motion + status text instead of a frozen splash.
- **Launch trace instrumentation (#685).** P0 — wall-clock measurement of every cold-launch step. We were guessing at launch time before; now it's measured.
- **Settings → Send Feedback row removed (#684).** P0 — email is a useless feedback channel; row was misleading testers about how to report bugs.

Infra (operator-visible):
- **`qa-tester` subagent + verdict hook (`d427f870`).** Adversarial pass before any commit touching `Drift/Views|ViewModels|Services` or `DriftCore/Sources/{Domain,AI,Persistence}`. `require-qa-verdict.sh` PreToolUse hook blocks the commit if the issue lacks a checked verdict block. Driven by the calorie overlay #669 incident — three bugs that QA scenarios would have caught.
- **`require-test-on-source-change.sh` hook (`ba46cfa9`).** Companion rule: source commits must stage a test, or include `[no-test]` in the message. Same #669 root cause.
- **One-time persona sediment + prune pass (#683, `8035faec`).** product-designer.md and principal-engineer.md cut from 412/402 → ≤200 lines each. Planning step 10 now mirrors decisions.md editing pattern.
- **TestFlight build 235** published cleanly. The publish path remains healthy — no new dark stretches.

## Competitive Analysis
- **MyFitnessPal:** Today tab redesign continues to draw user uproar through May 2026 — official position is "here to stay" but they're "open to refining." Free users now get macro breakdowns (previously paid). GLP-1 tracking expanded with location/dose/timing tracking. The redesign-backfire window remains open: every chat-first log that takes one sentence vs MFP's "4 taps" is the differentiator. ([Source](https://piunikaweb.com/2026/05/05/myfitnesspal-new-design-update-is-here-to-stay/))
- **MacroFactor:** April 2026 cookbook photo scanning is still the most recent flagship release — snap a written recipe → ingredient pre-fill. Workouts app continues to expand. No May release notes surfaced. Their lane (program design + recipe depth) is not Drift's; we win on day-to-day chat speed. ([Source](https://macrofactor.com/mm-april-2026/))
- **Whoop:** Behavior Insights + Advanced Labs Uploads remain the analytical-correlation challenge. Drift's `cycle_biomarker_correlation` (#689) is a first-mover here — Whoop's cycle tracking and biomarker panels are separate views, not correlated.
- **Boostcamp:** Unchanged. Visual exercise content gold standard; we remain text-only on 960 exercises.
- **Strong:** Unchanged. Minimalist logging.

## Product Designer Assessment

*Speaking as the Product Designer persona (sedimented persona, May 2026):*

### What's Working
- **The proactive coach + analytical breadth story is now genuinely differentiated.** With `cycle_biomarker_correlation` shipped, Drift now has 11 analytical engines spanning food×weight, food×glucose, food×sleep, supplements, GLP-1, workout volume, weight trend prediction, progressive overload, glucose spike analysis, food timing, and now cycle×biomarkers. No competitor tracks all of these in one place, let alone correlates across them. The chat-first surface makes this *legible* — "do I spike after rice?" is a sentence, not a workflow.
- **Multi-intent splitting (#688) collapses friction users didn't know they had.** "Log dinner and update weight" → both tools fire. Every meal-time conversation has natural compound intents; making them work without a follow-up turn is the kind of polish testers won't articulate but feel.
- **Smart meal reminders using median time (#690) is correct-by-design.** A reminder that fires at 12:30 because that's when *the user usually eats* is qualitatively different from a reminder at 13:47 because that's when the watchdog ran. Personalized cadence is invisible when right; this one is right.

### What Concerns Me
- **Settings → Feedback has been live ~30h with zero traffic.** PR #649, #673, #702, #703 all show `0 comments`. It is genuinely too early to call (testers may not have reopened the app since publish), but the structural risk from cycle 9441 is unchanged: feedback channel without traffic is undifferentiable from broken channel. The admin's note on #654 ("Build the in-app 'what's new' sheet — no need to do this") shuts down one activation lever. We need the *other* lever now — what's the equivalent of telling testers "we shipped 3 builds, here's why you should reopen"?
- **#568 (testPortionScaling_DecimalServings) is still on main across 5 reviews now.** It's been listed as "needs fix or gate" in 9441 and earlier. A perpetual-known-failure on main is a slow-motion erosion of the test suite as a quality signal — every session that sees it learns "the suite has noise, I can ignore one more." Either fix it or environment-gate it; pick one and close the chapter.
- **iCloud backup feature is the longest-running senior thread but isn't *visibly* shipping yet.** Sections B/C/D + ring buffer + Codable + allowlist + NSNull filter — six issues across two cycles. The implementation is rigorous (atomic restore, integrity validation, 7+4 retention), but until a tester does an end-to-end "back up → wipe device → restore" pass, we don't know it works in the field. The next sprint should land the user-facing surface (Settings → Backup, restore flow) and verify with real-device dogfooding.

### My Recommendation
This sprint, the product moves are:
1. **Land iCloud backup user-surface and dogfood it.** Settings → Backup row, "Back up now" button, "Restore from iCloud" on first-launch fresh install. Then a real wipe-and-restore on a test device. The engine work is done; the Designer's question is whether a friend can do device migration without reading docs.
2. **Replace the closed "what's new" lever with TestFlight release notes that read as a coaching narrative.** "Drift now correlates your menstrual cycle with iron and vitamin D" sounds like product, not a changelog. Lead the next 2-3 release notes with one sentence about the new coach behavior, not the issue list.
3. **Pick one cuisine and add 30 foods.** Food DB has been flat at 11,072 for two cycles. Indian-first tenet (#5) needs an active commit — South Indian regional was already in queue (#691); ship it. The food DB is not where the bottleneck is, but stagnation reads as drift.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (sedimented persona, May 2026):*

### Technical Health
- **Two new harness rules raise the floor materially.** `qa-tester` adversarial pass + `require-test-on-source-change` mean every UI/data-flow commit now ships with a traced QA verdict and a test, or gets blocked at the hook. The cost is ~5-10 minutes per source commit (subagent invocation + trace); the value is the end of multi-commit iteration on shipped bugs. The calorie overlay #669 incident — three bugs caught only post-merge — is the kind of failure these rules end.
- **Backup engine architecture is solid.** Ring buffer pruning (7 daily + 4 weekly), atomic restore + integrity validation, allowlist mirrored to production keys, NSNull filter, Codable+array round-trip. This is the kind of work that's invisible when right and catastrophic when wrong; the rigor is appropriate.
- **DriftCore test suite has expanded substantially.** ~1253 macOS pure-logic tests at 8s warm — same speed as before despite +539 tests. The Tier-0 split continues paying for itself.

### Technical Debt
- **The qa-tester rule is new and hasn't been stress-tested.** It will trigger on every UI/service commit going forward. Two risks: (a) sessions burn budget on subagent ceremony and ship less, (b) the verdict block becomes performative (sessions write "WORKS AS-IS" without actually tracing the path). The hook checks for the *block* but not for *correctness of the verdict*. We need to watch the next 5-10 commits for whether QA scenarios actually land bugs vs just satisfy the hook.
- **#568 (testPortionScaling_DecimalServings) — still open from cycle 9441.** Same finding as last review. Either fix it or environment-gate it. This is exactly what the Designer flagged: a known-failing test on main eats trust.
- **iCloud backup is missing the user-facing surface.** The engine ships, but no Settings row, no restore UI, no fresh-install detection. Engine without surface = ineligible for dogfooding = no field validation. The remaining work is Drift/Views, not DriftCore.
- **Heartbeat commits remain noisy in `git log`.** Despite #642's batching from cycle 8999, recent `git log --oneline -40` still shows 30+ heartbeats per real ship commit. The batching window is too short or there's a separate path. Either fix it or accept that operational state lives on main and stop calling it noise.
- **No automated E2E smoke for the *new* behaviors.** Multi-intent (#688) shipped with a Tier-2 deterministic regression test, which is correct. But cycle_biomarker_correlation (#689) and smart meal reminders (#690) shipped with unit tests — no end-to-end smoke that exercises chat → tool → presentation. The chat smoke test recommendation from cycle 9441 (ChatPathSmokeTests) was promised; verify it covers the new tools.

### My Recommendation
This sprint, the engineering moves are:
1. **Ship the iCloud backup user-facing surface and validate end-to-end.** Settings row, backup-now action, restore-on-first-launch detection, dogfood on a real device. Close the loop on the multi-cycle senior thread.
2. **Resolve #568 once and for all.** Either fix it (likely a fixture or rounding issue) or `XCTSkipIf(ProcessInfo.processInfo.environment["DRIFT_SKIP_KNOWN_FAILURE"] != nil)` and stop showing it. Pick within the cycle.
3. **Verify ChatPathSmokeTests covers the cycle_biomarker_correlation + multi-intent + smart-reminder paths.** If not, expand it. We promised to never ship a chat regression on a shipped feature again — five features in, the test surface needs to keep up.
4. **Audit qa-tester verdict effectiveness after 5-10 commits.** Read each verdict block; check whether the scenarios actually traced the code or just rubber-stamped. If rubber-stamping is the failure mode, tighten the hook to require commit hashes for "BUG FIXED" or file:line for "WORKS AS UPDATED".

## The Debate

**Designer:** The story is now "Drift coaches you across 11 dimensions and works offline." iCloud backup is the credibility play — without it, no tester will trust this app with their multi-year data. Ship the surface, dogfood it, and lead the next release notes with the coaching narrative. Hold feature work to one cuisine + one analytical tool. Activation signal must drive what we add next.

**Engineer:** Agree on iCloud surface. But I want to also pin a quality floor before we activate testers harder. The qa-tester rule is new — we don't know yet if it's working. Audit 5-10 commits before the cycle ends. Resolve #568. Verify chat smoke test covers the new tools. If we activate testers and they hit a regression on the new analytical tools, the trust hit is bigger than not activating.

**Designer:** Fair. Sequence: iCloud surface ships first (it's the headline), then quality floor work (smoke test expansion, #568 resolution, qa-tester audit). Both are sprint-sized. The cuisine and analytical tool can ride if budget allows; otherwise they wait.

**Engineer:** Agreed. One additional ask: every new sprint task this cycle must declare its qa-tester scope upfront in the body — "qa-scope: chat path" / "qa-scope: backup flow" / "qa-scope: none (no UI/data-flow change)". Forces the question to be answered at task creation, not at commit time.

**Agreed Direction:** **Backup-ship + quality-floor-validate sprint.** Surface iCloud backup, dogfood end-to-end, expand chat smoke tests for new analytical tools, resolve #568, audit qa-tester effectiveness over 5-10 commits. Hold feature additions to one cuisine ship (#691 South Indian) and one analytical/UX touch (TBD). All new tasks declare qa-scope in body.

## Decisions for Human

1. **iCloud backup user-facing surface — UI design ask.** The engine works (Sections B/C/D + ring buffer). The remaining surface is Settings → Backup with three actions: (a) Back up now, (b) Restore from iCloud (on fresh install detection), (c) Show backup history. Options:
   - **(a) Add a single Settings row "iCloud Backup" → opens detail screen.** Lower discovery, cleaner Settings list.
   - **(b) Add to first-launch onboarding flow.** Higher discovery, more friction.
   - Recommendation: (a) for shipped flow, plus a one-line tip on dashboard for first 7 days.

2. **#568 (testPortionScaling_DecimalServings) — fix or gate? It's now appeared in 5 reviews.** Options:
   - **(a) Fix the underlying decimal-serving rounding.**
   - **(b) `XCTSkipIf` behind `DRIFT_SKIP_KNOWN_FAILURE` and document it as a known edge case.**
   - Either is fine; pick one and close the chapter.

3. **First TestFlight feedback channel.** With "what's new" sheet declined and Settings → Feedback at zero traffic for ~30h, we need a different signal. Options:
   - **(a) Direct ask to friend testers via DM.** Zero infra cost; relies on the human running the project.
   - **(b) Add a one-time "How's it going?" prompt to dashboard 7 days after install.** Higher signal cost, lower noise.
   - **(c) Wait — first feedback may still arrive organically.**
   - Recommendation: (a) immediately, (c) as the patient default.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
