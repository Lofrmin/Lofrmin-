"""常驻的本地 TTS 服务（sherpa-onnx）。

支持两套离线引擎：
  - piper:  VITS 模型，速度极快（RTF ≈ 0.26），用于实时对话
  - kokoro: Kokoro 模型，音质更好但较慢（RTF ≈ 1.8），可按需切换

模型只加载一次，Electron 主进程通过 HTTP 调用。
用法: python tts_server.py --model-dir <dir> --engine piper|kokoro --port 18090
"""
from __future__ import annotations

import argparse
import array
import io
import json
import os
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import sherpa_onnx


def build_piper(model_dir: str, num_threads: int = 4, provider: str = "cpu"):
    """Piper 中文模型：目录里是 zh_CN-<voice>.onnx，没有 model.onnx。"""
    model = None
    for name in sorted(os.listdir(model_dir)):
        if name.endswith(".onnx"):
            model = os.path.join(model_dir, name)
            break
    if not model:
        raise FileNotFoundError(f"no .onnx model in {model_dir}")
    vits = sherpa_onnx.OfflineTtsVitsModelConfig(
        model=model,
        tokens=os.path.join(model_dir, "tokens.txt"),
        lexicon=os.path.join(model_dir, "lexicon.txt"),
    )
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=vits, num_threads=num_threads, provider=provider
        ),
        max_num_sentences=1,
    )
    return sherpa_onnx.OfflineTts(config)


def build_kokoro(model_dir: str, num_threads: int = 4, provider: str = "cpu"):
    model = None
    for name in ("model.int8.onnx", "model.onnx", "model.q8.onnx"):
        if os.path.exists(os.path.join(model_dir, name)):
            model = os.path.join(model_dir, name)
            break
    if not model:
        raise FileNotFoundError(f"no kokoro model in {model_dir}")
    kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig(
        model=model,
        voices=os.path.join(model_dir, "voices.bin"),
        tokens=os.path.join(model_dir, "tokens.txt"),
        lexicon=os.path.join(model_dir, "lexicon-zh.txt"),
    )
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            kokoro=kokoro, num_threads=num_threads, provider=provider
        ),
        max_num_sentences=1,
    )
    return sherpa_onnx.OfflineTts(config)


def to_wav(samples, sample_rate) -> bytes:
    pcm = array.array(
        "h", [max(-32768, min(32767, int(s * 32767))) for s in samples]
    ).tobytes()
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(pcm)
    return buffer.getvalue()


class Handler(BaseHTTPRequestHandler):
    tts = None
    engine = "piper"

    def log_message(self, *args):
        pass

    def _json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/health"):
            self._json(200, {"ok": True, "engine": self.engine})
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        if not self.path.startswith("/speak"):
            self._json(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            request = json.loads(self.rfile.read(length) or b"{}")
            text = str(request.get("text", "")).strip()
            if not text:
                self._json(400, {"error": "empty text"})
                return
            sid = int(request.get("sid", 0))
            speed = float(request.get("speed", 1.0))
            audio = self.tts.generate(text, sid=sid, speed=speed)
            wav = to_wav(audio.samples, audio.sample_rate)
            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Content-Length", str(len(wav)))
            self.end_headers()
            self.wfile.write(wav)
        except Exception as error:
            self._json(500, {"error": str(error)[:300]})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True)
    parser.add_argument("--engine", default="piper", choices=["piper", "kokoro"])
    parser.add_argument("--port", type=int, default=18090)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--provider", default="cpu")
    args = parser.parse_args()

    builder = build_piper if args.engine == "piper" else build_kokoro
    Handler.tts = builder(args.model_dir, args.threads, args.provider)
    Handler.engine = args.engine
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"{args.engine} tts ready on http://127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
