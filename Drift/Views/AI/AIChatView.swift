import SwiftUI
import PhotosUI

/// Action-oriented AI assistant — buttons first, text secondary.
/// No free-form LLM chat. Structured actions powered by rule engine.
struct AIChatView: View {
    var currentTab: Int = 0
    @State private var aiService = LocalAIService.shared
    @State private var resultText = ""
    @State private var inputText = ""
    @State private var mode: AssistantMode = .actions
    @State private var showingFoodSearch = false
    @State private var foodSearchQuery = ""
    @State private var foodSearchServings: Double? = nil
    @FocusState private var inputFocused: Bool

    enum AssistantMode {
        case actions      // Show action buttons
        case foodInput    // "What did you eat?" text input
        case result       // Showing a result
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    // Page-aware context insight
                    let insight = pageInsight
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.accent)
                        Text(insight).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // Result display
                    if !resultText.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.accent)
                            Text(resultText).font(.caption).foregroundStyle(.primary)
                            Spacer()
                            Button { resultText = ""; mode = .actions } label: {
                                Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Action grid — ALWAYS visible
                    actionGrid

                    // Food input hint
                    if mode == .foodInput {
                        Text("Type what you ate below")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }

            Divider().overlay(Color.white.opacity(0.06))

            // Bottom input
            bottomInput
        }
        .sheet(isPresented: $showingFoodSearch) {
            NavigationStack {
                FoodSearchView(viewModel: FoodLogViewModel(), initialQuery: foodSearchQuery, initialServings: foodSearchServings)
            }
        }
    }

    // MARK: - Page-Aware Insight

    private var pageInsight: String {
        switch currentTab {
        case 0: // Dashboard
            return AIRuleEngine.quickInsight() ?? "Welcome to Drift."
        case 1: // Weight
            if let entries = try? AppDatabase.shared.fetchWeightEntries(),
               let trend = WeightTrendCalculator.calculateTrend(entries: entries.map { ($0.date, $0.weightKg) }) {
                let u = Preferences.weightUnit
                return "Weight: \(String(format: "%.1f", u.convert(fromKg: trend.currentEMA))) \(u.displayName), \(String(format: "%+.2f", u.convert(fromKg: trend.weeklyRateKg)))/wk"
            }
            return "Log your weight to start tracking."
        case 2: // Food
            let today = DateFormatters.todayString
            let n = (try? AppDatabase.shared.fetchDailyNutrition(for: today)) ?? .zero
            return n.calories > 0
                ? "Today: \(Int(n.calories))cal, \(Int(n.proteinG))P \(Int(n.carbsG))C \(Int(n.fatG))F"
                : "No food logged today. Tap Log Food below."
        case 3: // Exercise
            if let workouts = try? WorkoutService.fetchWorkouts(limit: 1), let last = workouts.first {
                return "Last workout: \(last.name) (\(last.date))"
            }
            return "Start a workout from your templates."
        case 4: // More
            return "Settings, supplements, cycle tracking, and more."
        default:
            return AIRuleEngine.quickInsight() ?? "How can I help?"
        }
    }

    // MARK: - Action Grid

    private var actionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 10) {
            actionButton(icon: "fork.knife", label: "Log Food", color: Theme.carbsGreen) {
                mode = .foodInput
                resultText = ""
                inputFocused = true
            }
            actionButton(icon: "scalemass", label: "Weight", color: Theme.accent) {
                mode = .result
                resultText = "Loading..."
                Task {
                    let context = AIContextBuilder.buildContext(tab: currentTab, action: "weight")
                    let prompt = AIContextBuilder.actionPrompt(for: "weight")
                    let response = await aiService.respond(to: prompt, context: context)
                    resultText = response.isEmpty ? AIContextBuilder.weightContext() : response
                }
            }
            actionButton(icon: "chart.bar", label: "Summary", color: Theme.calorieBlue) {
                mode = .result
                resultText = "Loading..."
                Task {
                    let context = AIContextBuilder.buildContext(tab: currentTab, action: "summary")
                    let prompt = AIContextBuilder.actionPrompt(for: "summary")
                    let response = await aiService.respond(to: prompt, context: context)
                    resultText = response.isEmpty ? AIRuleEngine.dailySummary() : response
                }
            }
            actionButton(icon: "dumbbell", label: "Workout", color: Theme.stepsOrange) {
                mode = .result
                resultText = "Loading..."
                Task {
                    let context = AIContextBuilder.buildContext(tab: currentTab, action: "workout")
                    let prompt = AIContextBuilder.actionPrompt(for: "workout")
                    let response = await aiService.respond(to: prompt, context: context)
                    resultText = response.isEmpty ? AIContextBuilder.workoutContext() : response
                }
            }
            actionButton(icon: "pill", label: "Supps", color: .mint) {
                let today = DateFormatters.todayString
                if let supplements = try? AppDatabase.shared.fetchActiveSupplements(),
                   let logs = try? AppDatabase.shared.fetchSupplementLogs(for: today) {
                    let taken = logs.filter(\.taken).count
                    resultText = "Supplements: \(taken)/\(supplements.count) taken today."
                } else {
                    resultText = "No supplements set up."
                }
                mode = .result
            }
            actionButton(icon: "clock", label: "Yesterday", color: .secondary) {
                resultText = AIRuleEngine.yesterdaySummary()
                mode = .result
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Food Input

    private var foodInputSection: some View {
        VStack(spacing: 10) {
            Text("What did you eat?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                mode = .actions
                inputText = ""
            } label: {
                Text("Cancel").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Bottom Input

    private var bottomInput: some View {
        HStack(spacing: 8) {
            TextField(mode == .foodInput ? "e.g. 2 eggs, 1/3 avocado..." : "Type a command...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .focused($inputFocused)
                .onSubmit { handleInput() }

            Button { handleInput() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(inputText.isEmpty ? Color.gray : Theme.accent)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Handle Input

    private func handleInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        if mode == .foodInput {
            // User typed a food name — search and open
            // Try exact match first, then fuzzy
            var query = text
            if let intent = AIActionExecutor.parseFoodIntent("log \(text)") {
                query = intent.query
                foodSearchServings = intent.servings
            } else {
                foodSearchServings = nil
            }
            // Fuzzy: try variations (remove trailing s, common misspellings)
            foodSearchQuery = query
            showingFoodSearch = true
            mode = .actions
            resultText = ""
            return
        }

        // Parse as command
        let lower = text.lowercased()

        // Food intent
        if let intent = AIActionExecutor.parseFoodIntent(lower) {
            if let match = AIActionExecutor.findFood(query: intent.query, servings: intent.servings) {
                foodSearchQuery = intent.query
                foodSearchServings = intent.servings
                showingFoodSearch = true
            } else {
                foodSearchQuery = intent.query
                foodSearchServings = intent.servings
                showingFoodSearch = true
            }
            return
        }

        // Data queries
        if lower.contains("summary") || lower.contains("today") || lower.contains("how am i") {
            resultText = AIRuleEngine.dailySummary()
            mode = .result
            return
        }
        if lower.contains("yesterday") {
            resultText = AIRuleEngine.yesterdaySummary()
            mode = .result
            return
        }
        if lower.contains("calorie") || lower.contains("protein") || lower.contains("macro") {
            let today = DateFormatters.todayString
            let n = (try? AppDatabase.shared.fetchDailyNutrition(for: today)) ?? .zero
            resultText = n.calories > 0
                ? "Today: \(Int(n.calories))cal, \(Int(n.proteinG))P \(Int(n.carbsG))C \(Int(n.fatG))F"
                : "No food logged today."
            mode = .result
            return
        }
        if lower.contains("weight") {
            if let entries = try? AppDatabase.shared.fetchWeightEntries(),
               let trend = WeightTrendCalculator.calculateTrend(entries: entries.map { ($0.date, $0.weightKg) }) {
                let u = Preferences.weightUnit
                resultText = "Weight: \(String(format: "%.1f", u.convert(fromKg: trend.currentEMA))) \(u.displayName), \(String(format: "%+.2f", u.convert(fromKg: trend.weeklyRateKg)))/wk"
            } else {
                resultText = "No weight data yet."
            }
            mode = .result
            return
        }

        // Unknown — send to LLM with page-specific context
        mode = .result
        resultText = "Thinking..."
        Task {
            let context = AIContextBuilder.buildContext(tab: currentTab)
            let response = await aiService.respond(to: text, context: context)
            if response.isEmpty {
                resultText = "I couldn't process that. Try the buttons above or a specific question."
            } else {
                resultText = response
                // Auto-execute any actions in the response
                let parsed = AIActionParser.parse(response)
                switch parsed.action {
                case .logFood(let name, _):
                    foodSearchQuery = name
                    showingFoodSearch = true
                case .startWorkout:
                    break
                default:
                    break
                }
            }
        }
    }
}
