import Foundation

/// Deterministic, on-device safety net for the personal vocabulary: finds spans
/// of the transcript that sound like a dictionary term and replaces them with
/// the term as written ("current johar" -> "Karan Johar"). Runs before cleanup
/// for every provider, so users on fully local cleanup are covered without any
/// network or LLM.
///
/// Matching is intentionally conservative: a span must be close both
/// phonetically and in raw spelling before it is replaced. Severely mangled
/// captures ("I should have a run" for "Aishwarya Rai") are left alone here;
/// the LLM cleanup layer, which sees the vocabulary in its prompt, handles those.
public enum VocabularyCorrector {
    /// Max normalized edit distance between phonetic keys for a match.
    private static let phoneticThreshold = 0.34
    /// Max normalized edit distance between letters-only spellings for a match.
    private static let spellingThreshold = 0.5
    /// Keys shorter than this fall back to a strict spelling-only comparison,
    /// since tiny phonetic keys collide too easily.
    private static let minKeyLength = 3
    /// Spelling threshold for the short-key fallback path.
    private static let strictSpellingThreshold = 0.25

    public static func correct(_ text: String, vocabulary: [String]) -> String {
        guard !text.isEmpty, !vocabulary.isEmpty else { return text }

        let segments = split(text)
        let words = segments.compactMap { $0.word }
        guard !words.isEmpty else { return text }

        let matches = bestMatches(words: words, vocabulary: vocabulary)
        guard !matches.isEmpty else { return text }

        return rebuild(segments: segments, words: words, matches: matches)
    }

    // MARK: Matching

    /// A replacement covering word indices `start...end` (inclusive).
    private struct Match {
        let start: Int
        let end: Int
        let score: Double
        let replacement: String
    }

    private static func bestMatches(words: [Word], vocabulary: [String]) -> [Match] {
        var candidates: [Match] = []
        // Spans already spelled exactly right are locked first, so a fuzzy
        // window like "Karan Johar is" can't swallow a correct "Karan Johar".
        var used = exactSpans(words: words, vocabulary: vocabulary)

        for term in vocabulary {
            let termWordCount = max(1, term.split(separator: " ").count)
            let termLetters = lettersOnly(term)
            guard !termLetters.isEmpty else { continue }
            let termKey = phoneticKey(termLetters)

            let minWindow = max(1, termWordCount - 1)
            let maxWindow = termWordCount + 1
            for windowLength in minWindow...maxWindow {
                guard windowLength <= words.count else { continue }
                for start in 0...(words.count - windowLength) {
                    let window = Array(words[start..<(start + windowLength)])
                    let visible = window.map(\.core).joined(separator: " ")
                    guard visible != term else { continue } // already correct
                    let windowLetters = lettersOnly(visible)
                    guard !windowLetters.isEmpty else { continue }

                    guard let score = matchScore(
                        termLetters: termLetters, termKey: termKey,
                        windowLetters: windowLetters
                    ) else { continue }

                    candidates.append(Match(
                        start: start, end: start + windowLength - 1,
                        score: score, replacement: term
                    ))
                }
            }
        }

        // Best (lowest score) first; longer spans win ties so "current johar"
        // beats a stray single-word match inside it. Then keep non-overlapping.
        candidates.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            if ($0.end - $0.start) != ($1.end - $1.start) { return ($0.end - $0.start) > ($1.end - $1.start) }
            return $0.start < $1.start
        }
        var accepted: [Match] = []
        for match in candidates {
            let span = match.start...match.end
            guard !span.contains(where: used.contains) else { continue }
            span.forEach { used.insert($0) }
            accepted.append(match)
        }
        return accepted
    }

    /// Word spans that already read exactly as a vocabulary term.
    private static func exactSpans(words: [Word], vocabulary: [String]) -> Set<Int> {
        var spans = Set<Int>()
        for term in vocabulary {
            let count = max(1, term.split(separator: " ").count)
            guard count <= words.count else { continue }
            for start in 0...(words.count - count) {
                let visible = words[start..<(start + count)].map(\.core).joined(separator: " ")
                if visible == term {
                    (start..<(start + count)).forEach { spans.insert($0) }
                }
            }
        }
        return spans
    }

    /// Nil when the window is not a plausible capture of the term; otherwise a
    /// score where lower is a closer match (0 = same letters, casing aside).
    private static func matchScore(termLetters: [Character], termKey: [Character], windowLetters: [Character]) -> Double? {
        if termLetters == windowLetters { return 0 } // casing or punctuation fix

        let spellingDistance = editDistance(termLetters, windowLetters)
        let spelling = Double(spellingDistance) / Double(max(termLetters.count, windowLetters.count))

        let windowKey = phoneticKey(windowLetters)
        if termKey.count >= minKeyLength, windowKey.count >= minKeyLength {
            let keyDistance = editDistance(termKey, windowKey)
            let phonetic = Double(keyDistance) / Double(max(termKey.count, windowKey.count))
            guard phonetic <= phoneticThreshold, spelling <= spellingThreshold else { return nil }
            return phonetic + spelling
        }

        guard spelling <= strictSpellingThreshold else { return nil }
        return spelling + 1 // rank below any phonetic-confirmed match
    }

    // MARK: Phonetics

    /// Lowercased letters only, any script. Words are squashed together before
    /// comparison so resegmentation ("bangalore" vs "bangaluru") doesn't matter.
    /// Internal so `DictionaryLearner` shares the same notion of similarity.
    static func lettersOnly(_ s: String) -> [Character] {
        s.lowercased().filter(\.isLetter)
    }

    /// A compact consonant skeleton (simplified Metaphone): vowels dropped,
    /// sound-alike consonants merged, doubles collapsed. "karanjohar" and
    /// "currentjohar" come out one edit apart.
    static func phoneticKey(_ letters: [Character]) -> [Character] {
        guard !letters.isEmpty else { return [] }

        // Digraphs first, so "sh"/"ch"/"ph"/"th"/"ck" map as one sound.
        var sounds: [Character] = []
        var i = 0
        while i < letters.count {
            if i + 1 < letters.count {
                switch String(letters[i...(i + 1)]) {
                case "ph": sounds.append("f"); i += 2; continue
                case "sh", "ch": sounds.append("x"); i += 2; continue
                case "th": sounds.append("t"); i += 2; continue
                case "ck": sounds.append("k"); i += 2; continue
                default: break
                }
            }
            sounds.append(letters[i])
            i += 1
        }

        var key: [Character] = []
        for (index, c) in sounds.enumerated() {
            let mapped: Character?
            switch c {
            case "a", "e", "i", "o", "u", "y", "h", "w":
                mapped = index == 0 ? "a" : nil // keep only a leading vowel marker
            case "b", "p": mapped = "p"
            case "f", "v": mapped = "f"
            case "c", "k", "q", "g": mapped = "k"
            case "s", "z": mapped = "s"
            case "d", "t": mapped = "t"
            default: mapped = c // j l m n r x and non-Latin letters keep identity
            }
            if let mapped, key.last != mapped { key.append(mapped) }
        }
        return key
    }

    static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    // MARK: Text plumbing

    /// A non-whitespace run, split into surrounding punctuation and the core
    /// ("(johar," -> leading "(", core "johar", trailing ","). Replacements keep
    /// the punctuation and swap only the core span.
    private struct Word {
        let leading: String
        let core: String
        let trailing: String
    }

    private enum Segment {
        case whitespace(String)
        case word(Word)

        var word: Word? {
            if case .word(let w) = self { return w }
            return nil
        }
    }

    private static func split(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var run = ""
        var runIsWhitespace: Bool?

        func flush() {
            guard let isWS = runIsWhitespace, !run.isEmpty else { return }
            segments.append(isWS ? .whitespace(run) : .word(makeWord(run)))
            run = ""
        }

        for ch in text {
            if ch.isWhitespace != runIsWhitespace {
                flush()
                runIsWhitespace = ch.isWhitespace
            }
            run.append(ch)
        }
        flush()
        return segments
    }

    private static func makeWord(_ token: String) -> Word {
        let isEdge: (Character) -> Bool = { !$0.isLetter && !$0.isNumber }
        let core = token.drop(while: isEdge)
        let trimmed = core.reversed().drop(while: isEdge).reversed()
        let leading = token.prefix(token.count - core.count)
        let trailing = core.suffix(core.count - trimmed.count)
        return Word(leading: String(leading), core: String(trimmed), trailing: String(trailing))
    }

    private static func rebuild(segments: [Segment], words: [Word], matches: [Match]) -> String {
        let matchAtStart = Dictionary(uniqueKeysWithValues: matches.map { ($0.start, $0) })
        var out = ""
        var wordIndex = 0
        var skipThroughWord = -1

        for segment in segments {
            switch segment {
            case .whitespace(let ws):
                // Whitespace inside a replaced span is dropped with it.
                if wordIndex > skipThroughWord { out += ws }
            case .word(let word):
                defer { wordIndex += 1 }
                if wordIndex <= skipThroughWord { continue }
                if let match = matchAtStart[wordIndex] {
                    out += word.leading + match.replacement + words[match.end].trailing
                    skipThroughWord = match.end
                } else {
                    out += word.leading + word.core + word.trailing
                }
            }
        }
        return out
    }
}
