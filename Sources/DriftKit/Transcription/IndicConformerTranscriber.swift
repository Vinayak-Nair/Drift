import Foundation

public enum IndicConformerError: LocalizedError {
    case missingWorkerScript
    case workerLaunchFailed(String)
    case workerNotReady(String)
    case requestFailed(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingWorkerScript:
            return "AI4Bharat worker script is missing from the app bundle."
        case .workerLaunchFailed(let detail):
            return "Could not launch the AI4Bharat worker. \(detail)"
        case .workerNotReady(let logPath):
            return """
            AI4Bharat worker did not become ready. Install the Python dependencies, accept the gated Hugging Face model, then try again. Log: \(logPath)
            """
        case .requestFailed(let detail):
            return "AI4Bharat transcription failed. \(detail)"
        case .invalidResponse:
            return "AI4Bharat worker returned an invalid response."
        }
    }
}

/// Transcribes 16 kHz mono samples with AI4Bharat's Hugging Face
/// IndicConformer model by delegating model runtime to a local Python worker.
public final class IndicConformerTranscriber: Transcriber {
    private let worker: IndicConformerWorker
    private let settings: Settings

    public init(workerScriptURL: URL, workingDirectory: URL, settings: Settings = .shared) {
        self.settings = settings
        self.worker = IndicConformerWorker(
            workerScriptURL: workerScriptURL,
            workingDirectory: workingDirectory,
            settings: settings
        )
    }

    public func prepare() async throws {
        try await worker.prepare()
    }

    public func transcribe(samples: [Float], language: Language) async throws -> String {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-indic-\(UUID().uuidString).wav")
        try Self.writeWAV(samples: samples, to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        return try await worker.transcribe(
            audioURL: audioURL,
            languageCode: language.code,
            decoder: settings.indicConformerDecoder
        )
    }

    private static func writeWAV(samples: [Float], to url: URL) throws {
        var data = Data()
        let sampleRate: UInt32 = 16_000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = UInt16(bitsPerSample / 8)
        let blockAlign = channels * bytesPerSample
        let byteRate = sampleRate * UInt32(blockAlign)
        let pcmByteCount = UInt32(samples.count * Int(bytesPerSample))
        let chunkSize = UInt32(36) + pcmByteCount

        data.appendASCII("RIFF")
        data.appendLittleEndian(chunkSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channels)
        data.appendLittleEndian(sampleRate)
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.appendASCII("data")
        data.appendLittleEndian(pcmByteCount)

        for sample in samples {
            let clamped = min(1, max(-1, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            data.appendLittleEndian(intSample)
        }
        try data.write(to: url, options: .atomic)
    }
}

private actor IndicConformerWorker {
    private let workerScriptURL: URL
    private let workingDirectory: URL
    private let settings: Settings
    private let port: Int
    private let logURL: URL
    private var process: Process?
    private var logHandle: FileHandle?

    init(workerScriptURL: URL, workingDirectory: URL, settings: Settings) {
        self.workerScriptURL = workerScriptURL
        self.workingDirectory = workingDirectory
        self.settings = settings
        self.port = Int.random(in: 52_000...59_999)
        self.logURL = workingDirectory.appendingPathComponent("worker.log")
    }

    deinit {
        process?.terminate()
        try? logHandle?.close()
    }

    func prepare() async throws {
        try await ensureStarted()
    }

    func transcribe(audioURL: URL, languageCode: String, decoder: String) async throws -> String {
        try await ensureStarted()

        var request = URLRequest(url: endpoint("/transcribe"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONEncoder().encode(TranscriptionRequest(
            audioPath: audioURL.path,
            language: languageCode,
            decoder: decoder
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw IndicConformerError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        guard (200..<300).contains(http.statusCode), let text = decoded.text else {
            throw IndicConformerError.requestFailed(decoded.error ?? "HTTP \(http.statusCode)")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureStarted() async throws {
        if await isHealthy() { return }
        if process?.isRunning != true {
            try startProcess()
        }

        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline {
            if await isHealthy() { return }
            if let process, !process.isRunning {
                throw IndicConformerError.workerNotReady(logURL.path)
            }
            try? await Task.sleep(for: .milliseconds(600))
        }
        throw IndicConformerError.workerNotReady(logURL.path)
    }

    private func startProcess() throws {
        try FileManager.default.createDirectory(
            at: workingDirectory, withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        logHandle = try FileHandle(forWritingTo: logURL)
        try logHandle?.seekToEnd()

        let python = settings.indicConformerPythonPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !python.isEmpty else {
            throw IndicConformerError.workerLaunchFailed("Set a Python executable path in Settings.")
        }

        let process = Process()
        if python.contains("/") {
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = workerArguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [python] + workerArguments
        }
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = logHandle
        process.standardError = logHandle

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw IndicConformerError.workerLaunchFailed(error.localizedDescription)
        }
        self.process = process
    }

    private var workerArguments: [String] {
        [
            workerScriptURL.path,
            "--host", "127.0.0.1",
            "--port", "\(port)",
            "--model-id", settings.indicConformerModelID,
            "--cache-dir", workingDirectory.appendingPathComponent("hf-cache").path
        ]
    }

    private func isHealthy() async -> Bool {
        var request = URLRequest(url: endpoint("/health"))
        request.timeoutInterval = 1
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    private func endpoint(_ path: String) -> URL {
        URL(string: "http://127.0.0.1:\(port)\(path)")!
    }
}

private struct TranscriptionRequest: Encodable {
    let audioPath: String
    let language: String
    let decoder: String
}

private struct TranscriptionResponse: Decodable {
    let text: String?
    let error: String?
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
