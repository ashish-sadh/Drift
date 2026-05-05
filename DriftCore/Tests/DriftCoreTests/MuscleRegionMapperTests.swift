import Testing
@testable import DriftCore

@Suite struct MuscleRegionMapperTests {

    // MARK: - region(for:) known mappings

    @Test func quadriceps_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "quadriceps") == .quadriceps)
        #expect(MuscleRegionMapper.region(for: "quads") == .quadriceps)
        #expect(MuscleRegionMapper.region(for: "Quadriceps") == .quadriceps)
    }

    @Test func shoulders_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "shoulders") == .shoulders)
        #expect(MuscleRegionMapper.region(for: "deltoids") == .shoulders)
        #expect(MuscleRegionMapper.region(for: "delts") == .shoulders)
    }

    @Test func abdominals_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "abdominals") == .abdominals)
        #expect(MuscleRegionMapper.region(for: "abs") == .abdominals)
        #expect(MuscleRegionMapper.region(for: "core") == .abdominals)
    }

    @Test func chest_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "chest") == .chest)
        #expect(MuscleRegionMapper.region(for: "pectorals") == .chest)
        #expect(MuscleRegionMapper.region(for: "pecs") == .chest)
    }

    @Test func back_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "middle back") == .middleBack)
        #expect(MuscleRegionMapper.region(for: "rhomboids") == .middleBack)
        #expect(MuscleRegionMapper.region(for: "lats") == .lats)
        #expect(MuscleRegionMapper.region(for: "latissimus dorsi") == .lats)
        #expect(MuscleRegionMapper.region(for: "lower back") == .lowerBack)
        #expect(MuscleRegionMapper.region(for: "erectors") == .lowerBack)
        #expect(MuscleRegionMapper.region(for: "traps") == .traps)
        #expect(MuscleRegionMapper.region(for: "trapezius") == .traps)
    }

    @Test func arms_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "triceps") == .triceps)
        #expect(MuscleRegionMapper.region(for: "biceps") == .biceps)
        #expect(MuscleRegionMapper.region(for: "forearms") == .forearms)
    }

    @Test func legs_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "hamstrings") == .hamstrings)
        #expect(MuscleRegionMapper.region(for: "calves") == .calves)
        #expect(MuscleRegionMapper.region(for: "glutes") == .glutes)
        #expect(MuscleRegionMapper.region(for: "gluteus maximus") == .glutes)
        #expect(MuscleRegionMapper.region(for: "adductors") == .adductors)
        #expect(MuscleRegionMapper.region(for: "inner thigh") == .adductors)
        #expect(MuscleRegionMapper.region(for: "abductors") == .abductors)
        #expect(MuscleRegionMapper.region(for: "outer thigh") == .abductors)
    }

    @Test func neck_mapsCorrectly() {
        #expect(MuscleRegionMapper.region(for: "neck") == .neck)
    }

    @Test func unknown_returnsNil() {
        #expect(MuscleRegionMapper.region(for: "") == nil)
        #expect(MuscleRegionMapper.region(for: "cardio") == nil)
        #expect(MuscleRegionMapper.region(for: "full body") == nil)
    }

    @Test func caseInsensitive() {
        #expect(MuscleRegionMapper.region(for: "BICEPS") == .biceps)
        #expect(MuscleRegionMapper.region(for: "Hamstrings") == .hamstrings)
        #expect(MuscleRegionMapper.region(for: "LOWER BACK") == .lowerBack)
    }

    // MARK: - regions(for:)

    @Test func regions_deduplicates() {
        let result = MuscleRegionMapper.regions(for: ["biceps", "biceps", "chest"])
        #expect(result.count == 2)
        #expect(result.contains(.biceps))
        #expect(result.contains(.chest))
    }

    @Test func regions_skipsUnknowns() {
        let result = MuscleRegionMapper.regions(for: ["biceps", "unknownMuscle", "chest"])
        #expect(result.count == 2)
    }

    @Test func regions_emptyInput_returnsEmpty() {
        #expect(MuscleRegionMapper.regions(for: []).isEmpty)
    }

    // MARK: - MuscleRegion.side

    @Test func frontMuscles_haveFrontSide() {
        let front: [MuscleRegion] = [.quadriceps, .abdominals, .chest, .biceps, .forearms, .adductors]
        for region in front {
            #expect(region.side == .front, "\(region) should be .front")
        }
    }

    @Test func backMuscles_haveBackSide() {
        let back: [MuscleRegion] = [.hamstrings, .lats, .middleBack, .lowerBack, .glutes, .calves, .traps, .triceps, .abductors]
        for region in back {
            #expect(region.side == .back, "\(region) should be .back")
        }
    }

    @Test func bothSideMuscles_haveBothSide() {
        #expect(MuscleRegion.shoulders.side == .both)
        #expect(MuscleRegion.neck.side == .both)
    }

    @Test func allRegions_haveSide() {
        // Every case must resolve to a non-nil side — compile-time exhaustiveness covers this,
        // but we assert it runs without hitting a switch default.
        for region in MuscleRegion.allCases {
            let side = region.side
            #expect(side == .front || side == .back || side == .both)
        }
    }
}
