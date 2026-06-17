#!/usr/bin/env bash
# Builds a distributable Drift.dmg. Signs and notarizes when credentials are set.
#
# One-time notarization setup:
#   xcrun notarytool store-credentials drift-notary \
#     --apple-id "you@example.com" --team-id TEAMID --password APP_SPECIFIC_PW
#
# Then run:
#   DEV_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="drift-notary" ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME=Drift
CONFIG=Release
BUILD=build
ARCHIVE="$BUILD/Drift.xcarchive"
APP="$BUILD/export/Drift.app"
DMG="$BUILD/Drift.dmg"

command -v xcodegen >/dev/null 2>&1 || { echo "Run scripts/bootstrap.sh first." >&2; exit 1; }
xcodegen generate

echo "==> Archiving"
xcodebuild -project Drift.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -archivePath "$ARCHIVE" archive

echo "==> Exporting app"
mkdir -p "$BUILD/export"
rm -rf "$APP"
cp -R "$ARCHIVE/Products/Applications/Drift.app" "$BUILD/export/"

# Bundle the default English model (Parakeet v3) so first-run dictation needs no
# download. Source defaults to the local model cache; run the app once to populate
# it, or point MODEL_CACHE at a directory containing the parakeet-tdt-0.6b-v3 folder.
MODEL_CACHE="${MODEL_CACHE:-$HOME/Library/Application Support/Drift/models/FluidAudio}"
MODEL_DIR="$MODEL_CACHE/parakeet-tdt-0.6b-v3"
if [ -d "$MODEL_DIR" ]; then
  echo "==> Bundling model from $MODEL_DIR"
  DEST="$APP/Contents/Resources/BundledModels/FluidAudio"
  mkdir -p "$DEST"
  cp -R "$MODEL_DIR" "$DEST/"
else
  echo "   (No model at $MODEL_DIR: shipping without a bundled model;"
  echo "    users will download it on first run. Set MODEL_CACHE to bundle it.)"
fi

if [ -n "${DEV_ID:-}" ]; then
  echo "==> Signing with Developer ID + hardened runtime"
  codesign --force --options runtime --deep --sign "$DEV_ID" "$APP"
else
  echo "   (DEV_ID not set: ad-hoc signing. Distributable but not notarizable.)"
  codesign --force --deep --sign - "$APP"
fi

echo "==> Building DMG"
rm -f "$DMG"
hdiutil create -volname Drift -srcfolder "$APP" -ov -format UDZO "$DMG"

if [ -n "${NOTARY_PROFILE:-}" ] && [ -n "${DEV_ID:-}" ]; then
  echo "==> Notarizing (this can take a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
else
  echo "   (Notarization skipped: set DEV_ID and NOTARY_PROFILE to enable.)"
fi

echo ""
echo "Done: $DMG"
