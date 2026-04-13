import Foundation
import Testing
@testable import Drift

// MARK: - groupIntoPeriods Tests

@Test func cycleGroupPeriodsEmpty() async throws {
    let result = CycleCalculations.groupIntoPeriods([])
    #expect(result.isEmpty)
}

@Test func cycleGroupPeriodsSingleEntry() async throws {
    let entry = HealthKitService.CycleEntry(date: Date(), flow: 2)
    let result = CycleCalculations.groupIntoPeriods([entry])
    #expect(result.count == 1)
    #expect(result[0].days.count == 1)
}

@Test func cycleGroupPeriodsGap3DaysSamePeriod() async throws {
    let cal = Calendar.current
    let d1 = cal.date(byAdding: .day, value: -5, to: Date())!
    let d2 = cal.date(byAdding: .day, value: -2, to: Date())! // 3 days later
    let entries = [
        HealthKitService.CycleEntry(date: d1, flow: 2),
        HealthKitService.CycleEntry(date: d2, flow: 1),
    ]
    let result = CycleCalculations.groupIntoPeriods(entries)
    #expect(result.count == 1, "3-day gap should be same period, got \(result.count)")
}

@Test func cycleGroupPeriodsGap4DaysSplits() async throws {
    let cal = Calendar.current
    let d1 = cal.date(byAdding: .day, value: -10, to: Date())!
    let d2 = cal.date(byAdding: .day, value: -6, to: Date())! // 4 days later
    let entries = [
        HealthKitService.CycleEntry(date: d1, flow: 2),
        HealthKitService.CycleEntry(date: d2, flow: 2),
    ]
    let result = CycleCalculations.groupIntoPeriods(entries)
    #expect(result.count == 2, "4-day gap should split into 2 periods, got \(result.count)")
}

@Test func cycleGroupPeriodsFiltersInvalidFlow() async throws {
    let cal = Calendar.current
    // HK: 0=notApplicable, 5=none — both should be excluded. 1-4 included.
    let entries = [
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -3, to: Date())!, flow: 0),
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -2, to: Date())!, flow: 2),
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!, flow: 5),
    ]
    let result = CycleCalculations.groupIntoPeriods(entries)
    #expect(result.count == 1)
    #expect(result[0].days.count == 1, "Only flow=2 (light) should be included, 0 and 5 excluded")
}

@Test func cycleGroupPeriodsIncludesHeavyFlow() async throws {
    let cal = Calendar.current
    let entries = [
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -3, to: Date())!, flow: 2), // light
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -2, to: Date())!, flow: 4), // heavy
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!, flow: 3), // medium
    ]
    let result = CycleCalculations.groupIntoPeriods(entries)
    #expect(result.count == 1)
    #expect(result[0].days.count == 3, "Should include heavy flow (4)")
    #expect(result[0].dominantFlow == 4, "Dominant should be heavy (4)")
}

@Test func cycleGroupPeriodsUnsortedInput() async throws {
    let cal = Calendar.current
    let d1 = cal.date(byAdding: .day, value: -5, to: Date())!
    let d2 = cal.date(byAdding: .day, value: -4, to: Date())!
    let d3 = cal.date(byAdding: .day, value: -3, to: Date())!
    // Pass in reverse order
    let entries = [
        HealthKitService.CycleEntry(date: d3, flow: 1),
        HealthKitService.CycleEntry(date: d1, flow: 3),
        HealthKitService.CycleEntry(date: d2, flow: 2),
    ]
    let result = CycleCalculations.groupIntoPeriods(entries)
    #expect(result.count == 1)
    #expect(result[0].days.count == 3)
    #expect(result[0].startDate == d1, "Should sort by date")
}

// MARK: - averageCycleLength Tests

@Test func cycleAverageLengthVaryingCycles() async throws {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())  // midnight — avoids DST edge cases
    // 3 periods: 28 days apart, then 30 days apart
    let p1Start = cal.date(byAdding: .day, value: -63, to: today)!
    let p2Start = cal.date(byAdding: .day, value: -35, to: today)! // 28 days gap
    let p3Start = cal.date(byAdding: .day, value: -5, to: today)!  // 30 days gap

    let entries = [p1Start, p2Start, p3Start].flatMap { start in
        (0..<5).map { day in
            HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: day, to: start)!, flow: 2)
        }
    }
    let periods = CycleCalculations.groupIntoPeriods(entries)
    let avg = CycleCalculations.averageCycleLength(periods: periods)
    #expect(avg == 29, "Average of 28 and 30 should be 29, got \(avg ?? -1)")
}

@Test func cycleAverageLengthSinglePeriodNil() async throws {
    let entry = HealthKitService.CycleEntry(date: Date(), flow: 2)
    let periods = CycleCalculations.groupIntoPeriods([entry])
    #expect(CycleCalculations.averageCycleLength(periods: periods) == nil)
}

// MARK: - currentCycleDay Tests

@Test func cycleCurrentDayBasic() async throws {
    let cal = Calendar.current
    let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: Date())!
    let entries = (0..<5).map { day in
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: day, to: tenDaysAgo)!, flow: 2)
    }
    let periods = CycleCalculations.groupIntoPeriods(entries)
    let day = CycleCalculations.currentCycleDay(periods: periods)
    #expect(day == 11, "10 days ago + 1 = day 11, got \(day ?? -1)")
}

// MARK: - ovulationDay Tests

@Test func cycleOvulationDay28() async throws {
    #expect(CycleCalculations.ovulationDay(cycleLength: 28) == 14)
}

@Test func cycleOvulationDay30() async throws {
    #expect(CycleCalculations.ovulationDay(cycleLength: 30) == 16)
}

@Test func cycleOvulationDay26() async throws {
    #expect(CycleCalculations.ovulationDay(cycleLength: 26) == 13)
}

// MARK: - currentPhase Tests

@Test func cyclePhaseDay3IsMenstrual() async throws {
    #expect(CycleCalculations.currentPhase(cycleDay: 3, cycleLength: 28) == "Menstrual phase")
}

@Test func cyclePhaseDay8IsFollicular() async throws {
    #expect(CycleCalculations.currentPhase(cycleDay: 8, cycleLength: 28) == "Follicular phase")
}

@Test func cyclePhaseDay14IsOvulation() async throws {
    let phase = CycleCalculations.currentPhase(cycleDay: 14, cycleLength: 28)
    #expect(phase == "Ovulation window", "Day 14 of 28 should be ovulation, got \(phase ?? "nil")")
}

@Test func cyclePhaseDay20IsLuteal() async throws {
    #expect(CycleCalculations.currentPhase(cycleDay: 20, cycleLength: 28) == "Luteal phase")
}

// MARK: - dominantFlowDisplay Tests

@Test func cycleDominantFlowDisplayLight() async throws {
    let cal = Calendar.current
    let entries = [
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -2, to: Date())!, flow: 2),
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!, flow: 2),
    ]
    let periods = CycleCalculations.groupIntoPeriods(entries)
    #expect(periods[0].dominantFlowDisplay == "Light")
}

@Test func cycleDominantFlowDisplayMedium() async throws {
    let cal = Calendar.current
    let entries = [
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -2, to: Date())!, flow: 2),
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!, flow: 3),
    ]
    let periods = CycleCalculations.groupIntoPeriods(entries)
    #expect(periods[0].dominantFlowDisplay == "Medium")
}

@Test func cycleDominantFlowDisplayHeavy() async throws {
    let cal = Calendar.current
    let entries = [
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -2, to: Date())!, flow: 4),
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!, flow: 3),
    ]
    let periods = CycleCalculations.groupIntoPeriods(entries)
    #expect(periods[0].dominantFlowDisplay == "Heavy")
}

@Test func cycleDominantFlowDisplayUnspecified() async throws {
    let cal = Calendar.current
    let entries = [
        HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!, flow: 1),
    ]
    let periods = CycleCalculations.groupIntoPeriods(entries)
    #expect(periods[0].dominantFlowDisplay == "Unspecified")
}

// MARK: - cycleLengthsWithDates Tests

@Test func cycleLengthsWithDatesBasic() async throws {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let p1Start = cal.date(byAdding: .day, value: -56, to: today)!
    let p2Start = cal.date(byAdding: .day, value: -28, to: today)!

    let entries = [p1Start, p2Start].flatMap { start in
        (0..<4).map { day in
            HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: day, to: start)!, flow: 2)
        }
    }
    let periods = CycleCalculations.groupIntoPeriods(entries)
    let lengths = CycleCalculations.cycleLengthsWithDates(periods: periods)
    #expect(lengths.count == 1)
    #expect(lengths[0].length == 28)
    #expect(lengths[0].label == DateFormatters.shortDisplay.string(from: p1Start))
}

@Test func cycleLengthsWithDatesSinglePeriodEmpty() async throws {
    let entries = [
        HealthKitService.CycleEntry(date: Date(), flow: 2),
    ]
    let periods = CycleCalculations.groupIntoPeriods(entries)
    let lengths = CycleCalculations.cycleLengthsWithDates(periods: periods)
    #expect(lengths.isEmpty, "Single period should produce no lengths")
}

@Test func cycleLengthsWithDatesThreePeriods() async throws {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let p1 = cal.date(byAdding: .day, value: -65, to: today)!
    let p2 = cal.date(byAdding: .day, value: -35, to: today)!
    let p3 = cal.date(byAdding: .day, value: -5, to: today)!

    let entries = [p1, p2, p3].flatMap { start in
        (0..<3).map { day in
            HealthKitService.CycleEntry(date: cal.date(byAdding: .day, value: day, to: start)!, flow: 3)
        }
    }
    let periods = CycleCalculations.groupIntoPeriods(entries)
    let lengths = CycleCalculations.cycleLengthsWithDates(periods: periods)
    #expect(lengths.count == 2)
    #expect(lengths[0].length == 30)
    #expect(lengths[1].length == 30)
}

// MARK: - currentPhaseId Tests

@Test func cyclePhaseIdPeriod() async throws {
    #expect(CycleCalculations.currentPhaseId(cycleDay: 3, cycleLength: 28) == "period")
    #expect(CycleCalculations.currentPhaseId(cycleDay: 5, cycleLength: 28) == "period")
}

@Test func cyclePhaseIdFollicular() async throws {
    #expect(CycleCalculations.currentPhaseId(cycleDay: 8, cycleLength: 28) == "follicular")
}

@Test func cyclePhaseIdOvulation() async throws {
    #expect(CycleCalculations.currentPhaseId(cycleDay: 14, cycleLength: 28) == "ovulation")
}

@Test func cyclePhaseIdLuteal() async throws {
    #expect(CycleCalculations.currentPhaseId(cycleDay: 20, cycleLength: 28) == "luteal")
}
