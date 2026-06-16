#!/usr/bin/env bash
# INTERIM ONLY (interim-whisper-cpp branch): builds Drift.app with swiftc, no
# Xcode/SwiftPM. Compiles DriftKit core (minus the WhisperKit files) plus the
# AppKit interim shell as a single module. The SwiftUI app and WhisperKit files
# are intentionally excluded.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Drift.app"
CONTENTS="$APP/Contents"
ARCH="$(uname -m)"
mkdir -p build

# DriftKit core, excluding files that import WhisperKit (need Xcode/SwiftPM).
KIT=$(find Sources/DriftKit -name '*.swift' \
  ! -name 'WhisperKitTranscriber.swift' \
  ! -name 'ModelManager.swift')

# AppKit shell (no SwiftUI).
APPFILES="
  Sources/DriftApp/Hotkey.swift
  Sources/DriftApp/Paster.swift
  Sources/DriftApp/Feedback.swift
  Sources/DriftApp/Interim/WhisperCppTranscriber.swift
  Sources/DriftApp/Interim/InterimAppDelegate.swift
  Sources/DriftApp/Interim/main.swift
"

echo "==> Compiling (swiftc)"
# shellcheck disable=SC2086
swiftc -O -o build/Drift $KIT $APPFILES \
  -framework AppKit -framework AVFoundation -framework ApplicationServices \
  -target "${ARCH}-apple-macosx13.0"

echo "==> Bundling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
cp build/Drift "$CONTENTS/MacOS/Drift"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Drift</string>
    <key>CFBundleDisplayName</key>     <string>Drift</string>
    <key>CFBundleIdentifier</key>      <string>com.drift.app</string>
    <key>CFBundleExecutable</key>      <string>Drift</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.1.0-interim</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Drift records your voice to transcribe it into text.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
  echo "    (ad-hoc codesign skipped)"

echo ""
echo "Built: $APP"
echo "Run:   open $APP"
