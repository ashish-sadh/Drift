# Architecture: AI-First Health Tracker

## Philosophy

AI chat is the primary interface — the showstopper. Every data entry should be doable through conversation. Traditional UI exists for visual analytics and as a fallback for users who prefer tapping.

**Dual-model approach:**
- **SmolLM (360M)** — Reliable harness. Hardcoded keyword/rule engine does heavy lifting. Fast, works on all devices.
- **Gemma 4 (2B)** — Intelligence layer. LLM decides tools, handles ambiguity, enables multi-turn. Makes the app smart.

**Model does:** Understand intent, pick tools, extract parameters, hold multi-turn context (Gemma 4), phrase results naturally.

**Swift does:** All computation, database, HealthKit, UI. Model never does math or recalls data.

## Flow

```
User message
    |
    v
Hardcoded Handlers (emoji, greetings, rule engine, food/weight/meal/exercise parsers)
    |  no match
    v
Model tier check
    |
    +-- SmolLM ---------> 6 screen-filtered tools, 800-token context
    |                      Keyword chain-of-thought → single LLM call
    |
    +-- Gemma 4 --------> ALL 10+ tools, 1200-token context
    |                      LLM decides tool, multi-turn capable
    |
    v
LLM outputs: {"tool":"name","params":{}} OR natural language
    |
    v
Swift executes tool → result / opens UI
```

## AI Chat Feature Parity

See `Docs/ai-parity.md` for the living gap log. Goal: close all P0/P1 gaps.

Currently available from chat: food logging (single/multi/meal/gram), weight, exercise (templates/smart/log), nutrition lookup, summaries, sleep/recovery, supplements, glucose, biomarkers, body comp.

UI-only gaps being closed: mark supplement taken, edit/delete entries, copy yesterday, quick-add calories, goal setting, barcode trigger, multi-turn meal planning (Gemma 4).

## Dual-Path Routing

### SmolLM Path (Small Model)
- Hardcoded handlers catch 80%+ of queries
- 6 tools per screen (screen-relevant first)
- Chain-of-thought: keyword → data fetch → single LLM call
- fullDayContext fallback when no keywords match

### Gemma 4 Path (Large Model)
- Essential hardcoded handlers still run (fast path preserved)
- Food question routing bypassed — LLM uses food_info tool
- All 10+ tools visible regardless of screen
- Richer system prompt, more examples, cross-domain awareness
- Multi-turn: meal planning, workout building, analysis

### Screen Bias — Solved
"How am I doing?" gives same quality answer regardless of which tab. Six sources of bias fixed: tool filtering, context fallback, suggestion pills, food question routing, chain-of-thought, system prompt.

## Models

| Model | Size | Devices | Speed | Role |
|-------|------|---------|-------|------|
| SmolLM2-360M Q8 | 368MB | 6GB (iPhone 15) | <2s CPU | Reliable harness |
| Gemma 4 E2B Q4_K_M | 2900MB | 8GB+ (iPhone 16 Pro) | ~5-8s GPU | Intelligence |

Auto-detect: `ramGB >= 6.5 → Gemma 4, >= 5.0 → SmolLM`.
GPU: Metal, all 36 layers offloaded on A19 Pro (~3GB VRAM).
Auto-unload after 60s idle, reload on return with "Preparing AI assistant..." indicator.

## Tool Registry

10 consolidated tools (JSON tool-calling):

| Tool | What it does |
|------|-------------|
| `log_food` | Log food user ate |
| `food_info` | Nutrition facts, calories left, suggestions |
| `explain_calories` | TDEE breakdown |
| `log_weight` | Log body weight (with confirmation) |
| `weight_info` | Trend, goal progress, body comp |
| `start_workout` | Start template or smart session |
| `exercise_info` | Workout suggestion, overload, streak |
| `sleep_recovery` | Sleep, HRV, recovery, readiness |
| `supplements` | Supplement status |
| `glucose` | Readings, spike detection |
| `biomarkers` | Lab results |

Gemma 4 sees all. SmolLM sees 6, screen-filtered.

## Key Files

| File | Role |
|------|------|
| `Services/LocalAIService.swift` | Orchestrator — dual system prompts, model management |
| `Services/LlamaCppBackend.swift` | llama.cpp C API — Gemma + ChatML templates |
| `Services/ToolSchema.swift` | Tool definitions, registry, JSON parsing, execution |
| `Services/ToolRegistration.swift` | 10+ tool registrations with handlers |
| `Services/AIChainOfThought.swift` | Query classification, context fetching |
| `Services/AIContextBuilder.swift` | Per-screen + fullDay context |
| `Services/AIActionExecutor.swift` | Food/weight intent parsing |
| `Services/ExerciseService.swift` | Smart session builder with reasoning |
| `Views/AI/AIChatView.swift` | Chat UI, dual-path routing, tool execution |
| `Docs/ai-parity.md` | Feature parity gap log |
