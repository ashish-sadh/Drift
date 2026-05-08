import XCTest
@testable import DriftCore

@MainActor
final class BehaviorInsightServiceTests: XCTestCase {

    // MARK: - proteinAdherenceAlertVariant

    func testFiresOnConsecutiveStreak3() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 3, loggedDays: 5, consecutiveStreak: 3,
            avgProtein: 55, proteinTarget: 120)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.dismissKey, "protein_streak")
        XCTAssertFalse(result?.isPositive ?? true)
    }

    func testFiresOnFourOfSeven() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 4, loggedDays: 7, consecutiveStreak: 1,
            avgProtein: 70, proteinTarget: 120)
        XCTAssertNotNil(result)
    }

    func testSilentBelow3Consecutive() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 2, loggedDays: 5, consecutiveStreak: 2,
            avgProtein: 100, proteinTarget: 120)
        XCTAssertNil(result)
    }

    func testSilentBelow4OfSeven() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 3, loggedDays: 7, consecutiveStreak: 0,
            avgProtein: 100, proteinTarget: 120)
        XCTAssertNil(result)
    }

    func testMessageContainsAvgAndTarget() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 5, loggedDays: 7, consecutiveStreak: 0,
            avgProtein: 63, proteinTarget: 140)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.detail.contains("63g"), "Should show avg protein consumed")
        XCTAssertTrue(result!.detail.contains("140g"), "Should show protein target")
    }

    func testMessageDescribesConsecutiveWhenStreakHigher() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 4, loggedDays: 7, consecutiveStreak: 4,
            avgProtein: 50, proteinTarget: 100)
        XCTAssertTrue(result!.detail.contains("4 days in a row"))
    }

    func testMessageDescribesFractionWhenNoStreak() {
        let result = BehaviorInsightService.proteinAdherenceAlertVariant(
            missedDays: 5, loggedDays: 7, consecutiveStreak: 1,
            avgProtein: 50, proteinTarget: 100)
        XCTAssertTrue(result!.detail.contains("5 of the last 7"))
    }

    // MARK: - glucoseSpikeAlertVariant

    func testGlucoseSpikeAlertFires() {
        let result = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 3, dataDays: 5)
        XCTAssertNotNil(result)
    }

    func testGlucoseSpikeAlertSilentInsufficientData() {
        let result = BehaviorInsightService.glucoseSpikeAlertVariant(spikeDays: 3, dataDays: 2)
        XCTAssertNil(result)
    }
}
