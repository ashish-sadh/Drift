# Sprint Board

## In Progress

_(pick from Ready)_

## Ready

### Next Up
- [ ] **Saved meals (one-tap re-log)** — Save multi-item meals as a group. One tap to re-log "My usual breakfast". Most-requested feature.
- [ ] **Time-of-day food search boost** — Coffee/oats ranked higher in morning, protein at dinner. Boost in search ranking, not separate UI.
- [ ] **Workout streak tracking** — Show current + longest streak on Exercise tab alongside consistency chart.
- [ ] **Eval harness to 100+** — Add more tool-call format tests, multi-turn conversation tests, ambiguous query tests.
- [ ] **Quick-add raw calories** — "Just enter 500 cal" button in Food tab for eating out.

### Blocked (needs device/model)
- [ ] **MQ-1: Test tool-calling models** — Try Hermes-3-Llama-3.2-1B. Needs device + model download.
- [ ] **MQ-2: Grammar-constrained sampling** — llama.cpp grammar for JSON. Needs device testing.
- [ ] **Metal GPU acceleration** — b7400 xcframework ready, needs device test on A19 Pro.

### Previous Sprint (remaining)

### Infrastructure
- [x] **TC-1: ToolSchema + ToolRegistry** — b24799d
- [x] **TC-2: SpellCorrectService** — da6e4c8
- [x] **TC-3: JSON tool-call parser** — da6e4c8+

### Services (one per domain — UI and AI share these)
- [x] **SVC-1: FoodService** — c8cc327+
- [x] **SVC-2: WeightService** — bc80c11+
- [x] **SVC-3: ExerciseService** — 7894260+
- [x] **SVC-4: SleepRecoveryService** — 17adc16+
- [x] **SVC-5: SupplementService** — 17adc16+
- [x] **SVC-6: GlucoseService** — 17adc16+
- [x] **SVC-7: BiomarkerService** — 17adc16+

### Wiring
- [x] **WIRE-1: Register all tools** — d72c698+
- [x] **WIRE-2: Update system prompt** — 6042fee+
- [x] **WIRE-3: Replace AIChatView routing** — cf9ce57+
- [x] **WIRE-4: Block health questions** — Done in WIRE-2 (system prompt)
- [x] **WIRE-5: Smart workout when no template** — e7eacfb+

### Quality
- [x] **QA-1: Eval tests for tool-call format** — af5f810+
- [x] **QA-2: Service unit tests** — db7fdc5+
- [x] **QA-3: Progressive overload tests** — db7fdc5+
- [x] **QA-4: Smart session builder tests** — db7fdc5+

### Bugs
- [ ] **BUG: Total calories error** — Needs reproduction steps from user. Calories math looks correct in FoodService/AIRuleEngine/AIContextBuilder.
- [x] **BUG: Flaky workout session tests** — 7564b2f+
- [x] **FEAT-001: Calorie estimation** — DB lookup instant, LLM fallback works via chain-of-thought

## Done

- [x] BUG-001: Calories left wrong number
- [x] Action tags in system prompt + all screens
- [x] Removed hardcoded handlers → LLM
- [x] Direct template start from chat
- [x] Food parser: beverages, snacks, cooking verbs
- [x] 41 self-improvement cycles, 63 eval tests, build 84
- [x] Docs rewrite: clean structure, tool-calling vision
- [x] Simplified program.md (220→76 lines)
