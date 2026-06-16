import Foundation

// INTERIM capture diagnostics. Appends dictation lifecycle events to a file so
// "erratic capture" can be diagnosed from real attempts. Remove once stable.
func driftLog(_ s: String) {
    let line = "\(Date()) \(s)\n"
    let url = URL(fileURLWithPath: "/tmp/drift-capture.log")
    guard let data = line.data(using: .utf8) else { return }
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile(); h.write(data); try? h.close()
    } else {
        try? data.write(to: url)
    }
}
