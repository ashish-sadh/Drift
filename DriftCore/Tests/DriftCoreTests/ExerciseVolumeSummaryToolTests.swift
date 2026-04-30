import XCTest
@testable import DriftCore

/// Tier-0: deterministic volume aggregation — no LLM, no DB, no network.
final class ExerciseVolumeSummaryToolTests: XCTestCase {

    // MARK: - groupSetsByMuscle

    func testGroupSetsByMuscle_empty() {
        let counts = ExerciseVolumeSummaryTool.groupSetsByMuscle([])
        XCTAssertTrue(counts.isEmpty)
    }

    func testGroupSetsByMuscle_singleMuscleGroup() {
        let sets = [
            WorkoutSet(workoutId: 1, exerciseName: "bench press", setOrder: 1),
            WorkoutSet(workoutId: 1, exerciseName: "bench press", setOrder: 2),
            WorkoutSet(workoutId: 1, exerciseName: "chest fly",   setOrder: 3),
        ]
        let counts = ExerciseVolumeSummaryTool.groupSetsByMuscle(sets)
        XCTAssertEqual(counts["Chest"], 3)
    }

    func testGroupSetsByMuscle_multipleGroups() {
        let sets = [
            WorkoutSet(workoutId: 1, exerciseName: "squat",          setOrder: 1),
            WorkoutSet(workoutId: 1, exerciseName: "leg press",       setOrder: 2),
            WorkoutSet(workoutId: 1, exerciseName: "bench press",     setOrder: 3),
            WorkoutSet(workoutId: 1, exerciseName: "shoulder press",  setOrder: 4),
        ]
        let counts = ExerciseVolumeSummaryTool.groupSetsByMuscle(sets)
        XCTAssertEqual(counts["Legs"],      2)
        XCTAssertEqual(counts["Chest"],     1)
        XCTAssertEqual(counts["Shoulders"], 1)
    }

    func testGroupSetsByMuscle_ignoresWarmupSetsAtCallSite() {
        // groupSetsByMuscle itself doesn't filter warmups — run() does.
        // Verify warmup sets ARE counted if passed in.
        let warmup = WorkoutSet(workoutId: 1, exerciseName: "bench press", setOrder: 1, isWarmup: true)
        let counts = ExerciseVolumeSummaryTool.groupSetsByMuscle([warmup])
        XCTAssertEqual(counts["Chest"], 1)
    }

    // MARK: - formatResult

    func testFormatResult_noUndertrained() {
        var setsByGroup: [String: Int] = [:]
        for group in ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"] {
            let min = ExerciseVolumeSummaryTool.minimumSetsPerGroup[group] ?? 10
            setsByGroup[group] = min
        }
        let result = ExerciseVolumeSummaryTool.formatResult(
            setsByGroup: setsByGroup, windowDays: 7, workoutCount: 3)
        XCTAssertTrue(result.contains("All major groups at or above minimum volume."))
    }

    func testFormatResult_identifiesMostUndertrained() {
        let setsByGroup: [String: Int] = ["Chest": 2, "Back": 12, "Legs": 12,
                                          "Shoulders": 12, "Arms": 8, "Core": 8]
        let result = ExerciseVolumeSummaryTool.formatResult(
            setsByGroup: setsByGroup, windowDays: 7, workoutCount: 2)
        XCTAssertTrue(result.contains("Most undertrained: Chest"))
        XCTAssertTrue(result.contains("2/10"))
    }

    func testFormatResult_weekLabel() {
        let result = ExerciseVolumeSummaryTool.formatResult(
            setsByGroup: [:], windowDays: 7, workoutCount: 1)
        XCTAssertTrue(result.contains("week"))
    }

    func testFormatResult_customWindowLabel() {
        let result = ExerciseVolumeSummaryTool.formatResult(
            setsByGroup: [:], windowDays: 14, workoutCount: 2)
        XCTAssertTrue(result.contains("14 days"))
    }

    // MARK: - cutoffDateString

    func testCutoffDateString_sevenDays() {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 28
        guard let now = cal.date(from: comps) else { return }
        let cutoff = ExerciseVolumeSummaryTool.cutoffDateString(windowDays: 7, now: now)
        XCTAssertEqual(cutoff, "2026-04-22")
    }
}
