# NeuroDesk 桌面版

Windows 桌宠 + 独立后台视觉疲劳监测。无需打开浏览器；启动后显示桌宠，点击桌宠打开工作台。拖动宠物可以移动位置。关闭工作台仅收起面板，监测继续；托盘菜单可暂停、恢复或彻底退出。

## 运行

```powershell
cd web
npm install
npm start
```

`npm start` 构建并启动原生桌面程序。`npm run desktop` 使用已有构建直接启动。`npm run pack` 生成 `release/win-unpacked/NeuroDesk.exe`，无需 Node 环境即可运行；移动或分发时保留整个 `win-unpacked` 文件夹。`npm run pack:portable` 可选生成单文件便携版（另需下载 NSIS 打包工具）。项目根目录的 `启动NeuroDesk.cmd` 优先打开已打包程序，没有打包程序时启动开发版本，并直接显示工作台。

CMD 将 Electron 用户数据与构建临时文件放到 `web/.runtime`，避免当前机器上对 `%APPDATA%\neurodesk-desktop` 的单实例锁写入权限问题。为兼容本机受限运行环境，CMD 还传入 `--no-sandbox`；应用本身仍保持 `contextIsolation`、禁用 Node 集成、限制导航和窗口打开。正常双击 `NeuroDesk.exe` 时可以不传该参数。

## 电脑屏幕亮度

桌面版的“工位与提醒 → 亮度”默认联动 Windows 屏幕实际亮度（0–100%），初次打开与重新聚焦工作台时读取系统当前亮度，启动时不会用预设覆盖屏幕亮度。拖动滑块或选择灯光预设会调用本机 WMI 亮度接口，调节后显示系统回读值；自动联动开启时，状态触发的灯光预设也会调整屏幕亮度。

“联动电脑屏幕亮度”可关闭并记住选择。仅修改色温不会调整屏幕亮度。网页预览、未提供 WMI 亮度接口的外接显示器和权限/驱动错误会显示相应提示。`npm run test:brightness` 是实际硬件测试，会短暂调节屏幕亮度并在结束时恢复原值。

## Live2D 数字人

默认形象为官方示例 Hiyori（界面名“小日和”）。使用 PixiJS 6.5.10、pixi-live2d-display 0.4.0 和 Cubism Core，模型、动作、贴图、物理配置及 Core 全部在 `public/live2d` 本地加载。支持待机动作、自动眨眼、鼠标视线跟随、点击动作、情绪参数和说话时的口型变化。形象卡片使用静态预览，避免多个 Pixi WebGL 上下文共享纹理导致空白。

原来的 SVG 宠物和自定义图片形象仍可在“桌面伙伴”中切换。Live2D 示例素材与 Core 的许可说明随资源放在 `public/live2d/*LICENSE.md`；公开发布前需按这些条款确认使用范围。

首次启动自动申请摄像头权限并进行约 8 秒基线校准。Windows 需要允许桌面应用使用摄像头。摄像头不可用、被占用或拔出时会显示错误，可在工作台或托盘重新开始。系统休眠时暂停，唤醒后按休眠前状态恢复。可以在设置开启“开机启动”。

后台使用独立隐藏感知窗口，以约 15 FPS 在本机运行 MediaPipe，每 250ms 融合视觉指标。面板不持有摄像头，关闭或隐藏面板不会关闭监测。EEG 公开数据集仅在“感知数据”中回放，**不参与日常监测评分**。效果演示单独标记为模拟数据。

## DeepSeek 智能陪伴

桌面版使用 [DeepSeek 官方 API](https://api-docs.deepseek.com/) 的 `deepseek-flash` 模型（非思考模式，流式输出），可实时显示生成中的文字，保留本次应用会话最近 20 条消息，支持停止生成、失败重试、清空对话和形象名字。回复同步到桌宠气泡，并由 edge-tts 神经网络语音朗读、驱动 Live2D 真实口型（见上一节）。

密钥保存在 `web/.runtime/deepseek-config.json` 的 `apiKey` 字段，只由 Electron 主进程读取。可用 `NEURODESK_CHAT_API_KEY` / `DEEPSEEK_API_KEY` 覆盖密钥、`NEURODESK_CHAT_MODEL` 覆盖模型、`NEURODESK_CHAT_CONFIG` 指定本机配置文件。配置不进入 Git 或安装包，网页拿不到密钥；模型请求固定发往 `https://api.deepseek.com/chat/completions`。普通测试在独立用户目录启动，不读取真实密钥。

聊天区默认开启“自动朗读回复”，普通文字对话和主动关心完成后都会朗读，不依赖“宠物说话”设置。每条新回复可点击“朗读回复”重播，“停止朗读”立即停止播放及等待中的语音；发送下一条消息或清空对话也会停止上一条。关闭自动朗读会保存在本机，重新打开后仍生效。长回复分段顺序朗读。

语音优先使用本机 Piper 模型。缺少 `sherpa_onnx` 时，可从项目根目录执行 `python -m pip install --target web/.runtime/tts-python sherpa-onnx`；桌面语音服务会自动读取该目录中的运行库，配置及依赖均不进入 Git。离线引擎不可用时仍可回退到系统语音。

设置中有两个开关：

- **让 DeepSeek 结合检测摘要回应**：开启后，将当前有效的专注、疲劳、是否在位、眨眼/PERCLOS/哈欠数值摘要与文字对话一同发送。摄像头帧、人脸关键点、图片和视频始终留在本机；暂停监测、校准、无脸、过期或缺失数据保留为空，不伪造零分。关闭后不再附加新的检测摘要，仍可文字对话。
- **疲劳或分心持续时主动关心**：有效的疲劳、困倦或分心状态持续 20 秒后，可生成一条简短提醒；全局至少间隔 5 分钟、同一状态至少间隔 15 分钟。状态已恢复时取消尚未完成的关心提醒；演示模式不触发真实主动模型请求。

模型不修改本地监测算法或评分，不做医学诊断。灯光、音乐、监测和咖啡操作作为可点击建议呈现；模型不能直接执行、创建咖啡订单或付款。原有本地检测、基础提醒与工位控制继续工作。聊天记录仅保存在本次会话内存中，清空后会中断当前请求并删除该会话上下文。

`npm test` 包含摘要白名单、缺失/过期数据、流式分块、工具参数、上下文、取消、重试及主动提醒节流验证；`npm run test:companion-ui` 使用合成模型验证界面；`npm run test:companion-desktop` 默认不请求远端。显式设置 `NEURODESK_COMPANION_LIVE=1` 后的桌面测试才会读取本机密钥并发起一条真实自检对话；该测试使用虚拟摄像头，关闭摘要共享及主动提醒，不操作咖啡订单。

## 神经网络语音合成（本地 piper，离线）

桌宠说话默认使用**本机离线神经网络语音**，不依赖网络，也不会因为现场断网而哑火。合成在 Electron 主进程完成，音频通过本机 `http://127.0.0.1:17863/tts?id=<hash>` 提供给渲染层；**Live2D 的口型由真实音频电平驱动**，不再是固定的正弦波假张合。

### 两套引擎

| 引擎 | 模型 | 实测延迟（8 字句） | RTF | 说明 |
|---|---|---|---|---|
| **piper**（默认） | `web/.runtime/piper` | **约 0.5 秒** | 0.26 | VITS 中文，20 MB，实时对话够用 |
| kokoro（可选） | `web/.runtime/kokoro` | 约 3.9 秒 | 1.8 | 音色更好但偏慢，205 MB，需自行下载 |
| edge-tts（兜底） | 需联网 | 3–4 秒 | — | 本地模型缺失时自动接管 |

### 工作方式

- **常驻服务**：`desktop/tts_server.py` 由主进程按需拉起，模型只加载一次，通过 `127.0.0.1:18090` 提供 `/speak`。退出应用时自动结束。
- **依赖**：`pip install sherpa-onnx`（实测 2.0.1 可用）。模型自带的 `zh_CN-xiao_ya-medium.onnx` 在 `.runtime/piper`。
- **缓存**：合成结果按 `sha256(引擎|音色|语速|文本)` 落到 `web/.runtime/tts-cache/`，同一句话第二次朗读为 0 ms；最多保留 48 条。`/tts` 只接受 32 位哈希 id，伪造或越权路径一律 404。
- **串行化**：合成内部排队，避免并发导致乱序和失败率上升。
- **关闭与降级**：`NEURODESK_TTS=0` 关闭合成，回退到系统 `speechSynthesis`；本地服务起不来时自动走 edge-tts，再失败才回退系统语音。可用 `NEURODESK_TTS_ENGINE`（`piper`/`kokoro`）、`NEURODESK_TTS_PORT`、`NEURODESK_TTS_PYTHON` 调整。
- **隐私**：本地引擎完全不出网；即使回退到 edge-tts，也只发送要朗读的回复文本，摄像头帧、人脸关键点与检测数值都不会进入语音请求。

`npm test` 中的 `tests/tts.test.mjs` 覆盖文本清洗、空文本/关闭状态拒绝、本地引擎优先、引擎隔离的缓存键、以及 `/tts` id 只接受哈希；`npm run test:tts` 是真实桌面端验证（会真正合成一句测试语音，并检查本地音频端点与播放可用性）。

## 咖啡服务接入

配置瑞幸 Token 后，桌面版默认使用下面的瑞幸真实服务。未配置 Token 且未指定其他商户接口时，会启动绑定 `127.0.0.1:18081` 的**本机演示适配器**，演示门店查询、幂等下单、订单号和四阶段进度轮询；该模式明确标注“本机演示”，不产生商户订单或扣款。设置 `NEURODESK_COFFEE_DEMO=0` 可关闭演示。网页预览始终使用静态示例，不直接下单。

### 瑞幸官方真实点单

从 [瑞幸官方 AI 平台](https://open.lkcoffee.com/mcp) 登录取得 Token，保存到 `web/.runtime/luckin-config.json` 的 `token` 字段（也可使用环境变量 `NEURODESK_LUCKIN_TOKEN`）。本地配置位于 Git 忽略目录，不在安装包中，Token 仅由 Electron 主进程读取，不下发到网页或写入日志。官方接口固定为 `https://gwmcp.lkcoffee.com/order/user/mcp`，参数依据 [官方工具文档](https://open.lkcoffee.com/docs)。

配置好 Token 后双击根目录 **`启动NeuroDesk.cmd`**（检测到 Token 且未指定其它 provider 时自动走真实瑞幸），在“工位与提醒 → 看看附近咖啡”中操作：

1. 点击“使用当前位置查门店”：通过 Windows 原生位置服务定位并将经纬度发送给瑞幸。打开弹窗本身不会定位或发送坐标；定位不可用时可打开 Windows 位置设置或手动填写经纬度。
2. 选择真实门店，搜索饮品，选杯型、温度等官方规格。每次一杯，到店自取。
3. 查看官方报价（含匹配的优惠券），确认门店、地址、规格、金额后点击“确认下单”。创建前重新核对报价；金额或优惠变化时要求重新预览。
4. 使用瑞幸返回的官方支付二维码或支付链接付款；系统按官方订单状态更新待付款、制作、取餐码等信息。不会显示演示小车、虚构取餐码或企业餐补付款。

报价有效期五分钟。订单提交前将尝试记录原子写入 `web/.runtime/luckin-orders.json`；提交超时不自动重试，重启后也会保留待核实状态。在“本机瑞幸订单”中，可关联 App 中已成功的订单，或在本人确认没有成功订单后解除待核实状态。不能删除订单记录来绕过核实，否则可能重复下单。

`NEURODESK_COFFEE_PROVIDER=luckin` 强制启用瑞幸；`NEURODESK_COFFEE_PROVIDER=adapter` 可继续使用原商户适配器。普通自动测试设置 `NEURODESK_TEST=1` 后不读取真实 Token，瑞幸桌面测试使用合成 Token 和隔离订单文件。

验证：`npm test` 检查真实服务适配、金额、规格、64 位订单号、确认门槛、价格变化、支付 URL、跨重启防重试；`npm run test:luckin-ui` 使用合成数据走完整界面；`npm run test:luckin-desktop` 检查 Electron IPC 权限与启动配置。它们不创建真实订单。真实查询、预览通过不等于已经验证真实支付与履约。

### 瑞幸 + 闪送取餐配送

瑞幸 MCP 仍创建自取订单；选择“闪送配送到地址”后，本项目另行调用闪送 V3 计费、发单、查询接口。用户填写收货人、手机号、城市、街道地址和楼栋门牌，闪送按文字地址反解析位置并校验服务范围，不会把系统定位坐标误当作百度坐标。联系手机号也作为骑手取餐联系号码，配送城市必须与门店同城。

**当前需要开通闪送商户接口后才能真实发单**。仅有瑞幸 Token 不具备配送权限。先在[闪送开放平台](https://open.ishansong.com)开通合作账号及余额支付，向平台取得适用的 V3 接口地址和凭据，充值，并确认当前商户协议与[公开 V3 文档](https://cdn.ishansong.com/iss-new-pc/images/docs/shansong_api_V3.0.9.pdf)兼容。公开文档较旧，生产地址不作猜测，以平台分配的 HTTPS 地址为准。未配置时，界面仍可填写地址，但禁止以配送方式创建咖啡订单。

将 `web/shansong-config.example.json` 复制为 `web/.runtime/shansong-config.json` 并在本机填写，随后重启桌面版：

| 字段 | 内容 |
| --- | --- |
| `baseUrl` | 平台分配的官方 HTTPS 接口根地址，路径为 `/openapi/order/v3`，不含 `/save` |
| `partnerNo` | 合作伙伴编号 |
| `key` | 签名加密 Key |
| `merchantId` | 商户唯一 ID |
| `mobile` | 闪送商户注册手机号 |
| `name` | 商户机构名称 |
| `token` | 余额支付 Token |

可用 `NEURODESK_SHANSONG_CONFIG` 指定配置位置。密钥只在 Electron 主进程使用，不进入前端、日志或安装包。配置文件及订单文件含敏感信息，不要分享或提交。

流程：规格页选配送并填地址 → 查询咖啡实价和闪送预计费用 → 确认咖啡订单并按瑞幸官方页面付款 → 瑞幸返回“等待取餐”及取餐码 → 点击“查询配送费并呼叫闪送” → 确认地址、报价及商户余额扣费方式 → 创建闪送单 → 刷新骑手和配送状态。配送信息只发送到已配置的闪送服务。发单前再查一次费用，变化则要求重新确认；V3 未提供锁价字段，最终按闪送发单时计费，不承诺价格锁定。不会自动呼叫、自动加价或虚构送达时间。

咖啡与配送是两笔独立交易。配送失败不会自动取消咖啡；取消或退款请在各自官方平台操作。发单结果不明确时不会自动重发；记录在 `web/.runtime/shansong-orders.json`（可用 `NEURODESK_SHANSONG_ORDERS` 覆盖）。按界面给出的商户订单号到闪送平台核实，成功后可关联闪送配送单号；不要删除记录或重新下咖啡订单来重试配送。

本机合成测试：`npm test`；界面回归：先 `npm run build`，再运行 `npm run test:shansong-ui`。测试覆盖地址校验、报价变化、付款/出餐门槛、余额扣费确认、取餐码传递、并发防重、超时持久化与恢复、配送状态及移动布局，不发真实订单。取得商户凭据后仍需沙箱联调，并在用户确认费用和地址后验证真实订单与履约。

### 白鹭湾园区商户模式（推荐演示）

项目内置 `server/bailu_coffee_adapter.py`，实现成都白鹭湾科技生态园 / 西部脑谷门店与四阶段进度。双击根目录 **`启动白鹭湾正式版.cmd`** 会依次启动网关和 NeuroDesk 正式商户模式，无需手工设环境变量。

```text
网关:  http://127.0.0.1:18082/api
令牌:  bailu-2026-secret
门店:  luckin coffee 瑞幸咖啡（白鹭湾科技生态园店）160m
       Manner Coffee（锦江西部脑谷中心站）290m
       星巴克专星送（锦江经开区创意山店）680m
单号:  LK + 月日 + 6 位随机（例如 LK1027B48A2E）
状态:  paid（企业餐补直付）→ accepted → preparing → delivering → ready
发车:  第一次进入 delivering 时 UDP 广播 CAR_RUN:<取餐码> 到 255.255.255.255:8888
```

界面在正式商户模式下**不显示“本机演示”黄标**，也不会出现 `DEMO-` 订单前缀。门店、餐补直付与订单仍是本机商户网关模拟，不调用真实瑞幸/星巴克接口，也不会真实扣款。

#### 手机电子小票（可选）

配置飞书 / 企业微信 / Bark 的 Webhook 后，下单瞬间会向手机推送带门店、商品、实付、单号、取餐码与配送方式的电子小票。推荐用配置脚本保存，重启后仍生效：

```powershell
python server/setup_demo_config.py --webhook 'https://open.feishu.cn/open-apis/bot/v2/hook/xxxx'
python server/setup_demo_config.py --show
```

配置优先级：环境变量 `COFFEE_WEBHOOK_URL` > `server/.runtime/demo-config.json` > 内置默认 Webhook。推送在后台线程执行，失败只写日志，不影响订单确认；同一幂等键重试不会重复推送。

#### 高德真实周边门店（可选）

在高德开放平台按以下方式建 Key：

| 表单项 | 填写 |
|---|---|
| 应用名称 | `NeuroDesk白鹭湾`（≤15 字） |
| 应用类型 | 出行 / 生活服务 |
| Key 名称 | `bailu-coffee-web`（≤15 字） |
| 服务平台 | **Web服务**（必须是这个，不能用 Web端 JS API） |
| IP 白名单 | 留空（本机运行最省事；要填就填公网出口 IP，不要填 127.0.0.1） |

保存后 `GET /api/stores/nearby` 会按传入经纬度拉取 2 公里内真实瑞幸 / Manner / 星巴克 POI；请求失败或额度用尽自动回退内置门店库，不阻断演示：

```powershell
python server/setup_demo_config.py --amap '你的32位Key'
```

高德动态门店沿用内置菜单与价格，下单时仍由网关复核门店、商品与 `expectedPriceCents`。

网关默认把订单持久化到 `server/.runtime/bailu_orders.json`，因此幂等键、订单状态和“已发车”标记在重启后仍有效。`BAILU_CAR_UDP_DRY_RUN=1` 可关闭真实 UDP 广播，只写日志；`BAILU_STAGE_SCALE` 可缩放各阶段时长用于测试。

疲劳/困倦时桌面程序自动打开推荐弹窗，同类推荐至少间隔 20 分钟。也可从面板或聊天主动打开。白鹭湾模式使用固定园区坐标，不申请系统定位；其他商户适配器仍使用系统定位。

启动前设置（令牌仅主进程使用，不发送给面板）：

```powershell
$env:NEURODESK_COFFEE_API = 'https://your-merchant-adapter.example/api'
$env:NEURODESK_COFFEE_TOKEN = 'your-token'
npm start
```

接口根地址要求 HTTPS；本机调试允许 `http://127.0.0.1:端口` 或 `http://localhost:端口`。定位需要系统定位权限；失败时弹窗允许重试。商户适配器负责账号授权、默认支付方式、库存、价格复核和实际履约。

### GET /stores/nearby?latitude=31.23&longitude=121.47

```json
{
  "stores": [{
    "id": "store-1", "name": "真实门店名称", "address": "真实地址", "distanceMeters": 260,
    "products": [{ "id": "sku-1", "name": "美式", "priceCents": 1800, "available": true }]
  }]
}
```

距离由服务端返回，客户端排序；价格以整数分表示，售罄商品不展示。不要将凭证或执行代码放在响应中。

### POST /orders

请求头：`Authorization: Bearer <token>`（配置了令牌时）、`Idempotency-Key: <UUID>`。

```json
{ "storeId": "store-1", "productId": "sku-1", "quantity": 1, "expectedPriceCents": 1800, "fulfilment": "pickup" }
```

确认响应：

```json
{ "orderId": "merchant-order-123", "status": "accepted", "pickupCode": "A123" }
```

仅 `accepted` 或 `paid` 且具有真实 `orderId` 才显示已下单；`accepted` 显示“门店已接单”，`paid` 显示“已支付”。请求失败不伪造成功。超时重试复用原订单 UUID。**服务端必须持久化幂等键并返回同一订单；价格变动或库存不足需返回非 2xx，不能静默加价或替换商品。**

### GET /orders/{orderId}

用于查询已确认订单的当前进度：

```json
{ "orderId": "merchant-order-123", "status": "preparing", "statusText": "咖啡制作中", "step": 2, "totalSteps": 4, "pickupCode": "A123" }
```

本机演示依次返回 `accepted → preparing → delivering → ready`，桌面每 2 秒查询一次。真实适配器若暂不支持进度查询，初始下单确认仍然保留，界面会显示进度查询错误而不会撤销或伪造订单结果。

## 验证

`npm test` 检查信号算法、状态机、订单网关和本机演示 API。`npm run build` 构建三个本地窗口入口。`npm run test:ui` 检查网页布局和 Live2D 页面错误；`npm run test:desktop` 检查窗口生命周期、后台监测、桌宠同步与 Live2D 加载；`npm run test:orders` 分别验证商户适配器及默认本机演示的端到端下单和进度；`npm run test:bailu` 会自动拉起白鹭湾网关并验证固定园区定位、真实门店、Bearer 下单和 4 阶段轮询。根目录 `python tests/test_bailu_gateway.py` 验证鉴权、三家真实门店、LK 订单号、paid 状态、电子小票、高德降级、幂等、价格冲突、单次发车和重启持久化。这些桌面测试使用项目内 Playwright 依赖与虚拟摄像头，不产生真实订单；不代表疲劳识别准确率或真人摄像头效果已经评估。

窗口配置遵循 [Electron BrowserWindow 文档](https://www.electronjs.org/docs/latest/api/browser-window)；预加载桥接使用隔离上下文，渲染器不能访问 Node。摄像头权限仅授予后台感知窗口。
