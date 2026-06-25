import SwiftUI
import DriftKit

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var appeared = false
    @State private var query = ""
    @State private var section: Section = .today

    enum Section: String, CaseIterable, Identifiable {
        case today = "Today", history = "History", apps = "Apps", settings = "Settings"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .today: return "checkmark"
            case .history: return "clock.arrow.circlepath"
            case .apps: return "square.grid.2x2.fill"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(GF.hairline).frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                sidebar
                ScrollView {
                    mainContent
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .opacity(appeared ? 1 : 0)
        .frame(minWidth: 940, minHeight: 720)
        .background(GF.pageBG.ignoresSafeArea())
        .tint(GF.accent)
        .preferredColorScheme(.light)
        .onAppear { withAnimation(.smooth(duration: 0.5)) { appeared = true } }
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            HStack(spacing: 7) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GF.accentGradient)
                Text("drift")
                    .font(.system(size: 21, weight: .bold, design: .rounded)).tracking(-0.3)
                    .foregroundStyle(GF.ink)
            }
            HStack {
                Spacer()
                StatusChip(text: state.statusBadgeText, color: state.statusBadgeColor, pulsing: state.isRecordingStatus)
            }
            .padding(.trailing, 24)
        }
        .frame(height: 60)
        .padding(.leading, 90) // clear the floating window controls
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Section.allCases) { s in
                SideItem(title: s.rawValue, icon: s.icon, active: section == s) {
                    withAnimation(.snappy(duration: 0.25)) { section = s }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
        .frame(width: 232)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Main content

    @ViewBuilder private var mainContent: some View {
        switch section {
        case .today: todayView
        case .history: historyView
        case .apps: appsView
        case .settings: settingsView
        }
    }

    private var todayView: some View {
        let stats = DashboardStats(state.transcriptHistory)
        return VStack(spacing: 24) {
            HeroCard(stats: stats, keyName: state.keyName(state.settings.pttKeyCode))
            tasksSection
        }
    }

    private var tasksSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 9) {
                Text("Get more from Drift")
                    .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(GF.ink)
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(GF.accentSoft).frame(width: 26, height: 26)
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold)).foregroundStyle(GF.accent)
                    }
                    Text("A few quick wins to dictate faster")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(GF.inkSecondary)
                }
            }
            .padding(.top, 30)

            VStack(spacing: 14) {
                TaskCard(
                    tint: GF.pastelTeal, icon: "command", badge: "command",
                    title: "Speak punctuation and edits, hands-free",
                    cta: state.commandModeEnabled ? "Command mode is on" : "Turn on Command mode",
                    done: state.commandModeEnabled
                ) { withAnimation(.snappy) { section = .apps } }

                TaskCard(
                    tint: GF.pastelBlue, icon: "square.grid.2x2.fill", badge: "wand.and.stars",
                    title: "Match your writing to each app automatically",
                    cta: "Set up per-app formatting",
                    done: !state.recentTargetApps.isEmpty
                ) { withAnimation(.snappy) { section = .apps } }

                TaskCard(
                    tint: GF.pastelGreen, icon: "cpu", badge: "checkmark",
                    title: "Pick the model that fits your voice",
                    cta: "Choose your model", done: false
                ) { withAnimation(.snappy) { section = .settings } }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 36, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 36, style: .continuous)
                .fill(GF.sectionBG)
        )
    }

    // MARK: History

    private var filtered: [TranscriptEntry] {
        guard !query.isEmpty else { return state.transcriptHistory }
        let q = query.lowercased()
        return state.transcriptHistory.filter { $0.text.lowercased().contains(q) || $0.microphoneName.lowercased().contains(q) }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Transcript History").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(GF.ink)
                    Text(historySubtitle).font(.caption).foregroundStyle(GF.inkSecondary)
                }
                Spacer()
                if !state.transcriptHistory.isEmpty {
                    Button(role: .destructive) { withAnimation(.smooth) { state.clearTranscriptHistory() } } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
            if !state.transcriptHistory.isEmpty {
                LightSearchField(text: $query)
            }

            if state.transcriptHistory.isEmpty {
                hint(symbol: "waveform", title: "No transcripts yet", message: "Hold your push-to-talk key and speak — finished dictations land here.")
            } else if filtered.isEmpty {
                hint(symbol: "text.magnifyingglass", title: "No matches", message: "Nothing matches “\(query)”.")
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(DashboardStats.group(filtered).enumerated()), id: \.element.title) { index, group in
                        Text(group.title.uppercased())
                            .font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(GF.inkTertiary)
                            .padding(.top, index == 0 ? 0 : 8)
                        ForEach(group.entries) { entry in
                            LightTranscriptRow(entry: entry, highlight: query) { state.copyTranscript(entry) }
                        }
                    }
                }
            }
        }
    }

    private var historySubtitle: String {
        if !query.isEmpty { let n = filtered.count; return n == 1 ? "1 match" : "\(n) matches" }
        let c = state.transcriptHistory.count
        return c == 0 ? "Nothing captured yet" : (c == 1 ? "1 dictation" : "\(c) dictations")
    }

    // MARK: Apps

    private var appsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Per-app Formatting").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(GF.ink)

            LightCard {
                HStack {
                    Text("Match style to the app").font(.callout.weight(.semibold)).foregroundStyle(GF.ink)
                    Spacer()
                    Toggle("", isOn: $state.perAppProfilesEnabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                if state.perAppProfilesEnabled {
                    Text("Drift matches its style to the app you dictate into.")
                        .font(.caption).foregroundStyle(GF.inkSecondary)
                    LightProfileRow(name: "Default", systemIcon: "asterisk.circle.fill", selection: $state.defaultProfileID)
                    ForEach(state.recentTargetApps.prefix(8)) { app in
                        LightAppRow(app: app)
                    }
                    Button { state.addApp() } label: { Label("Add app…", systemImage: "plus") }
                        .buttonStyle(.bordered).controlSize(.regular)
                } else {
                    Text("Turn on to auto-switch style per app.").font(.caption).foregroundStyle(GF.inkSecondary)
                }
            }

            LightCard {
                HStack {
                    Text("Command mode").font(.callout.weight(.semibold)).foregroundStyle(GF.ink)
                    Spacer()
                    Toggle("", isOn: $state.commandModeEnabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                Text(state.commandModeEnabled ? "Speak formatting instead of typing it." : "Turn on to speak punctuation and edits.")
                    .font(.caption).foregroundStyle(GF.inkSecondary)
                if state.commandModeEnabled {
                    ForEach(CommandProcessor.reference, id: \.spoken) { cmd in
                        HStack {
                            Text("“\(cmd.spoken)”").font(.caption2.weight(.medium)).foregroundStyle(GF.ink)
                            Spacer()
                            Text(cmd.effect).font(.caption2).foregroundStyle(GF.inkSecondary)
                        }
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: state.perAppProfilesEnabled)
        .animation(.smooth(duration: 0.25), value: state.commandModeEnabled)
    }

    // MARK: Settings

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(GF.ink)

            LightCard {
                Text("Input").font(.callout.weight(.semibold)).foregroundStyle(GF.ink)
                Picker("Microphone", selection: Binding(get: { state.selectedMicrophoneID }, set: { state.selectMicrophone($0) })) {
                    ForEach(state.availableMicrophones) { d in Text(d.name).tag(d.id) }
                }.labelsHidden()
                LightDetail(title: "Active input", value: state.selectedMicrophoneName)
                HStack {
                    Button { state.refreshSelectedMicrophone() } label: { Label("Refresh", systemImage: "arrow.clockwise") }.buttonStyle(.bordered)
                    Button { state.openSoundSettings() } label: { Label("Sound", systemImage: "speaker.wave.2") }.buttonStyle(.bordered)
                }
            }

            LightCard {
                Text("Model").font(.callout.weight(.semibold)).foregroundStyle(GF.ink)
                Picker("Model", selection: Binding(get: { state.selectedDictationModelID }, set: { state.selectDictationModel($0) })) {
                    ForEach(state.dictationModelOptions) { o in Text(o.displayName).tag(o.id) }
                }.labelsHidden()
                if state.transcriptionBackend == .whisperKit {
                    Picker("Language", selection: $state.languageCode) {
                        ForEach(Language.all) { l in Text(l.displayName).tag(l.code) }
                    }.labelsHidden()
                } else {
                    LightDetail(title: "Language", value: state.languageDisplayName)
                }
                LightDetail(title: "Cleanup", value: state.cleanupProviderDisplayName)
                LightDetail(title: "Push-to-talk", value: state.keyName(state.settings.pttKeyCode))
            }
        }
    }

    private func hint(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(GF.accentSoft).frame(width: 72, height: 72)
                Image(systemName: symbol).font(.system(size: 26, weight: .medium)).foregroundStyle(GF.accent)
            }
            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(GF.ink)
            Text(message).font(.callout).foregroundStyle(GF.inkSecondary).multilineTextAlignment(.center).frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
    }
}

// MARK: - Palette

private enum GF {
    static let pageBG = Color.white
    static let sectionBG = Color(red: 0.953, green: 0.961, blue: 0.969)
    static let cardBG = Color.white
    static let hairline = Color.black.opacity(0.06)
    static let cardBorder = Color.black.opacity(0.06)

    static let ink = Color(red: 0.105, green: 0.12, blue: 0.15)
    static let inkSecondary = Color(red: 0.42, green: 0.46, blue: 0.51)
    static let inkTertiary = Color(red: 0.60, green: 0.64, blue: 0.69)

    // GoFundMe green
    static let accent = Color(red: 0.05, green: 0.72, blue: 0.42)
    static let accentDeep = Color(red: 0.09, green: 0.36, blue: 0.22)
    static let accentSoft = Color(red: 0.05, green: 0.72, blue: 0.42).opacity(0.14)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.46, green: 0.85, blue: 0.50), Color(red: 0.07, green: 0.74, blue: 0.42), Color(red: 0.02, green: 0.59, blue: 0.37)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.80, green: 0.93, blue: 0.66), Color(red: 0.87, green: 0.95, blue: 0.75)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let pastelBlue = Color(red: 0.85, green: 0.93, blue: 0.99)
    static let pastelGreen = Color(red: 0.86, green: 0.95, blue: 0.89)
    static let pastelTeal = Color(red: 0.82, green: 0.94, blue: 0.93)
}

// MARK: - Sidebar item

private struct SideItem: View {
    let title: String
    let icon: String
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(active ? AnyShapeStyle(GF.accentGradient) : AnyShapeStyle(Color.black.opacity(hovering ? 0.06 : 0.04)))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(active ? .white : GF.inkSecondary)
                }
                Text(title)
                    .font(.system(size: 16, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? GF.ink : GF.inkSecondary)
                Spacer()
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Hero card

private struct HeroCard: View {
    let stats: DashboardStats
    let keyName: String

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                Color.clear.frame(height: 36)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(stats.words.formatted()) words")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(GF.accentDeep)
                        Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold)).foregroundStyle(GF.accentDeep.opacity(0.6))
                    }
                    HStack(spacing: 6) {
                        Text("Hold").foregroundStyle(GF.accentDeep.opacity(0.7))
                        LightKeycap(keyName)
                        Text("to talk").foregroundStyle(GF.accentDeep.opacity(0.7))
                    }
                    .font(.system(size: 14, weight: .semibold))
                }

                HStack(spacing: 9) {
                    HeroPill(value: stats.total.formatted(), label: "Dictations")
                    HeroPill(value: stats.week.formatted(), label: "This week")
                    HeroPill(value: "\(stats.streak)", label: stats.streak == 1 ? "Day streak" : "Day streak")
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(GF.heroGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(RadialGradient(colors: [.white.opacity(0.5), .clear], center: .topLeading, startRadius: 0, endRadius: 320))
                    )
            )
            .padding(.top, 40)

            HeroAvatar()
        }
    }
}

private struct HeroAvatar: View {
    @State private var breathe = false
    var body: some View {
        ZStack {
            // Sprout spike
            Capsule().fill(GF.accentGradient).frame(width: 5, height: 16).offset(y: -42)
            // Progress ring
            Circle().trim(from: 0, to: 0.82)
                .stroke(GF.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 84, height: 84)
            // White ring
            Circle().fill(.white).frame(width: 78, height: 78)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            // Orb
            ZStack {
                Circle().fill(GF.accentGradient)
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)))
                    .frame(width: 64, height: 64)
                Image(systemName: "waveform").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
            }
            .scaleEffect(breathe ? 1.03 : 0.99)
        }
        .frame(width: 84, height: 84)
        .onAppear { withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true } }
    }
}

private struct HeroPill: View {
    let value: String
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(GF.ink)
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(GF.inkSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(.white))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Task card

private struct TaskCard: View {
    let tint: Color
    let icon: String
    let badge: String
    let title: String
    let cta: String
    let done: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint).frame(width: 76, height: 76)
                    Image(systemName: icon).font(.system(size: 30, weight: .medium)).foregroundStyle(Color.black.opacity(0.22))
                        .frame(width: 76, height: 76)
                    Circle().fill(GF.accentGradient).frame(width: 26, height: 26)
                        .overlay(Image(systemName: badge).font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                        .offset(x: 6, y: -6)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(GF.ink)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(GF.accent) }
                        Text(cta).font(.system(size: 14, weight: .medium)).foregroundStyle(done ? GF.accent : GF.inkSecondary)
                        if !done { Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(GF.inkSecondary) }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GF.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(GF.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(hovering ? 0.08 : 0.04), radius: hovering ? 12 : 6, y: hovering ? 4 : 2)
            .offset(y: hovering ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
    }
}

// MARK: - Light shared rows

private struct LightCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GF.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(GF.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

private struct LightDetail: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).font(.callout).foregroundStyle(GF.inkSecondary)
            Spacer()
            Text(value).font(.callout.weight(.medium)).foregroundStyle(GF.ink).lineLimit(1)
        }
    }
}

private struct LightProfileRow: View {
    let name: String
    let systemIcon: String
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemIcon).font(.system(size: 14)).foregroundStyle(GF.accent).frame(width: 20)
            Text(name).font(.callout).foregroundStyle(GF.ink)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(FormattingProfile.all) { p in Text(p.name).tag(p.id) }
            }.labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }
}

private struct LightAppRow: View {
    @EnvironmentObject var state: AppState
    let app: TargetApp
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 10) {
            if let icon = state.appIcon(forBundleID: app.bundleID) {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed").foregroundStyle(GF.inkTertiary).frame(width: 20)
            }
            Text(app.name).font(.callout).foregroundStyle(GF.ink).lineLimit(1)
            Spacer()
            Picker("", selection: Binding(
                get: { state.profileID(forBundleID: app.bundleID) },
                set: { state.setProfile($0, forBundleID: app.bundleID) }
            )) {
                ForEach(FormattingProfile.all) { p in Text(p.name).tag(p.id) }
            }.labelsHidden().pickerStyle(.menu).fixedSize()
            Button { state.removeApp(app) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(GF.inkTertiary)
            }.buttonStyle(.plain).opacity(hovering ? 1 : 0)
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

private struct LightTranscriptRow: View {
    let entry: TranscriptEntry
    var highlight: String = ""
    let copy: () -> Void
    @State private var hovering = false
    @State private var justCopied = false

    private var wordCount: Int { entry.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.createdAt.formatted(.relative(presentation: .named)))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(GF.ink)
                Spacer(minLength: 8)
                Text("\(wordCount) words").font(.caption2.weight(.medium)).foregroundStyle(GF.inkSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Color.black.opacity(0.05)))
                Button {
                    copy(); justCopied = true
                    Task { try? await Task.sleep(for: .seconds(1.4)); justCopied = false }
                } label: {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(justCopied ? Color.green : GF.inkSecondary)
                        .contentTransition(.symbolEffect(.replace))
                }.buttonStyle(.plain).opacity(justCopied || hovering ? 1 : 0.4)
            }
            highlightedText.font(.body).foregroundStyle(GF.ink.opacity(0.85)).lineSpacing(2)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "mic.fill").font(.system(size: 9)).foregroundStyle(GF.inkTertiary)
                Text(entry.microphoneName).lineLimit(1)
                Text("·").foregroundStyle(GF.inkTertiary)
                Text(Language.from(code: entry.languageCode).displayName)
            }
            .font(.caption2).foregroundStyle(GF.inkSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(GF.cardBG))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(hovering ? GF.accent.opacity(0.4) : GF.cardBorder, lineWidth: 1))
        .shadow(color: .black.opacity(hovering ? 0.07 : 0.03), radius: hovering ? 10 : 5, y: 2)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
        .animation(.snappy(duration: 0.25), value: justCopied)
    }

    private var highlightedText: Text {
        guard !highlight.isEmpty, let range = entry.text.range(of: highlight, options: .caseInsensitive) else { return Text(entry.text) }
        return Text(String(entry.text[..<range.lowerBound]))
            + Text(String(entry.text[range])).foregroundColor(GF.accent).bold()
            + Text(String(entry.text[range.upperBound...]))
    }
}

private struct LightSearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundStyle(GF.inkTertiary)
            TextField("Search transcripts", text: $text).textFieldStyle(.plain).font(.callout).focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(GF.inkTertiary) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(GF.sectionBG))
        .overlay(Capsule().strokeBorder(focused ? GF.accent.opacity(0.5) : GF.cardBorder, lineWidth: 1))
        .frame(maxWidth: 280)
    }
}

private struct LightKeycap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(GF.accentDeep.opacity(0.15), lineWidth: 1))
            .foregroundStyle(GF.accentDeep)
    }
}

private struct StatusChip: View {
    let text: String
    let color: Color
    let pulsing: Bool
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color.opacity(0.9))
    }
}

// MARK: - Derived stats

private struct DashboardStats {
    var total = 0
    var words = 0
    var today = 0
    var week = 0
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
            if diff >= 0, diff < 7 { daily[6 - diff] += 1; week += 1 }
        }
        avg = total == 0 ? 0 : Int((Double(words) / Double(total)).rounded())
        var probe = activeDays.contains(todayStart) ? todayStart : cal.date(byAdding: .day, value: -1, to: todayStart)!
        while activeDays.contains(probe) { streak += 1; probe = cal.date(byAdding: .day, value: -1, to: probe)! }
    }

    struct Section { let title: String; let entries: [TranscriptEntry] }

    static func group(_ entries: [TranscriptEntry]) -> [Section] {
        let cal = Calendar.current
        var today: [TranscriptEntry] = [], yesterday: [TranscriptEntry] = [], earlier: [TranscriptEntry] = []
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

// MARK: - Status helpers

private extension AppState {
    var isDownloading: Bool { if case .downloadingModel = status { return true }; return false }
    var isRecordingStatus: Bool { if case .recording = status { return true }; return false }
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
        case .idle: return Color(red: 0.13, green: 0.7, blue: 0.42)
        case .recording: return Color(red: 0.9, green: 0.3, blue: 0.36)
        case .transcribing, .loadingModel, .downloadingModel: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .needsSetup: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .error: return Color(red: 0.9, green: 0.3, blue: 0.36)
        }
    }
}
