import Foundation

// INTERIM ONLY. Spawns and supervises a local whisper.cpp server so the model
// stays loaded in memory between dictations (no per-call reload). Readiness is
// probed with curl rather than URLSession to avoid any app-bundle networking
// (App Transport Security) issues talking to a local cleartext HTTP server.
final class WhisperServerManager {
    static let port = 8910
    static var baseURL: String { "http://127.0.0.1:\(port)" }

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

    /// Polls (via curl) until the server answers or the timeout elapses.
    func waitUntilReady(timeout: TimeInterval = 90) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if ping() { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    private func ping() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        p.arguments = ["-s", "-o", "/dev/null", "-m", "2", "\(Self.baseURL)/"]
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
