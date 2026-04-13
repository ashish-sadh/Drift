import Foundation
import Speech
import AVFoundation

/// On-device speech recognition for AI chat. Privacy-first: on-device only.
///
/// Approach: partial results accumulate the full transcript. We never rely on
/// isFinal for text — only to know when to restart the recognizer. The last
/// partial result always has the complete text.
@Observable
final class SpeechRecognitionService: @unchecked Sendable {
    static let shared = SpeechRecognitionService()

    enum RecordingState: Equatable, Sendable {
        case idle, recording
        case unavailable(String)
    }

    @MainActor private(set) var recordingState: RecordingState = .idle
    @MainActor private(set) var transcript = ""

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioQueue = DispatchQueue(label: "com.drift.speech", qos: .userInitiated)
    private var silenceTimer: DispatchWorkItem?
    private var onDoneCallback: (@MainActor (String) -> Void)?
    private var lastPartialText = ""  // Always the most recent text from partials

    private static let silenceTimeout: TimeInterval = 8.0

    private init() {}

    @MainActor var isRecording: Bool { recordingState == .recording }
    @MainActor var isAvailable: Bool { speechRecognizer?.isAvailable ?? false }

    @MainActor
    func toggleRecording(
        onTranscript: @escaping @MainActor (String) -> Void,
        onDone: @escaping @MainActor (String) -> Void
    ) {
        if isRecording { gracefulStop() }
        else { startRecording(onTranscript: onTranscript, onDone: onDone) }
    }

    @MainActor
    func startRecording(
        onTranscript: @escaping @MainActor (String) -> Void,
        onDone: @escaping @MainActor (String) -> Void
    ) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            recordingState = .unavailable("Speech recognition not available")
            return
        }
        onDoneCallback = onDone
        lastPartialText = ""
        recordingState = .recording
        transcript = ""
        setupEngine(recognizer: recognizer, onTranscript: onTranscript)
    }

    /// Stop and send — uses lastPartialText (always complete).
    @MainActor
    func gracefulStop() {
        silenceTimer?.cancel(); silenceTimer = nil
        let text = lastPartialText
        cleanup()
        recordingState = .idle
        let cb = onDoneCallback; onDoneCallback = nil
        if !text.trimmingCharacters(in: .whitespaces).isEmpty { cb?(text) }
    }

    /// Stop for editing — keeps text in field, doesn't send.
    @MainActor
    func forceStop() {
        silenceTimer?.cancel(); silenceTimer = nil
        onDoneCallback = nil
        cleanup()
        recordingState = .idle
        // transcript and inputText keep their values
    }

    @MainActor
    private func finishFromSilence(text: String) {
        silenceTimer?.cancel(); silenceTimer = nil
        cleanup()
        recordingState = .idle
        let cb = onDoneCallback; onDoneCallback = nil
        if !text.trimmingCharacters(in: .whitespaces).isEmpty { cb?(text) }
    }

    private func cleanup() {
        let engine = audioEngine
        let req = currentRequest
        let task = recognitionTask
        audioEngine = nil; currentRequest = nil; recognitionTask = nil
        audioQueue.async {
            engine?.stop()
            engine?.inputNode.removeTap(onBus: 0)
            req?.endAudio()
            task?.cancel()
        }
    }

    // MARK: - Engine Setup

    private func setupEngine(
        recognizer: SFSpeechRecognizer,
        onTranscript: @escaping @MainActor (String) -> Void
    ) {
        let supportsOnDevice = recognizer.supportsOnDeviceRecognition

        audioQueue.async { [weak self] in
            guard let self else { return }

            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                DispatchQueue.main.async { self.recordingState = .unavailable("Microphone unavailable") }
                return
            }

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                DispatchQueue.main.async { self.recordingState = .unavailable("Microphone unavailable") }
                return
            }

            // Audio tap writes to currentRequest — survives request swaps
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.currentRequest?.append(buffer)
            }
            engine.prepare()

            do { try engine.start() } catch {
                inputNode.removeTap(onBus: 0)
                DispatchQueue.main.async { self.recordingState = .unavailable("Could not start audio engine") }
                return
            }

            nonisolated(unsafe) let e = engine
            nonisolated(unsafe) let r = recognizer
            DispatchQueue.main.async {
                self.audioEngine = e
                self.startSegment(recognizer: r, supportsOnDevice: supportsOnDevice, onTranscript: onTranscript)
            }
        }
    }

    // MARK: - Recognition Segment

    @MainActor
    private func startSegment(
        recognizer: SFSpeechRecognizer,
        supportsOnDevice: Bool,
        onTranscript: @escaping @MainActor (String) -> Void
    ) {
        guard recordingState == .recording else { return }

        let prefix = lastPartialText  // Text accumulated from previous segments

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if supportsOnDevice { request.requiresOnDeviceRecognition = true }
        currentRequest = request

        nonisolated(unsafe) let unsafeRec = recognizer
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.recordingState == .recording else { return }

                if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                    // Combine with previous segments
                    let full = prefix.isEmpty ? text : prefix + " " + text
                    self.lastPartialText = full
                    self.transcript = full
                    onTranscript(full)

                    // Reset silence timer
                    self.silenceTimer?.cancel()
                    let captured = full
                    let timer = DispatchWorkItem { [weak self] in
                        self?.finishFromSilence(text: captured)
                    }
                    self.silenceTimer = timer
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.silenceTimeout, execute: timer)
                }

                let isFinal = result?.isFinal ?? false
                if isFinal {
                    // Apple ended this segment (pause detected).
                    // Don't touch lastPartialText — it already has the full text.
                    // Just start a new segment to keep listening.
                    self.startSegment(recognizer: unsafeRec, supportsOnDevice: supportsOnDevice, onTranscript: onTranscript)
                } else if error != nil {
                    let desc = error?.localizedDescription ?? ""
                    if desc.contains("203") || desc.contains("no speech") {
                        // No speech — just restart
                        self.startSegment(recognizer: unsafeRec, supportsOnDevice: supportsOnDevice, onTranscript: onTranscript)
                    }
                    // Other errors: just keep going, silence timer will finish
                }
            }
        }
    }
}
