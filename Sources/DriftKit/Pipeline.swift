import Foundation

/// Orchestrates one dictation: record -> transcribe -> clean. UI-agnostic, so the
/// app layer only deals with start/stop and the final string (and pasting it).
public final class Pipeline {
    private let recorder = Recorder()
    private let transcriber: Transcriber
    private let settings: Settings

    public init(transcriber: Transcriber, settings: Settings = .shared) {
        self.transcriber = transcriber
        self.settings = settings
    }

    public var isRecording: Bool { recorder.isRecording }

    public func startRecording() throws {
        try recorder.start()
    }

    /// Stops recording, transcribes, and cleans using the currently selected
    /// provider. Returns "" if nothing usable was captured. Cleanup failures
    /// degrade gracefully: selected provider -> on-device cleanup -> raw text.
    public func stopAndProcess() async throws -> String {
        let samples = recorder.stop()
        guard !samples.isEmpty else { return "" }

        let language = settings.language
        let raw = try await transcriber.transcribe(samples: samples, language: language)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let cleaner = CleanupFactory.make(settings: settings)
        do {
            return try await cleaner.clean(trimmed, language: language)
        } catch {
            return (try? await DeterministicCleanup().clean(trimmed, language: language)) ?? trimmed
        }
    }

    /// Discard an in-progress recording without processing it.
    public func cancel() {
        _ = recorder.stop()
    }
}
