# NeuroDesk 新人上手指南

> 给刚加入的队友。读完这份，你能跑起来、看懂代码、知道下一步该做什么。
>
> 深挖细节看 [HANDOFF.md](HANDOFF.md)；本文只讲「你需要知道什么」。

---

## 一、这是什么项目

**一句话**：一个 Windows 桌面数字人，看着你的脸判断你累不累、专不专注，然后用神经网络语音跟你说话，还能帮你点一杯真咖啡，由无人车送到工位。

**场景**：白鹭湾科技生态园 / 西部脑谷的智能工位。员工在工位上工作，桌面宠物（Live2D 数字人）在旁边陪着，检测到疲劳会主动关心，同时可以一键点园区咖啡，无人车配送。

**参赛**：黑客松 demo 项目，不是商业产品。

### 为什么这算「AI」

不是接个大模型聊天就完事，这里有四条真实的 AI 链路：

| 链路 | 技术 | 跑在哪 |
|---|---|---|
| 视觉感知 | MediaPipe Face Landmarker，468 点人脸关键点 | 本机，15 FPS |
| 状态推断 | 规则状态机 + 视觉/EEG 加权融合 | 本机，纯 JS |
| 对话 | DeepSeek 官方 API，流式 + 工具建议 | 云端，主进程直连 |
| 语音 | 本地 piper 神经网络 TTS，驱动 Live2D 口型 | **完全离线**，本机合成播放 |

**关键设计**：摄像头画面**永远不出本机**。只有你选择共享时，才会把「专注 52、疲劳 68」这种数值摘要发给模型。

---

## 二、5 分钟跑起来

### 前置

```text
Node.js  ≥ 18（当前验证 24.12.0）
Python   ≥ 3.10（当前验证 3.13.13）
```

### 最快路径

```powershell
cd E:\office_workspace\hks\web
npm install
npm start
```

`npm start` = 构建 + 启动 Electron。首次会申请摄像头权限，然后约 8 秒基线校准。

### 启动脚本（根目录）

| 脚本 | 用途 | 咖啡走哪 |
|---|---|---|
| `启动NeuroDesk.cmd` | 日常启动，优先用已打包 exe | 有瑞幸 Token 走瑞幸，否则本机演示 |
| `启动白鹭湾正式版.cmd` | 园区演示（含飞书小票/高德门店） | 本机网关 `127.0.0.1:18082` |

> 白鹭湾两个脚本会先检查 Python 依赖，缺了自动 `pip install`，再起网关、等健康检查、最后拉起桌面。

---

## 三、架构：三个窗口，一个主进程

这是**最容易被新人改错的地方**，务必先理解。

```text
Electron 主进程 (desktop/main.cjs)
│  本地 HTTP 服务 127.0.0.1:17863  ← 提供 dist/ 静态资源 + /tts 音频
│  所有密钥只在这里，渲染层拿不到
│
├─ panel   工作台  index.html    1320×900  四个视图
├─ pet     桌宠    pet.html      240×280   透明无边框，置顶
└─ monitor 感知    monitor.html  640×480   隐藏窗口，唯一持有摄像头
```

### 三条铁律

**1. 摄像头只在 monitor 窗口**

工作台和桌宠都**不持有**摄像头。所以关闭/隐藏工作台，后台监测继续跑。这是刻意的设计，别为了「方便」把 `getUserMedia` 挪到 panel。

**2. Live2D 卡片必须用静态预览**

工作台「桌面伙伴」里的形象卡片用的是静态 PNG，**只有主舞台和桌宠持有真实模型**。原因：多个 Pixi 实例共享 WebGL 纹理缓存会冲突，卡片区域会空白。这个坑踩过。

**3. 密钥永不进渲染层**

`preload.cjs` 用 `contextBridge` 暴露白名单 IPC。`contextIsolation: true`、`nodeIntegration: false`、导航和开窗都禁。瑞幸 Token、DeepSeek Key 只在主进程读。

### 数据流

```text
摄像头 → monitor(MediaPipe 15FPS)
         ↓ 每 250ms publish
主进程 snapshot → panel / pet
         ↓
   状态机 + 融合 → 界面 + 桌宠表情
         ↓
  疲劳/困倦持续 20s → 主动关心（DeepSeek）
         ↓
      回复 → 本地 piper → Live2D 真实口型
```

---

## 四、目录速查

```text
hks/
├─ HANDOFF.md                ★ 深度交接文档（改代码前先看第九节「已知的坑」）
├─ ONBOARDING.md             ★ 本文
├─ .gitignore
│
├─ web/
│  ├─ index.html / pet.html / monitor.html   三窗口入口
│  ├─ package.json
│  ├─ README.md              功能与配置说明
│  │
│  ├─ desktop/               ★ 主进程（Node 侧）
│  │  ├─ main.cjs            窗口/IPC/HTTP 服务/托盘
│  │  ├─ preload.cjs         contextBridge 白名单
│  │  ├─ companion.cjs       DeepSeek 对话
│  │  ├─ tts.cjs             语音合成调度（本地优先）
│  │  ├─ local-tts.cjs       本地 TTS 客户端
│  │  ├─ tts_server.py      常驻合成服务（piper/kokoro）
│  │  ├─ luckin.cjs          瑞幸官方 MCP 客户端
│  │  ├─ coffee.cjs          通用商户适配器
│  │  ├─ coffee-demo.cjs     本机演示服务
│  │  ├─ location.cjs        Windows 原生定位
│  │  └─ screen-brightness.cjs  WMI 屏幕亮度
│  │
│  ├─ src/
│  │  ├─ core/               纯算法，无 UI 依赖（最容易写测试）
│  │  │  ├─ face.js          MediaPipe 封装
│  │  │  ├─ fusion.js        视觉+EEG 融合（0.7/0.3）
│  │  │  ├─ state.js         状态机
│  │  │  ├─ bands.js          FFT + 频带
│  │  │  └─ eeg.js           EEG 回放
│  │  ├─ app/                界面逻辑
│  │  ├─ desk/               工位控制（灯光/音乐/MQTT）
│  │  ├─ pets/               桌宠 + Live2D + 语音
│  │  └─ desktop/            三个窗口各自的入口
│  │
│  ├─ public/                素材（Live2D 模型、MediaPipe、EEG 回放）
│  └─ tests/                 全部测试
│
├─ server/                   Python 咖啡网关
│  ├─ bailu_coffee_adapter.py  FastAPI 网关
│  ├─ start_bailu_demo.py      一键启动器
│  ├─ demo_config.py           配置读写
│  └─ setup_demo_config.py     命令行配置
│
├─ tests/                    Python 网关测试
└─ data_prep/                EEG 预处理（raw/*.edf 未入库）
```

---

## 五、核心算法（`src/core/`）

新人最该先读这里，因为**纯函数、无副作用、好测**。

### 视觉 → 分数（`fusion.js`）

```js
focus   = 100 - 偏头惩罚 - perclos × 200
fatigue = perclos × 300 + 哈欠 × 10 + 长闭眼 × 10 + 眨眼偏离
```

偏头惩罚：`|yaw| > 15°` 和 `|pitch| > 12°` 各按超出的度数乘系数。

### 融合

```js
focus   = 0.7 × 视觉 + 0.3 × EEG
fatigue = 0.7 × 视觉 + 0.3 × EEG
```

任一路缺失自动退化成单路。**注意**：EEG 只在「感知数据」页回放，不参与日常监测评分，因为公开数据集不是用户本人。

### 状态机（`state.js`）

6 个状态：`away / drowsy / tired / distracted / focused / normal`

**进入和保持用不同阈值**（迟滞，防抖动）：

| 状态 | 进入 | 保持 |
|---|---|---|
| 困倦 | fatigue > 75 | > 65 |
| 疲劳 | fatigue > 55 | > 45 |
| 分心 | focus < 40 | < 50 |
| 专注 | focus > 70 | > 60 |

外加 `hold 3s` 防抖 + `minDwell 5s` 最小停留。

---

## 六、退出程序：三条路，别只指望托盘

Windows 的通知区域有时会拒绝注册托盘图标（受管控的机器、特殊 ACL、只读的用户目录）。托盘一丢，用户就没法退出程序了。所以现在有**三条独立的退出路径**：

| 方式 | 位置 |
|---|---|
| 托盘图标右键 →「退出 NeuroDesk」 | 系统通知区 |
| 工作台「工位与提醒 → 退出 NeuroDesk → 退出应用」 | 界面内，最可靠 |
| 快捷键 `Ctrl + Shift + Q` | 任何时候 |

`npm run test:quit` 会验证界面按钮和 IPC 真的能结束进程。

> **开发环境提示**：DSH 沙箱会给 `E:\office_workspace` 加 `Everyone:(DENY)(DC)` 标记，并让 Electron 进程对 C 盘只读。这种环境下托盘图标**必然不显示**（Windows 通知区域拒绝注册），但用资源管理器双击 CMD 运行时不受影响。如果你在沙箱里测试，请以「界面里的退出按钮」为准。
>
> 之前 7 号文档里的 `--user-data-dir=%ND_ROOT%\.runtime\electron-userdata` 已从 CMD 中移除——那个目录带 DENY 标记，正是托盘消失的直接原因。

### 托盘图标不显示时怎么排查

`desktop/main.cjs` 的 `resolveUserData()` 会在启动时挑一个能正常承载 Chromium 单实例锁和托盘注册的目录，并依次跳过这些不安全的目录：

1. `Everyone:(DENY)(DC)` 的目录 —— 写文件没问题，但 Chromium 替换锁文件会失败，**托盘图标静默消失**
2. 删/改名文件失败的目录
3. 不可写的目录

所以**别把 `--user-data-dir` 指向项目目录**（例如 `web\.runtime\electron-userdata`）——项目目录常带 `DENY` 标记。CMD 里已经去掉了这个参数，改由程序自己选。

排查命令：

```powershell
icacls "C:\Users\w\AppData\Roaming\neurodesk-desktop"   # 看有没有 (DENY)(DC)
```

---

## 七、咖啡：三套 provider，别搞混

这是最容易踩坑的地方。`main.cjs` 的选择逻辑：

```js
useLuckin = PROVIDER === 'luckin'
         || (!PROVIDER && !COFFEE_API && !TEST && 有 Token)

useCoffeeDemo = !useLuckin && COFFEE_DEMO !== '0' && !COFFEE_API
```

优先级：**显式 `PROVIDER=luckin` > 显式 `COFFEE_API`（商户适配器）> 瑞幸 Token > 本机演示**

> **曾经的坑**：白鹭湾启动器只设 `COFFEE_API` 不设 provider，而 `luckin-config.json` 里有 Token，结果白鹭湾被瑞幸静默劫持。已修：白鹭湾显式设 `PROVIDER=adapter`，`main.cjs` 也加了「有 COFFEE_API 就不选瑞幸」。

| Provider | 真实度 | 入口 |
|---|---|---|
| `luckin` | **真实商户**：官方 MCP、真实门店/报价/支付码 | `启动NeuroDesk.cmd`（需已保存 Token） |
| `adapter` | 本机网关模拟，不扣款 | `启动白鹭湾正式版.cmd` |
| `local-demo` | 明确标注「本机演示」，四阶段进度 | `启动NeuroDesk.cmd`（无 Token 时） |

### 瑞幸真实下单链路

```text
点击定位 → Windows 定位 → 经纬度发给瑞幸
  → queryShopList（真实门店）
  → searchProductForMcp（真实商品）
  → queryProductDetailInfo + switchProduct（选规格）
  → previewOrder（真实报价，含优惠券，5 分钟有效）
  → createOrder（下单，返回 64 位订单号 + 支付二维码）
  → queryOrderDetailInfo（轮询状态/取餐码）
```

**安全设计**（别拆掉）：
- 下单前重新 preview，价格或优惠变了就拒绝
- 订单提交前**先落盘**「submitting」，超时不自动重试，重启后仍保持待核实
- 支付链接白名单校验，只允许微信官方和 lkcoffee 域名
- 一次只允许一笔在途订单

---

## 八、语音：本地 piper，真实口型

```text
DeepSeek 回复 → hub.utter()
  → speech.say() → 主进程 tts.cjs → 本地 tts_server.py（常驻）
  → 写到 .runtime/tts-cache/<hash>.audio（WAV）
  → 渲染层 <audio src="/tts?id=<hash>">
  → WebAudio 分析真实 RMS 电平
  → Live2D ParamMouthOpenY
```

**完全离线**，不依赖网络。实测延迟：

| 引擎 | 8 字句 | RTF | 体积 | 说明 |
|---|---|---|---|---|
| **piper**（默认） | 约 0.5 秒 | 0.26 | 20 MB | VITS 中文，实时对话够用 |
| kokoro（可选） | 约 3.9 秒 | 1.8 | 205 MB | 音色更好但偏慢，需自行下载 |
| edge-tts（兜底） | 3–4 秒 | — | 0 | 本地模型缺失时自动接管，**需联网** |

### 关键点

- **常驻服务**：`desktop/tts_server.py` 由主进程按需拉起，模型只加载一次，走 `127.0.0.1:18090`。退出应用时自动结束。
- **依赖**：`pip install sherpa-onnx`（实测 2.0.1 可用）。
- **模型位置**：`web/.runtime/piper/`（已随包附带）。kokoro 需自行下载放到 `web/.runtime/kokoro/`。
- 缓存键是 `sha256(引擎|音色|语速|文本)`——**引擎参与 key**，同一句话在不同引擎下不会串味。命中 0 ms。
- 合成失败 → 退回 edge-tts → 再失败退回系统 `speechSynthesis` + 定时张合口型。
- 调试环境变量：`NEURODESK_TTS_ENGINE`（`piper`/`kokoro`）、`NEURODESK_TTS_PORT`、`NEURODESK_TTS_PYTHON`、`NEURODESK_TTS=0`（关闭）。

> 曾经的坑：edge-tts 每次合成要 3–4 秒往返微软，直播现场网络一抖就哑火。现在默认走本地 piper，快 6 倍且不联网。

---

## 九、测试怎么跑

```powershell
cd E:\office_workspace\hks\web

npm test                  # 28 个单元测试（算法/咖啡/亮度/瑞幸/陪伴/TTS）
npm run test:ui           # 页面冒烟（四视图、无假数据）
npm run test:desktop      # 桌面回归（窗口生命周期、监测、桌宠）
npm run test:orders       # 订单端到端（适配器 + 本机演示）
npm run test:luckin-ui    # 瑞幸界面（合成数据走完整流程）
npm run test:luckin-desktop
npm run test:companion-ui / test:companion-desktop
npm run test:bailu        # 白鹭模式（自动拉起网关）
npm run test:tts          # 真实合成 + 播放验证
npm run test:brightness   # ⚠️ 会真的调你屏幕亮度，结束恢复
```

Python 网关：

```powershell
cd E:\office_workspace\hks
python tests\test_bailu_gateway.py
```

### 两条重要规矩

**1. 不要并行跑桌面测试**

`main.cjs` 用固定端口（可 `NEURODESK_PORT` 覆盖），并行会撞端口。**串行跑**。

**2. 临时目录设到项目内**

Windows 上 `%TEMP%` 可能不可写，导致 esbuild / electron-builder 报 `Access is denied`：

```powershell
$env:TMP = "E:\office_workspace\hks\web\.runtime\tmp"
$env:TEMP = $env:TMP
```

---

## 十、已经踩过的坑（省你几个小时）

| 坑 | 症状 | 原因 / 修法 |
|---|---|---|
| CMD 里有中文 | 命令被截断，报 `'OOT'` 之类的怪错 | `cmd.exe` 代码页问题。**所有 .cmd 必须纯 ASCII** |
| `%APPDATA%` 不可写 | 静默退出，日志 `Lock file can not be created Error code: 5` | CMD 里 `--user-data-dir` 指到 `web\.runtime\electron-userdata` |
| 打包版读不到密钥 | exe 启动后走本机演示 | `runtimeRoot` 打包时取 `dirname(execPath)`，要**上溯两级**到 `web/.runtime` |
| Live2D 卡片空白 | 形象卡片区域全白 | 多 Pixi 实例共享纹理缓存冲突，卡片改用静态预览 |
| 桌面 CSP 报 `unsafe-eval` | Live2D 模型加载失败 | 接 `@pixi/unsafe-eval` 适配模块，别放宽 CSP |
| 虚拟摄像头轨道 ended | 后台监测被误停 | 改成基于**真实帧时间**的 5 秒看门狗 |
| 打包卡住 | electron-builder 不产出 exe | 有 NeuroDesk.exe 在跑，锁了 `release\win-unpacked`。先关掉 |
| 测试不退出 | 打印通过后永久挂起，残留网关占端口 | fixture 派生孙进程。改成直接 spawn + `stdio:'ignore'` |
| 白鹭被瑞幸劫持 | 网关起来了界面不认 | 见第六节，显式设 `PROVIDER=adapter` |
| edge-tts 403 | 合成失败，回退系统语音 | 版本太旧，升到 7.3.1+（本地 piper 为主路径时不会触发） |
| 语音延迟 3-4 秒 | 现场网络抖动导致哑火 | 装 piper 本地模型，默认走本地 |
| **托盘图标不显示** | 程序能跑，但右下角没有图标，右键菜单里也没有「退出」 | Windows 通知区域拒绝注册。根因是 userData 目录带 `Everyone:(DENY)(DC)`（DSH 沙箱会给工作区加这个标记）。程序已自动避开；若仍不显示，用工作台里的「退出应用」按钮或 `Ctrl+Shift+Q` |
| `Lock file can not be created! Error code: 5` | Electron 一启动就退出，无窗口 | 同上，单实例锁写在 userData 里。**别用 `--user-data-dir` 指向项目目录** |
| electron.exe 闪退 `0xc0000005` | 开发模式起不来 | C 盘空间耗尽。`electron.exe --version` 就能复现，先清磁盘 |
| 单元测试偶发 EPERM | `rename orders.json.tmp` 失败 | Windows 文件锁，串行跑就好 |

---

## 十一、还没做的（你可以接的活）

### P0 — 直接影响演示

| 缺口 | 现状 | 建议做法 |
|---|---|---|
| **ASR 语音识别** | 依赖浏览器 `webkitSpeechRecognition`，国内常报 `network` | 接 faster-whisper 到主进程，走 `/asr` 类似 TTS 的路径 |
| **MQTT + 固件** | `src/desk/mqtt.js` 齐全，但没 broker 配置、没 `paho-mqtt`、没 ESP32 固件 | 建 `broker/mosquitto.conf` + 固件，和硬件一起做 |

### P1 — 工程完整性

| 缺口 | 说明 |
|---|---|
| **没有 Git 仓库** | 建议接手第一件事：`git init` + 首次提交。`.gitignore` 已配好 |
| portable 单文件 | `npm run pack:portable` 已配好，需 NSIS 工具 |
| exe 未签名 | 换机首次弹 SmartScreen，现场可能被拦 |
| 没有演示录屏 | 摄像头/网络翻车时的保命备份 |

### P2 — 产品化

- 白鹭湾网关仍是本机模拟（瑞幸那条是真的）
- 飞书 Webhook 单向，没有取餐确认/评价/退款回流
- 高德只用了周边搜索，没用路径规划/地理围栏
- 没有首次启动引导、错误上报、番茄钟统计持久化
- EEG 只导出了 Subject03

---

## 十二、配置在哪

### 密钥（都不进 Git）

| 文件 | 内容 |
|---|---|
| `web/.runtime/deepseek-config.json` | `{ apiKey, model, shareStatus, proactive }` |
| `web/.runtime/luckin-config.json` | `{ token }`，瑞幸官方 AI 平台取的 |
| `server/.runtime/demo-config.json` | `{ webhook, amap }`，飞书小票 + 高德 Key |

### 环境变量

| 变量 | 作用 |
|---|---|
| `NEURODESK_COFFEE_PROVIDER` | `luckin` / `adapter` |
| `NEURODESK_COFFEE_API` | 商户适配器地址（含这个就不选瑞幸） |
| `NEURODESK_COFFEE_DEMO=0` | 关本机演示 |
| `NEURODESK_COFFEE_LOCATION=bailu` | 固定园区坐标，不申请定位 |
| `NEURODESK_TTS=0` | 关神经网络语音 |
| `NEURODESK_TTS_VOICE` / `_RATE` | 音色 / 语速（`+0%` 形式） |
| `NEURODESK_PORT` | 本地 HTTP 端口，默认 17863 |
| `NEURODESK_TEST=1` | 测试模式：不读真实密钥、不请求远端 |
| `BAILU_CAR_UDP_DRY_RUN=1` | 只记日志，不发 UDP 发车 |

### 端口

```text
17863  本地 HTTP（静态资源 + /tts）
18082  白鹭湾网关
18081  本机演示咖啡服务
8888   UDP 发车广播（→ 无人车）
```

---

## 十三、你该从哪开始

### 第一天

1. 按第二节跑起来，确认桌宠出现、能打开工作台
2. 跑 `npm test` 和 `npm run test:desktop`，确认全绿
3. 读 `src/core/fusion.js` + `state.js`（最短、最独立）
4. 读 `desktop/main.cjs` 的窗口创建和 IPC 注册部分

### 动手前必读

- **改主进程** → 先看第三节三条铁律
- **改咖啡** → 先看第六节 provider 优先级
- **改测试** → 串行跑、临时目录设项目内
- **改 .cmd** → 纯 ASCII，一个中文字都不能有

### 提问前自查

- 是不是并行跑了桌面测试？
- 是不是 `%TEMP%` 不可写？
- 是不是有 NeuroDesk.exe 在跑，锁了文件？
- 打包版问题 → 先查 `runtimeRoot` 路径对不对

---

## 附：一句话记忆点

> 三个窗口、摄像头只在 monitor、密钥只在主进程、卡片用静态预览、CMD 纯 ASCII、测试串行跑、打包路径上溯两级。
