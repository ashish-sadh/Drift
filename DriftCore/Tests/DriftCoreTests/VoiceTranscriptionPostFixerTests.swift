import XCTest
@testable import DriftCore

final class VoiceTranscriptionPostFixerTests: XCTestCase {

    // MARK: - Unambiguous rewrites

    func testMetforminMutterIn() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("I took mutter in 500mg this morning"),
            "I took metformin 500mg this morning"
        )
    }

    func testMetforminMetForeman() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("met foreman 1000mg"),
            "metformin 1000mg"
        )
    }

    func testAshwagandhaVariants() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("ash wagon da before bed"),
            "ashwagandha before bed"
        )
    }

    func testPsyllium() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("I had silly um husk this morning"),
            "I had psyllium husk this morning"
        )
    }

    func testMelatonin() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("3mg mela toning"),
            "3mg melatonin"
        )
    }

    func testGlucosamine() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("glue cosa mine for my knees"),
            "glucosamine for my knees"
        )
    }

    func testTurmericTumorIck() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("tumor ick capsule"),
            "turmeric capsule"
        )
    }

    func testLionsMane() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("lions main mushroom"),
            "lion's mane mushroom"
        )
    }

    // MARK: - Context-guarded rewrites (positive)

    func testWheyProtein() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("I had way protein after the gym"),
            "I had whey protein after the gym"
        )
    }

    func testWheyShake() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("made a way shake"),
            "made a whey shake"
        )
    }

    func testCreatineWithDose() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("took creating 5g this morning"),
            "took creatine 5g this morning"
        )
    }

    func testCreatineMonohydrate() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("creating monohydrate"),
            "creatine monohydrate"
        )
    }

    func testCasein() {
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("case in protein before bed"),
            "casein protein before bed"
        )
    }

    // MARK: - Context-guarded rewrites (negative guards)

    func testCreatingMealPlanUnchanged() {
        let input = "I am creating a meal plan for the week"
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(input), input)
    }

    func testCreatingRecipeUnchanged() {
        let input = "creating a new recipe"
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(input), input)
    }

    func testMutteringSentenceUnchanged() {
        let input = "the muttering continued throughout the movie"
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(input), input)
    }

    func testWayHomeUnchanged() {
        let input = "made my way home after dinner"
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(input), input)
    }

    func testCaseInPointUnchanged() {
        let input = "that is a case in point"
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(input), input)
    }

    // MARK: - Invariants

    func testEmptyStringPassthrough() {
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(""), "")
    }

    func testPlainPhraseUnchanged() {
        let input = "log 200g chicken breast and rice"
        XCTAssertEqual(VoiceTranscriptionPostFixer.fix(input), input)
    }

    func testIdempotenceUnambiguous() {
        let once = VoiceTranscriptionPostFixer.fix("mutter in and ash wagon da")
        let twice = VoiceTranscriptionPostFixer.fix(once)
        XCTAssertEqual(once, twice)
    }

    func testIdempotenceContextGuarded() {
        let once = VoiceTranscriptionPostFixer.fix("way protein and creating 5g")
        let twice = VoiceTranscriptionPostFixer.fix(once)
        XCTAssertEqual(once, twice)
    }

    func testCaseInsensitivePreservesRegularText() {
        // "Mutter In" capitalized should still match — output is always lowercased replacement.
        XCTAssertEqual(
            VoiceTranscriptionPostFixer.fix("Mutter In 500mg"),
            "metformin 500mg"
        )
    }
}
