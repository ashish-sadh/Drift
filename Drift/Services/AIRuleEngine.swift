import Foundation

/// Rule-based health insights — works without the AI model.
/// Used as fallback when model isn't downloaded, and to enrich AI responses.
enum AIRuleEngine {

    /// Generate a quick insight based on today's data.
    static func quickInsight() -> String? {
        let today = DateFormatters.todayString

        // Check food logged
        guard let nutrition = try? AppDatabase.shared.fetchDailyNutrition(for: today) else { return nil }

        if nutrition.calories == 0 {
            return "You haven't logged any food today. Tap \"Log breakfast\" to get started."
        }

        // Weight trend
        if let entries = try? AppDatabase.shared.fetchWeightEntries() {
            let input = entries.map { (date: $0.date, weightKg: $0.weightKg) }
            if let trend = WeightTrendCalculator.calculateTrend(entries: input) {
                let rate = trend.weeklyRateKg
                let deficit = trend.estimatedDailyDeficit

                if rate < -0.1 {
                    let lbsPerWeek = abs(rate) * 2.20462
                    return String(format: "You're losing about %.1f lbs/week. Today you've eaten %d calories so far.", lbsPerWeek, Int(nutrition.calories))
                } else if rate > 0.1 {
                    return "Your weight is trending up. You've eaten \(Int(nutrition.calories)) calories today."
                } else {
                    return "Weight is stable. You've eaten \(Int(nutrition.calories)) calories today with \(Int(nutrition.proteinG))g protein."
                }
            }
        }

        return "You've logged \(Int(nutrition.calories)) calories today with \(Int(nutrition.proteinG))g protein."
    }

    /// Suggest what to do next based on gaps in today's data.
    static func nextAction() -> String? {
        let today = DateFormatters.todayString
        let nutrition = (try? AppDatabase.shared.fetchDailyNutrition(for: today)) ?? .zero

        let hour = Calendar.current.component(.hour, from: Date())

        if nutrition.calories == 0 {
            if hour < 11 { return "Log your breakfast to start tracking today." }
            if hour < 15 { return "Don't forget to log your meals — what did you have for lunch?" }
            return "It's getting late — try to log what you ate today."
        }

        if nutrition.proteinG < 50 && hour > 15 {
            return "Your protein is at \(Int(nutrition.proteinG))g — consider a high-protein dinner or snack."
        }

        // Check if workout logged today
        if let workouts = try? WorkoutService.fetchWorkouts(limit: 5) {
            let todayWorkouts = workouts.filter { $0.date == today }
            if todayWorkouts.isEmpty && hour > 10 {
                return "No workout logged today. Want to start one?"
            }
        }

        return nil
    }
}
