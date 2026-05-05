# Product Review — Cycle 8938 (2026-05-04)

## Executive Summary

Since cycle 8789 (yesterday), the sprint closed GLP-1 medication tracking end-to-end (tool + model + card + dose reminders), surfaced recent foods quick-log, fixed supplement routing and medication timezone bugs, and added 90+ foods. The critical blocker is TestFlight: builds 204–213 all failed to archive ("iOS 26.4 SDK missing") — no user has received an update in several days despite substantial work landing. The next sprint must ship a working build before anything else.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 213 (on-disk; TF broken) | +10 since review — none reached users |
| Tests | ~2,386 (1219 iOS + 1167 DriftCore) | +~60 (test coverage improvements) |
| Food DB | 3,396 | +90 since last review |
| AI Tools | 23 registered, 5 analytical | = stable |
| Coverage | Not measured this cycle | — |
| P0 Bugs Fixed | 2 (supplement_insight routing, medication timezone) | |
| Sprint Velocity | ~17/20 tasks closed | High |

## What Shipped Since Last Review

- **GLP-1 medication tracking** — `log_medication` tool, `DailyMedication` model, confirmation card; full medication adherence queries now route correctly
- **GLP-1 dose reminder notifications** — smart on-device reminders for medication timing
- **Per-stage elapsed time indicator in chat** (#309) — users see "Thinking… 1.2s" per pipeline stage; reduces perceived latency
- **Recent foods quick-log** — most-logged foods shown when search field is empty; friction-free re-logging
- **Settings → Feedback row** — closes 9-cycle deferral (#329); users can now submit feedback
- **Food DB +90** — Indian protein staples, branded protein (MuscleBlaze, AS-IT-IS), Rajasthani, Gujarati, Andhra, German, Russian, Cambodian, Laotian, Venezuelan, Colombian cuisines
- **Accessibility polish** — 5+ icon-only buttons now have VoiceOver labels
- **Design docs filed** — UX/theme redesign (#250, 3 directions), exercise muscle map + YouTube curation (#274)
- **Fix: supplement_insight steals medication adherence queries** — routing correctness
- **MultiTurnRegression +8** — GLP-1 and medication correction chains added to eval harness
- **StaticOverrides Tier-0 test suite** — 4 pre-existing failures fixed, coverage expanded

## Competitive Analysis

- **MyFitnessPal:** MFP launched free GLP-1 support in April 2026 (medication log, dose reminders, side effect tracking). Drift's GLP-1 tracking is now in parity on core functionality — and we do it on-device without cloud or account. MFP's advantage is integration with their 20M food DB and ChatGPT Health AI. Their GLP-1 feature is cloud-only and behind a login.
- **MacroFactor:** Launched Workouts app with auto-progression, cardio, Apple Health write, and AI recipe photo logging at $72/year. Becoming a serious all-in-one competitor. Our edge: free, on-device, privacy-first. No news on new MacroFactor features this week.
- **Whoop:** AI Coach now has conversation memory and contextual guidance; Women's Health panel with 11 biomarkers + hormone cycle integration. Their proactive nudge pattern continues to set the standard. We have dashboard alerts but not push-level nudges yet.
- **Strong:** Minimal and focused — no major changes observed. Clean UX remains their moat.
- **Boostcamp:** Exercise videos + muscle diagrams remain the gold standard for exercise vertical. Our design doc #274 (muscle map + YouTube curation) is the right response — need to execute.

## Product Designer Assessment

*Speaking as the Product Designer persona:*

### What's Working
- **GLP-1 tracking closure** — MFP launched this in April and we matched core parity within one sprint. That's fast execution on a real market signal. On-device + no-account is a genuine differentiator.
- **Recent foods quick-log** — reduces the single most common daily friction: re-logging the same breakfast. Small change, high daily impact.
- **Per-stage elapsed time** — sets user expectations during long AI queries. Reduces "is it frozen?" anxieties.

### What Concerns Me
- **TestFlight has been broken for ~10 days** — builds 204–213 never reached users. All the GLP-1 work, the recent foods quick-log, the accessibility fixes — none of this is in users' hands. This is a trust and feedback problem. If TestFlight friends can't test, we have no quality signal.
- **Design docs (#250, #274) are filed but not scheduled** — UX/theme redesign has been "Now" on the roadmap for several reviews. A third design direction doesn't close the gap; execution does. The muscle map design doc is cleaner in scope — schedule it first.
- **Exercise vertical is still all text** — Boostcamp users see diagrams and videos. Our exercise section feels like a spreadsheet. Design doc #274 is the right fix; it's been waiting long enough.

### My Recommendation
Fix TestFlight immediately (P0 — users have received nothing in days). Then ship exercise muscle map visualization from #274 — it's designed, scoped, and the exercise vertical has been our weakest point for 5 reviews. Defer UX/theme redesign to after muscle map ships.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona:*

### Technical Health
Architecture is solid. DriftCore separation is clean. The medication tracking implementation (log_medication tool + DailyMedication model + confirmation card) followed the existing patterns correctly. StaticOverrides test suite expansion is good hygiene. Test count growing steadily. The supplement_insight routing fix suggests the intent routing layer still needs systematic coverage — each new tool creates new routing conflicts.

### Technical Debt
- **iOS 26.4 SDK blocker is unresolved** — multiple failed archive attempts point to the Xcode SDK version not being installed, not a code issue. This is an infra gap, not a code fix. The session keeps bumping build numbers without ever archiving. Need to either install the correct SDK or lock the build to a known-good SDK version.
- **cycle-counter vs commit-counter divergence** — `cycle-counter` was 8666 while `commit-counter` was correctly at 8938. The `report-service.sh start-review` was generating stale cycle numbers until we passed the cycle explicitly. This is a data consistency bug that will quietly produce wrong review branch names every cycle.
- **AIChatView** — still 400+ lines. Each new feature (GLP-1 card, elapsed time indicator) adds to it. Should be extracted when the next major chat feature lands.
- **StaticOverrides** — now 421 lines. The file is still the right abstraction but the line count signals it's approaching extract-method territory.

### My Recommendation
P0: fix the iOS SDK archive issue so builds actually reach TestFlight. P1: exercise muscle map from #274 (clean design doc, high user visibility, no architecture risk). File a harness task to repair cycle-counter/commit-counter consistency. The AIChatView and StaticOverrides debt is real but not blocking — address in the next refactor cycle.

## The Debate

**Designer:** We have 10 days of work that no user has seen. The most important thing this sprint is getting a TestFlight build out. After that, exercise visualization is the highest ROI — users see the exercise tab every workout day and it's the one vertical where competitors visibly outclass us.

**Engineer:** Agreed on both counts — TestFlight is the P0. On exercise visualization: the muscle map in #274 is well-scoped (SVG body map, color intensity by volume, no video initially). We can ship the basic heatmap in one sprint. YouTube curation from #274 is a separate track — don't block on it. The bigger engineering concern is the cycle-counter bug: if we don't fix it, every future planning session will try to create review branches with wrong names.

**Designer:** The cycle-counter bug is a 10-minute fix. Add it to the junior queue. On exercise: agree — ship the heatmap, defer YouTube. Users asking "what did I work today?" in the exercise tab should see a visual answer, not a text list. That's the gap.

**Engineer:** Cycle-counter fix confirmed as junior. For the muscle map: we should ship it as an SVG overlay on the exercise log card, not a standalone screen — it's more useful in context. That's actually simpler to build than a separate view. One sprint, clean.

**Agreed Direction:** Ship TestFlight (fix SDK or downgrade) as P0. Ship exercise muscle map visualization as P1 (inline on workout card, SVG with volume-intensity). Fix cycle-counter/commit-counter divergence as junior infra task. Defer UX/theme redesign until muscle map is in users' hands.

## Decisions for Human

1. **TestFlight SDK blocker** — Multiple failed archives cite "iOS 26.4 SDK missing." Options: (a) install Xcode beta with iOS 26.4 SDK, (b) pin deployment target to iOS 17 and archive with current Xcode, (c) accept no TestFlight until Xcode updates. Which path?

2. **UX/theme redesign timing** — Design doc #250 has 3 directions. This has been on the roadmap for many reviews. Do you want to review the 3 directions and pick one before it enters the sprint, or defer another cycle?

3. **GLP-1 depth** — log_medication + dose reminders are shipped. The glp1_insight analytical tool (#603) is in the new sprint. Do you want to prioritize that, or hold GLP-1 depth until exercise visualization ships?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
