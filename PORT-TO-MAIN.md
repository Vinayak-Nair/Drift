# Porting the interim UX onto `main` (WhisperKit)

When Xcode is installed and `main` builds + runs with WhisperKit, bring the
daily-driver UX from `interim-whisper-cpp` onto `main`. The point: don't lose the
overlay, dictionary, trimming, and logging just because the speech engine changes.

The `Transcriber` / `CleanupProvider` protocols mean the **backend swap is the
only big difference**. Everything else is app/DriftKit code that ports.

## Phase 0 — get `main` building

- [ ] Install Xcode 16+ (87 GB free now, it fits), then
      `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`,
      accept the license, run first-launch components.
- [ ] `./scripts/bootstrap.sh` (installs XcodeGen, generates the project,
      resolves WhisperKit via SwiftPM).
- [ ] Build + run `main` in Xcode. Fix any WhisperKit API drift in
      `WhisperKitTranscriber` / `ModelManager` (pin against the resolved version).
- [ ] Live test: mic -> transcription -> paste (the one thing CI can't do).

## Phase 1 — port the shared (DriftKit) pieces (cheap, cherry-pickable)

These are backend-agnostic and already live in `DriftKit` on the interim branch:

- [ ] `Audio/SilenceTrimmer.swift` — copy as-is. `Pipeline.stopAndProcess`
      already calls it.
- [ ] `Recorder.onLevel`, `Pipeline.onLevel`, `Pipeline.lastTrimmedSeconds` —
      copy the diffs.
- [ ] Microphone selection (`Audio/AudioInputDevice.swift` + `Recorder`/`Settings`
      changes) — already being added on `main`; finish + verify under Xcode.

## Phase 2 — port the app-level UX (reimplement against `AppState`)

`main` is SwiftUI; the interim is AppKit. The logic ports, the wiring changes.

- [ ] **Overlay** (`OverlayController.swift`): reimplement as a SwiftUI overlay
      window (or reuse the AppKit `NSPanel` via the app delegate). Show on
      record start, feed it `Pipeline.onLevel`, hide on finish. Keep the
      non-activating panel behavior so focus isn't stolen (paste must work).
- [ ] **Learning dictionary** (`Corrections.swift`): move to `DriftKit` (pure
      logic), apply in `Pipeline` after cleanup, and add the "Correct Last
      Dictation" UI to the menu/settings.
- [ ] **Persistent log** (`DriftDebug.swift` -> `DriftLog`): move to DriftKit or
      DriftApp; keep the per-dictation summary line + "Open Log".
- [ ] **Permissions**: `main`'s `AppState` already handles Mic + Accessibility.
      ADD **Input Monitoring** (`IOHIDCheckAccess` / `IOHIDRequestAccess`) and the
      live-trust polling. Reference: interim `InterimAppDelegate.refreshPermissions`.

## Do NOT port (interim-only scaffolding)

- `WhisperServerManager`, `WhisperServerTranscriber`, `WhisperCppTranscriber`,
  `WavWriter` — `main` uses WhisperKit in-process.
- `curl` comms — no HTTP on `main`, so the ATS workaround is moot.
- `scripts/dev-build-clt.sh`, `scripts/dev-setup-clt.sh` — `main` uses
  `bootstrap.sh` + Xcode.
- The single-module `swiftc` build and the `Hotkey.swift` import tweak.

## Lessons that still apply on `main`

- Stable signing for dev so TCC grants survive rebuilds (Developer ID for
  release; a self-signed cert for local dev).
- Push-to-talk needs Input Monitoring, paste needs Accessibility.
- Default model `large-v3-turbo` for accented English. On WhisperKit the speed
  comes from the Neural Engine, so the `-ac`/server tuning is interim-only.

## Decision to make

Keep `whisper.cpp` as a **second, selectable backend** (works on any Mac without
Xcode) behind the `Transcriber` protocol, or drop it once WhisperKit ships.
Keeping it makes this branch's work permanent, not a detour.
