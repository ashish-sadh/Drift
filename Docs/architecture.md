# Architecture: Tool-Calling SLM

## Vision

Drift's AI assistant uses a small local model (1.5B parameters) to understand user intent and invoke tools. Inspired by Claude Code CLI: the model is the decision-maker, Swift services are the tools.

**Model does:** Understand intent, pick which tool to call, extract parameters, ask clarifying questions, phrase results naturally.

**Swift does:** All computation, database operations, HealthKit queries, UI actions. The model never does math, never recalls data from memory, never makes decisions that require accuracy.

## How It Works

```
User message
    |
    v
Rule Engine (exact matches: "summary", "calories left")
    |  no match
    v
Context Builder (fetch relevant data for current screen + query)
    |
    v
SLM with tool schemas in prompt
    |
    v
SLM outputs: tool_call OR natural language
    |
    v
Swift executes tool → presents result / opens UI
```

## Tool-Calling Flow (Target)

### Step 1: User message arrives
"I had 2 eggs for breakfast"

### Step 2: Rule engine check
No exact match → continue to SLM.

### Step 3: Build context
```
Screen: food
Calories: 800 eaten, 1800 target, 1000 remaining
Available tools: [log_food, get_nutrition, get_calories_left, ...]
```

### Step 4: SLM responds
```json
{"tool": "log_food", "params": {"name": "eggs", "amount": 2, "meal": "breakfast"}}
```

### Step 5: Swift executes
Opens FoodSearchView with "eggs" pre-filled, 2 servings.

### Step 6: Post-tool hook
After user confirms logging: "Logged 2 eggs (140 cal). You have 860 cal left."

## Current State (v1 — Action Tags)

The model outputs action tags as text that Swift regex-parses:
- `[LOG_FOOD: eggs 2]`
- `[LOG_WEIGHT: 165 lbs]`
- `[START_WORKOUT: Push Day]`
- `[CREATE_WORKOUT: Bench Press 3x10@135, OHP 3x8@95]`

This works but is fragile (regex parsing, model sometimes omits tags, format varies).

## Target State (v2 — Native Tool Calling)

The model outputs structured JSON tool calls. Benefits:
- Grammar-constrained sampling forces valid JSON
- Tool schemas are self-documenting
- No regex parsing — just JSON decode
- Model can chain multiple tools
- Pre/post hooks are clean function calls

### Pre-Tool Hooks
Before executing a tool call:
- Validate parameters (weight in range 20-500, food name non-empty)
- Check permissions (is model loaded? is DB accessible?)
- Inject defaults (meal type from time of day)

### Post-Tool Hooks
After executing:
- Format result for display
- Suggest follow-up ("Want to log something else?")
- Update conversation context

## Tool Registry

See `tools.md` for the complete mapping of services → tools with schemas.

Summary:
- **Food:** search, log, get_nutrition, get_daily_totals, get_calories_left
- **Weight:** log, get_trend, get_goal_progress
- **Workout:** start_template, create_workout, suggest_workout, get_history
- **Sleep:** get_sleep, get_recovery, get_readiness
- **Supplements:** get_status, mark_taken
- **Glucose:** get_readings, detect_spikes
- **Biomarkers:** get_results, get_detail
- **Navigation:** open_tab, open_sheet

## Model Selection

### Current: Qwen2.5-1.5B-Instruct Q4_K_M
- Good at: understanding intent, extracting values, natural conversation
- Bad at: math, data recall, long reasoning, consistent structured output
- Size: 1065MB download

### Candidates for Tool Calling
1. **Qwen2.5-1.5B fine-tune** — Fine-tune on health tool-calling dataset
2. **Hermes-3-Llama-3.2-1B** — Pre-tuned for tool calling, smaller
3. **SmolLM2-360M** — Much faster, needs fine-tuning for quality
4. **Custom distillation** — Train small model to match larger model's tool-calling ability

### Requirements
- Reliably output JSON tool calls (not free-form text)
- Fit in ~1GB on device (Q4 quantized)
- Respond in <3 seconds on iPhone CPU
- Handle 10+ tool schemas in context without confusion

## Eval Harness

63 test methods, ~400 individual test cases covering:
- Food intent detection (23 positive, 12 false positive)
- Weight intent detection (6 positive, 4 false positive)
- Workout intent routing (7 queries)
- Chain-of-thought routing accuracy (25 queries across all domains)
- Action tag parsing (CREATE_WORKOUT, START_WORKOUT, LOG_FOOD, LOG_WEIGHT)
- Response quality (markdown stripping, preamble removal, dedup, truncation)
- Keyword precision (false positive prevention for broad terms)
- Edge cases (empty input, special chars, long input, mixed intents)

Target: 200+ test methods. See `Docs/testing.md` for details.

## Key Files

| File | Role |
|------|------|
| `Services/LocalAIService.swift` | Orchestrator — model management, system prompt, inference |
| `Services/LlamaCppBackend.swift` | Raw llama.cpp C API — load, tokenize, generate |
| `Services/AIChainOfThought.swift` | Query classification, context fetching, LLM execution |
| `Services/AIContextBuilder.swift` | Build per-screen context with action hints |
| `Services/AIActionParser.swift` | Parse action tags from LLM response |
| `Services/AIActionExecutor.swift` | Food/weight intent parsing, food DB search |
| `Services/AIRuleEngine.swift` | Instant answers without LLM |
| `Services/AIResponseCleaner.swift` | Strip artifacts, quality gate |
| `Views/AI/AIChatView.swift` | Chat UI, message routing, action execution |
| `DriftTests/AIEvalHarness.swift` | 63 gold-standard eval tests |
