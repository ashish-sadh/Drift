import Foundation
@testable import DriftCore
import Testing

// MARK: - Medication profile round-trip

@Test func medicationProfileSaveAssignsId() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "semaglutide", brandName: "Ozempic", doseAmount: 0.5, doseUnit: "mg", scheduleType: "weekly", startDate: "2026-04-28")
    try db.saveMedicationProfile(&m)
    #expect(m.id != nil)
}

@Test func medicationProfileRoundTrip() throws {
    let db = try AppDatabase.empty()
    var m = Medication(
        name: "metformin", brandName: nil, doseAmount: 500, doseUnit: "mg",
        scheduleType: "daily", reminderTime: "08:00", startDate: "2026-04-01",
        notes: "twice daily"
    )
    try db.saveMedicationProfile(&m)

    let all = try db.fetchActiveMedications()
    #expect(all.count == 1)
    let fetched = all[0]
    #expect(fetched.name == "metformin")
    #expect(fetched.brandName == nil)
    #expect(fetched.doseAmount == 500)
    #expect(fetched.doseUnit == "mg")
    #expect(fetched.scheduleType == "daily")
    #expect(fetched.reminderTime == "08:00")
    #expect(fetched.startDate == "2026-04-01")
    #expect(fetched.isActive == true)
    #expect(fetched.notes == "twice daily")
}

@Test func medicationActiveFilterExcludesArchived() throws {
    let db = try AppDatabase.empty()
    var active = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    var archived = Medication(name: "atorvastatin", doseAmount: 20, doseUnit: "mg", isActive: false)
    try db.saveMedicationProfile(&active)
    try db.saveMedicationProfile(&archived)

    let activeList = try db.fetchActiveMedications()
    #expect(activeList.count == 1)
    #expect(activeList[0].name == "metformin")

    let allList = try db.fetchAllMedications(includeArchived: true)
    #expect(allList.count == 2)
}

@Test func medicationFindByBrandOrGeneric() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "semaglutide", brandName: "Ozempic", doseAmount: 0.5, doseUnit: "mg", scheduleType: "weekly")
    try db.saveMedicationProfile(&m)

    let byBrand = try db.findMedication(named: "ozempic")
    let byGeneric = try db.findMedication(named: "Semaglutide")
    let miss = try db.findMedication(named: "wegovy")
    #expect(byBrand?.id == m.id)
    #expect(byGeneric?.id == m.id)
    #expect(miss == nil)
}

@Test func medicationFindPrefersActiveMatch() throws {
    let db = try AppDatabase.empty()
    var older = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg", isActive: false)
    var current = Medication(name: "metformin", doseAmount: 1000, doseUnit: "mg", isActive: true)
    try db.saveMedicationProfile(&older)
    try db.saveMedicationProfile(&current)

    let found = try db.findMedication(named: "metformin")
    #expect(found?.id == current.id)
    #expect(found?.doseAmount == 1000)
}

@Test func medicationDisplayNamePrefersBrand() {
    let withBrand = Medication(name: "semaglutide", brandName: "Ozempic", doseAmount: 0.5, doseUnit: "mg")
    let generic = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    let blankBrand = Medication(name: "atorvastatin", brandName: "", doseAmount: 20, doseUnit: "mg")
    #expect(withBrand.displayName == "Ozempic")
    #expect(generic.displayName == "Metformin")
    #expect(blankBrand.displayName == "Atorvastatin", "Empty-string brand should fall back to generic")
}

// MARK: - MedicationLog round-trip

@Test func medicationLogSaveAndFetch() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "semaglutide", brandName: "Ozempic", doseAmount: 0.5, doseUnit: "mg", scheduleType: "weekly")
    try db.saveMedicationProfile(&m)
    let mid = try #require(m.id)

    let now = ISO8601DateFormatter().string(from: Date())
    var log = MedicationLog(medicationId: mid, takenAt: now, sideEffects: "nausea")
    try db.saveMedicationLog(&log)
    #expect(log.id != nil)

    let logs = try db.fetchMedicationLogs(medicationId: mid, days: 30)
    #expect(logs.count == 1)
    #expect(logs[0].sideEffects == "nausea")
    #expect(logs[0].doseAmount == nil, "nil dose means 'used prescribed'")
}

@Test func medicationLogDoseOverride() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "semaglutide", doseAmount: 0.5, doseUnit: "mg", scheduleType: "weekly")
    try db.saveMedicationProfile(&m)
    let mid = try #require(m.id)

    let now = ISO8601DateFormatter().string(from: Date())
    var log = MedicationLog(medicationId: mid, takenAt: now, doseAmount: 0.25)
    try db.saveMedicationLog(&log)

    let logs = try db.fetchMedicationLogs(medicationId: mid)
    #expect(logs.count == 1)
    #expect(logs[0].doseAmount == 0.25)
}

@Test func medicationLogOrderingNewestFirst() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    try db.saveMedicationProfile(&m)
    let mid = try #require(m.id)

    let fmt = ISO8601DateFormatter()
    let now = Date()
    let older = fmt.string(from: now.addingTimeInterval(-3600))
    let newer = fmt.string(from: now)

    var l1 = MedicationLog(medicationId: mid, takenAt: older)
    var l2 = MedicationLog(medicationId: mid, takenAt: newer)
    try db.saveMedicationLog(&l1)
    try db.saveMedicationLog(&l2)

    let logs = try db.fetchMedicationLogs(medicationId: mid)
    #expect(logs.count == 2)
    #expect(logs[0].takenAt == newer)
    #expect(logs[1].takenAt == older)
}

@Test func medicationLogDaysWindowCutsOldLogs() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    try db.saveMedicationProfile(&m)
    let mid = try #require(m.id)

    let fmt = ISO8601DateFormatter()
    let ancient = fmt.string(from: Date().addingTimeInterval(-86_400 * 100))   // 100 days back
    let recent = fmt.string(from: Date().addingTimeInterval(-86_400 * 5))      // 5 days back

    var l1 = MedicationLog(medicationId: mid, takenAt: ancient)
    var l2 = MedicationLog(medicationId: mid, takenAt: recent)
    try db.saveMedicationLog(&l1)
    try db.saveMedicationLog(&l2)

    let recent30 = try db.fetchMedicationLogs(medicationId: mid, days: 30)
    #expect(recent30.count == 1)
    #expect(recent30[0].takenAt == recent)

    let recent365 = try db.fetchMedicationLogs(medicationId: mid, days: 365)
    #expect(recent365.count == 2)
}

@Test func medicationLogCascadeOnProfileDelete() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    try db.saveMedicationProfile(&m)
    let mid = try #require(m.id)

    let now = ISO8601DateFormatter().string(from: Date())
    var log = MedicationLog(medicationId: mid, takenAt: now)
    try db.saveMedicationLog(&log)

    try db.deleteMedicationProfile(id: mid)
    let logs = try db.fetchMedicationLogs(medicationId: mid)
    #expect(logs.isEmpty, "FK cascade should drop the log when its medication is deleted")
}

@Test func fetchAllMedicationLogsAcrossMeds() throws {
    let db = try AppDatabase.empty()
    var a = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    var b = Medication(name: "semaglutide", brandName: "Ozempic", doseAmount: 0.5, doseUnit: "mg", scheduleType: "weekly")
    try db.saveMedicationProfile(&a)
    try db.saveMedicationProfile(&b)

    let now = ISO8601DateFormatter().string(from: Date())
    var la = MedicationLog(medicationId: a.id!, takenAt: now)
    var lb = MedicationLog(medicationId: b.id!, takenAt: now)
    try db.saveMedicationLog(&la)
    try db.saveMedicationLog(&lb)

    let all = try db.fetchAllMedicationLogs()
    #expect(all.count == 2)
}

@Test func medicationLogDeleteRemovesRow() throws {
    let db = try AppDatabase.empty()
    var m = Medication(name: "metformin", doseAmount: 500, doseUnit: "mg")
    try db.saveMedicationProfile(&m)
    let mid = try #require(m.id)

    let now = ISO8601DateFormatter().string(from: Date())
    var log = MedicationLog(medicationId: mid, takenAt: now)
    try db.saveMedicationLog(&log)
    let lid = try #require(log.id)

    try db.deleteMedicationLog(id: lid)
    #expect(try db.fetchMedicationLogs(medicationId: mid).isEmpty)
}

// MARK: - Codec round-trip (defensive — ensures column mapping holds)

@Test func medicationCodingKeysMapSnakeCase() throws {
    let db = try AppDatabase.empty()
    var m = Medication(
        name: "metformin", brandName: "Glucophage", doseAmount: 500, doseUnit: "mg",
        scheduleType: "daily", reminderTime: "08:00", reminderDay: nil,
        startDate: "2026-04-01", isActive: true, notes: "with food"
    )
    try db.saveMedicationProfile(&m)
    // Re-fetch from a separate read to bypass any in-memory caching.
    let all = try db.fetchAllMedications()
    let fetched = try #require(all.first)
    #expect(fetched.brandName == "Glucophage")
    #expect(fetched.reminderTime == "08:00")
    #expect(fetched.startDate == "2026-04-01")
}
