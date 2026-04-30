import Foundation
@testable import DriftCore
import Testing

/// Tier-0: pure logic + in-memory DB. No network, no cloud.
struct HydrationServiceTests {

    // MARK: - parseMl

    @Test func parseMlPassthrough() {
        #expect(HydrationService.parseMl(amount: 500, unit: "ml") == 500)
        #expect(HydrationService.parseMl(amount: 500, unit: "") == 500)
    }

    @Test func parseMlLitres() {
        #expect(HydrationService.parseMl(amount: 1, unit: "l") == 1000)
        #expect(HydrationService.parseMl(amount: 1.5, unit: "litre") == 1500)
        #expect(HydrationService.parseMl(amount: 2, unit: "liters") == 2000)
    }

    @Test func parseMlOz() {
        let result = HydrationService.parseMl(amount: 8, unit: "oz")
        #expect(result != nil)
        #expect(result! > 230 && result! < 240)
    }

    @Test func parseMlCups() {
        #expect(HydrationService.parseMl(amount: 1, unit: "cup") == 240)
        #expect(HydrationService.parseMl(amount: 2, unit: "cups") == 480)
    }

    @Test func parseMlGlass() {
        #expect(HydrationService.parseMl(amount: 1, unit: "glass") == 250)
        #expect(HydrationService.parseMl(amount: 2, unit: "glasses") == 500)
    }

    @Test func parseMlBottle() {
        #expect(HydrationService.parseMl(amount: 1, unit: "bottle") == 500)
        #expect(HydrationService.parseMl(amount: 2, unit: "bottles") == 1000)
    }

    @Test func parseMlUnknownUnitReturnsNil() {
        #expect(HydrationService.parseMl(amount: 1, unit: "gallon") == nil)
        #expect(HydrationService.parseMl(amount: 1, unit: "spoon") == nil)
    }

    // MARK: - DB round-trip

    @Test func logWaterAndFetchTotal() throws {
        let db = try AppDatabase.empty()
        var entry = WaterEntry(date: "2024-01-15", amountMl: 300)
        try db.saveWaterEntry(&entry)
        #expect(entry.id != nil)

        let total = try db.fetchDailyWaterMl(for: "2024-01-15")
        #expect(total == 300)
    }

    @Test func multipleLogs_sumCorrectly() throws {
        let db = try AppDatabase.empty()
        for ml in [250.0, 300.0, 150.0] {
            var e = WaterEntry(date: "2024-01-15", amountMl: ml)
            try db.saveWaterEntry(&e)
        }
        let total = try db.fetchDailyWaterMl(for: "2024-01-15")
        #expect(total == 700)
    }

    @Test func totalIsolatedByDate() throws {
        let db = try AppDatabase.empty()
        var e1 = WaterEntry(date: "2024-01-15", amountMl: 500)
        var e2 = WaterEntry(date: "2024-01-16", amountMl: 800)
        try db.saveWaterEntry(&e1)
        try db.saveWaterEntry(&e2)
        #expect(try db.fetchDailyWaterMl(for: "2024-01-15") == 500)
        #expect(try db.fetchDailyWaterMl(for: "2024-01-16") == 800)
    }

    @Test func emptyDateReturnsZero() throws {
        let db = try AppDatabase.empty()
        #expect(try db.fetchDailyWaterMl(for: "2024-01-15") == 0)
    }

    @Test func deleteRemovesEntry() throws {
        let db = try AppDatabase.empty()
        var entry = WaterEntry(date: "2024-01-15", amountMl: 400)
        try db.saveWaterEntry(&entry)
        let id = try #require(entry.id)
        try db.deleteWaterEntry(id: id)
        #expect(try db.fetchDailyWaterMl(for: "2024-01-15") == 0)
    }
}
