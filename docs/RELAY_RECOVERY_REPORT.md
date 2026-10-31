# NeuroDesk Claude 中断后接力报告

日期：2026-10-31；分支：feature/v2-demo-integration；基准提交：7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176。未创建提交，未推送或合并。

## 1. 检查点与 Claude 断点

接力前检查点：C:\Users\ASUS\Documents\Codex\2026-10-31\gpt-6-1-sol-high-git\work\relay-checkpoint-20261031-162724。

复制并逐文件校验 SHA-256：317 个 Git 已跟踪/非忽略未跟踪文件，包含当前未提交源码与文档。另存 manifest.json、git-status.txt、tracked.patch、backup-comparison.json。忽略的依赖、构建产物及本机运行配置不作为源码备份；未修改或清理原工程。检查点包含私有工程内容，仅留本机，不作为公开交付物。

旧备份 files/ 是部分未跟踪文件快照，不能将“旧备份内没有路径”等同于 Claude 新增。其 tracked-changes.patch 仅含此前 main.js 集成两行；综合 Git diff，确认 Claude 已修改 desktop/main.cjs、desktop/preload.cjs，新增 overlays.cjs；此前 v2 未跟踪文件与旧备份对应文件未发现内容差异。

【代码确认】Claude 已完成独立窗口管理骨架、托盘菜单、原生光标拖动、设置存储与受 sender 限制的 IPC。尚未接通：旧桌宠仍调用移除的 movePet，岛页面和 Vite 入口缺失，工作台状态发布与岛操作接收缺失。只能据保存文件判断完成度，不能推断 Claude 未保存的计划。

## 2. 本轮文件与修复

- web/desktop/overlays.cjs：复用 Claude 实现；结束拖动恢复穿透、限制拖动结束 sender、隐藏时正确收起岛、渲染进程异常隐藏窗口；保留 legacy move-pet 兼容；采样桌面光标位置补充 Windows forward:true；固定逻辑窗口尺寸；退出清理采样定时器。
- web/desktop/preload.cjs：保留原业务接口，恢复 movePet 兼容，增加只读光标采样订阅。
- web/pet.html、web/src/desktop/pet.js、web/src/styles/desktop-pet.css：接通新拖动协议；拖动/点击分离；点击表情、双击打开、独立隐藏、右键菜单。采用手动主进程拖动，因此页面使用 no-drag，避免 app-region 原生拖动与自定义拖动互相竞争。
- 新增 web/src/desktop/overlay-input.js：Windows mousemove 转发、原生光标采样、SVG painted hit、Live2D alpha 取样、指针捕获/释放处理。自定义图片目前采用图片边界命中，透明图片像素级穿透仍需完善。
- 新增 web/island.html、web/src/desktop/island.js、web/src/styles/desktop-island.css；web/vite.config.js 增加 island 构建入口。岛为独立小型 BrowserWindow，非全屏透明层。
- web/src/app/v2-integration.js：原生环境隐藏内嵌岛；工作台发布脱敏的 Mock 摘要；独立岛控制暂停/恢复/领取与导航；分别设置宠物/岛开关。聊天页复用共享 PetHub；健康页搬移原控件，不复制业务逻辑。
- web/src/styles/v2-integration.css：互动角色舞台、健康页环境控制优先、隐藏页规则修复。
- 新增 web/tests/relay-electron.cjs、relay-workspace-electron.cjs：实际 Electron 交互与截图。

桌宠 240×280 逻辑目标尺寸；岛内容约 248×44 / 392×232，加阴影边距原生窗约 268×64 / 412×252。Windows DPI/窗口管理器实测 bounds 有少量取整差异，不宣称任意 DPI 下像素完全一致。

## 3. 验证与覆盖矩阵

| 项目 | 结果与限制 |
|---|---|
| 构建 | Vite 成功，包含 island.html；既有大分包警告保留 |
| 原回归 | 核心脚本通过、37/37 通过；本地 Mock/注入依赖 |
| 演示及媒体单元测试 | 13/13 通过 |
| 预约/支付/配送 | 实际隔离 Electron 中商品只为水2+曲奇1，¥18跨页、日期时间同步、自动推进、暂停、异常、断联、恢复、领取通过 |
| 五页面 | 实际 Electron 已保存最新 page-home/supply/delivery/chat/health.png；无 pageerror |
| 健康控件 | 本地亮度60、色温4000输入，计时开始/暂停、音乐开始/停止通过；不验证物理亮度或扬声器音质 |
| 登录/注册 | 注册确认密码、演示访客通过；真实认证未接入，原界面明确提示 |
| 原八只伙伴 | 入口数量与团子切换同步通过，未删除 Live2D/SVG |
| 独立灵动岛 | Windows Electron 实际创建；键盘展开/收起通过；工作台隐藏后仍可见；配送导航、宠物单独隐藏/重显通过 |
| 位置与异常 | 代码含位置保存、边界限制、渲染进程异常隐藏；强制进程退出、跨显示器拔插、位置恢复的端到端未执行 |
| 桌宠鼠标穿透/拖动 | 待人工验收，不能宣称通过；见下节 |
| 真实API/AI/TTS/商户/摄像头/硬件 | 全部未触发；相关按钮不进行真实服务验收 |

测试历史：首轮组合 Electron 测试通过配送与独立窗口；增加健康检查后发现隐藏聊天残留与控件点击误触导航，均已修复。后续音乐测试误选隐藏的首页按钮，已限定健康页选择器。最终 relay-workspace-electron.cjs 专项通过（workspace-test-result.json）；组合脚本 electron-test-result.json 保留了失败记录，不伪装为最终全量绿灯。未将每个低频按钮或第三方服务都标为通过。

## 4. 原生鼠标实测边界及 P0

在 Windows 创建了桌宠和无业务操作的 Native Input Probe 窗口，使用 computer-use 技能尝试真实输入。工具在桌宠忽略鼠标时将命中点识别为下方 msedge.exe，拒绝拖动；另一次观察绑定失效，未产生可确认的拖动。Probe 点击数没有受控的前后对照，不能用来证明穿透成功。因此：

- P0 待人工验收：透明区域不挡 Edge/资源管理器/记事本；实心角色能连续拖动、点击与双击；释放后不继续跟随。
- P0 待人工验收：不同 DPI 与多显示器跨屏拖动、不缩放漂移、不越过任务栏、不丢失窗口。
- P1：自定义图片的透明像素命中；正式视频正常播放、预加载与衔接；原生窗口位置在异常终止后的恢复。

主进程光标采样与默认 ignore=true 的代码降低对单一 forwarded mousemove 的依赖，但代码审查和 Electron 渲染测试不能替代以上人工验收。

人工步骤：启动安全演示；使用团子与小日和各测试一次。将宠物移到普通软件按钮附近，在透明角落点击下方软件，确认下方软件收到点击；拖拽身体绕屏幕、连续释放和再拖动；单击表情、双击工作台；分别关岛/关宠物；最小化工作台后展开岛。Ctrl+Shift+H 可隐藏/恢复全部悬浮窗，托盘有独立开关和退出，Ctrl+Shift+Q 为退出入口。热键冲突时用托盘退出，不能假定热键注册一定成功。

## 5. 五页截图与设计差异

本目录 page-home.png、page-supply.png、page-delivery.png、page-chat.png、page-health.png 为实际 Electron 截图；native-island-compact.png、native-island-expanded.png、native-pet.png 为独立窗口截图。窗口页面截图不会将其他独立原生窗口合成到工作台截图中。

Modern Hybrid 颜色、留白、卡片和共享角色保留；健康页以环境控制优先，感知默认不启动且可选。对比 v1.4 交接说明，未声称逐像素还原；角色是既有八只保底美术，小车是概念 SVG，正式视频缺失。岛的屏幕避让和跨屏位置需人工验证，尚未做系统级多屏体验完整验收。

## 6. 保护与启动

对比接力检查点，本轮没有改动瑞幸、配送商、AI对话、TTS、硬件、固件、数据库、PetHub/Live2D/SVG 源模块或依赖锁。main.cjs 的 Claude 修改保留，本轮没有再次改写其业务部分；仅完善新增 overlay 模块和 Preload 的 overlay 扩展。git diff --check 无错误（现有 Git 配置提示 LF/CRLF 转换）；未清理、重置、切分支、暂存或提交。

Windows 双击 outputs/NeuroDesk-Safe-Demo.lnk 或 outputs/Open-NeuroDesk.cmd。使用项目外的隔离启动包装器，清空本次业务配置、阻止业务网络与子进程、禁用摄像头监测窗口；正常 npm start 不等于安全演示启动方式。开发构建命令：在 web 执行 npm run build。测试脚本依赖任务目录内隔离包装器；迁移到别的电脑需同时迁移/审查包装器，不能去除隔离直接运行。

当前交付是已恢复运行的候选版本，桌宠跨应用鼠标体验尚未完成验收，不宣称所有 P0 关闭。
