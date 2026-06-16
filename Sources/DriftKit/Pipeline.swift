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

    /// Length (seconds) of audio actually sent to the transcriber after silence
    /// trimming, for diagnostics.
    public private(set) var lastTrimmedSeconds: Double = 0

    /// Live mic level (0...1) forwarded from the recorder; set before recording.
    public var onLevel: ((Float) -> Void)? {
        get { recorder.onLevel }
        set { recorder.onLevel = newValue }
    }

    public func startRecording() throws {
        try recorder.start()
    }

    /// Stops recording, transcribes, and cleans using the currently selected
    /// provider. Returns "" if nothing usable was captured. Cleanup failures
    /// degrade gracefully: selected provider -> on-device cleanup -> raw text.
    public func stopAndProcess() async throws -> String {
        let samples = recorder.stop()
        guard !samples.isEmpty else { lastTrimmedSeconds = 0; return "" }

        let trimmedSamples = SilenceTrimmer.trim(samples)
        lastTrimmedSeconds = Double(trimmedSamples.count) / 16_000.0

        let language = settings.language
        let raw = try await transcriber.transcribe(samples: trimmedSamples, language: language)
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
