import Foundation
@testable import DriftCore
import Testing

/// Calibration gold set for `IntentThresholds.shouldClarify`. #302.
///
/// The policy is a small truth table; these tests are its ground truth. A
/// change to any threshold must either (a) update a specific named test here
/// or (b) be caught by the drift-sensitivity test at the bottom. Both are
/// intentional: we want future tuning to be visible and deliberate, not a
/// silent regression.
///
/// Organization — one test per domain, 10+ pass-through + 10+ clarify cases,
/// covering the most common shapes from the IntentRoutingEval gold set plus
/// adversarial edge cases.

// MARK: - Shared helpers

private func shouldClarify(_ tool: String, _ confidence: String, _ complete: Bool)
    -> IntentThresholds.Decision
{
    IntentThresholds.shouldClarify(
        tool: tool, confidence: confidence, hasCompleteParams: complete
    )
}

// MARK: - Domain mapping

@Test func domainMapping_coversAllClassifierTools() {
    // Tools listed in IntentClassifier.systemPrompt should each land in a
    // specific (non-.other) domain. If a tool is added there, add it to
    // `IntentDomain.of` too.
    let toolDomains: [(String, IntentDomain)] = [
        ("log_food", .food),
        ("food_info", .food),
        ("edit_meal", .food),
        ("delete_food", .food),
        ("copy_yesterday", .food),
        ("explain_calories", .food),
        ("log_weight", .weight),
        ("weight_info", .weight),
        ("set_goal", .weight),
        ("start_workout", .exercise),
        ("log_activity", .exercise),
        ("exercise_info", .exercise),
        ("sleep_recovery", .exercise),
        ("mark_supplement", .supplements),
        ("supplements", .supplements),
        ("body_comp", .data),
        ("glucose", .data),
        ("biomarkers", .data),
        ("cross_domain_insight", .data),
        ("navigate_to", .meta),
    ]
    for (tool, domain) in toolDomains {
        #expect(IntentDomain.of(tool: tool) == domain, "\(tool) should map to \(domain)")
    }
    #expect(IntentDomain.of(tool: "unknown_tool") == .other)
    #expect(IntentDomain.of(tool: "log_food()") == .food, "trailing () should be stripped")
}

// MARK: - Food: pass-through bias

@Test func food_highConfidence_alwaysProceeds() {
    // High-confidence food routes always proceed, regardless of params.
    let cases = [
        ("log_food", true), ("log_food", false),
        ("food_info", true), ("food_info", false),
        ("edit_meal", true), ("edit_meal", false),
        ("delete_food", true), ("delete_food", false),
        ("copy_yesterday", true), ("explain_calories", true),
    ]
    for (tool, complete) in cases {
        #expect(shouldClarify(tool, "high", complete) == .proceed,
                "\(tool) high/\(complete) should proceed")
    }
}

@Test func food_mediumConfidence_proceedsEvenIncomplete() {
    // Food leans toward proceeding at medium — "chicken rice", "biryani"
    // with any name extracted. Clarification on medium food produces
    // over-prompting; the gold set calls for pass-through here.
    #expect(shouldClarify("log_food", "medium", true) == .proceed)
    #expect(shouldClarify("log_food", "medium", false) == .proceed)
    #expect(shouldClarify("food_info", "medium", true) == .proceed)
    #expect(shouldClarify("food_info", "medium", false) == .proceed)
    #expect(shouldClarify("edit_meal", "medium", false) == .proceed)
    #expect(shouldClarify("delete_food", "medium", false) == .proceed)
}

@Test func food_lowConfidence_proceedsWhenParamsComplete() {
    // Low confidence with complete params → proceed. "log 3 eggs" extracted
    // cleanly should not prompt just because the verb "log" is a bare hint.
    #expect(shouldClarify("log_food", "low", true) == .proceed)
    #expect(shouldClarify("food_info", "low", true) == .proceed)
    #expect(shouldClarify("edit_meal", "low", true) == .proceed)
}

@Test func food_lowConfidence_clarifiesWhenParamsIncomplete() {
    // Low + incomplete is the only clarify case — e.g. "log" alone with no
    // name/quantity extracted.
    #expect(shouldClarify("log_food", "low", false) == .clarify)
    #expect(shouldClarify("food_info", "low", false) == .clarify)
    #expect(shouldClarify("edit_meal", "low", false) == .clarify)
}

// MARK: - Weight

@Test func weight_highAlwaysProceeds() {
    // High confidence always proceeds regardless of param completeness.
    #expect(shouldClarify("log_weight", "high", true) == .proceed)
    #expect(shouldClarify("log_weight", "high", false) == .proceed)
    #expect(shouldClarify("weight_info", "high", true) == .proceed)
    #expect(shouldClarify("weight_info", "high", false) == .proceed)
    #expect(shouldClarify("set_goal", "high", true) == .proceed)
    #expect(shouldClarify("set_goal", "high", false) == .proceed)
}

@Test func weight_readToolProceedsAtAnyConfidence() {
    // weight_info is read-only — no false-confirm risk. Same liberal policy
    // as food: clarify only on low + incomplete.
    for conf in ["high", "medium"] {
        for complete in [true, false] {
            #expect(shouldClarify("weight_info", conf, complete) == .proceed,
                    "weight_info \(conf)/\(complete) should proceed (read-only, no FC risk)")
        }
    }
    #expect(shouldClarify("weight_info", "low", true) == .proceed)
    #expect(shouldClarify("weight_info", "low", false) == .clarify)
}

@Test func weight_writeToolClarifiesOnMediumIncomplete() {
    // **Asymmetric cell.** log_weight / set_goal are high false-confirm
    // sensitivity — "log 165" without a unit could be 165 kg (364 lbs) or
    // 165 lbs (75 kg), a ~60% mass swing. At medium confidence + missing
    // unit, the right call is CLARIFY, not silently default. Compare with
    // food which proceeds at medium+incomplete because re-logging a wrong
    // food costs one tap, not chart corruption.
    #expect(shouldClarify("log_weight", "medium", false) == .clarify)
    #expect(shouldClarify("set_goal", "medium", false) == .clarify)
    // Complete params bypass the asymmetric rule — "I weigh 165 lbs" goes
    // through.
    #expect(shouldClarify("log_weight", "medium", true) == .proceed)
    #expect(shouldClarify("set_goal", "medium", true) == .proceed)
}

@Test func weight_writeToolClarifiesOnLowIncomplete() {
    // Low + incomplete → always clarify, regardless of sensitivity.
    #expect(shouldClarify("log_weight", "low", true) == .proceed)
    #expect(shouldClarify("log_weight", "low", false) == .clarify)
    #expect(shouldClarify("set_goal", "low", true) == .proceed)
    #expect(shouldClarify("set_goal", "low", false) == .clarify)
}

// MARK: - Exercise

@Test func exercise_highAndMediumAlwaysProceed() {
    for conf in ["high", "medium"] {
        for complete in [true, false] {
            #expect(shouldClarify("start_workout", conf, complete) == .proceed)
            #expect(shouldClarify("log_activity", conf, complete) == .proceed)
            #expect(shouldClarify("exercise_info", conf, complete) == .proceed)
            #expect(shouldClarify("sleep_recovery", conf, complete) == .proceed)
        }
    }
}

@Test func exercise_lowBehaviorMatchesLegacy() {
    #expect(shouldClarify("log_activity", "low", true) == .proceed)
    #expect(shouldClarify("log_activity", "low", false) == .clarify)
    #expect(shouldClarify("start_workout", "low", false) == .clarify)
}

// MARK: - Supplements

@Test func supplements_readToolProceedsAtAnyConfidence() {
    // supplements() (status query) — read-only, no false-confirm risk.
    for conf in ["high", "medium"] {
        for complete in [true, false] {
            #expect(shouldClarify("supplements", conf, complete) == .proceed)
        }
    }
    #expect(shouldClarify("supplements", "low", true) == .proceed)
    #expect(shouldClarify("supplements", "low", false) == .clarify)
}

@Test func supplements_writeToolClarifiesOnMediumIncomplete() {
    // **Asymmetric cell.** mark_supplement (and log_medication) are
    // high false-confirm sensitivity — marking the wrong med taken
    // breaks adherence tracking with medical implications. Clarify on
    // medium + incomplete (name unknown), proceed when name is concrete.
    #expect(shouldClarify("mark_supplement", "medium", false) == .clarify)
    #expect(shouldClarify("mark_supplement", "medium", true) == .proceed)
    #expect(shouldClarify("log_medication", "medium", false) == .clarify)
    #expect(shouldClarify("log_medication", "medium", true) == .proceed)
}

@Test func supplements_writeToolClarifiesOnLowIncomplete() {
    #expect(shouldClarify("mark_supplement", "high", true) == .proceed)
    #expect(shouldClarify("mark_supplement", "high", false) == .proceed)
    #expect(shouldClarify("mark_supplement", "low", true) == .proceed)
    #expect(shouldClarify("mark_supplement", "low", false) == .clarify)
}

// MARK: - Data: never clarifies

@Test func data_tools_neverClarify() {
    // body_comp/glucose/biomarkers take no required params and have no
    // sibling tool to disambiguate against. Always proceed.
    for tool in ["body_comp", "glucose", "biomarkers"] {
        for conf in ["high", "medium", "low"] {
            for complete in [true, false] {
                #expect(shouldClarify(tool, conf, complete) == .proceed,
                        "\(tool) \(conf)/\(complete) should proceed")
            }
        }
    }
}

// MARK: - Meta: demand HIGH

@Test func meta_highProceeds() {
    #expect(shouldClarify("navigate_to", "high", true) == .proceed)
    #expect(shouldClarify("navigate_to", "high", false) == .proceed)
}

@Test func meta_mediumClarifies() {
    // "show me my chart" — LLM often picks navigate_to at medium confidence
    // but the user might have meant body_comp or calories. Force clarify.
    #expect(shouldClarify("navigate_to", "medium", true) == .clarify)
    #expect(shouldClarify("navigate_to", "medium", false) == .clarify)
}

@Test func meta_lowClarifies() {
    #expect(shouldClarify("navigate_to", "low", true) == .clarify)
    #expect(shouldClarify("navigate_to", "low", false) == .clarify)
}

// MARK: - Confidence parsing

@Test func confidenceParse_defaultsToHigh() {
    // Unknown/empty/weird strings default to high — matches the default in
    // IntentClassifier.parseResponse where missing confidence is treated as
    // high.
    #expect(IntentThresholds.Confidence.parse("") == .high)
    #expect(IntentThresholds.Confidence.parse("HIGH") == .high)
    #expect(IntentThresholds.Confidence.parse("Medium") == .medium)
    #expect(IntentThresholds.Confidence.parse("LOW") == .low)
    #expect(IntentThresholds.Confidence.parse("garbage") == .high)
}

// MARK: - Drift sensitivity

/// If we relaxed meta to proceed on medium, this test names the exact case
/// that would break. Editing the meta rule without also editing this
/// test is a sign the change is wider than intended. #302.
@Test func driftSensitivity_metaMediumMustClarify() {
    // If someone changes meta's rule to `proceed on medium`, this test
    // fails with a meaningful name — "meta medium must clarify".
    let decision = shouldClarify("navigate_to", "medium", true)
    #expect(decision == .clarify,
            "If you changed meta to proceed on medium, update IntentThresholds tests and rationale.")
}

@Test func driftSensitivity_foodMediumMustProceed() {
    // Inverse guard — tightening food to clarify-on-medium would fail here.
    let decision = shouldClarify("log_food", "medium", false)
    #expect(decision == .proceed,
            "If you changed food to clarify on medium, the ~96% IntentRoutingEval pass rate will regress.")
}

// MARK: - Per-domain asymmetry: false-confirm sensitivity

@Test func sensitivityClassification_matchesIntent() {
    // Lock the high-sensitivity list. Adding a tool here is a deliberate
    // policy choice — the default `.low` should cover most additions.
    let highSensitivity = ["log_weight", "set_goal", "mark_supplement", "log_medication"]
    for tool in highSensitivity {
        #expect(IntentThresholds.FalseConfirmSensitivity.of(tool: tool) == .high,
                "\(tool) should be high false-confirm sensitivity")
    }
    // Spot-check defaults: high-volume + recoverable writes stay low.
    let lowSensitivity = ["log_food", "log_activity", "weight_info", "food_info", "supplements", "start_workout"]
    for tool in lowSensitivity {
        #expect(IntentThresholds.FalseConfirmSensitivity.of(tool: tool) == .low,
                "\(tool) should be low false-confirm sensitivity")
    }
}

@Test func asymmetry_foodVsWeightOnMediumIncomplete() {
    // The core asymmetry: same confidence × completeness inputs, different
    // decisions because the cost ratio differs.
    let foodDecision = shouldClarify("log_food", "medium", false)
    let weightDecision = shouldClarify("log_weight", "medium", false)
    #expect(foodDecision == .proceed,
            "Food false-clarify cost (friction) > false-confirm cost (easy undo) → proceed")
    #expect(weightDecision == .clarify,
            "Weight false-confirm cost (unit ambiguity → 60% mass swing) > friction → clarify")
    #expect(foodDecision != weightDecision,
            "Per-domain calibration: food and weight must differ at medium+incomplete")
}

@Test func asymmetry_supplementWriteVsRead() {
    // Same medium+incomplete inputs, different outcomes for write vs read.
    #expect(shouldClarify("mark_supplement", "medium", false) == .clarify,
            "Marking wrong med taken breaks adherence — clarify when name unknown")
    #expect(shouldClarify("supplements", "medium", false) == .proceed,
            "Reading supplement status has no false-confirm risk — proceed")
}
