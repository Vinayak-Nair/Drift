import AppKit

// INTERIM: a Wispr-style floating "listening" pill near the bottom of the screen.
// It's a non-activating panel so it never steals focus from the app you're
// dictating into (which would break paste). Appearance of the pill is the cue to
// start talking.
final class OverlayController {
    private let panel: NSPanel
    private let bars = BarsView()
    private let label = NSTextField(labelWithString: "Listening…")

    init() {
        let size = NSSize(width: 200, height: 52)
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 16
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]

        let mic = NSImageView(image: NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) ?? NSImage())
        mic.contentTintColor = .white
        mic.translatesAutoresizingMaskIntoConstraints = false

        bars.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.addSubview(bg)
        content.addSubview(mic)
        content.addSubview(bars)
        content.addSubview(label)
        panel.contentView = content

        NSLayoutConstraint.activate([
            mic.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            mic.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            mic.widthAnchor.constraint(equalToConstant: 16),
            mic.heightAnchor.constraint(equalToConstant: 16),

            bars.leadingAnchor.constraint(equalTo: mic.trailingAnchor, constant: 10),
            bars.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            bars.widthAnchor.constraint(equalToConstant: 56),
            bars.heightAnchor.constraint(equalToConstant: 22),

            label.leadingAnchor.constraint(equalTo: bars.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
    }

    func showListening() {
        label.stringValue = "Listening…"
        bars.active = true
        bars.start()
        positionBottomCenter()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func showTranscribing() {
        label.stringValue = "Transcribing…"
        bars.active = false // calmer animation while processing
    }

    /// Feed live mic level (0...1) so the bars react to the user's voice.
    func setLevel(_ level: CGFloat) {
        bars.setLevel(level)
    }

    func hide() {
        bars.stop()
        panel.orderOut(nil)
    }

    private func positionBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let x = f.midX - panel.frame.width / 2
        let y = f.minY + 110
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// Equalizer bars driven by the live mic level (peak-hold with decay), so they
/// rise with the user's voice and fall when quiet.
final class BarsView: NSView {
    private var phase: CGFloat = 0
    private var timer: Timer?
    private let count = 5
    private var heights: [CGFloat]
    private var targetLevel: CGFloat = 0
    /// true: react to live audio; false: gentle idle (e.g. while transcribing).
    var active = true

    override init(frame frameRect: NSRect) {
        heights = Array(repeating: 0.15, count: count)
        super.init(frame: frameRect)
    }
    required init?(coder: NSCoder) {
        heights = Array(repeating: 0.15, count: 5)
        super.init(coder: coder)
    }

    /// Live mic level in 0...1. Instant attack; the timer decays it for falloff.
    func setLevel(_ level: CGFloat) {
        targetLevel = max(targetLevel, min(1, level))
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.5
            self.targetLevel *= 0.86 // decay for a peak-hold meter feel
            for i in 0..<self.count {
                let variation = 0.55 + 0.45 * abs(sin(self.phase + CGFloat(i) * 0.9))
                let base = self.active ? self.targetLevel : 0.12
                let target = max(0.1, base * variation)
                self.heights[i] += (target - self.heights[i]) * 0.4 // smoothing
            }
            self.needsDisplay = true
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        targetLevel = 0
        heights = Array(repeating: 0.15, count: count)
    }

    override func draw(_ dirtyRect: NSRect) {
        let barWidth: CGFloat = 4
        let gap = (bounds.width - CGFloat(count) * barWidth) / CGFloat(count - 1)
        NSColor.white.setFill()
        for i in 0..<count {
            let x = CGFloat(i) * (barWidth + gap)
            let h = max(3, heights[i] * bounds.height)
            let y = (bounds.height - h) / 2
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: h),
                         xRadius: 2, yRadius: 2).fill()
        }
    }
}
