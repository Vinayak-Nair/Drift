import Foundation

/// Learns dictionary terms from the user's own corrections: Drift pastes a
/// transcript, the user fixes a misheard name in place, and the fix becomes a
/// vocabulary entry so the next dictation gets it right.
///
/// The caller supplies the pasted transcript plus before/after snapshots of the
/// destination text field. Only replacements *inside the pasted region of the
/// field* are considered — edits the user makes to their own text elsewhere in
/// the same field are ignored, even when they reuse words the dictation also
/// contained. A replacement is learned when it plausibly sounds like what it
/// replaced ("hat" -> "hair", "current johar" -> "Karan Johar"), so content
/// rewrites ("noon" -> "night") don't pollute the dictionary.
public enum DictionaryLearner {
    /// Fields larger than this are skipped: diffing huge documents is wasteful
    /// and corrections in them are ambiguous anyway.
    private static let maxTokens = 1200
    private static let maxTermWords = 4
    private static let minTermLetters = 3
    /// Looser than `VocabularyCorrector`'s matching thresholds on purpose: the
    /// user just demonstrated the correction, so a badly mangled capture
    /// ("I should have a run" -> "Aishwarya Rai") should still be learned.
    private static let phoneticTolerance = 0.75
    private static let spellingTolerance = 0.5

    public static func newTerms(pasted: String, before: String, after: String, vocabulary: [String]) -> [String] {
        guard before != after, !pasted.isEmpty else { return [] }
        let beforeTokens = tokens(before)
        let afterTokens = tokens(after)
        guard beforeTokens.count <= maxTokens, afterTokens.count <= maxTokens else { return [] }
        let pastedTokens = tokens(pasted)

        // Where in the field the dictation actually sits. An edit only counts
        // as a correction when it lands inside one of these regions.
        let regions = occurrences(of: pastedTokens, in: beforeTokens)
        guard !regions.isEmpty else { return [] }

        var known = Set(vocabulary.map { $0.lowercased() })
        var learned: [String] = []
        for hunk in replaceHunks(beforeTokens, afterTokens) {
            // ArraySlice keeps the parent array's indices, so the hunk's span
            // in the field is just its own index range.
            let span = hunk.old.startIndex..<hunk.old.endIndex
            guard regions.contains(where: { $0.lowerBound <= span.lowerBound && span.upperBound <= $0.upperBound }) else { continue }
            guard let term = candidateTerm(from: hunk.new) else { continue }
            guard !known.contains(term.lowercased()) else { continue }
            guard isPlausibleCorrection(of: hunk.old, to: term) else { continue }
            known.insert(term.lowercased())
            learned.append(term)
        }
        return learned
    }

    // MARK: Candidate filtering

    /// The corrected span as a dictionary term, or nil when it doesn't look
    /// like one (too long or too short).
    private static func candidateTerm(from span: ArraySlice<String>) -> String? {
        guard (1...maxTermWords).contains(span.count) else { return nil }
        let cores = span.map(trimEdgePunctuation)
        guard cores.allSatisfy({ !$0.isEmpty }) else { return nil }
        let term = cores.joined(separator: " ")
        guard VocabularyCorrector.lettersOnly(term).count >= minTermLetters else { return nil }
        return term
    }

    /// Whether replacing `old` with `term` reads as fixing a mishear rather
    /// than rewriting content. Pure casing fixes always qualify.
    private static func isPlausibleCorrection(of old: ArraySlice<String>, to term: String) -> Bool {
        let oldLetters = VocabularyCorrector.lettersOnly(old.joined(separator: " "))
        let termLetters = VocabularyCorrector.lettersOnly(term)
        guard !oldLetters.isEmpty else { return false }
        if oldLetters == termLetters { return true }

        let spellingDistance = VocabularyCorrector.editDistance(oldLetters, termLetters)
        let spelling = Double(spellingDistance) / Double(max(oldLetters.count, termLetters.count))
        if spelling <= spellingTolerance { return true }

        let oldKey = VocabularyCorrector.phoneticKey(oldLetters)
        let termKey = VocabularyCorrector.phoneticKey(termLetters)
        // Tiny keys make the loose tolerance meaningless ("Noon" and "Night"
        // are one edit apart as keys), so they must pass the spelling check.
        guard oldKey.count >= 2, termKey.count >= 2 else { return false }
        let keyDistance = VocabularyCorrector.editDistance(oldKey, termKey)
        return Double(keyDistance) / Double(max(oldKey.count, termKey.count)) <= phoneticTolerance
    }

    private static func trimEdgePunctuation(_ token: String) -> String {
        let isEdge: (Character) -> Bool = { !$0.isLetter && !$0.isNumber }
        let core = token.drop(while: isEdge)
        return String(core.reversed().drop(while: isEdge).reversed())
    }

    // MARK: Diffing

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Contiguous spans where `a` was replaced by `b` (LCS diff, with adjacent
    /// delete+insert merged into one replacement). Pure insertions and pure
    /// deletions are dropped: they're new content, not corrections.
    private static func replaceHunks(_ a: [String], _ b: [String]) -> [(old: ArraySlice<String>, new: ArraySlice<String>)] {
        let n = a.count, m = b.count
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }

        var hunks: [(ArraySlice<String>, ArraySlice<String>)] = []
        var i = 0, j = 0
        while i < n || j < m {
            if i < n, j < m, a[i] == b[j] {
                i += 1
                j += 1
                continue
            }
            let startI = i, startJ = j
            while i < n || j < m {
                if i < n, j < m, a[i] == b[j] { break }
                if j == m || (i < n && lcs[i + 1][j] >= lcs[i][j + 1]) { i += 1 } else { j += 1 }
            }
            let old = a[startI..<i], new = b[startJ..<j]
            if !old.isEmpty, !new.isEmpty { hunks.append((old, new)) }
        }
        return hunks
    }

    /// Token index ranges where `needle` appears as a consecutive run inside
    /// `haystack`. The snapshot is only taken once the field is known to contain
    /// the pasted text, so this is normally exactly one range.
    private static func occurrences(of needle: [String], in haystack: [String]) -> [Range<Int>] {
        guard !needle.isEmpty, needle.count <= haystack.count else { return [] }
        var ranges: [Range<Int>] = []
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle {
                ranges.append(start..<(start + needle.count))
            }
        }
        return ranges
    }
}
