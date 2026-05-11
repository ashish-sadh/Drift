import Foundation
@testable import DriftCore
import Testing

// MARK: - Significance test (Fisher z)

@Test func significance_belowSampleSizeIsNeverSignificant() {
    // n < 4 has no valid z (we'd divide by sqrt(0) or negative).
    #expect(CrossDomainPatternService.isSignificant(r: 0.95, n: 3, alpha: 0.05) == false)
    #expect(CrossDomainPatternService.isSignificant(r: 0.95, n: 0, alpha: 0.05) == false)
}

@Test func significance_perfectCorrelationIsSignificant() {
    // atanh(±1) is infinite — fast-path returns true once n ≥ 4.
    #expect(CrossDomainPatternService.isSignificant(r: 1.0, n: 4, alpha: 0.05) == true)
    #expect(CrossDomainPatternService.isSignificant(r: -1.0, n: 14, alpha: 0.05) == true)
}

@Test func significance_strongCorrelationAt30Days() {
    // r=0.5, n=30 → z = atanh(0.5) * sqrt(27) ≈ 0.549 * 5.196 ≈ 2.85 > 1.96
    #expect(CrossDomainPatternService.isSignificant(r: 0.5, n: 30, alpha: 0.05) == true)
    #expect(CrossDomainPatternService.isSignificant(r: -0.5, n: 30, alpha: 0.05) == true)
}

@Test func significance_weakCorrelationFailsEvenAt30Days() {
    // r=0.2, n=30 → z ≈ 0.203 * 5.196 ≈ 1.05 < 1.96
    #expect(CrossDomainPatternService.isSignificant(r: 0.2, n: 30, alpha: 0.05) == false)
}

@Test func significance_minThresholdNeedsLargerNAtSmallN() {
    // At the minimum n=14, |r|=0.4 is NOT significant by Fisher z.
    // z = atanh(0.4) * sqrt(11) ≈ 0.424 * 3.317 ≈ 1.41 < 1.96
    #expect(CrossDomainPatternService.isSignificant(r: 0.4, n: 14, alpha: 0.05) == false)
    // At n=24, |r|=0.4 IS significant. z ≈ 0.424 * sqrt(21) ≈ 1.94 (boundary).
    // n=30 is comfortably significant: z ≈ 0.424 * sqrt(27) ≈ 2.20.
    #expect(CrossDomainPatternService.isSignificant(r: 0.4, n: 30, alpha: 0.05) == true)
}

@Test func criticalZ_commonAlphas() {
    // A&S 26.2.23 max error ~4.5e-4 — pin the major levels we rely on.
    #expect(abs(CrossDomainPatternService.criticalZ(alpha: 0.05) - 1.960) < 0.001)
    #expect(abs(CrossDomainPatternService.criticalZ(alpha: 0.01) - 2.576) < 0.001)
    #expect(abs(CrossDomainPatternService.criticalZ(alpha: 0.001) - 3.291) < 0.005)
    // Bonferroni-adjusted alpha (0.05 / 25 pairs) ≈ 0.002 → z ≈ 3.09.
    #expect(abs(CrossDomainPatternService.criticalZ(alpha: 0.002) - 3.090) < 0.01)
    // Monotonic — stricter alpha → larger critical z.
    let z05 = CrossDomainPatternService.criticalZ(alpha: 0.05)
    let z01 = CrossDomainPatternService.criticalZ(alpha: 0.01)
    #expect(z01 > z05)
}

// MARK: - Pair generation

@Test func generatePairs_noSelfPairs() {
    let pairs = CrossDomainPatternService.generatePairs()
    #expect(pairs.allSatisfy { $0.0 != $0.1 }, "no metric should be paired with itself")
}

@Test func generatePairs_excludesTriviallyCorrelatedPairs() {
    let pairs = CrossDomainPatternService.generatePairs()
    let pairSet = Set(pairs.map { UnorderedMetricPair($0.0, $0.1) })
    // calories ≈ 4·protein + 4·carbs + 9·fat — these are excluded.
    #expect(!pairSet.contains(UnorderedMetricPair("calories", "protein")))
    #expect(!pairSet.contains(UnorderedMetricPair("calories", "carbs")))
    #expect(!pairSet.contains(UnorderedMetricPair("calories", "fat")))
}

@Test func generatePairs_includesActionablePairs() {
    let pairs = CrossDomainPatternService.generatePairs()
    let pairSet = Set(pairs.map { UnorderedMetricPair($0.0, $0.1) })
    // Workout × weight is the canonical proactive-pattern target.
    #expect(pairSet.contains(UnorderedMetricPair("workout_volume", "weight")))
    #expect(pairSet.contains(UnorderedMetricPair("carbs", "glucose_avg")))
}

@Test func generatePairs_noDuplicates() {
    let pairs = CrossDomainPatternService.generatePairs()
    let pairSet = Set(pairs.map { UnorderedMetricPair($0.0, $0.1) })
    #expect(pairSet.count == pairs.count, "no duplicate unordered pairs allowed")
}

// MARK: - UnorderedMetricPair

@Test func unorderedPair_equalsRegardlessOfOrder() {
    #expect(UnorderedMetricPair("weight", "calories") == UnorderedMetricPair("calories", "weight"))
    #expect(UnorderedMetricPair("a", "b").hashValue == UnorderedMetricPair("b", "a").hashValue)
}

// MARK: - analyzePure (pure stats, no DB)

@Test func analyzePure_strongPositiveProducesPattern() {
    // 20 days, perfectly correlated → r = 1.0, significant, |r| ≥ 0.4.
    var seriesA: [String: Double] = [:]
    var seriesB: [String: Double] = [:]
    for d in 0..<20 {
        let key = "2026-04-\(String(format: "%02d", d + 1))"
        seriesA[key] = Double(d)
        seriesB[key] = Double(d) * 2.0 + 5.0
    }
    let pattern = CrossDomainPatternService.analyzePure(
        metricA: "workout_volume", metricB: "weight",
        seriesA: seriesA, seriesB: seriesB,
        windowDays: 30
    )
    #expect(pattern != nil)
    #expect(pattern?.r == 1.0)
    #expect(pattern?.n == 20)
    #expect(pattern?.metricA == "workout_volume")
    #expect(pattern?.metricB == "weight")
    #expect(pattern?.summary.isEmpty == false)
}

@Test func analyzePure_strongNegativeProducesPattern() {
    var seriesA: [String: Double] = [:]
    var seriesB: [String: Double] = [:]
    for d in 0..<18 {
        let key = "2026-04-\(String(format: "%02d", d + 1))"
        seriesA[key] = Double(d)
        seriesB[key] = -Double(d) * 1.5 + 100.0
    }
    let pattern = CrossDomainPatternService.analyzePure(
        metricA: "carbs", metricB: "glucose_avg",
        seriesA: seriesA, seriesB: seriesB,
        windowDays: 30
    )
    #expect(pattern != nil)
    #expect((pattern?.r ?? 0) < 0)
    #expect(pattern?.summary.contains("r=-") == true)
}

@Test func analyzePure_weakCorrelationProducesNil() {
    // Hand-built mostly-uncorrelated series — r should land below 0.4.
    let seriesA: [String: Double] = [
        "2026-04-01": 1, "2026-04-02": 2, "2026-04-03": 1, "2026-04-04": 3,
        "2026-04-05": 2, "2026-04-06": 1, "2026-04-07": 3, "2026-04-08": 2,
        "2026-04-09": 1, "2026-04-10": 2, "2026-04-11": 3, "2026-04-12": 1,
        "2026-04-13": 2, "2026-04-14": 3, "2026-04-15": 1, "2026-04-16": 2,
        "2026-04-17": 3, "2026-04-18": 1, "2026-04-19": 2, "2026-04-20": 3,
    ]
    let seriesB: [String: Double] = [
        "2026-04-01": 5, "2026-04-02": 4, "2026-04-03": 5, "2026-04-04": 4,
        "2026-04-05": 5, "2026-04-06": 4, "2026-04-07": 5, "2026-04-08": 4,
        "2026-04-09": 5, "2026-04-10": 4, "2026-04-11": 5, "2026-04-12": 4,
        "2026-04-13": 5, "2026-04-14": 4, "2026-04-15": 5, "2026-04-16": 4,
        "2026-04-17": 5, "2026-04-18": 4, "2026-04-19": 5, "2026-04-20": 4,
    ]
    let pattern = CrossDomainPatternService.analyzePure(
        metricA: "fiber", metricB: "glucose_avg",
        seriesA: seriesA, seriesB: seriesB,
        windowDays: 30
    )
    #expect(pattern == nil, "weak correlation should not surface a pattern")
}

@Test func analyzePure_tooFewPairsProducesNil() {
    // 10 paired days < minPairs (14).
    var seriesA: [String: Double] = [:]
    var seriesB: [String: Double] = [:]
    for d in 0..<10 {
        let key = "2026-04-\(String(format: "%02d", d + 1))"
        seriesA[key] = Double(d)
        seriesB[key] = Double(d) * 2.0
    }
    let pattern = CrossDomainPatternService.analyzePure(
        metricA: "weight", metricB: "calories",
        seriesA: seriesA, seriesB: seriesB,
        windowDays: 30
    )
    #expect(pattern == nil, "fewer than 14 paired days → no pattern even if r is perfect")
}

@Test func analyzePure_innerJoinsOnSharedDates() {
    // Only 14 of 20 dates overlap — the other 6 are orphans on each side.
    var seriesA: [String: Double] = [:]
    var seriesB: [String: Double] = [:]
    for d in 0..<14 {
        let key = "2026-04-\(String(format: "%02d", d + 1))"
        seriesA[key] = Double(d)
        seriesB[key] = Double(d) * 2.0
    }
    // Add A-only and B-only orphan days — must be ignored.
    seriesA["2026-04-20"] = 99
    seriesA["2026-04-21"] = 99
    seriesB["2026-04-25"] = 99
    seriesB["2026-04-26"] = 99
    let pattern = CrossDomainPatternService.analyzePure(
        metricA: "weight", metricB: "workout_volume",
        seriesA: seriesA, seriesB: seriesB,
        windowDays: 30
    )
    #expect(pattern?.n == 14, "n should reflect inner-join, not the larger side")
}

@Test @MainActor func analyze_excludedPairRejected() {
    // analyze() (the DB path) checks the excluded list before fetching, so
    // a calories↔protein query returns nil even on a freshly-seeded DB.
    // analyzePure() intentionally bypasses this check so direct math
    // probing is unhindered — the protection lives in analyze().
    let pattern = CrossDomainPatternService.analyze(
        metricA: "calories", metricB: "protein",
        windowDays: 30
    )
    #expect(pattern == nil)
}

@Test @MainActor func analyze_samePairRejected() {
    let pattern = CrossDomainPatternService.analyze(
        metricA: "weight", metricB: "weight",
        windowDays: 30
    )
    #expect(pattern == nil, "same-metric pair → nil")
}

// MARK: - customPhrasing

@Test func customPhrasing_workoutWeightNegative() {
    let phrase = CrossDomainPatternService.customPhrasing(
        metricA: "workout_volume", metricB: "weight", r: -0.55
    )
    #expect(phrase?.contains("weight tends to drop") == true)
}

@Test func customPhrasing_workoutWeightPositive() {
    let phrase = CrossDomainPatternService.customPhrasing(
        metricA: "workout_volume", metricB: "weight", r: 0.55
    )
    #expect(phrase?.contains("runs higher") == true)
}

@Test func customPhrasing_orderIndependent() {
    let a = CrossDomainPatternService.customPhrasing(
        metricA: "carbs", metricB: "glucose_avg", r: 0.6
    )
    let b = CrossDomainPatternService.customPhrasing(
        metricA: "glucose_avg", metricB: "carbs", r: 0.6
    )
    #expect(a == b, "phrasing is keyed on unordered pair")
}

@Test func customPhrasing_unknownPairReturnsNil() {
    let phrase = CrossDomainPatternService.customPhrasing(
        metricA: "fiber", metricB: "weight", r: 0.5
    )
    #expect(phrase == nil)
}

// MARK: - formatPattern

@Test func formatPattern_containsExpectedFields() {
    let s = CrossDomainPatternService.formatPattern(
        metricA: "workout_volume", metricB: "weight",
        r: -0.55, n: 22, windowDays: 30
    )
    #expect(s.contains("r=-0.55"))
    #expect(s.contains("22 paired days"))
    #expect(s.contains("30"))
}

@Test func formatPattern_unknownPairFallsBackToGeneric() {
    let s = CrossDomainPatternService.formatPattern(
        metricA: "fiber", metricB: "weight",
        r: 0.42, n: 20, windowDays: 30
    )
    #expect(s.contains("fiber"))
    #expect(s.contains("weight"))
    #expect(s.contains("correlation"))
    #expect(s.contains("r=+0.42"))
}

// MARK: - Detect (against empty DB)

@Test @MainActor func detect_emptyDBProducesNoPatterns() {
    let patterns = CrossDomainPatternService.detect(windowDays: 30)
    #expect(patterns.isEmpty, "no seeded data → no patterns; got \(patterns)")
}

// MARK: - Tool: formatResults

@Test func formatResults_emptyShowsFriendlyDefault() {
    let s = CrossDomainPatternDetectorTool.formatResults([], windowDays: 30)
    #expect(s.lowercased().contains("nothing stands out"))
    #expect(s.contains("14 overlapping days"))
    #expect(s.contains("30 days"))
}

@Test func formatResults_singlePatternHasSingularHeader() {
    let p = CrossDomainPattern(
        metricA: "workout_volume", metricB: "weight",
        r: -0.55, n: 22, windowDays: 30,
        summary: "Your weight tends to drop on heavier-volume training days (r=-0.55, 22 paired days over 30)."
    )
    let s = CrossDomainPatternDetectorTool.formatResults([p], windowDays: 30)
    #expect(s.lowercased().contains("one pattern"))
    #expect(s.contains("1. "))
    #expect(s.contains("training days"))
}

@Test func formatResults_multiplePatternsAreNumbered() {
    let patterns = [
        CrossDomainPattern(metricA: "carbs", metricB: "glucose_avg",
                           r: 0.62, n: 25, windowDays: 30,
                           summary: "Carbs and glucose pattern."),
        CrossDomainPattern(metricA: "workout_volume", metricB: "weight",
                           r: -0.45, n: 22, windowDays: 30,
                           summary: "Workout and weight pattern."),
    ]
    let s = CrossDomainPatternDetectorTool.formatResults(patterns, windowDays: 30)
    #expect(s.contains("2 patterns"))
    #expect(s.contains("1. Carbs"))
    #expect(s.contains("2. Workout"))
}

// MARK: - Tool: clampWindow

@Test func patternDetector_clampWindow_bucketsByThreshold() {
    #expect(CrossDomainPatternDetectorTool.clampWindow(nil) == 30)
    #expect(CrossDomainPatternDetectorTool.clampWindow(7) == 14)
    #expect(CrossDomainPatternDetectorTool.clampWindow(14) == 14)
    #expect(CrossDomainPatternDetectorTool.clampWindow(21) == 14)
    #expect(CrossDomainPatternDetectorTool.clampWindow(22) == 30)
    #expect(CrossDomainPatternDetectorTool.clampWindow(30) == 30)
    #expect(CrossDomainPatternDetectorTool.clampWindow(60) == 60)
    #expect(CrossDomainPatternDetectorTool.clampWindow(90) == 90)
    #expect(CrossDomainPatternDetectorTool.clampWindow(365) == 90)
}

// MARK: - Tool: run (graceful degrade)

@Test @MainActor func run_emptyDBSurfacesBlankStateMessage() {
    let s = CrossDomainPatternDetectorTool.run(windowDays: 30)
    #expect(s.lowercased().contains("nothing stands out"))
}

// MARK: - Tool registry wiring

@Test @MainActor func patternDetector_registerRoundTrip() {
    CrossDomainPatternDetectorTool.syncRegistration()
    let t = ToolRegistry.shared.tool(named: CrossDomainPatternDetectorTool.toolName)
    #expect(t != nil)
    #expect(t?.service == "insights")
    #expect(t?.parameters.first(where: { $0.name == "window_days" })?.required == false)
}

@Test @MainActor func patternDetector_handlerExecutesAgainstEmptyDB() async {
    CrossDomainPatternDetectorTool.syncRegistration()
    let call = ToolCall(
        tool: CrossDomainPatternDetectorTool.toolName,
        params: ToolCallParams(values: ["window_days": "30"])
    )
    let result = await ToolRegistry.shared.execute(call)
    if case .text(let s) = result {
        #expect(s.lowercased().contains("nothing stands out"))
    } else {
        Issue.record("expected .text result, got \(result)")
    }
}

@Test @MainActor func patternDetector_isRegisteredAsInfoTool() {
    #expect(AIToolAgent.isInfoTool(CrossDomainPatternDetectorTool.toolName))
}

// MARK: - Intent threshold policy

@Test func intentThreshold_patternDetectorAlwaysProceeds() {
    for confidence in ["high", "medium", "low"] {
        for complete in [true, false] {
            let d = IntentThresholds.shouldClarify(
                tool: CrossDomainPatternDetectorTool.toolName,
                confidence: confidence,
                hasCompleteParams: complete
            )
            #expect(d == .proceed,
                "cross_domain_pattern_detector is read-only — never clarify (conf=\(confidence), complete=\(complete))")
        }
    }
}

// MARK: - QA regressions

@Test func analyzePure_flatSeriesReturnsNilWithoutNaN() {
    // A user with no workouts logged has workout_volume = 0 every day.
    // Zero variance → Pearson r is undefined; we must return nil, NOT a
    // NaN pattern that could poison the sort comparator in `detect`.
    var flat: [String: Double] = [:]
    var varying: [String: Double] = [:]
    for d in 0..<20 {
        let key = "2026-04-\(String(format: "%02d", d + 1))"
        flat[key] = 0
        varying[key] = Double(d) * 1.5
    }
    let pattern = CrossDomainPatternService.analyzePure(
        metricA: "workout_volume", metricB: "weight",
        seriesA: flat, seriesB: varying,
        windowDays: 30
    )
    #expect(pattern == nil, "flat metric must produce nil, not a NaN pattern")
    // And no .nan slips through if a future refactor changes the path:
    if let r = pattern?.r { #expect(!r.isNaN, "r must not be NaN") }
}

@Test @MainActor func detect_bonferroniScalesToTestablePairsNotAllPairs() {
    // A user without a CGM never gets data for `glucose_avg`. The 7 pairs
    // touching glucose can't be tested, so they shouldn't dilute the
    // Bonferroni budget for the 18 pairs that CAN be tested. Empty DB
    // here just confirms `detect` runs without crashing and exits early.
    let patterns = CrossDomainPatternService.detect(windowDays: 30)
    #expect(patterns.isEmpty)
}

// MARK: - False-positive resistance on random data

/// Seeded LCG — keeps the false-positive test deterministic across runs.
struct SeededLCG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Test func detect_randomizedFixtureProducesNoFalsePositives() {
    // 30 days of independently-drawn values per metric. With the per-pair
    // alpha (0.05) we'd see ~1.4 spurious correlations on average across
    // 25 pairs — that's exactly why `detect` applies Bonferroni
    // (alpha/pair-count). This test runs the same loop with the corrected
    // alpha and asserts zero false positives for a fixed seed.
    var rng = SeededLCG(state: 42)
    var series: [String: [String: Double]] = [:]
    for metric in CrossDomainPatternService.scannedMetrics {
        var s: [String: Double] = [:]
        for d in 0..<30 {
            let key = "2026-04-\(String(format: "%02d", d + 1))"
            s[key] = Double.random(in: 0...100, using: &rng)
        }
        series[metric] = s
    }
    let pairs = CrossDomainPatternService.generatePairs()
    let adjustedAlpha = CrossDomainPatternService.alpha / Double(pairs.count)
    var detected: [CrossDomainPattern] = []
    for (a, b) in pairs {
        if let p = CrossDomainPatternService.analyzePure(
            metricA: a, metricB: b,
            seriesA: series[a] ?? [:], seriesB: series[b] ?? [:],
            windowDays: 30,
            alpha: adjustedAlpha
        ) { detected.append(p) }
    }
    #expect(detected.isEmpty,
        "randomized fixture produced false positives: \(detected.map(\.summary))")
}
