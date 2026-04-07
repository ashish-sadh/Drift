# Tool Registry — AI Tool-Calling Surface

AI chat is the primary interface. Tools are how chat controls the app.
Each service exposes tools the model can invoke via JSON. See `Docs/ai-parity.md` for gap tracking.

The model's job: understand intent, pick tool, extract parameters.
Swift's job: execute tool, compute results, present UI.

## Tool Call Format

```json
{"tool": "log_food", "params": {"name": "eggs", "amount": "2"}}
```

Model outputs JSON. Swift parses via `parseToolCallJSON()`, executes via `ToolRegistry.shared.execute()`.

## Dual-Model Tool Filtering

**Gemma 4 (large):** Sees ALL 10 tools + `Current screen: X` hint. LLM decides which tool to call.

**SmolLM (small):** Sees 6 tools, screen-relevant first. Screen drives tool selection more heavily.

---

## Food Tools (3)

**Source:** `ToolRegistration.swift`, `FoodService.swift`, `AIActionExecutor.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `log_food` | name: String, amount: Number? | — | Opens FoodSearchView sheet |
| `food_info` | query: String? | Calories left, macros, balance, meal suggestions, top protein | Inline response |
| `explain_calories` | — | TDEE calculation breakdown | Inline response |

**`food_info`** is a smart router: tries nutrition lookup first, then falls back to daily totals + macro balance + meal suggestions + high-protein foods.

---

## Weight Tools (2)

**Source:** `ToolRegistration.swift`, `WeightServiceAPI.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `log_weight` | value: Number, unit: String? | Confirmation prompt | Inline (asks "Say yes to confirm") |
| `weight_info` | — | Trend, weekly rate, goal progress, body comp | Inline response |

**`log_weight`** has a validation hook: rejects values outside 20-500 range.

---

## Exercise Tools (2)

**Source:** `ToolRegistration.swift`, `ExerciseService.swift`, `WorkoutService.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `start_workout` | name: String | Template exercises or smart session | Opens ActiveWorkoutView or inline |
| `exercise_info` | exercise: String? | Progressive overload, last weight, suggestion, streak | Inline response |

**`start_workout`** tries template match first, then builds smart session via `ExerciseService.buildSmartSession()` (muscle group rotation, user history, last weights).

---

## Health Tools (4)

**Source:** `ToolRegistration.swift`, `SleepRecoveryService.swift`, `SupplementService.swift`, `GlucoseService.swift`, `BiomarkerService.swift`

| Tool | Parameters | Returns | UI Action |
|------|-----------|---------|-----------|
| `sleep_recovery` | — | Sleep hours/quality, HRV, RHR, recovery %, readiness | Inline response |
| `supplements` | — | Taken/total, remaining names | Inline response |
| `glucose` | — | Average, range, in-zone %, spikes | Inline response |
| `biomarkers` | — | Out-of-range markers with values and ranges | Inline response |

---

## Rule Engine (Instant — No Model Needed)

These bypass the model entirely. Both SmolLM and Gemma 4 paths check these first.

| Pattern | Handler |
|---------|---------|
| "daily summary" | `AIRuleEngine.dailySummary()` |
| "how's my protein" | Computed from daily nutrition + goal targets |
| "what did I eat today" | `AIContextBuilder.foodContext()` |
| "yesterday" | `AIRuleEngine.yesterdaySummary()` |
| "weekly summary" | `AIRuleEngine.weeklySummary()` |
| "calories left" | `AIRuleEngine.caloriesLeft()` |
| "supplements" | `AIRuleEngine.supplementStatus()` |
| "calories in [food]" | DB lookup → instant nutrition |

---

## Hardcoded Intent Parsers (No Model Needed)

| Intent | Parser | Example |
|--------|--------|---------|
| Food logging | `AIActionExecutor.parseFoodIntent()` | "log 2 eggs", "ate chicken" |
| Multi-food | `AIActionExecutor.parseMultiFoodIntent()` | "log chicken and rice" |
| Weight logging | `AIActionExecutor.parseWeightIntent()` | "I weigh 165" |
| Template start | Direct string matching | "start push day" |
| Smart workout | Direct string matching | "start smart workout" |

---

## System Prompt (Model-Aware)

**Gemma 4:** Richer prompt with cross-domain awareness, all tools, examples for each tool, "Current screen: X" hint.

**SmolLM:** Concise prompt — LOGGING/QUESTION/CHAT framework, 6 examples, 6 tools max.

Both enforce: "Never give health advice. Never invent numbers."
