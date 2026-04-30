# Product Review — Cycle 8519 (2026-04-29)

## Executive Summary

Since review cycle 8274, Drift shipped builds 188–192 and closed P0 #527 (cloud-model toggle crash), landed photo-attached meal logging (`propose_meal` card), wired RemoteBackendError fallback + retry, and made progress on zero-user-math (calories-left aggregation, multi-item macro totals, portion scaling gold set). `supplement_insight` and `food_timing_insight` remain unshipped — diagnosed, not implemented — while Whoop continues to actively market Behavior Trends as the canonical "habits → outcomes" pattern. MFP launched GLP-1 tracking (a new health domain we don't cover) and MacroFactor shipped AI photo recipe import directly competing with our photo log vision. The next sprint must ship both analytical tools and complete the zero-user-math campaign.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 192 | +5 (from 187) |
| Tests | ~2,940 (iOS ~1,219 + DriftCore ~913 + LLM eval ~160+) | stable |
| Food DB | 2,511 | flat (0 net adds since last review) |
| AI Tools | 21 (log_water active, propose_meal added) | +1 |
| Analytical Tools | 3 (cross_domain, weight_trend, wired) | 0 new |
| P0 Bugs Fixed | 3 (#527 toggle crash, #542 combo delete, #545 weight regression) | |
| Sprint Queue | 25 open | ↓37 from 62 |

## What Shipped Since Last Review (Cycle 8274)

- **Photo-attached meal logging with `propose_meal` card** (#518) — cloud AI vision now inline in chat. User attaches a photo; AI responds with a structured `ProposedMealCardView` with editable macros and one-tap log. Closes the "discuss the meal and log it in one chat" promise from Product Focus #2.
- **RemoteBackendError fallback + retry** (#519) — transient cloud errors (rate limit, timeout, 5xx) now auto-fallback to local model with a retry CTA. Permanent errors (auth, quota) surface a clear action. Chat doesn't hang silently on cloud failure.
- **Backend toggle fix** (#540) — P0 #527 resolved. Cloud-model toggle was stuck on Local due to stored-property + selector design issue. Redesigned to stored property properly reflecting backend state. Privacy notice updated to be model-aware.
- **Combo delete** (#542) — Delete moved to ellipsis menu in `ComboLogSheet`. Combo CRUD is now complete.
- **Hardcoded recipe seeds removed** (#541) — Default food seeds no longer pollute new installs with test recipes.
- **Weight chart time range** (#544) — Selected time range now enforced on chart x-axis. Users who pick "1 month" see 1 month, not all-time.
- **Weight regression window clipping** (#545) — Regression window no longer widens past logging gaps (gaps > 14 days). Prevents misleading trend lines when users take breaks.
- **Zero-user-math: calories left + multi-item totals** (#502) — "How many calories do I have left?" and multi-item meal totals now aggregate correctly. Partial zero-user-math campaign closure.
- **Portion scaling gold set** (#498) — Decimal servings parse correctly; gold set passes.
- **TestFlight build 192** shipped.

## Competitive Analysis

- **MyFitnessPal:** GLP-1 support launched April 28 (free to all users) — medication log, dose reminders, side effect tracking alongside nutrition. This is a new health domain Drift doesn't cover. MFP is also expanding the "Today" tab with Progress tab insights (weekly macro patterns vs goals). Their Today tab redesign continues to generate user complaints about more taps; competitive window for Drift's chat-first logging remains open but the GLP-1 move opens a new front. AI/coaching stack still behind Premium+ ($20/mo).
- **Boostcamp:** No notable Q2 2026 updates observed. Exercise content (videos, muscle diagrams, Jeff Nippard programming) remains the gold standard. Our exercise vertical remains text-only.
- **Whoop:** Behavior Trends and Behavior Insights now live — calendar views showing habit consistency + "once you've logged a behavior 5+ times yes/no, we show how it correlates with Recovery." This is exactly the `supplement_insight`/`food_timing_insight` pattern, fully shipped and marketed. Whoop 5.0 hardware update (Any-Wear sensor array for compression shorts/sports bras). Whoop is cementing "habits → outcomes correlation" as their identity.
- **Strong:** No notable April 2026 updates. Minimal and clean UX remains their moat. Not a direct competitor for our analytical or food-first direction.
- **MacroFactor:** Favorites (saved foods with preferred serving sizes), AI photo + text recipe import, expenditure modifier with step-informed data and goal-based adjustments, Push Pull Legs split in progress, Apple Watch experience coming. Their AI photo recipe import directly competes with our photo log for meal-from-photo UX — they're now in the same space we just entered. $72/year vs our free BYOK model.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **Photo-attached meal logging closes the two-app problem.** Users who used to discuss meals in ChatGPT and log in Drift manually can now do both in one chat. The `propose_meal` card + one-tap log is the product focus #2 promise (cloud AI as smart default) made real. MacroFactor is in this space now too — but our BYOK privacy model and on-device fallback is a meaningful differentiator.
2. **Backend toggle fix + RemoteBackendError handling = remote backend is usable.** The P0 crash on toggle (#527) was the biggest barrier to users actually trying the cloud backend. Now that it's fixed, users with BYOK keys have a reliable path. The auto-fallback to local on transient errors means the experience degrades gracefully rather than breaking.
3. **Sprint queue dropped from 62 → 25.** This is the healthiest queue state in months. Teams moving fast need a clear queue — 25 focused tasks is actionable, 62 was paralysis.

### What Concerns Me

1. **`supplement_insight` and `food_timing_insight` are still unshipped at review #57.** Whoop has been actively marketing Behavior Trends since April. Every week these stay queued, "habits → outcomes" becomes theirs in users' mental models. The diagnosis is done (#493). The InsightResult schema is reusable. This is a pure execution failure — the path is clear and the sprint keeps not claiming it.
2. **GLP-1 tracking is an emerging category Drift doesn't cover.** MFP made it free and prominent (April 28). GLP-1 adoption is accelerating — medication + nutrition tracking together is exactly the kind of cross-domain, daily-habit pattern that would fit Drift's all-in-one health coach identity. This isn't urgent, but it's a design doc conversation worth having this cycle.
3. **Unit conversion in chat (#497) stalled with WIP saved.** The zero-user-math campaign has `propose_meal` and macro aggregation, but unit conversion — the core of "user types oz, app converts silently" — is still incomplete. A resumable task with WIP isn't the same as done. The campaign isn't closed until unit conversion works invisibly.

### My Recommendation

Ship `supplement_insight` and `food_timing_insight` in the next senior session — make them the ONLY P0 priority. Resume and close unit conversion (#497). File a design-doc issue for GLP-1 tracking as a deferred investigation. Update State.md to build 192.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

The backend toggle redesign (#540) is architecturally cleaner — stored property with a proper setter, no stale selector capture. The RemoteBackendError categorization (auth / rateLimited / quotaExceeded / transient / malformed) is the right separation: callers can decide auto-fallback (transient) vs surface-to-user (auth/quota) without case analysis on HTTP status codes.

Weight regression fixes (#545: clip at logging gaps, #544: enforce x-axis range) show the analytics layer is getting tighter. These are correctness fixes, not cosmetic — users with gaps in their weight logs were getting misleading trend lines.

Test suite is stable at ~2,940 tests across all tiers. DriftCore 0.1s test loop is being used. Tier-0/1/3 split is clean.

### Technical Debt

1. **State.md says build 174, actual is 192** — 18 builds stale. This is now a planning-accuracy risk, not just doc debt. Any future session reading State.md is reasoning about a product that's 5 builds behind. Required fix this cycle.
2. **`supplement_insight`/`food_timing_insight` implementation gap** — crash root cause is diagnosed (#493), WIP patches exist from 4 stalled sessions. A 5th blind attempt would be inexcusable. The executor must read the diagnosis issue AND the WIP diffs before writing a single line. Reading the wip/<417/418>.patch files is step zero.
3. **Unit conversion (#497) has a resumable label** — WIP patch exists at `~/drift-state/wip/497.patch`. The executor should `git apply` the patch and finish, not start over. This is the zero-user-math campaign's most impactful remaining piece.
4. **USDA DEMO_KEY in production (#488)** — 1,000 req/day cap. TestFlight is fine; App Store launch is the trigger. Pre-launch blocker accumulating.
5. **Food DB flat at 2,511** — No net adds since the 500-food USDA batch last cycle. USDA Phase 2 proactive search (#345) is the growth lever. USDA offline JSON dumps are cheap to process — one junior session.

### My Recommendation

Read #493 and wip/417.patch + wip/418.patch before attempting `supplement_insight`/`food_timing_insight`. Then apply wip/497.patch and finish unit conversion. These are the two highest-impact unfinished tasks and both have WIP to work from. State.md update is a mandatory junior task — treat it as Step 0 before any product scorecard is valid.

## The Debate

**Designer:** Whoop Behavior Trends has been live for weeks. We keep saying "supplement_insight and food_timing_insight next sprint" and then not shipping them. Every review is the same — diagnosed, implementation pending. If we can't ship the 4th and 5th analytical tools in the next session, I want to understand what's structurally blocking it, not just defer again. The competitive cost is real.

**Engineer:** The structural blocker is well-documented: past attempts stalled because the InsightResult schema, SupplementService query methods, and registration all need to land together, and sessions ran out of budget mid-way. The fix is: (1) read the WIP patches from the 4 crashed sessions — they contain partial implementations — (2) claim both tools in one session, budget 10 tasks for it. The senior budget was raised to 10 per session. At 10 tasks, both tools + tests should fit.

**Designer:** On GLP-1 — it's not a sprint task yet, but MFP just made it free and prominent. Drift's all-in-one health coach identity should include medication tracking eventually. I'm not saying ship it now, but let's file a design-doc issue so it's not invisible in the queue.

**Engineer:** Agree. A design-doc request is low-cost and keeps the conversation from dying. Also: unit conversion (#497) has a WIP patch. `git apply` + finish is hours, not a full session. It's the most impactful zero-user-math item left. Bundle it with the analytical tools session.

**Agreed Direction:** Next senior session: read #493 + wip/417.patch + wip/418.patch, implement `supplement_insight` + `food_timing_insight` with eval cases in same PR. Apply wip/497.patch and close unit conversion. Junior: State.md to build 192, GLP-1 design-doc issue filed. These are the sprint priorities — no new analytical tools until these ship.

## Decisions for Human

1. **GLP-1 tracking scope.** MFP just launched free GLP-1 support (medication log + dose reminders + side effect tracking + nutrition correlation). Drift's all-in-one health coach identity is a natural fit, but it requires a new domain model (medication log, dose scheduling). Options: (a) file a design-doc issue now and research in a future sprint; (b) defer entirely — focus on food/weight/exercise/supplement depth first. Recommendation: (a) — file the design doc, no implementation commitment.

2. **USDA DEMO_KEY deadline.** The 1,000 req/day cap is fine for TestFlight; it becomes a launch blocker at App Store. Options: (a) swap DEMO_KEY for a registered key this sprint as a junior task (30 min); (b) defer until closer to App Store launch. Recommendation: (a) — it's 30 minutes and removes an accumulating risk.

3. **Unit conversion #497 ownership.** The task has a resumable label and WIP patch at `~/drift-state/wip/497.patch`. Options: (a) senior claims it as part of the analytical tools session (wip/497.patch is `git apply` + finish); (b) junior claims it separately. Recommendation: (a) — the zero-user-math campaign is architecturally related to the analytical tools layer; bundle it.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
