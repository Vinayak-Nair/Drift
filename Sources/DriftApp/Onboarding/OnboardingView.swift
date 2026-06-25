import SwiftUI
import DriftKit

/// First-run setup: microphone, accessibility, and the model download. Designed so
/// the user never needs the Terminal or any separate install.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var downloadFraction: Double? {
        if case .downloadingModel(let p) = state.status { return p }
        return nil
    }

    private var modelDownloaded: Bool { state.isSelectedModelDownloaded() }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                AuraOrb(diameter: 60, recording: false, busy: false)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Welcome to Drift")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Hold a key, speak, and your words appear as text in any app. Transcription runs entirely on your Mac.")
                        .font(.callout)
                        .foregroundStyle(Ink.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                StepRow(number: 1, title: "Microphone access", detail: "So Drift can hear you.",
                        done: state.micGranted, actionTitle: "Grant",
                        action: { Task { await state.requestMicrophone() } })
                StepRow(number: 2, title: "Accessibility access", detail: "Lets Drift type the transcribed text into other apps.",
                        done: state.accessibilityGranted, actionTitle: "Open Settings",
                        action: { state.requestAccessibility() })
                StepRow(number: 3, title: "Input Monitoring access", detail: "Lets the push-to-talk key work while other apps are focused.",
                        done: state.inputMonitoringGranted, actionTitle: "Open Settings",
                        action: { state.requestInputMonitoring() })
                modelStep
            }

            Spacer(minLength: 0)

            HStack {
                Button("Re-check") { state.refreshPermissions() }
                    .buttonStyle(.plain).font(.callout).foregroundStyle(Ink.text(0.6))
                Spacer()
                SoftButton(title: "Start Using Drift", systemImage: "arrow.right", prominent: true) {
                    state.finishOnboarding()
                }
                .disabled(!state.allPermissionsAndModelReady)
                .opacity(state.allPermissionsAndModelReady ? 1 : 0.5)
            }
        }
        .padding(28)
        .frame(width: 520, height: 620)
        .background(InkCanvas().ignoresSafeArea())
        .tint(Ink.accentSolid)
        .preferredColorScheme(.dark)
        .onReceive(permissionTimer) { _ in state.refreshPermissions() }
    }

    private var modelStep: some View {
        StepCard(done: modelDownloaded) {
            stepBadge(4, done: modelDownloaded)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.modelSetupTitle).font(.headline).foregroundStyle(.white)
                Text(state.modelSetupDetail)
                    .font(.callout).foregroundStyle(Ink.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                if let frac = downloadFraction {
                    ProgressView(value: frac) {
                        Text("Downloading… \(Int(frac * 100))%").font(.caption).foregroundStyle(Ink.text(0.6))
                    }
                    .frame(maxWidth: 320).tint(Ink.accentSolid)
                }
                if case .error(let msg) = state.status {
                    Text(msg).font(.caption).foregroundStyle(Ink.red)
                }
            }
            Spacer()
            if modelDownloaded {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Ink.green).font(.title2)
            } else if downloadFraction == nil {
                SoftButton(title: "Download", systemImage: "arrow.down.circle") { Task { await state.loadModel() } }
            }
        }
    }

    private func stepBadge(_ n: Int, done: Bool) -> some View {
        ZStack {
            Circle().fill(done ? AnyShapeStyle(Ink.green) : AnyShapeStyle(Color.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(.white.opacity(done ? 0 : 0.12), lineWidth: 1))
                .frame(width: 26, height: 26)
            if done {
                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
            } else {
                Text("\(n)").font(.caption.bold()).foregroundStyle(Ink.text(0.7))
            }
        }
    }
}

/// A card row used for each onboarding step, with a subtle accent when active.
private struct StepCard<Content: View>: View {
    let done: Bool
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(done ? Ink.green.opacity(0.3) : .white.opacity(0.08), lineWidth: 1))
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
        StepCard(done: done) {
            ZStack {
                Circle().fill(done ? AnyShapeStyle(Ink.green) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(.white.opacity(done ? 0 : 0.12), lineWidth: 1))
                    .frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.caption.bold()).foregroundStyle(Ink.text(0.7))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.callout).foregroundStyle(Ink.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Ink.green).font(.title2)
            } else {
                SoftButton(title: actionTitle, systemImage: "arrow.right", action: action)
            }
        }
    }
}
