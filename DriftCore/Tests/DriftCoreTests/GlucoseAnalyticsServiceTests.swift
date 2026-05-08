import Foundation
import Testing
@testable import DriftCore

// MARK: - GlucoseAnalyticsServiceTests (Tier 0)
// Pure logic tests — no DB, all data supplied inline.

private func makeReading(minutesFromNow: Double, mgdl: Double, base: Date = Date()) -> GlucoseReading {
    let ts = base.addingTimeInterval(minutesFromNow * 60)
    return GlucoseReading(timestamp: DateFormatters.iso8601.string(from: ts), glucoseMgdl: mgdl)
}

private func makeEntry(minutesFromNow: Double, food: String, base: Date = Date()) -> FoodEntry {
    let ts = base.addingTimeInterval(minutesFromNow * 60)
    let iso = DateFormatters.iso8601.string(from: ts)
    return FoodEntry(
        mealLogId: 0, foodName: food, servingSizeG: 100, servings: 1,
        calories: 200, proteinG: 5, carbsG: 40, fatG: 2, fiberG: 1,
        createdAt: iso, loggedAt: iso, date: nil
    )
}

// MARK: detectSpikes

@Test func detectSpikes_aboveThreshold_returnsEvent() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 90, base: base),   // baseline
        makeReading(minutesFromNow: 60, mgdl: 145, base: base),  // peak (+55)
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Rice", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.count == 1)
    #expect(spikes[0].foodName == "Rice")
    #expect(spikes[0].deltaMgdl > 30)
}

@Test func detectSpikes_belowThreshold_noEvent() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 90, base: base),
        makeReading(minutesFromNow: 60, mgdl: 115, base: base),  // +25, below 30
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Salad", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.isEmpty)
}

@Test func detectSpikes_exactThreshold_noEvent() {
    // Delta of exactly 30 should NOT fire (>30, not >=30)
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 100, base: base),
        makeReading(minutesFromNow: 30, mgdl: 130, base: base),  // exactly +30
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Oats", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.isEmpty)
}

@Test func detectSpikes_noReadingsBefore_skipped() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: 60, mgdl: 150, base: base),  // only post-meal reading
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Bread", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.isEmpty)
}

@Test func detectSpikes_noReadingsAfter_skipped() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -10, mgdl: 90, base: base),  // only pre-meal reading
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Dal", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.isEmpty)
}

@Test func detectSpikes_peakOutside2hWindow_notCounted() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 90, base: base),
        makeReading(minutesFromNow: 150, mgdl: 160, base: base), // 2.5h after — outside window
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Pizza", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.isEmpty)
}

@Test func detectSpikes_multipleReadings_usesPeak() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 90, base: base),
        makeReading(minutesFromNow: 30, mgdl: 110, base: base),
        makeReading(minutesFromNow: 60, mgdl: 145, base: base),  // peak
        makeReading(minutesFromNow: 90, mgdl: 120, base: base),
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Biryani", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    #expect(spikes.count == 1)
    #expect(spikes[0].peakMgdl == 145)
    #expect(spikes[0].baselineMgdl == 90)
}

// MARK: spikingFoods

@Test func spikingFoods_requiresMinTwoObservations() {
    let base = Date()
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 90, base: base),
        makeReading(minutesFromNow: 60, mgdl: 140, base: base),
    ]
    let entries = [makeEntry(minutesFromNow: 0, food: "Rice", base: base)]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    let foods = GlucoseAnalyticsService.spikingFoods(from: spikes)
    #expect(foods.isEmpty) // only 1 observation — filtered out
}

@Test func spikingFoods_twoObservations_returned() {
    let base = Date()
    let meal1 = base
    let meal2 = base.addingTimeInterval(6 * 3600) // 6h later
    let readings = [
        makeReading(minutesFromNow: -5, mgdl: 90, base: meal1),
        makeReading(minutesFromNow: 60, mgdl: 135, base: meal1),
        makeReading(minutesFromNow: -5, mgdl: 95, base: meal2),
        makeReading(minutesFromNow: 60, mgdl: 145, base: meal2),
    ]
    let entries = [
        makeEntry(minutesFromNow: 0, food: "Dal makhani", base: meal1),
        makeEntry(minutesFromNow: 0, food: "Dal makhani", base: meal2),
    ]
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: entries, readings: readings)
    let foods = GlucoseAnalyticsService.spikingFoods(from: spikes)
    #expect(foods.count == 1)
    #expect(foods[0].foodName == "dal makhani")
    #expect(foods[0].spikeCount == 2)
}

@Test func spikingFoods_sortedBySpikeCountThenDelta() {
    // food A: 3 spikes, food B: 2 spikes — A should come first
    let base = Date()
    let spikeA1 = GlucoseAnalyticsService.SpikeEvent(foodName: "A", mealTime: base, baselineMgdl: 90, peakMgdl: 135)
    let spikeA2 = GlucoseAnalyticsService.SpikeEvent(foodName: "A", mealTime: base, baselineMgdl: 90, peakMgdl: 130)
    let spikeA3 = GlucoseAnalyticsService.SpikeEvent(foodName: "A", mealTime: base, baselineMgdl: 90, peakMgdl: 132)
    let spikeB1 = GlucoseAnalyticsService.SpikeEvent(foodName: "B", mealTime: base, baselineMgdl: 90, peakMgdl: 150)
    let spikeB2 = GlucoseAnalyticsService.SpikeEvent(foodName: "B", mealTime: base, baselineMgdl: 90, peakMgdl: 155)
    let foods = GlucoseAnalyticsService.spikingFoods(from: [spikeA1, spikeA2, spikeA3, spikeB1, spikeB2])
    #expect(foods.count == 2)
    #expect(foods[0].foodName == "a") // 3 spikes > 2 spikes
    #expect(foods[1].foodName == "b")
}

@Test func detectSpikes_emptyInputs_returnsEmpty() {
    let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: [], readings: [])
    #expect(spikes.isEmpty)
}

@Test func spikingFoods_emptyInput_returnsEmpty() {
    let foods = GlucoseAnalyticsService.spikingFoods(from: [])
    #expect(foods.isEmpty)
}
