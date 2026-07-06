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

    public static let auto       = Language(code: "auto", displayName: "Auto-detect", script: .other)
    public static let english    = Language(code: "en", displayName: "English",      script: .latin)
    public static let assamese   = Language(code: "as", displayName: "Assamese",     script: .indic)
    public static let bengali    = Language(code: "bn", displayName: "Bengali",      script: .indic)
    public static let bodo       = Language(code: "brx", displayName: "Bodo",        script: .indic)
    public static let dogri      = Language(code: "doi", displayName: "Dogri",       script: .indic)
    public static let gujarati   = Language(code: "gu", displayName: "Gujarati",     script: .indic)
    public static let hindi      = Language(code: "hi", displayName: "Hindi",        script: .indic)
    public static let kannada    = Language(code: "kn", displayName: "Kannada",      script: .indic)
    public static let konkani    = Language(code: "kok", displayName: "Konkani",     script: .indic)
    public static let kashmiri   = Language(code: "ks", displayName: "Kashmiri",     script: .indic)
    public static let maithili   = Language(code: "mai", displayName: "Maithili",    script: .indic)
    public static let malayalam  = Language(code: "ml", displayName: "Malayalam",    script: .indic)
    public static let manipuri   = Language(code: "mni", displayName: "Manipuri",    script: .indic)
    public static let marathi    = Language(code: "mr", displayName: "Marathi",      script: .indic)
    public static let nepali     = Language(code: "ne", displayName: "Nepali",       script: .indic)
    public static let odia       = Language(code: "or", displayName: "Odia",         script: .indic)
    public static let punjabi    = Language(code: "pa", displayName: "Punjabi",      script: .indic)
    public static let sanskrit   = Language(code: "sa", displayName: "Sanskrit",     script: .indic)
    public static let santali    = Language(code: "sat", displayName: "Santali",     script: .indic)
    public static let sindhi     = Language(code: "sd", displayName: "Sindhi",       script: .indic)
    public static let tamil      = Language(code: "ta", displayName: "Tamil",        script: .indic)
    public static let telugu     = Language(code: "te", displayName: "Telugu",       script: .indic)
    public static let urdu       = Language(code: "ur", displayName: "Urdu",         script: .indic)
    public static let spanish    = Language(code: "es", displayName: "Spanish",      script: .latin)
    public static let french     = Language(code: "fr", displayName: "French",       script: .latin)
    public static let german     = Language(code: "de", displayName: "German",       script: .latin)

    /// Languages offered by the WhisperKit backend today.
    public static let whisperKitLanguages: [Language] = [
        .auto, .english,
        .hindi, .tamil, .malayalam, .kannada, .telugu,
        .spanish, .french, .german,
    ]

    /// The 22 official Indian languages supported by AI4Bharat IndicConformer.
    public static let indicConformerLanguages: [Language] = [
        .assamese, .bengali, .bodo, .dogri, .gujarati, .hindi, .kannada,
        .konkani, .kashmiri, .maithili, .malayalam, .manipuri, .marathi,
        .nepali, .odia, .punjabi, .sanskrit, .santali, .sindhi, .tamil,
        .telugu, .urdu,
    ]

    /// All language ids Drift may persist or display.
    public static let all: [Language] = [
        .auto, .english,
        .assamese, .bengali, .bodo, .dogri, .gujarati, .hindi, .kannada,
        .konkani, .kashmiri, .maithili, .malayalam, .manipuri, .marathi,
        .nepali, .odia, .punjabi, .sanskrit, .santali, .sindhi, .tamil,
        .telugu, .urdu,
        .spanish, .french, .german,
    ]

    public static func from(code: String) -> Language {
        all.first { $0.code == code } ?? .english
    }
}
