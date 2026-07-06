import Foundation

/// The user's personal vocabulary: names and terms the speech models keep
/// mishearing ("Karan Johar" -> "current johar"). One list feeds every layer
/// that can fix this: Whisper decode-time biasing and the LLM cleanup prompt.
public enum Vocabulary {
    /// Terms sent to Whisper as a decoding prompt. Whisper's prompt shares a
    /// 224-token budget with prefill, and WhisperKit keeps the prompt's *suffix*
    /// when trimming, so we cap the term count ourselves to keep the outcome
    /// deterministic. ~30 short names fits comfortably.
    public static let maxWhisperTerms = 30

    /// Splits raw user input (one term per line, commas also accepted) into a
    /// clean list: trimmed, blanks dropped, case-insensitive duplicates removed,
    /// original order kept.
    public static func parse(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { term in
                guard !term.isEmpty else { return false }
                return seen.insert(term.lowercased()).inserted
            }
    }

    /// Text passed to Whisper as the conditioning prompt (the model treats it as
    /// preceding transcript, which biases decoding toward these spellings).
    /// Plain comma-separated terms, per OpenAI's spelling-hint guidance.
    public static func whisperPrompt(terms: [String]) -> String? {
        guard !terms.isEmpty else { return nil }
        return terms.prefix(maxWhisperTerms).joined(separator: ", ")
    }

    /// Instruction appended to the LLM cleanup system prompt so mangled names
    /// ("I should have a run") are restored from the user's list.
    public static func cleanupClause(terms: [String]) -> String? {
        guard !terms.isEmpty else { return nil }
        let list = terms.joined(separator: ", ")
        return """
        The speaker often says these names and terms: \(list). \
        If a word or phrase in the transcript looks like a misrecognition of one \
        of them (similar sound, garbled spelling), replace it with the correct \
        term. Only substitute when the match is plausible from context.
        """
    }
}
