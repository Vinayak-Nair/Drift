import SwiftUI
import DriftKit

/// First-run setup: microphone, accessibility, and the model download. Designed so
/// the user never needs the Terminal or any separate install.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState

    private var downloadFraction: Double? {
        if case .downloadingModel(let p) = state.status { return p }
        return nil
    }

    private var modelDownloaded: Bool {
        state.isModelDownloaded(state.modelVariant)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Drift")
                    .font(.largeTitle.bold())
                Text("Hold a key, speak, and your words appear as text in any app. Transcription runs entirely on your Mac.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            StepRow(
                number: 1,
                title: "Microphone access",
                detail: "So Drift can hear you.",
                done: state.micGranted,
                actionTitle: "Grant",
                action: { Task { await state.requestMicrophone() } }
            )

            StepRow(
                number: 2,
                title: "Accessibility access",
                detail: "Needed for the push-to-talk key and to type into other apps. You may need to relaunch Drift after granting.",
                done: state.accessibilityGranted,
                actionTitle: "Open Settings",
                action: { state.requestAccessibility() }
            )

            modelStep

            Spacer(minLength: 0)

            HStack {
                Button("Re-check") { state.refreshPermissions() }
                Spacer()
                Button("Start Using Drift") { state.finishOnboarding() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.allPermissionsAndModelReady)
            }
        }
        .padding(28)
        .frame(width: 520, height: 600)
    }

    private var modelStep: some View {
        HStack(alignment: .top, spacing: 14) {
            stepBadge(3, done: modelDownloaded)
            VStack(alignment: .leading, spacing: 6) {
                Text("Download the speech model").font(.headline)
                Text("A one-time download of the multilingual Whisper model (large-v3 turbo). Supports English plus Hindi, Tamil, Malayalam, Kannada, Telugu, and more.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let frac = downloadFraction {
                    ProgressView(value: frac) {
                        Text("Downloading… \(Int(frac * 100))%").font(.caption)
                    }
                    .frame(maxWidth: 320)
                }
                if case .error(let msg) = state.status {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if modelDownloaded {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
            } else if downloadFraction == nil {
                Button("Download") { Task { await state.loadModel() } }
            }
        }
    }

    private func stepBadge(_ n: Int, done: Bool) -> some View {
        ZStack {
            Circle().fill(done ? Color.green : Color.secondary.opacity(0.2)).frame(width: 26, height: 26)
            if done {
                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
            } else {
                Text("\(n)").font(.caption.bold())
            }
        }
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let detail: String
    let done: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(done ? Color.green : Color.secondary.opacity(0.2)).frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.caption.bold())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
            } else {
                Button(actionTitle, action: action)
            }
        }
    }
}
