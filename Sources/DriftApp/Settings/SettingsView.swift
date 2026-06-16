import SwiftUI
import DriftKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Transcription") {
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
