import Testing
@testable import Drift
import DriftCore

/// Chip-count and overflow logic for ClarificationCard. #316.
/// Tests the view-model helpers directly — no ViewInspector needed.

private func makeOptions(count: Int) -> [ClarificationOption] {
    (1...count).map { i in
        .init(id: i, label: "Option \(i)", tool: "log_food",
              params: ["name": "item\(i)"], displayIcon: "fork.knife")
    }
}

@Test @MainActor func fiveOrFewerOptionsAreAllVisible() {
    for count in 2...5 {
        let card = ClarificationCard(options: makeOptions(count: count),
                                     isDisabled: false, onPick: { _ in }, onOther: {})
        #expect(card.visibleOptions.count == count)
        #expect(card.showsOtherChip == false)
    }
}

@Test @MainActor func sixOrMoreOptionsFoldsToFourPlusOther() {
    for count in 6...8 {
        let card = ClarificationCard(options: makeOptions(count: count),
                                     isDisabled: false, onPick: { _ in }, onOther: {})
        #expect(card.visibleOptions.count == 4)
        #expect(card.showsOtherChip == true)
    }
}

@Test @MainActor func emptyOptionsShowNeitherChipsNorOther() {
    let card = ClarificationCard(options: [], isDisabled: false, onPick: { _ in }, onOther: {})
    #expect(card.visibleOptions.isEmpty)
    #expect(card.showsOtherChip == false)
}
