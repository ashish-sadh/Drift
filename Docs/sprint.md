# Sprint Board

Focus: **Lab Reports LLM + Smart Units Interface Polish + Coverage.** Lab reports LLM (#151) is the big P1 SENIOR carry-forward. Smart Units shifts from rule-writing to cross-interface consistency verification. Coverage and food DB continue as junior tracks.

## Regression Gate

**55-query gold set at 100% baseline.** Any AI change MUST run gold set eval before AND after.

## In Progress

_(pick from Ready)_

## Ready

### P1 — Senior Implementation

- [ ] **#151 Implement LLM-first lab report parsing (#74)** — Per `Docs/designs/74-lab-reports-llm.md`. Gemma 4 as primary extractor (chunked, ~500 tokens/chunk), regex as validation layer. Add: confidence scoring, report date extraction (regex → LLM fallback → date picker), AI-parsed badge in biomarker history, accuracy warning banner in preview. SmolLM devices use existing regex-only path. Files: `Services/LabReportOCR.swift`, `Services/LabReportOCR+Biomarkers.swift`, `Models/BiomarkerResult.swift`. Tests required.

### P1 — Junior Tasks

- [ ] **#156 Smart Units: cross-interface consistency audit** — Log 10 varied foods (dosa, milk, rice, eggs, chicken, olive oil, almonds, dal, bread, protein powder) via (1) AI chat, (2) recipe builder, (3) manual food search. Verify all show natural units, not "serving". Fix any inconsistencies found. Add regression tests for fixes.
- [ ] **#157 Food DB enrichment: +20 foods** — Target gaps: street food/chaat, South Indian tiffin, gym/protein branded, Western breakfast, regional Indian sweets. Verify correct macros + smart unit assignment for each.
- [ ] **#153 Test coverage** — Run `./scripts/coverage-check.sh`. Fix any files below 80% (logic) or 50% (services) threshold. Priority: `LabReportOCR.swift` after #151 lands.
- [ ] **#140 Exercise visual enrichment research** — Per design doc #66. Research image/video sources (Wger, free-exercise-db, YouTube API, public domain GIFs). Document findings in `Docs/designs/133-exercise-enrichment.md` (create if missing). Time-boxed — go/no-go decision after research, not indefinite deferral.

### Design Docs (approved — pending implementation slot)
- #66 Design: Exercise image/video enrichment — `doc-ready`, `approved`
- #133 Design-impl: Exercise image/video enrichment — research task (= #140 above)

---

## Permanent Tasks (never remove — always pick from these when nothing else is queued)

**Before picking a task, read `Docs/roadmap.md` → "Now" items in the relevant domain. Work on what advances the current phase.**

### AI Chat Architecture & Quality (always ongoing)
Equally important pillar. Prefer architectural improvements over keyword additions.

- [ ] **State machine refactor** — Replace scattered pendingMealName/pendingWorkout state vars with a proper conversation state machine. States: idle -> classifying -> executing_tool -> confirming -> logging. Clear transitions, no dangling state.
- [ ] **Prompt consolidation** — Single source of truth for tool schemas, examples, context injection. Measure token count, compress.
- [ ] **Multi-turn reliability** — Eliminate bugs where context is lost between turns. Test: 3-turn meal logging, 3-turn workout building, topic switching mid-conversation.
- [ ] **Natural freeform logging** — "log for breakfast 2 eggs and spinach and bread and coffee with 2% milk with protein powder and creatine" or "log chipotle bowl with 800 calories" -> AI parses everything, asks clarifying questions, does macro calculations, logs it.
- [ ] **Meal planning** — "plan my meals for today" -> iterative suggestions based on remaining macros + history.
- [ ] **Workout split builder** — "build me a PPL split" -> multi-turn designing across sessions.
- [ ] **Navigate to screen** — "show me my weight chart", "go to food tab". Needs navigation tool.
- [ ] When no obvious gap: stress-test with real queries from `Docs/failing-queries.md` and fix what breaks.

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
- [ ] **Deeper refactoring** — Extract logic from fat functions (AIChatView.sendMessage 491 lines). Move business logic out of views into ViewModels/Services.
- [ ] **DDD violations** — Direct DB calls in views, business logic in UI layer.

## Done (this sprint)

_(empty — sprint just started)_

## Done (previous sprint — AI Chat P0 Fixes + Smart Units Audit)

- [x] #147 Bug: "Daily summary" tries to log food named "daily summary" — intent routing fixed, regression test added.
- [x] #148 Bug: "Weekly summary" query broken — same class fix, test added.
- [x] #149 Bug: "Log 2 eggs" adds egg benedict — food search ranking + SmartUnits egg rules fixed, test added.
- [x] #150 Bug: AI chat regressed broadly — LLM eval lite run, failure modes identified and restored. Gold set at 100%.
- [x] #154 AI eval: gold set at 100% verified post P0 fixes.
- [x] #152 Food DB enrichment: +20 foods (2,047→2,067): Bedmi Puri, Sooji Halwa, Anda Paratha, Churma Ladoo, Rajma Rice, Poha Cutlet, Ghevar, Imarti, Green Moong Dal, Sheer Khurma, Tawa Pulao, Methi Matar Malai, Oats Upma, Navratan Korma, Kathal Ki Sabzi, Lobia, Aloo Baingan, MuscleBlaze Biozyme Whey, Ghost Whey Protein, Masala Chai Powder.
- [x] #137 Smart Units: Complete audit of all 2,046 foods — serving count at ~65 (intentional nuts/canned). Eggs plural, bhaji, ras malai, kulfi, scone, cashew/pesto ordering, whey word-boundary, sambhar variant, rogan josh/sorpotel/rista/methi malai/balchao → bowl, orange chicken → bowl, sub/6-inch sandwiches → piece, biltong → strip, dressing → tbsp, half and half → tbsp, crab meat → cup, crab → piece, karela/bitter gourd → piece, lobia → cup, frosty → scoop.

## Done (two sprints ago — Multi-Stage LLM Pipeline)

- [x] #129 Stage 0+1: Wire pipeline skeleton in AIToolAgent
- [x] #92 Stage 2: Intent classifier (classification-only prompt)
- [x] #95 Stage 3: Domain-specific extraction prompts
- [x] #93 Prune StaticOverrides to ~10 essential patterns (Gemma path)
- [x] #94 Retire ToolRanker keyword scoring (Gemma path)
- [x] #96 Coverage: Pipeline refactor tests
- [x] Smart Units: rice→cup, protein powder→scoop, pasta/noodles→cup, dal/beans→cup
- [x] Smart Units: portionText fixes (bread→slices, pizza→slices, soup→bowls, momos→pieces)
- [x] Food DB: 1,641→1,927 (+286 foods across 5 junior cycles)
- [x] Synonym expansion: +24 South Indian, Middle Eastern, Bengali, Tamil terms
