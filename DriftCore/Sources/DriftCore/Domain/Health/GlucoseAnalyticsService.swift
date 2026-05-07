import Foundation

/// Pure-logic glucose spike analysis. Detects post-meal glucose spikes and
/// ranks foods by their association with spikes. No DB access — callers supply data.
///
/// Algorithm:
/// - Baseline = last glucose reading at or before meal time
/// - Peak = max glucose reading in the 2 hours after meal time
/// - Spike = peak − baseline > spikeThreshold (default 30 mg/dL)
public enum GlucoseAnalyticsService {

    public static let spikeThreshold: Double = 30

    public struct SpikeEvent: Sendable {
        public let foodName: String
        public let mealTime: Date
        public let baselineMgdl: Double
        public let peakMgdl: Double
        public var deltaMgdl: Double { peakMgdl - baselineMgdl }
    }

    public struct FoodSpikeRecord: Sendable {
        public let foodName: String
        public let spikeCount: Int
        public let avgDeltaMgdl: Double
    }

    // MARK: - Spike detection

    /// Detects per-meal glucose spikes. One SpikeEvent per meal that crosses the threshold.
    /// Requires at least one glucose reading before and at least one within 2h after each meal.
    nonisolated public static func detectSpikes(
        foodEntries: [FoodEntry],
        readings: [GlucoseReading],
        threshold: Double = spikeThreshold
    ) -> [SpikeEvent] {
        let fmt = DateFormatters.iso8601
        let twoHours: TimeInterval = 2 * 3600

        let parsed: [(date: Date, mgdl: Double)] = readings.compactMap { r in
            guard let d = fmt.date(from: r.timestamp) else { return nil }
            return (d, r.glucoseMgdl)
        }
        guard !parsed.isEmpty else { return [] }

        var events: [SpikeEvent] = []

        for entry in foodEntries {
            guard let mealTime = fmt.date(from: entry.loggedAt) else { continue }
            let foodName = entry.foodName.trimmingCharacters(in: .whitespaces)
            guard !foodName.isEmpty else { continue }

            // Baseline: last reading at or before meal time
            guard let baseline = parsed
                .filter({ $0.date <= mealTime })
                .max(by: { $0.date < $1.date })
            else { continue }

            // Peak: max reading within 2h after meal
            let postReadings = parsed.filter {
                $0.date > mealTime && $0.date <= mealTime.addingTimeInterval(twoHours)
            }
            guard let peak = postReadings.max(by: { $0.mgdl < $1.mgdl }) else { continue }

            let delta = peak.mgdl - baseline.mgdl
            if delta > threshold {
                events.append(SpikeEvent(
                    foodName: foodName,
                    mealTime: mealTime,
                    baselineMgdl: baseline.mgdl,
                    peakMgdl: peak.mgdl
                ))
            }
        }

        return events
    }

    // MARK: - Food ranking

    /// Aggregates spike events by food name. Requires ≥ 2 spike observations per food.
    /// Returns foods ranked by spike count descending, then avg delta descending.
    nonisolated public static func spikingFoods(from spikes: [SpikeEvent]) -> [FoodSpikeRecord] {
        var groups: [String: [Double]] = [:]
        for spike in spikes {
            let key = spike.foodName.lowercased()
            groups[key, default: []].append(spike.deltaMgdl)
        }
        return groups
            .compactMap { name, deltas -> FoodSpikeRecord? in
                guard deltas.count >= 2 else { return nil }
                let avg = deltas.reduce(0, +) / Double(deltas.count)
                return FoodSpikeRecord(foodName: name, spikeCount: deltas.count, avgDeltaMgdl: avg)
            }
            .sorted { lhs, rhs in
                lhs.spikeCount != rhs.spikeCount
                    ? lhs.spikeCount > rhs.spikeCount
                    : lhs.avgDeltaMgdl > rhs.avgDeltaMgdl
            }
    }
}
