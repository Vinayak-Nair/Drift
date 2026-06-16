# Drift interim build (`interim-whisper-cpp`)

This branch is a fully working Drift that runs on a Mac with **only Command Line
Tools** (no full Xcode, no working SwiftPM). It exists because the canonical
WhisperKit version on `main` needs full Xcode (which needs ~35 GB and an external
SSD that's on order). Until then, this is the **daily driver**.

It is **not throwaway**. Most of what was built here (overlay, learning
dictionary, silence trimming, logging) is real product UX that should move to
`main`. See [PORT-TO-MAIN.md](PORT-TO-MAIN.md).

## How it differs from `main`

| | `main` (canonical) | this branch (interim) |
|---|---|---|
| UI | SwiftUI (`MenuBarExtra`) | AppKit (`NSStatusItem`) |
| Speech engine | embedded WhisperKit (CoreML, Neural Engine) | whisper.cpp Homebrew binary as a warm local server |
| Build | Xcode + XcodeGen + SwiftPM | `swiftc` directly, single module |
| Transcribe call | in-process | `curl` to `127.0.0.1:8910/inference` |
| Signing | Developer ID (release) | stable self-signed "Drift Dev Cert" |

Why `swiftc`: SwiftPM is broken under CLT on this machine (`swift-package`
dyld-crashes on `SWBBuildService`), so `swift build` can't run.

## Build & run

```bash
./scripts/dev-setup-clt.sh        # brew install whisper-cpp + download default model
./scripts/dev-build-clt.sh        # swiftc -> /Applications/Drift.app, signs with Drift Dev Cert
open /Applications/Drift.app
```

First run: grant **Microphone**, **Input Monitoring**, and **Accessibility**
(menu ▸ Check Permissions). Then hold **Right Option (⌥)**, speak, release.

Current model: `ggml-large-v3-turbo-q5_0.bin` with `-ac 768` (good for
Indian-accented English, ~2 s on this hardware; small and medium-q5 are also
downloaded for comparison).

## File map (this branch)

Interim-only (in `Sources/DriftApp/Interim/`):
- `InterimAppDelegate.swift` — menu bar, orchestration, permissions, correction UI
- `WhisperServerManager.swift` — spawns/supervises the whisper.cpp server
- `WhisperServerTranscriber.swift` — `curl` POST to the warm server (a `Transcriber`)
- `WhisperCppTranscriber.swift` — CLI shell-out fallback (unused; kept as reference)
- `WavWriter.swift` — `[Float]` -> 16 kHz WAV
- `OverlayController.swift` — Wispr-style pill + live audio bars
- `Corrections.swift` — learning dictionary (`~/.drift/dictionary.json`)
- `DriftDebug.swift` — `DriftLog` persistent logger (`~/.drift/drift.log`)
- `main.swift` — AppKit entry point

Shared AppKit helpers (`Sources/DriftApp/`): `Hotkey.swift` (with a one-line
`import` tweak for the single-module build), `Paster.swift`, `Feedback.swift`.

`DriftKit` additions on this branch (backend-agnostic, belong on `main` too):
- `Audio/SilenceTrimmer.swift`
- `Recorder.onLevel`, `Pipeline.onLevel`, `Pipeline.lastTrimmedSeconds`

## Gotchas (hard-won; don't relearn these)

1. **TCC is bound to the signing identity.** Ad-hoc signing changes the code
   hash every build, so Microphone / Input Monitoring / Accessibility grants
   reset on every rebuild. The stable self-signed **"Drift Dev Cert"** fixes
   this. Create it once (see `scripts/dev-build-clt.sh`, which signs with it).
2. **Push-to-talk needs Input Monitoring, not Accessibility.** A listen-only
   `CGEventTap` on keyboard events is gated by Input Monitoring. Accessibility is
   only for pasting (synthesized Cmd+V). Both are required.
3. **App-bundle `URLSession` to localhost is blocked by App Transport Security.**
   `curl` (a subprocess) bypasses it. (Moot on `main`: WhisperKit is in-process,
   no HTTP.)
4. **Never call `AVAudioEngine.prepare()` / any "prewarm" on the main thread.**
   It hangs and froze the app on "Starting speech engine".
5. **Whisper pads short clips to a 30 s window.** `-ac N` caps the audio context
   so short clips are faster. `SilenceTrimmer` also cuts the audio actually sent.
6. **Mic capturing silence -> Whisper hallucinates "You"** and the level bars go
   flat. That's a permission/identity problem (see gotcha 1), not the engine.

## Logs

`~/.drift/drift.log` (menu ▸ Open Log): one line per dictation
(`audio=`, `sent=`, `level=`, `latency=`, `chars=`, text preview), plus `WARN` /
`ERROR` lines. Auto-rotates at 512 KB. This is the first thing to read when a
dictation misbehaves.
