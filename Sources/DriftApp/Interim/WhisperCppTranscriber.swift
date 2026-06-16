import Foundation

// INTERIM ONLY (interim-whisper-cpp branch).
// A `Transcriber` that shells out to the whisper.cpp CLI. This exists so Drift
// can run on a machine with only Command Line Tools (no Xcode / no SwiftPM, so
// WhisperKit can't be built). The shipped product on `main` uses embedded
// WhisperKit instead. Conforms to the same DriftKit `Transcriber` protocol, so
// the pipeline, cleanup, and app logic are unchanged.
final class WhisperCppTranscriber: Transcriber {
    enum Err: LocalizedError {
        case binaryMissing
        case modelMissing(String)
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .binaryMissing: return "whisper.cpp not installed. Run scripts/dev-setup-clt.sh."
            case .modelMissing(let p): return "Model not found at \(p). Run scripts/dev-setup-clt.sh."
            case .failed(let m): return "Transcription failed: \(m)"
            }
        }
    }

    let binaryPath: String
    let modelPath: String

    init(binaryPath: String, modelPath: String) {
        self.binaryPath = binaryPath
        self.modelPath = modelPath
    }

    var isReady: Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath)
            && FileManager.default.fileExists(atPath: modelPath)
    }

    func transcribe(samples: [Float], language: Language) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { throw Err.binaryMissing }
        guard FileManager.default.fileExists(atPath: modelPath) else { throw Err.modelMissing(modelPath) }

        let wav = try writeWAV(samples: samples, sampleRate: 16_000)
        defer { try? FileManager.default.removeItem(at: wav) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-f", wav.path,
            "-l", language.whisperCode ?? "auto",
            "-nt", "-np",
        ]
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do { try process.run() } catch { throw Err.failed(error.localizedDescription) }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw Err.failed(String(data: errData, encoding: .utf8) ?? "exit \(process.terminationStatus)")
        }
        return Self.clean(String(data: outData, encoding: .utf8) ?? "")
    }

    private static func clean(_ raw: String) -> String {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                let l = line.lowercased()
                return !(l.isEmpty || l == "[blank_audio]" || l == "(silence)")
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeWAV(samples: [Float], sampleRate: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-\(UUID().uuidString).wav")
        var pcm = [Int16](); pcm.reserveCapacity(samples.count)
        for s in samples { pcm.append(Int16(max(-1, min(1, s)) * 32767)) }

        var data = Data()
        let dataSize = pcm.count * 2
        func le<T: FixedWidthInteger>(_ v: T) {
            var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
        }
        data.append("RIFF".data(using: .ascii)!); le(UInt32(36 + dataSize))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!); le(UInt32(16)); le(UInt16(1)); le(UInt16(1))
        le(UInt32(sampleRate)); le(UInt32(sampleRate * 2)); le(UInt16(2)); le(UInt16(16))
        data.append("data".data(using: .ascii)!); le(UInt32(dataSize))
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        try data.write(to: url)
        return url
    }
}
