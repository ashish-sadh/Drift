# Product Roadmap

## Vision
AI-first health tracker. AI chat is the primary interface — every data entry doable through conversation. Traditional UI for visual analytics and fallback.

## Phase 1: Core Health Tracking (DONE)
Built the foundation: weight, food, exercise, sleep, supplements, body comp, glucose, biomarkers, cycle tracking. All local, no cloud.

## Phase 2: AI Chat Foundation (DONE)
- On-device inference: llama.cpp, Metal GPU
- Dual-model: SmolLM (reliable harness) + Gemma 4 (intelligence)
- 10 JSON tools, screen bias removed, chain-of-thought
- Food/weight/exercise/health logging and queries from chat
- Eval harness: 212+ tests + 100-query LLM eval

## Phase 3: AI Chat Parity (CURRENT)
Close the gap between AI chat and UI. See `Docs/ai-parity.md`.

### 3a: Friction Reducers (IN PROGRESS)
- Mark supplement taken via chat
- Edit/delete food entries via chat
- Copy yesterday's food
- Quick-add raw calories
- Set/update weight goal
- Trigger barcode scan from chat

### 3b: Multi-Turn Intelligence — Gemma 4 (IN PROGRESS)
- Meal planning dialogue ("plan my meals for today")
- Workout split builder ("build me a PPL")
- Cross-domain analysis ("why am I not losing weight?")
- Weekly comparison with trend data
- Coaching conversations using real user data

### 3c: Chat Quality (CONTINUOUS)
- Prompt optimization per tool
- Eval expansion (300+ tests)
- Response quality scoring
- Multi-turn context management
- Conversation memory (tool results in history)

## Phase 4: Input Expansion (NEXT)
- Voice input: iOS 26 SpeechAnalyzer (on-device) → AI chat
- Photo food logging: Core ML classifier → chat confirmation
- iOS widgets: calories remaining, recovery score
- Apple Watch: workout detection hints

## Phase 5: Deep Intelligence (FUTURE)
- Fine-tuned SmolLM on Drift tool-calling dataset
- Grammar-constrained sampling for reliable JSON
- On-device embeddings: semantic food/exercise search
- Training programming across weeks
- Weekly AI summary push notification
