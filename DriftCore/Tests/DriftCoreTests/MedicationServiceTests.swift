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
