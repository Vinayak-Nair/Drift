import SwiftUI

/// Floating, click-through HUD shown while dictation is active. Indicates that
/// Drift is listening (and shows live partial text for streaming engines) and
/// that it's transcribing after release.
struct LiveOverlayView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.status {
            case .recording:
                listening
            case .transcribing:
                transcribing
            default:
                EmptyView()
            }
        }
        .animation(.easeOut(duration: 0.12), value: state.livePartialText)
    }

    private var listening: some View {
        card {
            VStack(alignment: .leading, spacing: state.livePartialText.isEmpty ? 0 : 8) {
                HStack(spacing: 7) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Listening…")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if !state.livePartialText.isEmpty {
                    Text(state.livePartialText)
                        .font(.title3.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    private var transcribing: some View {
        card {
            HStack(spacing: 9) {
                ProgressView().controlSize(.small)
                Text("Transcribing…")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(width: 560, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
            .padding(8)
    }
}
