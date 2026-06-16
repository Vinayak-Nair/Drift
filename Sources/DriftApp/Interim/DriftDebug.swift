import Foundation

/// Persistent, thread-safe diagnostic log at ~/.drift/drift.log. One line per
/// event (dictation summaries, warnings, errors). Auto-rotates at ~512 KB so it
/// never grows unbounded. Point Claude at this file when reporting an issue.
enum DriftLog {
    static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".drift")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("drift.log")
    }()

    private static let queue = DispatchQueue(label: "com.drift.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func log(_ message: String) {
        queue.async {
            rotateIfNeeded()
            let line = "\(formatter.string(from: Date()))  \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    private static func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int, size > 512_000 else { return }
        let archived = fileURL.deletingLastPathComponent().appendingPathComponent("drift.old.log")
        try? FileManager.default.removeItem(at: archived)
        try? FileManager.default.moveItem(at: fileURL, to: archived)
    }
}

func driftLog(_ message: String) { DriftLog.log(message) }
