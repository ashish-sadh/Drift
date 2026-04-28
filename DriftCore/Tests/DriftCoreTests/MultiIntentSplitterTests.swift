import Foundation
@testable import DriftCore
import Testing

// MARK: - Acceptance criteria (from issue #384)

@Test func splitsFoodAndWeight() {
    let result = MultiIntentSplitter.split("I had eggs and logged 70kg")
    #expect(result == ["I had eggs", "logged 70kg"])
}

@Test func splitsSupplementAndWeight() {
    let result = MultiIntentSplitter.split("mark creatine and update my weight")
    #expect(result == ["mark creatine", "update my weight"])
}

@Test func doesNotSplitSameDomainFoodMultiItem() {
    // "rice" alone has no domain signal — prevents false split
    #expect(MultiIntentSplitter.split("I had chicken and rice") == nil)
}

// MARK: - split() — positive cases

@Test func splitsFoodAndWeightWithMealContext() {
    let result = MultiIntentSplitter.split("I had dal for lunch and weighed 68 kg")
    #expect(result?.count == 2)
    #expect(result?[0] == "I had dal for lunch")
    #expect(result?[1] == "weighed 68 kg")
}

@Test func splitsThreeDomains() {
    let result = MultiIntentSplitter.split("had eggs and took creatine and logged 70kg")
    #expect(result?.count == 3)
}

@Test func splitsFoodAndWeightWithLbsUnit() {
    let result = MultiIntentSplitter.split("ate biryani and I weigh 165 lbs")
    #expect(result?.count == 2)
}

@Test func splitsVitaminAndWeight() {
    let result = MultiIntentSplitter.split("took vitamin d and update weight to 72")
    #expect(result?.count == 2)
}

@Test func splitIsCaseInsensitiveOnAnd() {
    let result = MultiIntentSplitter.split("I had eggs AND logged 70kg")
    #expect(result?.count == 2)
}

// MARK: - split() — negative cases (no split)

@Test func noSplitWithoutAnd() {
    #expect(MultiIntentSplitter.split("I had eggs for breakfast") == nil)
    #expect(MultiIntentSplitter.split("log 2 eggs") == nil)
    #expect(MultiIntentSplitter.split("weighed 75kg") == nil)
}

@Test func noSplitBareMultiItemFood() {
    #expect(MultiIntentSplitter.split("eggs and toast") == nil)
    #expect(MultiIntentSplitter.split("rice and dal") == nil)
}

@Test func noSplitSameDomainSupplements() {
    #expect(MultiIntentSplitter.split("took vitamin d and creatine") == nil)
}

@Test func noSplitUnclassifiableSegment() {
    // "something" has no domain → don't split
    #expect(MultiIntentSplitter.split("I had eggs and something") == nil)
}

// MARK: - domain() — unit coverage

@Test func domainWeightByWord() {
    #expect(MultiIntentSplitter.domain(of: "update my weight") == "weight")
    #expect(MultiIntentSplitter.domain(of: "weighed 68 kg") == "weight")
    #expect(MultiIntentSplitter.domain(of: "scale says 165") == "weight")
}

@Test func domainWeightByUnit() {
    #expect(MultiIntentSplitter.domain(of: "logged 70kg") == "weight")
    #expect(MultiIntentSplitter.domain(of: "165 lbs") == "weight")
    #expect(MultiIntentSplitter.domain(of: "72.5 kg") == "weight")
}

@Test func domainFoodByEatingVerb() {
    #expect(MultiIntentSplitter.domain(of: "I had eggs") == "food")
    #expect(MultiIntentSplitter.domain(of: "ate biryani") == "food")
    #expect(MultiIntentSplitter.domain(of: "drank coffee") == "food")
}

@Test func domainFoodByLogVerb() {
    #expect(MultiIntentSplitter.domain(of: "log breakfast") == "food")
    #expect(MultiIntentSplitter.domain(of: "add 2 eggs") == "food")
    #expect(MultiIntentSplitter.domain(of: "track my food") == "food")
}

@Test func domainSupplementByName() {
    #expect(MultiIntentSplitter.domain(of: "mark creatine") == "supplement")
    #expect(MultiIntentSplitter.domain(of: "took vitamin d") == "supplement")
    #expect(MultiIntentSplitter.domain(of: "zinc tablet") == "supplement")
    #expect(MultiIntentSplitter.domain(of: "omega 3 capsule") == "supplement")
}

@Test func domainNilForBareNoun() {
    #expect(MultiIntentSplitter.domain(of: "rice") == nil)
    #expect(MultiIntentSplitter.domain(of: "chicken") == nil)
    #expect(MultiIntentSplitter.domain(of: "something") == nil)
}

@Test func domainWeightTakesPrecedenceOverLogVerb() {
    // "log weight 70kg" has "log " (food) AND weight unit — weight wins
    #expect(MultiIntentSplitter.domain(of: "log weight 70kg") == "weight")
}
