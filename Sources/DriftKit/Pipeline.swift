import Foundation

/// Orchestrates one dictation: record -> transcribe -> clean. UI-agnostic, so the
/// app layer only deals with start/stop and the final string (and pasting it).
public final class Pipeline {
    private let recorder: Recorder
    private let transcriber: Transcriber
    private let settings: Settings

    public init(transcriber: Transcriber, settings: Settings = .shared) {
        self.transcriber = transcriber
        self.settings = settings
        self.recorder = Recorder(settings: settings)
    }

    public var isRecording: Bool { recorder.isRecording }

    /// Whether the active engine supports live partial transcription.
    public var supportsStreaming: Bool { transcriber is StreamingTranscriber }

    public func startRecording() throws {
        try recorder.start()
    }

    // MARK: Streaming (live partials)

    /// Starts recording and streams audio into the transcriber, calling `onPartial`
    /// with the growing transcript as it decodes. Falls back to a plain recording
    /// if the engine isn't streaming-capable.
    public func startStreaming(onPartial: @escaping @Sendable (String) -> Void) async throws {
        guard let streaming = transcriber as? StreamingTranscriber else {
            try recorder.start()
            return
        }
        await streaming.beginStream(onPartial: onPartial)
        recorder.onSamples = { samples in streaming.feed(samples) }
        do {
            try recorder.start()
        } catch {
            recorder.onSamples = nil
            _ = try? await streaming.finishStream()
            throw error
        }
    }

    /// Stops a streaming session, finishes decoding, and returns the cleaned text.
    public func stopStreamingAndProcess() async throws -> String {
        recorder.onSamples = nil
        _ = recorder.stop()
        guard let streaming = transcriber as? StreamingTranscriber else { return "" }

        let raw = try await streaming.finishStream()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        return await clean(trimmed)
    }

    /// Stops recording, transcribes, and cleans using the currently selected
    /// provider. Returns "" if nothing usable was captured. Cleanup failures
    /// degrade gracefully: selected provider -> on-device cleanup -> raw text.
    public func stopAndProcess() async throws -> String {
        let samples = recorder.stop()
        guard !samples.isEmpty else { return "" }

        let language = settings.effectiveLanguage
        let raw = try await transcriber.transcribe(samples: samples, language: language)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        return await clean(trimmed)
    }

    /// Cleans transcript text with the selected provider. Failures degrade
    /// gracefully: selected provider -> on-device cleanup -> raw text.
    private func clean(_ text: String) async -> String {
        let language = settings.effectiveLanguage
        let cleaner = CleanupFactory.make(settings: settings)
        do {
            return try await cleaner.clean(text, language: language)
        } catch {
            return (try? await DeterministicCleanup().clean(text, language: language)) ?? text
        }
    }

    /// Discard an in-progress recording without processing it.
    public func cancel() {
        _ = recorder.stop()
    }
}
