# AI Chat Architecture: LLM for Intent, Swift for Execution

## Problem
Current approach hardcodes 30+ keyword checks for intent detection in Swift.
This is brittle, misses natural phrasing, and can't handle workout conversations.

The 1.5B model IS good at: understanding intent, extracting values, classifying queries.
The 1.5B model is BAD at: math, data recall, long reasoning.

## New Architecture

```
User message
    ↓
Rule Engine (exact matches only: "summary", "calories left")
    ↓ (no match)
LLM with structured action prompt
    ↓
LLM returns: [ACTION: params] or natural text
    ↓
Swift parses action → executes (DB write, open UI, fetch data)
    ↓
Show result to user
```

### What LLM Does
- Intent classification: is this food logging, workout, question, or chat?
- Value extraction: "3 sets of bench at 135" → {exercise: bench press, sets: 3, weight: 135}
- Ambiguity resolution: "coffee" → asks "black or with milk?"
- Natural conversation: multi-turn follow-ups

### What Swift Does
- All computation (calories, deficits, trends, projections)
- Database operations (save food, create workout, fetch history)
- Pre-computed insights injected into context ("Assessment: losing at healthy pace")
- UI actions (open sheets, navigate)

## Structured Actions

System prompt teaches the model to emit structured actions:

```
[LOG_FOOD: name amount]           — log food
[LOG_WEIGHT: value unit]          — log weight
[START_WORKOUT: template_name]    — start from existing template
[CREATE_WORKOUT: exercise1 3x15, exercise2 3x10@135] — build workout
[QUERY: topic]                    — for data questions
```

If unclear, the model asks a clarifying question instead of guessing.

## Conversational Workout Builder

### Flow A: Start from template
```
User: "I want to work out"
AI: "You have Push Day, Pull Day, and Legs. Suggestion: try Legs (not done in 4 days)."
User: "let's do legs"
AI: → opens ActiveWorkoutView with Legs template pre-filled
```

### Flow B: Build from conversation
```
User: "I did push ups"
AI: "How many sets and reps?"
User: "3 sets of 15"
AI: "Got it — Push Ups 3x15. Anything else?"
User: "also bench press 3x10 at 135"
AI: "Added Bench Press 3x10 @ 135 lbs. Want to save this as a workout?"
User: "yes"
AI: → creates Workout with 2 exercises, shows summary
```

### Flow C: AI suggests workout
```
User: "what should I train today?"
AI: (checks recent workouts, recovery score, templates)
    "You haven't trained legs in 4 days and recovery is 82/100. 
     Here's a leg day: Squats 4x8, Lunges 3x12, Leg Press 3x10. Start?"
User: "yes"
AI: → opens ActiveWorkoutView with AI-generated template
```

## Implementation

### New Action: CREATE_WORKOUT
```swift
case createWorkout(exercises: [(name: String, sets: Int, reps: Int, weight: Double?)])
```
Parse: `[CREATE_WORKOUT: Push Ups 3x15, Bench Press 3x10@135]`

### AIChatView Changes
- Add `@State private var showingActiveWorkout = false`
- Add `@State private var aiTemplate: WorkoutTemplate?`
- `.sheet` presents ActiveWorkoutView with AI-generated template
- Simplify sendMessage(): remove most keyword checks, let LLM classify

### System Prompt Update
Add structured action instructions + workout actions.
Keep rule engine for exact matches only (summary, calories left, etc.)

### Eval Harness Additions
- "I did push ups 3x15" → should trigger CREATE_WORKOUT
- "start push day" → should trigger START_WORKOUT
- "what should I train?" → should fetch workout context
- "I want to work out" → should list templates

## Files to Modify
- `Drift/Services/AIActionParser.swift` — add CREATE_WORKOUT parsing
- `Drift/Views/AI/AIChatView.swift` — workout sheet, simplify routing
- `Drift/Services/LocalAIService.swift` — system prompt with actions
- `Drift/Services/AIChainOfThought.swift` — workout context
- `DriftTests/AIEvalHarness.swift` — workout intent tests
