import Foundation

/// How dictated text should be shaped for a given destination app.
public enum FormattingStyle: Sendable, Equatable {
    case standard   // sentence case + punctuation (the default everywhere)
    case casual     // chat tone; drop the trailing period
    case formal     // same mechanics as standard; tone differs for LLM cleanup
    case code       // verbatim — never edited, never sent to a cloud provider
}

/// A named formatting profile. `style` drives deterministic, on-device behavior;
/// `tone` is an extra instruction handed to LLM cleanup providers (ignored by the
/// on-device cleaner).
public struct FormattingProfile: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let style: FormattingStyle
    public let tone: String?
    public let symbol: String   // SF Symbol name, for the UI
    public let blurb: String

    public static let standard = FormattingProfile(
        id: "standard", name: "Standard", style: .standard, tone: nil,
        symbol: "text.alignleft", blurb: "Clean sentences and punctuation."
    )
    public static let casual = FormattingProfile(
        id: "casual", name: "Casual", style: .casual,
        tone: "Write in a casual, conversational tone like a chat message, and do not end with a period.",
        symbol: "bubble.left.and.bubble.right", blurb: "Chat tone, no trailing period."
    )
    public static let formal = FormattingProfile(
        id: "formal", name: "Formal", style: .formal,
        tone: "Use a polished, professional tone suitable for an email.",
        symbol: "envelope", blurb: "Polished, email-ready tone."
    )
    public static let code = FormattingProfile(
        id: "code", name: "Code", style: .code, tone: nil,
        symbol: "chevron.left.forwardslash.chevron.right", blurb: "Verbatim — no edits, stays on device."
    )

    public static let all: [FormattingProfile] = [standard, casual, formal, code]

    public static func with(id: String) -> FormattingProfile {
        all.first { $0.id == id } ?? .standard
    }
}

/// Resolves which `FormattingProfile` applies to a destination app, combining
/// user overrides with sensible built-in defaults.
public enum FormattingProfiles {
    /// Default app → profile mapping, keyed by bundle identifier.
    public static let builtInRules: [String: String] = [
        // Chat
        "com.tinyspeck.slackmacgap": "casual",
        "com.apple.MobileSMS": "casual",
        "com.hnc.Discord": "casual",
        "net.whatsapp.WhatsApp": "casual",
        "ru.keepcoder.Telegram": "casual",
        // Email
        "com.apple.mail": "formal",
        "com.microsoft.Outlook": "formal",
        "com.readdle.smartemail-Mac": "formal",
        // Code / terminals
        "com.apple.dt.Xcode": "code",
        "com.microsoft.VSCode": "code",
        "com.todesktop.230313mzl4w4u92": "code", // Cursor
        "com.apple.Terminal": "code",
        "com.googlecode.iterm2": "code",
        "dev.warp.Warp-Stable": "code",
    ]

    /// The active profile for a destination app: user override → built-in default
    /// → the user's chosen default. Returns the user default when the feature is
    /// off or no app is known.
    public static func resolve(bundleID: String?, settings: Settings) -> FormattingProfile {
        guard settings.perAppProfilesEnabled, let bundleID, !bundleID.isEmpty else {
            return .with(id: settings.defaultProfileID)
        }
        return .with(id: effectiveProfileID(bundleID: bundleID, settings: settings))
    }

    /// The configured profile id for an app, ignoring the master toggle. Used by
    /// the UI to show/edit the per-app choice.
    public static func effectiveProfileID(bundleID: String, settings: Settings) -> String {
        settings.profileOverrides[bundleID] ?? builtInRules[bundleID] ?? settings.defaultProfileID
    }

    /// Casual style drops a single trailing period (texting style), while keeping
    /// "?", "!", and ellipses intact.
    public static func applyCasualTrim(_ s: String) -> String {
        guard s.hasSuffix("."), !s.hasSuffix("..") else { return s }
        return String(s.dropLast())
    }
}
