import Foundation

// INTERIM ONLY. Sends recorded audio to the warm local whisper.cpp server via
// curl (avoids app-bundle ATS issues with local cleartext HTTP) and returns the
// transcript. Conforms to DriftKit's Transcriber, so pipeline/cleanup match main.
final class WhisperServerTranscriber: Transcriber {
    enum Err: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self { case .failed(let m): return "Transcription failed: \(m)" }
        }
    }

    let baseURL: String
    init(baseURL: String) { self.baseURL = baseURL }

    func transcribe(samples: [Float], language: Language) async throws -> String {
        let wav = try WavWriter.write(samples: samples, sampleRate: 16_000)
        defer { try? FileManager.default.removeItem(at: wav) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        p.arguments = [
            "-s", "-m", "60",
            "-F", "file=@\(wav.path)",
            "-F", "response_format=json",
            "-F", "language=\(language.whisperCode ?? "auto")",
            "\(baseURL)/inference",
        ]
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch { throw Err.failed(error.localizedDescription) }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard p.terminationStatus == 0 else {
            throw Err.failed(String(data: errData, encoding: .utf8) ?? "curl exit \(p.terminationStatus)")
        }
        if let obj = try? JSONSerialization.jsonObject(with: outData) as? [String: Any],
           let text = obj["text"] as? String {
            return Self.clean(text)
        }
        return Self.clean(String(data: outData, encoding: .utf8) ?? "")
    }

    private static func clean(_ raw: String) -> String {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { let l = $0.lowercased(); return !(l.isEmpty || l == "[blank_audio]" || l == "(silence)") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
