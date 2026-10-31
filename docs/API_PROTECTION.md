# API_PROTECTION_MAP 与接口契约基线

> 审计日期：2026-10-31（Asia/Shanghai）。固定代码基线：`Lofrmin/Lofrmin-` 的 `feature/product-workspace`，Commit `7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176`。
> 【已由代码确认】指静态代码事实，不代表服务、凭据或设备已验证；【根据代码推测】表示推断；【需要队友确认】表示外部配置或产品决策缺失；【需要实机验证】表示运行及物理结果未知。代码事实一般为高置信度；未发现实现的结论只限于本次仓库版本。
> 接入限制：工作目录最初不是 Git 仓库。正常克隆因本机代理连接失败；单次停用代理后的克隆亦无法连接 GitHub 443。只读 GitHub 连接器成功读取固定 SHA 的完整目录树（未截断，297 个文件）和主要自有源码；没有本地克隆、origin 引用或个人分支。文档暂存于 outputs/docs，不能声称已写入个人分支。未运行项目、安装依赖、导入业务模块、执行测试、访问设备、调用业务第三方 API 或修改远端。
> 下文路径行号链接均指向固定 SHA；教程、README、HANDOFF 的历史描述只作辅助，运行源码优先。不复制任何 Secret 或凭据型 Webhook URL。


## 保护等级与审计范围

P0 = 完全保护：Provider、模型、URL、方法、参数、响应、凭据、SDK、IPC/WS/SSE、数据库/持久化结构、硬件协议及状态映射，本轮不修改。P1 = 混合文件中的调用/业务保护，未来仅在明确授权后修改视图片段。所有表中 API 均按 P0；出现 UI 文件不代表整文件冻结视觉样式。

只读读取了前端 JS、desktop CJS/Python、server、测试、启动器和主要文档；目录树未发现其他应用服务源码。检索覆盖 fetch/request/SDK/baseURL/endpoint/各 AI Provider/WebSocket/SSE/IPC/env，以及 MQTT、socket、UART。运行源码只确认 DeepSeek 模型接入；未发现 OpenAI/Gemini/Claude/Qwen 等正在使用的独立 Provider。教程中的示例不作为活动调用链。

## API_PROTECTION_MAP

每行包括请求发起点、处理函数/位置、请求/返回、环境变量、硬件关系、证据。后续契约表补全展开结构；以下均【已由代码确认，高】，实际授权/可用性【需要队友确认】。

| ID / API | 请求发起 → 处理函数及所属文件 | 请求 → 返回基线 | 环境变量名称（绝不记录值） | 硬件关系 / 保护 / 证据 |
|---|---|---|---|---|
| AI-1 DeepSeek Chat/SSE | bindChat → Chat.ask → preload.chatSend → main chat-send → createCompanion.request/readStream | {requestId,text,name} → POST model/messages/stream/thinking/tools等 → delta/done/error/cancelled | NEURODESK_CHAT_API_KEY, DEEPSEEK_API_KEY, NEURODESK_CHAT_MODEL, NEURODESK_CHAT_CONFIG | 工具可建议灯光等，但远端不直接驱车；P0。[web/src/app/chat.js:79](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/chat.js#L79)、[web/desktop/main.cjs:205](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L205)、[web/desktop/companion.cjs:110](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L110) |
| CO-1 商户附近门店 | Coffee.nearby → preload.nearby → main coffee-nearby → createCoffeeGateway.nearby → get_nearby_stores | GET /api/stores/nearby?latitude&longitude → {stores:[…]} | NEURODESK_COFFEE_API, NEURODESK_COFFEE_TOKEN; BAILU_COFFEE_TOKEN, BAILU_PORT | 无直接驱车；P0。[web/desktop/coffee.cjs:19](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L19)、[server/bailu_coffee_adapter.py:299](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L299) |
| CO-2 商户创建订单 | coffee-dialog click → Coffee.submit → coffee-order → gateway.order → create_order | POST /api/orders + Bearer + Idempotency-Key；OrderRequest → {orderId,status,pickupCode} | 同 CO-1；BAILU_DATA_DIR, COFFEE_WEBHOOK_URL | 下单后状态查询间接触发 UDP；P0。[web/src/desk/coffee.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/coffee.js#L23)、[web/desktop/coffee.cjs:35](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L35)、[server/bailu_coffee_adapter.py:328](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L328) |
| CO-3 商户订单查询 | coffee-dialog 的2秒轮询 → orderStatus IPC → gateway.orderStatus → get_order_status/_public_status | GET /api/orders/{orderId} → orderId/status/statusText/step/totalSteps/pickupCode等 | 同 CO-1；BAILU_STAGE_SCALE, BAILU_CAR_UDP_PORT, BAILU_CAR_UDP_DRY_RUN | **有发车副作用**；P0。[web/src/app/coffee-dialog.js:50](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/coffee-dialog.js#L50)、[web/desktop/coffee.cjs:29](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L29)、[server/bailu_coffee_adapter.py:251](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L251) |
| CO-4 网关健康 | 启动器 healthy → HTTP /health → health | GET → {ok,mode,stores,orders,carTriggers,hardwareUdp,receiptWebhook,amap} | BAILU_PORT 等网关配置 | 自身不发车，不能据此证明设备在线；P0。[server/start_bailu_demo.py:27](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/start_bailu_demo.py#L27)、[server/bailu_coffee_adapter.py:285](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L285) |
| CO-5 内置 coffee-demo | 同 Coffee IPC，main useCoffeeDemo → startCoffeeDemo 的 HTTP server | GET /stores/nearby、POST /orders、GET /orders/DEMO-*、GET /health；类似通用商户契约 | NEURODESK_COFFEE_DEMO, NEURODESK_COFFEE_API, NEURODESK_COFFEE_PROVIDER, NEURODESK_TEST | 内存/计时 Mock，无 UDP；P0。[web/desktop/main.cjs:63](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L63)、[web/desktop/coffee-demo.cjs:10](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee-demo.cjs#L10) |
| LK-1 瑞幸 MCP 7种工具 | createLuckinDialog → preload luckin-* / coffee-* → main → createLuckinGateway → createLuckinClient.call | POST JSON-RPC 2.0 tools/call → JSON 或 SSE 的 result.structuredContent/content → success/code/data校验 → DTO | NEURODESK_LUCKIN_TOKEN, NEURODESK_LUCKIN_CONFIG, NEURODESK_LUCKIN_ORDERS, NEURODESK_COFFEE_PROVIDER, NEURODESK_TEST | 外部商户，未发现直连小车；P0。[web/src/app/luckin-dialog.js:84](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/luckin-dialog.js#L84)、[web/desktop/luckin.cjs:5](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L5) |
| SS-1 闪送 V3 calc/save/info | luckin-dialog → deliveryPreview/Create/Recover → main → Luckin gateway → createShansongDelivery.request | POST calc/save带签名订单；GET info带签名query → {status,errCode,data} → quote/delivery DTO | NEURODESK_SHANSONG_CONFIG, NEURODESK_SHANSONG_ORDERS | 外部骑手配送，不等于园区小车；P0。[web/desktop/shansong.cjs:18](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/shansong.cjs#L18)、[web/desktop/shansong.cjs:46](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/shansong.cjs#L46)、[web/desktop/luckin.cjs:200](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L200) |
| MAP-1 高德 POI | 商户 nearby → get_nearby_stores → _amap_stores HTTPX | GET /v3/place/around，key/location/keywords/types/radius/offset/page/extensions/sortrule → status/pois → stores | AMAP_WEB_KEY, BAILU_AMAP_TIMEOUT | 只影响门店目录；P0。[server/bailu_coffee_adapter.py:186](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L186) |
| HOOK-1 小票 Webhook | create_order → 后台 Thread → push_receipt HTTPX | POST 配置型URL，{msg_type:'text',content:{text}} → 2xx视成功，异常False | COFFEE_WEBHOOK_URL（还可从本机配置/默认值读取） | 无设备回执；含订单/取餐数据；P0。[server/bailu_coffee_adapter.py:150](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L150)、[server/bailu_coffee_adapter.py:382](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L382)、[server/demo_config.py:40](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/demo_config.py#L40) |
| TTS-1 语音桥/本机音频 | PetHub.utter → createSpeech.say → ttsSpeak IPC → createTts.speak → localTts / edge-tts；Audio GET /tts?id | IPC {text,voice?,rate?} → {id,bytes,cached,mime,engine}；GET音频返回WAV/MP3 | NEURODESK_TTS, NEURODESK_TTS_VOICE, NEURODESK_TTS_RATE, NEURODESK_TTS_PYTHON, PYTHON | 驱口型，不驱小车；P0。[web/src/pets/speech.js:61](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/speech.js#L61)、[web/desktop/tts.cjs:134](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/tts.cjs#L134)、[web/desktop/main.cjs:88](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L88) |
| TTS-2 Python本地合成 | createLocalTts.speak/request → Handler.do_POST；启动等待GET health | POST /speak {text,sid,speed} → audio/wav；GET /health → {ok,engine} | NEURODESK_TTS_ENGINE, NEURODESK_TTS_PORT, NEURODESK_TTS_PROVIDER, NEURODESK_PIPER_DIR, NEURODESK_KOKORO_DIR, PYTHONPATH | 本机模型；P0。[web/desktop/local-tts.cjs:31](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/local-tts.cjs#L31)、[web/desktop/local-tts.cjs:135](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/local-tts.cjs#L135)、[web/desktop/tts_server.py:97](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/tts_server.py#L97) |
| OS-1 屏幕/定位/窗口IPC | ui-desk / desktop.panel / pet → preload → main → screen-brightness/location及Electron API | brightness read/set整数0–100；locate→coords；monitor控制/snapshot；窗口/通知/开机启动 | NEURODESK_USER_DATA, NEURODESK_PORT, SystemRoot 等 | 会改电脑硬件状态，不是小车；P0。[web/desktop/preload.cjs:8](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/preload.cjs#L8)、[web/desktop/main.cjs:242](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L242)、[web/src/desk/light.js:49](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/light.js#L49) |
| HW-1 MQTT over WS | ui-desk.connect → mqtt.connect；send/desk publish；on message dispatch | JSON topic消息，详硬件报告 | 无 process.env；localStorage nd-mqtt；默认基于location hostname | 前端直连broker；P0。[web/src/desk/mqtt.js:11](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L11) |
| HW-2 UDP | FastAPI _public_status → trigger_hardware_car → socket.sendto | UTF-8 CAR_RUN:<pickup_code> → 无返回/ACK | BAILU_CAR_UDP_PORT, BAILU_CAR_UDP_DRY_RUN | 真实发送代码存在，设备闭环未知；P0。[server/bailu_coffee_adapter.py:133](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L133) |
| LOCAL-1 本地模型/EEG/资源 | EEGPlayer.load fetch、本地 MediaPipe loader、Live2DModel.from | GET /eeg/session.json、/mediapipe/*、/live2d/*；session字段fs/data/marks/duration/channels | 无；应用origin受NEURODESK_PORT影响 | 不是真实脑电接收接口；P0资源schema。[web/src/core/eeg.js:18](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/core/eeg.js#L18)、[web/src/core/camera.js:19](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/core/camera.js#L19)、[web/src/pets/live2d.js:34](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/live2d.js#L34) |
| BROWSER-1 语音识别/系统朗读 | listenOnce → SpeechRecognition；sound.speak → speechSynthesis | zh-CN识别文本；utterance朗读；浏览器实现决定网络使用 | 无 | 未发现自定义远程识别Endpoint；P0行为兼容。[web/src/app/chat.js:107](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/chat.js#L107)、[web/src/pets/hub.js:61](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/hub.js#L61) |

## 核心请求与响应契约

### DeepSeek：Provider、模型与事件

Endpoint 固定 `https://api.deepseek.com/chat/completions`，POST，Bearer，application/json，redirect:error，45s超时。默认模型源码为 `deepseek-flash`，环境或配置可指定；本轮未读取实际生效配置，不改变默认/覆盖优先级。[web/desktop/main.cjs:210](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L210)、[web/desktop/companion.cjs:92](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L92)。

请求 body：
```text
{
 model,
 messages: [system, ...history.slice(-16), user],
 stream: true,
 thinking: {type:"disabled"},
 max_tokens: chat ? 800 : 220,
 temperature: 0.8,
 ...(chat ? {tools:[set_light,play_music,open_coffee,monitor_control]} : {})
}
```
响应 SSE 读取 `choices[0].delta.content` 与 `delta.tool_calls[].function.{name,arguments}`，忽略 reasoning_content；需要 [DONE] 且 finish_reason 为 stop/tool_calls。工具白名单及参数范围保留。requestId 8–80字符，text最长4000字符，history最多20条，累计回复限8000字符。[web/desktop/companion.cjs:46](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L46)、[web/desktop/companion.cjs:118](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L118)、[web/desktop/companion.cjs:144](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L144)。

IPC事件：start {requestId,kind,text,contextShared,model}；delta {requestId,kind,reply,model} 中 reply 为累计字符串，不能按增量再次追加；done {requestId,kind,reply,actions,via,model}；error/cancelled {requestId,kind,message,model}；reset；前端另有 config。Chat.pending 按 requestId收敛，kind区分chat/proactive。[web/src/app/chat.js:45](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/chat.js#L45)。

动作 DTO 为 light {kelvin,level}、music {play,name}、coffee、monitor {command}。远端动作在 UI 按钮点击后才执行；本地规则 Chat.local 则会自动 run。不能把远端动作自动执行以“简化交互”。[web/src/app/ui-misc.js:65](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/ui-misc.js#L65)、[web/src/app/chat.js:87](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/chat.js#L87)。

### 通用商户与 FastAPI

baseUrl 为 NEURODESK_COFFEE_API，客户端附加 /stores/nearby、/orders；白鹭启动器根地址包含 /api。不要重复或移除 /api。[web/desktop/coffee.cjs:11](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L11)、[server/start_bailu_demo.py:66](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/start_bailu_demo.py#L66)。

```text
GET /api/stores/nearby?latitude=<number>&longitude=<number>
Authorization: Bearer <受保护凭据>
→ {stores:[{id:string,name:string,address:string,distanceMeters:number,
             products:[{id:string,name:string,priceCents:int,available:bool}]}]}

POST /api/orders
Authorization: Bearer <受保护凭据>
Idempotency-Key: <16–80字符>
{storeId,productId,quantity:1,expectedPriceCents:int,fulfilment:"pickup"}
→ 201 {orderId:string,status:"paid",pickupCode:string}

GET /api/orders/{order_id}
→ {orderId,status,statusText,step,totalSteps:4,pickupCode,
    storeName,productName,priceCents}
```

前端 submit 输入为 {storeId,productId,priceCents,idempotencyKey}；网关转换成 expectedPriceCents。前端订单 DTO 还补 storeName/productName；orderStatus 会裁剪服务端字段。FastAPI quantity schema允许1–4，但处理函数只接受1；保持该实际限制。认证401，参数/幂等键400，找不到404，价格/库存/幂等冲突409，schema校验422。幂等请求和“已发车”标记持久化，不得因新 UI 重试重新生成 key 或清理 pending。[web/src/desk/coffee.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/coffee.js#L23)、[web/desktop/coffee.cjs:42](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L42)、[server/bailu_coffee_adapter.py:235](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L235)、[server/bailu_coffee_adapter.py:335](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L335)。

### 瑞幸 MCP 每个工具

统一 POST `https://gwmcp.lkcoffee.com/order/user/mcp`，Accept JSON/SSE，25秒超时。包络：
`{jsonrpc:"2.0",id,method:"tools/call",params:{name,arguments}}`。
响应按 id匹配，result.structuredContent 或 text JSON 中须 success===true、code===0，再取 data。不是普通 REST /api/orders。[web/desktop/luckin.cjs:8](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L8)。

| 工具 / Gateway函数 | arguments基线 | 返回消费结构 |
|---|---|---|
| queryShopList / nearby | latitude,longitude,deptName? | 数组 deptId/deptName/address/latitude/longitude/distance/workTime* → stores |
| searchProductForMcp / products | deptId,query | 商品数组 → selection |
| queryProductDetailInfo / detail | deptId,productId | productId/skuCode/productName/estimatePrice或initialPrice/productAttrs → selection |
| switchProduct / switchAttribute | deptId,productId,skuCode,amount:1,attrOperationParam:{attributeId,subAttr:{attributeId,operation:3}} | 同selection |
| previewOrder / preview与下单前复核 | deptId,productList:[{amount:1,productId,skuCode}] | productInfoList/shopInfo/discountPrice/couponCodeList → draft |
| createOrder / order | deptId,productList,longitude,latitude,couponCodeList | orderIdStr（优先）或安全整数/字符串orderId、needPay、discountPrice、payOrderUrl、payOrderQrCodeUrl → journal order；须保留源码验证 |
| queryOrderDetailInfo / orderStatus、recover | orderId | orderStatus/orderStatusName/takeMealCodeInfo.code/shopInfo/productInfoList等 → 状态/核实 |

证据：[web/desktop/luckin.cjs:78](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L78)、[web/desktop/luckin.cjs:103](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L103)、[web/desktop/luckin.cjs:116](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L116)、[web/desktop/luckin.cjs:128](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L128)、[web/desktop/luckin.cjs:135](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L135)、[web/desktop/luckin.cjs:149](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L149)、[web/desktop/luckin.cjs:186](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L186)。

selection DTO：selectionId/storeId/id/name/skuCode/priceCents/attrs/at；draft DTO：draftId/storeId/storeName/address/productId/productName/skuCode/specification/amount/priceCents/couponCodeList/expiresAt/fulfilment/recipient?/deliveryQuote?。币值必须保持“分”；店/商品ID在此为整数，不要与通用商户string ID统一。orderId维持字符串，避免大整数精度损失。selection有效30分钟、draft有效5分钟。提交 {draftId,priceCents,confirmed:true} 并重新预览价格优惠；unknown状态必须核实/恢复，不能盲目重试。官方支付URL白名单也必须保留。[web/desktop/luckin.cjs:76](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L76)、[web/desktop/luckin.cjs:89](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L89)、[web/desktop/luckin.cjs:149](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L149)。

状态映射：10 awaiting_payment、20 accepted、30 preparing、60 ready、80 completed、100 cancelled、其他processing。此处与白鹭“ready=计时模拟到站”含义不同，不能混为同一硬件到站事件。[web/desktop/luckin.cjs:191](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L191)。

### 闪送

baseUrl来自本机JSON配置，须官方HTTPS域 ishansong.com/bingex.com 下 /openapi/order/v3；不替换 Provider/签名。
calc/save POST：{partnerNo,signature,order:{orderNo,sender,receiverList,goods,weight,addition,appointTime,remark,merchant:{id,mobile,name,token}}}。
info GET query：partnerno/orderno/mobile/issorderno/signature。签名现用MD5组合逻辑是受保护契约，本轮不“升级”或改写。平台返回 {status:"OK",errCode:0,data}，calc消费amount/cutAmount，save取配送单号，info读状态骑手字段。[web/desktop/shansong.cjs:45](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/shansong.cjs#L45)。

UI报价返回 {quoteId,feeCents,expiresAt,recipient}；提交需 {orderId,quoteId,feeCents,confirmed:true,acceptBilling:true}；输出 delivery含 state/orderNo/deliveryId/feeCents/status/statusText/courier/courierName。取餐码、已付款、ready、地址、报价复核、余额扣费确认及unknown持久化防重不能去除。[web/src/app/luckin-dialog.js:219](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/luckin-dialog.js#L219)、[web/desktop/shansong.cjs:77](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/shansong.cjs#L77)、[web/desktop/luckin.cjs:200](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/luckin.cjs#L200)。

### 高德、Webhook、TTS与其他通信

高德GET `https://restapi.amap.com/v3/place/around`：
key/location为经度,纬度/keywords/types/radius/offset/page/extensions/sortrule；响应 status=="1"、pois[].id/name/distance/pname/cityname/adname/address。失败退内置门店，菜单仍是本地品牌菜单，不等于高德提供实时库存/价格。[server/bailu_coffee_adapter.py:186](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L186)。

Webhook地址本身是能力凭据，报告不输出；POST文本小票，异常不阻断订单。不根据HTTP成功声称手机已查看。[server/bailu_coffee_adapter.py:150](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L150)。

TTS调用链及本文表格保留原路径、音频格式与hash id。edge-tts由Python模块调用而非仓库自定义 Endpoint，不能凭空补写固定云URL；浏览器 SpeechRecognition/speechSynthesis 的实际网络路径也未在仓库定义。[web/desktop/tts.cjs:109](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/tts.cjs#L109)。
MQTT、UDP、UART全部字段见 HARDWARE_COMMUNICATION.md，属于本保护图的一部分。

## 完整调用链

1. **AI**：chat-form submit → bindChat.ask → Chat.ask/pending → window.neuroDesktop.chatSend → preload ipcRenderer.invoke('chat-send') → main handle → Companion.request → DeepSeek SSE → readStream → onEvent/webContents.send('chat-event') → preload.onChat → Chat.receive → bindChat DOM、hub.say/utter → TTS/音频电平 → Live2D口型。
2. **后台感知**：monitor Camera/StateMachine → preload.publish send('monitor-snapshot') → main验证sender → snapshot广播/companion.observe → panel bindDesktop.nativeSnapshot → sense强制同步状态 → Reactions → PetHub；桌宠经独立onSnapshot同步。
3. **白鹭**：coffee按钮 → Reactions.orderCoffee只开弹窗 → bindCoffeeDialog → Coffee.nearby/submit → preload IPC → main coffeeGateway → FastAPI → 可选高德/小票；成功订单轮询 → _public_status → UDP。返回DTO → 进度文案，没有设备回执。
4. **瑞幸/闪送**：luckinDialog选店/规格/preview → IPC → main Luckin gateway → MCP → DTO → 用户确认下单/支付；ready+取餐码后用户确认配送 → delivery IPC → Shansong V3 → journal → UI。仓库未发现消息队列；Webhook是后台线程。
5. **MQTT**：前端 Light/Reactions/sense → mqtt.js → broker WS → 仓库外设备；broker message → mqtt handlers → BOOT确认/连接状态。没有 Python转发。

## 受保护文件与凭据风险

P0受保护：`web/desktop/*`（包括main、preload、companion、coffee、luckin、shansong、tts、local-tts、tts_server、location、screen-brightness、coffee-demo）；`server/*`；`firmware/**`；`web/src/core/*`、`web/src/desk/*`；配置示例、package/lock、vite配置、启动与烧录工具；IndexedDB/localStorage及journal schema。

P1混合文件：`web/src/main.js`、`web/src/app/{chat,reactions,sense,ui-misc,ui-desk,coffee-dialog,luckin-dialog,product-workspace}.js`、`web/src/desktop/*`、`web/src/pets/{hub,view,speech,custom,upload}.js`。未来视觉改动不得改变它们的调用与状态语义。

【已由代码确认，高】潜在泄露/不安全默认：
- [server/demo_config.py:14](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/demo_config.py#L14)、[server/demo-config.example.json:3](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/demo-config.example.json#L3)：硬编码凭据型Webhook地址，值已省略；有效性未知。
- [server/bailu_coffee_adapter.py:15](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L15)、[server/bailu_coffee_adapter.py:56](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L56)：文档和代码包含默认共享Bearer凭据；[server/start_bailu_demo.py:67](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/start_bailu_demo.py#L67)与启动环境复用。值已省略。
- [web/README.md:128](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/README.md#L128)、[web/README.md:144](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/README.md#L144)、[HANDOFF.md:275](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/HANDOFF.md#L275)、[HANDOFF.md:686](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/HANDOFF.md#L686)、[web/tests/desktop-bailu-orders.mjs:46](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/tests/desktop-bailu-orders.mjs#L46)、[tests/test_bailu_gateway.py:20](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/tests/test_bailu_gateway.py#L20)也含同类默认凭据。
- 实际 DeepSeek/瑞幸本机JSON可含明文凭据；本轮未读取机器上的 .runtime 内容，不宣称泄露了有效云端Key，也不宣称仓库历史彻底无密钥。
- `server/demo_config.py`有默认Webhook回退，单纯“不配置环境变量”不能保证不发送通知。不要启动演示验证。
- 本轮没有试用、轮换、移除、传播或复制凭据值。由仓库/凭据负责人决定后续处理；UI升级禁止改此区域。

