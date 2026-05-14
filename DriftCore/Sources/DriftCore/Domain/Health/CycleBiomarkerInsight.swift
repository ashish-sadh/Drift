import Foundation

/// Pure analytical layer that joins biomarker readings to menstrual cycle phase.
/// All functions are deterministic and Sendable — no DB/HealthKit access lives here.
public enum CycleBiomarkerInsight {

    public enum Phase: String, Sendable, CaseIterable {
        case menstrual
        case follicular
        case ovulation
        case luteal

        public var displayName: String {
            switch self {
            case .menstrual: "menstrual phase"
            case .follicular: "follicular phase"
            case .ovulation: "ovulation window"
            case .luteal: "luteal phase"
            }
        }
    }

    /// Biomarkers we currently expose to this insight. Order = preference when no
    /// biomarker is named — first one with enough data wins.
    public static let candidateBiomarkerIds: [String] = [
        "ferritin",
        "iron",
        "vitamin_d",
        "hemoglobin",
        "vitamin_b12",
    ]

    public static let displayName: [String: String] = [
        "ferritin": "ferritin",
        "iron": "iron",
        "vitamin_d": "vitamin D",
        "hemoglobin": "hemoglobin",
        "vitamin_b12": "B12",
    ]

    // MARK: - Phase classification

    /// Classify a date against a sorted list of period start dates and an
    /// average cycle length. Returns nil when the date is before the first
    /// recorded period or further than `cycleLength + 10` days past the last.
    nonisolated public static func phase(forDate date: Date, periodStarts: [Date], cycleLength: Int) -> Phase? {
        guard !periodStarts.isEmpty else { return nil }
        let sorted = periodStarts.sorted()
        guard let lastStart = sorted.last(where: { $0 <= date }) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastStart, to: date).day ?? 0
        let cycleDay = days + 1
        if cycleDay > cycleLength + 10 { return nil }
        return phaseFor(cycleDay: cycleDay, cycleLength: cycleLength)
    }

    /// Mirror of `CycleCalculations.currentPhase` but typed.
    nonisolated public static func phaseFor(cycleDay: Int, cycleLength: Int) -> Phase {
        if cycleDay <= 5 { return .menstrual }
        let ovDay = max(cycleLength - 14, cycleLength / 2)
        if cycleDay < ovDay - 1 { return .follicular }
        if cycleDay <= ovDay + 1 { return .ovulation }
        return .luteal
    }

    // MARK: - Analysis

    public struct PhaseStats: Sendable, Equatable {
        public let phase: Phase
        public let count: Int
        public let mean: Double
    }

    public enum FlagDirection: String, Sendable {
        case drop
        case rise
    }

    public struct CorrelationResult: Sendable {
        public let biomarkerId: String
        public let displayName: String
        public let unit: String
        public let totalReadings: Int
        public let cyclesTracked: Int
        public let overallMean: Double
        public let overallStd: Double
        public let phaseStats: [PhaseStats]
        public let flaggedPhase: Phase?
        public let flaggedMean: Double?
        public let flaggedCount: Int?
        public let flaggedDirection: FlagDirection?
        public let belowThreshold: String?
    }

    /// Pure analysis. Tests pass synthetic `(value, phase)` tuples directly.
    nonisolated public static func analyze(
        readings: [(value: Double, phase: Phase)],
        biomarkerId: String,
        displayName: String,
        unit: String,
        cyclesTracked: Int,
        minReadingsPerPhase: Int = 3,
        minCycles: Int = 2,
        minTotalReadings: Int = 6
    ) -> CorrelationResult {
        if cyclesTracked < minCycles {
            let cyclesNeeded = max(0, minCycles - cyclesTracked)
            return belowThresholdResult(
                biomarkerId: biomarkerId, displayName: displayName, unit: unit,
                totalReadings: readings.count, cyclesTracked: cyclesTracked,
                reason: "I need more data — track \(cyclesNeeded) more cycle\(cyclesNeeded == 1 ? "" : "s") and re-upload your labs."
            )
        }
        if readings.count < minTotalReadings {
            return belowThresholdResult(
                biomarkerId: biomarkerId, displayName: displayName, unit: unit,
                totalReadings: readings.count, cyclesTracked: cyclesTracked,
                reason: "Only \(readings.count) \(displayName) reading\(readings.count == 1 ? "" : "s") line up with your cycle history. Need at least \(minTotalReadings) — upload more lab reports."
            )
        }

        let values = readings.map(\.value)
        let overallMean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - overallMean, 2) }.reduce(0, +) / Double(values.count)
        let std = variance.squareRoot()

        let grouped = Dictionary(grouping: readings, by: \.phase)
        var stats: [PhaseStats] = []
        // Flag the phase with the largest absolute deviation from the overall
        // mean — drop or rise — provided it exceeds 1 std. Tracks count so the
        // formatter can show "across N readings in <phase>" honestly.
        var flagged: (phase: Phase, mean: Double, count: Int, deviation: Double, direction: FlagDirection)? = nil

        for phase in Phase.allCases {
            let vs = grouped[phase]?.map(\.value) ?? []
            guard vs.count >= minReadingsPerPhase else { continue }
            let mean = vs.reduce(0, +) / Double(vs.count)
            stats.append(PhaseStats(phase: phase, count: vs.count, mean: mean))
            guard std > 0 else { continue }

            let signedDeviation = mean - overallMean
            let absDeviation = abs(signedDeviation)
            guard absDeviation > std else { continue }

            let direction: FlagDirection = signedDeviation < 0 ? .drop : .rise
            if flagged == nil || absDeviation > flagged!.deviation {
                flagged = (phase, mean, vs.count, absDeviation, direction)
            }
        }

        return CorrelationResult(
            biomarkerId: biomarkerId,
            displayName: displayName,
            unit: unit,
            totalReadings: readings.count,
            cyclesTracked: cyclesTracked,
            overallMean: overallMean,
            overallStd: std,
            phaseStats: stats,
            flaggedPhase: flagged?.phase,
            flaggedMean: flagged?.mean,
            flaggedCount: flagged?.count,
            flaggedDirection: flagged?.direction,
            belowThreshold: nil
        )
    }

    nonisolated private static func belowThresholdResult(
        biomarkerId: String, displayName: String, unit: String,
        totalReadings: Int, cyclesTracked: Int, reason: String
    ) -> CorrelationResult {
        CorrelationResult(
            biomarkerId: biomarkerId, displayName: displayName, unit: unit,
            totalReadings: totalReadings, cyclesTracked: cyclesTracked,
            overallMean: 0, overallStd: 0,
            phaseStats: [],
            flaggedPhase: nil, flaggedMean: nil,
            flaggedCount: nil, flaggedDirection: nil,
            belowThreshold: reason
        )
    }

    // MARK: - Formatting

    nonisolated public static func formatResult(_ r: CorrelationResult) -> String {
        if let reason = r.belowThreshold { return reason }

        if let phase = r.flaggedPhase,
           let phaseMean = r.flaggedMean,
           let phaseCount = r.flaggedCount,
           let direction = r.flaggedDirection {
            let phaseLabel = phase.displayName
            let phaseStr = formatValue(phaseMean, unit: r.unit)
            let overallStr = formatValue(r.overallMean, unit: r.unit)
            let verb = direction == .drop ? "drop" : "rise"
            let readingNoun = phaseCount == 1 ? "reading" : "readings"
            return "Your \(r.displayName) tends to \(verb) during \(phaseLabel) (mean \(phaseStr) across \(phaseCount) \(readingNoun) vs your overall \(overallStr) across \(r.totalReadings) total)."
        }

        // "Fairly consistent" only earns its message when at least 2 phases
        // qualified. With 0 or 1 qualifying phases the data can't yet show
        // *anything* about cycle correlation — say so explicitly.
        if r.phaseStats.count < 2 {
            return "Your \(r.displayName) doesn't have enough phase coverage yet — readings exist but at least 3 per phase are needed across at least 2 phases to spot a pattern."
        }

        let overallStr = formatValue(r.overallMean, unit: r.unit)
        return "Your \(r.displayName) is fairly consistent across cycle phases (overall \(overallStr), \(r.totalReadings) readings across \(r.phaseStats.count) phases)."
    }

    nonisolated static func formatValue(_ value: Double, unit: String) -> String {
        let rounded = (value * 10).rounded() / 10
        let str = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
        return unit.isEmpty ? str : "\(str) \(unit)"
    }
}
