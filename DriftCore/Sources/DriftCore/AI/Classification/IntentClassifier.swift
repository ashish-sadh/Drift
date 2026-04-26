import Foundation

/// LLM-driven intent classification + tool calling.
/// Pure (nonisolated) parts live here so tests on macOS can exercise the
/// classifier without an iOS simulator. The MainActor-bound methods that
/// reach into `ConversationState` / `LocalAIService` live in the Drift app.
public enum IntentClassifier {

    // MARK: - Intent Types

    public struct ClassifiedIntent: Sendable {
        public let tool: String
        public let params: [String: String]
        public let confidence: String

        public init(tool: String, params: [String: String], confidence: String) {
            self.tool = tool
            self.params = params
            self.confidence = confidence
        }
    }

    public enum ClassifyResult: Sendable {
        case toolCall(ClassifiedIntent)
        case text(String)
    }

    // MARK: - System Prompt

    public static let systemPrompt: String = """
    Health app. Reply JSON tool call or short text. Fix typos, word numbers, slang.
    Tools: log_food(name,servings?,calories?,protein?,carbs?,fat?) food_info(query) log_weight(value,unit?) weight_info(query?) start_workout(name?) log_activity(name,duration?) exercise_info(query?) sleep_recovery(period?) mark_supplement(name) supplements() set_goal(target,unit?,goal_type?) delete_food(entry_id?,name?) edit_meal(entry_id?,meal_period?,action,target_food?,new_value?) body_comp() glucose() biomarkers() navigate_to(screen) cross_domain_insight(metric_a,metric_b,window_days?) weight_trend_prediction()
    <recent_entries>: match user's row reference (ordinal/calories/meal/"just logged") → entry_id. Default: name/target_food.
    Rules: never invent health data — call a tool. "calories in X"→food_info (not log_food). log_food when user ate/had OR said log/add/track/record with a named food. Bare "log lunch/breakfast/dinner" (no food)→ask what they had. "search/find X in my logs"→food_info, not log_food. summary/intake/macros/micronutrients(fiber/sodium/sugar)→food_info. goal progress/hitting/on track→food_info. weight trend→weight_info. body fat/lean mass/DEXA→body_comp. blood sugar/glucose spike→glucose. lab results/biomarkers/cholesterol→biomarkers. sleep/HRV→sleep_recovery. "go to X"/"open X"→navigate_to. supplements() for any supplement status question (never text). mark_supplement when user took/had one.
    Act when user names food/supplement/exercise/weight/screen. Ask only when no object (bare "log"/"track"/"add") or two tools fit.
    "daily summary"→{"tool":"food_info","query":"daily summary"}
    "lab results"→{"tool":"biomarkers"}
    "weight trend"→{"tool":"weight_info","query":"trend"}
    "had biryani"→{"tool":"log_food","name":"biryani"}
    "I had 2 to 3 banans"→{"tool":"log_food","name":"banana","servings":"3"}
    "chipotle bowl 3000 cal 30p 45c 67f"→{"tool":"log_food","name":"chipotle bowl","calories":"3000","protein":"30","carbs":"45","fat":"67"}
    "calories left"→{"tool":"food_info","query":"calories left"}
    "calories in samosa"→{"tool":"food_info","query":"calories in samosa"}
    "how am I doing"→{"tool":"food_info","query":"daily summary"}
    "how much fiber today"→{"tool":"food_info","query":"fiber today"}
    "sodium today"→{"tool":"food_info","query":"sodium today"}
    "am I hitting my protein goal"→{"tool":"food_info","query":"protein goal"}
    "on track for calories"→{"tool":"food_info","query":"calorie goal"}
    "set protein target 150g"→{"tool":"set_goal","target":"150","goal_type":"protein"}
    "calorie target 2000"→{"tool":"set_goal","target":"2000","goal_type":"calorie"}
    "log 2 eggs"→{"tool":"log_food","name":"egg","servings":"2"}
    "I weigh 75 kg"→{"tool":"log_weight","value":"75","unit":"kg"}
    "start push day"→{"tool":"start_workout","name":"push day"}
    "did yoga for like half an hour"→{"tool":"log_activity","name":"yoga","duration":"30"}
    "took vitamin d"→{"tool":"mark_supplement","name":"vitamin d"}
    "did I take my vitamins"→{"tool":"supplements"}
    "any glucose spikes"→{"tool":"glucose"}
    "my hrv today"→{"tool":"sleep_recovery","query":"hrv"}
    "how's my muscle recovery"→{"tool":"exercise_info","query":"muscle recovery"}
    "set my goal to one sixty"→{"tool":"set_goal","target":"160","unit":"lbs"}
    "delete last"→{"tool":"delete_food"}
    "remove rice from lunch"→{"tool":"edit_meal","meal_period":"lunch","action":"remove","target_food":"rice"}
    "update oatmeal in breakfast to 200g"→{"tool":"edit_meal","meal_period":"breakfast","action":"update_quantity","target_food":"oatmeal","new_value":"200g"}
    "swap chicken for tofu in dinner"→{"tool":"edit_meal","meal_period":"dinner","action":"replace","target_food":"chicken","new_value":"tofu"}
    <recent_entries> "42|lunch|rice|180cal|3m": "delete the rice I just logged"→{"tool":"delete_food","entry_id":"42"}. "edit the 500 cal one to 2 servings" with id 7→{"tool":"edit_meal","entry_id":"7","action":"update_quantity","new_value":"2"}. Ordinals: match row by position.
    "when will I reach my goal weight"→{"tool":"weight_trend_prediction"}
    "did I lose weight on workout days"→{"tool":"cross_domain_insight","metric_a":"weight","metric_b":"workout_volume"}
    "glucose vs carbs last week"→{"tool":"cross_domain_insight","metric_a":"glucose_avg","metric_b":"carbs","window_days":"7"}
    "show me my weight chart"→{"tool":"navigate_to","screen":"weight"}
    "is it okay to take fish oil on an empty stomach"→Fish oil is generally fine with or without food.
    "log lunch"→What did you have for lunch?
    "hi"→Hi! How can I help?
    "log"→What would you like to log — food, weight, or a workout?
    If chat context shows "What did you have for lunch?" and user says "rice and dal"→{"tool":"log_food","name":"rice, dal"}
    JSON when ready. Ask if missing details. Text for chat.
    """

    // MARK: - Recent-Entries Triggers

    /// Trigger tokens that switch on recent-entries context injection. Kept
    /// narrow to avoid leaking the window into unrelated turns where the
    /// tokens would just waste budget.
    public static let deleteEditTriggers: [String] = [
        "delete", "remove", "undo", "edit", "change", "update",
        "replace", "swap", "the one", "the first", "the second",
        "the last", "the 500", "just logged", "just added",
        "instead", "actually i had", "no, i had", "no i had"
    ]

    /// Heuristic: does this message plausibly reference a recent entry?
    public static func needsRecentEntries(_ message: String) -> Bool {
        let lower = message.lowercased()
        return deleteEditTriggers.contains(where: { lower.contains($0) })
    }

    // MARK: - Build User Message

    /// Build the user message with optional history context. Deterministic, test-friendly.
    /// The MainActor-aware variant in the Drift app injects recent-entries context.
    public static func buildUserMessage(message: String, history: String) -> String {
        composeUserMessage(message: message, history: history, recentBlock: nil)
    }

    /// Pure composer. Order of precedence: `<recent_entries>` → `Chat:` → `User:`.
    /// Falls back to the bare message when neither recent-entries nor history applies.
    public static func composeUserMessage(
        message: String, history: String, recentBlock: String?, literalHint: String? = nil
    ) -> String {
        if recentBlock == nil && history.isEmpty && literalHint == nil { return message }
        var parts: [String] = []
        if let recentBlock { parts.append(recentBlock) }
        if !history.isEmpty { parts.append("Chat:\n\(String(history.prefix(400)))") }
        if let literalHint { parts.append("Hint: \(literalHint)") }
        parts.append("User: \(message)")
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Parse Response

    /// Map raw LLM response string to a ClassifyResult.
    public static func mapResponse(_ response: String?) -> ClassifyResult? {
        guard let response else { return nil }
        if let intent = parseResponse(response) {
            return .toolCall(intent)
        }
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return .text(cleaned)
    }

    /// Parse LLM response into intent. Returns nil for non-tool-call responses.
    public static func parseResponse(_ response: String) -> ClassifiedIntent? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return nil
        }

        let jsonStr = String(trimmed[jsonStart...jsonEnd])
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = json["tool"] as? String,
              !tool.isEmpty else {
            return nil
        }

        var params: [String: String] = [:]
        for (key, value) in json where key != "tool" {
            if let str = value as? String {
                params[key] = str
            } else if let arr = value as? [String] {
                params[key] = arr.joined(separator: ", ")
            } else if let num = value as? Int {
                params[key] = "\(num)"
            } else if let num = value as? Double {
                params[key] = "\(num)"
            }
        }

        return ClassifiedIntent(
            tool: tool,
            params: params,
            confidence: json["confidence"] as? String ?? "high"
        )
    }

    // MARK: - Timeout Helper

    public static func withTimeout<T: Sendable>(seconds: Int, operation: @Sendable @escaping () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
