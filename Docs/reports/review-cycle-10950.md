# Product Review — Cycle 10950 (2026-05-17)

## Executive Summary
Twenty-four hours since the cycle-10888 review and 1 substantive commit on `main` (the daily exec briefing). This review is firing because the cycle counter advanced past the 20-cycle interval despite ~1 wall-clock day passing — the review cadence is calibrated to cycle count, but autopilot cycle frequency has accelerated since the calibration was set. The product hasn't moved enough to justify a full cycle-10888-shape review; this one is short by design, documents one new decision, and surfaces the cadence-mismatch itself as the most important finding.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 251 (archived 2026-05-16) | flat |
| Tests | ~2,553 (~1,253 iOS + ~1,300 DriftCore) | flat |
| Food DB | 5,420 | flat (4 cycles) |
| AI Tools | 35 (11 analytical engines) | flat |
| Coverage | 80% logic / 50% services (gate target) | flat |
| P0 Bugs Fixed | 0 (since 10888) | n/a |
| Sprint Velocity | 0 new closures since 10888 | sub-baseline (24h window is small) |
| Open sprint-tasks | 48 | -1 (#788 closed, planning #798 in flight) |

## What Shipped Since Last Review
- **#799 — daily exec briefing 2026-05-17.** This is it. No feature commits, no fixes. Build 251 archive from yesterday remains the latest TestFlight build.

Honesty check: a single-doc commit is not "what shipped" in any meaningful product sense. Calling out the zero-feature window is the point.

## Competitive Analysis
Skipping the web-search sweep this review. The most recent cycle-10888 review covered MFP / Whoop / MacroFactor / Boostcamp / Strong moves comprehensively (1 day ago). No competitor has shipped a new public release in 24h that would change the strategic read; running the sweep would be ritual, not signal. Resume in the next review.

## Product Designer Assessment

### What's Working
- The cycle-10888 escalation pattern (file #789 to build `human-action.md` register with named owner + 48h deadline) is the right *shape* for fixing the #708 4-cycle slip — but the test is whether the register lands, not whether the recommendation got filed. So far it's still queued, not built. Watch this in the next 48–72h.
- TestFlight pipeline remains stable post cycle-10262 P0-on-failed-archive rule. Build 251 archived yesterday cleanly.

### What Concerns Me
- **Zero new user-facing surface in 24h, on the day after a full review found 3 SENIOR-level diversification opportunities (#789/#790/#797).** I'm not panicked by 24h of low velocity — sprint planning *is* the work today — but if the next 48h shows the same pattern, the queue is functioning as a holding pen, not a backlog.
- **Settings → Feedback null traffic 4 days post-banner-ship is still the unresolved activation question.** Cycle 10888's review surfaced it; cycle 10262's surfaced it; cycle 9851's surfaced it. Three reviews in a row with the same finding. The standing rule from cycle 9851 ("a review recommendation that survives one cycle without action becomes a sprint-task, not a re-recommendation") demands action, not re-naming. Tomorrow's `human-action.md` register (if #789 lands) is the structural enforcement — but I want to see the DM go out *before* I trust the register works.

### My Recommendation
Hold feature work, drain the three SENIOR diversification tasks (#789, #790, #797). One day of zero-feature velocity is OK; two is a problem. The next review (cycle 10970-ish) should be able to point to (a) #789 register landed, (b) #790 cuisine-routing diagnosis written, (c) #797 chat backend parity number measured.

## Principal Engineer Assessment

### Technical Health
- Working tree shows 4 uncommitted files under `DriftCore/.../MultiIntentSplitter*` and `DriftLLMEvalMacOS/MultiIntentDeterministicEval.swift` — that matches the in-flight work for #791 (multi-intent splitting v2 from cycle 10888). Another agent's WIP; not for me to touch.
- Test suite stable. No new flake reports since #729 (GLP1InsightToolTests date-sensitive flake, already in queue).
- Build 251 archive succeeded. The "auto-P0 on failed archive" rule from cycle 10262 has not fired since #770 closed.

### Technical Debt
- **The 5a3f6eec extrapolation fix is a class of bug, not an isolated case.** Today's decisions.md entry documents the 2-point projection bug that displayed "+4.41 lbs/wk" over a 5-day, 2-weigh-in window with a "based on last 21 days" label. The pattern — UI labels claim more evidence than the math used — likely exists elsewhere. Calorie projection, macro targets, TDEE-from-trend, glucose averages, supplement adherence percentages all run windowed calculations against potentially-sparse data. Worth a deliberate audit, not opportunistic catches.
- **graphify watch fails on every commit** (>7,908 nodes → too large for HTML viz). The error is noise but the AST extraction is also rebuilding 556 files on every branch switch / commit, which is real wall time. #793 ("quiet graphify watch noise") is in queue from cycle 10888 — keep it queued, don't deprioritize.

### My Recommendation
File the windowed-calculation audit as a SENIOR task. The 2-point extrapolation fix in 5a3f6eec only patched WeightTrendCalculator; the pattern (UI labels asserting confidence the math doesn't earn) almost certainly recurs. This is the kind of work that disappears between cycles unless it has a Source line and acceptance criteria.

## The Debate

**Designer:** The activation channel issue keeps slipping. We have three reviews in a row pointing at Feedback null traffic. Even if `human-action.md` (#789) lands tomorrow, the DM doesn't auto-send — a human still has to write it. I want a structural change: this cycle's sprint plan must include the DM as a register entry with a 48h deadline, not a recommendation. Otherwise the register is just a fancier form of the same un-actioned ask.

**Engineer:** Agreed in principle, but adding the DM as a register entry is *the work of #789*, not a parallel commit. If #789 builds the register and integrates it into the exec template, the DM gets named there as the first inhabitant. Filing the DM register entry now, before #789 lands, would just put the same ask in a different file with the same enforcement gap.

**Designer:** Then #789's acceptance criterion has to include "first register entry exists with the friend-tester DM as the inhabitant," not just "register file scaffolded." Otherwise we'll close #789 with an empty file and call it done.

**Engineer:** That I'll commit to. Update #789's body to require the seed entry; if that's already there, fine; if not, comment + update.

**Agreed Direction:** #789 must ship the register *with the friend-tester-DM as its first entry*, not as a scaffolded but empty file. Audit acceptance criteria when claiming the task.

## Decisions for Human

**1. Review cadence is mis-calibrated against autopilot's current cycle frequency.** The 20-cycle interval was set when cycles were slower; today, 70 cycles elapsed in ~24 hours, so we get a daily review. Daily reviews after daily exec briefings are redundant for the human and overweight the process side of work. **Options:**
- A: change interval to 100+ cycles (would have skipped this review)
- B: switch from cycle count to wall-clock interval (e.g. every 5 days)
- C: keep current interval but make reviews opt-in skippable when <3 substantive commits since last review
- D: accept current cadence; reviews are cheap docs that don't take human time unless commented on

Bias toward B (5–7 day wall clock).

**2. Should #793 ("quiet graphify watch noise") be promoted from JUNIOR to SENIOR?** Graphify rebuilds 556 files on every branch switch and commit, AND emits a "too large for HTML viz" error every time. JUNIOR scope would suppress the error; the real fix (sample the graph, partition by module, or skip when above N nodes) is a small architecture call. Vote on scope.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
