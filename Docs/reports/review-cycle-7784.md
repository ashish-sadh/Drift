# Product Review — Cycle 7784 (2026-04-27)

## Executive Summary

Since review cycle 7724, the team shipped TestFlight build 183 with atomic-write harness fixes and increased senior task budget to 10. The three active campaigns (photo logging recovery, remote model prep, zero user math) are in queue with concrete sprint tasks filed. The analytical tool queue (`supplement_insight` #417, `food_timing_insight` #418) remains the highest-leverage unshipped work — Whoop shipped Behavior Trends in April 2026 and is actively marketing it. Closing those two tools makes the "AI health coach" positioning defensible.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 183 | +1 (from 182) |
| Tests | ~2,900 (2,061 iOS + ~850 DriftCore) | stable |
| Food DB | 2,511+ (USDA batch +500 added cycle 7689) | +500 |
| AI Tools | 20+ (analytical tools: cross_domain_insight, weight_trend_prediction) | stable |
| Context Window | 4,096 tokens | stable |
| P0 Bugs Fixed | 0 open P0 bugs | clean |
| Sprint Queue | 68 open (3 stale closed this cycle) | ↓3 |

## What Shipped Since Last Review (Cycle 7724)

- **Atomic-write crash fix** — RETURN trap in atomic-write was crashing the watchdog ~8x/day. Removed entirely. Build 183.
- **Harness stale-claim improvement** — Senior sessions with real file edits (non-heartbeat) are no longer flagged as stale at 60min. Threshold raised to 90min.
- **WIP preservation on crash** — Crashed sessions now save patch files to `~/drift-state/wip/` for 1-line `git apply` recovery.
- **Senior task budget raised** — Senior session budget: 5 → 10 tasks per cycle for faster campaign execution.
- **USDA Phase 2 batch import** — 500+ verified USDA foods added offline (cycle 7689 carry-forward confirmed in queue).
- **All 4 failing-query categories closed** (historical dates, calorie goal, macro goal progress, micronutrients) — the highest-trust user-facing wins since launch.
- **TestFlight build 183** shipped (this session).

## Competitive Analysis

- **MyFitnessPal:** Today tab redesign continues to generate user complaints about added logging taps — competitive window is open. Cal AI (photo scanning) integrated, 20M food DB. Full AI/coaching stack behind Premium+ ($20/mo). Their weakness is friction; our strength is one-sentence logging.
- **Boostcamp:** Still the gold standard for exercise content (videos, muscle diagrams, per-exercise instructions). Drift has 960 exercises but text-only — significant visual gap on the exercise vertical.
- **Whoop:** Behavior Trends shipped April 2026 — habit → Recovery correlation after 5+ logs. This is exactly the `supplement_insight`/`food_timing_insight` pattern we've been building. Every cycle those stay queued, Whoop cements this pattern as theirs.
- **Strong:** Still minimal and clean. Fast set/rep entry remains their moat. No AI features announced.
- **MacroFactor:** Workouts app with Apple Health write, auto-progression, Jeff Nippard video content at $72/year. Expanding into all-in-one territory. Our counter: free, on-device, privacy-first.

## Product Designer Assessment

*Speaking as the Product Designer persona:*

### What's Working

1. **AI chat depth is real.** All 4 failing-query categories closed means week-1 users now get correct answers to "how many calories last Tuesday?" and "am I hitting my protein goal?" — the two queries that kill trust fastest. This is the most important product work done in recent cycles.
2. **One-sentence logging vs. 4-tap MFP diary.** The competitive window from MFP's Today tab redesign backfire is still open. Users are actively complaining about MFP friction; we should capitalize in TestFlight release notes.
3. **Privacy moat is differentiating.** MFP, Whoop, and MacroFactor are all adding cloud AI. Our on-device privacy story is genuinely unique — and the BYOK pattern (user brings cloud keys, pays vendor directly) lets power users get cloud quality without compromising trust.

### What Concerns Me

1. **`supplement_insight` and `food_timing_insight` are still unshipped.** Whoop shipped Behavior Trends in April 2026. We have sessions crashing on these two tools for the second time. If this fails a third time, we need a fundamentally different implementation strategy, not another blind retry. The diagnostic issue #493 must land first.
2. **State.md is 9 builds stale** (says build 174, actual is 183). A stale State.md misleads planning sessions and makes the PE scorecard unreliable. This must be fixed as step 0 of the next sprint — not a nice-to-have.
3. **Photo logging recovery is half-started.** Campaign 1 (editable title, add-by-text, remove-item) has tasks in queue (#495, #496) but hasn't shipped yet. The "scan again" loop is still the UX — every photo log user is experiencing this today.

### My Recommendation

Ship the diagnostic for #417/#418 first (issue #493 is already in queue as SENIOR). Once we know the crash root cause, both analytical tools can ship in a single senior session. Simultaneously, one junior session should fix State.md (#481) and another should ship the photo-log review card (#495). These three actions together close the three biggest open gaps this review identified.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona:*

### Technical Health

The codebase is in its cleanest state since launch:
- DriftCore pure-logic test suite runs in 0.1s warm — the "run gold set every session" directive is actually working.
- 6-stage pipeline is well-layered with per-stage eval coverage at every tier.
- WIP patch preservation means crashed sessions now have a recovery path instead of lost work.
- No open P0 bugs.

Architecture concern: `RemoteLLMBackend` (#494) must conform to `AIBackend` protocol without forking the pipeline. The constraint is well-understood from decisions log — streaming + tool calls go through `AIToolAgent` unchanged. BYOK via Keychain means it stays in DriftCore. Risk is low if the protocol boundary is respected.

### Technical Debt

1. **State.md at build 174** — 9 builds behind. Every session reading it makes wrong capacity assumptions. This is the highest-urgency non-code debt in the system.
2. **`supplement_insight` and `food_timing_insight` crash root cause undiagnosed** — two sessions each, four total failures. The WIP patch files from crashed sessions exist in `~/drift-state/wip/` and should be read. This is information we paid for in session crashes — use it.
3. **USDA DEMO_KEY in production** (#488) — 1,000 req/day cap is fine for TestFlight but a launch blocker. Low urgency now but must ship before any marketing push.
4. **Food DB flat at 2,511 for multiple cycles** despite USDA batch adding 500+. The reported roadmap number matches. But proactive search tier (USDA Phase 2 #345) has been deferred 15+ cycles. This is the compound loss — users who don't find their meal log elsewhere and don't come back.

### My Recommendation

1. **Read crash WIP from `~/drift-state/wip/` for #417 and #418** before the next senior session. The data is there — 4 crashed sessions' worth of intermediate work. Diagnosis in 15 minutes prevents the 5th crash.
2. **Enforce State.md refresh as step 0 of every sprint** — not a junior cleanup task, a planning precondition.
3. **RemoteLLMBackend** (#494) is architecturally clean. Keep it in DriftCore, conform to AIBackend, test with mock HTTP responses. Risk is low; execution is the constraint.

## The Debate

**Designer:** The #1 thing we need right now is to ship `supplement_insight` and `food_timing_insight`. Whoop is actively marketing Behavior Trends. Every day these stay unshipped is a day Whoop cements the "habits → outcomes" pattern in users' minds. I know the sessions crashed — read the WIP and finish the work.

**Engineer:** Agree on priority but disagree on approach. Four crashed sessions on two tools is a signal, not bad luck. The crash data exists in the WIP patch files. We need 15 minutes of diagnosis (#493) before the next attempt, not a 5th blind retry. The pattern from `weight_trend_prediction` — which shipped cleanly — was a single senior session with clean scope. These two crashed tasks may have been over-scoped or hit an architectural constraint. Read the WIP first.

**Designer:** Fair point. Diagnosis first, then implement. But I want us to commit: after #493 lands, the very next senior session ships both tools in one go if the diagnosis says they're similar scope. Don't split them across multiple sessions and create drift again.

**Engineer:** Agreed — conditional on diagnosis showing no blocking architectural issue. If it reveals a deeper problem (e.g., SupplementService query methods don't exist), we fix the service first. But if the crashes were execution-quality issues (session ran out of budget, hit API timeout), we ship both tools in the next session.

**Agreed Direction:** Diagnosis (#493) first, then ship `supplement_insight` and `food_timing_insight` in a single senior session. State.md refresh (#481) is step 0 of the next sprint. Photo-log review card (#495) as the parallel junior track.

## Decisions for Human

1. **Analytical tool crash pattern**: Four crashed sessions on two tools. Should we lower the implementation scope (ship each tool separately), or proceed as planned (single session for both after diagnosis)? The risk of two separate sessions is calendar drift and session budget; the risk of one combined session is another crash.

2. **USDA DEMO_KEY (#488)**: This is blocking before any marketing push or App Store launch. Is there a timeline in mind? If TestFlight stays below ~50 active users, the 1,000 req/day cap probably holds, but it's worth setting a date.

3. **Remote model exposure**: Campaign 2 (#494) says "wire it, don't expose it." Is that still the right call? Or is there a target date to expose it in Settings for beta users?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
