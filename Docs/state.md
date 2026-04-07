# Drift — Current State (April 2026)

## Overview
Local-first iOS health & fitness tracking app with on-device AI assistant. No cloud, no accounts. Published on TestFlight as "Drift Fitness" (bundle: com.drift.health).

## Numbers
- **Version:** 0.1.0, Build 84
- **Tests:** 729 (14 test files)
- **AI Eval Tests:** 63 methods, ~400 individual test cases
- **Foods:** 1004+ (curated DB with Indian, Mexican, global foods)
- **Exercises:** 873 (free-exercise-db, public domain)
- **Biomarkers:** 65 across 9 categories
- **Supplements:** 18 default + custom

## Tech Stack
- SwiftUI + MVVM, iOS 17+, Swift 6
- GRDB.swift for SQLite (only external SPM dependency)
- llama.cpp via embedded xcframework (built from source, b7400)
- Swift Charts, HealthKit, PDFKit, Vision (OCR), AVFoundation (barcode), CryptoKit
- XcodeGen for project generation

## AI System
- **Model:** Qwen2.5-1.5B-Instruct Q4_K_M (1065MB download, 8GB+ devices)
- **Fallback:** SmolLM2-360M Q8 (368MB, 6GB devices)
- **Backend:** Raw llama.cpp C API (not LLM.swift — bypasses Metal crash on A19 Pro)
- **Inference:** CPU-only currently (GPU fix built but untested on device)
- **Context:** 2048 tokens, 800-token context budget, 300-char conversation history
- **Architecture:** Chain-of-thought (classify → fetch data → call LLM), action tags for tool calls
- **Eval Harness:** 63 test methods covering food/weight/workout intent, routing, response quality

## Tab Structure
Dashboard | Weight | Food | Exercise | More

## Features

### Dashboard
- Deficit/surplus headline (goal-aware colors)
- Weight + trend card, goal progress bar
- Energy balance + macros, active cal + steps
- Sleep + recovery + HRV + RHR
- Workouts today, supplements taken

### Weight
- Chart: scale dots + EMA trend line, time range selector
- Insights: weight changes (3d-90d), weekly rate, deficit, projection
- Monthly grouped log, manual entry + HealthKit sync

### Food
- Date navigation, chronological diary
- Smart search (1004+ foods, ranked by usage)
- Barcode scanner (Open Food Facts), OCR nutrition label
- Recipe builder, manual entry, copy yesterday, quick-log
- 30-day consistency heatmap

### Exercise
- Body recovery map (6 muscle groups)
- Workout templates, live timer, rest timer with vibration
- 873 exercise database, custom exercises
- Strong/Hevy CSV import, workout detail + share, save as template

### More
- Weight Goal, Sleep & Recovery (WHOOP-style scores)
- Supplements checklist, Body Composition (DEXA import)
- Glucose (Apple Health + CSV), Biomarkers (65 markers, lab OCR)
- Cycle Tracking (Apple Health), Algorithm tuning, Settings

### AI Chat (Beta)
- On-device LLM with token streaming
- Chain-of-thought reasoning, screen awareness
- Food logging: "log 2 eggs and toast" → opens confirmation
- Weight logging: "I weigh 165" → saves instantly
- Workout: "start push day" → opens template, "I did bench 3x10@135" → creates workout
- Nutrition lookup: "calories in banana" → instant DB answer
- Rule engine: "calories left", "daily summary" → instant, no LLM
- Response cleaner, quality gate, conversation history

## Apple Developer
- Team ID: ZJ5H5XH82A
- API Key: 623N7AD6BJ, Issuer: ad762446-bede-4bcd-9776-a3613c669447
- Key file: `/Users/ashishsadh/important-ashisadh/key for apple app/AuthKey_623N7AD6BJ.p8`
- TestFlight: Drift Myself (internal), Drift Beta Users, Public Testers
- Public link: https://testflight.apple.com/join/NDxkRwRq

## Database (GRDB SQLite)
12 migrations: weight_entry, meal_log, food_entry, food, supplement, supplement_log, glucose_reading, dexa_scan, dexa_region, hk_sync_anchor, barcode_cache, favorite_food, exercise, workout, workout_set, workout_template, lab_report, biomarker_result

## Key Services
See `Docs/tools.md` for the full service → tool mapping.

| Service | Purpose |
|---------|---------|
| LocalAIService | LLM orchestration, model management |
| LlamaCppBackend | Raw llama.cpp C API inference |
| AIChainOfThought | Multi-step query classification |
| AIContextBuilder | Per-screen context generation |
| AIActionParser | Parse [LOG_FOOD:] etc from LLM output |
| AIActionExecutor | Food/weight intent parsing |
| AIRuleEngine | Instant answers without LLM |
| AIResponseCleaner | Strip artifacts, quality gate |
| WeightTrendCalculator | EMA + regression + deficit |
| HealthKitService | Weight, calories, sleep, HRV sync |
| WorkoutService | CRUD + import + PRs + history |
| ExerciseDatabase | 873 exercises + custom |
| TDEEEstimator | Total daily energy expenditure |
| RecoveryEstimator | Recovery/sleep/strain scores |
| OpenFoodFactsService | Barcode → nutrition |
| LabReportOCR | PDF/image lab extraction |
| BiomarkerKnowledgeBase | 65 biomarker definitions |
