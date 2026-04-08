# Sprint Board

Priority: AI chat quality — natural conversation, better tool calling, insightful responses.

## In Progress

_(pick from Ready)_

## Ready

### P0: Chat Response Quality
- [x] **Presentation prompt tuning** — Added time-of-day context, example response, "warm and brief" tone. Tuned for Gemma 4 2B.
- [x] **Include user query in presentation context** — bestQuery (normalizer output) now flows through Phase 3 tool execution + LLM presentation.
- [x] **Richer tool data for presentation** — food_info has progress status indicator, weight_info has total change + weekly trend.
- [x] **SmolLM fallback templates** — addInsightPrefix() adds "Looking good —" / "Heads up —" based on data content.

### P1: Tool Calling Accuracy
- [ ] **LLM eval on tool routing** — Run 40+ queries through Gemma 4 tool-calling path. Measure: does it pick the right tool? Does it extract the right params? Track accuracy and fix misroutes.
- [ ] **Normalizer → tool pick chain** — After normalizer rewrites, does tryRulePick find the right tool? Test messy variants: "hows my protien", "wat shud i eat", "cals left".
- [ ] **Tool param extraction quality** — ToolRanker.extractParamsForTool is basic regex. Test: does food_info get the right query param? Does sleep_recovery get "week" when user says "sleep this week"?
- [ ] **Anti-keyword tuning** — "how much does chicken weigh" should NOT trigger log_weight. "I want to reduce fat" should NOT trigger log_food. Audit anti-keywords across all 19 tool profiles.

### P2: Latency & Streaming
- [ ] **Measure end-to-end latency** — Time each pipeline stage for 10 common queries. Where is time spent? Normalizer? Tool execution? LLM presentation? Find the bottleneck.
- [ ] **Progressive multi-item disclosure** — For "rice and dal", show each found item as it's discovered, don't batch.
- [ ] **Normalizer cache** — If the same query was normalized before (same session), skip the 3s normalizer call.

### P3: Conversation Feel
- [ ] **Vary response openings** — LLM tends to start every response the same way. Add variety hints in the presentation prompt (time of day, performance vs goal).
- [ ] **Multi-turn meal planning** — "plan my meals for today" → iterative macro-aware suggestions. Gemma 4 only.
- [ ] **Conversation memory** — Pass previous tool results to next turn so LLM can reference them ("you mentioned protein was low earlier").

## Done

### This sprint
- [x] **LLM presentation layer** — Info queries route through tool execution → Gemma 4 streaming presentation instead of data dumps
- [x] **Parallel tool execution** — TaskGroup-based parallel info tool execution
- [x] **ToolRanker keyword expansion** — food_info, weight_info, sleep_recovery enriched with summary/yesterday/weekly/suggest/trend keywords
- [x] **Enriched weight_info** — Total change + weekly trend data for LLM presentation
- [x] **Food_info context routing** — yesterday/weekly/suggest queries get specific data paths
- [x] **Sleep_recovery period param** — "sleep trend" routes with period=week

### Previous sprint
- [x] Multi-turn via normalizer context + history detection
- [x] Normalizer accuracy tuning (330+ eval scenarios)
- [x] Multi-turn pronoun resolution
- [x] Eval harness 370+ scenarios
- [x] Multi-item meal continuation
- [x] Gram/unit parsing (200ml, half cup, ranges)
- [x] Food search ranking (singular-first + length tiebreaker)
- [x] All P0/P1 AI parity gaps closed
- [x] All failing queries fixed (except meal planning)
- [x] Cross-domain analysis, weekly comparison, calorie estimation
- [x] Delete/undo food, weight progress, TDEE/BMR, barcode scan from chat
