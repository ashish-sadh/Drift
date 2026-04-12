import SwiftUI

/// Apple Fitness-style concentric rings showing macro progress toward daily targets.
struct MacroRingsView: View {
    let calories: Double
    let calorieTarget: Double
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    private let lineWidth: CGFloat = 8
    private let ringGap: CGFloat = 3

    var body: some View {
        ZStack {
            ringLayer(value: calories, target: calorieTarget, color: Theme.calorieBlue, index: 0)
            ringLayer(value: protein, target: proteinTarget, color: Theme.proteinRed, index: 1)
            ringLayer(value: carbs, target: carbsTarget, color: Theme.carbsGreen, index: 2)
            ringLayer(value: fat, target: fatTarget, color: Theme.fatYellow, index: 3)

            // Center: remaining calories
            VStack(spacing: 1) {
                let remaining = Int(calorieTarget - calories)
                Text("\(abs(remaining))")
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                Text(remaining >= 0 ? "left" : "over")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var diameter: CGFloat { 140 }

    private func ringRadius(index: Int) -> CGFloat {
        let outerRadius = diameter / 2 - lineWidth / 2
        return outerRadius - CGFloat(index) * (lineWidth + ringGap)
    }

    private func ringLayer(value: Double, target: Double, color: Color, index: Int) -> some View {
        let radius = ringRadius(index: index)
        let progress = target > 0 ? min(value / target, 1.5) : 0

        return ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}
