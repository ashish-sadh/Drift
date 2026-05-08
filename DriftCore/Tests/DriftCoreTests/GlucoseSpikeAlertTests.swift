import Foundation
@testable import DriftCore
import Testing

// MARK: - GlucoseSpikeAlert Tests (Tier 0)
// Tests BehaviorInsightService.glucoseSpikeAlertVariant() — pure logic, no DB.
// Covers: threshold boundary (spikeDays/dataDays), content, isPositive flag.

@MainActor
@Test func glucoseSpike_belowDataThreshold_returnsNil() {
    // Only 2 data days — need at least 3 to fire
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 3, dataDays: 2)
    #expect(alert == nil)
}

@MainActor
@Test func glucoseSpike_belowSpikeThreshold_returnsNil() {
    // 3 data days but only 2 spike days — need at least 3 spikes
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 2, dataDays: 3)
    #expect(alert == nil)
}

@MainActor
@Test func glucoseSpike_exactThreshold_fires() {
    // Exactly 3 data days and 3 spike days — should fire
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 3, dataDays: 3)
    #expect(alert != nil)
    #expect(alert?.isPositive == false)
    #expect(alert?.title == "Recurring glucose spikes")
}

@MainActor
@Test func glucoseSpike_aboveThreshold_fires() {
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 5, dataDays: 7)
    #expect(alert != nil)
    #expect(alert?.isPositive == false)
    #expect(alert?.detail.contains("5") == true)
}

@MainActor
@Test func glucoseSpike_zeroData_returnsNil() {
    // No CGM data at all — no alert for users without a device
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 0, dataDays: 0)
    #expect(alert == nil)
}

@MainActor
@Test func glucoseSpike_detailMentionsSpikeCount() {
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 4, dataDays: 6)
    #expect(alert?.detail.contains("4") == true)
    #expect(alert?.detail.contains("140") == true)
}

@MainActor
@Test func glucoseSpike_hasExpectedIcon() {
    let alert = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 3, dataDays: 5)
    #expect(alert?.icon == "waveform.path.ecg")
}
