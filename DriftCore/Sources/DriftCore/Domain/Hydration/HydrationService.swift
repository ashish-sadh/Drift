import Foundation

public enum HydrationService {

    /// Log a water intake entry for today. Returns the updated daily total in ml.
    @discardableResult
    public static func logWater(amountMl: Double, source: String = "manual") throws -> Double {
        let today = DateFormatters.todayString
        var entry = WaterEntry(date: today, amountMl: amountMl, source: source)
        try AppDatabase.shared.saveWaterEntry(&entry)
        return try AppDatabase.shared.fetchDailyWaterMl(for: today)
    }

    /// Today's total water intake in ml.
    public static func dailyTotalMl() throws -> Double {
        try AppDatabase.shared.fetchDailyWaterMl(for: DateFormatters.todayString)
    }

    /// Parse a user-supplied amount string into millilitres.
    /// Returns nil when the input is unrecognisable.
    ///
    /// Handles: "500ml", "500 ml", "2 cups", "1L", "1 litre", "8oz", "a glass", "250"
    public static func parseMl(amount: Double, unit: String) -> Double? {
        switch unit.lowercased().trimmingCharacters(in: .whitespaces) {
        case "ml", "milliliter", "millilitre", "milliliters", "millilitres", "":
            return amount
        case "l", "liter", "litre", "liters", "litres":
            return amount * 1000
        case "oz", "fl oz", "fluid oz", "fluid ounce", "fluid ounces", "ounce", "ounces":
            return amount * 29.5735
        case "cup", "cups":
            return amount * 240
        case "glass", "glasses":
            return amount * 250
        case "bottle", "bottles":
            return amount * 500
        default:
            return nil
        }
    }
}
