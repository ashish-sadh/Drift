import XCTest
import SwiftUI
@testable import Drift

/// Tier-1 constructs / source-guard tests for the V6 hero rings.
///
/// V6Rings is the first piece of the V6 visual evolution (issue #782) — Apple
/// Fitness-style 3 concentric rings that replace the legacy MacroRingsView in
/// the Dashboard's calorieBalanceCard. These tests assert that:
/// 1. The component constructs across the relevant value regimes (under, at,
///    over target) and with optional center content.
/// 2. The Dashboard call-site actually uses V6Rings — so a future refactor
///    can't silently revert the hero back to MacroRingsView.
/// 3. The V6 palette tokens stay namespaced under `Theme.V6` so the dark
///    legacy palette and the new light/Apple-Fitness palette remain separable.
final class V6RingsTests: XCTestCase {

    // MARK: - V6Rings constructs

    func testV6RingsUnderTargetConstructs() {
        let rings = sampleRings(kcal: 1450, protein: 95, fiber: 18)
        let view = V6Rings(rings: rings, size: 200, stroke: 18)
        XCTAssertNotNil(view)
        XCTAssertEqual(view.rings.count, 3)
    }

    func testV6RingsAtTargetConstructs() {
        let rings = sampleRings(kcal: 2000, protein: 150, fiber: 30)
        let view = V6Rings(rings: rings)
        XCTAssertNotNil(view)
    }

    func testV6RingsOvershootConstructs() {
        // Overshoot triggers the second halo arc — must construct cleanly even
        // when the value is double the target.
        let rings = sampleRings(kcal: 4000, protein: 320, fiber: 60)
        let view = V6Rings(rings: rings)
        XCTAssertNotNil(view)
    }

    func testV6RingsZeroTargetIsSafe() {
        // Defensive: a zero target shouldn't divide-by-zero the trim().
        let ring = V6Ring(label: "kcal", unit: "", value: 100, target: 0,
                          color: Theme.V6.ringMove, trackColor: Theme.V6.ringMoveBg)
        let view = V6Rings(rings: [ring])
        XCTAssertNotNil(view)
    }

    func testV6RingsNonFiniteValuesAreSafe() {
        // NaN/inf compare false to everything — without the explicit isFinite
        // guard in ringLayer, the ring would silently render zero. We can't
        // assert against the rendered arc directly, but we can confirm the
        // view constructs without crashing on bad numerics. The Tier-0
        // safety lives in V6Rings.ringLayer itself (safeValue/safeTarget).
        let ring = V6Ring(label: "kcal", unit: "", value: .nan, target: .infinity,
                          color: Theme.V6.ringMove, trackColor: Theme.V6.ringMoveBg)
        let view = V6Rings(rings: [ring])
        XCTAssertNotNil(view)
    }

    func testV6RingIdIsLabelNotUUID() {
        // Stable ForEach identity matters: parents rebuild [V6Ring] every body
        // pass, and a per-init UUID would churn ring identity each render.
        let a = V6Ring(label: "kcal", unit: "", value: 1, target: 2,
                       color: Theme.V6.ringMove, trackColor: Theme.V6.ringMoveBg)
        let b = V6Ring(label: "kcal", unit: "", value: 999, target: 999,
                       color: Theme.V6.ringMove, trackColor: Theme.V6.ringMoveBg)
        XCTAssertEqual(a.id, b.id, "Two rings with the same label must share id so SwiftUI keeps stable identity across rebuilds.")
        XCTAssertEqual(a.id, "kcal")
    }

    func testV6RingsAcceptsCenterContent() {
        let rings = sampleRings(kcal: 1450, protein: 95, fiber: 18)
        let view = V6Rings(
            rings: rings,
            center: AnyView(Text("1,450"))
        )
        XCTAssertNotNil(view)
    }

    // MARK: - V6RingLegend constructs

    func testV6RingLegendConstructs() {
        let rings = sampleRings(kcal: 1450, protein: 95, fiber: 18)
        let legend = V6RingLegend(rings: rings)
        XCTAssertNotNil(legend)
        XCTAssertEqual(legend.rings.count, 3)
    }

    func testV6RingLegendTwoColumnsConstructs() {
        let carbs = V6Ring(label: "carbs", unit: "g", value: 180, target: 250,
                           color: Theme.V6.ringCarbs, trackColor: Theme.V6.ringCarbsBg)
        let fat = V6Ring(label: "fat", unit: "g", value: 55, target: 70,
                         color: Theme.V6.ringFat, trackColor: Theme.V6.ringFatBg)
        let legend = V6RingLegend(rings: [carbs, fat], columns: 2)
        XCTAssertNotNil(legend)
    }

    // MARK: - Theme palette guards

    func testThemeV6PaletteIsAdditiveAndNamespaced() {
        // V6 colors must live under `Theme.V6` so the legacy dark palette
        // (Theme.calorieBlue, Theme.proteinRed, ...) stays untouched until
        // the runtime light/dark switch lands. If these references stop
        // compiling, the palette has been moved or renamed — update both
        // the call sites and this guard intentionally.
        _ = Theme.V6.ringMove
        _ = Theme.V6.ringEx
        _ = Theme.V6.ringStand
        _ = Theme.V6.ringCarbs
        _ = Theme.V6.ringFat

        // Legacy dark palette must STILL exist — V6 is additive, not a
        // replacement, in this PR.
        _ = Theme.calorieBlue
        _ = Theme.proteinRed
        _ = Theme.carbsGreen
        _ = Theme.fatYellow
    }

    // MARK: - Source-guard: dashboard hero uses V6Rings

    /// Pins the call-site swap. Ensures a future "boy scout" refactor of
    /// DashboardView+Cards.swift can't silently restore MacroRingsView as
    /// the hero — V6 evolution is one-way per the permanent task.
    func testDashboardCalorieBalanceCardUsesV6Rings() throws {
        let source = try projectFile(
            "Drift", "Views", "Dashboard", "DashboardView+Cards.swift"
        )
        let content = try String(contentsOf: source, encoding: .utf8)
        XCTAssertTrue(
            content.contains("v6RingsHero(targets:"),
            "calorieBalanceCard must call v6RingsHero(targets:) for the goal-set hero (issue #782 V6 evolution)."
        )
        XCTAssertTrue(
            content.contains("V6Rings("),
            "v6RingsHero must instantiate V6Rings; raw MacroRingsView is no longer the hero."
        )
        XCTAssertFalse(
            content.contains("MacroRingsView("),
            "calorieBalanceCard must not instantiate MacroRingsView — V6Rings replaced it (#782)."
        )
    }

    // MARK: - Helpers

    private func sampleRings(kcal: Double, protein: Double, fiber: Double) -> [V6Ring] {
        [
            V6Ring(label: "kcal", unit: "", value: kcal, target: 2000,
                   color: Theme.V6.ringMove, trackColor: Theme.V6.ringMoveBg),
            V6Ring(label: "protein", unit: "g", value: protein, target: 150,
                   color: Theme.V6.ringEx, trackColor: Theme.V6.ringExBg),
            V6Ring(label: "fiber", unit: "g", value: fiber, target: 30,
                   color: Theme.V6.ringStand, trackColor: Theme.V6.ringStandBg),
        ]
    }

    private func projectFile(_ components: String...) throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        var url = testFile
            .deletingLastPathComponent()  // DriftTests/
            .deletingLastPathComponent()  // <project root>
        for c in components { url.appendPathComponent(c) }
        return url
    }
}
