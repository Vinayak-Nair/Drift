import SwiftUI
import DriftKit

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var appeared = false
    @State private var query = ""

    var body: some View {
        let stats = DashboardStats(state.transcriptHistory)

        return VStack(spacing: 0) {
            header(stats)
                .padding(.horizontal, 26)
                .padding(.top, 30)
                .padding(.bottom, 20)

            hairline.frame(height: 1)

            statsBand(stats)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            hairline.frame(height: 1)

            HStack(spacing: 0) {
                transcriptPanel
                    .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)

                hairline.frame(width: 1)

                sidebar
                    .frame(width: 286)
                    .frame(maxHeight: .infinity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .frame(minWidth: 880, minHeight: 640)
        .background(DashboardBackground(recording: state.isRecordingStatus).ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: state.status)
        .onAppear {
            withAnimation(.smooth(duration: 0.5)) { appeared = true }
        }
    }

    private var hairline: some View {
        Rectangle().fill(Color.primary.opacity(0.07))
    }

    // MARK: Hero

    private func header(_ stats: DashboardStats) -> some View {
        HStack(spacing: 16) {
            StatusOrb(recording: state.isRecordingStatus, busy: state.isBusyStatus)

            VStack(alignment: .leading, spacing: 4) {
                Text("Drift")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .tracking(0.2)

                Text(state.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .id(state.statusText)
            }

            Spacer(minLength: 12)

            if stats.streak >= 1 {
                StreakPill(days: stats.streak)
                    .transition(.scale.combined(with: .opacity))
            }

            StatusBadge(
                text: state.statusBadgeText,
                color: state.statusBadgeColor,
                pulsing: state.isRecordingStatus
            )
        }
    }

    // MARK: KPI band

    private func statsBand(_ stats: DashboardStats) -> some View {
        let spoken = stats.words < 150
            ? "≈ under a min"
            : "≈ \(Int((Double(stats.words) / 150).rounded())) min spoken"

        return HStack(spacing: 12) {
            StatTile(
                label: "Dictations",
                value: stats.total.formatted(),
                caption: stats.today == 0 ? "none today" : "\(stats.today) today",
                trend: TrendValue(now: stats.week, prior: stats.priorWeek)
            )
            StatTile(
                label: "Words",
                value: stats.words.formatted(),
                caption: spoken,
                emphasis: true,
                trend: TrendValue(now: stats.weekWords, prior: stats.priorWeekWords)
            )
            StatTile(
                label: "Avg length",
                value: "\(stats.avg)",
                caption: "words per take"
            )
            ActivityTile(week: stats.week, daily: stats.daily)
        }
    }

    // MARK: Transcript panel

    private var filtered: [TranscriptEntry] {
        guard !query.isEmpty else { return state.transcriptHistory }
        let q = query.lowercased()
        return state.transcriptHistory.filter {
            $0.text.lowercased().contains(q) || $0.microphoneName.lowercased().contains(q)
        }
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcript History")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    Text(historySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                if !state.transcriptHistory.isEmpty {
                    SearchField(text: $query)
                        .frame(maxWidth: 200)
                }

                SoftButton(
                    title: "Clear",
                    systemImage: "trash",
                    role: .destructive,
                    action: { withAnimation(.smooth) { state.clearTranscriptHistory() } }
                )
                .disabled(state.transcriptHistory.isEmpty)
                .opacity(state.transcriptHistory.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            if state.transcriptHistory.isEmpty {
                emptyHistory
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else if filtered.isEmpty {
                noMatches
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(DashboardStats.group(filtered).enumerated()), id: \.element.title) { index, section in
                            DateHeader(title: section.title, count: section.entries.count)
                                .padding(.top, index == 0 ? 0 : 8)

                            ForEach(section.entries) { entry in
                                TranscriptRow(entry: entry, highlight: query) {
                                    state.copyTranscript(entry)
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: -8)),
                                    removal: .opacity
                                ))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                    .animation(.smooth(duration: 0.4), value: state.transcriptHistory)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var historySubtitle: String {
        if !query.isEmpty {
            let n = filtered.count
            return n == 1 ? "1 match" : "\(n) matches"
        }
        let count = state.transcriptHistory.count
        if count == 0 { return "Nothing captured yet" }
        return count == 1 ? "1 dictation · newest first" : "\(count) dictations · newest first"
    }

    private var emptyHistory: some View {
        VStack(spacing: 14) {
            iconMedallion("waveform")
            VStack(spacing: 6) {
                Text("No transcripts yet")
                    .font(.system(.headline, design: .rounded))
                Text("Hold your push-to-talk key and speak — finished dictations land here with their time and microphone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .lineSpacing(2)
            }
        }
        .padding(28)
    }

    private var noMatches: some View {
        VStack(spacing: 14) {
            iconMedallion("text.magnifyingglass")
            VStack(spacing: 6) {
                Text("No matches")
                    .font(.system(.headline, design: .rounded))
                Text("Nothing in your history matches “\(query)”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Clear search") { query = "" }
                    .buttonStyle(.link)
                    .padding(.top, 2)
            }
        }
        .padding(28)
    }

    private func iconMedallion(_ symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 76, height: 76)
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    SectionLabel("Input", systemImage: "mic.fill")

                    Picker("Microphone", selection: Binding(
                        get: { state.selectedMicrophoneID },
                        set: { state.selectMicrophone($0) }
                    )) {
                        ForEach(state.availableMicrophones) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    DetailLine(icon: "waveform", title: "Active input", value: state.selectedMicrophoneName)

                    HStack(spacing: 8) {
                        SoftButton(title: "Refresh", systemImage: "arrow.clockwise") {
                            withAnimation(.smooth) { state.refreshSelectedMicrophone() }
                        }
                        SoftButton(title: "Sound", systemImage: "speaker.wave.2") {
                            state.openSoundSettings()
                        }
                    }
                }

                GlassCard {
                    SectionLabel("Model", systemImage: "cpu")

                    Picker("Model", selection: Binding(
                        get: { state.selectedDictationModelID },
                        set: { state.selectDictationModel($0) }
                    )) {
                        ForEach(state.dictationModelOptions) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    if state.transcriptionBackend == .whisperKit {
                        Picker("Language", selection: $state.languageCode) {
                            ForEach(Language.all) { lang in
                                Text(lang.displayName).tag(lang.code)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    } else {
                        DetailLine(icon: "globe", title: "Language", value: state.languageDisplayName)
                    }

                    DetailLine(icon: "wand.and.stars", title: "Cleanup", value: state.cleanupProviderDisplayName)

                    if state.status == .loadingModel || state.isDownloading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(state.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                        .transition(.opacity)
                    }
                }

                GlassCard {
                    HStack {
                        SectionLabel("Formatting", systemImage: "wand.and.stars")
                        Spacer()
                        Toggle("", isOn: $state.perAppProfilesEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    if state.perAppProfilesEnabled {
                        Text("Drift matches its style to the app you dictate into.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        DefaultProfileRow(selection: $state.defaultProfileID)

                        if !state.recentTargetApps.isEmpty {
                            Divider().padding(.vertical, 1)
                            ForEach(state.recentTargetApps.prefix(6)) { app in
                                AppProfileRow(app: app)
                            }
                        }

                        SoftButton(title: "Add app…", systemImage: "plus") {
                            state.addApp()
                        }
                        .padding(.top, 2)
                    } else {
                        Text("Turn on to auto-switch style per app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.smooth(duration: 0.25), value: state.perAppProfilesEnabled)
                .animation(.smooth(duration: 0.25), value: state.recentTargetApps)

                GlassCard {
                    HStack {
                        SectionLabel("Commands", systemImage: "command")
                        Spacer()
                        Toggle("", isOn: $state.commandModeEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    Text(state.commandModeEnabled
                         ? "Speak formatting and edits instead of typing them."
                         : "Turn on to speak punctuation, line breaks, and edits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if state.commandModeEnabled {
                        VStack(spacing: 5) {
                            ForEach(CommandProcessor.reference, id: \.spoken) { cmd in
                                HStack(spacing: 8) {
                                    Text("“\(cmd.spoken)”")
                                        .font(.caption2.weight(.medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(cmd.effect)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.25), value: state.commandModeEnabled)

                GlassCard {
                    SectionLabel("Worth Adding Next", systemImage: "sparkles")

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Self.ideas, id: \.self) { IdeaChip($0) }
                    }
                }
            }
            .padding(18)
        }
        .scrollContentBackground(.hidden)
        .background(Color.primary.opacity(0.02))
    }

    private static let ideas = [
        "Tone presets", "Language picker", "Personal dictionary",
        "Snippets", "Quick notes", "Retry history"
    ]
}

// MARK: - Derived stats

private struct DashboardStats {
    var total = 0
    var words = 0
    var today = 0
    var week = 0
    var priorWeek = 0
    var weekWords = 0
    var priorWeekWords = 0
    var avg = 0
    var streak = 0
    var daily = Array(repeating: 0, count: 7)

    init(_ entries: [TranscriptEntry]) {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        total = entries.count
        var activeDays = Set<Date>()

        for e in entries {
            let w = e.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            words += w
            if cal.isDateInToday(e.createdAt) { today += 1 }

            let dayStart = cal.startOfDay(for: e.createdAt)
            activeDays.insert(dayStart)
            let diff = cal.dateComponents([.day], from: dayStart, to: todayStart).day ?? 99
            if diff >= 0, diff < 7 {
                daily[6 - diff] += 1
                week += 1
                weekWords += w
            } else if diff >= 7, diff < 14 {
                priorWeek += 1
                priorWeekWords += w
            }
        }

        avg = total == 0 ? 0 : Int((Double(words) / Double(total)).rounded())

        // Consecutive active days ending today (or yesterday, if today is empty).
        var probe = activeDays.contains(todayStart)
            ? todayStart
            : cal.date(byAdding: .day, value: -1, to: todayStart)!
        while activeDays.contains(probe) {
            streak += 1
            probe = cal.date(byAdding: .day, value: -1, to: probe)!
        }
    }

    struct Section { let title: String; let entries: [TranscriptEntry] }

    /// Splits newest-first entries into Today / Yesterday / Earlier groups,
    /// preserving order and dropping empty sections.
    static func group(_ entries: [TranscriptEntry]) -> [Section] {
        let cal = Calendar.current
        var today: [TranscriptEntry] = []
        var yesterday: [TranscriptEntry] = []
        var earlier: [TranscriptEntry] = []
        for e in entries {
            if cal.isDateInToday(e.createdAt) { today.append(e) }
            else if cal.isDateInYesterday(e.createdAt) { yesterday.append(e) }
            else { earlier.append(e) }
        }
        var out: [Section] = []
        if !today.isEmpty { out.append(Section(title: "Today", entries: today)) }
        if !yesterday.isEmpty { out.append(Section(title: "Yesterday", entries: yesterday)) }
        if !earlier.isEmpty { out.append(Section(title: "Earlier", entries: earlier)) }
        return out
    }
}

private struct TrendValue {
    let now: Int
    let prior: Int

    var pct: Int? {
        guard prior > 0 else { return nil }
        return Int(((Double(now) - Double(prior)) / Double(prior) * 100).rounded())
    }
    var isNew: Bool { prior == 0 && now > 0 }
    var hasValue: Bool { pct != nil || isNew }
}

// MARK: - Backdrop

/// Layered, depth-giving window background: a faint vertical wash plus a soft
/// accent glow in the top-leading corner that warms up while recording.
private struct DashboardBackground: View {
    let recording: Bool

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [Color.accentColor.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [Color.accentColor.opacity(recording ? 0.20 : 0.09), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
        }
        .animation(.smooth(duration: 0.6), value: recording)
    }
}

// MARK: - Status orb

/// The hero glyph: a gradient orb whose waveform animates while recording and
/// gains an indeterminate sweep while the model loads or transcribes.
private struct StatusOrb: View {
    let recording: Bool
    let busy: Bool

    var body: some View {
        ZStack {
            if recording {
                PulseRing(delay: 0)
                PulseRing(delay: 0.6)
            }

            Circle()
                .fill(Palette.accentGradient)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: Color.accentColor.opacity(0.45), radius: 12, y: 4)

            if busy {
                BusyArc()
            }

            Image(systemName: "waveform")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: recording)
        }
        .frame(width: 54, height: 54)
    }
}

/// An expanding, fading ring used as a "listening" pulse around the orb.
private struct PulseRing: View {
    let delay: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(Color.accentColor.opacity(0.55), lineWidth: 2)
            .frame(width: 54, height: 54)
            .scaleEffect(animate ? 1.7 : 0.95)
            .opacity(animate ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false).delay(delay)) {
                    animate = true
                }
            }
    }
}

/// A thin rotating arc overlaid on the orb to signal indeterminate work.
private struct BusyArc: View {
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
    }
}

// MARK: - Streak pill

private struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(days)-day streak")
                .font(.caption.weight(.semibold))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(Color.orange.opacity(0.24), lineWidth: 1))
        .foregroundStyle(.orange)
        .help("\(days) consecutive day\(days == 1 ? "" : "s") with a dictation")
    }
}

// MARK: - Stat tiles

private struct StatTile: View {
    let label: String
    let value: String
    let caption: String
    var emphasis: Bool = false
    var trend: TrendValue? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(emphasis ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.primary))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let trend, trend.hasValue {
                    Spacer(minLength: 2)
                    TrendChip(trend: trend)
                }
            }

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .cardSurface()
    }
}

private struct TrendChip: View {
    let trend: TrendValue

    var body: some View {
        Group {
            if let pct = trend.pct {
                let up = pct > 0
                let down = pct < 0
                chip(
                    symbol: up ? "arrow.up.right" : (down ? "arrow.down.right" : "minus"),
                    text: "\(abs(pct))%",
                    color: up ? .green : (down ? .red : .secondary)
                )
            } else if trend.isNew {
                chip(symbol: "sparkle", text: "new", color: .accentColor)
            }
        }
        .help("vs. previous 7 days")
    }

    private func chip(symbol: String, text: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 8, weight: .bold))
            Text(text).font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }
}

/// A stat tile whose visual is a 7-day activity sparkline.
private struct ActivityTile: View {
    let week: Int
    let daily: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(week)")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text("dictations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            MiniBars(values: daily)
                .frame(height: 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .cardSurface()
    }
}

/// Hand-rolled 7-bar activity chart with a grow-in animation. Each day gets an
/// equal-width column with a narrow, bottom-anchored bar so it reads as a true
/// vertical sparkline rather than a row of dashes.
private struct MiniBars: View {
    let values: [Int]
    @State private var grow = false

    var body: some View {
        let peak = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(values.indices, id: \.self) { i in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(values[i] == 0 ? AnyShapeStyle(Color.primary.opacity(0.12)) : AnyShapeStyle(Palette.accentGradient))
                        .frame(width: 6, height: grow ? barHeight(values[i], peak) : 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.12)) { grow = true }
        }
    }

    private func barHeight(_ value: Int, _ peak: Int) -> CGFloat {
        guard value > 0 else { return 4 }
        return max(5, CGFloat(value) / CGFloat(peak) * 26)
    }
}

// MARK: - Reusable chrome

/// Adaptive surface tokens so cards read as *floating* (lighter than the window)
/// in dark mode and crisp white in light mode.
private extension ColorScheme {
    var surfaceFill: Color { self == .dark ? Color(white: 0.19) : Color(nsColor: .controlBackgroundColor) }
    var surfaceStroke: Color { self == .dark ? Color.white.opacity(0.10) : Color.primary.opacity(0.07) }
    var surfaceShadow: Double { self == .dark ? 0.45 : 0.05 }
    var surfaceShadowRadius: CGFloat { self == .dark ? 13 : 10 }
}

/// A clean, elevated card surface: adaptive fill, hairline border, soft shadow,
/// and a faint top highlight to sell the elevation in dark mode.
private struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(scheme.surfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(scheme.surfaceStroke, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.06), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(scheme.surfaceShadow), radius: scheme.surfaceShadowRadius, y: 3)
    }
}

private extension View {
    func cardSurface(_ radius: CGFloat = 14) -> some View { modifier(CardSurface(radius: radius)) }
}

/// A control panel container with consistent padding and stacking.
private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface()
    }
}

/// Small uppercase section heading with an accent glyph.
private struct SectionLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(.secondary)
        }
    }
}

/// Inline date-group header for the transcript list.
private struct DateHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            Spacer()
        }
    }
}

/// A rounded search field used to filter transcript history.
private struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search transcripts", text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .overlay(
            Capsule().stroke(focused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.10), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// A bordered, hover-aware button used across the dashboard.
private struct SoftButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(hovering ? 0.18 : 0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(hovering ? 0.45 : 0.18), lineWidth: 1)
                )
                .foregroundStyle(role == .destructive ? Color.red : Color.primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private var tint: Color { role == .destructive ? .red : .primary }
}

// MARK: - Transcript row

private struct TranscriptRow: View {
    let entry: TranscriptEntry
    var highlight: String = ""
    let copy: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false
    @State private var justCopied = false

    private var wordCount: Int {
        entry.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.createdAt.formatted(.relative(presentation: .named)))
                    .font(.subheadline.weight(.semibold))
                    .help(entry.createdAt.formatted(.dateTime.month(.wide).day().year().hour().minute()))

                Spacer(minLength: 8)

                Text("\(wordCount) words")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))

                Button(action: triggerCopy) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(justCopied ? Color.green : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(hovering ? 0.06 : 0)))
                }
                .buttonStyle(.plain)
                .help("Copy transcript")
                .opacity(justCopied || hovering ? 1 : 0.35)
            }

            highlightedText
                .font(.body)
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(entry.microphoneName)
                    .lineLimit(1)
                Text("·").foregroundStyle(.tertiary)
                Text(Language.from(code: entry.languageCode).displayName)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hovering ? Color.accentColor.opacity(0.40) : scheme.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(hovering ? scheme.surfaceShadow + 0.05 : scheme.surfaceShadow * 0.8),
                radius: hovering ? scheme.surfaceShadowRadius : 4, y: hovering ? 3 : 2)
        .offset(y: hovering ? -1 : 0)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
        .animation(.snappy(duration: 0.25), value: justCopied)
    }

    /// Renders the transcript, bolding the active search term where it occurs.
    private var highlightedText: Text {
        guard !highlight.isEmpty,
              let range = entry.text.range(of: highlight, options: .caseInsensitive) else {
            return Text(entry.text)
        }
        let pre = String(entry.text[..<range.lowerBound])
        let match = String(entry.text[range])
        let post = String(entry.text[range.upperBound...])
        return Text(pre)
            + Text(match).foregroundColor(.accentColor).bold()
            + Text(post)
    }

    private func triggerCopy() {
        copy()
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            justCopied = false
        }
    }
}

// MARK: - Detail / idea rows

private struct DetailLine: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A compact profile picker over the four formatting profiles.
private struct ProfileMenu: View {
    @Binding var selection: String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(FormattingProfile.all) { profile in
                Text(profile.name).tag(profile.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .fixedSize()
    }
}

/// The user-selected default profile, applied to any app without its own rule.
private struct DefaultProfileRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "asterisk.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
            Text("Default")
                .font(.caption.weight(.medium))
            Spacer(minLength: 4)
            ProfileMenu(selection: $selection)
        }
    }
}

/// A configured destination app with a live profile picker and a remove control.
private struct AppProfileRow: View {
    @EnvironmentObject var state: AppState
    let app: TargetApp
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(app.name)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            ProfileMenu(selection: Binding(
                get: { state.profileID(forBundleID: app.bundleID) },
                set: { state.setProfile($0, forBundleID: app.bundleID) }
            ))

            Button { state.removeApp(app) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remove this rule")
            .opacity(hovering ? 1 : 0)
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    @ViewBuilder private var icon: some View {
        if let nsIcon = state.appIcon(forBundleID: app.bundleID) {
            Image(nsImage: nsIcon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
    }
}

private struct IdeaChip: View {
    let title: String
    @State private var hovering = false

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 5, height: 5)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Status badge

private struct StatusBadge: View {
    let text: String
    let color: Color
    let pulsing: Bool

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                if pulsing {
                    PulseDot(color: color)
                }
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .contentTransition(.opacity)
                .id(text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
        .foregroundStyle(color)
    }
}

/// An expanding ring behind the badge dot used to convey live recording.
private struct PulseDot: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.6))
            .frame(width: 8, height: 8)
            .scaleEffect(animate ? 2.4 : 1)
            .opacity(animate ? 0 : 0.6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

// MARK: - Palette

private enum Palette {
    static let accentGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Status helpers

private extension AppState {
    var isDownloading: Bool {
        if case .downloadingModel = status { return true }
        return false
    }

    var isRecordingStatus: Bool {
        if case .recording = status { return true }
        return false
    }

    var isBusyStatus: Bool {
        switch status {
        case .transcribing, .loadingModel, .downloadingModel: return true
        default: return false
        }
    }

    var statusBadgeText: String {
        switch status {
        case .needsSetup: return "Setup"
        case .loadingModel, .downloadingModel: return "Loading"
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .transcribing: return "Processing"
        case .error: return "Error"
        }
    }

    var statusBadgeColor: Color {
        switch status {
        case .idle: return .green
        case .recording: return .red
        case .transcribing, .loadingModel, .downloadingModel: return .orange
        case .needsSetup: return .yellow
        case .error: return .red
        }
    }
}
