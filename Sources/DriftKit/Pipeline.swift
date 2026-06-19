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
    /// `targetBundleID` is the app being dictated into, used to pick a formatting profile.
    public func stopStreamingAndProcess(targetBundleID: String? = nil) async throws -> String {
        recorder.onSamples = nil
        _ = recorder.stop()
        guard let streaming = transcriber as? StreamingTranscriber else { return "" }

        let raw = try await streaming.finishStream()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        return await clean(trimmed, targetBundleID: targetBundleID)
    }

    /// Stops recording, transcribes, and cleans using the currently selected
    /// provider. Returns "" if nothing usable was captured. Cleanup failures
    /// degrade gracefully: selected provider -> on-device cleanup -> raw text.
    public func stopAndProcess(targetBundleID: String? = nil) async throws -> String {
        let samples = recorder.stop()
        guard !samples.isEmpty else { return "" }

        let language = settings.effectiveLanguage
        let raw = try await transcriber.transcribe(samples: samples, language: language)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        return await clean(trimmed, targetBundleID: targetBundleID)
    }

    /// Cleans transcript text using the formatting profile for the destination app
    /// and the selected provider. Failures degrade gracefully: selected provider
    /// -> on-device cleanup -> raw text.
    private func clean(_ text: String, targetBundleID: String?) async -> String {
        let language = settings.effectiveLanguage
        let profile = FormattingProfiles.resolve(bundleID: targetBundleID, settings: settings)
        let prepared = applyCommandMode(to: text, language: language)

        // Code destinations are inserted verbatim — never reshaped, never sent to
        // a cloud provider.
        if profile.style == .code { return prepared }

        let cleaner = CleanupFactory.make(settings: settings, profile: profile)
        var result: String
        do {
            result = try await cleaner.clean(prepared, language: language)
        } catch {
            result = (try? await DeterministicCleanup().clean(prepared, language: language)) ?? prepared
        }

        if profile.style == .casual {
            result = FormattingProfiles.applyCasualTrim(result)
        }
        return result
    }

    /// Rewrites spoken commands ("new line", "comma"…) before cleanup when the
    /// feature is enabled. Skipped for Indic scripts since the commands are English.
    private func applyCommandMode(to text: String, language: Language) -> String {
        guard settings.commandModeEnabled else { return text }
        let isIndic = language.script == .indic
            || (language.isAuto && DeterministicCleanup.containsIndic(text))
        guard !isIndic else { return text }
        return CommandProcessor().process(text)
    }

    /// Discard an in-progress recording without processing it.
    public func cancel() {
        _ = recorder.stop()
    }
}
