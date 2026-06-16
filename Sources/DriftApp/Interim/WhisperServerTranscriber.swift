import Foundation

// INTERIM ONLY. Sends recorded audio to the warm local whisper.cpp server and
// returns the transcript. Conforms to DriftKit's Transcriber, so the pipeline,
// cleanup, and app are identical to the WhisperKit path on main.
final class WhisperServerTranscriber: Transcriber {
    enum Err: LocalizedError {
        case http(Int, String)
        case bad(String)
        var errorDescription: String? {
            switch self {
            case .http(let c, let m): return "Server HTTP \(c): \(m)"
            case .bad(let m): return m
            }
        }
    }

    let baseURL: URL
    init(baseURL: URL) { self.baseURL = baseURL }

    func transcribe(samples: [Float], language: Language) async throws -> String {
        let wav = try WavWriter.write(samples: samples, sampleRate: 16_000)
        defer { try? FileManager.default.removeItem(at: wav) }
        let audio = try Data(contentsOf: wav)

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: baseURL.appendingPathComponent("inference"), timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func boundaryLine() { body.append("--\(boundary)\r\n".data(using: .utf8)!) }
        func field(_ name: String, _ value: String) {
            boundaryLine()
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        boundaryLine()
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audio)
        body.append("\r\n".data(using: .utf8)!)
        field("response_format", "json")
        field("language", language.whisperCode ?? "auto")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Err.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = obj["text"] as? String {
            return Self.clean(text)
        }
        return Self.clean(String(data: data, encoding: .utf8) ?? "")
    }

    private static func clean(_ raw: String) -> String {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { let l = $0.lowercased(); return !(l.isEmpty || l == "[blank_audio]" || l == "(silence)") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
