import Foundation
import WhisperKit

/// Manages Whisper model storage and loading: where models live, whether they're
/// present, downloading them (with progress) on first run, and producing a ready
/// `Transcriber`. This is what makes the user flow zero-friction: no manual
/// downloads, no Terminal.
public final class ModelManager {
    private let settings: Settings

    public init(settings: Settings = .shared) {
        self.settings = settings
    }

    /// Root directory for models. Honors a user-chosen path (e.g. external SSD),
    /// otherwise Application Support/Drift/models.
    public var modelsDirectory: URL {
        if let custom = settings.modelStoragePath, !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Drift/models", isDirectory: true)
    }

    /// Whether the given variant has been downloaded and its folder still exists.
    public func isDownloaded(_ variant: String) -> Bool {
        guard let path = settings.modelFolderPath(for: variant) else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    public var isDefaultModelDownloaded: Bool {
        isDownloaded(settings.modelVariant)
    }

    /// Ensures the variant is present (downloading with progress if needed), loads
    /// it, and returns a ready `Transcriber`.
    /// - Parameter onProgress: download progress in 0...1 (only called while downloading).
    public func loadTranscriber(
        variant requested: String? = nil,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> Transcriber {
        let variant = requested ?? settings.modelVariant
        try FileManager.default.createDirectory(
            at: modelsDirectory, withIntermediateDirectories: true
        )

        let folder: URL
        if let saved = settings.modelFolderPath(for: variant),
           FileManager.default.fileExists(atPath: saved) {
            folder = URL(fileURLWithPath: saved) // offline-friendly fast path
        } else {
            folder = try await WhisperKit.download(
                variant: variant,
                downloadBase: modelsDirectory,
                from: settings.modelRepo,
                progressCallback: { progress in
                    onProgress?(progress.fractionCompleted)
                }
            )
            settings.setModelFolderPath(folder.path, for: variant)
        }

        let config = WhisperKitConfig(modelFolder: folder.path)
        let kit = try await WhisperKit(config)
        return WhisperKitTranscriber(whisperKit: kit)
    }
}
