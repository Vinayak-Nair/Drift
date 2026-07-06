import Foundation
import WhisperKit

/// `Transcriber` backed by an already-loaded WhisperKit pipeline. Created by
/// `ModelManager` once the model is present on disk.
public final class WhisperKitTranscriber: Transcriber {
    private let whisperKit: WhisperKit
    /// Read at transcribe time (not captured once) so vocabulary edits in
    /// Settings apply to the next dictation without reloading the model.
    private let vocabularyProvider: () -> [String]

    public init(whisperKit: WhisperKit, vocabularyProvider: @escaping () -> [String] = { [] }) {
        self.whisperKit = whisperKit
        self.vocabularyProvider = vocabularyProvider
    }

    public func transcribe(samples: [Float], language: Language) async throws -> String {
        // `language: nil` lets Whisper auto-detect (used for Language.auto).
        var options = DecodingOptions(
            task: .transcribe,
            language: language.whisperCode
        )
        options.promptTokens = biasPromptTokens()
        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results
            .map { $0.text }
            .joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Encodes the user's vocabulary as a conditioning prompt so the decoder is
    /// biased toward those spellings ("Karan Johar" instead of "current johar").
    /// Whisper treats prompt tokens as preceding transcript; the leading space
    /// and special-token filter mirror WhisperKit's own CLI prompt handling.
    private func biasPromptTokens() -> [Int]? {
        guard
            let prompt = Vocabulary.whisperPrompt(terms: vocabularyProvider()),
            let tokenizer = whisperKit.tokenizer
        else { return nil }
        let tokens = tokenizer
            .encode(text: " " + prompt)
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        return tokens.isEmpty ? nil : tokens
    }
}
