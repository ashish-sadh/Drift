# Backlog — Organized by AI Chat Parity

Items move to `sprint.md` when picked up. Priority: close AI chat gaps first.

---

## AI Chat Gap Closing (from ai-parity.md)

### Friction Reducers
- **Mark supplement taken** — "took my creatine". Match by name, mark today's entry.
- **Edit/delete food** — "remove the rice", "delete last entry". Find + remove from DB.
- **Copy yesterday** — "same as yesterday". Duplicate all yesterday's food_entry rows.
- **Quick-add calories** — "log 500 cal lunch". Parse number + "cal" pattern.
- **Set weight goal** — "set goal to 160". Update WeightGoal model.
- **Body comp entry** — "body fat 18%". Save to body_composition table.
- **Add supplement** — "add vitamin D 2000 IU". Insert into supplement table.
- **Trigger barcode** — "scan barcode". Open camera sheet from chat action.
- **Manual macros** — "log 400cal 30P 50C 20F". Parse inline macro notation.

### Multi-Turn (Gemma 4)
- **Meal planner** — "plan my meals today". Multi-turn: suggest → adjust → confirm → log all.
- **Workout split** — "build me a PPL split". Design across multiple sessions.
- **Cross-domain** — "why am I not losing?". Combine food deficit + weight trend + exercise data.
- **Comparison** — "this week vs last". Side-by-side trend analysis.
- **Coaching** — "am I eating enough for my workouts?". Contextual using real data.
- **Conversation memory** — Pass tool results back to next turn. "You logged 2 eggs (140 cal)."

### Chat Quality
- **Grammar-constrained sampling** — Force valid JSON from SmolLM via llama.cpp grammar.
- **Fine-tune SmolLM** — Collect Gemma 4 tool-calling examples → distill to SmolLM.
- **Gemma 4 few-shot per tool** — 2-3 examples per tool. Measure accuracy vs token cost.
- **Larger context window** — Test 4096 tokens (currently 2048). Memory profiling needed.
- **Streaming quality** — Clean artifacts during streaming, not just after.

## Input Expansion
- **Voice input** — iOS 26 SpeechAnalyzer → on-device speech-to-text → AI chat.
- **Photo food logging** — Core ML food classifier → DB match → chat confirmation.
- **Vision model POC** — llama.cpp vision model for food photo → description → tool call.

## Traditional UI
- **Saved meals** — One-tap re-log of multi-item meals.
- **Inline diary editing** — Tap number to edit directly.
- **Exercise demos** — Static images from free-exercise-db.
- **Post-workout card** — Shareable summary with PRs.
- **iOS widgets** — Calories remaining, recovery score.
- **Haptic feedback** — Subtle haptics on key interactions.
- **Accessibility** — VoiceOver labels.
- **Macro rings** — Apple Fitness-style concentric rings.

## Data & Architecture
- **Export CSV** — Weight, food, workout data.
- **UserDefaults centralization** — 30+ hardcoded keys → enum.
- **Cache HealthKit baselines** — 42 queries per dashboard load → cache 6h.
- **Weekly AI summary notification** — Background task → push.
