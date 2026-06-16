import Foundation

/// Turns recorded audio samples into text. Abstracts the STT engine so the rest
/// of Drift never depends on WhisperKit directly (swappable, testable).
public protocol Transcriber: AnyObject {
    /// Transcribe 16 kHz mono Float samples in the given language.
    func transcribe(samples: [Float], language: Language) async throws -> String
}
