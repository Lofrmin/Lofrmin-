"""白鹭湾演示配置读写。

把飞书 Webhook 与高德 Key 存到 server/.runtime/demo-config.json，
启动器读取后注入网关环境变量，避免每次手工 set。
"""
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "server" / ".runtime" / "demo-config.json"
DEFAULT_WEBHOOK = "https://open.feishu.cn/open-apis/bot/v2/hook/5f3365c5-e58c-44a1-8b48-62b5312e449e"


def load() -> dict:
    if CONFIG.exists():
        try:
            data = json.loads(CONFIG.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return data
        except (OSError, ValueError):
            pass
    return {}


def save(values: dict) -> None:
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    current = load()
    current.update({key: value for key, value in values.items() if value is not None})
    tmp = CONFIG.with_suffix(".tmp")
    tmp.write_text(json.dumps(current, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, CONFIG)


def resolve() -> dict:
    """环境变量优先，其次本地配置，最后内置飞书 Webhook。"""
    saved = load()
    return {
        "webhook": os.environ.get("COFFEE_WEBHOOK_URL") or saved.get("webhook") or DEFAULT_WEBHOOK,
        "amap": os.environ.get("AMAP_WEB_KEY") or saved.get("amap") or "",
    }
