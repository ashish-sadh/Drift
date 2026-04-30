# Product Review — Cycle 8274 (2026-04-28)

## Executive Summary

Since review cycle 7784, the team shipped builds 184–187 and closed all three active campaigns from last review: photo logging recovery is complete (editable card, free-text correction, DB-hint surfaced inline), the remote AI backend is live (BYOK, three providers, SSE streaming), and five P0 bugs were fixed. One new P0 is open (#527: cloud-model toggle crashes + stale privacy notice). `supplement_insight` and `food_timing_insight` are still unshipped — crash root cause was diagnosed via #493 but implementation hasn't started. These remain the highest-leverage unshipped work while Whoop actively markets Behavior Trends.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 187 | +4 (from 183) |
| Tests | ~2,940 (iOS ~1,240 + DriftCore ~913 + LLM eval ~160+) | +~40 |
| Food DB | 2,511 | flat |
| AI Tools | 21+ (log_water added, remote backend available) | +1 active |
| Context Window | 4,096 tokens | stable |
| P0 Bugs Fixed | 5 this cycle (#522, #524, #525, #514, #513) | high |
| Sprint Queue | 62 open | ↓6 |

## What Shipped Since Last Review (Cycle 7784)

- **Remote AI chat backend** (#515) — RemoteLLMBackend with BYOK Keychain; cloud chat reuses Photo Log's API key. Anthropic/OpenAI/Gemini SSE streaming with native parser for each, categorized errors (auth / rateLimited / transient / malformed), auto-fallback to local on transient failures only. Privacy-first: defaults to on-device, cloud toggle only renders when a BYOK key exists.
- **Photo logging recovery campaign complete** — Editable card title + add-by-text + remove-item (#495), free-text correction re-runs AI recognition with photo+hint as context (#496), DB search surfaced inline for post-recognition pick (#525). The "scan again" loop is retired.
- **Photo Log fallback chain** (#359) — FallbackVisionClient actor tries Anthropic → OpenAI → Gemini on transient failures (429, timeout, 5xx). Permanent errors (401, malformed) abort immediately. Keys fetched lazily; biometrics only prompt for the provider actually used. Provider name surfaced in chat summary when a fallback occurs.
- **DB-matching removed from all AI workflows** (#523) — `PhotoLogTool.applyDBMatching`, `log_food` preHook DB lookup paths, and `PhotoLogMatcher.matchFood` deleted. AI output lands directly. DB retained for explicit user search, barcode scan, and manual entry.
- **Cross-session conversation context** (#506) — Last 5 turns persisted as ring buffer (user message + AI summary, max 200 chars each). Injected as system-prompt prefix at session start. Chat no longer forgets users between sessions.
- **Hydration tracking** (#383) — `log_water` tool + daily hydration summary in chat. "I drank 2 glasses of water" works end-to-end.
- **Analytical tool crash diagnosed** (#493) — Root cause identified for `supplement_insight` (#417) and `food_timing_insight` (#418) crashes across 4 sessions. Implementation can now proceed without blind retry.
- **RemoteLLMBackend integration test** (#512) — Mock HTTP server for full streaming + tool-call round trip through `AIToolAgent` without a real API key.
- **P0 bugs**: Photo-log Fix button silent (#522), photo-log hint scoping to one item (#524), camera no permission prompt on first use (#514), servings change not persisting on Quick-add (#513), correction-as-replacement triggers (#346).
- **TestFlight build 187** shipped.

## Competitive Analysis

- **MyFitnessPal:** Today tab redesign complaints persist — more taps for logging, users frustrated. Cal AI photo scanning integrated, full coaching stack behind Premium+ ($20/mo). Our one-sentence logging is a direct counter to their added friction. Competitive window remains open but will close when they fix the tab redesign.
- **Boostcamp:** Exercise content (videos, muscle diagrams, per-exercise instructions) remains the gold standard. Drift has 960 exercises, text-only. Exercise vertical is still our weakest visual area.
- **Whoop:** Behavior Trends (habit → Recovery correlation after 5+ logs) is live and actively marketed. This is the `supplement_insight`/`food_timing_insight` pattern. Whoop is cementing the "habits → outcomes" mental model. Every cycle our analytical tools stay unshipped, that mental model is theirs.
- **Strong:** Minimal and clean, fast set/rep entry. No AI features. Their moat is UX simplicity — we don't need to match it.
- **MacroFactor:** All-in-one story deepening (Workouts + Apple Health write + Jeff Nippard content at $72/year). Same lane as Drift. Our counter: free, on-device, privacy-first.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **Photo logging is now a complete story.** Editable card, free-text correction, DB search inline — the "scan again" loop that made every photo log feel broken is gone. This is the cycle's biggest UX win. Users who tried photo logging and gave up now have a reason to retry.
2. **Remote backend + fallback chain = cloud quality without cloud lock-in.** A user who configured Anthropic + OpenAI keys gets seamless fallback on transient failures and they never know which provider served them. This is the "works like a premium service but stays private" promise made concrete.
3. **Cross-session context fixes the "app that forgets you" problem.** "You mentioned you're cutting last week — still going?" is now possible. This is table stakes for any app claiming to be a health coach.

### What Concerns Me

1. **`supplement_insight` and `food_timing_insight` are still unshipped.** Diagnosed (#493), but not implemented. Whoop is actively marketing Behavior Trends. We have the diagnosis, the campaign context, and the InsightResult pattern from `weight_trend_prediction`. This is an execution gap, not a design gap. Next senior session must ship both.
2. **P0 #527 (cloud-model toggle crashes + stale privacy notice) is the new credibility issue.** A feature we just shipped (#515 remote backend) has a crash on toggle. Privacy notice showing the wrong text based on which model is loaded is worse than no privacy notice — it trains users to ignore it. This blocks the remote backend from being a usable feature.
3. **Food DB flat at 2,511 for multiple cycles.** USDA Phase 2 proactive search (#345) has been deferred 15+ cycles. We added 500 foods from USDA batch last cycle — the model works. Proactive search is the next step. Users who type "edamame" or "lentil soup" and get nothing still open MFP. This is a daily trust erosion we can measure.

### My Recommendation

P0 #527 first — fix the cloud-model toggle crash and update the privacy notice to be model-aware. This unblocks the remote backend as a real feature, not a broken one. Then: senior session ships `supplement_insight` + `food_timing_insight` (diagnosis is done, execution is the constraint). Junior: USDA Phase 2 proactive search to break the food DB plateau.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

Strong sprint:
- DB-matching removed from AI workflows eliminates a class of silent failures. Vision AI is more accurate than fuzzy string matching for photos — the code now reflects that. Fewer attack surfaces for wrong answers.
- FallbackVisionClient actor is architecturally clean: single provider-selection responsibility, lazy key fetching, permanent vs transient error semantics clearly separated. This pattern should be the model for any future multi-provider integration.
- RemoteLLMBackend in DriftCore (no UIKit/AppKit) with AIBackend protocol conformance keeps the pipeline unchanged — only the backend differs. The integration test (#512) with mock HTTP server gives real confidence in the streaming + tool-call path.
- Cross-session context compression (user message + AI summary, capped at 200 chars each, ring buffer of 5) is the right tradeoff — conversation continuity without prompt bloat.

### Technical Debt

1. **State.md says build 174, actual is 187** — 13 builds stale. This has been flagged 6 consecutive reviews. Every session reading it makes wrong assumptions. No longer acceptable as backlog — treat as P0 quality issue.
2. **P0 #527 (cloud model toggle crash)** — A crash on user action is the worst failure mode. Remote backend just shipped; having a crash on the toggle means users who try it lose trust immediately. Root-cause must be read before implementing a fix.
3. **`supplement_insight` / `food_timing_insight` implementation pending** — #493 diagnosed the crash. We know what went wrong. Not implementing after diagnosis is the last failure mode — all the information to succeed is available.
4. **USDA DEMO_KEY in production (#488)** — 1,000 req/day cap. Fine for TestFlight under ~50 active users; launch blocker for public release.

### My Recommendation

1. **P0 #527 first** — read the crash, fix toggle + update privacy notice to reflect active model. This is one senior session at most.
2. **supplement_insight + food_timing_insight in next senior session** — diagnosis is done, WIP from crashed sessions exists. Read the diagnosis output, implement cleanly.
3. **State.md refresh as mandatory planning step 0** — this will be wrong again by next review if it's not on the checklist.

## The Debate

**Designer:** P0 #527 is the highest-priority item — a crash on a feature we just shipped undermines everything about the remote backend campaign. The privacy notice showing wrong model state is even more concerning from a trust angle. Fix it first, then the analytical tools.

**Engineer:** Agree completely — #527 is P0 and it blocks the remote backend from being usable. The crash surface is likely small (model toggle state transition). Once that's fixed, I want to do analytical tools in the same senior session if budget allows — the diagnosis (#493) is already done and the InsightResult pattern from `weight_trend_prediction` is proven. We have all the information; it's pure execution.

**Designer:** Yes — if #527 is a one-session fix (which it should be), the analytical tools should be the immediate follow-on. Don't let "after the P0" become "two cycles later." The Whoop window isn't closing gradually — it already closed. We're now building a feature that has a well-known competitor analog. Ship speed is the only variable left.

**Engineer:** Agreed. Plan: (1) P0 #527 fix in session 1, (2) supplement_insight + food_timing_insight in session 2, (3) State.md refresh as planning step 0 going forward. USDA proactive search (#345) as the junior parallel track to break the food DB plateau.

**Agreed Direction:** P0 #527 fix first (crash + privacy notice), then `supplement_insight` + `food_timing_insight` in the next senior session. State.md refresh moves to mandatory planning step 0. USDA Phase 2 proactive search as the junior parallel campaign.

## Decisions for Human

1. **Remote backend UI**: P0 #527 says the cloud-model toggle is "not very visible" in addition to crashing. After fixing the crash, should we make the model switch more prominent (e.g., a top-of-chat banner when cloud is active, showing which model and privacy implications), or keep it low-profile in Settings?

2. **supplement_insight + food_timing_insight scope**: The diagnosis (#493) is done. Should these ship as one senior session (two tools together), or as two sequential sessions (one tool each)? Single session is faster but higher crash risk; two sessions is safer but slower. Previous decision was "single session after diagnosis" — confirming this is still the call.

3. **USDA DEMO_KEY (#488)**: Any timeline for swapping to a registered key before a marketing push or App Store submission?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
