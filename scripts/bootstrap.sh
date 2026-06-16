#!/usr/bin/env bash
# Contributor setup: generates the Xcode project and resolves dependencies.
# End users do NOT need this; they just download Drift.app from Releases.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Drift bootstrap"

# Full Xcode is required (Command Line Tools alone cannot build the app or
# resolve the WhisperKit package on this setup).
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "!! Full Xcode is required (Command Line Tools are not enough)." >&2
  echo "   1. Install Xcode 16+ from the App Store (or an external SSD if low on disk)." >&2
  echo "   2. sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "   3. Re-run this script." >&2
  exit 1
fi

# XcodeGen turns project.yml into Drift.xcodeproj.
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> Installing XcodeGen via Homebrew"
    brew install xcodegen
  elif command -v mint >/dev/null 2>&1; then
    echo "==> Installing XcodeGen via Mint"
    mint install yonaskolb/xcodegen
  else
    echo "!! XcodeGen not found. Install Homebrew (https://brew.sh), then: brew install xcodegen" >&2
    exit 1
  fi
fi

echo "==> Generating Drift.xcodeproj"
xcodegen generate

echo "==> Resolving Swift package dependencies (downloads WhisperKit)"
xcodebuild -resolvePackageDependencies -project Drift.xcodeproj -scheme Drift >/dev/null

echo ""
echo "Done. Next:"
echo "  open Drift.xcodeproj   then press Run (Cmd+R)"
echo "or build from the CLI:"
echo "  xcodebuild -project Drift.xcodeproj -scheme Drift -configuration Debug build"
