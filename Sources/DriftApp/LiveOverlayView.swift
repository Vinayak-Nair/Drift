import SwiftUI

/// Floating, click-through HUD shown while dictation is active. A compact pill
/// that hugs its content: just a waveform while listening, growing to show the
/// live partial transcript for streaming engines, then a transcribing state.
struct LiveOverlayView: View {
    @EnvironmentObject var state: AppState

    private var hasText: Bool { !state.livePartialText.isEmpty }

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
        // Fill the transparent panel and float the pill in its centre so it stays
        // anchored on screen no matter how the content resizes.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.16), value: state.livePartialText)
        .animation(.smooth(duration: 0.24), value: state.status)
    }

    private var listening: some View {
        card(expanded: hasText) {
            if hasText {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    Text(state.livePartialText)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 440, alignment: .leading)
                }
            } else {
                header
            }
        }
    }

    /// Brand mark for the active state: the live waveform plus a quiet label.
    private var header: some View {
        HStack(spacing: 10) {
            LiveWaveform(active: true)
                .frame(width: 52, height: 16)
            Text("Listening…")
                .font(.callout.weight(.medium))
                .foregroundStyle(Ink.text(0.55))
        }
    }

    private var transcribing: some View {
        card(expanded: false) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Transcribing…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Ink.text(0.55))
            }
        }
    }

    /// A content-hugging glass pill. Reads as a capsule when compact and a soft
    /// card once it grows, sharing the house glass treatment from the rest of
    /// the app. One quiet shadow, no accent glow.
    private func card<Content: View>(expanded: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        let corner: CGFloat = 22
        return content()
            .padding(.horizontal, 20)
            .padding(.vertical, expanded ? 15 : 11)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Ink.bgTop.opacity(0.7))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 18, y: 6)
            .preferredColorScheme(.dark)
    }
}
