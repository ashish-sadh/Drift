import Foundation
@testable import DriftCore
import Testing
@testable import Drift

// MARK: - SpellCorrectService.correct() Tests

@Test func spellCorrect_hardcoded_chickenMisspelling() {
    #expect(SpellCorrectService.correct("chiken") == "chicken")
}

@Test func spellCorrect_hardcoded_proteinMisspelling() {
    #expect(SpellCorrectService.correct("protien") == "protein")
}

@Test func spellCorrect_hardcoded_paneerMisspelling() {
    #expect(SpellCorrectService.correct("panner") == "paneer")
}

@Test func spellCorrect_hardcoded_biryaniMisspelling() {
    #expect(SpellCorrectService.correct("biryanni") == "biryani")
}

@Test func spellCorrect_hardcoded_pizzaMisspelling() {
    #expect(SpellCorrectService.correct("piza") == "pizza")
}

@Test func spellCorrect_hardcoded_sandwichMisspelling() {
    #expect(SpellCorrectService.correct("sandwhich") == "sandwich")
}

@Test func spellCorrect_hardcoded_yogurtMisspelling() {
    #expect(SpellCorrectService.correct("yoghurt") == "yogurt")
}

@Test func spellCorrect_hardcoded_espressoMisspelling() {
    #expect(SpellCorrectService.correct("expresso") == "espresso")
}

@Test func spellCorrect_hardcoded_benchpress() {
    #expect(SpellCorrectService.correct("benchpress") == "bench press")
}

@Test func spellCorrect_hardcoded_deadliftMisspelling() {
    #expect(SpellCorrectService.correct("deadlfit") == "deadlift")
}

@Test func spellCorrect_hardcoded_calorieMisspelling() {
    #expect(SpellCorrectService.correct("calries") == "calories")
}

@Test func spellCorrect_correctWordReturnedUnchanged() {
    // Already correct words should not be changed
    let result = SpellCorrectService.correct("chicken")
    #expect(result == "chicken")
}

@Test func spellCorrect_shortWordSkipped() {
    // Words < 4 chars are skipped
    let result = SpellCorrectService.correct("had")
    #expect(result == "had")
}

@Test func spellCorrect_commonWordSkipped() {
    // "calories" is in the commonWords set
    let result = SpellCorrectService.correct("calories")
    #expect(result == "calories")
}

@Test func spellCorrect_multipleWordsInSentence() {
    let result = SpellCorrectService.correct("I had chiken and salman")
    #expect(result.contains("chicken"))
    #expect(result.contains("salmon"))
}

@Test func spellCorrect_multipleWords_protienAndBreakfest() {
    let result = SpellCorrectService.correct("breakfest protien")
    #expect(result == "breakfast protein")
}

@Test func spellCorrect_idlMisspelling() {
    #expect(SpellCorrectService.correct("idly") == "idli")
}

@Test func spellCorrect_avocadoMisspelling() {
    #expect(SpellCorrectService.correct("avacado") == "avocado")
}

@Test func spellCorrect_broccoliMisspelling() {
    #expect(SpellCorrectService.correct("brocoli") == "broccoli")
}

// MARK: - SpellCorrectService.expandSynonyms() Tests

@Test func expandSynonyms_aloo() {
    let result = SpellCorrectService.expandSynonyms("aloo")
    #expect(result == "potato")
}

@Test func expandSynonyms_palak() {
    let result = SpellCorrectService.expandSynonyms("palak paneer")
    #expect(result.contains("spinach"))
}

@Test func expandSynonyms_fries() {
    let result = SpellCorrectService.expandSynonyms("fries")
    #expect(result == "french fries")
}

@Test func expandSynonyms_pb() {
    let result = SpellCorrectService.expandSynonyms("pb")
    #expect(result == "peanut butter")
}

@Test func expandSynonyms_chana() {
    let result = SpellCorrectService.expandSynonyms("chana")
    #expect(result == "chickpeas")
}

@Test func expandSynonyms_gobi() {
    let result = SpellCorrectService.expandSynonyms("gobi")
    #expect(result == "cauliflower")
}

@Test func expandSynonyms_dahi() {
    let result = SpellCorrectService.expandSynonyms("dahi")
    #expect(result == "yogurt")
}

@Test func expandSynonyms_mince() {
    let result = SpellCorrectService.expandSynonyms("mince")
    #expect(result == "ground beef")
}

@Test func expandSynonyms_pravns() {
    let result = SpellCorrectService.expandSynonyms("prawns")
    #expect(result == "shrimp")
}

@Test func expandSynonyms_multiWordNimbuPani() {
    let result = SpellCorrectService.expandSynonyms("nimbu pani please")
    #expect(result.contains("lemon water"))
}

@Test func expandSynonyms_noSynonymReturnsOriginal() {
    let input = "chicken breast"
    let result = SpellCorrectService.expandSynonyms(input)
    #expect(result == input)
}

@Test func expandSynonyms_crispsToChips() {
    let result = SpellCorrectService.expandSynonyms("crisps")
    #expect(result == "potato chips")
}

@Test func expandSynonyms_pbj() {
    let result = SpellCorrectService.expandSynonyms("pbj")
    #expect(result == "peanut butter jelly")
}
