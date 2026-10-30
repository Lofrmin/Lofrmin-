"""启动/复用白鹭湾网关供其他测试使用。

用法:
  python tests/bailu_fixture.py start   # 打印端口后保持进程
  python tests/bailu_fixture.py ensure  # 已运行则立即退出，否则启动
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "server" / "bailu_coffee_adapter.py"
PORT = int(os.environ.get("BAILU_TEST_PORT", "18182"))
HEALTH = f"http://127.0.0.1:{PORT}/health"


def healthy() -> bool:
    try:
        with urllib.request.urlopen(HEALTH, timeout=1) as response:
            return response.status == 200
    except OSError:
        return False


def ensure() -> subprocess.Popen | None:
    if healthy():
        return None
    env = {
        **os.environ,
        "BAILU_PORT": str(PORT),
        "BAILU_DATA_DIR": str(ROOT / "server" / ".runtime-test"),
        "BAILU_CAR_UDP_DRY_RUN": "1",
        "BAILU_STAGE_SCALE": "0.05",
        "PYTHONUNBUFFERED": "1",
    }
    process = subprocess.Popen([sys.executable, str(SERVER)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(120):
        if process.poll() is not None:
            raise RuntimeError("bailu gateway exited during startup")
        if healthy():
            return process
        time.sleep(0.25)
    process.kill()
    raise RuntimeError("bailu gateway did not become ready")


if __name__ == "__main__":
    if sys.argv[1:] == ["ensure"]:
        started = ensure()
        print(json.dumps({"port": PORT, "started": started is not None}))
        if started:
            try:
                started.wait()
            except KeyboardInterrupt:
                started.terminate()
    else:
        process = ensure()
        print(f"BAILU_GATEWAY_READY={PORT}")
        if process:
            try:
                process.wait()
            except KeyboardInterrupt:
                process.terminate()
