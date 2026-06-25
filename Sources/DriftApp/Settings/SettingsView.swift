import SwiftUI
import DriftKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Card {
                    SectionLabel("Audio", systemImage: "mic.fill")
                    Picker("Microphone", selection: Binding(
                        get: { state.selectedMicrophoneID },
                        set: { state.selectMicrophone($0) }
                    )) {
                        ForEach(state.availableMicrophones) { device in Text(device.name).tag(device.id) }
                    }
                    .labelsHidden()
                    HStack {
                        Text("Using \(state.selectedMicrophoneName)")
                            .font(.caption).foregroundStyle(Ink.text(0.5)).lineLimit(1)
                        Spacer()
                        SoftButton(title: "Refresh", systemImage: "arrow.clockwise") { state.refreshSelectedMicrophone() }
                    }
                }

                Card {
                    SectionLabel("Transcription", systemImage: "waveform")
                    Picker("Engine", selection: Binding(
                        get: { state.transcriptionBackendID },
                        set: { state.selectTranscriptionBackend($0) }
                    )) {
                        ForEach(TranscriptionBackend.allCases) { backend in Text(backend.displayName).tag(backend.id) }
                    }
                    .labelsHidden()

                    if state.transcriptionBackend == .whisperKit {
                        Picker("Model", selection: Binding(
                            get: { state.modelVariant },
                            set: { state.selectModel($0) }
                        )) {
                            ForEach(ModelCatalog.options) { option in Text(option.displayName).tag(option.id) }
                        }
                        .labelsHidden()
                        Picker("Language", selection: $state.languageCode) {
                            ForEach(Language.all) { lang in Text(lang.displayName).tag(lang.code) }
                        }
                        .labelsHidden()
                        note("Indian-language accuracy is best with the Large model; smaller models trade accuracy for speed.")
                    } else {
                        DetailLine(icon: "cpu", title: "Model", value: state.modelDisplayName)
                        DetailLine(icon: "globe", title: "Language", value: "English")
                        note("FluidAudio uses Parakeet v3 for local dictation. Switch to WhisperKit for Indian-language transcription.")
                    }
                }

                Card {
                    SectionLabel("Cleanup", systemImage: "wand.and.stars")
                    Picker("Provider", selection: $state.cleanupProviderID) {
                        ForEach(CleanupRegistry.all) { info in Text(info.displayName).tag(info.id) }
                    }
                    .labelsHidden()

                    switch state.cleanupProviderID {
                    case "openai":
                        field("Base URL", text: $state.openAIBaseURL)
                        field("Model", text: $state.openAIModel)
                        secureField("API Key", text: $state.openAIKey)
                        note("Works with any OpenAI-compatible API: OpenAI, Groq, Sarvam, LM Studio.")
                    case "ollama":
                        field("Base URL", text: $state.ollamaBaseURL)
                        field("Model", text: $state.ollamaModel)
                        note("Requires Ollama running locally with the model pulled.")
                    case "none":
                        note("Text is inserted exactly as transcribed.")
                    default:
                        note("Fast, private formatting on your Mac. No setup, no network.")
                    }
                }

                Card {
                    SectionLabel("Commands", systemImage: "command")
                    Toggle("Voice command mode", isOn: $state.commandModeEnabled)
                    note("Say “new line”, “comma”, “scratch that”… and Drift formats instead of typing the words. English only.")
                }

                Card {
                    SectionLabel("Per-app Formatting", systemImage: "square.grid.2x2")
                    Toggle("Match style to the app", isOn: $state.perAppProfilesEnabled)
                    Picker("Default style", selection: $state.defaultProfileID) {
                        ForEach(FormattingProfile.all) { profile in Text(profile.name).tag(profile.id) }
                    }
                    .disabled(!state.perAppProfilesEnabled)
                    note("The default applies to apps without their own rule. Add apps and tune each one on the Dashboard.")
                }

                Card {
                    SectionLabel("Push-to-talk", systemImage: "keyboard")
                    HStack {
                        Text("Key").font(.callout).foregroundStyle(Ink.text(0.85))
                        Spacer()
                        Keycap(state.keyName(state.settings.pttKeyCode))
                    }
                    note("Hold the key, speak, and release to insert text.")
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .frame(width: 540, height: 620)
        .background(InkCanvas().ignoresSafeArea())
        .tint(Ink.accentSolid)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AuraOrb(diameter: 34, recording: false, busy: false)
            VStack(alignment: .leading, spacing: 1) {
                Text("Settings").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Configure Drift").font(.caption).foregroundStyle(Ink.text(0.45))
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(Ink.text(0.45)).fixedSize(horizontal: false, vertical: true)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text).textFieldStyle(.roundedBorder)
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text).textFieldStyle(.roundedBorder)
    }
}

/// Local copy of the dashboard's detail row (kept here so Settings is self-contained).
private struct DetailLine: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.accentSolid.opacity(0.9)).frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(Ink.text(0.45))
                Text(value).font(.callout.weight(.medium)).foregroundStyle(Ink.text(0.9))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
