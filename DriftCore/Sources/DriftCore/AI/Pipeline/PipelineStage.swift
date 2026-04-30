/// The six logical stages of the AI tool pipeline, used for failure attribution
/// in gold-set evaluations and debug-mode stage tracing.
///
/// Order mirrors AIToolAgent execution:
///   normalization → staticRules → toolRanker → llmIntent → extraction → execution → presentation
public enum PipelineStage: String, Sendable, CaseIterable {
    /// Stage 0 — InputNormalizer: voice repair, typo correction, language normalisation.
    case normalization
    /// Stage 1 — Static rules: parseFoodIntent, StaticOverrides, IntentContextResolver.
    case staticRules
    /// Stage 2 — ToolRanker: routes the normalised input to the highest-confidence tool.
    case toolRanker
    /// Stage 3 — LLM intent classification: Gemma extracts tool + params from the prompt.
    case llmIntent
    /// Stage 4 — DomainExtractor: pulls structured fields (food name, quantity, date) from LLM output.
    case extraction
    /// Stage 5 — Tool execution: FoodService / WeightService / etc. perform the operation.
    case execution
    /// Stage 6 — Presentation: LLM-streamed or template-rendered reply to the user.
    case presentation
}
