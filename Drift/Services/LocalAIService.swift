import Foundation
@preconcurrency import LLM

/// Manages local AI model download and inference.
@MainActor
@Observable
final class LocalAIService {
    static let shared = LocalAIService()

    enum ModelState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case error(String)
    }

    private(set) var state: ModelState = .notDownloaded
    nonisolated(unsafe) private var bot: LLM?

    // Model config
    private let modelFileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    private let modelURL = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
    private let systemPrompt = """
    You are Drift AI, a concise health assistant inside a fitness tracking app. \
    The user tracks weight, food, workouts, sleep, and vitals. \
    Be brief (1-3 sentences). Use the context provided to give personalized answers. \
    If asked to log food or start a workout, respond with the action in [brackets] like [LOG_FOOD: chicken breast 200g] or [START_WORKOUT: legs]. \
    Never make up health data — only reference what's provided in the context.
    """

    private var modelPath: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(modelFileName)
    }

    var isModelDownloaded: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    init() {
        if isModelDownloaded {
            state = .ready
        }
    }

    // MARK: - Download

    func downloadModel() async {
        guard !isModelDownloaded else { state = .ready; return }
        guard let url = URL(string: modelURL) else {
            state = .error("Invalid model URL")
            return
        }

        state = .downloading(progress: 0)

        do {
            // Use delegate-based download for progress tracking
            let delegate = DownloadDelegate { [weak self] progress in
                Task { @MainActor in
                    self?.state = .downloading(progress: progress)
                }
            }
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let (tempURL, _) = try await session.download(from: url)

            // Move to final location
            let dest = modelPath
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            state = .ready
            Log.app.info("AI model downloaded: \(self.modelFileName)")
        } catch {
            state = .error("Download failed: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: modelPath)
        }
    }

    // MARK: - Load Model

    func loadModel() {
        guard isModelDownloaded, bot == nil else { return }
        bot = LLM(from: modelPath, template: .chatML(systemPrompt), historyLimit: 6, maxTokenCount: 512)
        bot?.temp = 0.7
        bot?.topP = 0.9
    }

    // MARK: - Inference

    /// Generate a response with health context injected.
    func respond(to message: String, context: String = "") async -> String {
        guard let bot else { return "Model not loaded." }

        let prompt: String
        if context.isEmpty {
            prompt = message
        } else {
            prompt = "Context about the user:\n\(context)\n\nUser: \(message)"
        }

        let localBot = bot
        await localBot.respond(to: prompt)
        return localBot.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the bot's live output (for streaming UI updates).
    var output: String {
        bot?.output ?? ""
    }

    func stop() {
        bot?.stop()
    }

    func reset() {
        bot?.reset()
    }

    // MARK: - Delete Model

    func deleteModel() {
        bot = nil
        try? FileManager.default.removeItem(at: modelPath)
        state = .notDownloaded
    }
}

// MARK: - Download Progress Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by the async download(from:) caller
    }
}
