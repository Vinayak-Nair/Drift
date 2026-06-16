#!/usr/bin/env bash
# INTERIM ONLY (interim-whisper-cpp branch): installs whisper.cpp + a model so
# the swiftc-built Drift.app can transcribe without Xcode/WhisperKit.
set -euo pipefail

MODEL="${1:-large-v3-turbo-q5_0}"   # multilingual incl. Indian languages, ~570 MB
DIR="$HOME/.drift/models"
FILE="$DIR/ggml-${MODEL}.bin"

echo "==> whisper.cpp"
if command -v whisper-cli >/dev/null 2>&1 || command -v whisper-cpp >/dev/null 2>&1; then
  echo "    already installed"
else
  command -v brew >/dev/null 2>&1 || { echo "!! Install Homebrew first: https://brew.sh" >&2; exit 1; }
  brew install whisper-cpp
fi

mkdir -p "$DIR"
if [ -f "$FILE" ]; then
  echo "==> model present: $FILE"
else
  echo "==> downloading ggml-${MODEL}.bin (~570 MB)…"
  curl -L --fail -o "$FILE" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
fi

echo ""
echo "Done."
echo "  binary: $(command -v whisper-cli || command -v whisper-cpp)"
echo "  model:  $FILE"
