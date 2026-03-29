import Foundation
import HealthKit

/// Service managing all HealthKit interactions.
/// Runs on MainActor to simplify concurrency with UI layer.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    // MARK: - Types to read/write

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let basalEnergy = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(basalEnergy) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let energy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(energy) }
        if let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein) { types.insert(protein) }
        if let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) { types.insert(carbs) }
        if let fat = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) { types.insert(fat) }
        if let fiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber) { types.insert(fiber) }
        return types
    }

    // MARK: - Authorization

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: - Weight Sync

    func syncWeight() async throws -> Int {
        guard isAvailable,
              let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return 0 }

        let database = AppDatabase.shared
        let anchor = try loadAnchor(for: "bodyMass", database: database)

        let (samples, newAnchor) = try await queryAnchoredWeight(type: weightType, anchor: anchor)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var count = 0
        for sample in samples {
            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let dateString = formatter.string(from: sample.startDate)

            var entry = WeightEntry(
                date: dateString,
                weightKg: kg,
                source: "healthkit",
                syncedFromHk: true
            )
            try database.saveWeightEntry(&entry)
            count += 1
        }

        if let newAnchor {
            try saveAnchor(newAnchor, for: "bodyMass", database: database)
        }

        return count
    }

    private func queryAnchoredWeight(type: HKQuantityType, anchor: HKQueryAnchor?) async throws -> ([HKQuantitySample], HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, added, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let samples = (added ?? []).compactMap { $0 as? HKQuantitySample }
                continuation.resume(returning: (samples, newAnchor))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Energy Burned

    func fetchCaloriesBurned(for date: Date) async throws -> (active: Double, basal: Double) {
        async let active = fetchDaySum(typeIdentifier: .activeEnergyBurned, for: date)
        async let basal = fetchDaySum(typeIdentifier: .basalEnergyBurned, for: date)
        return try await (active, basal)
    }

    func fetchSteps(for date: Date) async throws -> Double {
        try await fetchDaySum(typeIdentifier: .stepCount, for: date, unit: .count())
    }

    func fetchSleepHours(for date: Date) async throws -> Double {
        guard isAvailable,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let previousEvening = calendar.date(byAdding: .hour, value: -12, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: previousEvening, end: startOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let totalSeconds = (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: totalSeconds / 3600)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Write Nutrition

    func writeNutrition(calories: Double, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double, date: Date) async throws {
        guard isAvailable else { return }

        var samples: [HKQuantitySample] = []

        func addSample(_ identifier: HKQuantityTypeIdentifier, value: Double, unit: HKUnit) {
            guard value > 0, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
            samples.append(sample)
        }

        addSample(.dietaryEnergyConsumed, value: calories, unit: .kilocalorie())
        addSample(.dietaryProtein, value: proteinG, unit: .gram())
        addSample(.dietaryCarbohydrates, value: carbsG, unit: .gram())
        addSample(.dietaryFatTotal, value: fatG, unit: .gram())
        addSample(.dietaryFiber, value: fiberG, unit: .gram())

        guard !samples.isEmpty else { return }
        try await healthStore.save(samples)
    }

    // MARK: - Helpers

    private func fetchDaySum(typeIdentifier: HKQuantityTypeIdentifier, for date: Date, unit: HKUnit = .kilocalorie()) async throws -> Double {
        guard isAvailable,
              let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private nonisolated func loadAnchor(for dataType: String, database: AppDatabase) throws -> HKQueryAnchor? {
        guard let data = try database.fetchAnchor(dataType: dataType) else { return nil }
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private nonisolated func saveAnchor(_ anchor: HKQueryAnchor, for dataType: String, database: AppDatabase) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        try database.saveAnchor(dataType: dataType, anchor: data)
    }
}
