import SwiftUI
import DriftKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Audio") {
                Picker("Microphone", selection: Binding(
                    get: { state.selectedMicrophoneID },
                    set: { state.selectMicrophone($0) }
                )) {
                    ForEach(state.availableMicrophones) { device in
                        Text(device.name).tag(device.id)
                    }
                }

                HStack {
                    Text("Using \(state.selectedMicrophoneName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { state.refreshSelectedMicrophone() }
                }
            }

            Section("Transcription") {
                Picker("Engine", selection: Binding(
                    get: { state.transcriptionBackendID },
                    set: { state.selectTranscriptionBackend($0) }
                )) {
                    ForEach(TranscriptionBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend.id)
                    }
                }

                if state.transcriptionBackend == .whisperKit {
                    Picker("Model", selection: Binding(
                        get: { state.modelVariant },
                        set: { state.selectModel($0) }
                    )) {
                        ForEach(ModelCatalog.options) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    Picker("Language", selection: $state.languageCode) {
                        ForEach(Language.all) { lang in
                            Text(lang.displayName).tag(lang.code)
                        }
                    }
                    Text("Indian-language accuracy is best with the Large model; smaller models trade accuracy for speed.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    LabeledContent("Model", value: state.modelDisplayName)
                    LabeledContent("Language", value: "English")
                    Text("FluidAudio uses Parakeet v3 for local dictation. Switch to WhisperKit for Indian-language transcription.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Cleanup") {
                Picker("Provider", selection: $state.cleanupProviderID) {
                    ForEach(CleanupRegistry.all) { info in
                        Text(info.displayName).tag(info.id)
                    }
                }

                switch state.cleanupProviderID {
                case "openai":
                    TextField("Base URL", text: $state.openAIBaseURL)
                    TextField("Model", text: $state.openAIModel)
                    SecureField("API Key", text: $state.openAIKey)
                    Text("Works with any OpenAI-compatible API: OpenAI, Groq, Sarvam, LM Studio.")
                        .font(.caption).foregroundStyle(.secondary)
                case "ollama":
                    TextField("Base URL", text: $state.ollamaBaseURL)
                    TextField("Model", text: $state.ollamaModel)
                    Text("Requires Ollama running locally with the model pulled.")
                        .font(.caption).foregroundStyle(.secondary)
                case "none":
                    Text("Text is inserted exactly as transcribed.")
                        .font(.caption).foregroundStyle(.secondary)
                default:
                    Text("Fast, private formatting on your Mac. No setup, no network.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Commands") {
                Toggle("Voice command mode", isOn: $state.commandModeEnabled)
                Text("Say “new line”, “comma”, “scratch that”… and Drift formats instead of typing the words. English only.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Per-app formatting") {
                Toggle("Match style to the app", isOn: $state.perAppProfilesEnabled)
                Picker("Default style", selection: $state.defaultProfileID) {
                    ForEach(FormattingProfile.all) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .disabled(!state.perAppProfilesEnabled)
                Text("The default applies to apps without their own rule. Add apps and tune each one on the Dashboard.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Push-to-talk") {
                LabeledContent("Key", value: state.keyName(state.settings.pttKeyCode))
                Text("Hold the key, speak, and release to insert text.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 540)
    }
}
