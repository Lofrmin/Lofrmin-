"""配置飞书电子小票 Webhook 与高德 Web 服务 Key。

用法:
  python server/setup_demo_config.py --webhook <URL>
  python server/setup_demo_config.py --amap <KEY>
  python server/setup_demo_config.py --show
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import demo_config  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="配置白鹭湾演示 Webhook / 高德 Key")
    parser.add_argument("--webhook", help="飞书/企微/Bark Webhook URL")
    parser.add_argument("--amap", help="高德 Web 服务 Key")
    parser.add_argument("--show", action="store_true", help="显示当前配置")
    args = parser.parse_args()

    values = {}
    if args.webhook:
        if not args.webhook.startswith(("https://", "http://")):
            print("Webhook 必须以 http:// 或 https:// 开头")
            return 1
        values["webhook"] = args.webhook.strip()
    if args.amap:
        values["amap"] = args.amap.strip()
    if values:
        demo_config.save(values)
        print("已保存到", demo_config.CONFIG)

    resolved = demo_config.resolve()
    masked = {key: (value[:12] + "…" + value[-4:] if len(value) > 20 else value) for key, value in resolved.items()}
    print(json.dumps({"config": str(demo_config.CONFIG), "effective": masked}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
