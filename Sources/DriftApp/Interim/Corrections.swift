import Foundation

/// User-taught corrections ("heard" -> "meant"), learned from explicit fixes and
/// applied to every future transcription. Stored at ~/.drift/dictionary.json,
/// which is human-editable (remove or tweak entries by hand any time).
final class Corrections {
    static let shared = Corrections()

    struct Rule: Codable { var from: String; var to: String }

    let fileURL: URL
    private var rules: [Rule] = []
    private let lock = NSLock()

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".drift")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("dictionary.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Rule].self, from: data) else { return }
        lock.lock(); rules = decoded; lock.unlock()
    }

    private func save() {
        lock.lock(); let snapshot = rules; lock.unlock()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(snapshot) { try? data.write(to: fileURL) }
    }

    /// Apply learned corrections to a transcription (whole-word/phrase boundary,
    /// case-insensitive).
    func apply(to text: String) -> String {
        lock.lock(); let snapshot = rules; lock.unlock()
        var result = text
        for rule in snapshot where !rule.from.isEmpty {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: rule.from) + "\\b"
            result = result.replacingOccurrences(
                of: pattern, with: rule.to,
                options: [.regularExpression, .caseInsensitive])
        }
        return result
    }

    /// Learn the difference between what Drift produced and what the user meant.
    /// Same word count -> learn each changed word; otherwise learn the phrase.
    /// Returns the newly added rules.
    @discardableResult
    func learn(original: String, corrected: String) -> [Rule] {
        let o = original.split(separator: " ").map(String.init)
        let c = corrected.split(separator: " ").map(String.init)
        var candidates: [Rule] = []

        if o.count == c.count {
            for i in 0..<o.count where normalize(o[i]) != normalize(c[i]) {
                candidates.append(Rule(from: o[i], to: c[i]))
            }
        } else {
            let from = original.trimmingCharacters(in: .whitespacesAndNewlines)
            let to = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
            if !from.isEmpty, normalize(from) != normalize(to) {
                candidates.append(Rule(from: from, to: to))
            }
        }

        lock.lock()
        var added: [Rule] = []
        for rule in candidates where !rules.contains(where: { $0.from.caseInsensitiveCompare(rule.from) == .orderedSame }) {
            rules.append(rule)
            added.append(rule)
        }
        lock.unlock()
        if !added.isEmpty { save() }
        return added
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .punctuationCharacters).lowercased()
    }
}
