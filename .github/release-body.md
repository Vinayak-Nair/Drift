**Local-first voice dictation for macOS.** Hold **Right Option (⌥)**, speak, and cleaned-up text is typed into whatever app you're in. Transcription and cleanup run entirely on your Mac — no account, no API key, nothing uploaded.

## Install

1. Download **`Drift.dmg`** below and open it.
2. Drag **Drift** into your **Applications** folder.
3. **First launch (one-time):** this build isn't notarized by Apple, so macOS Gatekeeper blocks it the first time. **Right-click (Control-click) Drift.app → Open**, then click **Open** in the dialog.
   - Or from Terminal: `xattr -dr com.apple.quarantine /Applications/Drift.app`
4. Grant **Microphone** and **Accessibility** when asked.
5. Click into any text field, **hold Right Option (⌥)**, speak, and release.

## What's included

- **Bundled FluidAudio Parakeet v3** English model — dictation works instantly on first run, no extra download.
- **Universal binary** — Apple Silicon and Intel.

Requires **macOS 14 (Sonoma)** or later. This build is ad-hoc signed (not notarized) — Drift is fully open source, so you can also build it yourself from source.

---
