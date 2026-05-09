import Foundation
@testable import DriftCore
import Testing

// MARK: - phase classification

@Test func cycleBiomarker_phaseFor_menstrual() {
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 1, cycleLength: 28) == .menstrual)
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 5, cycleLength: 28) == .menstrual)
}

@Test func cycleBiomarker_phaseFor_follicular() {
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 6, cycleLength: 28) == .follicular)
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 12, cycleLength: 28) == .follicular)
}

@Test func cycleBiomarker_phaseFor_ovulation() {
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 14, cycleLength: 28) == .ovulation)
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 15, cycleLength: 28) == .ovulation)
}

@Test func cycleBiomarker_phaseFor_luteal() {
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 20, cycleLength: 28) == .luteal)
    #expect(CycleBiomarkerInsight.phaseFor(cycleDay: 28, cycleLength: 28) == .luteal)
}

@Test func cycleBiomarker_phaseForDate_emptyPeriodsReturnsNil() {
    #expect(CycleBiomarkerInsight.phase(forDate: Date(), periodStarts: [], cycleLength: 28) == nil)
}

@Test func cycleBiomarker_phaseForDate_dateBeforeFirstPeriodReturnsNil() {
    let cal = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
    let earlier = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    #expect(CycleBiomarkerInsight.phase(forDate: earlier, periodStarts: [start], cycleLength: 28) == nil)
}

@Test func cycleBiomarker_phaseForDate_pastLastCyclePlusBufferReturnsNil() {
    let cal = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let waaay = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!
    #expect(CycleBiomarkerInsight.phase(forDate: waaay, periodStarts: [start], cycleLength: 28) == nil)
}

@Test func cycleBiomarker_phaseForDate_lutealAfterMidCycleStart() {
    let cal = Calendar.current
    let p1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let p2 = cal.date(from: DateComponents(year: 2026, month: 1, day: 29))!
    let reading = cal.date(from: DateComponents(year: 2026, month: 2, day: 18))! // p2 + 20 days = day 21
    #expect(CycleBiomarkerInsight.phase(forDate: reading, periodStarts: [p1, p2], cycleLength: 28) == .luteal)
}

// MARK: - analyze: clear correlation

@Test func cycleBiomarker_analyze_clearMenstrualDrop() {
    // 12 readings, ferritin tanks during menstrual phase
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (12, .menstrual), (11, .menstrual), (13, .menstrual),
        (28, .follicular), (30, .follicular), (29, .follicular),
        (32, .ovulation), (31, .ovulation), (33, .ovulation),
        (29, .luteal), (30, .luteal), (28, .luteal),
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings,
        biomarkerId: "ferritin",
        displayName: "ferritin",
        unit: "ng/mL",
        cyclesTracked: 3
    )
    #expect(result.belowThreshold == nil)
    #expect(result.flaggedPhase == .menstrual, "menstrual phase should be flagged")
    #expect(result.totalReadings == 12)
    #expect(result.phaseStats.count == 4)
    if let menstrualMean = result.phaseStats.first(where: { $0.phase == .menstrual })?.mean {
        #expect(menstrualMean < 15, "menstrual mean should be the dip value (~12)")
    } else {
        Issue.record("menstrual phase missing from stats")
    }
}

// MARK: - analyze: no correlation

@Test func cycleBiomarker_analyze_noCorrelation() {
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (28, .menstrual), (29, .menstrual), (30, .menstrual),
        (29, .follicular), (28, .follicular), (30, .follicular),
        (29, .ovulation), (30, .ovulation), (28, .ovulation),
        (29, .luteal), (30, .luteal), (28, .luteal),
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings,
        biomarkerId: "ferritin",
        displayName: "ferritin",
        unit: "ng/mL",
        cyclesTracked: 3
    )
    #expect(result.belowThreshold == nil)
    #expect(result.flaggedPhase == nil, "no phase should be flagged when readings are uniform")
    #expect(result.phaseStats.count == 4)
}

// MARK: - analyze: insufficient data

@Test func cycleBiomarker_analyze_insufficientCycles() {
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (12, .menstrual), (28, .follicular)
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings,
        biomarkerId: "ferritin",
        displayName: "ferritin",
        unit: "ng/mL",
        cyclesTracked: 1
    )
    #expect(result.belowThreshold != nil, "single cycle should trigger below-threshold message")
    #expect(result.belowThreshold?.contains("more cycle") == true, "message should mention cycles needed")
    #expect(result.flaggedPhase == nil)
}

@Test func cycleBiomarker_analyze_insufficientTotalReadings() {
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (12, .menstrual), (28, .follicular), (29, .ovulation)
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings,
        biomarkerId: "ferritin",
        displayName: "ferritin",
        unit: "ng/mL",
        cyclesTracked: 3
    )
    #expect(result.belowThreshold != nil, "3 readings is below default min of 6")
    #expect(result.flaggedPhase == nil)
}

// MARK: - analyze: only one phase has min readings

@Test func cycleBiomarker_analyze_phasesWithoutMinAreSkipped() {
    // 3 menstrual + 1 each follicular/ovulation/luteal — only menstrual gets stats
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (12, .menstrual), (13, .menstrual), (11, .menstrual),
        (28, .follicular),
        (30, .ovulation),
        (29, .luteal),
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings,
        biomarkerId: "ferritin",
        displayName: "ferritin",
        unit: "ng/mL",
        cyclesTracked: 3
    )
    #expect(result.belowThreshold == nil)
    // With most readings clustered low and outliers high, menstrual (the lowest mean)
    // may or may not exceed 1 std below overall — assertion is on "no spurious flagging"
    let qualifyingPhases = result.phaseStats.map(\.phase)
    #expect(qualifyingPhases == [.menstrual], "only phases with >=3 readings should appear")
}

@Test func cycleBiomarker_format_singlePhaseCoverageReportsLackOfCoverage() {
    // 6 readings all in menstrual phase — can't show cycle correlation with 1 phase.
    // Regression: previously this hit the "fairly consistent across cycle phases" branch.
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (10, .menstrual), (11, .menstrual), (12, .menstrual),
        (10, .menstrual), (11, .menstrual), (12, .menstrual),
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings, biomarkerId: "ferritin",
        displayName: "ferritin", unit: "ng/mL", cyclesTracked: 3
    )
    #expect(result.flaggedPhase == nil)
    #expect(result.phaseStats.count == 1)
    let text = CycleBiomarkerInsight.formatResult(result)
    #expect(!text.contains("consistent across cycle phases"),
            "single-phase coverage must not claim across-phase consistency: \(text)")
    #expect(text.contains("phase coverage") || text.contains("at least 2 phases"),
            "should explain coverage gap: \(text)")
}

// MARK: - format

@Test func cycleBiomarker_format_belowThresholdPropagates() {
    let result = CycleBiomarkerInsight.analyze(
        readings: [(12, .menstrual)],
        biomarkerId: "ferritin",
        displayName: "ferritin",
        unit: "ng/mL",
        cyclesTracked: 0
    )
    let text = CycleBiomarkerInsight.formatResult(result)
    #expect(text.contains("more cycle"))
}

@Test func cycleBiomarker_format_flagsPhaseWithReadable() {
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (12, .menstrual), (11, .menstrual), (13, .menstrual),
        (28, .follicular), (30, .follicular), (29, .follicular),
        (32, .ovulation), (31, .ovulation), (33, .ovulation),
        (29, .luteal), (30, .luteal), (28, .luteal),
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings, biomarkerId: "ferritin",
        displayName: "ferritin", unit: "ng/mL", cyclesTracked: 3
    )
    let text = CycleBiomarkerInsight.formatResult(result)
    #expect(text.contains("ferritin"))
    #expect(text.contains("menstrual"))
    #expect(text.contains("ng/mL"))
    #expect(text.contains("12") || text.contains("12.0"), "phase mean should appear in output: \(text)")
}

@Test func cycleBiomarker_format_consistentMessageWhenNoFlag() {
    let readings: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = [
        (28, .menstrual), (29, .menstrual), (30, .menstrual),
        (29, .follicular), (28, .follicular), (30, .follicular),
        (29, .ovulation), (30, .ovulation), (28, .ovulation),
    ]
    let result = CycleBiomarkerInsight.analyze(
        readings: readings, biomarkerId: "ferritin",
        displayName: "ferritin", unit: "ng/mL", cyclesTracked: 3
    )
    let text = CycleBiomarkerInsight.formatResult(result)
    #expect(text.contains("consistent"), "no-flag message should mention consistency: \(text)")
}

// MARK: - normalizeBiomarkerId (tool input)

@Test func cycleBiomarker_normalizeBiomarkerId_aliases() {
    #expect(CycleBiomarkerInsightTool.normalizeBiomarkerId("vitamin D") == "vitamin_d")
    #expect(CycleBiomarkerInsightTool.normalizeBiomarkerId("Vit D") == "vitamin_d")
    #expect(CycleBiomarkerInsightTool.normalizeBiomarkerId("B12") == "vitamin_b12")
    #expect(CycleBiomarkerInsightTool.normalizeBiomarkerId("hb") == "hemoglobin")
    #expect(CycleBiomarkerInsightTool.normalizeBiomarkerId("ferritin") == "ferritin")
    #expect(CycleBiomarkerInsightTool.normalizeBiomarkerId("Vitamin B12") == "vitamin_b12")
}
