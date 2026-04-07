# Tool Registry — SLM Tool-Calling Surface

Each service in Drift exposes tools the small language model can invoke.
The model's job: understand intent, pick tool, extract parameters.
Swift's job: execute tool, compute results, present UI.

## Tool Format

```json
{
  "name": "tool_name",
  "description": "What this tool does (shown to model)",
  "parameters": { "param1": "type", "param2": "type" },
  "returns": "What the tool returns",
  "action": "What happens in UI (sheet, navigation, inline response)"
}
```

---

## Food Tools

**Source:** `AIActionExecutor.swift`, `AppDatabase.swift`, `FoodLogViewModel.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `search_food` | query: String | Food name, calories, macros per serving | Inline response |
| `log_food` | name: String, amount: Double?, meal: String? | Confirmation | Opens FoodSearchView sheet |
| `get_nutrition` | name: String | Cal/P/C/F/fiber per serving | Inline response |
| `get_daily_totals` | date: String? | Calories eaten, remaining, macros | Inline response |
| `get_calories_left` | — | Remaining cal, protein needed, time context | Inline response |

**Current implementation:** `parseFoodIntent()`, `parseMultiFoodIntent()`, `findFood()` in AIActionExecutor.swift. Action tag: `[LOG_FOOD: name amount]`.

---

## Weight Tools

**Source:** `AIActionExecutor.swift`, `WeightTrendCalculator.swift`, `AppDatabase.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `log_weight` | value: Double, unit: String | Confirmation | Saves to DB |
| `get_weight_trend` | — | Current, weekly rate, direction, changes | Inline response |
| `get_goal_progress` | — | Target, % done, projection date | Inline response |

**Current implementation:** `parseWeightIntent()` in AIActionExecutor.swift. Action tag: `[LOG_WEIGHT: value unit]`.

---

## Workout Tools

**Source:** `WorkoutService.swift`, `ExerciseDatabase.swift`, `AIActionParser.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `start_workout` | template_name: String | Template exercises | Opens ActiveWorkoutView sheet |
| `create_workout` | exercises: [{name, sets, reps, weight?}] | Workout summary | Opens ActiveWorkoutView sheet |
| `suggest_workout` | — | Body parts needing training, template suggestion | Inline response |
| `get_workout_history` | limit: Int? | Recent workouts with exercises | Inline response |
| `get_exercise_info` | name: String | Body part, muscles, equipment | Inline response |

**Current implementation:** Direct template matching in AIChatView.swift. Action tags: `[START_WORKOUT: name]`, `[CREATE_WORKOUT: Exercise 3x10@135]`.

---

## Sleep & Recovery Tools

**Source:** `HealthKitService.swift`, `RecoveryEstimator.swift`, `AIDataCache.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `get_sleep` | — | Hours, stages, quality | Inline response |
| `get_recovery` | — | Recovery %, HRV, RHR | Inline response |
| `get_readiness` | — | Training readiness assessment | Inline response |

**Current implementation:** `sleepRecoveryContext()` in AIContextBuilder.swift.

---

## Supplement Tools

**Source:** `AppDatabase.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `get_supplement_status` | — | Taken/total, remaining names | Inline response |
| `mark_supplement_taken` | name: String | Confirmation | Updates DB |

**Current implementation:** `supplementStatus()` in AIRuleEngine.swift.

---

## Glucose Tools

**Source:** `AppDatabase.swift`, `AIContextBuilder.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `get_glucose` | — | Average, range, in-zone %, spikes | Inline response |
| `get_glucose_after_meal` | meal: String | Pre-meal, peak, rise | Inline response |

**Current implementation:** `glucoseContext()` in AIContextBuilder.swift.

---

## Biomarker Tools

**Source:** `AppDatabase.swift`, `BiomarkerKnowledgeBase.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `get_biomarkers` | — | Out-of-range markers with values | Inline response |
| `get_biomarker_detail` | name: String | Value, range, trend, improvement tips | Inline response |

**Current implementation:** `biomarkerContext()` in AIContextBuilder.swift.

---

## Navigation Tools

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `open_food_tab` | — | — | Switches to Food tab |
| `open_weight_tab` | — | — | Switches to Weight tab |
| `open_exercise_tab` | — | — | Switches to Exercise tab |

**Current implementation:** `[SHOW_WEIGHT]`, `[SHOW_NUTRITION]` parsed but not yet executed.

---

## Rule Engine (Instant — No Model Needed)

These bypass the model entirely for speed:

| Pattern | Handler | Source |
|---------|---------|--------|
| "daily summary" / "summary" | `AIRuleEngine.dailySummary()` | AIRuleEngine.swift |
| "how's my protein" | Computed from daily nutrition | AIChatView.swift |
| "what did I eat today" | `AIContextBuilder.foodContext()` | AIChatView.swift |
| "yesterday" | `AIRuleEngine.yesterdaySummary()` | AIRuleEngine.swift |
| "weekly summary" | `AIRuleEngine.weeklySummary()` | AIRuleEngine.swift |
| "calories left" | `AIRuleEngine.caloriesLeft()` | AIRuleEngine.swift |
| "supplements" | `AIRuleEngine.supplementStatus()` | AIRuleEngine.swift |
| "calories in [food]" | DB lookup → instant nutrition | AIChatView.swift |

---

## Migration Path: Action Tags → Native Tool Calling

**Current (v1):** Model outputs `[LOG_FOOD: eggs 2]` as text, Swift regex-parses it.

**Target (v2):** Model outputs structured JSON:
```json
{"tool": "log_food", "params": {"name": "eggs", "amount": 2}}
```

**How to get there:**
1. Define tool schemas in JSON format (this file)
2. Inject schemas into system prompt: "Available tools: [...]"
3. Find/fine-tune a model that outputs tool calls reliably at 1.5B scale
4. Candidates: Qwen2.5-1.5B-Instruct (current), Hermes-3-Llama-3.2-1B (tool-tuned), custom fine-tune
5. Add grammar-constrained sampling in llama.cpp to force valid JSON output
6. Swift parses JSON instead of regex — cleaner, more reliable
