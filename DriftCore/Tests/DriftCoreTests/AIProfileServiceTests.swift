import XCTest
@testable import DriftCore

@MainActor
final class AIProfileServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserAIProfile.clear()
    }

    override func tearDown() {
        UserAIProfile.clear()
        super.tearDown()
    }

    // MARK: - extractPreferences

    func testExtractsDietaryKeyword() {
        let found = AIProfileService.extractPreferences(from: "I'm vegetarian so no chicken")
        XCTAssertTrue(found.contains("vegetarian"))
    }

    func testExtractsMultipleDietaryKeywords() {
        let found = AIProfileService.extractPreferences(from: "I eat vegan and gluten-free")
        XCTAssertTrue(found.contains("vegan"))
        XCTAssertTrue(found.contains("gluten-free"))
    }

    func testExtractsMedicationAsLabel() {
        let found = AIProfileService.extractPreferences(from: "I'm on ozempic for weight loss")
        XCTAssertTrue(found.contains("GLP-1"), "ozempic should map to GLP-1 label")
    }

    func testDeduplicatesMedicationLabels() {
        let found = AIProfileService.extractPreferences(from: "I take ozempic and wegovy")
        XCTAssertEqual(found.filter { $0 == "GLP-1" }.count, 1, "Same label should appear once")
    }

    func testEmptyTextReturnsEmpty() {
        XCTAssertTrue(AIProfileService.extractPreferences(from: "").isEmpty)
    }

    func testCaseInsensitive() {
        let found = AIProfileService.extractPreferences(from: "I AM VEGETARIAN")
        XCTAssertTrue(found.contains("vegetarian"))
    }

    func testNoMatchReturnsEmpty() {
        let found = AIProfileService.extractPreferences(from: "I had biryani for lunch")
        XCTAssertTrue(found.isEmpty)
    }

    // MARK: - updateProfile

    func testUpdateProfilePersistsNewPreferences() {
        AIProfileService.updateProfile(from: "I'm vegetarian and keto")
        let profile = UserAIProfile.load()
        XCTAssertTrue(profile.explicitPreferences.contains("vegetarian"))
        XCTAssertTrue(profile.explicitPreferences.contains("keto"))
    }

    func testUpdateProfileDeduplicates() {
        AIProfileService.updateProfile(from: "I'm vegetarian")
        AIProfileService.updateProfile(from: "I'm vegetarian")
        let profile = UserAIProfile.load()
        XCTAssertEqual(profile.explicitPreferences.filter { $0 == "vegetarian" }.count, 1)
    }

    func testUpdateProfileMergesNewWithExisting() {
        AIProfileService.updateProfile(from: "I'm vegetarian")
        AIProfileService.updateProfile(from: "I'm also on ozempic")
        let profile = UserAIProfile.load()
        XCTAssertTrue(profile.explicitPreferences.contains("vegetarian"))
        XCTAssertTrue(profile.explicitPreferences.contains("GLP-1"))
    }

    func testUpdateProfileNoOpWhenNoKeywords() {
        AIProfileService.updateProfile(from: "log 2 eggs")
        let profile = UserAIProfile.load()
        XCTAssertTrue(profile.explicitPreferences.isEmpty)
    }

    // MARK: - buildSummary

    func testBuildSummaryHasCorrectPrefix() {
        // Whatever the DB state, a non-nil summary must start with "User profile:"
        if let summary = AIProfileService.buildSummary() {
            XCTAssertTrue(summary.hasPrefix("User profile:"))
        }
    }

    func testBuildSummaryIncludesExplicitPreferences() {
        var profile = UserAIProfile()
        profile.explicitPreferences = ["vegetarian"]
        UserAIProfile.save(profile)
        let summary = AIProfileService.buildSummary()
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("vegetarian"))
        XCTAssertTrue(summary!.hasPrefix("User profile:"))
    }

    func testBuildSummaryStaysWithinTokenBudget() {
        var profile = UserAIProfile()
        profile.explicitPreferences = Array(repeating: "vegetarian keto gluten-free paleo pescatarian carnivore halal kosher", count: 10)
        UserAIProfile.save(profile)
        let summary = AIProfileService.buildSummary() ?? ""
        XCTAssertLessThanOrEqual(summary.count, 300, "Summary must stay within char cap (~75 tokens)")
    }

    // MARK: - UserAIProfile round-trip

    func testProfileSaveLoadRoundtrip() {
        var profile = UserAIProfile()
        profile.explicitPreferences = ["vegetarian", "GLP-1"]
        UserAIProfile.save(profile)
        let loaded = UserAIProfile.load()
        XCTAssertEqual(loaded.explicitPreferences, ["vegetarian", "GLP-1"])
    }

    func testProfileClearReturnsEmpty() {
        var profile = UserAIProfile()
        profile.explicitPreferences = ["keto"]
        UserAIProfile.save(profile)
        UserAIProfile.clear()
        XCTAssertTrue(UserAIProfile.load().explicitPreferences.isEmpty)
    }

    // MARK: - composeUserMessage integration

    func testComposeInjectsProfileContext() {
        let composed = IntentClassifier.composeUserMessage(
            message: "what should I eat",
            history: "",
            recentBlock: nil,
            profileContext: "User profile: vegetarian"
        )
        XCTAssertTrue(composed.contains("User profile: vegetarian"))
        XCTAssertTrue(composed.contains("User: what should I eat"))
    }

    func testComposeProfileAppearsBeforeHistory() {
        let composed = IntentClassifier.composeUserMessage(
            message: "log rice",
            history: "I had dal",
            recentBlock: nil,
            profileContext: "User profile: vegetarian"
        )
        let profileIdx = composed.range(of: "User profile:")!.lowerBound
        let historyIdx = composed.range(of: "Chat:")!.lowerBound
        XCTAssertLessThan(profileIdx, historyIdx, "Profile must appear before chat history")
    }

    func testComposeNilProfileOmitted() {
        let composed = IntentClassifier.composeUserMessage(
            message: "log rice",
            history: "",
            recentBlock: nil,
            profileContext: nil
        )
        XCTAssertEqual(composed, "log rice", "Nil profile with no other context returns bare message")
    }
}
