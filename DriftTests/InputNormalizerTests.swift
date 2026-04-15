import Foundation
import Testing
@testable import Drift

// MARK: - InputNormalizer Tests

// MARK: Filler Word Removal

@Test func normalizerRemovesUmm() {
    let result = InputNormalizer.normalize("umm I had 2 eggs")
    #expect(result == "I had 2 eggs")
}

@Test func normalizerRemovesUhAndLike() {
    let result = InputNormalizer.normalize("uh like I ate some rice")
    #expect(result == "I ate some rice")
}

@Test func normalizerRemovesMultiWordFillers() {
    let result = InputNormalizer.normalize("you know I had breakfast")
    #expect(result == "I had breakfast")
}

@Test func normalizerRemovesIMean() {
    let result = InputNormalizer.normalize("i mean I want to log lunch")
    #expect(result == "I want to log lunch")
}

@Test func normalizerKeepsMeaningfulLike() {
    // "like" as filler is removed, but the content meaning is preserved
    let result = InputNormalizer.normalize("I had like 3 bananas")
    #expect(result == "I had 3 bananas")
}

// MARK: Partial Restarts

@Test func normalizerRemovesPartialRestart() {
    let result = InputNormalizer.removePartialRestarts("I had I had 2 eggs")
    #expect(result == "I had 2 eggs")
}

@Test func normalizerRemovesSingleWordRestart() {
    let result = InputNormalizer.removePartialRestarts("log log rice and dal")
    #expect(result == "log rice and dal")
}

@Test func normalizerRemovesTwoWordRestart() {
    let result = InputNormalizer.removePartialRestarts("I ate I ate chicken for dinner")
    #expect(result == "I ate chicken for dinner")
}

@Test func normalizerNoRestartWhenDifferent() {
    let result = InputNormalizer.removePartialRestarts("I had rice and dal")
    #expect(result == "I had rice and dal")
}

// MARK: Repeated Words

@Test func normalizerCollapsesRepeatedWords() {
    let result = InputNormalizer.collapseRepeatedWords("the the rice")
    #expect(result == "the rice")
}

@Test func normalizerCollapsesMultipleRepeats() {
    let result = InputNormalizer.collapseRepeatedWords("I I I ate ate rice")
    #expect(result == "I ate rice")
}

@Test func normalizerKeepsDistinctWords() {
    let result = InputNormalizer.collapseRepeatedWords("rice and dal")
    #expect(result == "rice and dal")
}

// MARK: Contractions

@Test func normalizerFixesDont() {
    let result = InputNormalizer.fixCommonContractions("I dont want rice")
    #expect(result == "I don't want rice")
}

@Test func normalizerFixesIm() {
    let result = InputNormalizer.fixCommonContractions("im at 165 pounds")
    #expect(result == "I'm at 165 pounds")
}

@Test func normalizerFixesWhats() {
    let result = InputNormalizer.fixCommonContractions("whats my protein")
    #expect(result == "what's my protein")
}

@Test func normalizerPreservesExistingApostrophe() {
    let result = InputNormalizer.fixCommonContractions("I don't want rice")
    #expect(result == "I don't want rice")
}

// MARK: Whitespace

@Test func normalizerCollapsesWhitespace() {
    let result = InputNormalizer.normalizeWhitespace("I  had    rice")
    #expect(result == "I had rice")
}

@Test func normalizerHandlesTabs() {
    let result = InputNormalizer.normalizeWhitespace("I\thad\trice")
    #expect(result == "I had rice")
}

@Test func normalizerHandlesNewlines() {
    let result = InputNormalizer.normalizeWhitespace("I had\nrice")
    #expect(result == "I had rice")
}

// MARK: Leading Conjunctions

@Test func normalizerStripsLeadingSo() {
    let result = InputNormalizer.trimLeadingConjunctions("so I had rice")
    #expect(result == "I had rice")
}

@Test func normalizerStripsOkSo() {
    let result = InputNormalizer.trimLeadingConjunctions("ok so log my lunch")
    #expect(result == "log my lunch")
}

@Test func normalizerStripsWell() {
    let result = InputNormalizer.trimLeadingConjunctions("well I want to log eggs")
    #expect(result == "I want to log eggs")
}

@Test func normalizerKeepsSoInMiddle() {
    let result = InputNormalizer.trimLeadingConjunctions("I had rice so log it")
    #expect(result == "I had rice so log it")
}

// MARK: Full Pipeline (End-to-End)

@Test func normalizerFullVoiceInput() {
    let result = InputNormalizer.normalize("umm so I had like 2 eggs and and some toast for breakfast")
    #expect(result == "I had 2 eggs and some toast for breakfast")
}

@Test func normalizerFullCleanInput() {
    // Clean input should pass through unchanged
    let result = InputNormalizer.normalize("log 3 eggs")
    #expect(result == "log 3 eggs")
}

@Test func normalizerFullRestart() {
    let result = InputNormalizer.normalize("I had I had umm 2 bananas")
    #expect(result == "I had 2 bananas")
}

@Test func normalizerEmptyInput() {
    let result = InputNormalizer.normalize("")
    #expect(result == "")
}

@Test func normalizerOnlyFillers() {
    // If everything is filler, return original trimmed
    let result = InputNormalizer.normalize("umm uh like")
    #expect(!result.isEmpty)
}

@Test func normalizerPreservesNumbers() {
    let result = InputNormalizer.normalize("umm like 200 grams of rice")
    #expect(result == "200 grams of rice")
}

@Test func normalizerPreservesSpecialFood() {
    let result = InputNormalizer.normalize("uh I had paneer tikka masala")
    #expect(result == "I had paneer tikka masala")
}

@Test func normalizerVoiceStyleNoFiller() {
    // Voice input without fillers but with restarts
    let result = InputNormalizer.normalize("log log rice and dal")
    #expect(result == "log rice and dal")
}

@Test func normalizerContractionAndFiller() {
    let result = InputNormalizer.normalize("um whats my calories left")
    #expect(result == "what's my calories left")
}

@Test func normalizerComplexVoice() {
    let result = InputNormalizer.normalize("ok so umm I basically had like chicken and rice for lunch")
    #expect(result == "I had chicken and rice for lunch")
}
