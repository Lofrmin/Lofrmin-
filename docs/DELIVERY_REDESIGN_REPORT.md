# NeuroDesk 配送页面增量重构交付

日期：2026-10-31。分支：feature/v2-demo-integration。基准提交：7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176。保留了开始时的所有未提交集成代码和审计文档；未创建 Commit、Push 或 Merge。

## 实现与文件

| 文件（仓库相对路径） | 本轮职责 |
|---|---|
| web/src/app/v2-delivery-page.js | 新增独立配送展示：中央大车舞台、右侧订单/取餐卡、横向四阶段、详细事件记录；空订单/配送/到站/完成/异常/通信中断 |
| web/src/app/v2-demo-model.js | 单一草稿入口 setDraft、付款快照、事件时间戳、断联冻结、DEMO-only 推进及付款保护、手动领取 |
| web/src/app/v2-components.js | 六状态 DeliveryVisual，受信任本地视频路径、错误时 SVG 回退、减少动态效果、depart/arrived 不循环 |
| web/src/app/v2-integration.js | 首页/补给/确认/配送共享草稿及订单；挂载原 PetHub；保留八只伙伴；视频资源替换事件及清理 |
| web/src/styles/v2-integration.css | Modern Hybrid 配送布局、动画、响应式、原有静态四形象选项隐藏、原角色舞台 |
| web/tests/v2-demo.test.mjs | 原有演示测试扩展至 10 项 |
| web/tests/v2-vehicle.test.mjs | 新增 3 项媒体适配与路径保护测试 |
| web/tests/v2-delivery-electron.cjs | 隔离实际 Electron 交互、状态与三尺寸截图 |
| docs/superpowers/plans/2026-10-31-delivery-ui.md | 本轮计划 |

main.js 的两行 initV2 导入/挂载是此前集成已有内容，本轮未改。原有 API、后台、IPC、MQTT/UDP/UART、宠物模块、固件、数据库与依赖锁均未修改。

## 数据和行为契约

- DemoDelivery.draft 是唯一可编辑草稿，edit() 取得同一对象引用；表单仅修改该对象，金额由 CATALOG 和数量派生。付款生成独立订单快照，后续编辑草稿不篡改已确认订单。
- “明天下午三点送两瓶水和一份曲奇到 A 区取餐点”只产生 water:2、cookie:1，总价 ¥18；不会从商品浏览目录自动加入其他商品。
- 首页、补给摘要、支付确认和配送详情统一读取该草稿/订单快照。无订单且有草稿时摘要明确标为“待确认预约”。
- 八个细分演示阶段保持兼容，展示合并为“预约确认 → 备货装车 → 小车配送 → 到站领取”。
- Demo 自动推进；异常、断联、暂停时冻结。暂停到站仍能手动领取；断联/异常不能确认领取。重启演示会清空本次演示事件并从确认开始。
- 构造为 REAL 或订单 mode=REAL 时，pay 拒绝且 advance/restart 不改变设备确认。没有新增真实付款、订单或设备 API，也未给真实数据连接计时器。当前无 Real 模式切换 UI。
- 原 PetHub.mount 提供点击、情绪与对话同步；八只角色仍为小日和、团子、煤球、波波、飘飘、豆柴、啾啾、小七。选择委托原 Gallery 事件；不删除原 Live2D/SVG 模块。未制作新的系统级宠物窗口。
- 灵动岛保持胶囊/小面板双态，不把展开动作直接映射为全屏工作台。

## 动画资源接口

DeliveryVisual.setState 支持 idle / loading / depart / moving / arrived / error。默认全状态采用 SVG 概念小车，非实车影像，不代表导航、定位或设备 ACK。

资源准备后放入 web/public/workspace/；可通过组件 setVideos 或 renderer 的 #v2-service 事件 v2:vehicle-videos 注入状态与路径映射，例如 moving → /workspace/robot_moving.mp4。仅允许 workspace 下 MP4/WebM，拒绝外部 URL 和路径穿越。错误或无法播放时保留 SVG，不显示破损素材。不存在网络下载或资源上传接口。

## 验证结果

- npm run build：成功；仍有既有大分包提示。
- 原 npm test：核心脚本通过，37/37 测试通过。测试使用原有本地 Mock/注入接口。
- node --test tests/v2-demo.test.mjs tests/v2-vehicle.test.mjs：13/13 通过。
- node tests/v2-delivery-electron.cjs：通过；pageErrors 为 0。运行报告：electron-test-result.json。
- 实际 Electron 外窗 1440×900、1280×711、980×660 均检查了主内容宽度和无横向溢出；截图为 Electron 页面截图，Windows DPI 会令 PNG 像素尺寸不同于逻辑窗口尺寸。完整页面可纵向滚动，不宣称所有内容均在首屏。
- 验证了请求商品数、¥18 跨页一致、日期/时间同步、模拟支付、自动配送、暂停、异常、通信中断、恢复、到站与手动完成、八只伙伴入口和选择团子的 PetHub 同步。
- 视频路径切换和解码事件在组件测试中验证；实际 Electron 中验证了视频缺失后的 SVG 回退。有效正式视频的真实播放未通过验收：交接包没有小车视频，临时录制夹具缺少有效帧；已停止相关重试，没有虚报成功。
- 最终截图前复核发现“暂停到站不能领取”并已修复，新增单元断言与 Electron 完成状态断言均通过。
- git diff --check 通过；受保护路径 git diff 为空。未暂存、提交或推送。

## 隔离前提与截图

Electron 测试依赖任务目录 work/v2-electron-wrapper.cjs，使用独立 userData 和本地端口；拦截非静态业务请求、WebSocket、系统控制、子进程及摄像头监测，保持原 Electron main 源码不变。不能用正常 desktop 命令代替隔离测试。快捷入口仍为 outputs/Open-NeuroDesk.cmd（启动已构建的 dist）。

截图均在本报告同目录：delivery-1440.png、delivery-1280.png、delivery-980.png、empty-1440.png、moving.png、arrived.png、completed-events.png、error.png、disconnected.png、booking-requested-only.png、home-pethub-1440.png、svg-pet-fallback.png。

## 与高保真参考的差异及待验证事项

对照交接包 Design_Handoff、Robot_Animation_Prompt 的森林绿/米白、圆角卡片、双态岛与 SVG 动效方向，并按本轮指定的舞台/订单/横向进度结构实现。未宣称与 v1.4 单文件原型逐像素一致。

- 小车采用概念 SVG，没有正式三维车视频、真实车型或六片段逐帧还原；正式资源播放、无缝衔接、下一片预加载、编码兼容性仍需资源到位后验证。
- SVG 动画较参考目标的三维影片简单，不表示实机能力；目前未显示实时地图或预计剩余分钟。
- 原 Live2D/SVG 是交互保底，不是新美术；系统级桌宠窗口与新资源制作未改造。
- 演示只保留本次内存中的最新草稿/订单；刷新后清空，不是正式多订单历史。
- 真实 API/AI/TTS/支付、硬件 ACK 与网络断连均未实机验证；页面的断联按钮仅模拟此状态。
- 其他跨页功能保留现有实现，不承诺原型所有页面完全还原。

## 回退

本轮开始时已有大量未提交集成文件，不能整体 git restore/reset。需只回退本报告列出的配送模块和对应集成/CSS片段，并保留此前 main.js 入口与团队文件。没有新增提交，因此没有可安全整体撤销的提交号；合并前建议团队逐文件评审。
