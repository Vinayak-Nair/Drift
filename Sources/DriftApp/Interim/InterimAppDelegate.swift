import AppKit
import AVFoundation
import ApplicationServices

// INTERIM ONLY (interim-whisper-cpp branch).
// AppKit menu-bar shell that drives the DriftKit pipeline with the whisper.cpp
// transcriber. Used instead of the SwiftUI app so it builds with swiftc (no
// Xcode). `main` keeps the SwiftUI + WhisperKit version.
final class InterimAppDelegate: NSObject, NSApplicationDelegate {
    private enum State { case needsSetup, idle, recording, processing, error(String) }

    private var statusItem: NSStatusItem!
    private let hotkey = Hotkey()
    private var pipeline: Pipeline?
    private var transcriber: WhisperCppTranscriber?
    private var state: State = .idle { didSet { updateIcon() } }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupPipeline()
        rebuildMenu()
        updateIcon()

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        promptAccessibility()

        hotkey.onPress = { [weak self] in self?.startDictation() }
        hotkey.onRelease = { [weak self] in self?.stopDictation() }
        hotkey.start()
    }

    // MARK: Setup

    private func setupPipeline() {
        let binary = Self.resolveBinary()
        let model = Self.resolveModel()
        let t = WhisperCppTranscriber(binaryPath: binary, modelPath: model)
        transcriber = t
        pipeline = Pipeline(transcriber: t, settings: .shared)
        state = t.isReady ? .idle : .needsSetup
    }

    private static func resolveBinary() -> String {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp", "/usr/local/bin/whisper-cpp",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }

    private static func resolveModel() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".drift/models/ggml-large-v3-turbo-q5_0.bin").path
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if case .needsSetup = state {
            let s = NSMenuItem(title: "Run scripts/dev-setup-clt.sh to finish", action: nil, keyEquivalent: "")
            s.isEnabled = false
            menu.addItem(s)
            menu.addItem(.separator())
        } else {
            let toggle = NSMenuItem(
                title: isRecording ? "Stop Dictation" : "Start Dictation",
                action: #selector(toggleDictation), keyEquivalent: "")
            toggle.target = self
            menu.addItem(toggle)
        }

        let langMenu = NSMenu()
        for lang in Language.all {
            let item = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            item.state = (Settings.shared.languageCode == lang.code) ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        menu.setSubmenu(langMenu, for: langItem)
        menu.addItem(langItem)

        let cleanupMenu = NSMenu()
        for (id, title) in [("deterministic", "On-device cleanup"), ("none", "Raw text")] {
            let item = NSMenuItem(title: title, action: #selector(selectCleanup(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = (Settings.shared.cleanupProviderID == id) ? .on : .off
            cleanupMenu.addItem(item)
        }
        let cleanupItem = NSMenuItem(title: "Cleanup", action: nil, keyEquivalent: "")
        menu.setSubmenu(cleanupMenu, for: cleanupItem)
        menu.addItem(cleanupItem)

        menu.addItem(.separator())
        let perms = NSMenuItem(title: "Check Permissions…", action: #selector(checkPermissions), keyEquivalent: "")
        perms.target = self
        menu.addItem(perms)
        let quit = NSMenuItem(title: "Quit Drift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private var statusText: String {
        switch state {
        case .needsSetup: return "Drift — setup needed"
        case .idle: return "Ready — hold Right Option (⌥) to talk"
        case .recording: return "Recording…"
        case .processing: return "Transcribing…"
        case .error(let m): return "Error: \(m)"
        }
    }

    private var isRecording: Bool {
        if case .recording = state { return true } else { return false }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let name: String
        switch state {
        case .recording: name = "waveform.circle.fill"
        case .processing: name = "ellipsis.circle"
        case .error, .needsSetup: name = "exclamationmark.triangle"
        case .idle: name = "waveform"
        }
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "Drift")
        button.image?.isTemplate = true
    }

    // MARK: Actions

    @objc private func toggleDictation() {
        if isRecording { stopDictation() } else { startDictation() }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String { Settings.shared.languageCode = code }
        rebuildMenu()
    }

    @objc private func selectCleanup(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { Settings.shared.cleanupProviderID = id }
        rebuildMenu()
    }

    @objc private func checkPermissions() {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let ax = AXIsProcessTrusted()
        let alert = NSAlert()
        alert.messageText = "Drift Permissions"
        alert.informativeText = """
        Microphone: \(mic ? "granted" : "not granted")
        Accessibility: \(ax ? "granted" : "not granted")

        Accessibility is required for the push-to-talk key and for typing into other apps.
        Grant it in System Settings, Privacy & Security, Accessibility, then relaunch Drift.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Dictation

    private func startDictation() {
        guard case .idle = state, let pipeline else { return }
        do {
            try pipeline.startRecording()
            state = .recording
            rebuildMenu()
            Feedback.start()
        } catch {
            state = .error("Microphone unavailable")
            rebuildMenu()
        }
    }

    private func stopDictation() {
        guard isRecording, let pipeline else { return }
        state = .processing
        rebuildMenu()
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let text = try await pipeline.stopAndProcess()
                await MainActor.run { self.finish(text: text) }
            } catch {
                await MainActor.run {
                    self.state = .idle
                    self.rebuildMenu()
                    Feedback.empty()
                }
            }
        }
    }

    @MainActor private func finish(text: String) {
        state = .idle
        rebuildMenu()
        if text.isEmpty {
            Feedback.empty()
        } else {
            Paster.paste(text)
            Feedback.success()
        }
    }

    // MARK: Permissions

    private func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
