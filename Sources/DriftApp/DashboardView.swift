import SwiftUI
import DriftKit

struct DashboardView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.vertical, 18)

            Divider()

            HStack(spacing: 0) {
                transcriptPanel
                    .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                sidebar
                    .frame(width: 270)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("Drift Dashboard")
                    .font(.title2.bold())
                Text(state.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            StatusBadge(text: state.statusBadgeText, color: state.statusBadgeColor)
        }
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Transcript History")
                        .font(.headline)
                    Text("\(state.transcriptHistory.count) saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    state.clearTranscriptHistory()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(state.transcriptHistory.isEmpty)
            }
            .padding(20)

            Divider()

            if state.transcriptHistory.isEmpty {
                emptyHistory
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(state.transcriptHistory) { entry in
                            TranscriptRow(entry: entry) {
                                state.copyTranscript(entry)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.page")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No transcripts yet")
                .font(.headline)
            Text("Completed dictations will appear here with their timestamp and microphone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(24)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Microphone", selection: Binding(
                            get: { state.selectedMicrophoneID },
                            set: { state.selectMicrophone($0) }
                        )) {
                            ForEach(state.availableMicrophones) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .pickerStyle(.menu)

                        DetailLine(icon: "mic.fill", title: "Active input", value: state.selectedMicrophoneName)

                        HStack {
                            Button {
                                state.refreshSelectedMicrophone()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }

                            Button {
                                state.openSoundSettings()
                            } label: {
                                Label("Sound", systemImage: "speaker.wave.2")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Input", systemImage: "slider.horizontal.3")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Model", selection: Binding(
                            get: { state.selectedDictationModelID },
                            set: { state.selectDictationModel($0) }
                        )) {
                            ForEach(state.dictationModelOptions) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)

                        if state.transcriptionBackend == .whisperKit {
                            Picker("Language", selection: $state.languageCode) {
                                ForEach(Language.all) { lang in
                                    Text(lang.displayName).tag(lang.code)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            DetailLine(icon: "globe", title: "Language", value: state.languageDisplayName)
                        }

                        DetailLine(icon: "wand.and.stars", title: "Cleanup", value: state.cleanupProviderDisplayName)

                        if state.status == .loadingModel || state.isDownloading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(state.statusText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Models", systemImage: "gearshape")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        IdeaLine("Command mode")
                        IdeaLine("Language picker")
                        IdeaLine("Personal dictionary")
                        IdeaLine("Snippets")
                        IdeaLine("Quick notes")
                        IdeaLine("Retry history")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Worth Adding Next", systemImage: "sparkles")
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct TranscriptRow: View {
    let entry: TranscriptEntry
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.subheadline.weight(.semibold))
                    Text("\(Language.from(code: entry.languageCode).displayName) - \(entry.microphoneName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy transcript")
            }

            Text(entry.text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18))
        }
    }
}

private struct DetailLine: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
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

private struct IdeaLine: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

private extension AppState {
    var isDownloading: Bool {
        if case .downloadingModel = status { return true }
        return false
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
