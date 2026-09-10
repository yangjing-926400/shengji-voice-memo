#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "app"
TRANSCRIBER_APP = ROOT / "server" / "SpeechTranscriber.app"
HOST = "127.0.0.1"
PORT = int(os.environ.get("SHENGJI_PORT", "4174"))
MAX_AUDIO_BYTES = 30 * 1024 * 1024


class ShengjiHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(APP_DIR), **kwargs)

    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args), flush=True)

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/transcribe":
            self.send_error(HTTPStatus.NOT_FOUND, "Not found")
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            content_length = 0

        if content_length <= 0 or content_length > MAX_AUDIO_BYTES:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "音频为空或文件过大"})
            return

        audio_bytes = self.rfile.read(content_length)
        query = parse_qs(urlparse(self.path).query)
        suffix = (query.get("ext", ["wav"])[0] or "wav").lower()
        if suffix not in {"wav", "m4a", "mp4", "aac", "webm", "audio"}:
            suffix = "audio"
        audio_path = None
        result_path = None
        started_at = time.time()

        try:
            with tempfile.NamedTemporaryFile(prefix="shengji-", suffix=f".{suffix}", delete=False) as audio_file:
                audio_file.write(audio_bytes)
                audio_path = audio_file.name

            with tempfile.NamedTemporaryFile(prefix="shengji-result-", suffix=".json", delete=False) as result_file:
                result_path = result_file.name

            completed = subprocess.run(
                [
                    "/usr/bin/open",
                    "-W",
                    "-n",
                    str(TRANSCRIBER_APP),
                    "--args",
                    audio_path,
                    result_path,
                ],
                capture_output=True,
                text=True,
                timeout=70,
            )

            if result_path and Path(result_path).exists():
                raw = Path(result_path).read_text(encoding="utf-8").strip()
                result = json.loads(raw) if raw else {}
            else:
                result = {}

            if not result:
                message = completed.stderr.strip() or "语音识别服务没有返回结果"
                self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": message})
                return

            if result.get("error"):
                self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, result)
                return

            result["durationMs"] = int((time.time() - started_at) * 1000)
            self._send_json(HTTPStatus.OK, result)
        except subprocess.TimeoutExpired:
            self._send_json(HTTPStatus.GATEWAY_TIMEOUT, {"error": "语音识别超时，请重试"})
        except Exception as error:
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(error)})
        finally:
            for path in (audio_path, result_path):
                if path:
                    try:
                        Path(path).unlink()
                    except OSError:
                        pass

    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    if not TRANSCRIBER_APP.exists():
        raise SystemExit("缺少 SpeechTranscriber.app，请先运行 server/build-speech-transcriber.sh")
    print(f"声记服务：http://{HOST}:{PORT}/")
    print(f"语音模型：{TRANSCRIBER_APP}")
    server = ThreadingHTTPServer((HOST, PORT), ShengjiHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
