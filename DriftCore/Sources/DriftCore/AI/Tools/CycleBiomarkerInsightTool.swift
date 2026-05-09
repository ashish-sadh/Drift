import Foundation
import DriftCore

@MainActor
public enum CycleBiomarkerInsightTool {

    nonisolated static let toolName = "cycle_biomarker_correlation"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.cycle_biomarker_correlation",
            name: toolName,
            service: "insights",
            description: "User asks whether a biomarker shifts with their menstrual cycle — 'does my iron drop during my period?', 'is my ferritin worse in luteal phase?', 'how does vitamin D track with my cycle?'. Joins lab biomarker history to cycle phase.",
            parameters: [
                ToolParam("biomarker", "string", "Specific biomarker to check (ferritin, iron, vitamin_d, hemoglobin, vitamin_b12). Optional — if omitted, picks the first one with enough data.", required: false),
                ToolParam("window_days", "number", "Cycle history window in days (default 365)", required: false)
            ],
            handler: { params in
                let biomarker = params.string("biomarker")?.lowercased()
                let window = max(60, min(730, params.int("window_days") ?? 365))
                return .text(await run(biomarker: biomarker, windowDays: window))
            }
        )
    }

    // MARK: - Entry point

    public static func run(biomarker: String?, windowDays: Int) async -> String {
        guard let hk = DriftPlatform.health else {
            return "Cycle data isn't available yet. Connect Apple Health to enable cycle-aware insights."
        }
        guard let cycleHistory = try? await hk.fetchCycleHistory(days: windowDays), !cycleHistory.isEmpty else {
            return "No cycle history found. Track your period in the Health app and re-ask once a cycle or two are recorded."
        }
        let periods = CycleCalculations.groupIntoPeriods(cycleHistory)
        // groupIntoPeriods filters HK flow values to 1...4 — entries where the
        // user logged "none" (5) yield zero periods even though cycleHistory was
        // non-empty. Surface the same message as "no flow recorded" so we don't
        // mislead the user with a "track 2 more cycles" nudge.
        guard !periods.isEmpty else {
            return "No cycle history found. Track your period in the Health app and re-ask once a cycle or two are recorded."
        }
        let cyclesTracked = max(0, periods.count - 1) // first period anchors; cycles = transitions
        let avgLength = CycleCalculations.averageCycleLength(periods: periods) ?? 28
        let periodStarts = periods.map(\.startDate)

        let labReports = BiomarkerService.fetchLabReports()
        guard !labReports.isEmpty else {
            return "No lab reports yet. Upload one via Biomarkers and re-ask."
        }
        let reportDateById: [Int64: Date] = Dictionary(
            labReports.compactMap { r -> (Int64, Date)? in
                guard let id = r.id, let date = DateFormatters.dateOnly.date(from: r.reportDate) else { return nil }
                return (id, date)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let targets = biomarker.map { [normalizeBiomarkerId($0)] } ?? CycleBiomarkerInsight.candidateBiomarkerIds

        var fallback: CycleBiomarkerInsight.CorrelationResult? = nil
        for id in targets {
            let results = BiomarkerService.fetchBiomarkerResults(forBiomarkerId: id)
            guard !results.isEmpty else { continue }

            var pairs: [(value: Double, phase: CycleBiomarkerInsight.Phase)] = []
            for r in results {
                guard let date = reportDateById[r.reportId],
                      let phase = CycleBiomarkerInsight.phase(forDate: date, periodStarts: periodStarts, cycleLength: avgLength) else { continue }
                pairs.append((value: r.normalizedValue, phase: phase))
            }

            let display = CycleBiomarkerInsight.displayName[id] ?? id
            let unit = results.first?.normalizedUnit ?? ""
            let result = CycleBiomarkerInsight.analyze(
                readings: pairs,
                biomarkerId: id,
                displayName: display,
                unit: unit,
                cyclesTracked: cyclesTracked
            )

            if biomarker != nil || result.belowThreshold == nil {
                return CycleBiomarkerInsight.formatResult(result)
            }
            // Hold on to the first below-threshold result so we can return a real
            // explanation if no candidate ends up having enough data.
            if fallback == nil { fallback = result }
        }

        if let fallback {
            return CycleBiomarkerInsight.formatResult(fallback)
        }
        return "No biomarker readings overlap your tracked cycles yet. Upload a lab report dated within the cycle history window."
    }

    nonisolated static func normalizeBiomarkerId(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "vitamin d", "vit d", "vitd", "25-oh", "25(oh)d": return "vitamin_d"
        case "vitamin b12", "vit b12", "b12", "cobalamin": return "vitamin_b12"
        case "hb", "haemoglobin": return "hemoglobin"
        default:
            return lower.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
        }
    }
}
