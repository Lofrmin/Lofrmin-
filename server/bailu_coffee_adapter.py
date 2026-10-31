"""白鹭湾科技生态园企业咖啡网关（真实门店 + 手机小票 + 无人车联动）。

实现桌面端 README 约定的三个接口：
  GET  /api/stores/nearby
  POST /api/orders
  GET  /api/orders/{order_id}

订单进入 delivering（第 3 阶段）时，通过 UDP 广播向 ESP32-S3 发送一次
CAR_RUN:<取餐码>。门店、餐补直付与订单均为本机商户网关模拟，
不会调用真实瑞幸/星巴克接口，也不会产生真实扣款。

运行:
  python server/bailu_coffee_adapter.py
配置:
  BAILU_COFFEE_TOKEN       Bearer token，默认 bailu-2026-secret
  BAILU_PORT               HTTP 端口，默认 18082
  BAILU_CAR_UDP_PORT       UDP 端口，默认 8888
  BAILU_CAR_UDP_DRY_RUN    1 时不真正广播，只记录日志
  BAILU_STAGE_SCALE       状态时间缩放，测试用，默认 1.0
  BAILU_DATA_DIR           订单持久化目录，默认 server/.runtime
  COFFEE_WEBHOOK_URL       飞书/企业微信/Bark Webhook，下单即推送电子小票
  AMAP_WEB_KEY             高德 Web 服务 Key，启用真实周边咖啡 POI
  BAILU_AMAP_TIMEOUT       高德请求超时秒数，默认 3.0
"""
from __future__ import annotations

import hmac
import json
import logging
import os
import socket
import threading
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

import httpx
from fastapi import FastAPI, Header, HTTPException, Query
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("BAILU_DATA_DIR", ROOT / ".runtime"))
DATA_DIR.mkdir(parents=True, exist_ok=True)
ORDER_FILE = DATA_DIR / "bailu_orders.json"
LOG_FILE = DATA_DIR / "gateway.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(), logging.FileHandler(LOG_FILE, encoding="utf-8")],
)
log = logging.getLogger("bailu-coffee")

EXPECTED_TOKEN = os.environ.get("BAILU_COFFEE_TOKEN", "bailu-2026-secret")
UDP_PORT = int(os.environ.get("BAILU_CAR_UDP_PORT", "8888"))
UDP_DRY_RUN = os.environ.get("BAILU_CAR_UDP_DRY_RUN", "0") == "1"
STAGE_SCALE = max(0.01, float(os.environ.get("BAILU_STAGE_SCALE", "1")))
STAGE_LIMITS = (3.0 * STAGE_SCALE, 6.5 * STAGE_SCALE, 12.0 * STAGE_SCALE)
WEBHOOK_URL = os.environ.get("COFFEE_WEBHOOK_URL", "").strip()
AMAP_KEY = os.environ.get("AMAP_WEB_KEY", "").strip()
AMAP_TIMEOUT = max(0.5, float(os.environ.get("BAILU_AMAP_TIMEOUT", "3.0")))

# 白鹭湾科技生态园 / 西部脑谷周边门店库，价格以“分”为单位。
STORES = [
    {
        "id": "lk-jinjiang-bailu-01",
        "name": "luckin coffee 瑞幸咖啡（白鹭湾科技生态园店）",
        "address": "成都市锦江区锦江大道1188号白鹭湾科技生态园A区1栋1层 · 脑谷无人车1号接驳点",
        "distanceMeters": 160,
        "products": [
            {"id": "lk-coconut-latte", "name": "生椰拿铁（大杯·少冰·不另外加糖）[企业餐补直付]", "priceCents": 990, "available": True},
            {"id": "lk-ice-americano", "name": "标准美式（大杯·冰·无糖）[提神首选]", "priceCents": 990, "available": True},
            {"id": "lk-orange-americano", "name": "橙C美式（大杯·冰·标准糖）", "priceCents": 1290, "available": True},
        ],
    },
    {
        "id": "manner-brain-valley-02",
        "name": "Manner Coffee（锦江西部脑谷中心站）",
        "address": "成都市锦江经济开发区西部脑谷B座连廊1F · 园区无人配送站",
        "distanceMeters": 290,
        "products": [
            {"id": "mn-oat-latte", "name": "燕麦拿铁（中杯·热·自带杯减免）", "priceCents": 1500, "available": True},
            {"id": "mn-dirty", "name": "冰博客Dirty（中杯·冰）", "priceCents": 2000, "available": True},
        ],
    },
    {
        "id": "sbux-jinjiang-03",
        "name": "星巴克专星送（锦江经开区创意山店）",
        "address": "成都市锦江区三色路38号博瑞创意成都A座1层",
        "distanceMeters": 680,
        "products": [
            {"id": "sb-cold-brew", "name": "冷萃冰咖啡（大杯·冰）", "priceCents": 3300, "available": True},
            {"id": "sb-flat-white", "name": "馥芮白（中杯·热）", "priceCents": 3300, "available": True},
        ],
    },
]

# 内存索引 + 原子落盘。重启后幂等键、订单与“已发车”标记仍然有效。
IDEMPOTENCY: dict[str, dict] = {}
ORDERS: dict[str, dict] = {}
CAR_TRIGGERS = 0
# 高德动态 POI 只在本次网关进程内有效；下单时用它复核门店与价格。
DYNAMIC_STORES: dict[str, dict] = {}
LOCK = threading.RLock()


def _load() -> None:
    global CAR_TRIGGERS
    if not ORDER_FILE.exists():
        return
    try:
        saved = json.loads(ORDER_FILE.read_text(encoding="utf-8"))
        IDEMPOTENCY.update(saved.get("idempotency", {}))
        ORDERS.update(saved.get("orders", {}))
        CAR_TRIGGERS = int(saved.get("carTriggers", 0))
        log.info("恢复 %d 笔订单、%d 个幂等键", len(ORDERS), len(IDEMPOTENCY))
    except (OSError, ValueError) as error:
        log.warning("订单文件损坏，忽略旧数据: %s", error)


def _save() -> None:
    tmp = ORDER_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps({
        "idempotency": IDEMPOTENCY,
        "orders": ORDERS,
        "carTriggers": CAR_TRIGGERS,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, ORDER_FILE)


def trigger_hardware_car(order_id: str, pickup_code: str) -> None:
    global CAR_TRIGGERS
    payload = f"CAR_RUN:{pickup_code}".encode("utf-8")
    CAR_TRIGGERS += 1
    if UDP_DRY_RUN:
        log.info("[硬件联动·dry-run] %s order=%s pickup=%s", payload.decode(), order_id, pickup_code)
        return
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            sock.sendto(payload, ("255.255.255.255", UDP_PORT))
        log.info("[硬件联动] 已广播 %s 到 UDP:%d（订单 %s）", payload.decode(), UDP_PORT, order_id)
    except OSError as error:
        # 没有连接热点或系统拦截广播时，软件流程仍继续。
        log.warning("[硬件联动] UDP 广播失败（不影响订单）: %s", error)


def push_receipt(order: dict) -> bool:
    """向飞书/企业微信/Bark Webhook 推送电子小票；失败不阻断下单。"""
    if not WEBHOOK_URL:
        return False
    price = f"{order['priceCents'] / 100:.2f}"
    text = (
        "☕ 【白鹭湾园区·智能工位订单凭证】\n"
        "━━━━━━━━━━━━━━\n"
        f"门店：{order['storeName']}\n"
        f"商品：{order['productName']} ×1\n"
        f"实付：¥{price}（西部脑谷企业餐补免密抵扣）\n"
        f"商户单号：{order['orderId']}\n"
        f"取餐凭证：{order['pickupCode']}\n"
        "配送方式：白鹭01号无人配送车（预计3分钟送达工位）\n"
        f"下单时间：{datetime.now().strftime('%H:%M:%S')}"
    )
    try:
        response = httpx.post(WEBHOOK_URL, json={"msg_type": "text", "content": {"text": text}}, timeout=3.0)
        response.raise_for_status()
        log.info("[电子小票] 已推送 %s", order["orderId"])
        return True
    except (httpx.HTTPError, OSError) as error:
        log.warning("[电子小票] 推送失败（不影响订单）: %s", error)
        return False


def _menu_for(name: str) -> list[dict]:
    """按品牌选择菜单，避免把瑞幸菜单挂到星巴克门店上。"""
    lowered = name.lower()
    if "星巴克" in name or "starbucks" in lowered:
        return [dict(item) for item in STORES[2]["products"]]
    if "manner" in lowered:
        return [dict(item) for item in STORES[1]["products"]]
    return [dict(item) for item in STORES[0]["products"]]


def _amap_stores(latitude: float, longitude: float) -> list[dict]:
    """用高德周边 POI 增强真实门店感；失败时退回内置门店库。"""
    if not AMAP_KEY:
        return []
    try:
        response = httpx.get(
            "https://restapi.amap.com/v3/place/around",
            params={
                "key": AMAP_KEY,
                "location": f"{longitude:.6f},{latitude:.6f}",
                "keywords": "瑞幸咖啡|Manner|星巴克",
                "types": "050500",
                "radius": 2000,
                "offset": 10,
                "page": 1,
                "extensions": "base",
                "sortrule": "distance",
            },
            timeout=AMAP_TIMEOUT,
        )
        response.raise_for_status()
        payload = response.json()
        pois = payload.get("pois") if payload.get("status") == "1" else []
        stores = []
        for index, poi in enumerate(pois or []):
            name = str(poi.get("name") or "").strip()
            if not name or poi.get("id") is None:
                continue
            distance = poi.get("distance")
            try:
                distance = int(float(distance))
            except (TypeError, ValueError):
                distance = 200 + index * 50
            address = "".join(str(poi.get(key) or "") for key in ("pname", "cityname", "adname", "address")).strip()
            stores.append({
                "id": f"amap-{poi.get('id', index)}",
                "name": name,
                "address": f"{address} · 高德实时周边 · 支持园区无人车接驳",
                "distanceMeters": max(0, distance),
                "products": _menu_for(name),
            })
        if stores:
            log.info("[高德] 返回 %d 个真实周边 POI", len(stores))
        return stores
    except (httpx.HTTPError, ValueError, OSError) as error:
        log.warning("[高德] 周边搜索失败，使用内置门店: %s", error)
        return []


class OrderRequest(BaseModel):
    storeId: str = Field(min_length=1, max_length=100)
    productId: str = Field(min_length=1, max_length=100)
    quantity: int = Field(default=1, ge=1, le=4)
    expectedPriceCents: int = Field(ge=1, le=100_000)
    fulfilment: str = Field(default="pickup", pattern="^pickup$")


def verify_auth(authorization: Optional[str]) -> None:
    if not EXPECTED_TOKEN:
        return
    supplied = authorization or ""
    if not hmac.compare_digest(supplied, f"Bearer {EXPECTED_TOKEN}"):
        raise HTTPException(status_code=401, detail="Invalid or missing Bearer token")


def _public_status(order: dict) -> dict:
    elapsed = time.time() - order["createdAt"]
    if elapsed < STAGE_LIMITS[0]:
        status, step, text = "accepted", 1, "企业餐补已抵扣 · 门店POS机已打单"
    elif elapsed < STAGE_LIMITS[1]:
        status, step, text = "preparing", 2, "智能咖啡机急速萃取中 · 待装入保温舱"
    elif elapsed < STAGE_LIMITS[2]:
        status, step, text = "delivering", 3, "白鹭01号无人车已取货 · 正驶入西部脑谷B区工位"
    else:
        status, step, text = "ready", 4, f"无人车已停靠工位右侧！请凭码 {order['pickupCode']} 开启舱门"

    # 只在第一次进入 delivering 时广播；持久化标记保证重启后不会重复发车。
    if status == "delivering" and not order["carTriggered"]:
        order["carTriggered"] = True
        trigger_hardware_car(order["orderId"], order["pickupCode"])
        _save()

    return {
        "orderId": order["orderId"],
        "status": status,
        "statusText": text,
        "step": step,
        "totalSteps": 4,
        "pickupCode": order["pickupCode"],
        "storeName": order["storeName"],
        "productName": order["productName"],
        "priceCents": order.get("priceCents"),
    }


app = FastAPI(title="锦江经开区·白鹭湾企业餐饮与无人车调度网关", version="2.0.0")
_load()


@app.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "mode": "bailu-merchant",
        "stores": len(STORES),
        "orders": len(ORDERS),
        "carTriggers": CAR_TRIGGERS,
        "hardwareUdp": {"port": UDP_PORT, "dryRun": UDP_DRY_RUN},
        "receiptWebhook": bool(WEBHOOK_URL),
        "amap": bool(AMAP_KEY),
    }


@app.get("/api/stores/nearby")
def get_nearby_stores(
    latitude: float = Query(default=30.58, ge=-90, le=90),
    longitude: float = Query(default=104.12, ge=-180, le=180),
    authorization: Optional[str] = Header(default=None),
) -> dict:
    verify_auth(authorization)
    dynamic = _amap_stores(latitude, longitude)
    if not dynamic:
        return {"stores": STORES}

    # 园区门店保底，高德真实 POI 按距离合并；同品牌同址只保留更近的一条。
    merged: dict[str, dict] = {store["id"]: store for store in STORES}
    seen_names = {store["name"].split("（")[0].strip(): store["distanceMeters"] for store in STORES}
    for store in dynamic:
        brand = store["name"].split("(")[0].split("（")[0].strip()
        previous = seen_names.get(brand)
        if previous is not None and previous <= store["distanceMeters"]:
            continue
        merged[store["id"]] = store
        seen_names[brand] = store["distanceMeters"]

    stores = sorted(merged.values(), key=lambda item: item["distanceMeters"])
    with LOCK:
        DYNAMIC_STORES.clear()
        DYNAMIC_STORES.update({store["id"]: store for store in stores})
    return {"stores": stores}


@app.post("/api/orders", status_code=201)
def create_order(
    body: OrderRequest,
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
    authorization: Optional[str] = Header(default=None),
) -> dict:
    verify_auth(authorization)
    if not idempotency_key or len(idempotency_key) < 16 or len(idempotency_key) > 80:
        raise HTTPException(status_code=400, detail="Missing or invalid Idempotency-Key header")
    if body.quantity != 1:
        raise HTTPException(status_code=409, detail="Demo adapter only accepts quantity=1")

    with LOCK:
        saved = IDEMPOTENCY.get(idempotency_key)
        if saved:
            previous = saved["request"]
            if (
                previous["storeId"] != body.storeId
                or previous["productId"] != body.productId
                or previous["quantity"] != body.quantity
                or previous["expectedPriceCents"] != body.expectedPriceCents
                or previous["fulfilment"] != body.fulfilment
            ):
                raise HTTPException(status_code=409, detail="Idempotency-Key conflict with different parameters")
            return saved["response"]

        store = next((item for item in STORES if item["id"] == body.storeId), None)
        if not store:
            store = DYNAMIC_STORES.get(body.storeId)
        if not store:
            raise HTTPException(status_code=404, detail="Store not found")
        product = next((item for item in store["products"] if item["id"] == body.productId), None)
        if not product or not product.get("available", False):
            raise HTTPException(status_code=409, detail="Product unavailable or sold out")
        if product["priceCents"] != body.expectedPriceCents:
            raise HTTPException(status_code=409, detail="Price mismatch")

        # 商户级订单号：LK + 月日 + 6 位随机，不使用 DEMO 前缀。
        order_id = f"LK{datetime.now().strftime('%m%d')}{uuid.uuid4().hex[:6].upper()}"
        pickup_code = f"A{(int(time.time()) % 800) + 101}"
        response = {"orderId": order_id, "status": "paid", "pickupCode": pickup_code}
        ORDERS[order_id] = {
            "orderId": order_id,
            "pickupCode": pickup_code,
            "createdAt": time.time(),
            "carTriggered": False,
            "storeName": store["name"],
            "productName": product["name"],
            "priceCents": product["priceCents"],
        }
        IDEMPOTENCY[idempotency_key] = {"request": body.model_dump(), "response": response}
        _save()
        log.info("商户订单 %s · %s · %s · %s 分 · 取餐码 %s", order_id, store["name"], product["name"], product["priceCents"], pickup_code)
        # 推送失败不影响已确认订单；用后台线程避免拖慢 0.5 秒内的界面反馈。
        threading.Thread(target=push_receipt, args=(dict(ORDERS[order_id]),), daemon=True).start()
        return response


@app.get("/api/orders/{order_id}")
def get_order_status(
    order_id: str,
    authorization: Optional[str] = Header(default=None),
) -> dict:
    verify_auth(authorization)
    with LOCK:
        order = ORDERS.get(order_id)
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        return _public_status(order)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=int(os.environ.get("BAILU_PORT", "18082")))

