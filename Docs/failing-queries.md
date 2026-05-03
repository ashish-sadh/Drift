# Failing Queries — AI Chat Fix Backlog

Real queries that don't work well. Fix systematically, then move to Fixed.

**Rules for fixing:**
- Fix the CATEGORY, not just the exact query
- Tier 0 (instant rules/parsers) is best — no latency
- Tier 1 (normalizer) handles messy variants — ~3s latency
- Add eval harness tests for the query AND 3+ variants
- Test both model paths before marking fixed

## Failing

### Supplement Insight Routing
- **"did I miss any magnesium doses"** — Routes to `mark_supplement` instead of `supplement_insight`. Root cause: `classifyIntent` includes `"did"` in `logVerbs` (ToolRanker.swift:229), so the intent is classified as `.log`, giving `mark_supplement` a +2 logBoost. `supplement_insight` has a `"missed"` trigger but not `"miss"` (word form), and its `-1` logBoost on a `.log` intent drops it below zero. Fix tier: 0 — add `"did i miss"` as a multi-word trigger for `supplement_insight` (score ≥ 4.5 to overcome logBoost gap). Variants: "have I logged zinc this week" (same issue — "have" not in logVerbs so actually routes OK), "did I forget to take magnesium".

### Medication History Queries
- **"when did I last take my ozempic shot"** — CATEGORY: medication history / last-dose lookup. `log_medication` exists for logging but there is no query/history tool. Query routes to `log_medication` (high score due to "ozempic" trigger), which logs another dose instead of returning last-dose time. `MedicationService.lastDoseTime(for:)` has the data but nothing surfaces it in the AI pipeline. Fix tier: 2 (add `medication_info` tool backed by `MedicationService.lastDoseTime`/`weekMedications`). Variants: "how many times did I take metformin this week", "what time did I inject semaglutide", "am I consistent with my GLP-1 shots".

## Fixed

### Cycle 8666–8789
- [x] **"how much fiber did I eat today"** — `food_info` handler now checks `query.contains("fiber")` and returns `n.fiberG` from the daily nutrition summary, with a 25g default target. `02b6c27`. Variants: "how much sodium today", "what's my sugar intake".
- [x] **"am I hitting my protein goal"** — `food_info` handler compares today's protein against `goal.proteinGoal` (user-set) or macro-breakdown target, showing a % progress line with suggestions for top protein foods. `31be180` (#284), `eeab10b` (#441). Variants: "did I hit my fat goal today", "how far off am I from my protein target".

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
