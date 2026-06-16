import AppKit

// INTERIM ONLY (interim-whisper-cpp branch). Entry point for the swiftc-built,
// AppKit menu-bar app. The SwiftUI @main app (DriftApp.swift) is excluded from
// this build by scripts/dev-build-clt.sh.
let app = NSApplication.shared
let delegate = InterimAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
app.run()
