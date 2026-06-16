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

/// Animated equalizer bars indicating the mic is live.
final class BarsView: NSView {
    private var phase: CGFloat = 0
    private var timer: Timer?
    private let count = 5
    /// When false, bars animate gently (e.g. while transcribing).
    var active = true

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.phase += 0.35
            self?.needsDisplay = true
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let barWidth: CGFloat = 4
        let gap = (bounds.width - CGFloat(count) * barWidth) / CGFloat(count - 1)
        NSColor.white.setFill()
        let amp: CGFloat = active ? 1.0 : 0.35
        for i in 0..<count {
            let x = CGFloat(i) * (barWidth + gap)
            let s = abs(sin(phase + CGFloat(i) * 0.7))
            let h = max(4, (4 + s * (bounds.height - 4)) * amp)
            let y = (bounds.height - h) / 2
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: h),
                         xRadius: 2, yRadius: 2).fill()
        }
    }
}
