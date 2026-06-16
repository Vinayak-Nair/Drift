import AppKit
import AVFoundation
import ApplicationServices
import SwiftUI
import DriftKit

/// Central app orchestrator: owns the model, pipeline, and hotkey; tracks status
/// and permissions; drives the dictation flow; and manages the onboarding and
/// settings windows. `@MainActor` so UI state is always touched on the main thread.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Status: Equatable {
        case needsSetup
        case loadingModel
        case downloadingModel(Double)
        case idle
        case recording
        case transcribing
        case error(String)
    }

    @Published private(set) var status: Status = .needsSetup
    @Published private(set) var micGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var lastText = ""
    @Published private(set) var transcriptHistory: [TranscriptEntry]
    @Published private(set) var availableMicrophones: [AudioInputDevice]
    @Published private(set) var selectedMicrophoneID: String
    @Published private(set) var selectedMicrophoneName: String

    // Editable settings mirrors (observable for SwiftUI). didSet writes through.
    @Published var languageCode: String { didSet { settings.languageCode = languageCode } }
    @Published var cleanupProviderID: String { didSet { settings.cleanupProviderID = cleanupProviderID } }
    @Published var openAIBaseURL: String { didSet { settings.openAIBaseURL = openAIBaseURL } }
    @Published var openAIModel: String { didSet { settings.openAIModel = openAIModel } }
    @Published var openAIKey: String { didSet { settings.openAIKey = openAIKey } }
    @Published var ollamaBaseURL: String { didSet { settings.ollamaBaseURL = ollamaBaseURL } }
    @Published var ollamaModel: String { didSet { settings.ollamaModel = ollamaModel } }
    @Published private(set) var modelVariant: String

    let settings = Settings.shared
    private let modelManager = ModelManager()
    private var pipeline: Pipeline?
    private let hotkey = Hotkey()
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let transcriptHistoryKey = "transcriptHistory"
    private let transcriptHistoryLimit = 100

    private init() {
        let s = Settings.shared
        languageCode = s.languageCode
        cleanupProviderID = s.cleanupProviderID
        openAIBaseURL = s.openAIBaseURL
        openAIModel = s.openAIModel
        openAIKey = s.openAIKey
        ollamaBaseURL = s.ollamaBaseURL
        ollamaModel = s.ollamaModel
        modelVariant = s.modelVariant
        transcriptHistory = Self.loadTranscriptHistory()
        availableMicrophones = AudioInputDevices.available()
        selectedMicrophoneID = s.inputDeviceID
        if !availableMicrophones.contains(where: { $0.id == selectedMicrophoneID }) {
            selectedMicrophoneID = AudioInputDevice.systemDefaultID
            s.inputDeviceID = selectedMicrophoneID
        }
        selectedMicrophoneName = AudioInputDevices.displayName(
            for: selectedMicrophoneID,
            in: availableMicrophones
        )
    }

    // MARK: Lifecycle

    func bootstrap() async {
        refreshPermissions()
        refreshSelectedMicrophone()
        let ready = settings.hasCompletedOnboarding && micGranted
            && accessibilityGranted && modelManager.isDefaultModelDownloaded
        if ready {
            await loadModelAndStart()
        } else {
            status = .needsSetup
            showOnboardingWindow()
        }
    }

    private func loadModelAndStart() async {
        await loadModel()
        if case .idle = status { startHotkey() }
    }

    func loadModel(variant: String? = nil) async {
        let target = variant ?? settings.modelVariant
        status = modelManager.isDownloaded(target) ? .loadingModel : .downloadingModel(0)
        do {
            let transcriber = try await modelManager.loadTranscriber(variant: target) { [weak self] frac in
                Task { @MainActor in self?.status = .downloadingModel(frac) }
            }
            pipeline = Pipeline(transcriber: transcriber, settings: settings)
            status = .idle
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func startHotkey() {
        hotkey.onPress = { Task { @MainActor in AppState.shared.startDictation() } }
        hotkey.onRelease = { Task { @MainActor in await AppState.shared.stopDictation() } }
        hotkey.start()
    }

    // MARK: Dictation

    func toggleDictation() {
        if case .recording = status { Task { await stopDictation() } }
        else { startDictation() }
    }

    func startDictation() {
        guard case .idle = status, let pipeline else { return }
        do {
            refreshSelectedMicrophone()
            try pipeline.startRecording()
            status = .recording
            Feedback.start()
        } catch {
            status = .error("Microphone unavailable")
        }
    }

    func stopDictation() async {
        guard case .recording = status, let pipeline else { return }
        status = .transcribing
        do {
            let text = try await pipeline.stopAndProcess()
            status = .idle
            if text.isEmpty {
                Feedback.empty()
            } else {
                lastText = text
                recordTranscript(text)
                Paster.paste(text)
                Feedback.success()
            }
        } catch {
            status = .idle
            Feedback.empty()
        }
    }

    // MARK: Model selection

    func selectModel(_ variant: String) {
        guard variant != settings.modelVariant else { return }
        settings.modelVariant = variant
        modelVariant = variant
        hotkey.stop()
        Task {
            await loadModel(variant: variant)
            if case .idle = status { startHotkey() }
        }
    }

    // MARK: Permissions

    func refreshPermissions() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        refreshPermissions()
        refreshSelectedMicrophone()
    }

    /// Prompts for Accessibility and opens the right System Settings pane.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        onboardingWindow?.close()
        if pipeline != nil, case .idle = status {
            startHotkey() // model already loaded during onboarding
        } else {
            Task { await loadModelAndStart() }
        }
    }

    // MARK: Windows

    func showOnboardingWindow() {
        if let onboardingWindow {
            NSApp.activate(ignoringOtherApps: true)
            onboardingWindow.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: OnboardingView().environmentObject(self))
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Drift"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 600))
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func showSettingsWindow() {
        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: SettingsView().environmentObject(self))
        let window = NSWindow(contentViewController: host)
        window.title = "Drift Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 540))
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Derived UI state

    var menuBarSymbol: String {
        switch status {
        case .recording: return "waveform.circle.fill"
        case .transcribing, .loadingModel, .downloadingModel: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle.fill"
        case .needsSetup: return "waveform.badge.exclamationmark"
        case .idle: return "waveform"
        }
    }

    var statusText: String {
        switch status {
        case .needsSetup: return "Setup required"
        case .loadingModel: return "Loading model…"
        case .downloadingModel(let p): return "Downloading model… \(Int(p * 100))%"
        case .idle: return "Ready. Hold \(keyName(settings.pttKeyCode)) to talk"
        case .recording: return "Recording…"
        case .transcribing: return "Transcribing…"
        case .error(let m): return "Error: \(m)"
        }
    }

    var isReady: Bool { if case .idle = status { return true } else { return false } }

    var languageDisplayName: String {
        Language.from(code: languageCode).displayName
    }

    var cleanupProviderDisplayName: String {
        CleanupRegistry.all.first { $0.id == cleanupProviderID }?.displayName ?? cleanupProviderID
    }

    var modelDisplayName: String {
        ModelCatalog.options.first { $0.id == modelVariant }?.displayName ?? modelVariant
    }

    var allPermissionsAndModelReady: Bool {
        micGranted && accessibilityGranted && modelManager.isDefaultModelDownloaded
    }

    func isModelDownloaded(_ variant: String) -> Bool { modelManager.isDownloaded(variant) }

    func keyName(_ code: Int) -> String {
        switch code {
        case 61: return "Right Option (⌥)"
        case 58: return "Left Option (⌥)"
        case 54: return "Right Command (⌘)"
        case 55: return "Left Command (⌘)"
        case 60: return "Right Shift (⇧)"
        case 62: return "Right Control (⌃)"
        default: return "key \(code)"
        }
    }

    // MARK: Dashboard

    func refreshSelectedMicrophone() {
        availableMicrophones = AudioInputDevices.available()
        if selectedMicrophoneID != AudioInputDevice.systemDefaultID,
           !availableMicrophones.contains(where: { $0.id == selectedMicrophoneID }) {
            selectedMicrophoneID = AudioInputDevice.systemDefaultID
            settings.inputDeviceID = selectedMicrophoneID
        }
        selectedMicrophoneName = AudioInputDevices.displayName(
            for: selectedMicrophoneID,
            in: availableMicrophones
        )
    }

    func selectMicrophone(_ id: String) {
        selectedMicrophoneID = id
        settings.inputDeviceID = id
        refreshSelectedMicrophone()
    }

    func clearTranscriptHistory() {
        transcriptHistory.removeAll()
        persistTranscriptHistory()
    }

    func copyTranscript(_ entry: TranscriptEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    func openSoundSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func recordTranscript(_ text: String) {
        let entry = TranscriptEntry(
            createdAt: Date(),
            text: text,
            languageCode: languageCode,
            microphoneName: selectedMicrophoneName
        )
        transcriptHistory.insert(entry, at: 0)
        if transcriptHistory.count > transcriptHistoryLimit {
            transcriptHistory.removeLast(transcriptHistory.count - transcriptHistoryLimit)
        }
        persistTranscriptHistory()
    }

    private static func loadTranscriptHistory() -> [TranscriptEntry] {
        guard let data = UserDefaults.standard.data(forKey: "transcriptHistory"),
              let decoded = try? JSONDecoder().decode([TranscriptEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistTranscriptHistory() {
        guard let data = try? JSONEncoder().encode(transcriptHistory) else { return }
        UserDefaults.standard.set(data, forKey: transcriptHistoryKey)
    }
}
