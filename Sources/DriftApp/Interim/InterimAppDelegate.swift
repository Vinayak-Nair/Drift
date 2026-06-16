import AppKit
import AVFoundation
import ApplicationServices
import IOKit.hid

// INTERIM ONLY (interim-whisper-cpp branch).
// AppKit menu-bar shell driving the DriftKit pipeline. Transcription goes to a
// warm local whisper.cpp server (model stays in memory). `main` keeps the
// SwiftUI + WhisperKit version.
//
// Permissions: the global push-to-talk key is a listen-only keyboard event tap,
// which macOS gates behind INPUT MONITORING. Pasting the result into the focused
// app synthesizes Cmd+V, which needs ACCESSIBILITY. Both are required.
final class InterimAppDelegate: NSObject, NSApplicationDelegate {
    private enum State {
        case needsSetup, startingEngine, idle, recording, processing, error(String)
    }

    private var statusItem: NSStatusItem!
    private let hotkey = Hotkey()
    private var server: WhisperServerManager!
    private var pipeline: Pipeline?
    private var state: State = .startingEngine { didSet { updateIcon() } }
    private var permTimer: Timer?
    private var lastPermSignature = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        server = WhisperServerManager(binaryPath: Self.resolveServerBinary(), modelPath: Self.resolveModel())
        rebuildMenu(); updateIcon()

        // Trigger the permission prompts up front.
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)        // Input Monitoring
        _ = AXIsProcessTrustedWithOptions(                          // Accessibility
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)

        hotkey.onPress = { [weak self] in self?.startDictation() }
        hotkey.onRelease = { [weak self] in self?.stopDictation() }
        hotkey.start()

        // Enable the hotkey the moment Input Monitoring is granted, and keep the
        // menu's permission warnings in sync, without forcing a relaunch.
        permTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }

        startEngine()
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    // MARK: Permissions

    private var inputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }
    private var accessibilityGranted: Bool { AXIsProcessTrusted() }

    private func refreshPermissions() {
        if inputMonitoringGranted && !hotkey.isActive { hotkey.start() }
        let signature = "\(inputMonitoringGranted)-\(accessibilityGranted)-\(hotkey.isActive)"
        if signature != lastPermSignature { lastPermSignature = signature; rebuildMenu() }
    }

    // MARK: Engine

    private func startEngine() {
        guard server.isReadyToStart else { state = .needsSetup; rebuildMenu(); return }
        state = .startingEngine
        rebuildMenu()
        server.start()
        Task { [weak self] in
            guard let self else { return }
            let ready = await self.server.waitUntilReady()
            await MainActor.run {
                if ready {
                    let t = WhisperServerTranscriber(baseURL: WhisperServerManager.baseURL)
                    self.pipeline = Pipeline(transcriber: t, settings: .shared)
                    self.state = .idle
                } else {
                    self.state = .error("speech engine didn't start")
                }
                self.rebuildMenu()
            }
        }
    }

    private static func resolveServerBinary() -> String {
        let candidates = ["/opt/homebrew/bin/whisper-server", "/usr/local/bin/whisper-server"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }

    private static func resolveModel() -> String {
        // Small multilingual model: ~4x faster than large-v3-turbo. Good for
        // English/Hindi; weaker for Malayalam. Swap the filename to change models.
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".drift/models/ggml-small.bin").path
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let imOK = inputMonitoringGranted
        let axOK = accessibilityGranted
        if !imOK || !axOK {
            menu.addItem(.separator())
            if !imOK {
                addDisabled("⚠ Input Monitoring off: push-to-talk disabled", to: menu)
                addAction("Grant Input Monitoring…", #selector(openInputMonitoring), to: menu)
            }
            if !axOK {
                addDisabled("⚠ Accessibility off: can't paste text", to: menu)
                addAction("Grant Accessibility…", #selector(openAccessibility), to: menu)
            }
        }

        menu.addItem(.separator())

        switch state {
        case .idle:
            addAction("Start Dictation", #selector(toggleDictation), to: menu)
        case .recording:
            addAction("Stop Dictation", #selector(toggleDictation), to: menu)
        case .needsSetup:
            addDisabled("Run scripts/dev-setup-clt.sh to finish setup", to: menu)
        default:
            break
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
        addAction("Check Permissions…", #selector(checkPermissions), to: menu)
        let quit = NSMenuItem(title: "Quit Drift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }
    private func addAction(_ title: String, _ action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private var statusText: String {
        switch state {
        case .needsSetup: return "Drift — setup needed"
        case .startingEngine: return "Starting speech engine…"
        case .idle:
            return hotkey.isActive ? "Ready — hold Right Option (⌥) to talk"
                                   : "Ready — grant permissions to use the hotkey"
        case .recording: return "Recording…"
        case .processing: return "Transcribing…"
        case .error(let m): return "Error: \(m)"
        }
    }

    private var isRecording: Bool { if case .recording = state { return true } else { return false } }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let name: String
        switch state {
        case .recording: name = "waveform.circle.fill"
        case .processing, .startingEngine: name = "ellipsis.circle"
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

    @objc private func openInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openSettings("Privacy_ListenEvent")
    }

    @objc private func openAccessibility() {
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openSettings("Privacy_Accessibility")
    }

    private func openSettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func checkPermissions() {
        let alert = NSAlert()
        alert.messageText = "Drift Permissions"
        alert.informativeText = """
        Input Monitoring: \(inputMonitoringGranted ? "granted" : "NOT granted")  (needed for the push-to-talk key)
        Accessibility: \(accessibilityGranted ? "granted" : "NOT granted")  (needed to paste text)
        Microphone: \(AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? "granted" : "NOT granted")

        Turn on Drift in BOTH System Settings ▸ Privacy & Security ▸ Input Monitoring
        and ▸ Accessibility. If a permission was just granted but is still shown off,
        quit and reopen Drift once.
        """
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Close")
        switch alert.runModal() {
        case .alertFirstButtonReturn: openSettings("Privacy_ListenEvent")
        case .alertSecondButtonReturn: openSettings("Privacy_Accessibility")
        default: break
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
}
