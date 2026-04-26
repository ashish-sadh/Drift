import Foundation
@testable import DriftCore
import Testing

/// #282 — plain `Int()` truncation on small fiber values made 1.5g → "1g" and
/// 0.6g → "0g", which looked like data loss. These tests lock the
/// one-decimal-for-sub-10g behaviour so we don't regress back to a bare cast.

@Test func fiberZeroShowsZero() {
    #expect(MacroFormatter.fiber(0) == "0")
}

@Test func fiberWholeUnderTenShowsInteger() {
    #expect(MacroFormatter.fiber(1) == "1")
    #expect(MacroFormatter.fiber(3) == "3")
    #expect(MacroFormatter.fiber(9) == "9")
}

@Test func fiberFractionalUnderTenShowsOneDecimal() {
    #expect(MacroFormatter.fiber(1.5) == "1.5")
    #expect(MacroFormatter.fiber(2.3) == "2.3")
    #expect(MacroFormatter.fiber(0.5) == "0.5")
}

@Test func fiberSmallNonZeroRoundsToOneDecimal() {
    // 0.6 rounds to 0.6 (shown), not 0 — the original truncation bug.
    #expect(MacroFormatter.fiber(0.6) == "0.6")
    // 0.04 rounds down to 0.0, collapsed to "0".
    #expect(MacroFormatter.fiber(0.04) == "0")
}

@Test func fiberTenOrAboveShowsRoundedInteger() {
    #expect(MacroFormatter.fiber(10) == "10")
    #expect(MacroFormatter.fiber(12.4) == "12")
    #expect(MacroFormatter.fiber(12.6) == "13")
    #expect(MacroFormatter.fiber(25) == "25")
}

/// Regression for #282 specifically: user logs 75g strawberry, fiber should
/// render as "1.5g", not "0g" or "1g".
@Test func fiberSeventyFiveGramStrawberryShowsOnePointFive() {
    let fiberPerServing: Double = 3    // per 150g
    let servings: Double = 75.0 / 150.0
    let total = fiberPerServing * servings
    #expect(MacroFormatter.fiber(total) == "1.5")
}
