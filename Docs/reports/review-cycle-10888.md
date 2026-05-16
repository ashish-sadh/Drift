# Product Review — Cycle 10888 (2026-05-16)

## Executive Summary
The **unblock-and-validate sprint delivered both halves**: TestFlight pipeline shipped 6 builds (244 → 250) closing the 243 archive failure that defined the last review, and 3 of 4 cycle-10262 P0 senior tasks landed (#770 archive diagnosis, #771 FM Tier-3 eval gate, #772 medication crash hunt). Layered on top: an entirely new V6 visual evolution shipped in 3 elements (#782) — Apple-Fitness-style V6Rings hero, quick-log chip row, Body tile row — plus a `.foundationModels` chat backend (PR A of Task 1) opening Apple FM as a first-class chat-time inference path. **Two unfinished asks carry forward to this cycle**: #708 backup E2E dogfood still open (4th consecutive cycle); Settings → Feedback null traffic — the 7-day banner shipped 2026-05-12 with build 242, has been in user hands for 4 days, and we have not yet asked "did anyone see it?"

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 250 published (build 251 archive in flight as of this report) | TestFlight UNBLOCKED — 6 builds shipped this cycle (242→250) |
| Tests | ~1253 iOS DriftTests + ~1300 macOS DriftCoreTests + 160+ LLM eval | +47 (#771 FM eval gate fixture rows) |
| Food DB | 5,420 | flat — 4th consecutive cycle with zero cuisine ship |
| AI Tools | 35 (23 core + 12 insight) — 12 analytical engines | flat (no new tools; expected — focus was UI + infra) |
| Coverage | flat | new code shipped with tests (#771, #772, V6 element tests) |
| P0 Bugs Fixed | 0 (no new P0s; 4 cycle-10262 P0s addressed) | health remains good |
| Sprint Velocity | ~22 closes since 2026-05-13 (~72h) | 0.30/h (vs 0.50/h prev) — slower because work was heavier (V6 visual + FM backend = ~6h each) |
| Open sprint-task queue | 39 | dropped from 50 — TRIAGE happened during cycle 10705 planning |
| Open SENIOR queue | 8 | drained from 12 — strong design-impl progress |
| TestFlight builds shipped | 6 (244, 245, 246, 247, 248, 250) | reach restored after 1-day gap |
| Cycles since last review | 626 (vs 411 prev) — review-cycle-interval honored | on cadence |

## What Shipped Since Last Review (cycle 10262 → 10888, ~72 hours)

User-visible:
- **TestFlight pipeline unblocked + 6 builds shipped (#770).** Build 243 archive failure (DriftCore compile interrupted) diagnosed and resolved; builds 244, 245, 246, 247, 248, and 250 all published. The cycle-10262 designer concern ("testers see nothing from this sprint") closed within 24h. The fix path included `0e0b9dfd` honest TestFlight lookup in command-center so we can see what's actually published vs what GitHub thinks.
- **V6 visual evolution — 3 elements shipped (#782).** Element 1: Apple-Fitness-style V6Rings hero (`7090a421`). Element 2: quick-log chip row (`982e7c68`). Element 3: Body tile row (`f01223b2`). This is the most concentrated UI redesign push since the cycle 869 Phase 3c theme overhaul — and unlike that one, it's incremental: each element ships standalone, each is reversible, and the V6 mockup in `docs(design-ref)` (`ae08a21d`) gives the trajectory.
- **FoundationModelsBackend chat backend wired (`4f0f1d4f`, PR A of Task 1).** New `.foundationModels` backend type means chat-time inference can route through Apple Foundation Models alongside the existing llama.cpp + remote backends. Backend selectable; not yet default. Logical successor to the cycle-10262 extractor migrations.
- **Backup first-launch enable nudge (`8421ee10`).** First-launch users now see an inline prompt to enable iCloud backup; pairs with Migrations version fix. Surface present, but #708 dogfood still open — we still don't know if restore works on a real device.
- **CycleBiomarker insight tool (#778).** Symmetric rise/drop detection + honest stats (sample-size-gated). Adds the 12th analytical engine. Closes the cycle-10262 ask for "non-design-impl SENIOR diversification."
- **Weight 2-point extrapolation killed (`5a3f6eec`).** Goal-rate display no longer invents weekly rates from 2 datapoints. Was producing fictional projections like "you'll hit goal in 3 weeks" off two morning readings. Cleaner is honest "need more data."

Infra (operator-visible):
- **FM extractor Tier-3 eval gate (#771).** `DriftLLMEvalMacOS` test runs actual FM calls against composite-food fixtures, measures parity vs regex baseline. This is the cutover gate cycle 10262's debate landed on. Flag-on cutover blocked until parity is ≥95%; the gate exists, the measurement infra works, the actual cutover is a downstream decision.
- **Crash hunt #772 — non-finite medication doses sanitized (`464ba73e`).** Filed under tenet #8 (proactive crash hunt on recent FM + GLP-1 code); found a real one — non-finite dose values from GLP-1 chat logs would crash medication serialization. Fix is defensive sanitization at the data-model layer.
- **`design-service.sh self-heal orphan design branches** (`586ec3c2`). cmd_pending now auto-heals orphan branches without manual intervention. Removes one class of "stalled design doc waiting on a stale ref" friction.
- **command-center "Resolved (1h)" metric + honest TestFlight lookup (`0e0b9dfd`).** Dashboard now shows a real-time "bugs resolved in last 1h" pulse + the actual published TestFlight build (not just what `git tag` says). Operator-facing transparency.
- **Daily exec briefings shipped on schedule** — 2026-05-14 (#783), 2026-05-15 (#785). No misses.

Items still open (carryover):
- **#708 iCloud backup E2E dogfood — STILL open (4th consecutive cycle: 9760, 9792, 9851, 10262).** Cycle 10262 said "escalate to human-action in daily exec." Done. No friend tester has run wipe-and-restore. The friction is real human availability, not engineering. **Engineer's recommendation from last review (move from sprint-task to daily-exec ask) was followed**; the ask is still open. Now flagged `human-action` per cycle 10262 decision.
- **Settings → Feedback null traffic — 4 days after banner ship.** Banner shipped 2026-05-12 in build 242. Builds 244-250 all carry it. No DM has gone out to friend testers asking "did the banner appear?" Cycle 10262 decision (b) was "human DMs 3-5 friend testers." Not done. The passive lever is shipping; the active lever is not.
- **Cuisine ship gap — 4th consecutive cycle with foods.json flat at 5,420.** Tenet #5 ("Indian food is the bar") has shipped zero cuisine since the curation pass landed. #691, #761, #727 all queued. Junior queue had bandwidth; routing failed.

## Competitive Analysis
*Web search snapshot 2026-05-16. Sources cited inline.*

- **Apple Foundation Models (platform):** Drift now has TWO production surfaces on FM — the cycle-10262 extractor migrations (CompositeFood/Workout/NutritionLabel/LabReport) AND this cycle's chat-time `.foundationModels` backend. Apple's WWDC25 framework continues to be the on-device LLM moat competitors haven't matched. ([Apple Foundation Models updates](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates))
- **MyFitnessPal:** No major announcement surfaced May 13-16. Their April GLP-1 + Today redesign push is still settling; user complaints about the 4-tap diary remain in app store review channels. Drift's chat-first logging continues to differentiate against their backwards step. ([Hoot Fitness comparison 2026](https://www.hootfitness.com/blog/macrofactor-vs.-myfitnesspal-vs.-hoot-the-definitive-2026-review))
- **MacroFactor:** Workouts app (launched Jan 2026) still iterating; recipe photo scanning remains their headline feature for nutrition entry. Drift's GLP-1 impl (#751/#752) closed the medication parity gap last cycle. Recipe scanning remains a gap we deliberately don't chase (cloud-backed; conflicts with privacy tenet).
- **Whoop:** WHOOP 5.0 platform unchanged. Cross-domain analytical engines (12 now with #778 CycleBiomarker) remain the differentiation lane — they correlate hardware sensor data; we correlate user-logged habits to recovery + biomarkers.
- **Boostcamp:** Unchanged — exercise videos and muscle diagrams remain best-in-class. #697 muscle-group icons still queued; the V6 Body tile row this cycle hints at where their visual depth could route into our exercise tab without copying videos.
- **Strong:** Unchanged. The set/rep entry minimalism remains the bar; we match speed via chat (no taps).

## Product Designer Assessment

*Speaking as the Product Designer persona (read Docs/personas/product-designer.md first):*

### What's Working
- **TestFlight reach was restored within 24h of the cycle-10262 alarm — and then EXTENDED.** Last review's most dire concern was "testers see nothing from this sprint." This cycle: 6 builds shipped. The standing rule ("any failed archive within last 24h = auto-P0") held; #770 closed inside one day. The FM extractor, GLP-1 data model, V6 visual evolution, FoundationModelsBackend — all reachable from a tester's hand right now. That's the cycle-9441 dark-stretch tenet enforced.
- **V6 visual evolution shipped in three reversible elements, not one monolithic rewrite.** This is the right shape for a UI overhaul — Element 1 (V6Rings hero) lands and gets feedback, Element 2 ships on top, Element 3 layers in. Each is its own commit; if testers hate the hero we can revert without losing Body tile row work. Compare to cycle 869's Phase 3c theme overhaul which shipped all-at-once and produced two cycles of refinement work — this approach is materially better.
- **CycleBiomarker insight (#778) closed the "non-design-impl SENIOR diversification" ask AND added a 12th analytical engine.** "Symmetric rise/drop + honest stats" is the right shape for a correlation tool — it doesn't claim insight on tiny samples. The bar for analytical tools is honesty about confidence; #778 sets it correctly.

### What Concerns Me
- **#708 backup E2E dogfood is now FOUR cycles open with the same root cause.** Cycle 9760: filed. Cycle 9792: still open. Cycle 9851: still open. Cycle 10262: "escalate to human-action in daily exec" — the engineer's specific recommendation was followed. Cycle 10888: *still open*. The escalation worked at the *labeling* level (#708 now has `human-action`) but not at the *outcome* level (no human has wiped a device). The lever cycle 10262 picked was correct; the lever didn't produce the action. **Recommendation: this cycle, the daily exec briefing must explicitly request a wipe-and-restore from a named human tester (not "anyone") with a 48h deadline. If no response, the feature ships as "engine verified, restore unvalidated" — name the gap, don't pretend it's complete.**
- **Settings → Feedback banner shipped 4 days ago. We have not asked anyone if they saw it.** Cycle 10262 decision (b) — "human DMs 3-5 friend testers" — was filed nowhere. The banner is the *passive half* of the activation lever; the active half (the DM ask) was never paired with it despite my own persona note "passive levers are half-levers — pair with active asks." I'm in violation of my own learning from cycle 10262. The activation question doesn't close with traffic measurement — it closes when we know the banner is *visible*. A single DM today gets us field signal by Sunday.
- **Cuisine has been flat at 5,420 for four cycles.** Tenet #5 has shipped *zero* in the last 96 hours. Junior queue had bandwidth this cycle (V6 element work was senior-claimed, infra was senior-claimed); the cuisine tasks (#691, #761, #727) sat un-claimed. The routing bug isn't "queue empty" — it's "junior sessions are exiting without claiming." **Need to audit the junior session loop**: are they receiving "none" from `next --junior`? Or are they claiming and abandoning? Either way, four cycles of flat food DB is the longest stretch since the curation pass.
- **V6 visual evolution shipped 3 elements without a tester DM saying "here's a redesign, what do you think?"** Same passive-vs-active problem. Visual change is the highest-signal feedback surface we have. The right shape: ship Element 1, DM 3 friends, get reactions, *then* ship Element 2. Instead we shipped 1-2-3 in 60h with zero qualitative input. If the V6 direction is wrong, we're 3 elements deep in the wrong direction.

### My Recommendation
This sprint, the product moves are:
1. **Daily exec briefing makes one specific human-action ask** — "Run wipe-and-restore on iPhone today, report back" — named tester, 48h deadline. Stop filing #708 as anything; close it on confirmation OR ship it as "engine validated, restore not field-tested."
2. **Send the friend-tester DM (cycle 10262 decision b).** "We shipped the V6 visual evolution AND a Feedback banner in Settings. Two questions: (1) did the banner show up? (2) what do you think of the new look?" One DM, two signals.
3. **One cuisine ship — claim #691 (South Indian) OR #761 (East Asian) today.** Junior queue routing bug must be diagnosed in parallel; even if routing is broken, manually claim one.
4. **Audit V6 visual evolution against the V6 design-ref doc (`ae08a21d`).** Three elements shipped; are they the right three? Does the V6 doc imply Element 4 should be next, or do we pause for tester input before continuing?
5. **Cross-stage prompt audit verification.** Cycle 9851's #766 template was filed; cycle 10262 said "verify it's actually getting applied to the next prompt refresh." No prompt refresh shipped this cycle, so the template isn't yet tested. File a verification for the *next* prompt audit — don't let the template calcify.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (read Docs/personas/principal-engineer.md first):*

### Technical Health
- **The cycle-10262 P0 list closed cleanly: 3 of 4 SENIOR tasks shipped (#770 archive, #771 eval gate, #772 crash hunt); only #778 cycle-biomarker reframing landed as a feature.** This is the discipline shape I want to see — review files a P0 list, planning files it as sprint-tasks, senior claims and ships within a sprint. The "review recommendation → sprint task → close" loop worked end-to-end for the first time since cycle 9851 said it broke.
- **FoundationModelsBackend wiring (`4f0f1d4f`) is shaped correctly.** New `.foundationModels` backend type alongside existing llama.cpp + remote; backend selectable but not default. This is the right de-risk: ship the plumbing now, leave the default conservative, flip default after eval coverage. Same template as the cycle-10262 extractor migrations (flag-off path first, eval-gate cutover after).
- **FM extractor Tier-3 eval gate (#771) measures the right thing.** Composite-food fixture parity against regex baseline, structured output validation, honest false-positive/false-negative counts. The infrastructure is reusable for the next platform-API integration — pattern is now templated.
- **V6 visual evolution sequencing is engineering-sound.** Three commits, three reversible elements, each with its own tests. The pre-commit hook (`require-test-on-source-change`) caught the requirement and the tests are inline with the views. Compare to past UI overhauls (cycle 869) which shipped one massive commit then spent 2 cycles refactoring — incremental is materially safer.
- **Weight 2-point extrapolation fix (`5a3f6eec`) is the right kind of correction.** "Kill the fictional projection" beats "add a confidence interval to the projection" — honesty about insufficient data is better than statistical theater. The tenet-aligned move.

### Technical Debt
- **#708 backup E2E dogfood is a process-mismatch we still haven't resolved.** Cycle 10262 said "stop filing as sprint-task, escalate to human-action." The label changed; the workflow didn't. We have no machinery for "feature requires human-action validation" — it's still sitting in the sprint queue with a different label. **Real fix**: features that need human-action validation should be moved to a separate `human-action.md` register that the daily exec reads from, with a named owner and deadline. Adding a label to a sprint-task is just relabeling the problem.
- **No prompt refresh shipped this cycle.** Cycle 9851 filed #766 (cross-stage eval gate template); cycle 10262 said "verify it gets applied next prompt refresh." This cycle: no prompt refresh happened, so the template is untested. We need either (a) a sprint to schedule a prompt refresh + verify template, or (b) acknowledge that prompt refreshes are reactive (only happen when failing-queries.md surfaces a cluster) and the template stays in standby. Probably (b), but write it down.
- **`graphify watch` is failing on every run** (`Graph has 7883 nodes - too large for HTML viz`). This appears in every Bash output. It's not blocking anything but it's noise. Either fix the threshold, run with `--no-viz`, or remove the watcher. Quiet noise > loud noise.
- **The `.foundationModels` backend has no eval coverage yet.** PR A of Task 1 is the wiring; PR B should be the eval (mirroring the #771 pattern). File it before the backend gets a default-on flip.
- **Cuisine routing bug** (junior queue not claiming food-DB tasks) is now a real production drift, not a one-off. Four cycles flat. Probably worth a one-shot diagnostic: are juniors getting "none" or is it a `--junior --claim` mismatch with `food-db-curation` labels? Worth 30 minutes of `sprint-service.sh` debug logs.

### My Recommendation
This sprint, the engineering moves are:
1. **Diagnose junior cuisine-routing bug.** Add `set -x` to `sprint-service.sh next --junior --claim`, run it manually, see what tasks it considers and rejects. Fix the routing OR file the cuisine tasks with explicit `JUNIOR` label override OR document that food-DB ships need senior pickup until routing is fixed.
2. **File `.foundationModels` chat backend eval gate (Task 1 PR B).** Tier 3 `DriftLLMEvalMacOS` against actual FM chat completions vs llama.cpp baseline on the existing IntentRouting gold set. Same shape as #771 but for chat, not extraction. Cutover when parity ≥95%.
3. **Build `human-action.md` register + daily exec read.** Move #708 (and any future "human must do X to validate Y" items) out of the sprint queue. The exec briefing reads from the register and surfaces each item with named owner + deadline. Sprint queue should only contain things sessions can complete; everything else is process-mismatch.
4. **One non-design-impl SENIOR task this cycle.** #778 was last cycle's diversification proof; this cycle needs another. Candidates: `.foundationModels` eval gate (per #2 above), or a chat-pipeline depth feature (multi-intent splitting v2, conversational onboarding, etc.).
5. **Fix or quiet `graphify watch` noise.** Run with `--no-viz` in the hook, or up the node threshold. Small fix, big quality-of-life improvement for every session.

## The Debate

**Designer:** The headline this cycle is two things tied: TestFlight unblocked + 6 builds (the cycle-10262 alarm closed within a day), and V6 visual evolution in 3 elements (the most disciplined UI ship in 4 phases). But I'm in violation of my own learning — passive levers are half-levers, and I haven't paired the V6 ship OR the Feedback banner with a single human DM. The shipping discipline is excellent; the *activation* discipline is regressing.

**Engineer:** Agreed on shipping discipline. Adding: the cycle-10262 review-to-sprint-to-close loop worked end-to-end this cycle for the first time in months. Three of four P0 senior tasks shipped within a sprint. That's the discipline arrow pointing up. But #708 is now four cycles open with the same root cause and the *fix we agreed on last cycle* (relabel + daily exec) produced the relabel without producing the action. Means our escalation mechanism is missing a step.

**Designer:** The missing step is "named owner + deadline." Relabeling #708 from sprint-task to human-action gave us a category but no responsibility. If the daily exec says "human-action: backup dogfood" without a name and a deadline, it's a permanent fixture, not a call to action. Same applies to my friend-DM ask — "human DMs 3-5 testers" was a recommendation without an owner, and predictably no one owned it.

**Engineer:** Then let's bake the owner+deadline into the human-action mechanism. The exec briefing already has a "Decision Needed" section — extend it with a "Human Action" section that lists items, owners, and 48h deadlines. After deadline: feature ships flagged as "unvalidated," or the human action becomes a P0 sprint-task with the new label `human-blocked`.

**Designer:** That's the shape. And — separately — I'm flagging the V6 visual evolution as something we should *pause* and seek tester feedback on before shipping Element 4. Three elements in 60h with zero qualitative input is the same anti-pattern as backup-engine-without-dogfood: shipping into a vacuum.

**Engineer:** Agreed. The pause is cheap; the cost of going 4-5 elements deep in the wrong direction is high. Pair the V6 pause with the friend-DM ask.

**Agreed Direction:** **Activate-and-validate sprint.** Cycle 10888 ships the friend-DM (V6 + Feedback banner ask). Builds the `human-action.md` register with owner+deadline mechanic and migrates #708 into it. Pauses V6 Element 4+ pending tester input. Diagnoses cuisine-routing bug + ships one cuisine. Files `.foundationModels` chat backend eval gate. One non-design-impl SENIOR task. Verifies cross-stage eval gate template (#766) on the next prompt refresh or acknowledges it stays in standby.

## Decisions for Human

1. **#708 backup E2E dogfood — fourth consecutive cycle open.**
   - **(a) (Recommended) Build a `human-action.md` register with named owner + 48h deadline. Migrate #708 in with `@ashish-sadh` as owner. After deadline: ship feature flagged "engine validated, restore not field-tested."**
   - **(b) File yet another sprint-task asking for the wipe-and-restore.**
   - **(c) Accept the gap; backup ships unvalidated; first user device migration discovers any breakage.**
   - Recommendation: (a). Cycle-to-cycle re-asks are not producing action. A named owner + deadline + visible fallback is the shape that finally moves it.

2. **Settings → Feedback activation — banner shipped 4 days ago, zero signal.**
   - **(a) Wait additional 7 days for organic banner traffic.**
   - **(b) (Recommended) Human DMs 3-5 named friend testers TODAY with two questions: "did the banner appear?" + "what do you think of the V6 visual evolution?" — pairs both pending activation asks in one outreach.**
   - **(c) Build a second activation lever (in-chat prompt, push notification CTA) before measuring this one.**
   - Recommendation: (b). Single DM, double signal. Cycle 10262 made the same recommendation; it didn't happen. Naming the testers + scheduling the DM (or asking the human to do it on a specific date) is the missing step.

3. **V6 visual evolution — 3 elements shipped, 0 tester feedback. Continue or pause?**
   - **(a) Continue — ship Element 4 next cycle based on the V6 design-ref doc.**
   - **(b) (Recommended) PAUSE Element 4. Pair with the friend-DM ask above; get qualitative reactions to elements 1-3 first; resume after one round of feedback.**
   - **(c) Revert one of the three elements as A/B feedback baseline.**
   - Recommendation: (b). 3 elements in 60h with zero input is the engine-without-surface anti-pattern in UI form. Cost of pause is one cycle; cost of going wrong direction is 3+ cycles.

4. **Cuisine ship — 4 cycles flat at 5,420.**
   - **(a) (Recommended) Diagnose junior routing bug AND manually claim one cuisine task this cycle (parallel paths — don't wait).**
   - **(b) Reassign the cuisine tasks to SENIOR queue temporarily.**
   - **(c) Accept the slow lane; cuisine ships only when senior has bandwidth.**
   - Recommendation: (a). Both — the routing bug needs fixing (this cycle's commit), and the cuisine deficit needs closing (this cycle's ship). Don't let one block the other.

5. **`.foundationModels` chat backend — wired this cycle, no eval coverage yet.**
   - **(a) (Recommended) File PR B (Tier 3 eval gate) as sprint-task this cycle, before any default-on flip is considered.**
   - **(b) Wait for first user friction signal, then file eval.**
   - **(c) Keep `.foundationModels` selectable but never default; treat as "experimental setting" indefinitely.**
   - Recommendation: (a). Same template as cycle 10262 #771 — ship the wiring, file the eval gate immediately, cutover when parity is measured.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
