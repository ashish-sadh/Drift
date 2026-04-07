# Backlog — Long-Term Ticket Queue

Organized by area. Items move to `sprint.md` when picked up.

---

## AI / Tool Calling

- **Grammar-constrained sampling** — Force valid JSON tool calls via llama.cpp grammar sampling. Eliminates regex parsing errors.
- **Find/fine-tune tool-calling model** — Candidates: Hermes-3-Llama-3.2-1B (tool-tuned), Qwen2.5-1.5B fine-tune on health Q&A. Test: does it reliably output `{"tool": "log_food", "params": {...}}`?
- **Metal GPU acceleration** — b7400 xcframework has the bfloat/half shader fix for A19 Pro. Untested on device. Would 3-5x speed up inference.
- **Vision model POC** — Can llama.cpp load Qwen3-VL-2B + mmproj? Photo → food description → tool call.
- **Larger context window** — Test 4096 tokens (currently 2048). Needs memory profiling on device.
- **On-device embeddings** — MiniLM or similar for semantic food/exercise search instead of keyword matching.
- **Voice input** — iOS 26 SpeechAnalyzer: fully on-device speech-to-text → AI chat.
- **Weekly AI summary notification** — Background task generates insight, delivers as push notification.
- **Multi-turn workout accumulation** — "I did bench" → "also did OHP" → combines into single workout in Swift state.

## Food Logging

- **Photo food logging** — Core ML food classifier (Food101/MobileNetV3) → local DB match → confirm. On-device, no cloud.
- **Saved meals (one-tap re-log)** — Users eat same breakfast ~80% of time. Save multi-item meals.
- **Multi-add / batch select** — Check multiple foods from search results, add all at once.
- **Copy from any past day** — Not just yesterday.
- **Inline editing** — Tap any number in diary to edit directly.
- **Time-of-day search context** — Show coffee/oats in morning, protein at dinner.
- **Quick-add raw calories** — "Just enter 500 cal" button for eating out.

## Exercise

- **Exercise demonstrations** — Options: (1) Static JPGs from free-exercise-db (already bundled, ~2MB), (2) Lottie animations (~12MB for 1470 exercises), (3) YouTube deep links (zero storage). Recommendation: start with option 1.
- **Workout streak tracking** — Current + longest streak alongside consistency chart.
- **Post-workout summary card** — Shareable card with PRs, volume, duration.
- **Swipe gestures on sets** — Swipe to adjust reps +/- 1.
- **Auto rep counting** — Apple Watch accelerometer (Motra-style). ~70% accuracy for isolation moves.

## Data & Health

- **Export data** — CSV export for weight, food, workout data.
- **Epic MyChart lab format** — ~35% of US hospitals. `Component | Value | Flag | Range | Units`.
- **Cerner/Oracle Health format** — ~25% of hospitals.
- **Body fat from smart scales** — Apple Health body fat → Katch-McArdle BMR.
- **VO2 Max** — Fitness level indicator from Apple Watch.

## UI / UX

- **iOS widgets** — Calories remaining, recovery score on home screen.
- **Haptic feedback** — Subtle haptics on key interactions.
- **Accessibility** — Zero VoiceOver labels currently. Needs systematic pass.
- **Macro rings** — Apple Fitness-style concentric rings for P/C/F progress.
- **Time since last meal** — Dashboard shows "Last logged 4h ago".
- **Weekday weight pattern** — "You weigh least on Wednesdays".

## Architecture

- **UserDefaults key centralization** — 30+ hardcoded string keys. Create Constants.swift enum.
- **Cache recovery baselines** — Dashboard fetches 42 HealthKit queries per load. Cache for 6 hours.
- **Schofield equation** — Alternative TDEE base when no profile exists.

## Research

- **Apple Health+ monitoring** — If Apple adds native food tracking, Drift's advantage shifts to algorithm/AI.
- **Passio Nutrition-AI SDK** — On-device Core ML, 2.5M food DB. Token pricing ($2.50/M).
- **Model distillation** — Fine-tune SmolLM2-360M to match Qwen2.5-1.5B quality for faster inference.
