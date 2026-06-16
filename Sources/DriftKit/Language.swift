import Foundation

/// Writing system of a language. Drives script-aware text cleanup so we never
/// apply Latin-centric rules (English filler words, capitalization) to Indic text.
public enum Script: Sendable {
    case latin
    case indic
    case other
}

/// A spoken language Drift can transcribe. `code` is the Whisper language code
/// (ISO 639-1), or "auto" for Whisper's built-in language detection.
public struct Language: Equatable, Hashable, Sendable, Identifiable {
    public let code: String
    public let displayName: String
    public let script: Script

    public var id: String { code }
    public var isAuto: Bool { code == "auto" }
    /// The code to hand WhisperKit (`nil` means auto-detect).
    public var whisperCode: String? { isAuto ? nil : code }

    public init(code: String, displayName: String, script: Script) {
        self.code = code
        self.displayName = displayName
        self.script = script
    }

    public static let auto      = Language(code: "auto", displayName: "Auto-detect", script: .other)
    public static let english   = Language(code: "en", displayName: "English",   script: .latin)
    public static let hindi     = Language(code: "hi", displayName: "Hindi",     script: .indic)
    public static let tamil     = Language(code: "ta", displayName: "Tamil",     script: .indic)
    public static let malayalam = Language(code: "ml", displayName: "Malayalam", script: .indic)
    public static let kannada   = Language(code: "kn", displayName: "Kannada",   script: .indic)
    public static let telugu    = Language(code: "te", displayName: "Telugu",    script: .indic)
    public static let spanish   = Language(code: "es", displayName: "Spanish",   script: .latin)
    public static let french    = Language(code: "fr", displayName: "French",    script: .latin)
    public static let german    = Language(code: "de", displayName: "German",    script: .latin)

    /// Indian languages are listed first to match Drift's focus.
    public static let all: [Language] = [
        .auto, .english,
        .hindi, .tamil, .malayalam, .kannada, .telugu,
        .spanish, .french, .german,
    ]

    public static func from(code: String) -> Language {
        all.first { $0.code == code } ?? .english
    }
}
