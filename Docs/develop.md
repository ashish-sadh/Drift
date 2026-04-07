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
│   │                  AIActionParser, AIActionExecutor, AIRuleEngine, AIResponseCleaner
│   ├── Health       → HealthKitService, WeightTrendCalculator, TDEEEstimator, RecoveryEstimator
│   ├── Data         → WorkoutService, ExerciseDatabase, DefaultFoods, DefaultTemplates
│   └── Import       → LabReportOCR, BodySpecPDFParser, CGMImportService, OpenFoodFactsService
├── Database/        → GRDB setup, 12 migrations
├── Resources/       → foods.json (1004), exercises.json (873), biomarkers.json (65)
├── Frameworks/      → llama.xcframework (built from source, b7400)
└── Utilities/       → Theme, Log, DateFormatters, CSVParser
```

## Key Patterns

### Database
- `AppDatabase.shared` for production, `AppDatabase.empty()` for tests
- GRDB `ValueObservation` for reactive UI
- All models: `Codable + FetchableRecord + PersistableRecord`

### AI System
- See `Docs/architecture.md` for the tool-calling vision
- See `Docs/tools.md` for the service → tool mapping
- Each service method = a potential tool the SLM can invoke
- System prompt + context → SLM → action tags → Swift executes

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

## Dependencies
- **GRDB.swift** v7.x (SQLite) — only external SPM dependency
- **llama.xcframework** — embedded, built from source (llama.cpp b7400)
- Everything else is Apple-native
