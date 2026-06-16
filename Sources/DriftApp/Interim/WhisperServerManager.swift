import Foundation

// INTERIM ONLY. Spawns and supervises a local whisper.cpp server so the model
// stays loaded in memory between dictations (no per-call reload, the big latency
// win). The app starts this on launch and stops it on quit.
final class WhisperServerManager {
    static let port = 8910
    static var baseURL: URL { URL(string: "http://127.0.0.1:\(port)")! }

    let binaryPath: String
    let modelPath: String
    private var process: Process?

    init(binaryPath: String, modelPath: String) {
        self.binaryPath = binaryPath
        self.modelPath = modelPath
    }

    var binaryExists: Bool { FileManager.default.isExecutableFile(atPath: binaryPath) }
    var modelExists: Bool { FileManager.default.fileExists(atPath: modelPath) }
    var isReadyToStart: Bool { binaryExists && modelExists }

    func start() {
        guard process == nil, isReadyToStart else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binaryPath)
        p.arguments = [
            "-m", modelPath,
            "-l", "auto",            // per-request language overrides this
            "-nt",
            "--host", "127.0.0.1",
            "--port", "\(Self.port)",
        ]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); process = p } catch { NSLog("Drift: whisper-server failed to start: \(error)") }
    }

    /// Polls until the server answers or the timeout elapses.
    func waitUntilReady(timeout: TimeInterval = 60) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await ping() { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    private func ping() async -> Bool {
        var req = URLRequest(url: Self.baseURL, timeoutInterval: 2)
        req.httpMethod = "GET"
        do { _ = try await URLSession.shared.data(for: req); return true }
        catch { return false }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
