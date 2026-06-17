#!/usr/bin/env python3
"""Download the Parakeet v3 CoreML model subset that Drift bundles in releases.

This mirrors what FluidAudio's `AsrModels.downloadAndLoad(version: .v3)` lays
down in the local model cache, so `scripts/release.sh` can copy it into the app
bundle. The HF repo also contains other model variants and uncompiled
`.mlpackage`s — we deliberately fetch only the files the v3 inference path needs.

Destination and repo are read from the environment (set in
`.github/workflows/release.yml`).
"""
import os

from huggingface_hub import snapshot_download

repo_id = os.environ.get("MODEL_REPO", "FluidInference/parakeet-tdt-0.6b-v3-coreml")
dir_name = os.environ.get("MODEL_DIR_NAME", "parakeet-tdt-0.6b-v3")
dest = os.path.join(os.environ["RUNNER_TEMP"], "fluidaudio", dir_name)

snapshot_download(
    repo_id=repo_id,
    local_dir=dest,
    allow_patterns=[
        "config.json",
        "parakeet_v3_vocab.json",
        "parakeet_vocab.json",
        "Encoder.mlmodelc/*",
        "Decoder.mlmodelc/*",
        "JointDecisionv3.mlmodelc/*",
        "Preprocessor.mlmodelc/*",
    ],
)
print(f"Downloaded {repo_id} subset -> {dest}")
