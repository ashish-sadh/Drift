import Foundation
@testable import DriftCore
import Testing

// MARK: - MedicationService Tests

@Test @MainActor func medicationServiceLogCreatesEntry() {
    let name = "TestMed_\(UUID().uuidString.prefix(8))"
    let result = MedicationService.logMedication(name: name, doseMg: 0.5, doseUnit: "mg")
    #expect(result.contains(name.capitalized))
    #expect(result.contains("0.5mg"))
}

@Test @MainActor func medicationServiceLogWithoutDose() {
    let name = "TestNoDose_\(UUID().uuidString.prefix(8))"
    let result = MedicationService.logMedication(name: name, doseMg: nil, doseUnit: nil)
    #expect(result.contains(name.capitalized))
    #expect(!result.contains("("))
}

@Test @MainActor func medicationServiceLogWholeDoseOmitsDecimal() {
    let result = MedicationService.logMedication(name: "Metformin", doseMg: 500, doseUnit: "mg")
    #expect(result.contains("500mg"), "Whole-number doses must not show decimal: got '\(result)'")
    #expect(!result.contains("500.0"))
}

@Test @MainActor func medicationServiceTodayMedicationsReturnsLogged() {
    let name = "TodayMed_\(UUID().uuidString.prefix(8))"
    _ = MedicationService.logMedication(name: name, doseMg: 1, doseUnit: "mg")
    let today = MedicationService.todayMedications()
    #expect(today.contains(where: { $0.name == name.capitalized }))
}

@Test @MainActor func medicationServiceMultipleLogsAccumulate() {
    let countBefore = MedicationService.todayMedications().count
    _ = MedicationService.logMedication(name: "DrugA_\(UUID().uuidString.prefix(4))", doseMg: nil, doseUnit: nil)
    _ = MedicationService.logMedication(name: "DrugB_\(UUID().uuidString.prefix(4))", doseMg: nil, doseUnit: nil)
    let countAfter = MedicationService.todayMedications().count
    #expect(countAfter == countBefore + 2)
}

@Test @MainActor func medicationServiceLogCapitalizesName() {
    let result = MedicationService.logMedication(name: "ozempic", doseMg: 0.5, doseUnit: "mg")
    #expect(result.contains("Ozempic"))
}

// MARK: - lastDoseTime

@Test @MainActor func lastDoseTimeReturnsNilForUnknownMedication() {
    let result = MedicationService.lastDoseTime(for: "NonExistentMed_\(UUID().uuidString)")
    #expect(result == nil)
}

@Test @MainActor func lastDoseTimeReturnsDateAfterLogging() {
    let name = "DoseTimeMed_\(UUID().uuidString.prefix(8))"
    let before = Date()
    _ = MedicationService.logMedication(name: name, doseMg: 1, doseUnit: "mg")
    let result = MedicationService.lastDoseTime(for: name)
    #expect(result != nil)
    #expect(result! >= before.addingTimeInterval(-1))
}

@Test @MainActor func lastDoseTimeReturnsLatestOfMultipleLogs() {
    let name = "MultiDoseMed_\(UUID().uuidString.prefix(8))"
    let before = Date()
    _ = MedicationService.logMedication(name: name, doseMg: 1, doseUnit: "mg")
    _ = MedicationService.logMedication(name: name, doseMg: 2, doseUnit: "mg")
    let result = MedicationService.lastDoseTime(for: name)
    #expect(result != nil)
    // ISO8601 storage truncates to second precision — allow 1s tolerance
    #expect(result!.timeIntervalSince(before) >= -1.0)
}

// MARK: - recentDoseHours

@Test @MainActor func recentDoseHoursReturnsEmptyForUnknownMedication() {
    let result = MedicationService.recentDoseHours(for: "Ghost_\(UUID().uuidString)")
    #expect(result.isEmpty)
}

@Test @MainActor func recentDoseHoursReturnsHourAfterLogging() {
    let name = "HourMed_\(UUID().uuidString.prefix(8))"
    _ = MedicationService.logMedication(name: name, doseMg: nil, doseUnit: nil)
    let hours = MedicationService.recentDoseHours(for: name)
    #expect(!hours.isEmpty)
    #expect(hours.allSatisfy { $0 >= 0 && $0 < 24 })
}

// MARK: - consistentMedicationNames

@Test @MainActor func consistentMedicationNamesRequiresMinLogs() {
    let name = "SparseMed_\(UUID().uuidString.prefix(8))"
    _ = MedicationService.logMedication(name: name, doseMg: nil, doseUnit: nil)
    // Only 1 log — should not appear in consistent list (minLogs=3)
    let consistent = MedicationService.consistentMedicationNames(days: 30, minLogs: 3)
    #expect(!consistent.contains(name.capitalized))
}

@Test @MainActor func consistentMedicationNamesAppearsAfterMinLogs() {
    let name = "FreqMed_\(UUID().uuidString.prefix(8))"
    for _ in 0..<3 {
        _ = MedicationService.logMedication(name: name, doseMg: nil, doseUnit: nil)
    }
    let consistent = MedicationService.consistentMedicationNames(days: 30, minLogs: 3)
    #expect(consistent.contains(name.capitalized))
}
