# LLM Tool-Calling Eval Results

**Model:** Qwen2.5-1.5B-Instruct Q4_K_M
**Date:** 2026-04-06
**Prompt:** 6 tools max, LOGGING/QUESTION/CHAT framework, 7 few-shot examples

## Results

| Category | Score | % | Notes |
|----------|-------|---|-------|
| Food Logging (20) | 20/20 | **100%** | Perfect. "I had X" always calls log_food. |
| Food Questions (15) | 6/15 | **40%** | Confuses questions with logging. "What should I eat" → log_food. |
| Exercise Coach (23) | 3/23 | **13%** | Responds naturally, almost never calls exercise tools. |
| Weight (15) | 3/15 | **20%** | Responds naturally. Even "I weigh 165" gets natural response. |

## Key Findings

1. **Food logging is the only reliable tool call.** 100% accuracy on "I had/ate/log [food]" → log_food.
2. **Questions trigger no tool call.** The model prefers to answer naturally rather than call an info tool.
3. **The word "eat" confuses LOG vs QUESTION.** "What should I eat" → log_food (wrong).
4. **Exercise tools are almost never called.** Model just gives advice text.
5. **Weight logging also fails.** "I weigh 165" → natural response instead of log_weight.

## Architecture Decision

Based on data: **hybrid approach**

- **LLM handles:** Food logging (100%), natural conversation, rephrasing data
- **Swift harness handles:** Weight logging (regex), exercise routing (keywords), all data queries (call tool → pass result to LLM)
- **Rule engine handles:** Exact matches (summary, calories left, supplements)

The 1.5B model is a **food logging specialist + conversational rephraser**, not a general tool-caller. The harness must compensate.

## Next Steps

1. Keep food logging via LLM tool call (it works)
2. Keep Swift intent parsing for weight, exercise, supplements
3. For questions: Swift calls the right service tool, returns data, LLM phrases it
4. Improve food question routing: add "what should I eat" → suggest_meal in Swift
5. Test with Hermes-3 or other tool-tuned models for comparison
