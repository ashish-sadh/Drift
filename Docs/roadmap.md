# Product Roadmap

## Phase 1: Core Health Tracking (DONE)

Local-first health tracking with no cloud dependency.

- Dashboard with deficit/surplus, weight trend, energy balance, sleep, recovery
- Weight tracking: manual + HealthKit sync, EMA trend, goal projection
- Food logging: 1004+ food DB, barcode scanner, OCR, recipes, smart search, Indian foods
- Exercise: 873 exercises, templates, Strong/Hevy import, live workout timer, recovery map
- Sleep & Recovery: Apple Health integration, WHOOP-style scores
- Supplements: daily checklist, consistency tracking
- Body Composition: BodySpec DEXA PDF import, scan comparison
- Glucose: Apple Health + Lingo CSV import, spike detection
- Biomarkers: 65 blood markers, lab report OCR (Quest/Labcorp/WHOOP), encrypted storage
- Cycle Tracking: Apple Health period data, phase timeline, biometric correlation

## Phase 2: AI Assistant — On-Device SLM (CURRENT)

Remove form-filling friction. Every data entry should be doable through natural conversation.

### 2a: Foundation (DONE)
- On-device inference: raw llama.cpp C API, Qwen2.5-1.5B Q4_K_M
- Chat UI with streaming, thinking indicators, suggestion pills
- Chain-of-thought: classify query → fetch relevant data → call LLM
- Action tags: [LOG_FOOD:], [LOG_WEIGHT:], [START_WORKOUT:], [CREATE_WORKOUT:]
- Response cleaner: strips artifacts, preambles, disclaimers, deduplicates
- Quality gate: catches garbage, generic fillers, context regurgitation
- Eval harness: 63 test methods, ~400 individual test cases
- Screen awareness: 11 screens tracked, context adapted per screen
- Conversation history: last 2 exchanges, compact Q/A format

### 2b: Tool-Calling Architecture (IN PROGRESS)
- Each service = a tool with defined schema (name, params, returns)
- Model decides which tool to call (not hardcoded keyword matching)
- Pre-tool hooks: validate inputs, check permissions
- Post-tool hooks: format output, suggest follow-ups
- Structured output: model produces JSON tool calls, Swift executes
- Fine-tune or find pre-tuned tool-calling model for on-device

### 2c: Conversational Flows (IN PROGRESS)
- Food logging via chat: "I had 2 eggs and toast" → opens confirmation
- Weight logging: "I weigh 165" → saves instantly
- Workout builder: "start push day", "I did bench 3x10@135"
- Nutrition lookup: "calories in banana" → instant DB answer
- Multi-turn: "also did OHP" after bench press
- Calorie estimation for unknown foods via LLM

## Phase 3: Input Expansion (NEXT)

- Voice input: iOS SpeechAnalyzer (on-device, iOS 26+)
- Photo food logging: Core ML food classifier → local DB match → confirm
- Exercise demonstrations: Lottie animations or static images from free-exercise-db
- iOS widgets: calories remaining, recovery score
- Apple Watch: workout detection hints
- Smart suggestions from eating patterns ("You usually eat eggs at 8am on weekdays")

## Phase 4: Intelligence (FUTURE)

- Fine-tuned model: health Q&A dataset trained on Qwen2.5-1.5B
- Metal GPU acceleration: b7400 xcframework has the fix, needs device testing
- On-device embeddings: semantic food/exercise search
- Meal planning: "plan my meals for today" based on remaining macros + history
- Training programming: build workout splits from goals + history
- Weekly AI summary push notification
- Export data as CSV
- Apple Health+ integration (if launched)
