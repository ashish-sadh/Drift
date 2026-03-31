import Foundation

/// Seeds default workout templates on first launch. Respects user edits - only seeds if no templates exist.
enum DefaultTemplates {
    private static let seededKey = "drift_default_templates_v2"

    static func seedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard (try? WorkoutService.fetchTemplates())?.isEmpty ?? true else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        for template in programTemplates {
            var t = template
            try? WorkoutService.saveTemplate(&t)
        }

        // Add all custom exercises that aren't in the 873 DB
        let dbNames = Set(ExerciseDatabase.all.map { $0.name.lowercased() })
        for (name, bodyPart) in customExercises {
            if !dbNames.contains(name.lowercased()) {
                ExerciseDatabase.addCustomExercise(name: name, bodyPart: bodyPart)
            }
        }

        UserDefaults.standard.set(true, forKey: seededKey)
        Log.app.info("Seeded \(programTemplates.count) default workout templates")
    }

    /// Exercises not in the free-exercise-db that need to be added as custom
    private static let customExercises: [(String, String)] = [
        // Warmup
        ("Banded Shoulder Rotations", "Shoulders"),
        ("Banded Pull Aparts (Palms Up)", "Shoulders"),
        ("Banded Pull Aparts (Palms Down)", "Shoulders"),
        ("Shoulder Depressions", "Shoulders"),
        ("Rope Pulling Machine", "Full Body"),
        ("Ladder Drill", "Full Body"),
        ("90/90 Hip Stretch + Extensions", "Legs"),
        // Chest
        ("Incline Chest Press", "Chest"),
        ("Standing Cable Chest Flies (High to Low)", "Chest"),
        // Core
        ("Crunch Machine", "Core"),
        ("Yoga Ball Pike", "Core"),
        ("Woodchopper", "Core"),
        ("Paloff Press", "Core"),
        // Back
        ("High Rows", "Back"),
        ("TRX Rows", "Back"),
        ("Assisted Pull-Ups", "Back"),
        // Arms
        ("Wrist Extension", "Arms"),
        ("Wrist Flexion", "Arms"),
        ("Barbell Wrist Rolls", "Arms"),
        ("Plate Pinches", "Arms"),
        // Legs
        ("Bulgarian Split Squats", "Legs"),
        // Common gym exercises not in the 873 DB
        ("Ab Wheel Rollout", "Core"),
        ("Battle Ropes", "Full Body"),
        ("Box Jump", "Legs"),
        ("Mountain Climber", "Core"),
        ("Hip Abductor Machine", "Legs"),
        ("Hip Adductor Machine", "Legs"),
        ("Chest Supported Row", "Back"),
        ("Spider Curl", "Arms"),
        ("Cable Lateral Raise", "Shoulders"),
        ("Cable Tricep Kickback", "Arms"),
        ("Seated Cable Row", "Back"),
        ("Machine Chest Press", "Chest"),
        ("Machine Shoulder Press", "Shoulders"),
        ("Assisted Dips", "Chest"),
    ]

    // MARK: - Trainer Program (exact from plan)

    private static var programTemplates: [WorkoutTemplate] {
        let encoder = JSONEncoder()
        func json(_ exercises: [WorkoutTemplate.TemplateExercise]) -> String {
            (try? encoder.encode(exercises)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
        let now = ISO8601DateFormatter().string(from: Date())

        return [
            // ── Day 1 - Chest/Core (Monday) ──
            WorkoutTemplate(name: "Day 1 - Chest/Core", exercisesJson: json([
                // Warmup circuit
                .init(name: "Banded Shoulder Rotations", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Pull Aparts (Palms Up)", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Pull Aparts (Palms Down)", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Shoulder Depressions", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Dumbbell Shrug", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x15"),
                // Working sets
                .init(name: "Incline Chest Press", sets: 3, restSeconds: 150, notes: "5-8 reps"),
                .init(name: "Dumbbell Bench Press", sets: 3, restSeconds: 120, notes: "8-10 reps"),
                .init(name: "Dips", sets: 3, restSeconds: 120, notes: "8-12 reps"),
                .init(name: "Leg Raise", sets: 3, restSeconds: 90, notes: "8-10 reps, Captain's Chair"),
                .init(name: "Crunch Machine", sets: 3, restSeconds: 90, notes: "8-12 reps"),
                .init(name: "Back Extension", sets: 3, restSeconds: 90, notes: "8-12 reps"),
            ]), createdAt: now),

            // ── Day 2 - Forearms/Accessories (Tuesday) ──
            WorkoutTemplate(name: "Day 2 - Forearms/Accessories", exercisesJson: json([
                // Warmup
                .init(name: "Rope Pulling Machine", sets: 1, isWarmup: true, restSeconds: 30, notes: "5 mins"),
                .init(name: "Banded Shoulder Rotations", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                // Working sets
                .init(name: "Lat Pulldown", sets: 3, restSeconds: 105, notes: "8-10 reps, scap depression"),
                .init(name: "High Rows", sets: 3, restSeconds: 105, notes: "8-12 reps, upper"),
                .init(name: "Reverse Barbell Curl", sets: 3, restSeconds: 75, notes: "10-15 reps"),
                .init(name: "Wrist Extension", sets: 3, restSeconds: 45, notes: "10-15 reps"),
                .init(name: "Wrist Flexion", sets: 3, restSeconds: 45, notes: "10-15 reps"),
                .init(name: "Farmer's Walk", sets: 3, restSeconds: 75, notes: "30-45 secs"),
                .init(name: "Shoulder Press", sets: 3, restSeconds: 75, notes: "10-15 reps"),
                .init(name: "Lateral Raise", sets: 3, restSeconds: 75, notes: "10-15 reps"),
            ]), createdAt: now),

            // ── Day 3 - Chest/Core (Thursday) ──
            WorkoutTemplate(name: "Day 3 - Chest/Core", exercisesJson: json([
                // Warmup circuit
                .init(name: "Banded Shoulder Rotations", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Pull Aparts (Palms Up)", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Pull Aparts (Palms Down)", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Shoulder Depressions", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Dumbbell Shrug", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x15"),
                // Working sets
                .init(name: "Incline Dumbbell Press", sets: 3, restSeconds: 120, notes: "10-12 reps, 30° bench"),
                .init(name: "Push-Ups", sets: 3, restSeconds: 120, notes: "20 reps, strict then assisted"),
                .init(name: "Standing Cable Chest Flies (High to Low)", sets: 3, restSeconds: 60, notes: "12-15 reps, shoulders down"),
                .init(name: "Yoga Ball Pike", sets: 3, restSeconds: 75, notes: "8-12 reps, shins/knees tucked"),
                .init(name: "Woodchopper", sets: 3, restSeconds: 75, notes: "8-15 reps, superset w/ Paloff Press"),
                .init(name: "Decline Crunch", sets: 3, restSeconds: 75, notes: "8-15 reps, reach hands up, use weight"),
            ]), createdAt: now),

            // ── Day 4 - Lower Body/Forearms (flexible day) ──
            WorkoutTemplate(name: "Day 4 - Lower/Forearms", exercisesJson: json([
                // Warmup
                .init(name: "Ladder Drill", sets: 1, isWarmup: true, restSeconds: 30, notes: "2-5 mins"),
                .init(name: "90/90 Hip Stretch + Extensions", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Shoulder Rotations", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Pull Aparts (Palms Up)", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                .init(name: "Banded Pull Aparts (Palms Down)", sets: 2, isWarmup: true, restSeconds: 15, notes: "2x10"),
                // Working sets
                .init(name: "Deadlift", sets: 3, restSeconds: 150, notes: "2-3x5-8 reps"),
                .init(name: "Assisted Pull-Ups", sets: 3, restSeconds: 150, notes: "5-8 reps"),
                .init(name: "Bulgarian Split Squats", sets: 3, restSeconds: 120, notes: "8-10 reps"),
                .init(name: "TRX Rows", sets: 3, restSeconds: 105, notes: "8-12 reps"),
                .init(name: "Hammer Curls", sets: 3, restSeconds: 75, notes: "8-15 reps"),
                .init(name: "Barbell Wrist Rolls", sets: 3, restSeconds: 75, notes: "10-15 reps"),
                .init(name: "Plate Pinches", sets: 3, restSeconds: 75, notes: "20-30 secs"),
            ]), createdAt: now),
        ]
    }
}
