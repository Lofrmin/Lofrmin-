# NeuroDesk 交接文档

> 面向接手队员。读完这份文档，你应该能：**在一台干净的 Windows 机器上从零跑起项目**、**看懂队友最初做了什么、我改了什么、为什么这么改**、**知道哪些地方是坑**、**下一步该补什么**。
>
> 项目路径：`E:\office_workspace\hks`
> 当前状态：瑞幸真实点单 + DeepSeek 陪伴 + edge-tts 语音 + Live2D 已跑通；硬件未接入
> 密钥已随包附带（可信内部交接），见第四节
>
> **新人先读 [ONBOARDING.md](ONBOARDING.md)**（15 分钟上手版），需要深挖细节或查历史决策再回到本文。

---

## 一、项目是什么

**一句话**：Windows 原生桌宠 + 后台视觉疲劳监测 + 白鹭湾园区咖啡下单 + 无人车联动的演示系统。

**给评委的完整叙事**（4 分钟）：

1. 桌面上只挂一只 Live2D 小日和（不占屏幕空间，视线跟随鼠标）
2. 后台隐藏窗口以 15 FPS 跑 MediaPipe，本机计算眨眼 / PERCLOS / 哈欠 / 转头，**画面不上传**
3. 检测到疲劳 → 桌宠变表情 + 语音提醒 + 自动弹出园区咖啡推荐
4. 点下单 → 企业餐补直付 → 手机飞书立刻收到电子小票 → 进度到第 3 步时桌上实体小车发车
5. 强调三件事：**原生桌面程序**、**感知全本地**、**B2B 企业授信直付**（不是让你掏手机扫码）

---

## 二、开发历程：从队友的初始 demo 到现在

这一节是给接手人最重要的上下文。知道"为什么变成这样"，比知道"现在是什么样"更能避免改错。

### 2.1 起点：队友的初始 demo

队友交付的版本是**已经成型的 Electron 桌面应用**，包含：

- 三窗口 Electron 壳（工作台面板 / 桌宠 / 隐藏感知）
- MediaPipe 视觉疲劳监测（眨眼、PERCLOS、哈欠、转头）
- EEG 数据集回放 + FFT 频段指数
- 多模态融合 + 带迟滞的状态机（6 状态）
- 7 只 SVG 宠物 + 自定义形象上传 + 悬浮窗
- 灯光、WebAudio 生成音乐（3 首，无版权素材）
- 番茄钟、喝水提醒、聊天（本地关键词意图）
- 咖啡下单骨架：门店查询 / 幂等下单 / 订单状态查询
- 一套测试（算法、UI、桌面、订单）

**当时咖啡是什么状态**：只有骨架和接口约定，默认连 `127.0.0.1:18081` 本机演示适配器，界面显示「本机演示」黄标，订单号 `DEMO-` 前缀。有真实商户适配器（`desktop/coffee.cjs`），但没有可对接的商户后端。

**当时的启动问题**：`启动NeuroDesk.cmd` 打不开。

### 2.2 第一轮：修启动 + Live2D + 咖啡 API

**① 启动故障排查（三个真实原因）**

| 现象 | 根因 | 修法 |
|---|---|---|
| CMD 双击没反应 | Electron 默认用户目录 `%APPDATA%\neurodesk-desktop` 在受限环境创建单实例锁失败：`Lock file can not be created Error code: 5` | CMD 里加 `--user-data-dir` 指向 `web\.runtime\electron-userdata` |
| 同样双击没反应 | 受限环境需要 `--no-sandbox` | CMD 加该参数（保留 `contextIsolation`、禁 Node 集成） |
| 改了 CMD 后命令被截断 | 批处理里有中文，`chcp 65001` 下被错误解析，报 `'OOT' is not recognized` | 三个 CMD 全部改成**纯 ASCII** |

**② Live2D 接入（从零开始）**

项目原本只有 SVG 宠物，没有 Live2D。做了这些：

- 下载官方 Hiyori 模型 + Cubism Core 到 `public/live2d/`（本地加载，不依赖 CDN）
- 装 `pixi.js@6.5.10` + `pixi-live2d-display@0.4.0`（社区验证最多的组合）
- 新建 `src/pets/live2d.js`：待机动作、自动眨眼、视线跟随、点击动作、情绪参数、说话口型
- 改造 `src/pets/view.js`：`setPet` 支持 `def.live2d`，异步加载 + 竞态保护（快速切换形象不会串）
- 新建 Hiyori 形象卡（`library.js`），默认选中

**踩到的三个坑**：

| 问题 | 根因 | 修法 |
|---|---|---|
| 舞台空白 | 形象卡片和主舞台各自创建 Pixi 应用，共享纹理缓存导致跨 WebGL 上下文冲突 | 卡片改用静态预览图 `hiyori-preview.png`，只有主舞台和桌宠各持一个真实实例 |
| 只显示躯干 | 直接用 `model.width/height` 取景 | 改用 `getBounds()` 计算自然边界再缩放居中 |
| Electron 里白屏 | 桌面 CSP 比浏览器严格，Pixi 需要 `new Function` 编译着色器，报 `Current environment does not allow unsafe-eval` | 装 `@pixi/unsafe-eval@6.5.10`，`install(PIXI)` |

**③ 咖啡 API 从骨架到可用**

- 新增 `desktop/coffee-demo.cjs`：本机 18081 演示适配器，四阶段进度
- 网关客户端 `coffee.cjs` 加 `orderStatus()`，支持进度查询
- 前端加订单状态轮询（2 秒一次），显示 `x/4`
- 修复一个真实 bug：`coffee-dialog.js` 里把 `configured`（布尔）和整个配置对象混用，导致演示模式也去申请系统定位

### 2.3 第二轮：白鹭湾商户网关

按 `neurodesk (2).md` 第一部分实现：

- 新建 `server/bailu_coffee_adapter.py`（FastAPI，端口 18082）
- 三家园区门店、四阶段状态、UDP 发车触发
- **比文档版本多做了三件事**（文档版会丢数据）：
  - 订单与幂等键原子落盘到 `server/.runtime/bailu_orders.json`
  - `carTriggered` 标记持久化，重启不重复发车
  - 幂等键参数冲突检测（同 key 不同参数返回 409）
- 桌面端加固定园区坐标支持：`NEURODESK_COFFEE_LOCATION=bailu` 时不再申请系统定位
- 新增 `启动白鹭咖啡演示.cmd` + `server/start_bailu_demo.py`

**踩到的坑**：

| 问题 | 根因 | 修法 |
|---|---|---|
| 启动器卡住不起网关 | 批处理里 `start` + `^>` 转义在嵌套 cmd 下失效 | 改成 Python 启动器负责起网关、等健康检查、再拉桌面 |
| 发车计数重启后对不上 | 先落盘标记、后自增计数，顺序错 | 改为先发车+计数，再一起原子落盘 |
| 测试复用了残留数据目录 | 计数累积导致断言失败 | 测试改用独立临时目录 |

### 2.4 第三轮：真实感升级

按 `neurodesk (3).md` 第一部分升级：

- 门店从 2 家扩到 3 家（加星巴克），真实街道地址
- 订单号 `BAILU-` → `LK + 月日 + 6 位随机`
- 状态 `accepted` → `paid`（企业餐补直付），界面显示「已支付」
- 新增飞书/企微/Bark Webhook 电子小票（后台线程推送）
- 新增高德周边 POI 搜索（可选）
- 新增 `server/demo_config.py` + `setup_demo_config.py`：配置持久化，不用每次手工 set 环境变量

**这轮修的两个隐患**：

| 问题 | 根因 | 修法 |
|---|---|---|
| 高德动态门店下单 404 | 网关按内置门店校验，不认高德 POI ID | 网关用 `DYNAMIC_STORES` 记住当次查询的 POI |
| 星巴克门店挂瑞幸菜单 | 所有动态 POI 都套 `STORES[0]` 的菜单 | 加 `_menu_for(name)` 按品牌匹配菜单 |

另外把高德 POI 和园区门店**合并**（按距离排序 + 同品牌去重），而不是完全替换——高德额度用尽或断网时园区门店仍在。

### 2.5 第四轮：配置密钥并验证

- 飞书 Webhook 实测打通：返回 `{"code":0,"msg":"success"}`，手机收到小票
- 高德 Key 实测有效：返回 3 家真实瑞幸（828m / 1489m / 1828m）
- 实测高德动态门店可下单：`LK10274ACD0C`
- 最终形态：4 家门店（3 内置 + 1 高德）、`LK` 单号、`paid`、飞书小票、第 3 阶段发车

### 2.6 第五轮：队友迭代合并（2026-10-29）

队友送来一版大更新，新增四个模块，并修掉三个真实缺陷后合并入本仓库。

**队友新增**：

| 模块 | 实现 |
|---|---|
| 瑞幸真实点单 | `desktop/luckin.cjs` 走官方 MCP `gwmcp.lkcoffee.com`，7 个工具：查店/搜品/选规格/报价/下单/查单；订单号 64 位、幂等、跨重启防重试 |
| DeepSeek 陪伴 | `desktop/companion.cjs` 主进程直连官方 API，流式输出 + 工具建议 + 主动关心；密钥只进主进程 |
| 屏幕亮度 | `desktop/screen-brightness.cjs` WMI 真实调节，串行化 + 回读校验 |
| Windows 定位 | `desktop/location.cjs` `GeoCoordinateWatcher`，点击后才定位 |

**修掉的三个缺陷**：

| 缺陷 | 症状 | 根因 | 修法 |
|---|---|---|---|
| 白鹭湾被瑞幸静默劫持 | 网关起来了但界面不认 | `luckin-config.json` 有 Token，启动器不设 provider，优先级判定走瑞幸 | `main.cjs` 加「显式适配器优先」；`start_bailu_demo.py` 显式设 `PROVIDER=adapter` |
| **打包版丢失全部配置** | exe 启动后读不到 Token/Key，静默退回本机演示 | `runtimeRoot` 打包时取 `dirname(execPath)`，即 `release/win-unpacked/.runtime` | 打包时上溯两级到 `web/.runtime` |
| 白鹭测试永久挂起 | 打印通过后不退出，残留孤儿网关占 18182 | `bailu_fixture.py` 再派生孙进程，杀 fixture 时孙进程存活且管道不关 | 直接 spawn 网关本体 + `stdio:'ignore'` + 轮询等端口释放 |

顺带把写死的 17863 改成 `NEURODESK_PORT` 可配 + 端口占用自动回退，解决并行测试冲突。

### 2.7 第六轮：接入 edge-tts 神经网络语音（2026-10-29）

原来的口型是 `Math.sin` 假张合，语音是浏览器机械音。这一轮换成真实音频驱动。

- `desktop/tts.cjs`：`python -m edge_tts` 合成，**必须 7.3.1+**（7.2.8 被微软返回 `403 Invalid response status`）
- `src/pets/speech.js`：`<audio>` 播放 + WebAudio 分析真实 RMS 电平
- `live2d.js` 新增 `lipSync()/stopLip()`：用真实音频电平驱动 `ParamMouthOpenY`，合成失败时自动退回定时张合
- `/tts?id=<hash>` 本机端点：只接受 32 位哈希，伪造/越权一律 404
- 缓存按 `sha256(音色|语速|文本)` 落 `web/.runtime/tts-cache/`，命中 0 ms，上限 48 条
- 合成串行排队（每次一个 websocket），失败时删除 0 字节文件，启动时清扫残留

实测：首次合成 3.3–4.8 s、缓存命中 0 ms、音频可播放 2.88 s。

### 2.8 变更文件总览

**新增**：

```text
HANDOFF.md                        本文档
.gitignore                        排除依赖/产物/密钥
server/bailu_coffee_adapter.py    咖啡商户网关
server/start_bailu_demo.py        一键启动器
server/demo_config.py             配置读写
server/setup_demo_config.py       命令行配置工具
server/demo-config.example.json   脱敏示例
tests/test_bailu_gateway.py       网关端到端测试
tests/bailu_fixture.py            测试用网关 fixture
web/desktop/coffee-demo.cjs       本机演示适配器
web/src/pets/live2d.js            Live2D 封装
web/tests/desktop-bailu-orders.mjs 白鹭模式桌面测试
web/desktop/luckin.cjs           瑞幸官方 MCP 客户端
web/desktop/companion.cjs        DeepSeek 陪伴
web/desktop/location.cjs         Windows 原生定位
web/desktop/screen-brightness.cjs WMI 屏幕亮度
web/desktop/tts.cjs             edge-tts 语音合成
web/src/pets/speech.js           真实音频播放与电平
web/src/app/luckin-dialog.js     瑞幸点单界面
web/tests/tts.test.mjs           TTS 单元测试
web/tests/desktop-tts.mjs        TTS 桌面端到端
web/tests/fake-camera.mjs         循环视频测试输入
启动白鹭湾正式版.cmd               演示入口
```

**修改（关键）**：

```text
web/src/pets/view.js              setPet 支持 Live2D + 竞态保护
web/src/pets/library.js           加 Hiyori 形象
web/src/pets/gallery.js           卡片改用静态预览
web/src/app/coffee-dialog.js      定位判断 bug、商户模式文案
web/src/desk/coffee.js            加 demo/merchant 标记
web/desktop/main.cjs              咖啡 demo 服务、园区坐标、orderStatus IPC
web/desktop/preload.cjs           暴露 orderStatus
web/src/core/camera.js            看门狗改为基于帧时间（修虚拟摄像头误停）
web/src/desktop/monitor.js        onError 清 camera 引用（避免覆盖错误状态）
web/index.html, pet.html          引入 Cubism Core
web/package.json                  加 pixi 依赖、test:bailu 脚本
web/tests/*.mjs                   改用项目内 Playwright、独立 userData、循环视频
启动NeuroDesk.cmd                 纯 ASCII + user-data-dir + --show-panel
```

---

## 三、目录结构

```
hks/
├─ HANDOFF.md                    ★ 本文档
├─ .gitignore                    排除依赖/产物/密钥
├─ 启动NeuroDesk.cmd            普通启动（本机演示咖啡）
├─ 启动白鹭湾正式版.cmd          【演示用这个】园区商户 + 飞书 + 高德
├─ data_prep/
│  ├─ prep_eeg.py                EDF → session.json
│  └─ raw/                       原始 EDF（本包已排除，需从 PhysioNet 下载）
├─ server/
│  ├─ bailu_coffee_adapter.py    ★ 咖啡网关（端口 18082）
│  ├─ start_bailu_demo.py        ★ 一键启动器
│  ├─ demo_config.py             配置读写
│  ├─ setup_demo_config.py       命令行配置
│  ├─ demo-config.example.json   脱敏示例
│  └─ .runtime/demo-config.json  ★ 真实密钥（本包已附带）
├─ tests/
│  ├─ test_bailu_gateway.py      ★ 网关端到端测试
│  └─ bailu_fixture.py           测试 fixture
└─ web/
   ├─ desktop/
   │  ├─ main.cjs                ★ Electron 主进程
   │  ├─ preload.cjs             contextBridge API
   │  ├─ coffee.cjs              ★ 咖啡网关客户端
   │  └─ coffee-demo.cjs         本机 18081 演示
   ├─ src/
   │  ├─ main.js                 面板入口
   │  ├─ core/                   EEG、人脸、融合、状态机
   │  ├─ pets/                   Live2D + SVG 宠物 + 上传 + 悬浮窗
   │  ├─ app/                    聊天、反应、感知循环、UI 绑定
   │  ├─ desk/                   灯光、音乐、MQTT、咖啡
   │  └─ desktop/                三个渲染进程
   ├─ public/
   │  ├─ live2d/                 Hiyori + Cubism Core + 许可证
   │  ├─ mediapipe/              wasm + face_landmarker.task
   │  └─ eeg/session.json        Subject03 回放数据
   └─ tests/                     Playwright + Electron 测试
```

**架构约束（必须遵守）**：

- 三个独立渲染进程：`index.html`（工作台）、`pet.html`（桌宠）、`monitor.html`（隐藏感知）
- 摄像头权限**只授予 monitor**，面板不持有摄像头，所以关掉工作台监测继续
- 面板和桌宠通过主进程 `broadcast` 同步，不能直接互相引用
- Live2D 只能主舞台和桌宠各持一个实例，**形象卡片必须用静态预览**

---

## 四、密钥与配置

**本包已附带真实配置**（内部可信交接）：

```json
// server/.runtime/demo-config.json
{
  "webhook": "https://open.feishu.cn/open-apis/bot/v2/hook/5f3365c5-e58c-44a1-8b48-62b5312e449e",
  "amap": "86a7e228a2ed242e4712883bb9486c8e"
}
```

| 用途 | 说明 |
|---|---|
| 飞书 Webhook | 下单即推送电子小票到手机，已实测 `code:0 success` |
| 高德 Key | Web 服务 Key，周边搜索，已实测返回真实门店 |

**注意**：

- 这两个 Key 只在本团队内部使用，**不要提交到公开仓库、不要发到公开群、不要出现在公开截图里**
- 高德 Key 有免费日额度，超限返回 `DAILY_QUERY_OVER_LIMIT`，网关会自动回退内置门店
- 要换 Key 时：
  ```powershell
  python server\setup_demo_config.py --webhook "新Webhook"
  python server\setup_demo_config.py --amap "新Key"
  python server\setup_demo_config.py --show
  ```
- 配置优先级：环境变量 > `server/.runtime/demo-config.json` > 内置默认

---

## 五、环境准备

### 5.1 必需

| 依赖 | 版本 | 说明 |
|---|---|---|
| Node.js | ≥ 20（实测 24.12） | 前端构建 + Electron |
| Python | ≥ 3.10（实测 3.13） | 咖啡网关 |
| Windows | 10 22H2+ | Electron 42 要求 |

### 5.2 安装

```powershell
cd E:\office_workspace\hks\web
npm install

cd E:\office_workspace\hks
python -m pip install fastapi uvicorn pydantic httpx `
  -i https://mirror.nju.edu.cn/pypi/web/simple
```

**当前机器已验证可用的 Python 依赖**：`fastapi` `uvicorn` `pydantic` `httpx` `edge_tts` `numpy` `scipy` 都已安装。
**未安装**：`mne`（不需要，`prep_eeg.py` 自己解析 EDF）、`faster_whisper`（做 ASR 才需要）、`paho-mqtt`（做 MQTT 才需要）。

### 5.3 重新导出 EEG（可选）

`public/eeg/session.json` 已经是 Subject03 的数据，直接用即可。想换被试：

```powershell
cd E:\office_workspace\hks\data_prep
# 先下载 PhysioNet EEGMAT 的 EDF 到 raw/
python prep_eeg.py            # 自动挑「心算 vs 静息」差异最大的被试
python prep_eeg.py Subject05  # 指定被试
```

---

## 六、怎么跑（软件）

### 6.1 演示用这个（推荐）

双击 **`启动白鹭湾正式版.cmd`**

依次执行：
1. 检查 Python 依赖，缺了自动装
2. 打印当前配置（飞书/高德是否启用）
3. 起网关 `127.0.0.1:18082`，等 `/health` 通
4. 注入 `NEURODESK_COFFEE_API` / `TOKEN` / `LOCATION=bailu` 后启动桌面

成功标志：

```text
Bailu Coffee Gateway ready: http://127.0.0.1:18082/api
  飞书电子小票: 已启用
  高德真实门店: 已启用
Starting NeuroDesk merchant mode...
```

### 6.2 普通启动

双击 **`启动NeuroDesk.cmd`**，显示「本机演示」黄标，订单号 `DEMO-` 前缀。

### 6.3 开发模式

```powershell
cd E:\office_workspace\hks\web
npm run dev          # 浏览器预览，无桌面能力
npm run desktop      # 用已有 dist 起 Electron
npm start            # 构建 + 起 Electron
```

### 6.4 只测网关

```powershell
cd E:\office_workspace\hks
python tests\test_bailu_gateway.py
```

---

## 七、硬件部分（STM32F407VET6 + 白鹭湾无人车）

> 详细排错见 [`KEIL_JLINK_NOTES.md`](E:/office_workspace/hks/KEIL_JLINK_NOTES.md)。

### 7.1 当前状态

| 项目 | 状态 |
|---|---|
| Keil 5.14 + J-Link OB | ✅ 已通，V9.88 驱动已装，29 个例程全部修好 |
| 器件包 | ✅ 2.11.0（**必须 2.9+**，1.0.8 没有 512KB 算法） |
| 下载烧录 | ✅ `Erase Done / Programming Done / Verify OK` |
| LED 闪烁 | ✅ PA1 500ms 翻转，实测 ODR bit1 在 0/1 之间跳 |
| 电机焊接 | ✅ 已焊好 8 根线 |
| HC-05 底板 | ⏳ 待到货（4 针够用，6 针的 EN/STATE 用不上） |
| 舵机 / OLED / 超声波 | ⏳ 待接线 |
| 综合固件工程 | ✅ `firmware/bailu_car/` 编译 0 error，下载 Verify OK |

### 7.2 烧录（推荐用脚本，避开 Keil 各种坑）

```powershell
cd E:\office_workspace\hks
python tools\jlink_flash.py "E:\Keil\...\例1 LED灯\OBJ\LED.hex"
```

成功输出 `O.K.`。脚本自动处理中文路径问题。

### 7.3 综合固件工程（白鹭湾无人车）

位置：`firmware/bailu_car/`（含 README.md 完整说明）。

一个工程跑齐 OLED / 舵机 / 电机 / 按键 / 蓝牙，触发方式三选一（按 K0 / 蓝牙发 `G` / 上位机发 `G`）：

```powershell
# 编译（-f 不隐含编译，必须先 -b）
E:\Keil_v5\UV4\UV4.exe -b "USER\LED.uvprojx" -t LED -j0 -o build.log
E:\Keil_v5\UV4\UV4.exe -f "USER\LED.uvprojx" -t LED -j0 -o flash.log

# 或绕过 Keil
python tools\jlink_flash.py "…\OBJ\LED.hex"
```

> **不要改 `<TargetName>`** —— Keil 5.14 的 `<nTsel>` 与它绑定，改了就报 Internal DLL Error。

### 7.4 Keil 修复脚本

```powershell
python tools\fix_keil_jlink.py "E:\Keil\STM32F407VE"      # 批量修 29 个例程的 J-Link 配置
python tools\rebuild_uvoptx.py "USER\LED.uvprojx" "USER\LED.uvoptx"  # 增删源文件后同步索引
python tools\build_bailu_project.py --target "<工程目录>"     # 整工程重建
python tools\jlink_flash.py "…\hex"                          # 绕过 Keil 直接烧
```

修：调试器换 J-Link、Flash 算法换 512KB、`JLinkSettings.ini` 的 Device 设为 `STM32F407VE`、器件名统一 VETx、PackID 统一 2.11.0、清理 J-Link 残留 TCP 会话参数。

### 7.5 例程对照

| 用途 | 工程 |
|---|---|
| 空模板 | `例程-库函数版本\Template工程模板\USER\Template.uvprojx` |
| 点灯 | `例程-库函数版本\例1 LED灯\USER\LED.uvprojx`（PA1） |
| 按键 | `例程-库函数版本\例2 按键输入\USER\KEY.uvprojx`（K0=PE4, K1=PE3） |
| 串口/蓝牙 | `例程-库函数版本\例3 串口实验\USER\USART.uvprojx`（PA9/PA10） |
| 舵机 PWM | `例程-库函数版本\例8 PWM输出\USER\PWM.uvprojx`（改 PA6） |
| OLED | `例程-库函数版本\例10  OLED显示\USER\OLED.uvprojx`（PB6/PB7） |

### 7.6 接线

| 模块 | 接法 |
|---|---|
| OLED | GND / 3V3 / PB6(SCL) / PB7(SDA) |
| SG90 舵机 | 棕=GND、红=5V 充电宝、橙=PA6 |
| HC-05 底板 | VCC=5V、GND=GND、**TXD→PA10**、**RXD→PA9**（交叉） |
| L298N 电机 | 左前+左后红→OUT1、黑→OUT2；右前+右后红→OUT3、黑→OUT4 |
| L298N 控制 | IN1→PA0、IN2→PA1、IN3→PA2、IN4→PA3；ENA/ENB 跳线帽插上 |
| L298N 供电 | 4×AA → +12V/GND；电源口并 1000µF |
| 舵机供电 | 5V 充电宝，并 470µF |

**所有 GND 必须共地**。J-Link 的 3.3V 只够调试，不够带舵机和电机。

### 7.7 已知硬件坑

- **F407VET6 只有 512KB Flash**，例程默认写的是 1MB，不改会 `Erase Failed`
- **器件包版本**：1.0.8 的算法在 `Flash\`，2.x 在 `CMSIS/Flash\`，工程引用路径必须匹配
- **`JLinkSettings.ini` 的 `Device="UNSPECIFIED"`** 会让 J-Link 找不到算法
- **GPIOA 基址是 `0x40020000`**（ODR=`0x40020014`），不是 `0x40010814`
- **GPIO 引脚在复位后默认是输入**，调试时看不到输出电平，要先 `r`（复位运行）再读
- **`delay_us` 单次上限约 798ms**（24 位 SysTick 计数器限制）
- **J-Link 打不开中文路径**，脚本已自动转存临时目录
- **改 `<TargetName>` 会报 Internal DLL Error**（`<nTsel>` 与它绑定）
- **增删源文件后必须同步 `.uvoptx`**（文件索引数与分组结构都要对）
- **卖家 OLED 驱动是 4 线 SPI**（PB12/13/14/15+PC5），与 4 针 I2C 模块不兼容 → 已重写为 I2C 版
- **这个 F4 库是精简版**：`GPIO_Mode_AF_PP` 要写成 `GPIO_Mode_AF`；无 HAL 的 `I2C_HandleTypeDef`

---

## 八、已完成的功能

### 7.1 感知链路（队友完成）

- **视觉**：MediaPipe FaceLandmarker，478 点 + 52 blendshape + 头部矩阵 → 眨眼频率、PERCLOS、长闭眼、哈欠、yaw/pitch
- **EEG**：PhysioNet EEGMAT 回放，滑窗 FFT + Hann 窗，θ/α/β → 投入度 β/(α+θ)、困倦度 (θ+α)/(α+β)，个人基线 z 分数
- **融合**：视觉 0.7 + EEG 0.3，EMA 平滑，状态机迟滞防抖（3 秒持续 + 5 秒最小停留）
- **6 状态**：focused / normal / distracted / tired / drowsy / away

> **注意**：EEG 是数据集回放，**不参与日常监测评分**；日常监测只靠摄像头。这是刻意设计，评委问起要如实说。

### 7.2 Live2D（本次接入）

- 官方 Hiyori 模型，本地加载
- 待机动作、自动眨眼、视线跟随、点击动作
- 情绪参数（嘴型/眉毛/脸红）、说话口型
- Electron 严格 CSP 下正常渲染
- 7 只 SVG 宠物 + 自定义上传仍可切换

### 7.3 咖啡链路（本次重点）

**桌面端** `web/desktop/coffee.cjs`：
- Bearer 鉴权、幂等键（16–80 字符）、价格复核
- 单飞（重复点击只提交一次）、超时复用原幂等键
- 订单状态轮询（2 秒一次）

**网关** `server/bailu_coffee_adapter.py`：
- 三家园区门店（瑞幸 160m / Manner 290m / 星巴克 680m）
- 订单号 `LK + 月日 + 6 位随机`，状态 `paid`
- 幂等键冲突 409、价格不符 409、门店不存在 404
- **订单与发车标记原子落盘**，重启不重复发车
- 第 3 阶段 UDP 广播 `CAR_RUN:<取餐码>` 到 `255.255.255.255:8888`，只发一次
- 飞书/企微/Bark 电子小票（后台线程，失败不影响订单，幂等重试不重发）
- 高德周边 POI 合并（按距离排序 + 同品牌去重），失败回退内置门店
- 高德动态门店可直接下单

### 7.4 桌面壳（队友完成 + 本次修复）

- 三窗口 + 托盘菜单
- 单实例锁、稳定 origin `127.0.0.1:17863`
- 关闭面板继续监测；休眠暂停、唤醒恢复
- 开机启动、系统通知
- 摄像头看门狗：连续 5 秒无新帧才报错（修了虚拟摄像头误停）

### 7.5 测试（全绿）

```powershell
cd E:\office_workspace\hks\web
npm test                # 算法 + 订单网关单测
npm run test:ui         # 页面布局 + Live2D
npm run test:desktop    # 三窗口 + 后台监测 + 桌宠 + 暂停恢复
npm run test:orders     # 商户适配器 + 本机演示下单
npm run test:bailu      # 白鹭模式端到端（自动拉网关）
```

根目录：`python tests/test_bailu_gateway.py`

**注意**：`npm test` 需要 `web/node_modules`，本包已排除依赖，先 `npm install`。

---

## 九、还没做的（按优先级）

> **2026-10-29 更新**：P0 的第 1、2 项已解决。DeepSeek 对话改由 Electron 主进程直连官方 API（不再需要 `server/app.py`），语音已接 edge-tts 神经网络合成并驱动真实口型。详见第二节「第四轮 / 第五轮」。

### P0 — 会直接影响演示

| # | 缺口 | 现状 | 怎么补 |
|---|---|---|---|
| 1 | ~~**LLM 对话后端**~~ | ✅ **已解决**：`desktop/companion.cjs` 主进程直连 `api.deepseek.com`，流式输出 + 工具建议 + 主动关心；密钥只进主进程 | — |
| 2 | ~~**TTS**~~ | ✅ **已解决**：`desktop/tts.cjs` 用 edge-tts 合成，`src/pets/speech.js` 播放并用真实音频电平驱动 Live2D 口型 | — |
| 2b | **ASR** | 仍依赖浏览器 `webkitSpeechRecognition`，国内常报 `network` | 接 faster-whisper 到主进程，或先用文字输入演示 |
| 3 | **MQTT + 固件** | 前端 `mqtt.js` / `desk/cmd` / `desk/event` 齐全，但没有 `broker/mosquitto.conf`、没装 `paho-mqtt`、没有 ESP32 固件 | 建 broker 配置 + Arduino/ESP-IDF 固件，与硬件一起做 |

### P1 — 工程完整性

| # | 缺口 | 后果 |
|---|---|---|
| 4 | **没有 Git 仓库** | 无法回滚，多人协作会互相覆盖。建议接手第一件事：`git init` 并首次提交 |
| 5 | **未做 portable 单文件** | `npm run pack:portable` 已配好，需下载 NSIS 工具 |
| 6 | **exe 未签名** | 换机首次运行弹 SmartScreen，现场可能被拦 |
| 7 | **没有演示录屏** | 摄像头/网络翻车时的保命备份 |
| 8 | **原始 EDF 未打包** | 本包排除了 `data_prep/raw`（49 MB），需要换 EEG 被试时从 PhysioNet 重新下载 |

### P2 — 真实感与产品化

- **瑞幸是真实商户**：走官方 MCP 接口，真实门店、真实报价、真实支付二维码（需 Token）
- 白鹭湾园区模式仍是本机网关模拟，不调真实瑞幸/星巴克、不真扣款（口径：园区企业餐补授信直付）
- Webhook 单向，没有取餐确认/评价/退款回流
- 高德只用了周边搜索，没用路径规划/地理围栏；「穿过 B 区连廊」是文案
- 没有首次启动引导、错误上报、番茄钟统计持久化、设置恢复默认
- EEG 只导出了 Subject03

---

## 十、已知的坑

### 9.1 启动

- **CMD 必须纯 ASCII**：写中文在 `chcp 65001` 下会被错误解析，命令截断。三个 CMD 都是纯 ASCII，改的时候别加中文。
- **`--user-data-dir` 必须可写**：默认 `%APPDATA%\neurodesk-desktop` 在受限环境报 `Lock file can not be created Error code: 5`，应用静默退出。现有 CMD 指向 `web\.runtime\electron-userdata`。
- **`--no-sandbox` 是兼容妥协**：当前机器受限环境需要。评委问安全要能解释：仍保持 `contextIsolation`、禁 Node 集成、限制导航。
- **打包时不能有进程占用 `release\win-unpacked`**：否则 electron-builder 卡住不产出 exe。打包前先关掉 NeuroDesk。
- **打 ZIP 前也要关应用**：否则 MediaPipe wasm 文件被锁，`Compress-Archive` 报「正由另一进程使用」。

### 9.2 Live2D

- **不能多个 WebGL 上下文共享模型纹理**：卡片用静态 `hiyori-preview.png`，只有主舞台和桌宠各持真实实例。
- **Electron CSP 禁止 `unsafe-eval`**：必须 `install(PIXI)` from `@pixi/unsafe-eval`。
- **取景用 `getBounds()`**，不要用 `model.width/height`。

### 9.3 咖啡

- **高德动态门店下单**：网关必须记住当次查询的 POI，否则提交时按内置门店校验会 404。
- **高德额度**：超限自动回退内置门店，不会崩。
- **发车只发一次**：`carTriggered` 和 `CAR_TRIGGERS` 必须一起落盘。
- **电子小票不能阻塞下单**：后台线程推送，失败只写日志。
- **幂等重试不能重发小票**：幂等命中直接返回缓存响应。

### 9.4 测试

- **Electron 测试要用循环视频文件**：Windows 自带虚拟摄像头长时间会停帧，`tests/fake-camera.mjs` 生成 Y4M 循环输入。
- **测试用独立 userData 目录**：避免和运行中的应用抢单实例锁。
- **`NEURODESK_TEST=1` 会禁用休眠监听**：否则测试环境误触发 suspend 导致监测停止。

---

## 十一、改代码指引

### 10.1 改 UI

- 结构 `web/index.html`，样式 `web/src/styles/*.css`
- 绑定逻辑按功能分在 `web/src/app/*.js`
- 改完跑 `npm run test:ui`

### 10.2 改感知算法

- 纯函数在 `web/src/core/`，单测 `web/tests/core.test.mjs`
- 改完必须跑 `npm test`，状态机阈值改动要同步更新测试期望

### 10.3 改咖啡

- 客户端 `web/desktop/coffee.cjs`
- 网关 `server/bailu_coffee_adapter.py`
- 改完跑 `python tests/test_bailu_gateway.py` + `npm run test:bailu`

### 10.4 补 LLM 后端（P0 第 1 项）参考骨架

```python
# server/app.py
import json, os
import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI()
KEY = os.environ["DEEPSEEK_API_KEY"]
SYSTEM = (
    "你是智能工位助手「小澄」，语气温柔简短（不超过40字）。"
    "根据用户状态回复，只输出 JSON："
    '{"reply":"...","actions":[{"type":"light","kelvin":2700-6500},'
    '{"type":"music","play":true/false},{"type":"coffee"},{"type":"alert"}]}。'
    "叫咖啡必须用户明确同意。"
)

class ChatIn(BaseModel):
    text: str = Field(max_length=500)
    state: dict = {}
    history: list[dict] = Field(default=[], max_length=10)

@app.post("/api/chat")
async def chat(body: ChatIn):
    msgs = [{"role": "system", "content": SYSTEM}]
    msgs += [m for m in body.history if m.get("role") in ("user", "assistant")][-8:]
    msgs.append({"role": "user", "content": f"[状态]{json.dumps(body.state, ensure_ascii=False)}\n{body.text}"})
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.post("https://api.deepseek.com/chat/completions",
            headers={"Authorization": f"Bearer {KEY}"},
            json={"model": "deepseek-chat", "messages": msgs,
                  "response_format": {"type": "json_object"}})
    if r.status_code != 200:
        raise HTTPException(502, "LLM 调用失败")
    data = json.loads(r.json()["choices"][0]["message"]["content"])
    # 必须做动作白名单 + 参数夹取，不能直接执行模型输出
    return {"reply": str(data.get("reply", ""))[:200],
            "actions": sanitize(data.get("actions"))}
```

**关键约束**：动作必须走白名单 + 参数范围校验（kelvin 夹到 2700–6500，只允许 light/music/coffee/alert）。Vite 已配 `/api` 代理到 `127.0.0.1:8001`，起后端用这个端口。

---

## 十二、演示前检查清单

- [ ] `python server\setup_demo_config.py --show` 确认飞书/高德已启用
- [ ] 双击 `启动白鹭湾正式版.cmd`，看到三行 ready
- [ ] 点开咖啡，确认 4 家门店（3 内置 + 1 高德）
- [ ] 下一单，确认：`LK` 单号、`已支付`、手机飞书收到小票
- [ ] 进度到 3/4 时看网关日志 `[硬件联动]` 确认 UDP 已发
- [ ] 摄像头权限已授予，校准完成
- [ ] Live2D 正常显示、能换表情
- [ ] 录屏备份已就绪
- [ ] 备用方案：高德挂了自动回退内置门店；飞书挂了不影响下单

---

## 十三、配置速查

| 项 | 值 |
|---|---|
| 桌面本地服务 | `http://127.0.0.1:17863` |
| 咖啡网关 | `http://127.0.0.1:18082/api` |
| 网关令牌 | `bailu-2026-secret` |
| 本机演示咖啡 | `127.0.0.1:18081`（`NEURODESK_COFFEE_DEMO=0` 可关） |
| UDP 发车端口 | `8888`，广播 `CAR_RUN:<取餐码>` |
| 配置优先级 | 环境变量 > `server/.runtime/demo-config.json` > 内置默认 |
| 数据落盘 | `server/.runtime/bailu_orders.json` |
| 网关日志 | `server/.runtime/gateway.log`、`web/.runtime/bailu-gateway.out.log` |

**环境变量**：

```text
NEURODESK_COFFEE_API      商户网关根地址
NEURODESK_COFFEE_TOKEN    Bearer token
NEURODESK_COFFEE_DEMO     0 = 关闭本机演示
NEURODESK_COFFEE_LOCATION bailu = 使用固定园区坐标（不申请系统定位）
COFFEE_WEBHOOK_URL        飞书/企微/Bark
AMAP_WEB_KEY              高德 Web 服务 Key
BAILU_CAR_UDP_DRY_RUN     1 = 只记录不发广播
BAILU_STAGE_SCALE         阶段时长缩放（测试用）
NEURODESK_TEST            1 = 测试模式（禁用休眠监听）
```

