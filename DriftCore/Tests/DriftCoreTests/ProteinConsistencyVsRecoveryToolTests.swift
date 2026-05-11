import Foundation
@testable import DriftCore
import Testing

// MARK: - Helpers

private func obs(_ p: Double, hrv: Double, sleep: Double) -> ProteinConsistencyVsRecoveryTool.DayObservation {
    .init(proteinG: p, hrvMs: hrv, sleepHours: sleep)
}

// MARK: - Analysis branches

@Test func protein_consistency_highProteinRecoveryHigher() {
    // High-protein days line up with better recovery.
    let pairs: [ProteinConsistencyVsRecoveryTool.DayObservation] = [
        obs(80,  hrv: 30, sleep: 6.0),
        obs(85,  hrv: 32, sleep: 6.2),
        obs(90,  hrv: 35, sleep: 6.5),
        obs(140, hrv: 70, sleep: 7.8),
        obs(150, hrv: 75, sleep: 8.0),
        obs(160, hrv: 80, sleep: 8.2),
        obs(85,  hrv: 33, sleep: 6.3),
        obs(155, hrv: 78, sleep: 8.1),
        obs(95,  hrv: 36, sleep: 6.6),
        obs(145, hrv: 72, sleep: 7.9)
    ]
    let r = ProteinConsistencyVsRecoveryTool.analyze(pairs: pairs)
    #expect(r.totalPairs == 10)
    #expect(r.highProteinCount >= 3 && r.lowProteinCount >= 3)
    if let hi = r.highProteinRecoveryMean, let lo = r.lowProteinRecoveryMean {
        #expect(hi > lo, "high-protein days should show higher recovery, got hi=\(hi) lo=\(lo)")
    }
}

@Test func protein_consistency_highCVNoCorrelation() {
    // Protein varies wildly but recovery doesn't track it — high CV, flat recovery.
    let pairs: [ProteinConsistencyVsRecoveryTool.DayObservation] = [
        obs(40,  hrv: 50, sleep: 7.0),
        obs(180, hrv: 50, sleep: 7.0),
        obs(50,  hrv: 51, sleep: 7.1),
        obs(170, hrv: 49, sleep: 6.9),
        obs(45,  hrv: 50, sleep: 7.0),
        obs(175, hrv: 51, sleep: 7.0),
        obs(55,  hrv: 50, sleep: 7.0),
        obs(165, hrv: 50, sleep: 7.1),
        obs(60,  hrv: 50, sleep: 6.9),
        obs(160, hrv: 50, sleep: 7.0)
    ]
    let r = ProteinConsistencyVsRecoveryTool.analyze(pairs: pairs)
    #expect(r.proteinCV > 0.30, "expected high CV, got \(r.proteinCV)")
    let text = ProteinConsistencyVsRecoveryTool.formatResult(r)
    #expect(text.contains("high"), "CV bucket should be 'high', got: \(text)")
}

@Test func protein_consistency_steadyProteinSteadyRecovery() {
    // Both protein and recovery are steady — CV should be in the "steady" bucket.
    let pairs: [ProteinConsistencyVsRecoveryTool.DayObservation] = [
        obs(120, hrv: 55, sleep: 7.5),
        obs(122, hrv: 56, sleep: 7.4),
        obs(118, hrv: 54, sleep: 7.6),
        obs(121, hrv: 55, sleep: 7.5),
        obs(119, hrv: 55, sleep: 7.5),
        obs(123, hrv: 56, sleep: 7.5),
        obs(117, hrv: 54, sleep: 7.4),
        obs(120, hrv: 55, sleep: 7.5),
        obs(122, hrv: 56, sleep: 7.6),
        obs(118, hrv: 55, sleep: 7.4)
    ]
    let r = ProteinConsistencyVsRecoveryTool.analyze(pairs: pairs)
    #expect(r.proteinCV < 0.15, "expected steady CV, got \(r.proteinCV)")
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(r.proteinCV) == "steady")
}

@Test func protein_consistency_emptyPairsAnalyzesCleanly() {
    let r = ProteinConsistencyVsRecoveryTool.analyze(pairs: [])
    #expect(r.totalPairs == 0)
    #expect(r.proteinMean == 0)
    #expect(r.proteinCV == 0)
}

// MARK: - Recovery-score normalization

@Test func protein_consistency_recoveryScoresIn0to1Range() {
    let pairs = (0..<10).map { i in
        obs(100 + Double(i) * 5, hrv: 40 + Double(i) * 3, sleep: 6.0 + Double(i) * 0.2)
    }
    let scores = ProteinConsistencyVsRecoveryTool.computeRecoveryScores(pairs: pairs)
    #expect(scores.count == 10)
    for s in scores {
        #expect(s >= 0 && s <= 1, "score out of [0,1]: \(s)")
    }
}

@Test func protein_consistency_constantInputsScoreMidpoint() {
    // Flat HRV + flat sleep → minMax falls back to 0.5 — composite stays 0.5.
    let pairs = (0..<5).map { _ in obs(120, hrv: 55, sleep: 7.5) }
    let scores = ProteinConsistencyVsRecoveryTool.computeRecoveryScores(pairs: pairs)
    for s in scores {
        #expect(abs(s - 0.5) < 0.001, "flat inputs should normalize to 0.5, got \(s)")
    }
}

// MARK: - CV bucket thresholds

@Test func protein_consistency_cvBuckets() {
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(0.05) == "steady")
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(0.149) == "steady")
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(0.15) == "moderate")
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(0.25) == "moderate")
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(0.30) == "high")
    #expect(ProteinConsistencyVsRecoveryTool.cvBucket(0.50) == "high")
}

// MARK: - formatResult output

@Test func protein_consistency_formatIncludesAvg() {
    let pairs: [ProteinConsistencyVsRecoveryTool.DayObservation] = [
        obs(100, hrv: 45, sleep: 7.0),
        obs(120, hrv: 60, sleep: 7.5),
        obs(110, hrv: 50, sleep: 7.2),
        obs(130, hrv: 65, sleep: 8.0),
        obs(105, hrv: 48, sleep: 7.1),
        obs(125, hrv: 62, sleep: 7.7),
        obs(115, hrv: 55, sleep: 7.4),
        obs(135, hrv: 68, sleep: 8.1),
        obs(118, hrv: 56, sleep: 7.3),
        obs(128, hrv: 64, sleep: 7.9)
    ]
    let r = ProteinConsistencyVsRecoveryTool.analyze(pairs: pairs)
    let text = ProteinConsistencyVsRecoveryTool.formatResult(r)
    #expect(text.contains("avg"))
    #expect(text.contains("g"))
    #expect(text.contains("CV"))
}
