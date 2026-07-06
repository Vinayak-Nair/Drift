#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.venv-indic-conformer}"
PYTHON="${PYTHON:-python3}"

"$PYTHON" -m venv "$ROOT"
"$ROOT/bin/python" -m pip install --upgrade pip
"$ROOT/bin/python" -m pip install \
  transformers \
  torch \
  torchaudio \
  huggingface_hub \
  "onnx==1.20.1" \
  "onnxruntime==1.20.1"

cat <<MSG

IndicConformer Python environment is ready.

1. Accept the gated model:
   https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual

2. Log in so transformers can download it:
   $ROOT/bin/huggingface-cli login

3. In Drift Settings, select "AI4Bharat IndicConformer" and set Python path to:
   $(pwd)/$ROOT/bin/python

MSG
