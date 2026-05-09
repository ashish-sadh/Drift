import XCTest
import DriftCore
import Foundation

/// Tier-2 deterministic eval — does NOT load Gemma. Asserts that
/// `MultiIntentSplitter` correctly identifies multi-intent prompts and
/// classifies each clause's domain. The downstream end-to-end execution
/// (`AIToolAgent.executeMultiIntent`) is exercised by `MultiIntentSplitterTests`
/// + the runtime AIToolAgent flow; this file pins the eval-set contract for #688.
final class MultiIntentDeterministicEval: XCTestCase {

    // MARK: - Multi-intent prompts → expected segment domains

    private struct Case {
        let prompt: String
        let expectedDomains: [String]
        let line: UInt
        init(_ prompt: String, _ domains: [String], line: UInt = #line) {
            self.prompt = prompt
            self.expectedDomains = domains
            self.line = line
        }
    }

    func testMultiIntent_splitsAndDomainsMatch() {
        let cases: [Case] = [
            // Food + weight (anchor case from acceptance criteria)
            Case("I had eggs and logged 70kg",        ["food",       "weight"]),
            Case("ate biryani and I weigh 165 lbs",   ["food",       "weight"]),
            Case("had dal for lunch and weighed 68 kg", ["food",     "weight"]),

            // Supplement + weight
            Case("mark creatine and update my weight", ["supplement", "weight"]),
            Case("took vitamin d and update weight to 72", ["supplement", "weight"]),

            // Three-way: food + supplement + weight
            Case("had eggs and took creatine and logged 70kg",
                 ["food", "supplement", "weight"]),

            // Food + supplement
            Case("ate biryani and took fish oil",     ["food",       "supplement"]),
            Case("had breakfast and marked creatine", ["food",       "supplement"]),

            // Weight + supplement (verbosity variations)
            Case("weighed 75kg and took my zinc",     ["weight",     "supplement"]),
            Case("scale says 165 and add vitamin d",  ["weight",     "supplement"]),
        ]

        for c in cases {
            guard let segments = MultiIntentSplitter.split(c.prompt) else {
                XCTFail("split returned nil for '\(c.prompt)' (expected \(c.expectedDomains.count) segments)",
                        file: #filePath, line: c.line)
                continue
            }
            XCTAssertEqual(segments.count, c.expectedDomains.count,
                           "segment count mismatch for '\(c.prompt)' — got \(segments)",
                           file: #filePath, line: c.line)
            for (i, segment) in segments.enumerated() where i < c.expectedDomains.count {
                let domain = MultiIntentSplitter.domain(of: segment)
                XCTAssertEqual(domain, c.expectedDomains[i],
                               "segment \(i) of '\(c.prompt)' → domain '\(domain ?? "nil")' (expected '\(c.expectedDomains[i])')",
                               file: #filePath, line: c.line)
            }
        }
    }

    // MARK: - Same-domain compounds must NOT split (food-name protection)

    func testCompoundFoodNames_notSplit() {
        let compoundFoodNames = [
            "I had fish and chips",
            "ate fish and chips for lunch",
            "had mac and cheese",
            "peanut butter and jelly sandwich",
            "cookies and cream ice cream",
            "I had chicken and rice",
            "rice and dal for dinner",
            "eggs and toast",
        ]
        for prompt in compoundFoodNames {
            XCTAssertNil(MultiIntentSplitter.split(prompt),
                         "splitter must not split compound food name: '\(prompt)'")
        }
    }

    // MARK: - Single-intent must NOT split

    func testSingleIntent_notSplit() {
        let singleIntent = [
            "log 2 eggs",
            "I had biryani for breakfast",
            "weighed 75kg",
            "took vitamin d",
            "show me my weight",
            "what did I eat yesterday",
        ]
        for prompt in singleIntent {
            XCTAssertNil(MultiIntentSplitter.split(prompt),
                         "splitter must not split single-intent prompt: '\(prompt)'")
        }
    }
}
