# Testing Guide

## Running Tests

```bash
cd /Users/ashishsadh/workspace/Drift

# All tests (729+)
xcodebuild test -project Drift.xcodeproj -scheme Drift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Quick pass/fail check
xcodebuild test ... 2>&1 | grep "✘"  # empty = all pass

# AI eval harness only (63 test methods)
xcodebuild test -project Drift.xcodeproj -scheme Drift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:'DriftTests/AIEvalHarness'

# Specific test class
xcodebuild test ... -only-testing:DriftTests/WorkoutTests
```

## Test Files (14 files, 729+ tests)

| File | Tests | Covers |
|------|-------|--------|
| `FoodLoggingTests.swift` | 180+ | Food search, logging, recipes, macros, TDEE |
| `AIEvalHarness.swift` | 63 methods (~400 cases) | Food/weight/workout intent, routing, response quality |
| `WorkoutTests.swift` | 68+ | Workouts, CSV import, recovery, templates |
| `WorkoutPersistenceTests.swift` | 40+ | Session save/load, exercise persistence |
| `UIFlowTests.swift` | 49 | DB CRUD: weight, food, supplements, DEXA, glucose |
| `WeightTrendCalculatorTests.swift` | 40 | EMA, regression, deficit, projection |
| `AITests.swift` | 30+ | Action parsing, context builders, intent detection |
| `RobustnessTests.swift` | 30+ | Stress tests, concurrent access |
| `EdgeCaseTests.swift` | 26 | Large datasets, special chars, zero values |
| `DatabaseEdgeCaseTests.swift` | 20+ | Schema edge cases, cascade deletes |
| `LabReportOCRTests.swift` | 48 | Quest + LabCorp PDF extraction |
| `CycleCalculationTests.swift` | 16 | Cycle phase, ovulation, fertile window |
| `NutritionOCRTests.swift` | 15 | OCR parsing: calories, macros, serving size |
| `CSVParserTests.swift` | 4 | CSV parsing basics |

## AI Eval Harness

The eval harness (`DriftTests/AIEvalHarness.swift`) is the gold-standard test suite for AI quality. Run it after every AI change.

### Current Coverage (63 test methods)
- Food logging precision: 23 positive cases, 12 false positive checks
- Indian food logging: 12 cases
- Food phrasing variety: 12 cases
- Beverages/snacks: 9 cases
- Amount parsing: 9 cases + 7 edge cases + 3 fractions + 5 exact amounts
- Weight logging: 6 positive, 4 false positive, 5 unit detection, 3+4 edge cases
- Workout routing: 7 queries, 4 false positive checks
- Workout parsing: CREATE (2 exercises, single, no weight, 3-exercise, weight extraction), START (5 templates)
- Chain-of-thought routing: 25 queries across all domains
- Calorie estimation: 7 routing + 4 false positive checks
- Nutrition lookup: 8 query formats
- Cross-screen routing: 6 cases
- Keyword false positive prevention: 5 broad-term cases
- Screen fallback context: 5 screens
- Response cleaner: markdown, preambles, ChatML, format echo, disclaimers, dedup, truncation, low quality, good responses
- Action parser: 10 tag formats, 3 clean text preservation
- Meal hints: 4 cases
- Compound food protection: 3 cases
- Multi-food logging: 3 cases
- Edge cases: 7 empty/special inputs, 5 mixed intents
- Token budget: truncation + all contexts under budget
- Rule engine: 19 exact-match patterns
- Domain routing: 9 domains verified

### Target: 200+ test methods
Priority areas for expansion: calorie estimation accuracy, calories remaining, multi-turn conversations, ambiguous queries, Indian food amounts.

## Test Patterns

```swift
// Database test (empty in-memory DB)
@Test func myTest() async throws {
    let db = try AppDatabase.empty()
    // ... test with db
}

// Pure logic test
@Test func calculationTest() async throws {
    let result = MyService.calculate(input: 42)
    #expect(result == expected)
}

// AI eval pattern (precision measurement)
func testFoodIntents() {
    let cases = ["log 2 eggs", "ate chicken", ...]
    var detected = 0
    for query in cases {
        if parseFoodIntent(query) != nil { detected += 1 }
    }
    let precision = Double(detected) / Double(cases.count)
    XCTAssertGreaterThanOrEqual(precision, 0.85)
}
```

## Simulator Testing

```bash
# Install on simulator
APP=$(find ~/Library/Developer/Xcode/DerivedData/Drift-*/Build/Products/Debug-iphonesimulator/Drift.app -maxdepth 0 | head -1)
xcrun simctl install "iPhone 17 Pro" "$APP"
xcrun simctl launch "iPhone 17 Pro" com.drift.health

# Screenshot
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/drift_screenshot.png
```
