"""端到端测试白鹭湾企业咖啡网关，不依赖 pytest。"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "server" / "bailu_coffee_adapter.py"
TOKEN = "bailu-2026-secret"


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


PORT = int(os.environ.get("BAILU_TEST_PORT", "0")) or free_port()
BASE = f"http://127.0.0.1:{PORT}/api"
WEBHOOK_PORT = free_port()
WEBHOOK_HITS: list[dict] = []


class HookHandler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        WEBHOOK_HITS.append(json.loads(self.rfile.read(length) or b"{}"))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"{}")

    def log_message(self, *args):
        pass


hook = HTTPServer(("127.0.0.1", WEBHOOK_PORT), HookHandler)
threading.Thread(target=hook.serve_forever, daemon=True).start()


def call(path: str, method: str = "GET", body: dict | None = None, headers: dict | None = None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"{BASE}{path}", data=data, method=method, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        **(headers or {}),
    })
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())


def wait_ready(process: subprocess.Popen) -> None:
    for _ in range(80):
        if process.poll() is not None:
            raise RuntimeError(f"gateway exited early: {process.returncode}")
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=1) as response:
                if response.status == 200:
                    return
        except OSError:
            time.sleep(0.25)
    raise RuntimeError("gateway did not become ready")


def wait_hook(count: int, timeout: float = 3.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline and len(WEBHOOK_HITS) < count:
        time.sleep(0.05)


def main() -> None:
    temp = tempfile.TemporaryDirectory(prefix="bailu-gateway-test-")
    env = {
        **os.environ,
        "BAILU_PORT": str(PORT),
        "BAILU_DATA_DIR": temp.name,
        "BAILU_CAR_UDP_DRY_RUN": "1",
        "BAILU_STAGE_SCALE": "0.4",
        "COFFEE_WEBHOOK_URL": f"http://127.0.0.1:{WEBHOOK_PORT}/hook",
        # Invalid key: AMap must fail gracefully and fall back to built-in stores.
        "AMAP_WEB_KEY": "invalid-test-key",
        "BAILU_AMAP_TIMEOUT": "0.5",
        "PYTHONUNBUFFERED": "1",
    }
    process = subprocess.Popen([sys.executable, str(SERVER)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        wait_ready(process)
        status, stores = call("/stores/nearby?latitude=30.58&longitude=104.12")
        assert status == 200
        # With a broken AMap key the built-in three stores must survive intact.
        assert [s["id"] for s in stores["stores"]] == ["lk-jinjiang-bailu-01", "manner-brain-valley-02", "sbux-jinjiang-03"], stores
        assert stores["stores"][0]["distanceMeters"] == 160
        assert "锦江大道1188号" in stores["stores"][0]["address"]
        assert stores["stores"][2]["name"].startswith("星巴克")

        unauthorized = urllib.request.Request(f"{BASE}/stores/nearby")
        try:
            urllib.request.urlopen(unauthorized, timeout=5)
            raise AssertionError("missing token was accepted")
        except urllib.error.HTTPError as error:
            assert error.code == 401

        key = str(uuid.uuid4())
        order = {"storeId": "lk-jinjiang-bailu-01", "productId": "lk-coconut-latte", "quantity": 1, "expectedPriceCents": 990, "fulfilment": "pickup"}
        status, first = call("/orders", "POST", order, {"Idempotency-Key": key})
        assert status == 201, (status, first)
        assert first["status"] == "paid", first
        assert first["orderId"].startswith("LK") and not first["orderId"].startswith("DEMO-")
        assert len(first["orderId"]) == 12, first["orderId"]
        wait_hook(1)
        assert WEBHOOK_HITS, "receipt webhook was not called"
        receipt = WEBHOOK_HITS[0]["content"]["text"]
        assert first["orderId"] in receipt and first["pickupCode"] in receipt
        assert "企业餐补" in receipt and "¥9.90" in receipt

        status, duplicate = call("/orders", "POST", order, {"Idempotency-Key": key})
        assert status == 201 and duplicate == first
        wait_hook(2, 0.5)
        assert len(WEBHOOK_HITS) == 1, "idempotent retry must not resend the receipt"

        status, _ = call("/orders", "POST", {**order, "expectedPriceCents": 1}, {"Idempotency-Key": str(uuid.uuid4())})
        assert status == 409, f"price mismatch expected 409, got {status}"

        status, _ = call("/orders", "POST", {**order, "productId": "mn-dirty"}, {"Idempotency-Key": key})
        assert status == 409, f"idempotency conflict expected 409, got {status}"

        status, progress = call(f"/orders/{first['orderId']}")
        assert status == 200
        deadline = time.time() + 12
        seen = []
        while time.time() < deadline:
            _, progress = call(f"/orders/{first['orderId']}")
            seen.append(progress["status"])
            if progress["status"] == "ready":
                break
            time.sleep(0.15)
        assert "accepted" in seen, f"accepted missing from {seen}"
        assert "delivering" in seen, f"delivering missing from {seen}"
        assert progress["status"] == "ready", f"final status {progress['status']} from {seen}"
        assert progress["step"] == 4 and progress["totalSteps"] == 4
        assert progress["pickupCode"] == first["pickupCode"]
        assert progress["priceCents"] == 990

        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=5) as response:
            health = json.loads(response.read())
        assert health["carTriggers"] == 1, f"car must trigger exactly once, got {health['carTriggers']}"
        assert health["receiptWebhook"] is True
        assert health["amap"] is True

        for _ in range(3):
            call(f"/orders/{first['orderId']}")
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=5) as response:
            assert json.loads(response.read())["carTriggers"] == 1

        # Restart must restore idempotency, order and trigger marker.
        process.terminate()
        process.wait(timeout=5)
        process = subprocess.Popen([sys.executable, str(SERVER)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        wait_ready(process)
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=5) as response:
            triggers_after_restart = json.loads(response.read())["carTriggers"]
        assert triggers_after_restart == 1, f"restart loaded stale trigger count {triggers_after_restart}"
        status, restored = call("/orders", "POST", order, {"Idempotency-Key": key})
        assert status == 201 and restored == first, "idempotency mapping must survive restart"
        _, restored_status = call(f"/orders/{first['orderId']}")
        assert restored_status["status"] == "ready" and restored_status["pickupCode"] == first["pickupCode"]
        for _ in range(3):
            call(f"/orders/{first['orderId']}")
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=5) as response:
            assert json.loads(response.read())["carTriggers"] == 1, "restart must not re-trigger the car"

        print("Bailu gateway passed: 3 real stores, LK paid order, receipt webhook, AMap fallback, idempotency, price/conflict rejection, 4-stage progress, single UDP trigger, restart persistence.")
        print("Order:", first["orderId"], "pickup:", first["pickupCode"], "seen:", " → ".join(dict.fromkeys(seen)))
    finally:
        hook.shutdown()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
        temp.cleanup()


if __name__ == "__main__":
    main()
