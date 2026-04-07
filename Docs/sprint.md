# Sprint Board

## In Progress

_(empty — pick from Ready)_

## Ready

### Tool-Calling Foundation
- [ ] **TC-1: ToolSchema struct** — Create `Drift/Services/ToolSchema.swift`. Struct with name, description, parameters (as JSON-encodable), handler closure. This is the building block.
- [ ] **TC-2: ToolRegistry** — Create `Drift/Services/ToolRegistry.swift`. Singleton that holds all registered tools. Methods: `register()`, `schemaPrompt()` (returns tool list for LLM prompt), `execute(toolCall:)`.
- [ ] **TC-3: Register food tools** — Register `search_food`, `log_food`, `get_nutrition`, `get_calories_left` in ToolRegistry. Handlers call existing AIActionExecutor/AppDatabase methods.
- [ ] **TC-4: Register weight tools** — Register `log_weight`, `get_weight_trend`, `get_goal_progress`. Handlers call existing WeightTrendCalculator/AppDatabase.
- [ ] **TC-5: Register workout tools** — Register `start_workout`, `create_workout`, `suggest_workout`. Handlers call existing WorkoutService.
- [ ] **TC-6: Register remaining tools** — Sleep, supplements, glucose, biomarkers, navigation. One tool per service.
- [ ] **TC-7: Inject tool schemas into system prompt** — Update LocalAIService.systemPrompt to include `ToolRegistry.shared.schemaPrompt()`. Keep it compact (tool name + 1-line description + params).
- [ ] **TC-8: JSON tool-call parser** — Add JSON parsing to AIActionParser alongside existing regex. Parse `{"tool":"name","params":{...}}` from LLM output.
- [ ] **TC-9: Wire ToolRegistry into AIChatView** — After LLM responds, check for JSON tool call → `ToolRegistry.execute()` → show result. Keep existing action tag parsing as fallback.
- [ ] **TC-10: Eval tests for tool calling** — Add 10+ eval tests: does the LLM output valid tool calls for "log 2 eggs", "start push day", "calories in banana"?

### Tool-Calling Polish
- [ ] **TC-11: Pre-tool hooks** — Validate params before execution (weight in 20-500 range, food name non-empty). Add to ToolSchema as optional `validate` closure.
- [ ] **TC-12: Post-tool hooks** — After tool executes, format result + suggest follow-up ("Want to log something else?"). Add as optional `formatResult` closure.
- [ ] **TC-13: Remove old keyword routing** — Once tools work reliably, remove AIChainOfThought keyword matching. Keep rule engine for instant answers only.
- [ ] **TC-14: Screen-aware tool filtering** — Only show relevant tools per screen (food screen → food tools, exercise → workout tools). Reduces prompt size.

### Model Quality
- [ ] **MQ-1: Test tool-calling models** — Try Hermes-3-Llama-3.2-1B and functionary-small for structured output. Compare with Qwen2.5-1.5B on eval harness.
- [ ] **MQ-2: Grammar-constrained sampling** — Use llama.cpp grammar to force valid JSON tool calls. Eliminates malformed output.
- [ ] **MQ-3: Eval harness to 100+ methods** — Expand from 63. Focus: tool-call format, multi-turn, ambiguous queries, Indian foods.

### Bugs & Polish
- [ ] **FEAT-001: Calorie estimation for unknown foods** — LLM fallback when DB lookup fails. Partially done (DB lookup works). Needs: LLM prompt for estimation, show breakdown, offer to log.
- [ ] **Food data gaps** — Add missing common foods found during testing (check eval harness MISS logs).
- [ ] **Flaky workout session tests** — `sessionSaveAndLoad`, `sessionRoundtripWithWarmups` fail intermittently. Fix UserDefaults timing.

## Done

- [x] BUG-001: Calories left wrong number
- [x] Action tags in system prompt + all screens
- [x] Removed hardcoded handlers → LLM
- [x] Direct template start from chat
- [x] Food parser: beverages, snacks, cooking verbs
- [x] Synced multi-food parser verbs
- [x] Enhanced workout context (body parts, exercises, suggestions)
- [x] CREATE_WORKOUT includes reps + weight
- [x] Few-shot examples in system prompt
- [x] Tightened 8 keyword false positives
- [x] Fixed action tag stripping bug
- [x] Instant nutrition lookup for DB foods
- [x] Response cleaner improvements
- [x] Calorie target floored at 500
- [x] 41 self-improvement cycles, 63 eval tests, build 84
- [x] Docs rewrite: 11 deleted, 7 created, clean structure
