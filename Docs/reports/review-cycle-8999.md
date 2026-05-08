# Product Review — Cycle 8999 (2026-05-06)

## Executive Summary
Six-day review window. The proactive-coach pivot landed: progressive overload alerts shipped (#633, #632), and the queue is shaped around three more proactive cards (protein adherence, glucose spike, workout consistency). But TestFlight has now been broken for ~17 builds (204–220) — every shipped feature since 2026-04-26 is invisible to testers. This is no longer a "blocker we tracked" — it is the single most important product fact this cycle.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 220 in project.yml / 203 last on TestFlight | +17 builds blocked since last review |
| Tests | ~1219 iOS + ~1201 DriftCore (pure-logic) | flat |
| Food DB | ~3,396 | +30 vs review #62 (Indian protein staples ship) |
| AI Tools | 23 registered + 5 analytical engines + 1 new (`detect_overload_plateau`) | +1 |
| Coverage | ExerciseService 67% (was 5%), TDEEEstimator 55% (was 29%) | + on critical services |
| P0 Bugs Fixed | 1 (#569 router prompt token ceiling) | +1 |
| Sprint Velocity | ~6 features shipped of ~20 in 61 cycles | low; ~30% |

## What Shipped Since Last Review (cycle 8938 → 8999)
- **Progressive overload plateau detection (#633, #632)** — Users now see "your bench has stalled for 3 sessions" with weight suggestions in the workout tab; AI tool `detect_overload_plateau` answers "is my squat plateauing?" in chat.
- **Build counter automation reliability** — `cb7bae16` (WIP build 219), build counter now at 220 in project.yml.
- **TestFlight watchdog circuit-breaker (#626)** — Watchdog now skips `testflight-due` creation while `testflight-archive-failed` flag exists, so sessions stop burning budget on guaranteed failure (still firing this session — see "Concerns" below).
- **No new features have reached real users since 2026-04-26.** The features above are merged to main but invisible to TestFlight testers.

## Competitive Analysis
- **MyFitnessPal:** Today tab redesign complaints persist as of late April; their GLP-1 free tier (April 28) remains the last major shipped move. Our chat-first logging vs their 4-tap diary is still the sharpest pitch — but the window only matters if our app reaches users.
- **Boostcamp:** Still the gold standard for exercise visual presentation. We have 960 exercises, all text. Design docs (#250, #274) for muscle-map visualization are filed but unexecuted.
- **Whoop:** 5.0 Healthspan (WHOOP Age, ECG, Blood Pressure) cements the "full health platform" positioning. Behavior Trends (habit→Recovery correlation after 5+ logs) directly competes with our analytical tools.
- **Strong:** Unchanged — minimal/clean workout logging, no AI moves.
- **MacroFactor:** Workouts app + Jeff Nippard programs + recipe photo scanning still defines the all-in-one bar at $72/year. Our edge: free, on-device, BYOK.

## Product Designer Assessment

### What's Working
- **Proactive coach identity is now coherent.** Progressive overload alerts complete a triad with protein streak alerts and supplement gap alerts — Drift is recognizably "the app that tells you what to look at." This is the pattern competitors spend cloud cycles to replicate.
- **Queue hygiene is healthier.** 23 open sprint-tasks (down from 70+ a few reviews ago) means the next senior session has clear focus, not a junk drawer.
- **Code-merged features are real and shippable.** `detect_overload_plateau`, recent foods quick-log, GLP-1 logging — these are not WIP, they're built. The constraint is publish, not build.

### What Concerns Me
- **17 builds dark on TestFlight is a credibility cliff.** A user who installed in late April has seen no updates in 10+ days. They will infer the app is dead. P0 #614 has been open across 4 reviews; no human has run the Xcode platform install. We need to either escalate the human ask harder, or accept this and ship to App Store directly with a different SDK target.
- **Feedback loop is silent.** Six consecutive cycles with zero user-filed bugs and zero user-filed feature requests. Reviews #54–#63 all flagged this. Settings → Feedback (#329 → #588) is at ~12 cycles deferred. Without a feedback channel, every product decision is a guess.
- **TestFlight hook is misfiring repeatedly** in this very session despite #626 — every Bash call is injecting "MANDATORY TestFlight publish" reminders. The watchdog fix isn't covering the human-session hook path. This eats session budget on a guaranteed-fail action.

### My Recommendation
Two product moves this sprint:
1. **Unblock TestFlight or pivot delivery.** Either escalate #614 with a literal "ashish must open Xcode > Settings > Platforms" reminder visible in command-center, OR pin the deployment target to iOS 17.0 (drop iOS 26.4 SDK requirement) and ship a fallback build. Pick one — the wait-for-human pattern is failing.
2. **Ship Settings → Feedback (#588) this sprint, no exceptions.** A 30-minute mailto row that has been deferred 12 cycles is not a prioritization decision, it's a product failure. Without it, the next zero-feedback cycle is also a guess.

## Principal Engineer Assessment

### Technical Health
- **Tests are healthy and fast.** DriftCore at ~1201 pure-logic tests in <8s warm; iOS suite at ~1219 in ~25s. The `swift test` loop is the highest-leverage quality gate Drift has.
- **Critical service coverage is climbing.** ExerciseService 5%→67%, TDEEEstimator 29%→55%. Targeted coverage on services that feed AI tools is paying off — these are the correctness layer for chat.
- **Build 220 in project.yml + Build 203 on TestFlight** means we have a 17-build version drift. Releases.json will have a gap. Whatever gets shipped next will be a "version 220" with no testers having seen 204–219.

### Technical Debt
- **TestFlight hook is broken in two ways.** (a) The circuit-breaker (#626) doesn't cover human-session injection, evidenced by repeated injection during this planning session. (b) The watchdog continues bumping `CURRENT_PROJECT_VERSION` despite the archive failure — we're at 220 with 0 archives since 203. Both need fixing in the next senior session.
- **State.md is now ~17 builds stale** (says 203, project.yml at 220). The pre-commit hook proposed in review #62 has not been built. Every session reading State.md silently undercounts shipped capabilities.
- **Planning crash (#407 → #589)** has been deferred 11+ cycles. Two-hour fix; human manual restart every 6h is the cost. This continues to be the highest unjustified deferral in the queue.
- **AIChatView at ~400+ lines** approaches the threshold; needs ViewModel extraction next time chat gets a feature touch.
- **Unbounded heartbeat commits.** Recent git log shows >30 `chore: heartbeat snapshot` commits since the last feature commit. These pollute `git log` and make "what shipped recently" hard to read. The watchdog should batch heartbeats or write them to a separate ref.

### My Recommendation
Two engineering moves this sprint:
1. **Fix the TestFlight hook end-to-end.** Stop bumping `CURRENT_PROJECT_VERSION` when archive has failed within last 24h. Stop injecting "mandatory publish" reminders during human sessions or when `testflight-archive-failed` flag exists. Both are single-file changes in `.claude/hooks/testflight-check.sh`.
2. **Ship the planning crash fix (#589).** Two hours of work has been deferred 11 cycles. The cost is human ops time every 6h. Make it the next senior P0 — no analytical tool is more valuable than this fix.

## The Debate

**Designer:** Stop building. Ship what we have. 17 builds dark on TestFlight is the only thing that matters this week. We cannot keep shipping into a void — every cycle of "feature merged but invisible" devalues all the engineering work behind it.

**Engineer:** I agree the TestFlight gap is the binding constraint, but "stop building" wastes a perfect-good queue of small fixes. The right move: fix the hook (so we stop wasting budget on guaranteed failures), file an escalation issue with literal install instructions for the human, and let the queue drain in parallel. Building doesn't compete with delivery — broken hooks compete with delivery.

**Designer:** Fair, with one caveat: every sprint task this cycle must be in the "high signal, low risk" tier. No new analytical tools, no new food DB grinds. Just reliability fixes (hook, planning crash, State.md), feedback loop unblockers (Settings → Feedback), and the proactive cards already in flight (#627, #631, #635). When we finally publish, the diff testers see should be coherent ("Drift now coaches you proactively") not a grab bag.

**Engineer:** Agreed. One more constraint: every PR this cycle must include a `Source:` line that maps either to (a) TestFlight unblock, (b) feedback loop, or (c) a 2026-05-04 review finding. No freelancing. The queue is small enough that discipline is cheap.

**Agreed Direction:** Reliability + delivery sprint. Prioritize TestFlight unblock and hook fix; ship Settings → Feedback and planning crash fix; finish the proactive-card triad (#627, #631, #635) so when delivery resumes, the user sees a coherent "proactive coach" story.

## Decisions for Human

1. **TestFlight: install or pivot?** P0 #614 has been open across 4 reviews. Options:
   - **(a) Open Xcode > Settings > Platforms > iOS and download the iOS 26.4 platform.** ~5 minutes of human time, unblocks 17 builds of work.
   - **(b) Pin deployment target to iOS 17.0 in `project.yml`** (drop iOS 26.4 requirement), accept that some new APIs unavailable. Ships immediately without human intervention, costs feature scope.
   - Recommendation: (a). Lowest cost. The autopilot literally cannot do (a).

2. **TestFlight hook injection during human sessions** — The hook is firing aggressive "MANDATORY publish" instructions even in human-driven sessions (this very session, repeatedly). Should we make the hook respect the session-type ("human" → no inject) the same way other auto-actions do? Filing as #639 in this planning cycle pending your nod.

3. **Heartbeat commit policy** — `chore: heartbeat snapshot` commits dominate `git log -20`. Should they (a) be squashed weekly, (b) live on a separate ref, or (c) be removed entirely? Currently inert ops noise drowning real ship signal.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
