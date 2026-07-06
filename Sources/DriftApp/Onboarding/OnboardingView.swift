import SwiftUI
import DriftKit

/// First-run setup: microphone, accessibility, and the model download. Designed so
/// the user never needs the Terminal or any separate install.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// Onboarding is two pages: permission setup, then a one-time "quick wins"
    /// step. After this the same options live only in the dashboard's Settings.
    @State private var showQuickWins = false

    private var downloadFraction: Double? {
        if case .downloadingModel(let p) = state.status { return p }
        return nil
    }

    private var modelDownloaded: Bool { state.isSelectedModelDownloaded() }

    var body: some View {
        ZStack {
            if showQuickWins {
                quickWinsContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity))
            } else {
                setupContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .opacity))
            }
        }
        .frame(width: 520, height: 620)
        .background(InkCanvas().ignoresSafeArea())
        .tint(Ink.accentSolid)
        .preferredColorScheme(.dark)
        .animation(.snappy(duration: 0.3), value: showQuickWins)
        .onReceive(permissionTimer) { _ in state.refreshPermissions() }
    }

    // MARK: Page 1 — permission setup

    private var setupContent: some View {
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
                SoftButton(title: "Continue", systemImage: "arrow.right", prominent: true) {
                    withAnimation(.snappy(duration: 0.3)) { showQuickWins = true }
                }
                .disabled(!state.allPermissionsAndModelReady)
                .opacity(state.allPermissionsAndModelReady ? 1 : 0.5)
            }
        }
        .padding(28)
    }

    // MARK: Page 2 — quick wins (first-run only)

    private var quickWinsContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle().fill(Ink.green.opacity(0.16)).frame(width: 60, height: 60)
                    Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(Ink.green)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("You're all set")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A few quick wins to dictate faster. Turn these on now, or find them later in Settings.")
                        .font(.callout)
                        .foregroundStyle(Ink.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                TipRow(icon: "command", title: "Speak punctuation and edits, hands-free",
                       subtitle: "Say “new line”, “period”, or “scratch that”.",
                       toggle: $state.commandModeEnabled)
                TipRow(icon: "wand.and.stars", title: "Match your writing to each app",
                       subtitle: "Drift adapts its style to the app you dictate into.",
                       toggle: $state.perAppProfilesEnabled)
                TipRow(icon: "cpu", title: "Pick the model that fits your voice",
                       subtitle: "Switch speech models anytime in Settings.")
            }

            Spacer(minLength: 0)

            HStack {
                Button("Back") { withAnimation(.snappy(duration: 0.3)) { showQuickWins = false } }
                    .buttonStyle(.plain).font(.callout).foregroundStyle(Ink.text(0.6))
                Spacer()
                SoftButton(title: "Start dictating", systemImage: "arrow.right", prominent: true) {
                    state.finishOnboarding()
                }
            }
        }
        .padding(28)
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

/// A recommended-setup row on the final onboarding page: an icon, a short pitch,
/// and an optional inline toggle. Rows without a toggle just point to Settings.
private struct TipRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var toggle: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Ink.accentSolid.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(Ink.accentSolid)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.caption).foregroundStyle(Ink.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let toggle {
                Toggle("", isOn: toggle).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
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
