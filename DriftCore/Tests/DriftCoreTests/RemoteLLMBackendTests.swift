import Foundation
@testable import DriftCore
import Testing

// MARK: - Mock HTTP Session

/// Returns pre-canned Data for every request. No network I/O.
struct MockHTTPSession: HTTPDataSession, Sendable {
    let responseData: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

struct MockHTTPSessionError: HTTPDataSession, Sendable {
    let statusCode: Int

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

// MARK: - Canned SSE Fixtures

private enum SSEFixture {
    /// Anthropic streaming SSE with one text content block delivering "Hello world".
    static let textResponse = Data("""
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_01","type":"message","role":"assistant","model":"claude-sonnet-4-6","content":[],"stop_reason":null,"usage":{"input_tokens":10,"output_tokens":1}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}

        event: message_stop
        data: {"type":"message_stop"}

        """.utf8)

    /// Anthropic streaming SSE with a tool_use block for log_food(name=eggs, servings=2).
    static let toolCallResponse = Data("""
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_02","type":"message","role":"assistant","model":"claude-sonnet-4-6","content":[],"stop_reason":null,"usage":{"input_tokens":20,"output_tokens":1}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01","name":"log_food","input":{}}}

        event: ping
        data: {"type":"ping"}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"name\\":"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"\\"eggs\\","}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"\\"servings\\":\\"2\\"}"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":18}}

        event: message_stop
        data: {"type":"message_stop"}

        """.utf8)
}

// MARK: - Request-Capturing Session

private final class RequestBox: @unchecked Sendable { var request: URLRequest? }

private struct CapturingSession: HTTPDataSession, Sendable {
    let box: RequestBox
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        box.request = request
        let r = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(), r)
    }
}

// MARK: - RemoteLLMBackend Tests

/// Tier-0: no real network, no model. MockHTTPSession returns pre-canned SSE.
struct RemoteLLMBackendTests {

    // MARK: - Init / isLoaded

    @Test func isLoadedWhenAPIKeyProvided() {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: Data())
        )
        #expect(backend.isLoaded == true)
    }

    @Test func notLoadedWhenAPIKeyNil() {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: nil, session: MockHTTPSession(responseData: Data())
        )
        #expect(backend.isLoaded == false)
    }

    @Test func loadAndUnloadAreNoOps() async throws {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: Data())
        )
        try await backend.load()
        backend.unload()
        #expect(backend.isLoaded == true)
    }

    @Test func supportsVisionIsFalse() {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: Data())
        )
        #expect(backend.supportsVision == false)
    }

    // MARK: - Request Construction

    @Test func anthropicRequestHasCorrectHeaders() async throws {
        let box = RequestBox()
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test-key", session: CapturingSession(box: box)
        )
        _ = await backend.respond(to: "hi", systemPrompt: "sys")
        let req = try #require(box.request)
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "sk-test-key")
        #expect(req.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.url?.host == "api.anthropic.com")
    }

    @Test func openAIRequestHasBearerToken() async throws {
        let box = RequestBox()
        let backend = RemoteLLMBackend(
            provider: .openai, modelID: "gpt-4o",
            apiKey: "sk-openai", session: CapturingSession(box: box)
        )
        _ = await backend.respond(to: "hi", systemPrompt: "sys")
        let req = try #require(box.request)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-openai")
        #expect(req.url?.host == "api.openai.com")
    }

    // MARK: - Missing API Key

    @Test func returnsEmptyWhenNoAPIKey() async {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: nil, session: MockHTTPSession(responseData: SSEFixture.textResponse)
        )
        let result = await backend.respond(to: "hi", systemPrompt: "sys")
        #expect(result.isEmpty)
    }

    // MARK: - Text Streaming Round Trip

    @Test func textResponseDelivered() async {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: SSEFixture.textResponse)
        )
        let result = await backend.respond(to: "hi", systemPrompt: "sys")
        #expect(result == "Hello world")
    }

    @Test func textStreamingDeliversTokensIncrementally() async {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: SSEFixture.textResponse)
        )
        var tokens: [String] = []
        _ = await backend.respondStreaming(to: "hi", systemPrompt: "sys") { token in
            tokens.append(token)
        }
        #expect(tokens == ["Hello", " world"])
    }

    // MARK: - Tool Call Round Trip

    @Test func toolCallSSEReturnsDriftJSON() async throws {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: SSEFixture.toolCallResponse)
        )
        let result = await backend.respond(to: "log 2 eggs", systemPrompt: "sys")
        #expect(!result.isEmpty, "tool_use SSE must produce non-empty output")

        // IntentClassifier must be able to parse the result as a tool call
        let intent = IntentClassifier.parseResponse(result)
        let parsed = try #require(intent)
        #expect(parsed.tool == "log_food")
        #expect(parsed.params["name"] == "eggs")
        #expect(parsed.params["servings"] == "2")
    }

    @Test func toolCallStreamingDeliversNoSpuriousTokens() async {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: SSEFixture.toolCallResponse)
        )
        var tokens: [String] = []
        _ = await backend.respondStreaming(to: "log 2 eggs", systemPrompt: "sys") { token in
            tokens.append(token)
        }
        // tool_use blocks deliver no text tokens — the result is returned as the final string
        #expect(tokens.isEmpty, "tool_use SSE must not deliver spurious text tokens")
    }

    @Test func toolCallResultParsedByIntentClassifierMapResponse() async {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSession(responseData: SSEFixture.toolCallResponse)
        )
        let result = await backend.respond(to: "log 2 eggs", systemPrompt: "sys")
        let classifyResult = IntentClassifier.mapResponse(result)
        guard case .toolCall(let intent) = classifyResult else {
            Issue.record("Expected toolCall, got \(String(describing: classifyResult))")
            return
        }
        #expect(intent.tool == "log_food")
        #expect(intent.params["name"] == "eggs")
    }

    // MARK: - HTTP Error Handling

    @Test func httpErrorReturnsEmpty() async {
        let backend = RemoteLLMBackend(
            provider: .anthropic, modelID: "claude-sonnet-4-6",
            apiKey: "sk-test", session: MockHTTPSessionError(statusCode: 429)
        )
        let result = await backend.respond(to: "hi", systemPrompt: "sys")
        #expect(result.isEmpty)
    }

    // MARK: - Preferences

    @Test func useRemoteModelOnWiFiRoundTrips() {
        let original = Preferences.useRemoteModelOnWiFi
        defer { Preferences.useRemoteModelOnWiFi = original }
        Preferences.useRemoteModelOnWiFi = true
        #expect(Preferences.useRemoteModelOnWiFi == true)
        Preferences.useRemoteModelOnWiFi = false
        #expect(Preferences.useRemoteModelOnWiFi == false)
    }
}
