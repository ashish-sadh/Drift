import SwiftUI

/// Shared styling for consistent dark UI.
enum Theme {

    // MARK: - Surface Colors

    /// Near-black with neutral warmth — premium without the blue cast.
    static let background = Color(hex: "0E0E12")
    /// Card surface — warm dark gray, clearly distinct from background.
    static let cardBackground = Color(hex: "1A1B24")
    /// Elevated card surface — modals, popovers, selected states.
    static let cardBackgroundElevated = Color(hex: "242530")
    /// Subtle separator/border color.
    static let separator = Color.white.opacity(0.06)

    // MARK: - Brand & Accent

    /// Primary accent — warm violet. CTAs, nav highlights, active states.
    static let accent = Color(hex: "8B7CF6")
    /// Secondary accent — warm coral for variety without clashing.
    static let accentSecondary = Color(hex: "FF6B8A")

    // MARK: - Semantic Colors

    /// Aligned with goal direction (weight loss → green, weight gain → green).
    static let deficit = Color(hex: "34D399")
    /// Against goal direction.
    static let surplus = Color(hex: "EF4444")

    // MARK: - Macro Colors

    static let calorieBlue = Color(hex: "3B82F6")
    static let proteinRed = Color(hex: "EF4444")
    static let carbsGreen = Color(hex: "22C55E")
    static let fatYellow = Color(hex: "EAB308")
    static let fiberBrown = Color(hex: "A16207")

    // MARK: - Domain Colors

    static let sleepIndigo = Color(hex: "818CF8")
    static let stepsOrange = Color(hex: "F97316")
    static let heartRed = Color(hex: "F43F5E")
    static let rhythmTeal = Color(hex: "2DD4BF")
    static let plantGreen = Color(hex: "4ADE80")
    static let cyclePink = Color(hex: "F472B6")
    static let supplementMint = Color(hex: "34D399")

    // MARK: - Text Colors

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    // MARK: - Typography

    static let fontLargeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let fontTitle = Font.system(size: 20, weight: .bold, design: .rounded)
    static let fontHeadline = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let fontBody = Font.system(size: 15, weight: .regular, design: .default)
    static let fontCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let fontStat = Font.system(size: 22, weight: .bold, design: .rounded).monospacedDigit()

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 14
    static let spacingLG: CGFloat = 20
    static let spacingXL: CGFloat = 28

    // MARK: - Card

    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16

    // MARK: - Score Helpers

    /// Continuous color for a 0-100 score (red -> yellow -> green).
    static func scoreColor(_ score: Int) -> Color {
        if score >= 67 { return deficit }
        if score >= 34 { return fatYellow }
        return surplus
    }

    /// Gradient for score progress bars.
    static let scoreGradient = LinearGradient(
        colors: [surplus, fatYellow, deficit],
        startPoint: .leading, endPoint: .trailing
    )

    /// Accent gradient for hero elements.
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Card View Modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .strokeBorder(Theme.separator, lineWidth: 0.5)
            )
    }
}

extension View {
    func card() -> some View {
        modifier(CardStyle())
    }
}
