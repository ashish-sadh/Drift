import Foundation
import Testing
@testable import Drift

/// Multi-turn flow coverage for ask-don't-guess clarification. #226.
/// Walks the resolver through typical user replies (number, ordinal, chip
/// label, keyword, cancel, gibberish) so the dispatch contract stays
/// stable even without the live LLM in the loop.

private func sampleOptions() -> [ClarificationOption] {
    [
        .init(id: 1, label: "Log chicken as food", tool: "log_food",
              params: ["name": "chicken"]),
        .init(id: 2, label: "Look up calories in chicken", tool: "food_info",
              params: ["query": "calories in chicken"])
    ]
}

private func supplementOptions() -> [ClarificationOption] {
    [
        .init(id: 1, label: "Mark creatine as taken today", tool: "mark_supplement",
              params: ["name": "creatine"]),
        .init(id: 2, label: "Check if I've taken creatine", tool: "supplements",
              params: ["query": "creatine"])
    ]
}

// MARK: - Numeric pick

@Test @MainActor func numericResponsePicksRightOption() {
    let opts = sampleOptions()
    let one = AIChatViewModel.resolveClarificationPick("1", options: opts)
    #expect(one?.tool == "log_food")
    let two = AIChatViewModel.resolveClarificationPick("2", options: opts)
    #expect(two?.tool == "food_info")
}

// MARK: - Ordinal pick

@Test @MainActor func ordinalWordsResolve() {
    let opts = sampleOptions()
    #expect(AIChatViewModel.resolveClarificationPick("first", options: opts)?.tool == "log_food")
    #expect(AIChatViewModel.resolveClarificationPick("second", options: opts)?.tool == "food_info")
    #expect(AIChatViewModel.resolveClarificationPick("1st", options: opts)?.tool == "log_food")
    #expect(AIChatViewModel.resolveClarificationPick("one", options: opts)?.tool == "log_food")
    #expect(AIChatViewModel.resolveClarificationPick("two", options: opts)?.tool == "food_info")
}

// MARK: - Chip label pick (UI taps send the exact label)

@Test @MainActor func literalLabelMatchResolves() {
    let opts = sampleOptions()
    let match = AIChatViewModel.resolveClarificationPick(
        "log chicken as food", options: opts)
    #expect(match?.tool == "log_food")
}

// MARK: - Keyword fallback

@Test @MainActor func keywordLogRoutesToActionTool() {
    let opts = sampleOptions()
    #expect(AIChatViewModel.resolveClarificationPick("log it", options: opts)?.tool == "log_food")
    #expect(AIChatViewModel.resolveClarificationPick("add it", options: opts)?.tool == "log_food")
    #expect(AIChatViewModel.resolveClarificationPick("track it", options: opts)?.tool == "log_food")
}

@Test @MainActor func keywordCaloriesRoutesToFoodInfo() {
    let opts = sampleOptions()
    #expect(AIChatViewModel.resolveClarificationPick("calories", options: opts)?.tool == "food_info")
    #expect(AIChatViewModel.resolveClarificationPick("check calories", options: opts)?.tool == "food_info")
    #expect(AIChatViewModel.resolveClarificationPick("nutrition info", options: opts)?.tool == "food_info")
}

@Test @MainActor func keywordForSupplementDisambiguates() {
    let opts = supplementOptions()
    #expect(AIChatViewModel.resolveClarificationPick("log it", options: opts)?.tool == "mark_supplement")
    #expect(AIChatViewModel.resolveClarificationPick("check", options: opts)?.tool == "supplements")
}

// MARK: - Gibberish

@Test @MainActor func unknownResponseReturnsNilSoCallerCanFallThrough() {
    let opts = sampleOptions()
    #expect(AIChatViewModel.resolveClarificationPick("asdfqwer", options: opts) == nil)
    #expect(AIChatViewModel.resolveClarificationPick("99", options: opts) == nil)
}

// MARK: - Phase transitions (dispatch contract)

@Test @MainActor func dispatchClearsPhaseOnSuccessfulPick() {
    let state = ConversationState.shared
    let opts = sampleOptions()
    state.phase = .awaitingClarification(options: opts)
    let vm = AIChatViewModel()
    let handled = vm.handleClarificationResponse("1")
    #expect(handled == true)
    #expect(state.phase == .idle)
}

@Test @MainActor func dispatchCancelsOnNevermind() {
    let state = ConversationState.shared
    let opts = sampleOptions()
    state.phase = .awaitingClarification(options: opts)
    let vm = AIChatViewModel()
    let handled = vm.handleClarificationResponse("nevermind")
    #expect(handled == true)
    #expect(state.phase == .idle)
    // A brief "no problem" assistant message should be appended to avoid
    // a silent reset.
    #expect(vm.messages.last?.text.lowercased().contains("no problem") == true)
}

@Test @MainActor func dispatchDropsPhaseOnUnknownInput() {
    let state = ConversationState.shared
    let opts = sampleOptions()
    state.phase = .awaitingClarification(options: opts)
    let vm = AIChatViewModel()
    let handled = vm.handleClarificationResponse("tacos on tuesday")
    #expect(handled == false)
    // Phase cleared so caller flows through to normal classification.
    #expect(state.phase == .idle)
}

@Test @MainActor func dispatchSkipsWhenNotInClarificationPhase() {
    let state = ConversationState.shared
    state.phase = .idle
    let vm = AIChatViewModel()
    let handled = vm.handleClarificationResponse("1")
    #expect(handled == false)
}
