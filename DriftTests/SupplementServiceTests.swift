import Foundation
import Testing
@testable import Drift

// MARK: - SupplementService Tests

@Test @MainActor func supplementServiceGetStatusReturnsString() {
    let result = SupplementService.getStatus()
    #expect(!result.isEmpty)
    // Either "No supplements set up." or a taken/remaining breakdown
    #expect(result.contains("supplement") || result.contains("Supplement"))
}

@Test @MainActor func supplementServiceMarkTakenUnknownName() {
    let result = SupplementService.markTaken(name: "xyzzy_unknown_supplement_zzz")
    #expect(result.contains("Couldn't find") || result.contains("No supplements"))
}

@Test @MainActor func supplementServiceAddNewSupplement() {
    let name = "TestSupp_Coverage_\(UUID().uuidString.prefix(8))"
    let result = SupplementService.addSupplement(name: name)
    #expect(result.contains("Added"), "Should confirm new supplement was added")
    #expect(result.contains(name.capitalized))
}

@Test @MainActor func supplementServiceAddDuplicateReturnsAlreadyInStack() {
    let name = "TestSupp_Dup_\(UUID().uuidString.prefix(8))"
    _ = SupplementService.addSupplement(name: name)
    let result = SupplementService.addSupplement(name: name)
    #expect(result.contains("already in your stack"))
}

@Test @MainActor func supplementServiceAddSupplementWithDosage() {
    let name = "TestSupp_Dosage_\(UUID().uuidString.prefix(8))"
    let result = SupplementService.addSupplement(name: name, dosage: "500mg")
    #expect(result.contains("Added"))
    #expect(result.contains("500mg"))
}

@Test @MainActor func supplementServiceGetStatusAfterAddReflectsNewEntry() {
    let name = "TestSupp_Status_\(UUID().uuidString.prefix(8))"
    _ = SupplementService.addSupplement(name: name)
    let status = SupplementService.getStatus()
    // After adding, there's at least 1 supplement — should not say "No supplements set up."
    #expect(!status.contains("No supplements set up."))
}
