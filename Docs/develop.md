# Development Guide

## Prerequisites
- macOS with Xcode 16+, Swift 6.x
- `brew install xcodegen`
- Physical iPhone for HealthKit testing

## Quick Start
```bash
cd /Users/ashishsadh/workspace/Drift
xcodegen generate
xcodebuild -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

```
├── Models/          → GRDB records (Codable + FetchableRecord + PersistableRecord)
├── Views/           → SwiftUI views organized by tab (AI/, Food/, Weight/, Workout/, etc.)
├── ViewModels/      → @Observable classes bridging Views ↔ Services
├── Services/        → Business logic + AI system (27 service files)
│   ├── AI Layer     → LocalAIService, LlamaCppBackend, AIChainOfThought, AIContextBuilder,
│   │                  ToolSchema, ToolRegistration, AIActionExecutor, AIRuleEngine, AIResponseCleaner
│   ├── Health       → HealthKitService, WeightTrendCalculator, TDEEEstimator, RecoveryEstimator
│   ├── Data         → WorkoutService, ExerciseDatabase, DefaultFoods, DefaultTemplates
│   └── Import       → LabReportOCR, BodySpecPDFParser, CGMImportService, OpenFoodFactsService
├── Database/        → GRDB setup, 20 migrations
├── Resources/       → foods.json (1004), exercises.json (873), biomarkers.json (65)
├── Frameworks/      → llama.xcframework (rebuilt from source, latest llama.cpp)
└── Utilities/       → Theme, Log, DateFormatters, CSVParser
```

## Key Patterns

### Database
- `AppDatabase.shared` for production, `AppDatabase.empty()` for tests
- GRDB `ValueObservation` for reactive UI
- All models: `Codable + FetchableRecord + PersistableRecord`

### AI System — Dual-Model Architecture
- See `Docs/architecture.md` for the dual-path design (SmolLM + Gemma 4)
- See `Docs/tools.md` for the 10 consolidated tools
- **SmolLM path:** Hardcoded keyword/rule engine handles 80%+, model handles overflow
- **Gemma 4 path:** LLM decides which tool to call with all 10 tools visible
- Tool calls are JSON: `{"tool":"log_food","params":{"name":"eggs","amount":"2"}}`
- `LocalAIService.isLargeModel` flag drives routing decisions
- Run eval harness after any AI change: `cd DriftCore && swift test --filter AIEvalHarness`

### HealthKit
- `HealthKitService` is an `actor` for thread safety
- Anchored queries for incremental weight sync
- Queries energy/sleep/steps on demand

## Adding a Feature
1. Check `Docs/sprint.md` for current priorities
2. Add migration in `Database/Migrations.swift` (if new data)
3. Create model in `Models/`
4. Create/update service in `Services/`
5. Create view in `Views/`
6. Write tests
7. If AI-related: add eval harness tests, update `Docs/tools.md`
8. Run `xcodegen generate` if new files added

## USDA FoodData Central API Key

`USDAFoodService` uses a free USDA API key for online food search. The default `DEMO_KEY` is capped at 1,000 req/day — fine for development, a launch blocker at scale.

**Register a key (2 min):**
1. Go to https://fdc.nal.usda.gov/api-guide.html and click "Get an API Key"
2. Enter your email — the key arrives immediately
3. Set it once at app startup (e.g. in `DriftApp.init()`):
   ```swift
   Preferences.usdaApiKey = "YOUR_KEY_HERE"
   ```

The key is stored in `UserDefaults` and persists across launches. `USDAFoodService` uses it automatically; falls back to `DEMO_KEY` only when the preference is empty. Registered keys are rate-limited at 3,600 req/hour.

## Dependencies
- **GRDB.swift** v7.x (SQLite) — only external SPM dependency
- **llama.xcframework** — embedded, rebuilt from latest llama.cpp (supports Gemma 4, Qwen, SmolLM)
- Everything else is Apple-native
