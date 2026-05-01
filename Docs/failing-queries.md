# Failing Queries — AI Chat Fix Backlog

Real queries that don't work well. Fix systematically, then move to Fixed.

**Rules for fixing:**
- Fix the CATEGORY, not just the exact query
- Tier 0 (instant rules/parsers) is best — no latency
- Tier 1 (normalizer) handles messy variants — ~3s latency
- Add eval harness tests for the query AND 3+ variants
- Test both model paths before marking fixed

## Failing

### Micronutrient Queries
- **"how much fiber did I eat today"** — CATEGORY: micronutrient queries (fiber, sodium, sugar, vitamins). `food_info` handler exposes cal/protein/carbs/fat per entry but fiber_g is only used in the nutrition estimation flow (Gemma 4 food lookup), not stored per logged entry. Query routes to `food_info(query:"fiber today")` but the handler returns a daily macro summary that omits fiber — user gets a non-answer. Fix tier: 2 (store fiber_g on FoodEntry, surface in `food_info` daily summary). Variants: "did I get enough fiber this week", "how much sodium today", "what's my sugar intake".

### Macro Goal Progress Queries
- **"am I hitting my protein goal"** — CATEGORY: macro goal tracking / goal-vs-actual comparison. There is no protein goal in the data model (`WeightGoal` stores only target weight). The system prompt routes protein queries to `food_info`, which shows today's protein intake, but there is no goal to compare against — so the response is just "you had X g protein" with no benchmark. User question goes half-answered. Fix tier: 3 (add macro targets to user prefs; expose them in `food_info` so it can compare intake vs. goal). Variants: "did I hit my fat goal today", "am I on track for carbs", "how far off am I from my protein target".

### Supplement Insight Routing
- **"did I miss any magnesium doses"** — Routes to `mark_supplement` instead of `supplement_insight`. Query contains "magnesium" (supplement name) and "miss any doses" (review/history intent), but ToolRanker picks the logging tool. Fix tier: 0 (add dose-history patterns to supplement_insight ranker). Variants: "did I take my vitamins today", "have I logged zinc this week".

## Fixed

### Cycle 8581 (builds 196–197)
- [x] **"of" connector in unit parsing** — "100g of oats", "200ml of milk", "8oz of chicken" returned food="of oats/of milk". Skip leading "of" after extracting unit. `d265f85` (#497)
- [x] **Decimal Nx multiplier phrases** — "1.5x rice", "0.5x oats", "2.5x whey" now parsed as serving multipliers in extractAmount. `14b6bb9` (#559)
- [x] **Food-aware cup/tbsp/tsp conversion** — "1.5 cups of rice" → 277.5g (185g/cup), "half cup oats" → 40g (80g/cup). Uses RawIngredient.gramsPerCup density table instead of flat 240g. `d034ab5` (#552)

### Earlier cycles
- [x] "No, I had the other chicken instead" — `IntentClassifier.deleteEditTriggers` + recent-entries context on correction turns. Variants: "Actually I had salmon, not chicken".
- [x] "set my calorie goal to 2000" — StaticOverrides matches calorie/caloric/cal goal/target/limit/budget → `WeightGoal.calorieTargetOverride`. Variants: "calorie budget 2000", "my calorie limit is 1500".
- [x] "how many calories did I eat last Tuesday" — `AIRuleEngine.weekdayDateString` parses last/past/on weekday refs → `historicalDaySummary`. Variants: "what did I eat on Monday", "calories last Saturday".
- [x] "I had 2 to 3 bananas" — extractAmount handles "X to Y" ranges (takes higher).
- [x] "I ate three biryani" — extractAmount word→number already handled.
- [x] "set my goal to one sixty" — resolveWordNumbers() converts "one sixty"→160.
- [x] "I did yoga for like half an hour" — trailing duration parser handles "for like X".
- [x] Second meal item after recipe builder — meal continuation handler prepends to pendingRecipeItems.
- [x] "what about protein?" after food chat — topic continuation in StaticOverrides.
- [x] "and yesterday?" after today's data — StaticOverrides topic continuation.
- [x] "plan my meals for today" — planningMeals state phase with suggestions/pagination.
- [x] "Tell me my workout history" — exercise_info shows recent workouts from HealthKit.
- [x] "How is my sleep quality last week" — sleep_recovery accepts period param, 7-day average.
- [x] "Daily summary" — dailySummary() was using .last on DESC array; changed to .first.
- [x] "I want to reduce fat" — StaticOverrides catches diet/fitness advice, personalized macro advice.
- [x] "I want to estimate calories for samosa" — StaticOverrides nutrition estimation handler.
- [x] "I had couple of bananas" — singular-first search + LENGTH tiebreaker.
- [x] "100 gram Rice and 2 cups of daal" → Kirkland Chicken — pendingMealName before food parsers.
- [x] "suggest me workout" — Hardcoded handler, 12 phrasings.
- [x] "I did yoga today" — Activity parser with duration.
- [x] "how many workouts this week" — Rule engine + streak.
- [x] "what's healthy for dinner" — suggestMeal + macros.
- [x] "I had a cheat meal" — pendingMealName flow.
- [x] "how much sugar today" — Shows carbs + note.
- [x] "am I making progress" — fullDayContext.
- [x] "should I eat more today" — Cross-domain.
- [x] "I feel tired" — Cross-domain sleep+food.
- [x] "how is my protein" — StaticOverride + food_info tool with query:"protein".
- [x] "body fat is 3" — Validation fixed (>3 → >=3).
- [x] "log exercise" → "Logging food..." — Added exercise trigger before Gemma pipeline.
- [x] "Unknown tool: sleep_recovery()" — parseToolCallJSON strips `()` from tool names.
