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

# AppKit shell (no SwiftUI): shared AppKit helpers + everything under Interim/.
APPFILES="
  Sources/DriftApp/Hotkey.swift
  Sources/DriftApp/Paster.swift
  Sources/DriftApp/Feedback.swift
  $(find Sources/DriftApp/Interim -name '*.swift')
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

# Prefer a stable self-signed identity so TCC permission grants (Input Monitoring,
# Accessibility) survive rebuilds. Falls back to ad-hoc if the cert isn't present.
SIGN_ID="Drift Dev Cert"
if ! security find-certificate -c "$SIGN_ID" >/dev/null 2>&1; then
  echo "    (stable cert '$SIGN_ID' not found; falling back to ad-hoc signing)"
  SIGN_ID="-"
fi
codesign --force --deep --sign "$SIGN_ID" "$APP" >/dev/null 2>&1 || echo "    (codesign skipped)"

# Install into /Applications so the path (and TCC permission grants) are stable.
echo "==> Installing to /Applications/Drift.app"
pkill -x Drift 2>/dev/null || true
sleep 1
rm -rf /Applications/Drift.app
cp -R "$APP" /Applications/Drift.app
codesign --force --deep --sign "$SIGN_ID" /Applications/Drift.app >/dev/null 2>&1 || true

echo ""
echo "Built and installed: /Applications/Drift.app"
echo "Run:   open /Applications/Drift.app"
