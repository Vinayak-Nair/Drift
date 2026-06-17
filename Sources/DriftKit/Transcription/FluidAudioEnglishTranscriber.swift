import Foundation
import FluidAudio

/// FluidAudio backend using Parakeet TDT v3. Drift records full
/// push-to-talk utterances, so each transcription gets a fresh decoder state.
public final class FluidAudioEnglishTranscriber: Transcriber {
    private let asrManager: AsrManager

    public init(asrManager: AsrManager) {
        self.asrManager = asrManager
    }

    public func transcribe(samples: [Float], language _: Language) async throws -> String {
        let decoderLayers = await asrManager.decoderLayerCount
        var decoderState = try TdtDecoderState(decoderLayers: decoderLayers)
        let result = try await asrManager.transcribe(samples, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
