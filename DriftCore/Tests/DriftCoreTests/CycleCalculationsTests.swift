import XCTest
@testable import DriftCore

/// Tier-0 tests for CycleCalculations pure logic.
/// Run: cd DriftCore && swift test --filter CycleCalculationsTests
final class CycleCalculationsTests: XCTestCase {

    // MARK: - Helpers

    private let cal = Calendar.current

    private func date(_ daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: makeAnchor())!
    }

    private func makeAnchor() -> Date {
        var c = DateComponents()
        c.year = 2024; c.month = 6; c.day = 1
        return cal.date(from: c)!
    }

    private func entry(_ daysAgo: Int, flow: Int) -> CycleEntry {
        CycleEntry(date: date(daysAgo), flow: flow)
    }

    // MARK: - groupIntoPeriods

    func testGroupIntoPeriods_Empty() {
        XCTAssertTrue(CycleCalculations.groupIntoPeriods([]).isEmpty)
    }

    func testGroupIntoPeriods_ExcludesFlow5AndFlow0() {
        let entries = [entry(10, flow: 5), entry(9, flow: 0), entry(8, flow: 5)]
        XCTAssertTrue(CycleCalculations.groupIntoPeriods(entries).isEmpty,
            "flow 0 and 5 must be excluded")
    }

    func testGroupIntoPeriods_SingleEntry() {
        let periods = CycleCalculations.groupIntoPeriods([entry(5, flow: 2)])
        XCTAssertEqual(periods.count, 1)
        XCTAssertEqual(periods[0].days.count, 1)
    }

    func testGroupIntoPeriods_ConsecutiveDaysFormOnePeriod() {
        // Days 10, 9, 8, 7 — all within 3-day gap → one period
        let entries = [entry(10, flow: 2), entry(9, flow: 3), entry(8, flow: 3), entry(7, flow: 2)]
        let periods = CycleCalculations.groupIntoPeriods(entries)
        XCTAssertEqual(periods.count, 1)
        XCTAssertEqual(periods[0].days.count, 4)
    }

    func testGroupIntoPeriods_GapOver3DaysCreatesTwoPeriods() {
        // Period 1: days 30-28, Period 2: days 3-1 (24-day gap)
        let entries = [entry(30, flow: 3), entry(29, flow: 3), entry(28, flow: 2),
                       entry(3, flow: 2), entry(2, flow: 3), entry(1, flow: 2)]
        let periods = CycleCalculations.groupIntoPeriods(entries)
        XCTAssertEqual(periods.count, 2)
        XCTAssertEqual(periods[0].days.count, 3)
        XCTAssertEqual(periods[1].days.count, 3)
    }

    func testGroupIntoPeriods_Exactly3DayGapStaysSamePeriod() {
        // Gap of exactly 3 days — should remain same period
        let d1 = makeAnchor()
        let d2 = cal.date(byAdding: .day, value: 3, to: d1)!
        let entries = [CycleEntry(date: d1, flow: 2), CycleEntry(date: d2, flow: 2)]
        let periods = CycleCalculations.groupIntoPeriods(entries)
        XCTAssertEqual(periods.count, 1)
    }

    func testGroupIntoPeriods_4DayGapCreatesTwoPeriods() {
        let d1 = makeAnchor()
        let d2 = cal.date(byAdding: .day, value: 4, to: d1)!
        let entries = [CycleEntry(date: d1, flow: 2), CycleEntry(date: d2, flow: 2)]
        let periods = CycleCalculations.groupIntoPeriods(entries)
        XCTAssertEqual(periods.count, 2)
    }

    // MARK: - CyclePeriod.dominantFlow + display

    func testDominantFlow_NoValidFlows_Returns1() {
        let period = CyclePeriod(startDate: date(5), days: [entry(5, flow: 0), entry(4, flow: 5)])
        XCTAssertEqual(period.dominantFlow, 1)
    }

    func testDominantFlow_ReturnsMax() {
        let period = CyclePeriod(startDate: date(5),
                                  days: [entry(5, flow: 2), entry(4, flow: 4), entry(3, flow: 3)])
        XCTAssertEqual(period.dominantFlow, 4)
    }

    func testDominantFlowDisplay_AllCases() {
        func period(flow: Int) -> CyclePeriod {
            CyclePeriod(startDate: date(0), days: [entry(0, flow: flow)])
        }
        XCTAssertEqual(period(flow: 1).dominantFlowDisplay, "Unspecified")
        XCTAssertEqual(period(flow: 2).dominantFlowDisplay, "Light")
        XCTAssertEqual(period(flow: 3).dominantFlowDisplay, "Medium")
        XCTAssertEqual(period(flow: 4).dominantFlowDisplay, "Heavy")
    }

    // MARK: - cycleLengthsWithDates

    func testCycleLengthsWithDates_FewerThan2Periods_Empty() {
        let periods = [CyclePeriod(startDate: date(10), days: [entry(10, flow: 2)])]
        XCTAssertTrue(CycleCalculations.cycleLengthsWithDates(periods: periods).isEmpty)
    }

    func testCycleLengthsWithDates_TwoPeriods_CorrectLength() {
        let d1 = makeAnchor()
        let d2 = cal.date(byAdding: .day, value: 28, to: d1)!
        let p1 = CyclePeriod(startDate: d1, days: [CycleEntry(date: d1, flow: 2)])
        let p2 = CyclePeriod(startDate: d2, days: [CycleEntry(date: d2, flow: 2)])
        let lengths = CycleCalculations.cycleLengthsWithDates(periods: [p1, p2])
        XCTAssertEqual(lengths.count, 1)
        XCTAssertEqual(lengths[0].length, 28)
    }

    // MARK: - averageCycleLength

    func testAverageCycleLength_FewerThan2_Nil() {
        let period = CyclePeriod(startDate: date(0), days: [entry(0, flow: 2)])
        XCTAssertNil(CycleCalculations.averageCycleLength(periods: [period]))
    }

    func testAverageCycleLength_TwoPeriods() {
        let d1 = makeAnchor()
        let d2 = cal.date(byAdding: .day, value: 28, to: d1)!
        let d3 = cal.date(byAdding: .day, value: 56, to: d1)!
        let periods = [
            CyclePeriod(startDate: d1, days: [CycleEntry(date: d1, flow: 2)]),
            CyclePeriod(startDate: d2, days: [CycleEntry(date: d2, flow: 2)]),
            CyclePeriod(startDate: d3, days: [CycleEntry(date: d3, flow: 2)])
        ]
        XCTAssertEqual(CycleCalculations.averageCycleLength(periods: periods), 28)
    }

    // MARK: - currentCycleDay

    func testCurrentCycleDay_EmptyPeriods_Nil() {
        XCTAssertNil(CycleCalculations.currentCycleDay(periods: []))
    }

    func testCurrentCycleDay_SameDay_Returns1() {
        let now = makeAnchor()
        let period = CyclePeriod(startDate: now, days: [CycleEntry(date: now, flow: 2)])
        let day = CycleCalculations.currentCycleDay(periods: [period], now: now)
        XCTAssertEqual(day, 1)
    }

    func testCurrentCycleDay_14DaysLater_Returns15() {
        let start = makeAnchor()
        let now = cal.date(byAdding: .day, value: 14, to: start)!
        let period = CyclePeriod(startDate: start, days: [CycleEntry(date: start, flow: 2)])
        let day = CycleCalculations.currentCycleDay(periods: [period], now: now)
        XCTAssertEqual(day, 15)
    }

    // MARK: - ovulationDay

    func testOvulationDay_28DayCycle() {
        XCTAssertEqual(CycleCalculations.ovulationDay(cycleLength: 28), 14)
    }

    func testOvulationDay_ShortCycle_UsesHalf() {
        // 20 - 14 = 6, 20/2 = 10 → max is 10
        XCTAssertEqual(CycleCalculations.ovulationDay(cycleLength: 20), 10)
    }

    func testOvulationDay_LongCycle() {
        // 35 - 14 = 21, 35/2 = 17 → max is 21
        XCTAssertEqual(CycleCalculations.ovulationDay(cycleLength: 35), 21)
    }

    // MARK: - currentPhase

    func testCurrentPhase_Day1to5_Menstrual() {
        for day in 1...5 {
            XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: day, cycleLength: 28),
                           "Menstrual phase", "Day \(day) should be menstrual")
        }
    }

    func testCurrentPhase_Follicular() {
        // ovDay for 28 = 14; follicular is day 6 to day 12 (< 14-1=13)
        XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: 8, cycleLength: 28), "Follicular phase")
    }

    func testCurrentPhase_OvulationWindow() {
        // ovDay = 14; window is day 13 to day 15
        XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: 14, cycleLength: 28), "Ovulation window")
        XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: 13, cycleLength: 28), "Ovulation window")
        XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: 15, cycleLength: 28), "Ovulation window")
    }

    func testCurrentPhase_Luteal() {
        // After ovulation window (day 16+)
        XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: 20, cycleLength: 28), "Luteal phase")
    }

    func testCurrentPhase_Day6_Follicular() {
        XCTAssertEqual(CycleCalculations.currentPhase(cycleDay: 6, cycleLength: 28), "Follicular phase")
    }

    // MARK: - currentPhaseId

    func testCurrentPhaseId_AllCases() {
        XCTAssertEqual(CycleCalculations.currentPhaseId(cycleDay: 3, cycleLength: 28), "period")
        XCTAssertEqual(CycleCalculations.currentPhaseId(cycleDay: 8, cycleLength: 28), "follicular")
        XCTAssertEqual(CycleCalculations.currentPhaseId(cycleDay: 14, cycleLength: 28), "ovulation")
        XCTAssertEqual(CycleCalculations.currentPhaseId(cycleDay: 20, cycleLength: 28), "luteal")
    }
}
