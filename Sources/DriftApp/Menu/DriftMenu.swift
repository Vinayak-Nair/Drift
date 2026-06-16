import SwiftUI
import DriftKit

/// Contents of the menu-bar dropdown.
struct DriftMenu: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Text(state.statusText)

        if !state.lastText.isEmpty {
            Text("Last: \(state.lastText.prefix(40))\(state.lastText.count > 40 ? "…" : "")")
        }

        Divider()

        if state.isReady || state.status == .recording {
            Button(state.status == .recording ? "Stop Dictation" : "Start Dictation") {
                state.toggleDictation()
            }
        }

        Menu("Language") {
            ForEach(Language.all) { lang in
                Button {
                    state.languageCode = lang.code
                } label: {
                    if state.languageCode == lang.code {
                        Label(lang.displayName, systemImage: "checkmark")
                    } else {
                        Text(lang.displayName)
                    }
                }
            }
        }

        Divider()

        Button("Settings…") { state.showSettingsWindow() }
        Button("Setup & Permissions…") { state.showOnboardingWindow() }

        Divider()

        Button("Quit Drift") { NSApp.terminate(nil) }
    }
}
