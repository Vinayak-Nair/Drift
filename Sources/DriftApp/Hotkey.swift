import AppKit
// Note: on the interim-whisper-cpp branch everything compiles as one swiftc
// module, so DriftKit types (Settings) are visible without an import. On main,
// this file imports DriftKit.

/// Listens system-wide for the push-to-talk key and reports press/release.
/// Defaults to a modifier key (Right Option) but also supports normal keys.
/// Requires Accessibility permission for the event tap.
final class Hotkey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false

    /// Modifier keycodes mapped to their CGEventFlags bit.
    private static let modifierFlags: [Int: CGEventFlags] = [
        61: .maskAlternate, 58: .maskAlternate, // right/left option
        54: .maskCommand, 55: .maskCommand,     // right/left command
        60: .maskShift, 56: .maskShift,         // right/left shift
        62: .maskControl, 59: .maskControl,     // right/left control
    ]

    func start() {
        guard eventTap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.keyUp.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(refcon).takeUnretainedValue()
            hotkey.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: selfPtr
        ) else {
            NSLog("Drift: could not create event tap (needs Accessibility permission)")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let ptt = Settings.shared.pttKeyCode

        if let flag = Self.modifierFlags[ptt] {
            guard type == .flagsChanged, keyCode == ptt else { return }
            setHeld(event.flags.contains(flag))
        } else {
            guard keyCode == ptt else { return }
            if type == .keyDown { setHeld(true) }
            else if type == .keyUp { setHeld(false) }
        }
    }

    private func setHeld(_ held: Bool) {
        guard held != isHeld else { return } // dedupe auto-repeat / flag noise
        isHeld = held
        DispatchQueue.main.async { [weak self] in
            if held { self?.onPress() } else { self?.onRelease() }
        }
    }
}
