"""白鹭咖啡演示一键启动器。

1. 若 18082 网关已在运行则复用；
2. 否则用当前 Python 启动网关并等待 /health；
3. 用正式商户模式启动 NeuroDesk（复用根目录 CMD）。
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
DATA = ROOT / "web" / ".runtime"
LOG = DATA / "bailu-gateway.out.log"
HEALTH = "http://127.0.0.1:18082/health"

sys.path.insert(0, str(ROOT / "server"))
import demo_config  # noqa: E402


def healthy() -> bool:
    try:
        with urllib.request.urlopen(HEALTH, timeout=1) as response:
            return response.status == 200
    except OSError:
        return False


def main() -> int:
    DATA.mkdir(parents=True, exist_ok=True)
    settings = demo_config.resolve()
    if not healthy():
        log = LOG.open("w", encoding="utf-8")
        env = {
            **os.environ,
            "BAILU_PORT": "18082",
            "BAILU_DATA_DIR": str(ROOT / "server" / ".runtime"),
            "COFFEE_WEBHOOK_URL": settings["webhook"],
            "AMAP_WEB_KEY": settings["amap"],
            "PYTHONUNBUFFERED": "1",
        }
        subprocess.Popen(
            [sys.executable, str(SERVER)],
            cwd=str(ROOT), env=env, stdout=log, stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
        )
        for _ in range(120):
            if healthy():
                break
            time.sleep(0.25)
        else:
            print(f"Gateway failed to start. See {LOG}")
            return 1
    print("Bailu Coffee Gateway ready: http://127.0.0.1:18082/api")
    print(f"  飞书电子小票: {'已启用' if settings['webhook'] else '未配置'}")
    print(f"  高德真实门店: {'已启用' if settings['amap'] else '未配置（使用内置门店）'}")
    print("Starting NeuroDesk merchant mode...")
    env = {
        **os.environ,
        "NEURODESK_COFFEE_API": "http://127.0.0.1:18082/api",
        "NEURODESK_COFFEE_TOKEN": "bailu-2026-secret",
        "NEURODESK_COFFEE_DEMO": "0",
        "NEURODESK_COFFEE_LOCATION": "bailu",
        # A saved Luckin token must never override this merchant adapter.
        "NEURODESK_COFFEE_PROVIDER": "adapter",
    }
    launch = ROOT / "启动NeuroDesk.cmd"
    subprocess.Popen(["cmd.exe", "/d", "/c", str(launch)], cwd=str(ROOT), env=env)
    print("NeuroDesk launch requested. Keep this window or close it; the gateway runs independently.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
