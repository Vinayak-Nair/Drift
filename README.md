# Drift

**Local-first voice dictation for macOS. A free, open-source alternative to Wispr Flow.**

Hold a key, speak, and Drift types cleaned-up text into whatever app you're using. Transcription runs entirely on your Mac with [WhisperKit](https://github.com/argmaxinc/WhisperKit), so your voice never leaves the device.

- 🎙️ **Push-to-talk anywhere**, system-wide
- 🔒 **Private by default**: on-device transcription and on-device cleanup, no account, no API key
- 🌐 **Multilingual**, with a focus on Indian languages (Hindi, Tamil, Malayalam, Kannada, Telugu) alongside English and more
- 🧹 **Smart cleanup**: removes filler words and fixes punctuation instantly on-device; optional cloud or local LLM cleanup for higher quality
- 🪶 **Native and lightweight**: a Swift menu-bar app, no Electron
- 🆓 **MIT licensed**

## Install (for users)

1. Download `Drift.dmg` from the [Releases](https://github.com/) page.
2. Open it and drag **Drift** to your Applications folder.
3. Open Drift. A small waveform icon appears in your menu bar.
4. Follow the one-time setup: grant **Microphone** and **Accessibility**, and let the speech model download.
5. Click into any text field, **hold Right Option (⌥)**, speak, and release.

No Homebrew, no Terminal, no separate downloads. Everything is handled inside the app.

> Accessibility is required so Drift can detect the push-to-talk key and type into other apps. You can review this anytime in the menu under **Setup & Permissions**.

## Using Drift

- **Dictate:** hold Right Option (⌥), speak, release. The text is inserted at your cursor.
- **Change language:** menu bar ▸ Language, or Settings.
- **Pick a cleanup style:** Settings ▸ Cleanup.
- Sounds confirm start, success, and empty results.

## Languages

Drift ships a multilingual model and supports English plus Hindi, Tamil, Malayalam, Kannada, Telugu, and others. Accuracy varies by language (Hindi and Tamil are strong; Malayalam and Kannada are improving). For the best Indian-language accuracy keep the default **Large v3 Turbo** model; switch to a smaller model in Settings if you want more speed.

## Cleanup options

| Provider | Where it runs | Setup | Best for |
|----------|---------------|-------|----------|
| **On-device** (default) | Your Mac | None | Instant, private formatting |
| **Cloud (OpenAI-compatible)** | A hosted API | Base URL + key | Highest quality; works with OpenAI, Groq, **Sarvam**, LM Studio |
| **Local LLM (Ollama)** | Your Mac | Run Ollama | Private LLM cleanup, advanced |
| **Raw** | n/a | None | Insert the transcription verbatim |

The cleanup layer is model-agnostic, so adding an Indian-language model such as Sarvam is just a base URL and model name in Settings.

## Privacy

By default, audio is transcribed on-device and cleaned on-device. Nothing is uploaded. If you opt into a cloud cleanup provider, only the transcribed text (not your audio) is sent to the endpoint you configure.

---

## Building from source (for contributors)

### Requirements

- macOS 14+
- **Full Xcode 16+** (Command Line Tools alone are not enough: WhisperKit and the app build need Xcode). If your internal disk is low, Xcode and its build data can live on an external APFS SSD.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the bootstrap script installs it via Homebrew)

### Steps

```bash
git clone <repo-url> Drift && cd Drift
./scripts/bootstrap.sh     # installs XcodeGen, generates the project, resolves deps
open Drift.xcodeproj       # then press Run (Cmd+R)
```

Run the core unit tests with:

```bash
swift test
```

### Project layout

`DriftKit` is a pure, testable Swift package (no UI). The macOS app in `Sources/DriftApp` is generated into an Xcode project by XcodeGen from `project.yml`.

| Area | Path | Responsibility |
|------|------|----------------|
| Core | `Sources/DriftKit/Pipeline.swift` | record ▸ transcribe ▸ clean orchestration |
| STT | `Sources/DriftKit/Transcription/` | `Transcriber` protocol, WhisperKit impl, model download |
| Cleanup | `Sources/DriftKit/Cleanup/` | `CleanupProvider` protocol + deterministic / OpenAI-compatible / Ollama |
| Audio | `Sources/DriftKit/Audio/Recorder.swift` | mic capture to 16 kHz samples |
| App | `Sources/DriftApp/` | menu bar, onboarding, settings, hotkey, paste |

### Releasing

```bash
DEV_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="drift-notary" \
./scripts/release.sh
```

Produces a signed, notarized `build/Drift.dmg`. Notarization needs a paid Apple Developer account; without one the script still builds an ad-hoc-signed DMG for local use.

## Roadmap

- [ ] App icon and a polished menu-bar status UI
- [ ] Move the API key to the Keychain
- [ ] Live partial-transcription overlay
- [ ] Custom vocabulary and per-app formatting profiles
- [ ] Sarvam and other Indian-language cleanup presets
- [ ] Configurable push-to-talk key in Settings

## Credits

Built on [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax. Inspired by Wispr Flow.

## License

MIT, see [LICENSE](LICENSE).
