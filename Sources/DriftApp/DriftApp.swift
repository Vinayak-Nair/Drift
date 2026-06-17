import SwiftUI

@main
struct DriftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        WindowGroup("Drift", id: "dashboard") {
            DashboardView()
                .environmentObject(state)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            DriftMenu().environmentObject(state)
        } label: {
            Image(systemName: state.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Task { await AppState.shared.bootstrap() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in AppState.shared.refreshPermissions() }
    }
}
