import Foundation

/// Typed, persisted configuration. Backed by `UserDefaults`; inject a custom
/// suite in tests. Note: the API key lives in UserDefaults for now; moving it to
/// the Keychain is tracked in the roadmap.
public final class Settings {
    public static let shared = Settings()

    private let d: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.d = defaults }

    // MARK: Transcription

    public var transcriptionBackendID: String {
        get { d.string(forKey: "transcriptionBackendID") ?? TranscriptionBackend.defaultBackend.rawValue }
        set { d.set(newValue, forKey: "transcriptionBackendID") }
    }

    public var transcriptionBackend: TranscriptionBackend {
        get { TranscriptionBackend.from(id: transcriptionBackendID) }
        set { transcriptionBackendID = newValue.rawValue }
    }

    public var modelVariant: String {
        get { d.string(forKey: "modelVariant") ?? ModelCatalog.defaultVariant }
        set { d.set(newValue, forKey: "modelVariant") }
    }

    public var modelRepo: String {
        get { d.string(forKey: "modelRepo") ?? "argmaxinc/whisperkit-coreml" }
        set { d.set(newValue, forKey: "modelRepo") }
    }

    /// Optional custom model storage directory (e.g. an external SSD). When nil,
    /// models are stored under Application Support.
    public var modelStoragePath: String? {
        get { d.string(forKey: "modelStoragePath") }
        set { d.set(newValue, forKey: "modelStoragePath") }
    }

    /// Remembers where a downloaded variant lives so relaunches work offline
    /// without re-checking the network.
    public func modelFolderPath(for variant: String) -> String? {
        d.string(forKey: "modelFolder_\(variant)")
    }
    public func setModelFolderPath(_ path: String, for variant: String) {
        d.set(path, forKey: "modelFolder_\(variant)")
    }

    public var languageCode: String {
        get { d.string(forKey: "languageCode") ?? "en" }
        set { d.set(newValue, forKey: "languageCode") }
    }

    public var language: Language {
        get { Language.from(code: languageCode) }
        set { languageCode = newValue.code }
    }

    /// The language used for transcription and cleanup. FluidAudio's first
    /// Drift integration is English-only, even if an old language preference is
    /// still stored from the multilingual WhisperKit path.
    public var effectiveLanguage: Language {
        transcriptionBackend == .fluidAudioEnglish ? .english : language
    }

    public var inputDeviceID: String {
        get { d.string(forKey: "inputDeviceID") ?? AudioInputDevice.systemDefaultID }
        set { d.set(newValue, forKey: "inputDeviceID") }
    }

    // MARK: Hotkey

    /// Push-to-talk key. Default: Right Option (keycode 61).
    public var pttKeyCode: Int {
        get { d.object(forKey: "pttKeyCode") as? Int ?? 61 }
        set { d.set(newValue, forKey: "pttKeyCode") }
    }

    // MARK: Cleanup

    /// Active cleanup provider id: "none", "deterministic", "openai", or "ollama".
    public var cleanupProviderID: String {
        get { d.string(forKey: "cleanupProviderID") ?? "deterministic" }
        set { d.set(newValue, forKey: "cleanupProviderID") }
    }

    // OpenAI-compatible (OpenAI, Groq, Sarvam, LM Studio, …)
    public var openAIBaseURL: String {
        get { d.string(forKey: "openAIBaseURL") ?? "https://api.openai.com/v1" }
        set { d.set(newValue, forKey: "openAIBaseURL") }
    }
    public var openAIModel: String {
        get { d.string(forKey: "openAIModel") ?? "gpt-4o-mini" }
        set { d.set(newValue, forKey: "openAIModel") }
    }
    public var openAIKey: String {
        get { d.string(forKey: "openAIKey") ?? "" }
        set { d.set(newValue, forKey: "openAIKey") }
    }

    // Ollama (advanced/local)
    public var ollamaBaseURL: String {
        get { d.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434" }
        set { d.set(newValue, forKey: "ollamaBaseURL") }
    }
    public var ollamaModel: String {
        get { d.string(forKey: "ollamaModel") ?? "llama3.2" }
        set { d.set(newValue, forKey: "ollamaModel") }
    }

    // MARK: App state

    public var hasCompletedOnboarding: Bool {
        get { d.bool(forKey: "hasCompletedOnboarding") }
        set { d.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}
