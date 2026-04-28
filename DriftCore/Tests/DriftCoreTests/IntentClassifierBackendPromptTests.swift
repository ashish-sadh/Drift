import Foundation
@testable import DriftCore
import Testing

/// Pin the contract for backend-aware prompt selection added with #515.
/// Three-way fan-out: local-small → routerPrompt, local-large → intelligence,
/// remote → remotePrompt (intelligence + brevity-clamping extras).

@Test func activeSystemPrompt_remoteBackendReturnsRemotePrompt() {
    #expect(IntentClassifier.activeSystemPrompt(backend: .remote) == IntentClassifier.remotePrompt)
}

@Test func activeSystemPrompt_llamaCppReturnsIntelligencePrompt() {
    // Local backends get intelligencePrompt regardless of tier — the agent's
    // tiered pipeline downshifts to routerPrompt explicitly when the small
    // model is loaded (see IntentClassifier+Live.classifyFull). The
    // backend-aware variant only fans out by backend type.
    #expect(IntentClassifier.activeSystemPrompt(backend: .llamaCpp) == IntentClassifier.intelligencePrompt)
}

@Test func activeSystemPrompt_mlxReturnsIntelligencePrompt() {
    #expect(IntentClassifier.activeSystemPrompt(backend: .mlx) == IntentClassifier.intelligencePrompt)
}

// MARK: - Token Ceilings

/// Cloud LLMs charge per token in. The remotePrompt is paired with the
/// intelligence prompt's tool list + chat history + recent_entries every
/// turn — keep it lean. 16K char ceiling lets a Sonnet/Opus request fit
/// comfortably under any provider's per-request limit even with the photo
/// blob attached on photo turns. #515.
@Test func remotePrompt_underTokenCeiling() {
    let chars = IntentClassifier.remotePrompt.count
    #expect(chars <= 16000, "remotePrompt is \(chars) chars — over 16K ceiling")
}

@Test func remotePrompt_isStrictlyLargerThanIntelligencePrompt() {
    // remotePrompt = intelligencePrompt + extras. Catches accidental swap
    // where the extras get nilled out and remotePrompt ≡ intelligencePrompt.
    #expect(IntentClassifier.remotePrompt.count > IntentClassifier.intelligencePrompt.count)
}

@Test func remotePrompt_containsBrevityClamps() {
    // The whole point of the remote extras is to reshape verbose cloud-LLM
    // defaults toward Drift's terse house style. If these markers vanish,
    // someone has gutted the spec.
    let prompt = IntentClassifier.remotePrompt
    #expect(prompt.contains("Brevity is the bar"), "missing brevity preamble")
    #expect(prompt.contains("Hard ceiling: 50 words"), "missing word-count ceiling")
    #expect(prompt.contains("propose_meal"), "missing photo-card protocol")
}

// MARK: - Backend Type Round-Trip

@Test func aiBackendType_rawValueRoundTrips() {
    // Preferences serializes by rawValue — round-trip protects against
    // accidental case-only changes that would orphan stored preferences.
    for backend in [AIBackendType.llamaCpp, .mlx, .remote] {
        let raw = backend.rawValue
        let decoded = AIBackendType(rawValue: raw)
        #expect(decoded == backend, "round-trip failed for \(backend)")
    }
}
