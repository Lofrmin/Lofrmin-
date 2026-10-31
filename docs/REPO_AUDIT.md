# Repository Overview 与接入审计

> 审计日期：2026-10-31（Asia/Shanghai）。固定代码基线：`Lofrmin/Lofrmin-` 的 `feature/product-workspace`，Commit `7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176`。
> 【已由代码确认】指静态代码事实，不代表服务、凭据或设备已验证；【根据代码推测】表示推断；【需要队友确认】表示外部配置或产品决策缺失；【需要实机验证】表示运行及物理结果未知。代码事实一般为高置信度；未发现实现的结论只限于本次仓库版本。
> 接入限制：工作目录最初不是 Git 仓库。正常克隆因本机代理连接失败；单次停用代理后的克隆亦无法连接 GitHub 443。只读 GitHub 连接器成功读取固定 SHA 的完整目录树（未截断，297 个文件）和主要自有源码；没有本地克隆、origin 引用或个人分支。文档暂存于 outputs/docs，不能声称已写入个人分支。未运行项目、安装依赖、导入业务模块、执行测试、访问设备、调用业务第三方 API 或修改远端。
> 下文路径行号链接均指向固定 SHA；教程、README、HANDOFF 的历史描述只作辅助，运行源码优先。不复制任何 Secret 或凭据型 Webhook URL。


## 仓库、分支与 Git 状态

- 目标：https://github.com/Lofrmin/Lofrmin- 。连接器确认 public、可读取、非归档；未使用写权限。
- 当前目录：`C:\Users\ASUS\Documents\Codex\2026-10-31\gpt-6-1-sol-high-git`。Git Root / Remote / Branch / 未提交修改：不适用，`git rev-parse`、`git status`、`git remote -v` 均报非仓库。
- 分支存在：只读 API 确认 `feature/product-workspace`；目标 SHA 如上；tree SHA `300f5751df03c0f08aefc9f99861393035428c4c`。
- 相对 main：连接器 compare 固定目标 SHA，main 当时为 `59ece7558e5a097d04bd74e0a111aa97172fd74d`；ahead 3 / behind 0。新增 product-workspace JS/CSS、工作台素材、speech 测试等；大量其他文件也标记 modified，不能据此断言均为语义改动或纯换行差异。未修改 main。
- `feature/pet-ui-redesign` **未创建**，本地同名分支检查因无仓库无法执行；远端个人同名分支未查询。未 commit / stage / push / merge / rebase / reset / PR / deploy。
- 权限：连接器读取成功；阻塞原因是 Git 网络连接，不能据此判断 Git 推送权限或认证状态。

## 整体用途、技术与目录

【已由代码确认，高】NeuroDesk 是 Windows 桌面专注陪伴工作台：本机摄像头启发式专注/疲劳感知、数字人、聊天/朗读、灯光/音乐、咖啡及配送。网页预览与 Electron 桌面能力不同。新工作台同时包含本地补给体验。证据：[web/package.json:2](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/package.json#L2)、[web/src/main.js:35](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/main.js#L35)、[web/src/app/product-workspace.js:16](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L16)。

```text
/
├─ README.md                         极简标题
├─ ONBOARDING.md / HANDOFF.md         上手、历史交接（部分内容落后于源码）
├─ KEIL_JLINK_NOTES.md                硬件烧录说明
├─ firmware/bailu_car/
│  ├─ USER/main.c                    STM32F407 配送演示主循环
│  ├─ HARDWARE/{MOTOR,SERVO,OLED,KEY,LED}
│  ├─ SYSTEM/usart/                   UART 接收与初始化
│  ├─ CORE/ / FWLIB/                  芯片厂商基础库
│  └─ USER/LED.uvprojx                Keil 工程
├─ server/
│  ├─ bailu_coffee_adapter.py         FastAPI 门店/模拟订单/UDP/Webhook/高德
│  ├─ demo_config.py / setup_demo_config.py
│  └─ start_bailu_demo.py             启动器
├─ tests/{bailu_fixture.py,test_bailu_gateway.py}
├─ tools/                            Keil/J-Link 构建与烧录工具，未执行
├─ web/
│  ├─ package.json / package-lock.json / vite.config.js
│  ├─ index.html / pet.html / monitor.html
│  ├─ desktop/                       Electron 主进程、preload、服务适配器、TTS
│  ├─ src/
│  │  ├─ app/                        工作台/对话/业务反应/弹窗
│  │  ├─ core/                       视觉、EEG回放、融合、状态机
│  │  ├─ desk/                       灯光、音乐、咖啡、MQTT
│  │  ├─ pets/                       视图、Live2D、SVG、上传、语音
│  │  ├─ desktop/                    面板/桌宠/后台感知渲染进程
│  │  ├─ ui/                         仪表、时间线、日志、EEG图
│  │  └─ styles/
│  ├─ public/{eeg,mediapipe,live2d,workspace}
│  ├─ voices/piper/
│  └─ tests/                         Node 与 Playwright/Electron 测试
└─ 启动NeuroDesk.cmd / 启动白鹭湾正式版.cmd
```

扫描未读取 node_modules、缓存或构建产物；未在目录树中发现 AGENTS.md、Dockerfile/Compose、GitHub Actions、pyproject.toml、requirements.txt、独立数据库 schema 或常规 .env 示例。存在 JSON 配置示例。EEG 原始预处理目录被文档提及，但此 tree 中没有 `data_prep/prep_eeg.py`，不可照文档假定存在。

| 部分 | 实际技术与证据 |
|---|---|
| 前端 | 原生 ES module JavaScript + HTML/CSS + Vite；没有 React/Vue 路由或 Hook 框架。[web/package.json:8](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/package.json#L8)、[web/vite.config.js:4](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/vite.config.js#L4) |
| 桌面主进程 | Electron + Node CommonJS；三窗口 panel/monitor/pet，隔离上下文、preload 白名单 IPC。[web/desktop/main.cjs:72](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L72)、[web/desktop/main.cjs:201](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L201) |
| AI/动画 | DeepSeek HTTP SSE；PixiJS + pixi-live2d-display Cubism4、SVG/CSS、图片。[web/desktop/companion.cjs:116](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L116)、[web/src/pets/view.js:24](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/view.js#L24) |
| 感知 | @mediapipe/tasks-vision，本地 wasm/model；GPU 失败回 CPU，摄像头视频而非音频。[web/src/core/camera.js:15](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/core/camera.js#L15) |
| Python 网关 | FastAPI + Pydantic + HTTPX + Uvicorn，订单 JSON 持久化。[server/bailu_coffee_adapter.py:39](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L39)、[server/bailu_coffee_adapter.py:399](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L399) |
| 语音 | Electron TTS 编排 → Python 标准库 HTTP 服务 + sherpa_onnx；Piper/Kokoro，edge-tts 远程后备和系统语音降级。[web/desktop/tts.cjs:90](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/tts.cjs#L90)、[web/desktop/tts_server.py:127](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/tts_server.py#L127) |
| 硬件 | STM32F407 C/Keil + HC-05 UART；另有网关 UDP 广播、前端 MQTT 通道。三者未证明闭环。详见 HARDWARE_COMMUNICATION.md |

## 如何启动、部署（仅记录，未执行）

【已由代码确认】在 `web` 中，`npm run dev` 为 Vite 网页预览；`npm start` 为 build 后 Electron；`npm run desktop` 复用现有 dist。依赖尚未安装；本轮没有运行以上命令。[web/package.json:9](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/package.json#L9)。

Electron 自带本机静态 HTTP，默认 17863，端口占用后可能换随机端口；仅绑定 loopback。该变化可能使 origin 下的 localStorage/IndexedDB 看起来丢失，未来登录持久化也需考虑。[web/desktop/main.cjs:103](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L103)。

白鹭启动脚本会检查并可能安装 Python 依赖、启动网关、解析本机配置和拉起桌面，不能作为无副作用审计命令。网关默认本机 18082；本地 TTS 默认 18090。[启动白鹭湾正式版.cmd:16](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/%E5%90%AF%E5%8A%A8%E7%99%BD%E9%B9%AD%E6%B9%BE%E6%AD%A3%E5%BC%8F%E7%89%88.cmd#L16)、[server/start_bailu_demo.py:35](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/start_bailu_demo.py#L35)、[web/desktop/local-tts.cjs:69](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/local-tts.cjs#L69)。

`pack` / `pack:portable` 使用 electron-builder 打包 Windows；配置是存在的，不代表本轮验证能打包或具备 Python/模型运行时。没有发现容器/云端生产部署自动化。[web/package.json:30](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/package.json#L30)、[web/package.json:45](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/package.json#L45)。
Vite 的 `/api → localhost:8001` 是开发期历史代理；实际桌面聊天走主进程 DeepSeek，目录中没有对应 `server/app.py`。[web/vite.config.js:6](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/vite.config.js#L6)、[web/desktop/main.cjs:237](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L237)。

## 数据存在哪里

| 数据 | 位置及证据 | 边界 |
|---|---|---|
| 偏好、称呼、工位、本地补给订单、待确认咖啡订单 | localStorage，[web/src/app/product-workspace.js:73](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L73)、[web/src/desk/coffee.js:13](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/coffee.js#L13) | 同 origin 的本机状态；不是账号数据 |
| 自定义宠物图片 Blob | IndexedDB `neurodesk-pets/custom`，[web/src/pets/custom.js:1](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/custom.js#L1) | 原有 DB/store/版本保持兼容 |
| 白鹭订单、幂等请求、发车标记 | server/.runtime/bailu_orders.json，[server/bailu_coffee_adapter.py:43](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L43)、[server/bailu_coffee_adapter.py:123](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L123) | 模拟商户订单；不是真支付凭证 |
| 瑞幸/闪送 journal、配置、TTS缓存与日志 | web/.runtime 或环境变量指定位置，[web/desktop/main.cjs:22](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L22)、[web/desktop/main.cjs:61](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L61) | 可能含凭据/地址；未读取机器实际运行目录 |
| 聊天上下文 | companion 内存 history，[web/desktop/companion.cjs:124](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L124) | 最近20条，配置另落盘；不是用户会话 |
| EEG示例与模型 | web/public/eeg/session.json、public/mediapipe、public/live2d、voices | 数据/模型资源，不能当真实脑电 |
| 专注指标 | 视觉渲染进程 → 内存 snapshot → IPC，[web/src/desktop/monitor.js:9](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/monitor.js#L9) | 没发现业务用户数据库 |

## 已实现与未完成的边界

【已由代码确认】存在完整调用实现：本地摄像头检测/校准、六态状态机、数字人多渲染器、气泡/口型、流式 AI 对话的取消重试与动作建议、音乐、亮度、形象上传、咖啡适配器和外部订单流程。实现存在不等于运行已通过。

【已由代码确认】新工作台补给购物、预约、配送进度、称呼编辑由本地数据和计时实现；原咖啡入口通过 `real-coffee` 单独复用。[web/src/app/product-workspace.js:98](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L98)、[web/src/app/product-workspace.js:116](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L116)、[web/src/app/product-workspace.js:126](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L126)。

【已由代码确认】没有注册/登录/当前用户/退出的账号系统；没有发现 ESP32 UDP 接收桥、MQTT broker/设备端实现、真实小车遥测闭环。已有商户 Bearer token 不等于用户认证。详见另外两份报告。

【需要队友确认】第三方账号开通、余额、生产配置、实际小车型号与当前刷入固件、仓库外桥接程序、云部署、已通过哪些联调。文档过去声称的演示成功不能替代本轮验证。

## 主要风险与数据流

1. 【高】硬件链断点：网关 UDP 与固件 UART 不匹配；配送状态不是遥测。详见硬件报告。
2. 【高】GET 订单状态可能发车：`_public_status` 在 delivering 窗口发送 UDP，**查询不是安全实机测试**。[server/bailu_coffee_adapter.py:251](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L251)。
3. 【高】凭据型 Webhook URL 和默认网关凭据出现在源码/示例/文档，禁止复制值或试用。API 报告只列路径行号。
4. 【高】UI 与业务/通信混写：product-workspace、main、ui-misc、coffee-dialog、reactions 不能整文件覆盖。
5. 【中】本地补给订单、内置 coffee-demo、白鹭模拟商户、瑞幸真实接口四类流程，UI必须保持来源区别。
6. 【中】桌面监测在隐藏进程启动，MQTT 可从保存 URL 自动连；运行服务可能联网或触发设备。[web/src/desktop/monitor.js:64](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/monitor.js#L64)、[web/src/app/ui-desk.js:111](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/ui-desk.js#L111)。
7. 【中】构建/单元/端到端/硬件测试均未运行；不能宣称现状无 bug。缺少 Python 依赖锁定文件，打包不等于完整 Python 运行环境。

主链：panel DOM → app services → preload IPC → Electron main → 外部 AI/商户服务；monitor 摄像头 → StateMachine → IPC snapshot → panel/桌宠/AI摘要；白鹭订单查询 → FastAPI → UDP。前端 MQTT 则直接连 broker，不经过 Python。详情、契约及后续改造见其他报告。

## 最终交付与安全核验

五份报告已新增到本机 outputs/docs，未覆盖既有文件。检查确认五份均含固定 SHA，合计221处源码行号链接；行号均在已读文件范围内，无合并冲突标记。报告与本次识别出的凭据字面量逐项比对，未发现复制值；Webhook/Key模式检查也未命中。这不代表对整个Git历史做过专业Secret扫描。

最终再次执行 git status --short --branch 与 git diff --stat，结果仍为“不是Git仓库”，因此Git源文件差异验证不适用/未完成，不能报告为通过。当前工作目录只有既有 work、outputs 两个目录，work 无克隆产物；本轮仅写入 outputs/docs 下五份新Markdown，没有业务源文件落盘或变更。远程操作仅为Git克隆尝试和连接器GET读取，无远端写入。

未运行构建、单元测试、端到端测试、服务或设备测试；没有第三方业务调用、硬件指令、数据库迁移、依赖安装、提交、推送、合并、部署。仍待恢复：安全克隆、实际origin引用检查、个人本地分支创建、把文档加入该分支，并在真实仓库重新执行git status/git diff。网络恢复后必须先确认团队分支是否已移动，再决定是否补审计。

