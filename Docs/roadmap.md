# Drift Product Roadmap

## Vision

Two equally important pillars:
1. **AI chat that handles 90% of interactions** — type what you did, AI does the rest
2. **Beautiful, fast, opinionated health tracking UI** — charts, diary, insights that are world-class

Neither is secondary. Every improvement should advance one or both pillars.

Privacy-first: everything on-device, no cloud, no accounts. This is non-negotiable.

## Current Phase: Polish & Depth (Phase 3c)

What's working: core tracking across all domains, AI chat foundation, 19 tools, dual-model pipeline, 743+ tests.

What's not: UI feels rough and unpolished compared to competitors, AI chat drops context in multi-turn, test coverage has gaps, food DB is incomplete, exercise has no visual aids.

---

## AI Chat

### Now
- **State machine refactor** — Replace scattered pendingMealName/pendingWorkout state vars with a proper conversation state machine (idle → classifying → executing → confirming → logging). Clear transitions, no dangling state.
- **Prompt consolidation** — Single source of truth for tool schemas, examples, context injection. Measure and compress token count.
- **Multi-turn reliability** — Eliminate context loss bugs. Test: 3-turn meal logging, 3-turn workout building, topic switching mid-conversation.
- **Natural freeform logging** — "log for breakfast 2 eggs and spinach and bread and coffee with 2% milk with protein powder and creatine" → AI parses everything, asks clarifying questions, does macro calculations, logs it.

### Next
- Meal planning dialogue — "plan my meals today" → iterative suggestions based on remaining macros + history
- Workout split builder — "build me a PPL split" → multi-turn designing
- Voice input (iOS 26 SpeechAnalyzer → on-device speech-to-text → chat)
- Photo food logging (Core ML classifier → DB match → chat confirmation)

### Later
- Fine-tuned SmolLM on Drift tool-calling dataset
- Grammar-constrained sampling for reliable JSON
- Conversation memory across sessions
- On-device embeddings for semantic food/exercise search

## UI & Design

### Now
- **Theme overhaul** — Coherent visual language across ALL views. Colors, spacing, typography, card styles. Pick a direction and commit app-wide. Not tied to dark-only.
- **Dashboard** — Scannable at a glance. Clear progress indicators, better hierarchy, less clutter.
- **Chat UI** — Message bubbles, animated typing indicators, tool execution feedback, streaming UX.
- **Food diary** — Faster logging flow, better meal grouping, clearer macro display.

### Next
- Macro rings (Apple Fitness-style concentric rings)
- iOS widgets (calories remaining, recovery score)
- Saved meals (one-tap re-log of multi-item meals)
- Inline diary editing (tap number to edit directly)

### Later
- Apple Watch companion
- Accessibility audit (VoiceOver, Dynamic Type throughout)

## Weight

### Now
- **LB/KG unit switching** — Currently broken (P0 bug). Toggle has no effect on displayed values.
- Trend visualization improvements — clearer charts, milestone markers

### Next
- Body recomposition tracking (muscle vs fat trends over time)
- Goal milestones and celebrations
- Predictive "you'll reach goal by" based on trend

## Food

### Now
- **DB enrichment** — Correct serving sizes, add missing foods. Indian, regional, restaurant items. Cross-reference with USDA.
- **Search quality** — Better aliases, spelling corrections, partial matches. "paneer" finds all paneer dishes.
- Ingredient persistence for recipe rebuilding

### Next
- USDA API integration for verified nutrition data
- Restaurant menu items (Chipotle bowl builder, etc.)
- Barcode coverage expansion

### Benchmark: MyFitnessPal
- MFP has 14M+ foods. We have ~1000. Close the gap on common foods first.
- MFP logging is ~3 taps. Match or beat this with AI chat.

## Exercise

### Now
- Workout history polish
- Progressive overload tracking improvements

### Next
- **Exercise presentation** — Images, muscle group icons, exercise instructions. Match Boostcamp quality.
- Training programming across weeks
- Exercise alternatives/substitutions

### Benchmark: Boostcamp
- Boostcamp has exercise videos/GIFs, muscle group diagrams, detailed instructions per exercise.
- We have 873 exercises but text-only. This is a major visual gap.

### Benchmark: Strong
- Strong's workout logging UX is clean and fast. Match their set/rep entry speed.

## Biomarkers & Glucose

### Now
- Trend analysis improvements
- Better glucose spike detection and pattern recognition

### Next
- Correlation with food/exercise (cross-domain insights: "your glucose spikes after rice")
- Lab report comparison over time

### Benchmark: Whoop
- Whoop's recovery/strain insights are excellent. Match their insight quality for biomarker trends.

## Quality & Testing

### Now
- Coverage targets: **80%** logic, **50%** services — find and fix gaps
- AI eval harness: every tool gets 10+ eval queries
- Integration tests for multi-step flows (parse → resolve → log → confirm)
- Bug hunting: find bugs before users report them

### Next
- UI snapshot tests
- Performance benchmarks (chat response time, build time)

---

## Competitive Benchmarks Summary

| Domain | Benchmark App | What to match |
|--------|--------------|---------------|
| Food logging | MyFitnessPal | DB breadth, logging speed |
| Exercise | Boostcamp | Visual exercise presentation (images, videos, instructions) |
| Workout logging | Strong | Clean, fast set/rep entry UX |
| Macro coaching | MacroFactor | Adaptive calorie/macro targets |
| Biomarkers | Whoop | Insight quality, recovery analysis |
| AI chat | None (unique advantage) | Push further — no competitor has this |

---

## Phase History

- **Phase 1: Core Health Tracking** (DONE) — Weight, food, exercise, sleep, supplements, body comp, glucose, biomarkers, cycle tracking.
- **Phase 2: AI Chat Foundation** (DONE) — On-device inference, dual-model, 19 tools, eval harness.
- **Phase 3a: Tiered Pipeline** (DONE) — ToolRanker, AIToolAgent, StaticOverrides, LLM normalizer.
- **Phase 3b: Parity Gaps** (DONE) — All high-impact chat features implemented.
- **Phase 3c: Polish & Depth** (CURRENT) — UI overhaul, AI reliability, test coverage, food DB.
- **Phase 4: Input Expansion** (NEXT) — Voice, photo, widgets, Apple Watch.
- **Phase 5: Deep Intelligence** (FUTURE) — Fine-tuned models, conversation memory, training programming.
