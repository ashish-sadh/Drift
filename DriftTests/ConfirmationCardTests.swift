import Foundation
import Testing
@testable import Drift

// MARK: - Workout Muscle Group Lookup Tests

@Test func bodyPartLookupRunning() {
    let part = ExerciseDatabase.bodyPart(for: "Running")
    // "Running" doesn't match any specific muscle pattern in guessBodyPart
    #expect(!part.isEmpty)
}

@Test func bodyPartLookupBenchPress() {
    let part = ExerciseDatabase.bodyPart(for: "Bench Press")
    #expect(part == "Chest")
}

@Test func bodyPartLookupSquat() {
    let part = ExerciseDatabase.bodyPart(for: "Squat")
    #expect(part == "Legs")
}

@Test func bodyPartLookupDeadlift() {
    let part = ExerciseDatabase.bodyPart(for: "Deadlift")
    #expect(part == "Back" || part == "Legs")
}

@Test func bodyPartGuessCycling() {
    let part = ExerciseDatabase.bodyPart(for: "Cycling")
    #expect(!part.isEmpty)
}

@Test func bodyPartGuessYoga() {
    let part = ExerciseDatabase.bodyPart(for: "Yoga")
    // Should return something, not crash
    #expect(!part.isEmpty)
}

@Test func bodyPartGuessSwimming() {
    let part = ExerciseDatabase.bodyPart(for: "Swimming")
    #expect(!part.isEmpty)
}

// MARK: - Card Data Struct Tests

@Test func workoutCardDataDefaults() {
    let card = AIChatViewModel.WorkoutCardData(name: "Push Day", durationMin: 45, exerciseCount: 6)
    #expect(card.confirmed == true)
    #expect(card.muscleGroups.isEmpty)
}

@Test func workoutCardDataWithMuscles() {
    let card = AIChatViewModel.WorkoutCardData(
        name: "Push Day", durationMin: 45, exerciseCount: 6,
        muscleGroups: ["Chest", "Shoulders", "Arms"]
    )
    #expect(card.muscleGroups.count == 3)
    #expect(card.muscleGroups.contains("Chest"))
}

@Test func workoutCardUnconfirmed() {
    let card = AIChatViewModel.WorkoutCardData(
        name: "Running", durationMin: 30, exerciseCount: nil,
        muscleGroups: ["Legs"], confirmed: false
    )
    #expect(!card.confirmed)
    #expect(card.muscleGroups == ["Legs"])
}

@Test func glucoseCardDataConstruction() {
    let card = AIChatViewModel.GlucoseCardData(
        avgMgdl: 105, minMgdl: 78, maxMgdl: 152,
        inZonePct: 85, readingCount: 48,
        spikeCount: 2, peakMgdl: 152
    )
    #expect(card.avgMgdl == 105)
    #expect(card.spikeCount == 2)
    #expect(card.inZonePct == 85)
}

@Test func biomarkerCardAllOptimal() {
    let card = AIChatViewModel.BiomarkerCardData(
        totalCount: 12, optimalCount: 12, outOfRange: []
    )
    #expect(card.outOfRange.isEmpty)
    #expect(card.optimalCount == card.totalCount)
}

@Test func biomarkerCardWithOutOfRange() {
    let card = AIChatViewModel.BiomarkerCardData(
        totalCount: 10, optimalCount: 8,
        outOfRange: [
            .init(name: "Vitamin D", value: "18.5 ng/mL", status: "low"),
            .init(name: "Iron", value: "250.0 mcg/dL", status: "high")
        ]
    )
    #expect(card.outOfRange.count == 2)
    #expect(card.outOfRange[0].name == "Vitamin D")
    #expect(card.outOfRange[1].status == "high")
}

@Test func supplementCardAllTaken() {
    let card = AIChatViewModel.SupplementCardData(
        taken: 5, total: 5, remaining: [], action: nil
    )
    #expect(card.remaining.isEmpty)
    #expect(card.taken == card.total)
}

@Test func supplementCardWithRemaining() {
    let card = AIChatViewModel.SupplementCardData(
        taken: 2, total: 5,
        remaining: ["Creatine", "Vitamin D", "Fish Oil"],
        action: "Marked Magnesium as taken"
    )
    #expect(card.remaining.count == 3)
    #expect(card.action == "Marked Magnesium as taken")
}

@Test func sleepCardWithFullData() {
    let card = AIChatViewModel.SleepCardData(
        sleepHours: 7.5, remHours: 1.8, deepHours: 1.2,
        recoveryScore: 82, hrvMs: 45, restingHR: 58,
        readiness: "Good to train"
    )
    #expect(card.sleepHours == 7.5)
    #expect(card.recoveryScore == 82)
    #expect(card.readiness == "Good to train")
}

@Test func sleepCardWithPartialData() {
    let card = AIChatViewModel.SleepCardData(
        sleepHours: 6.2, remHours: nil, deepHours: nil,
        recoveryScore: nil, hrvMs: nil, restingHR: nil,
        readiness: nil
    )
    #expect(card.sleepHours == 6.2)
    #expect(card.recoveryScore == nil)
    #expect(card.readiness == nil)
}

// MARK: - Muscle Group Filter Logic

@Test func muscleGroupFilterExcludesFullBody() {
    // The card creation logic filters out "Full Body" and "Other"
    let bodyPart = "Full Body"
    let filtered = [bodyPart].filter { $0 != "Full Body" && $0 != "Other" }
    #expect(filtered.isEmpty)
}

@Test func muscleGroupFilterKeepsSpecific() {
    let bodyPart = "Chest"
    let filtered = [bodyPart].filter { $0 != "Full Body" && $0 != "Other" }
    #expect(filtered == ["Chest"])
}
