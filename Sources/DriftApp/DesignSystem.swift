import SwiftUI

// MARK: - Palette

/// Drift's hand-tuned dark palette — an ink canvas with a cool aurora accent.
/// Hardcoded (not semantic) so the signature look is identical across windows.
enum Ink {
    static func text(_ o: Double) -> Color { .white.opacity(o) }

    static let bgTop = Color(red: 0.070, green: 0.072, blue: 0.090)
    static let bgBottom = Color(red: 0.032, green: 0.033, blue: 0.046)

    static let aCyan = Color(red: 0.42, green: 0.66, blue: 1.00)
    static let aIndigo = Color(red: 0.55, green: 0.49, blue: 1.00)
    static let aViolet = Color(red: 0.78, green: 0.49, blue: 1.00)

    static let accentSolid = aIndigo
    static let accentGlow = aIndigo
    static let accentGradient = LinearGradient(
        colors: [aCyan, aIndigo, aViolet],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let amber = Color(red: 1.00, green: 0.72, blue: 0.38)
    static let green = Color(red: 0.34, green: 0.86, blue: 0.58)
    static let red = Color(red: 1.00, green: 0.42, blue: 0.47)
}

// MARK: - Canvas

/// Layered ink background with a soft aurora glow that warms while recording.
struct InkCanvas: View {
    var active: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Ink.bgTop, Ink.bgBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Ink.accentGlow.opacity(active ? 0.36 : 0.18), .clear],
                center: .top, startRadius: 0, endRadius: 760
            )
            RadialGradient(
                colors: [Ink.aCyan.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 620
            )
        }
        .animation(.smooth(duration: 0.7), value: active)
    }
}

// MARK: - Panels

/// A glass panel with a subtle fill, a top-lit hairline border, and depth.
struct GlassPanel: ViewModifier {
    var corner: CGFloat = 18
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.white.opacity(0.045))
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
                    .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
            )
    }
}

extension View {
    func glassPanel(corner: CGFloat = 18, padding: CGFloat = 16) -> some View {
        modifier(GlassPanel(corner: corner, padding: padding))
    }
}

/// Standard card container with consistent stacking and padding.
struct Card<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(corner: 18, padding: 16)
    }
}

// MARK: - Labels & buttons

struct SectionLabel: View {
    let title: String
    let systemImage: String
    init(_ title: String, systemImage: String) { self.title = title; self.systemImage = systemImage }
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Ink.accentSolid)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(1.1)
                .foregroundStyle(Ink.text(0.5))
        }
    }
}

struct SoftButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    var prominent: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(stroke, lineWidth: 1))
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private var fill: AnyShapeStyle {
        if prominent { return AnyShapeStyle(Ink.accentGradient.opacity(hovering ? 1 : 0.9)) }
        if role == .destructive { return AnyShapeStyle(Ink.red.opacity(hovering ? 0.18 : 0.1)) }
        return AnyShapeStyle(Color.white.opacity(hovering ? 0.12 : 0.06))
    }
    private var stroke: Color {
        if prominent { return .white.opacity(0.2) }
        if role == .destructive { return Ink.red.opacity(hovering ? 0.5 : 0.25) }
        return .white.opacity(hovering ? 0.22 : 0.1)
    }
    private var foreground: Color {
        if prominent { return .white }
        return role == .destructive ? Ink.red : Ink.text(0.9)
    }
}

/// A keyboard-key chip, e.g. for the push-to-talk key.
struct Keycap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.09)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .foregroundStyle(Ink.text(0.85))
    }
}

// MARK: - Aura orb

struct AuraOrb: View {
    var diameter: CGFloat = 56
    let recording: Bool
    let busy: Bool
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Ink.accentGlow)
                .frame(width: diameter, height: diameter)
                .blur(radius: diameter * 0.42)
                .opacity(breathe ? (recording ? 0.95 : 0.5) : (recording ? 0.7 : 0.32))

            if recording {
                PulseRing(diameter: diameter, delay: 0)
                PulseRing(diameter: diameter, delay: 0.6)
            }

            Circle()
                .fill(Ink.accentGradient)
                .overlay(
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .frame(width: diameter, height: diameter)

            if busy { BusyArc(diameter: diameter) }

            Image(systemName: "waveform")
                .font(.system(size: diameter * 0.41, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: recording)
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

struct PulseRing: View {
    var diameter: CGFloat = 56
    let delay: Double
    @State private var animate = false
    var body: some View {
        Circle()
            .strokeBorder(Ink.accentGlow.opacity(0.6), lineWidth: 2)
            .frame(width: diameter, height: diameter)
            .scaleEffect(animate ? 1.7 : 0.95)
            .opacity(animate ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false).delay(delay)) {
                    animate = true
                }
            }
    }
}

struct BusyArc: View {
    var diameter: CGFloat = 52
    @State private var spin = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: max(2, diameter * 0.045), lineCap: .round))
            .frame(width: diameter * 0.92, height: diameter * 0.92)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spin = true }
            }
    }
}

// MARK: - Live waveform

/// A continuously animated voice waveform. Energetic while `active`, a calm
/// breathing line otherwise. Synthetic (not tied to mic levels) but lively.
struct LiveWaveform: View {
    var active: Bool
    var barCount: Int = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let h = geo.size.height
                // Size bars to the frame so they always fill it edge to edge.
                let spacing = geo.size.width / CGFloat(barCount) * 0.42
                let barWidth = (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
                HStack(spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        Capsule()
                            .fill(Ink.accentGradient)
                            .frame(width: barWidth, height: barHeight(i, t: t, maxH: h))
                            .opacity(active ? 1 : 0.7)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func barHeight(_ i: Int, t: Double, maxH: CGFloat) -> CGFloat {
        // Bell envelope so the centre bars are tallest, edges shortest.
        let envelope = sin(Double(i) / Double(barCount - 1) * .pi)
        let speed = active ? 7.0 : 2.2
        let amp = active ? 1.0 : 0.28
        let wobble = 0.5 + 0.5 * sin(t * speed + Double(i) * 0.55)
        let secondary = 0.5 + 0.5 * sin(t * speed * 0.6 + Double(i) * 0.9)
        let value = envelope * amp * (0.55 * wobble + 0.45 * secondary)
        return max(2.5, CGFloat(value) * maxH)
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let text: String
    let color: Color
    let pulsing: Bool
    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                if pulsing { PulseDot(color: color) }
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(text).font(.caption.weight(.semibold)).contentTransition(.opacity).id(text)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(color.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        .foregroundStyle(color)
    }
}

struct PulseDot: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle().fill(color.opacity(0.6)).frame(width: 8, height: 8)
            .scaleEffect(animate ? 2.4 : 1).opacity(animate ? 0 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { animate = true }
            }
    }
}
