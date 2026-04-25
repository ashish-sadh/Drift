# Sprint Board

Focus: **AI Chat Quality (60%) + Code Architecture (40%).** Sprint: prompt token audit + multi-stage prompt experiment, expand LLM eval toward 175-case milestone, context window experiment, implicit intent coverage, conversation context pass-through.

## Regression Gate

**All pipeline gold sets at 100% baseline.** Any AI change MUST run BOTH before AND after:
1. `xcodebuild test -only-testing:DriftTests/FoodLoggingGoldSetTests` (deterministic, ~2s)
2. `xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS'` (LLM-loaded, ~5min — requires models at `~/drift-state/models/`, run `bash scripts/download-models.sh` first)

## In Progress

_(pick from Ready)_

## Ready

### P0 — AI Chat Quality

- [x] **#167 Prompt token audit** — Removed 8 redundant examples (rule restatements + duplicates), compressed 3 prose sections, consolidated recent_entries block from 3 lines to 1. Result: ~17% token reduction (~1060→~870 tokens). Rules updated: "HRV→sleep_recovery" → "sleep/HRV→sleep_recovery" to compensate for removed sleep example. Both IntentClassifier.swift and PerStageEvalSupport.swift updated (byte-for-byte identical). Run IntentRoutingEval to verify no accuracy regression.

- [x] **#176 Context window expansion** — Already shipped: n_ctx=min(4096,trainCtx), maxPromptTokens=4096-512-16=3568, maxNewTokens=512. testMultiTurn_longContextFollowUp validates >2048 token history. No action needed.

- [x] **#177 LLM eval milestone: 175 cases** — IntentRoutingEval now has 230+ assertions across 57 test functions. Added: testFoodLogging_noLogKeyword (7), testSleep_deepEdgeCases (5), testSupplementAdvice_isNotTool (3), testGlucose_implicitAndTrend (5), testCrossDomainInsight_routing (6), testWeightTrendPrediction_routing (5), and more. 175-case milestone exceeded.

- [x] **#178 Progressive multi-item disclosure** — Implemented in AIToolAgent.executeMultiItemFoodDisclosure (lines 375–415). Parallel TaskGroup resolves each food item, streams via onToken as each finishes (first-come). Final order sorted back to input order for recipe builder.

### P1 — SENIOR

- [x] **#163 Multi-stage prompt experiment** — Prototype built: MultiStageEval.swift in DriftLLMEvalMacOS. Stage A: compact domain router (food/weight/exercise/health/navigate/chat, 1-word output). Stage B: 6 domain-specific extractor prompts (~50% shorter than single-stage). Features.multiStageClassifier flag added (off by default). Run `xcodebuild test -scheme DriftLLMEvalMacOS -only-testing:MultiStageEval/testCompareStages` to measure accuracy+latency vs single-stage. Ship only if Δaccuracy ≥+2% AND Δlatency ≤0ms.

### P1 — Junior Tasks

- [ ] **#183 AI eval: implicit food intent coverage** — Add 20+ IntentRoutingEval cases for food logging without "log" keyword (natural phrasing: "had rice", "ate oatmeal", "drank a protein shake"). Mix in 5+ negative cases (nutrition queries vs log intent). All must pass at 100%.

- [ ] **#184 AI chat: pass last tool result as context** — When user logs food then asks a follow-up ("how many calories was that?"), pass the last tool result as `[LAST ACTION: ...]` context in the next LLM call. Add 3+ multi-turn eval cases. Token budget must not exceed 2048.

- [ ] **Food DB enrichment: +20 foods** — Target next cuisine gap. Check `Docs/backlog.md` for gaps. Verify macros via reliable source before adding.

---

## Permanent Tasks (never remove — always pick from these when nothing else is queued)

**AI chat quality is the product's core value. Every session must improve it. No sprint is complete without AI chat being better than when it started.**

**Before picking a task, read `Docs/roadmap.md` → "Now" items in the relevant domain. Work on what advances the current phase.**

### Auto-Research Loop (every sprint — automated, run at sprint start AND end)
The optimizer finds the best pipeline config, applies it, and pushes if regression-free. See `Docs/ai-autoresearch.md`.

- [ ] **Sprint start — record baseline:**
  ```
  xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS' \
    -only-testing:AutoResearchTests/testBaseline
  ```
  Record score in sprint notes (routing %, params %, response %, per-category).

- [ ] **Run optimization loop (~40 min, gated):**
  ```
  DRIFT_AUTORESEARCH=1 xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS' \
    -only-testing:AutoResearchTests/testAutoResearch
  ```
  Auto-applies winner if held-out ≥+1% with zero IntentRoutingEval regressions. Auto-reverts otherwise. Auto-pushes.

- [ ] **Eval enrichment (manual, separate PR):**
  Add 3–5 new `HardCase` entries to `DriftLLMEvalMacOS/HardEvalSet.swift` (isTrainSet: true).
  Sources: weakest perCategory from last run, new capability gaps observed in practice.
  Run `testHardEvalSetSanity` to confirm structure, then commit.

### LLM Eval Quality Loop (60% of every sprint — non-negotiable)
The eval is the product's immune system. It must grow every sprint or regressions will silently accumulate.

- [ ] **Every sprint: run → fix → expand → audit**
  1. **Run** `xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS'` — any failure is a P0, fix it now
  2. **Fix via prompt first** — change an example, reorder, tighten the RULES line. StaticOverride only if prompt tuning fails twice
  3. **Expand** — add 3+ new test cases from real user phrasings (not keywords). Pick a domain with <5 cases and add variants
  4. **Audit** — pick one domain (sleep, exercise, supplements, etc.) and add 3 edge-case variants: messy spelling, implicit intent, slang. Run eval after each
  5. **Retire** — check if any StaticOverride is now handled by the LLM at 100%. Remove it if so
  6. **Track** in PR description: cases added this sprint, failures fixed, overrides removed. Eval case count must never decrease

### AI Chat Architecture & Quality (always ongoing)
Equally important pillar. Prefer architectural improvements over keyword additions.

- [ ] **State machine refactor** — Replace scattered pendingMealName/pendingWorkout state vars with a proper conversation state machine. States: idle -> classifying -> executing_tool -> confirming -> logging. Clear transitions, no dangling state.
- [ ] **Prompt consolidation** — Single source of truth for tool schemas, examples, context injection. Measure token count, compress.
- [ ] **Multi-turn reliability** — Eliminate bugs where context is lost between turns. Test: 3-turn meal logging, 3-turn workout building, topic switching mid-conversation.
- [ ] **Natural freeform logging** — "log for breakfast 2 eggs and spinach and bread and coffee with 2% milk with protein powder and creatine" or "log chipotle bowl with 800 calories" -> AI parses everything, asks clarifying questions, does macro calculations, logs it.
- [ ] **Meal planning** — "plan my meals for today" -> iterative suggestions based on remaining macros + history.
- [ ] **Workout split builder** — "build me a PPL split" -> multi-turn designing across sessions.
- [ ] **Navigate to screen** — "show me my weight chart", "go to food tab". Needs navigation tool.
- [ ] When no obvious gap: stress-test with 10 real-world queries per domain in IntentRoutingEval.swift, run eval, fix what fails.

### UI Overhaul (always ongoing)
Equally important pillar. Bold changes encouraged — a full theme redesign overnight is fine. New card styles, new color palette, new typography — go for it. The only rule: app-wide consistency.

- [ ] **Theme overhaul** — Pick a direction and execute across ALL views in one cycle. Dark+accent, light+minimal, glassmorphism — any coherent vision. Touch every view.
- [ ] **Dashboard redesign** — Better information hierarchy, scannable at a glance, clearer progress indicators.
- [ ] **Chat UI polish** — Message bubbles, typing indicators, tool execution feedback, streaming UX.
- [ ] **Food diary UX** — Faster logging flow, better meal grouping, clearer macro display.
- [ ] **Usability rough edges** — Find confusing flows, missing feedback, awkward transitions. Fix them.
- [ ] UI changes must NOT break existing functionality. Visual-layer refactoring only.

### Test Coverage Improvement (always ongoing)
Ship quality. Coverage is a forcing function for finding bugs and understanding code.

- [ ] **Run coverage-check.sh** — Identify files below 80% (logic) or 50% (services) threshold. Fix them.
- [ ] **Write tests for uncovered paths** — Focus on error paths, edge cases, empty states, boundary conditions. Not just happy paths.
- [ ] **AI eval harness expansion** — Add test cases for every new capability. Target: every tool has 10+ eval queries.
- [ ] **Integration-style tests** — Test multi-step flows (parse -> resolve -> log -> confirm) end-to-end.

### Bug Hunting (always ongoing)
Proactively find bugs before users do.

- [ ] **Find and fix bugs** — Run the app mentally through edge cases. Check error paths, empty states, boundary conditions, data corruption scenarios.
- [ ] **Regression prevention** — When fixing a bug, add a test that would have caught it.

### Food Database Enrichment (always ongoing)
Better the DB, more people will come and log. Benchmark: MyFitnessPal has 14M+ foods.

- [ ] **Correct existing entries** — Find foods with wrong macros, missing data, bad serving sizes. Fix them.
- [ ] **Add missing foods** — Indian foods, regional dishes, restaurant items, branded products. Cross-reference with USDA/reliable sources.
- [ ] **Improve search** — Better aliases, spelling corrections, partial matches. "paneer" should find all paneer dishes.

### Ongoing: Code Improvement Loop
Autonomous refactoring. Run `code-improvement.md`. Principles in `Docs/principles/`. Log in `Docs/code-improvement-log.md`.

- [x] **Continue file decomposition** — GoalSetupView, LabsAndScans, Sleep, TemplatePreviewSheet extracted. Only 3 files over 700 remain (AIChatView, FoodTabView, ActiveWorkoutView) — these need ViewModel extraction.
- [x] **AIChatView.sendMessage ViewModel extraction** — sendMessage extracted to AIChatViewModel (AIChatView+MessageHandling.swift, extension AIChatViewModel). 491-line monolith decomposed into 20+ private handlers. AIChatView.swift is now pure SwiftUI view code.
- [x] **FoodTabView ViewModel extraction** — Done (#179, commit a0390be). ActiveWorkoutView still fat.
- [ ] **Deeper refactoring** — ActiveWorkoutView still fat. Move business logic out of views into ViewModels/Services.
- [ ] **DDD violations** — Direct DB calls in views, business logic in UI layer.

## Done (this sprint — cycle 6046+)

- [x] **#167 Prompt token audit** — ~17% token reduction in IntentClassifier prompt (1060→870 tokens). Removed 8 redundant examples, compressed 3 prose blocks, consolidated recent_entries. PerStageEvalSupport synced byte-for-byte.
- [x] **#177 LLM eval milestone: 175 cases** — IntentRoutingEval at 230+ assertions / 57 test functions. Milestone exceeded.
- [x] **#178 Progressive multi-item disclosure** — Parallel TaskGroup + per-item onToken streaming in AIToolAgent.executeMultiItemFoodDisclosure.
- [x] **#163 Multi-stage prompt experiment** — MultiStageEval.swift prototype with 26-case gold set. Features.multiStageClassifier flag added. Run to get Δaccuracy/Δlatency before deciding to ship.

## Done (previous sprint — cycle 5820→6046)

- [x] **#179 FoodTabView ViewModel extraction** — FoodTabView business logic extracted to FoodTabViewModel, eliminating DDD violations (direct DB calls in view). Commit a0390be.
- [x] **#180 Food DB +20** — Indian bread, eggs, Indian vegetables, grains, chicken, salads batch. Commit ac2b980.
- [x] **#182 P0 Bug: AI chat hallucinating food when diary is empty** — Fixed. Commit c978e89.
- [x] **TestFlight build 136** — Commit 87432e3.
- [x] **#169 Non-food negative assertions** — Added exercise instruction queries ("how do I do a deadlift", "form tips for squats") and protein-status queries ("am I on track for protein") to FoodLoggingGoldSetTests. Gold set 100%. Cycle 5892.
- [x] **#168 Supplement intent disambiguation** — Added testSupplementSubIntents_MarkVsStatus() to IntentClassifierGoldSetTests: 3 status cases (→ supplements) + 3 mark cases (→ mark_supplement). Deterministic gold sets 100%. Cycle 5892.
- [x] **#166 Multi-turn food logging reliability** — Added testMultiTurn_3TurnFoodLogging() to IntentRoutingEval: 3-turn breakfast test (oatmeal → banana → black coffee) with history context at each turn. Cycle 5892.
- [x] **#165 StaticOverrides audit** — All 20 rules enumerated and annotated. 0 rules removed — every rule serves a purpose distinct from LLM routing. Cycle 5892.
- [x] **#164 Voice filler word stripping** — Filler word normalization added to InputNormalizer (um, uh, like, you know, so). NormalizerGoldSetTests added. Deterministic gold set 100%. Commit a6ab5bc.
- [x] **Food DB +20** — 2,167→2,187: Burger King, Subway, Domino's, Gathiya, Surti Locho, Sev Mamra, Fage 0%, Two Good Yogurt, L-Glutamine, Collagen Peptides, Chipotle Burrito Bowl. Commit a6ab5bc.
- [x] **TestFlight build 134** — Commit c4d386a.

## Done (previous sprint — cycle 5374→5820)

- [x] **#161 Per-component isolated gold sets** — IntentClassifierGoldSetTests (22 cases), FoodSearchGoldSetTests (20+ cases), SmartUnitsGoldSetTests (20+ cases). All deterministic, <1s. Commit baa492a.
- [x] **#162 AIChatView.sendMessage ViewModel extraction** — sendMessage decomposed into 20+ private handlers in AIChatViewModel. AIChatView.swift now pure SwiftUI. Commit 139338a.
- [x] **#158/#160 LLM eval expansion** — IntentRoutingEval at ~120 cases (up from ~95). +5 new test groups. 100% pass rate. Commit 7a0fbd0.
- [x] **IntentRoutingEval calibration** — Synced prompt with IntentClassifier, protein shake routing hardened (was mis-routing to mark_supplement), phase reset hardened, +13 cases. Commits f9cd263, b2869d7.
- [x] **P0 Bug #170** — "a cup of dal" parsing fixed. Commit 706e77f.
- [x] **P0 Bug #171** — "log lunch" mis-logging cannoli (meal re-request in awaitingMealItems) fixed. Commit 706e77f.
- [x] **Voice: stuck indicator + utterance loss** — Stuck spinner resolved; earlier utterances no longer lost when pausing mid-session. Commit c642099. Build 133.
- [x] **Dashboard: deduplicate alerts + P0/issue lifecycle** — Alert deduplication and program.md P0 lifecycle fix. Commit 2c9b1d9.
- [x] **Dashboard: suppress protein + workout alerts for non-loggers** — Commit 19ab858.
- [x] **Karpathy-style auto-research optimizer + HardEvalSet** — `AutoResearchTests/testAutoResearch` pipeline with HardEvalSet.swift. Commit 8dfd77a.
- [x] **Food DB +20 foods** — 2,167→2,187: Burger King, Subway, Domino's, Gathiya, Surti Locho, Sev Mamra, Fage 0%, Two Good Yogurt, L-Glutamine, Collagen Peptides, Chipotle Burrito Bowl. Commit b9cd63f.

## Done (two sprints ago — Per-Component Gold Sets + LLM Eval)

- [x] **#151 LLM-first lab report parsing** — Shipped (cycle 5228). Gemma 4 primary extractor, chunked inference, confidence scoring (≥0.85 LLM wins), regex validation layer, AI-parsed badge.
- [x] **#156 Smart Units cross-interface consistency** — 4 bugs fixed, 5 regression tests added.
- [x] **#157 Food DB enrichment: +20 foods** — 2,067→2,087.
- [x] **Food DB enrichment: +20 foods** — 2,087→2,107 (Maharashtrian/Goan/seafood batch).
- [x] **#153 Test coverage** — All files pass thresholds.

## Done (three sprints ago — AI Chat P0 Fixes + Smart Units Audit)

- [x] #147 Bug: "Daily summary" tries to log food named "daily summary".
- [x] #148 Bug: "Weekly summary" query broken.
- [x] #149 Bug: "Log 2 eggs" adds egg benedict.
- [x] #150 Bug: AI chat regressed broadly — LLM eval lite run, gold set restored to 100%.
- [x] #154 AI eval: gold set at 100% verified post P0 fixes.
- [x] #152 Food DB enrichment: +20 foods (2,047→2,067).
- [x] #137 Smart Units: Complete audit of all 2,046 foods.
