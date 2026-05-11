import Foundation
@testable import DriftCore
import Testing

@Test func sleepFood_earlyDinnerBetterSleep() {
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (18.0, 7.5), (18.5, 8.0), (17.5, 7.8),   // early dinner
        (21.0, 6.0), (22.0, 5.5), (21.5, 6.2),   // late dinner
        (18.0, 7.2), (21.0, 6.1), (17.5, 7.9), (22.0, 5.8)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.earlyDinnerCount >= 3)
    #expect(result.lateDinnerCount >= 3)
    if let early = result.earlyDinnerAvgSleep, let late = result.lateDinnerAvgSleep {
        #expect(early > late, "early dinner should correlate with more sleep")
    }
    #expect(result.totalPairs == 10)
}

@Test func sleepFood_insufficientGroupsFallsToPearson() {
    // Only one early dinner day — should fall back to Pearson
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 8.0),              // only 1 early
        (21.0, 6.0), (22.0, 5.5), (21.5, 6.2), (20.5, 6.5), (21.0, 6.0)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.earlyDinnerCount == 1)
    #expect(result.pearsonR != nil, "should compute pearson when groups too small")
}

@Test func sleepFood_uniformTimingReturnsNilPearson() {
    // All meals at same hour → zero variance → pearsonR = nil
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (20.0, 6.5), (20.0, 7.0), (20.0, 6.8), (20.0, 7.2), (20.0, 6.9)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.pearsonR == nil, "flat meal-hour series → undefined correlation")
}

@Test func sleepFood_formatResultIncludesDiff() {
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (18.0, 7.5), (18.5, 8.0), (17.5, 7.8),
        (21.0, 6.0), (22.0, 5.5), (21.5, 6.2),
        (18.0, 7.2), (21.0, 6.1), (17.5, 7.9), (22.0, 5.8)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("longer"), "output should mention sleep difference")
    #expect(text.contains("8pm") || text.contains("7pm"), "should mention meal time cutoff")
}

@Test func sleepFood_emptyPairsAnalyzesCleanly() {
    let result = SleepFoodCorrelationTool.analyze(pairs: [])
    #expect(result.totalPairs == 0)
    #expect(result.lateDinnerAvgSleep == nil)
    #expect(result.earlyDinnerAvgSleep == nil)
    #expect(result.pearsonR == nil)
}

// MARK: - formatResult branch coverage

@Test func sleepFood_formatResult_lateDinnerBetterSleep() {
    // Late dinner nights have MORE sleep than early — should produce the "interestingly" branch
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 5.5), (17.5, 5.8), (17.0, 5.2),   // early dinner, less sleep
        (21.0, 8.0), (22.0, 8.5), (21.5, 7.8),   // late dinner, more sleep
        (17.0, 5.4), (21.0, 8.2), (17.5, 5.6), (22.0, 7.9)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("Interestingly") || text.contains("longer on late dinner"),
            "should take the late-better branch, got: \(text)")
}

@Test func sleepFood_formatResult_noDifferenceBetweenEarlyAndLate() {
    // Roughly equal sleep regardless of dinner time
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 7.0), (17.5, 7.1), (17.0, 6.9),
        (21.0, 7.0), (22.0, 7.1), (21.5, 6.9),
        (17.0, 7.0), (21.0, 7.0), (17.5, 7.1), (22.0, 7.0)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("doesn't strongly affect") || text.contains("Dinner timing"),
            "should note no meaningful difference, got: \(text)")
}

@Test func sleepFood_formatResult_pearsonNegativeStrongPattern() {
    // Small groups (< 3 each) so falls through to Pearson, with strong negative correlation
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 8.5),              // 1 early
        (21.0, 6.0), (22.0, 5.5), (23.0, 5.0), (21.5, 5.8), (22.5, 5.2)  // 5 late
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    // With strong negative r, should recommend finishing meal earlier
    if let r = result.pearsonR, r < -0.3 {
        #expect(text.contains("shorter sleep") || text.contains("2–3 hours"),
                "strong negative correlation should produce recommendation, got: \(text)")
    } else {
        #expect(text.contains("No strong pattern") || text.contains("factor"),
                "weak correlation should note no pattern, got: \(text)")
    }
}

@Test func sleepFood_formatResult_pearsonNilMessage() {
    // Uniform meal timing → pearsonR nil → specific message
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (20.0, 6.5), (20.0, 7.0)  // only 2 pairs, same hour → nil pearson
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.pearsonR == nil)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("Couldn't compute") || text.contains("consistent"),
            "nil pearsonR should produce fallback message, got: \(text)")
}

// MARK: - #736 acceptance thresholds

@Test func sleepFood_thresholdsMatchAcceptance() {
    // Pin the numbers — a future tweak should fail this test, not slip
    // silently past the acceptance criteria.
    #expect(SleepFoodCorrelationTool.minPairs == 10)
    #expect(SleepFoodCorrelationTool.effectThreshold == 0.25)
}

@Test func sleepFood_analyze_lateBoundaryInclusiveEarlyBoundaryExclusive() {
    // 20.0 IS late (>=20); 19.0 is NOT early (<19 required); 18.99 IS early.
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (20.0, 6.5), (19.0, 7.0), (18.99, 7.5),
    ]
    let r = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(r.lateDinnerCount == 1, "20.0 should land in the late bin")
    #expect(r.earlyDinnerCount == 1, "only 18.99 is strictly <19")
}

@Test func sleepFood_format_aboveEffectThresholdEmitsRecommendation() {
    // r = -0.30 ≥ effectThreshold(0.25) → recommendation should fire on the
    // Pearson-fallback path (group counts < 3 to bypass group comparison).
    let result = SleepFoodCorrelationTool.CorrelationResult(
        lateDinnerAvgSleep: nil, earlyDinnerAvgSleep: nil,
        lateDinnerCount: 0, earlyDinnerCount: 0,
        pearsonR: -0.30, totalPairs: 12
    )
    let s = SleepFoodCorrelationTool.formatResult(result)
    #expect(s.contains("r=-0.30"))
    #expect(s.lowercased().contains("shorter sleep"))
    #expect(s.lowercased().contains("2–3 hours before bed"))
}

@Test func sleepFood_format_belowEffectThresholdSuppressesRecommendation() {
    // |r| = 0.20 < effectThreshold(0.25) → must NOT emit a recommendation.
    let result = SleepFoodCorrelationTool.CorrelationResult(
        lateDinnerAvgSleep: nil, earlyDinnerAvgSleep: nil,
        lateDinnerCount: 0, earlyDinnerCount: 0,
        pearsonR: -0.20, totalPairs: 12
    )
    let s = SleepFoodCorrelationTool.formatResult(result)
    #expect(s.lowercased().contains("no strong pattern"))
    #expect(!s.lowercased().contains("2–3 hours before bed"))
}

@Test func sleepFood_format_positiveCorrelationAboveThresholdFlagsOtherFactors() {
    // |r| = 0.30 ≥ effectThreshold but r > 0 — the existing tool should
    // call out "other factors" rather than mis-recommend earlier dinner.
    let result = SleepFoodCorrelationTool.CorrelationResult(
        lateDinnerAvgSleep: nil, earlyDinnerAvgSleep: nil,
        lateDinnerCount: 0, earlyDinnerCount: 0,
        pearsonR: 0.30, totalPairs: 12
    )
    let s = SleepFoodCorrelationTool.formatResult(result)
    #expect(s.lowercased().contains("other factors"))
    #expect(!s.lowercased().contains("finishing your last meal"))
}

// MARK: - Tool wiring

@Test @MainActor func sleepFood_registerRoundTrip() {
    SleepFoodCorrelationTool.syncRegistration()
    let t = ToolRegistry.shared.tool(named: SleepFoodCorrelationTool.toolName)
    #expect(t != nil)
    #expect(t?.service == "insights")
    #expect(t?.parameters.first(where: { $0.name == "window_days" })?.required == false)
}

@Test @MainActor func sleepFood_isRegisteredAsInfoTool() {
    #expect(AIToolAgent.isInfoTool(SleepFoodCorrelationTool.toolName))
}

@Test func sleepFood_intentThresholdAlwaysProceeds() {
    for confidence in ["high", "medium", "low"] {
        for complete in [true, false] {
            let d = IntentThresholds.shouldClarify(
                tool: SleepFoodCorrelationTool.toolName,
                confidence: confidence,
                hasCompleteParams: complete
            )
            #expect(d == .proceed,
                "sleep_food_correlation is read-only — never clarify (conf=\(confidence), complete=\(complete))")
        }
    }
}

// MARK: - lastDinnerHour — QA regressions

@Test func sleepFood_lastDinnerHour_breakfastOnlyDayReturnsNil() {
    // A breakfast-only day must NOT count as "early dinner" — used to
    // produce a "finish before 7pm" message at 8am log times. #736 QA.
    let entries = [makeFoodEntry(localHour: 8)]
    #expect(SleepFoodCorrelationTool.lastDinnerHour(forEntries: entries) == nil)
}

@Test func sleepFood_lastDinnerHour_pastMidnightWrapsAfterEvening() {
    // A 21:00 dinner + a 00:15 snack — the snack is the latest meal of the
    // logical "yesterday" eating window and should outrank the 9pm dinner.
    let entries = [
        makeFoodEntry(localHour: 21, minute: 0),
        makeFoodEntry(localHour: 0, minute: 15),
    ]
    let h = SleepFoodCorrelationTool.lastDinnerHour(forEntries: entries)
    #expect(h != nil)
    #expect((h ?? 0) > 23.0, "00:15 unwraps to 24.25 to outrank 21.0; got \(h ?? -1)")
}

@Test func sleepFood_lastDinnerHour_postMidnightOnlyMealStillCountsLate() {
    // A user with ONLY a 03:30 log shouldn't be filed under "early dinner"
    // (the bug before this fix). Should land in the late bucket via the
    // wrap-to-27.5 logic.
    let entries = [makeFoodEntry(localHour: 3, minute: 30)]
    let h = SleepFoodCorrelationTool.lastDinnerHour(forEntries: entries)
    #expect(h != nil)
    #expect((h ?? 0) >= 24.0)
}

@Test func sleepFood_lastDinnerHour_postNoonFloorEnforced() {
    // 11:59 is below noon — must be dropped. 12:00 is the inclusive floor.
    let entries = [makeFoodEntry(localHour: 11, minute: 59)]
    #expect(SleepFoodCorrelationTool.lastDinnerHour(forEntries: entries) == nil)
    let entries2 = [makeFoodEntry(localHour: 12)]
    #expect(SleepFoodCorrelationTool.lastDinnerHour(forEntries: entries2) == 12.0)
}

@Test func sleepFood_lastDinnerHour_picksLatestNotEarliest() {
    let entries = [
        makeFoodEntry(localHour: 12, minute: 30),
        makeFoodEntry(localHour: 19, minute: 45),
        makeFoodEntry(localHour: 15, minute: 0),
    ]
    let h = SleepFoodCorrelationTool.lastDinnerHour(forEntries: entries)
    #expect(h != nil && (h ?? 0) >= 19.7 && (h ?? 0) <= 19.8,
        "expected ~19.75; got \(h ?? -1)")
}

@Test func sleepFood_lastDinnerHour_emptyEntriesReturnsNil() {
    #expect(SleepFoodCorrelationTool.lastDinnerHour(forEntries: []) == nil)
}

/// Lightweight FoodEntry factory keyed on local hour/minute, mirroring
/// the helper pattern in `FoodTimingInsightToolTests`. Using local-TZ
/// ISO strings keeps the dinner-hour math independent of where the test
/// machine lives.
private func makeFoodEntry(localHour hour: Int, minute: Int = 0) -> FoodEntry {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 5; comps.day = 10
    comps.hour = hour; comps.minute = minute
    let date = Calendar.current.date(from: comps)!
    return FoodEntry(
        foodName: "test",
        servingSizeG: 100,
        calories: 0,
        loggedAt: DateFormatters.iso8601.string(from: date)
    )
}

@Test @MainActor func sleepFood_runWithoutHealthAdapterDegradesGracefully() async {
    // The DriftCore test process doesn't register a HealthDataProvider,
    // so `run` must fall through to the setup-hint path instead of
    // crashing the whole tool call.
    let s = await SleepFoodCorrelationTool.run(windowDays: 30)
    #expect(s.lowercased().contains("no sleep data") || s.lowercased().contains("not enough data"),
        "expected graceful degrade; got: \(s)")
}
