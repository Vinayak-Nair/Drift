import Foundation
import WhisperKit

/// `Transcriber` backed by an already-loaded WhisperKit pipeline. Created by
/// `ModelManager` once the model is present on disk.
public final class WhisperKitTranscriber: Transcriber {
    private let whisperKit: WhisperKit

    public init(whisperKit: WhisperKit) {
        self.whisperKit = whisperKit
    }

    public func transcribe(samples: [Float], language: Language) async throws -> String {
        // `language: nil` lets Whisper auto-detect (used for Language.auto).
        let options = DecodingOptions(
            task: .transcribe,
            language: language.whisperCode
        )
        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results
            .map { $0.text }
            .joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
