import SwiftUI

struct AIChatView: View {
    @State private var aiService = LocalAIService.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false
    @FocusState private var inputFocused: Bool

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        var text: String
        let timestamp = Date()

        enum Role { case user, assistant, system }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if isGenerating {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.7)
                                Text("Thinking...").font(.caption).foregroundStyle(.tertiary)
                            }
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }


            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                TextField("Ask about your health...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .onSubmit { sendMessage() }

                if isGenerating {
                    Button { aiService.stop() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.surplus)
                    }
                } else {
                    Button { sendMessage() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(inputText.isEmpty ? Color.gray : Theme.accent)
                    }
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.cardBackground)
        }
        .background(Theme.background)
        .navigationTitle("Drift AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if messages.isEmpty {
                messages.append(ChatMessage(role: .system, text: "I'm your health assistant. Ask me about your nutrition, weight, workouts, or say \"log food\" / \"start workout\" and I'll help."))
            }
            if aiService.state == .ready && !aiService.isModelDownloaded {
                // Model was deleted
            } else if aiService.state == .ready {
                aiService.loadModel()
            }
        }
    }

    // MARK: - Send Message

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        messages.append(ChatMessage(role: .user, text: text))
        inputText = ""
        isGenerating = true

        Task {
            let context = AIContextBuilder.buildContext()

            var response = await aiService.respond(to: text, context: context)
            if response.isEmpty { response = "I couldn't generate a response. Try again." }

            messages.append(ChatMessage(role: .assistant, text: response))
            isGenerating = false
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            switch message.role {
            case .user:
                Spacer()
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.primary)

            case .assistant:
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()

            case .system:
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Theme.accent.opacity(0.6))
                    Text(message.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
    }
}
