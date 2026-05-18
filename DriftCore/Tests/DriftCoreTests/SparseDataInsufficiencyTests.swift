import Foundation
@testable import DriftCore
import Testing

// Pins the sparse-data / insufficient-data / min-sample contract added by
// commit 5a3f6eec — the calculator must NEVER publish a fabricated weekly
// rate / projection when it has too few points or too short a span.
// Pre-fix bug: 2 weigh-ins 5 days apart produced "+4.41 lbs/wk based on last
// 21 days". Filed as #801's reference regression.

@Test func weightTrendSparseDataInsufficiencyReturnsZero() async throws {
    // Two entries, 1 day apart. The min-sample gate requires ≥4 points
    // spanning ≥14 days. Contract: weeklyRateKg == 0 AND hasInsufficientData
    // == true so the UI renders "—" instead of an extrapolated number.
    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    let entries: [(String, Double)] = [
        (f.string(from: yesterday), 70.0),
        (f.string(from: today), 69.5),
    ]
    let t = WeightTrendCalculator.calculateTrend(entries: entries)!
    #expect(t.hasInsufficientData == true)
    #expect(t.weeklyRateKg == 0)
    #expect(t.estimatedDailyDeficit == 0)
}

@Test func weightTrendInsufficientDataMinSampleGate() async throws {
    // Three entries spanning 7 days — fails BOTH the ≥4 points AND the
    // ≥14 days span criteria. Calculator must report insufficient data.
    let today = Date()
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    let entries: [(String, Double)] = (0..<3).map { i in
        let d = Calendar.current.date(byAdding: .day, value: -(6 - i * 3), to: today)!
        return (f.string(from: d), 70.0 - Double(i) * 0.3)
    }
    let t = WeightTrendCalculator.calculateTrend(entries: entries)!
    #expect(t.hasInsufficientData == true)
    #expect(t.weeklyRateKg == 0)
}

@Test func weightTrendSparseDataHidesProjection() async throws {
    // Sparse data must hide projection30Day (nil) — the UI must render
    // "—" instead of a fabricated future weight. This is the projection-
    // tile companion to the weekly-rate hide.
    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    let entries: [(String, Double)] = [
        (f.string(from: yesterday), 70.0),
        (f.string(from: today), 69.5),
    ]
    let t = WeightTrendCalculator.calculateTrend(entries: entries)!
    #expect(t.projection30Day == nil)
    #expect(t.hasInsufficientData == true)
}
