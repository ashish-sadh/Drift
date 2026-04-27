import Foundation

// MARK: - HTTP Session Protocol (injectable for testing)

/// Minimal URLSession interface needed by RemoteLLMBackend. URLSession conforms
/// automatically via extension below — tests can supply a mock.
public protocol HTTPDataSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataSession {}

// MARK: - Remote LLM Backend

/// AIBackend backed by Anthropic or OpenAI via HTTP. Privacy-surfaced: any call
/// from this backend exits the device. API key is injected by the caller — the
/// iOS app reads it from Keychain; DriftCore itself does not touch Keychain.
public final class RemoteLLMBackend: AIBackend, @unchecked Sendable {

    // MARK: - Provider

    public enum Provider: String, Sendable {
        case anthropic
        case openai
    }

    // MARK: - Errors

    enum BackendError: Error {
        case invalidURL
    }

    // MARK: - Properties

    public let provider: Provider
    public let modelID: String
    private let apiKey: String?
    let session: any HTTPDataSession

    public var isLoaded: Bool { apiKey != nil }
    public var supportsVision: Bool { false }

    // MARK: - Init

    public init(
        provider: Provider,
        modelID: String,
        apiKey: String?,
        session: any HTTPDataSession = URLSession.shared
    ) {
        self.provider = provider
        self.modelID = modelID
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - AIBackend

    public func load() async throws {}
    public func unload() {}

    public func respond(to prompt: String, systemPrompt: String) async -> String {
        await respondStreaming(to: prompt, systemPrompt: systemPrompt, onToken: { _ in })
    }

    public func respondStreaming(
        to prompt: String,
        systemPrompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async -> String {
        guard let key = apiKey else { return "" }
        do {
            let request = try buildRequest(prompt: prompt, systemPrompt: systemPrompt, apiKey: key)
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                Log.app.error("RemoteLLMBackend: HTTP \(http.statusCode)")
                return ""
            }
            return AnthropicSSEParser.parse(data: data, onToken: onToken)
        } catch {
            Log.app.error("RemoteLLMBackend: \(error)")
            return ""
        }
    }

    // MARK: - Request Building

    private func buildRequest(prompt: String, systemPrompt: String, apiKey: String) throws -> URLRequest {
        switch provider {
        case .anthropic: return try buildAnthropicRequest(prompt: prompt, systemPrompt: systemPrompt, apiKey: apiKey)
        case .openai: return try buildOpenAIRequest(prompt: prompt, systemPrompt: systemPrompt, apiKey: apiKey)
        }
    }

    private func buildAnthropicRequest(prompt: String, systemPrompt: String, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw BackendError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": 256,
            "stream": true,
            "system": systemPrompt,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func buildOpenAIRequest(prompt: String, systemPrompt: String, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw BackendError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": 256,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }
}

// MARK: - Anthropic SSE Parser

/// Parses Anthropic streaming SSE bytes into a unified string result.
///
/// Two response modes:
/// - text:     concatenated text_delta tokens, delivered to onToken as they arrive.
/// - tool_use: input JSON accumulated from input_json_delta events, then
///             merged with the tool name into Drift's {"tool":"...","key":"val"}
///             format so IntentClassifier.parseResponse can consume it directly.
enum AnthropicSSEParser {

    struct Block {
        var type: String = ""       // "text" or "tool_use"
        var toolName: String = ""
        var textBuffer: String = ""
        var toolInputBuffer: String = ""
    }

    static func parse(data: Data, onToken: @escaping @Sendable (String) -> Void) -> String {
        guard let raw = String(data: data, encoding: .utf8) else { return "" }

        var blocks: [Int: Block] = [:]   // keyed by content_block index

        for line in raw.components(separatedBy: "\n") {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            guard jsonStr != "[DONE]",
                  let jData = jsonStr.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jData) as? [String: Any]
            else { continue }

            switch event["type"] as? String ?? "" {

            case "content_block_start":
                let index = event["index"] as? Int ?? 0
                if let cb = event["content_block"] as? [String: Any] {
                    var block = Block()
                    block.type = cb["type"] as? String ?? ""
                    block.toolName = cb["name"] as? String ?? ""
                    blocks[index] = block
                }

            case "content_block_delta":
                let index = event["index"] as? Int ?? 0
                guard let delta = event["delta"] as? [String: Any] else { continue }
                let deltaType = delta["type"] as? String ?? ""

                if deltaType == "text_delta", let text = delta["text"] as? String {
                    onToken(text)
                    blocks[index, default: Block()].textBuffer += text
                } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                    blocks[index, default: Block()].toolInputBuffer += partial
                }

            default:
                break
            }
        }

        // Prefer first tool_use block (by SSE index); fall back to concatenated text in index order.
        if let toolEntry = blocks.filter({ $0.value.type == "tool_use" }).min(by: { $0.key < $1.key }) {
            return formatToolCall(name: toolEntry.value.toolName, inputJSON: toolEntry.value.toolInputBuffer)
        }

        return blocks.sorted(by: { $0.key < $1.key })
            .filter { $0.value.type == "text" }
            .map { $0.value.textBuffer }
            .joined()
    }

    /// Merge Anthropic tool_use input JSON with the tool name into Drift's flat
    /// {"tool":"log_food","name":"eggs"} format that IntentClassifier expects.
    private static func formatToolCall(name: String, inputJSON: String) -> String {
        guard !name.isEmpty,
              let inputData = inputJSON.data(using: .utf8),
              var params = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any]
        else {
            return inputJSON.isEmpty ? "" : "{\"tool\":\"\(name)\"}"
        }
        params["tool"] = name
        guard let merged = try? JSONSerialization.data(withJSONObject: params, options: .sortedKeys),
              let str = String(data: merged, encoding: .utf8)
        else { return "{\"tool\":\"\(name)\"}" }
        return str
    }
}
