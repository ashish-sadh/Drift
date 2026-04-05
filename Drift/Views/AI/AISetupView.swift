import SwiftUI

/// Entry point for the AI feature — handles model download + shows chat when ready.
struct AIView: View {
    @State private var aiService = LocalAIService.shared

    var body: some View {
        NavigationStack {
            Group {
                switch aiService.state {
                case .notDownloaded:
                    downloadPrompt
                case .downloading(let progress):
                    downloadingView(progress: progress)
                case .ready:
                    AIChatView()
                case .error(let msg):
                    errorView(message: msg)
                }
            }
            .background(Theme.background.ignoresSafeArea())
        }
    }

    // MARK: - Download Prompt

    private var downloadPrompt: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent.opacity(0.6))

            Text("Drift AI")
                .font(.title2.weight(.bold))

            Text("Chat with an AI health assistant that understands your data. Runs entirely on your device — nothing leaves your phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 4) {
                Text("Requires a one-time download")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("~470 MB")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await aiService.downloadModel() }
            } label: {
                Label("Download AI Model", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Theme.deficit)
                        .font(.caption)
                    Text("100% on-device")
                        .font(.caption.weight(.medium))
                }
                Text("The AI model runs locally on your iPhone. Your health data never leaves your device.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Downloading

    private func downloadingView(progress: Double) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent.opacity(0.6))

            Text("Downloading AI Model")
                .font(.title3.weight(.semibold))

            ProgressView(value: progress)
                .tint(Theme.accent)
                .padding(.horizontal, 60)

            Text("\(Int(progress * 100))%")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)

            Text("This only happens once. The model will be stored on your device for offline use.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Theme.surplus.opacity(0.6))

            Text("Download Failed")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await aiService.downloadModel() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }
}
