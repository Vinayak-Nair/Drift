#!/usr/bin/env python3
import argparse
import json
import os
import sys
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def load_model(model_id, cache_dir):
    try:
        from transformers import AutoModel
    except Exception as exc:
        raise RuntimeError(
            "Missing dependency 'transformers'. Install Drift's IndicConformer "
            "Python dependencies first."
        ) from exc

    token = os.environ.get("HF_TOKEN") or None
    kwargs = {
        "trust_remote_code": True,
        "cache_dir": cache_dir,
    }
    if token:
        kwargs["token"] = token
    return AutoModel.from_pretrained(model_id, **kwargs)


def load_audio(path):
    try:
        import torch
        import torchaudio
    except Exception as exc:
        raise RuntimeError(
            "Missing dependencies 'torch' and 'torchaudio'. Install Drift's "
            "IndicConformer Python dependencies first."
        ) from exc

    wav, sr = torchaudio.load(path)
    if wav.shape[0] > 1:
        wav = torch.mean(wav, dim=0, keepdim=True)
    if sr != 16000:
        wav = torchaudio.transforms.Resample(orig_freq=sr, new_freq=16000)(wav)
    return wav


class Handler(BaseHTTPRequestHandler):
    model = None

    def do_GET(self):
        if self.path != "/health":
            self.send_json({"error": "not found"}, status=404)
            return
        self.send_json({"status": "ok"})

    def do_POST(self):
        if self.path != "/transcribe":
            self.send_json({"error": "not found"}, status=404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length)
            payload = json.loads(body.decode("utf-8"))
            audio_path = payload["audioPath"]
            language = payload["language"]
            decoder = payload.get("decoder", "ctc")
            if decoder not in ("ctc", "rnnt"):
                raise ValueError("decoder must be 'ctc' or 'rnnt'")
            if not os.path.exists(audio_path):
                raise FileNotFoundError(audio_path)

            wav = load_audio(audio_path)
            text = Handler.model(wav, language, decoder)
            self.send_json({"text": str(text)})
        except Exception as exc:
            traceback.print_exc()
            self.send_json({"error": str(exc)}, status=500)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def send_json(self, payload, status=200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model-id", default="ai4bharat/indic-conformer-600m-multilingual")
    parser.add_argument("--cache-dir", required=True)
    args = parser.parse_args()

    os.makedirs(args.cache_dir, exist_ok=True)
    print(f"Loading {args.model_id}...", flush=True)
    Handler.model = load_model(args.model_id, args.cache_dir)
    print("READY", flush=True)

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
