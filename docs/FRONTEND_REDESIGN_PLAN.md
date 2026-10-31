# 前端审计、PET_ANIMATION_ARCHITECTURE 与未来升级方案

> 审计日期：2026-10-31（Asia/Shanghai）。固定代码基线：`Lofrmin/Lofrmin-` 的 `feature/product-workspace`，Commit `7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176`。
> 【已由代码确认】指静态代码事实，不代表服务、凭据或设备已验证；【根据代码推测】表示推断；【需要队友确认】表示外部配置或产品决策缺失；【需要实机验证】表示运行及物理结果未知。代码事实一般为高置信度；未发现实现的结论只限于本次仓库版本。
> 接入限制：工作目录最初不是 Git 仓库。正常克隆因本机代理连接失败；单次停用代理后的克隆亦无法连接 GitHub 443。只读 GitHub 连接器成功读取固定 SHA 的完整目录树（未截断，297 个文件）和主要自有源码；没有本地克隆、origin 引用或个人分支。文档暂存于 outputs/docs，不能声称已写入个人分支。未运行项目、安装依赖、导入业务模块、执行测试、访问设备、调用业务第三方 API 或修改远端。
> 下文路径行号链接均指向固定 SHA；教程、README、HANDOFF 的历史描述只作辅助，运行源码优先。不复制任何 Secret 或凭据型 Webhook URL。


本文件是静态分析后的建议，没有执行重构、登录开发或宠物替换。未来默认采用“保持现有服务/事件输入，分步替换显示层”；这是一项建议，尚未成为团队批准的实现规格。

## Route → Page → Component → Hook/Store → API

【已由代码确认，高】没有React/Vue Router；“页面路由”主要是函数navigate与DOM显隐，不能凭设计图引入新URL假定路由已存在。Vite有三个HTML入口，工作台入口内部又有新壳和旧视图。[web/vite.config.js:4](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/vite.config.js#L4)、[web/src/app/product-workspace.js:77](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L77)、[web/src/desktop/panel.js:6](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/panel.js#L6)。

| 入口/虚拟页 | Page / 组件 | 事件/状态模块（不是React Hook） | API / 副作用 |
|---|---|---|---|
| /、index.html → home | 今日工作台、hero、导航、卡片、计时器、侧栏 | initProductWorkspace(app)、app.hub/light/music/coffee、localStorage | 主入口装配IPC；卡片交互可调灯光/声音 |
| navigate('chat') | AI伙伴；复用原chat节点与form，气泡动作/朗读 | bindChat、Chat.pending/history/onEvent、PetHub | chat-* IPC → DeepSeek SSE；tts-* |
| navigate('supply') | 园区补给、分类、购物与预约modal | checkout/renderShop、nd-service-orders/profile | 本地体验，无商户API |
| navigate('delivery') | 我的配送、状态卡、确认取货/取消预约 | stageFor/renderOrderList，本地订单计时 | 无真实车反馈；app.coffee.onChange有原咖啡订单提示 |
| navigate('health') → 原overview | 摄像头状态、专注/疲劳Gauge、时间线 | sense + nativeSnapshot / Camera + StateMachine | monitor IPC、MediaPipe本地模型 |
| navigate('insights') | 感知实验室、EEG曲线、回放、视觉指标/演示 | EEGPlayer、EEGView、FaceFeatures、bindDemo | /eeg/session.json，非真实脑电采集 |
| navigate('desk') | 灯光、音乐、咖啡、MQTT状态 | bindDesk、Light、Music、Coffee、mq | MQTT、系统屏幕亮度IPC、咖啡API |
| navigate('companion') | 形象库、上传/编辑、预览、悬浮 | Gallery、PetHub、PetView、custom/upload/pip | IndexedDB、select-pet IPC / Document PiP |
| settings modal | 声音、通知、番茄、AI摘要/主动提醒、MQTT、自动启动等 | bindSettings、Chat.configure、bindDesk、bindDesktop | chat-settings、通知、OS启动、MQTT连接；无账号登录 |
| 原coffee dialog | 选店/商品/下单/进度 | bindCoffeeDialog + Coffee.pending/busy | 通用商户IPC / FastAPI；轮询可能发车 |
| 瑞幸/闪送dialog | 规格、预览、支付链接、未知订单核实、配送报价 | createLuckinDialog、main gateway/journal | 瑞幸MCP、闪送V3；真实费用边界 |
| /pet.html | 悬浮桌宠、拖动、点击打开工作台、语音气泡 | desktop/pet.js 独立PetView、onSnapshot/onPet | 仅允许的preload IPC |
| /monitor.html | 隐藏后台感知窗口，无普通用户导航 | desktop/monitor.js、Camera、StateMachine | 摄像头、本地模型、publish IPC |
| 登录/注册/退出/当前用户页 | 未发现 | 无AuthStore/User Session | 无相应API，不能把profile编辑称为登录 |

证据：[web/src/main.js:35](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/main.js#L35)、[web/src/main.js:171](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/main.js#L171)、[web/src/app/product-workspace.js:16](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L16)、[web/src/app/product-workspace.js:126](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L126)、[web/src/app/ui-misc.js:6](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/ui-misc.js#L6)、[web/src/app/coffee-dialog.js:6](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/coffee-dialog.js#L6)、[web/src/app/luckin-dialog.js:6](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/luckin-dialog.js#L6)、[web/src/desktop/pet.js:19](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/pet.js#L19)、[web/src/desktop/monitor.js:9](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/monitor.js#L9)。

### 所有主要前端模块职责

- app：product-workspace新壳/本地业务；chat对话服务；reactions状态反应；sense循环与显示；ui-desk设备绑定；ui-misc对话/演示/设置；coffee-dialog、luckin-dialog商户流程；lines台词。
- core：camera本地视觉推理；face视觉指标/校准；fusion指标融合；state六态滞回；eeg示例回放；bands脑电频带计算。
- pets：hub多视图/语音；view渲染选择/气泡/事件；live2d Pixi/Cubism；library/library-a/library-b/face SVG形象；custom IndexedDB；gallery、upload形象库/表单；pip浮窗；sound系统语音/音效；speech TTS播放/电平。
- desk：mqtt通信；light亮度/色温与发送节流；music WebAudio生成；coffee商户服务/幂等状态。
- desktop：panel面板与snapshot；pet悬浮；monitor隐藏视觉计算。
- ui：gauges、timeline、eegview绘图；toast日志/提示。styles：base/layout/pets/widgets/workspace/product-workspace/desktop-pet。

文件存在由完整tree确认，具体调用由main imports与上述路由表对应。不是组件化框架项目，不需要为视觉重做先迁移框架。

## A/B/C/D 分层与可修改范围

| 分类 | 后续候选文件/片段 | 保护要求 |
|---|---|---|
| A UI（优先） | web/src/styles/{base,layout,widgets,workspace,product-workspace,desktop-pet,pets}.css；public/workspace图标图片；index.html 的纯布局/文字 | 保留DOM id、data属性、可访问性与绑定宿主；不得覆盖既有素材；改前检查授权范围 |
| A 渲染实现 | pets/library-a.js、library-b.js、face.js、Live2DAvatar绘制细节；ui/gauges/timeline/eegview显示 | 保留调用签名与输入单位/空值/时序；模型资源许可需核对；绘图模块仍含数据解释，不能整文件盲替 |
| B Interaction（谨慎） | product-workspace导航/modal、view pointer、gallery/upload、ui-misc聊天表单、coffee/luckin dialog视觉与loading | 不改变点击次数、确认门槛、重复提交、取消/重试语义、事件冒泡 |
| C Business（默认保护） | core/*、app/chat/reactions/sense、desk/light/music/coffee、main.js装配、本地订单/profile逻辑、pets/hub/speech/custom | 保持阈值、mood映射、幂等、localStorage/IndexedDB、订阅/清理与副作用 |
| D API（完全保护） | desk/mqtt、desktop/preload/main及服务适配器、server/*、firmware/**、所有env/Provider/SDK/依赖配置 | 参数、返回、URL、topic、协议、状态与错误映射完全兼容；不自动加登录校验 |

**高风险混写**：`index.html`（宿主契约）、`src/main.js`、`app/product-workspace.js`、`app/ui-misc.js`、`app/ui-desk.js`、`app/coffee-dialog.js`、`app/luckin-dialog.js`、`app/reactions.js`、`app/sense.js`、`pets/view.js`、`pets/hub.js`、`desktop/pet.js`。以上不能宣称“整文件可以替换”。

新壳会移动既有聊天节点、把旧视图保留在legacy并重排弹窗；重建DOM可能丢掉监听器或造成多个定时器。[web/src/app/product-workspace.js:17](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L17)。
main.js在装配时大量无空值防御地查询节点；先做宿主id清单，再改HTML。[web/src/main.js:39](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/main.js#L39)、[web/src/main.js:118](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/main.js#L118)。
新壳的单行actions里有调亮度、播音乐、改存储等副作用，不是纯模板。[web/src/app/product-workspace.js:126](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L126)。

## PET_ANIMATION_ARCHITECTURE

### 当前渲染与状态

【已由代码确认，高】当前已经有连续Live2D motion/眨眼/物理，而不是全部图片切换。三种路径：
- def.live2d → PetView → Live2DAvatar → Pixi WebGL canvas + Cubism4；Hiyori模型/Idle/TapBody、参数口型/眉毛/脸颊、鼠标注视。[web/src/pets/live2d.js:28](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/live2d.js#L28)。
- def.custom → img，按def.images[mood]切图，缺省回normal；CSS闲置动画。[web/src/pets/view.js:42](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/view.js#L42)。
- 内置其他形象 → SVG library/face，setMood替换面部SVG并用CSS动作/粒子。[web/src/pets/library.js:17](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/library.js#L17)、[web/src/pets/view.js:57](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/view.js#L57)。

业务状态：away/drowsy/tired/distracted/focused/normal，StateMachine提供onChange/update/force，含hold/minDwell/滞回。输入来自本地视觉/手动demo；EEG是独立回放，sense调用fuse(null,face)，未用于本人的真实状态判断。[web/src/core/state.js:1](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/core/state.js#L1)、[web/src/app/sense.js:15](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/sense.js#L15)、[web/src/desktop/monitor.js:41](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/monitor.js#L41)。

表达状态：normal/focused/curious/tired/alert/away/sleepy/happy/love等；保存在PetHub.mood与各PetView/Avatar.mood。Reactions将distracted→curious、drowsy→alert；临时flash结束回当前业务态，away延后sleepy。桌宠独立映射away→sleepy，和panel有细节差异，应先保留后讨论统一。[web/src/app/reactions.js:5](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L5)、[web/src/app/reactions.js:32](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L32)、[web/src/desktop/pet.js:11](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/pet.js#L11)。
Live2D MOODS没有显式love，当前按normal回退；未来映射可以作为视觉扩展设计，但不能改业务枚举。[web/src/pets/live2d.js:9](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/live2d.js#L9)。

### 事件、接口、调用边界

| 接口/事件 | 输入 → 现有行为 |
|---|---|
| PetHub.mount(host,opts) / unmount(view) | 同步选择、mood与近期say到多个view；清理生命周期 |
| setPet(def) | def.id/name/live2d/custom/images/idle/accent/voice等既有结构；销毁旧Avatar |
| setMood(mood) | 业务事件输入；不能在动画帧回调中再运行Reactions |
| say(text,{actions,voice,sound,notify,ms}) | 占位文本、气泡、动作按钮、语音/通知；保留回调语义 |
| onPoke | 点击→Reactions.poke→短时happy/love；不应触发设备命令 |
| Avatar.setMood/speak/lipSync/stopLip/destroy | mood、时长、onLevel订阅；归一化电平驱ParamMouthOpenY |
| chat-event / companion-speech | AI文本和播报触发口型/气泡；不是模型直接输出宠物mood |
| snapshot / select-pet | 主进程广播给独立桌宠；保持面板关闭后后台与桌宠行为 |
| desk/event confirm | 打开咖啡建议或happy；不是小车遥测 |

证据：[web/src/pets/hub.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/hub.js#L23)、[web/src/pets/hub.js:49](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/hub.js#L49)、[web/src/pets/hub.js:61](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/hub.js#L61)、[web/src/pets/live2d.js:71](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/live2d.js#L71)、[web/src/desktop/pet.js:25](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/pet.js#L25)、[web/src/app/ui-misc.js:80](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/ui-misc.js#L80)。

声音链：reply/utter → speech.say → ttsSpeak IPC → 本机Piper/Kokoro或edge-tts → Audio /tts?id → WebAudio RMS 0..1 → Avatar lipSync；失败系统朗读和定时口型。桌宠独立的companion-speech目前主要用定时speak，不可宣称它已经共享面板真实音频电平。[web/src/pets/speech.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/speech.js#L23)、[web/src/pets/speech.js:61](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/speech.js#L61)、[web/src/pets/hub.js:67](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/pets/hub.js#L67)、[web/src/desktop/pet.js:27](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desktop/pet.js#L27)。

### 是否能只替换渲染层

【根据代码推测，中高】可以以PetView/Avatar接口作为接缝，保持PetHub、Reactions、StateMachine、IPC、API和硬件模块不变，升级模型、动作混合、眼神、口型与过渡。建议优先沿用已有Live2D，避免先引入另一套引擎/依赖。
备选为在同接口下新增其他渲染器；优点是资产自由，代价是口型/生命周期/多窗口/性能全需重新适配。整套换框架会扩大保护面，当前不建议。

高风险点：
1. PetView.say中的actions是真回调；动画不能自动click/执行。
2. Reactions.onState同时管宠物和灯光/alert，不能为动画改该函数业务分支。
3. 多视图/WebGL context、异步load后destroy、ResizeObserver、pointer监听、lip订阅、timer必须释放，防窗口切换后重复运行。
4. workspace setAvatar对hiyori与静态角色的持久化/IPC路径不完全相同，需回归当前差异，不在视觉任务中顺便统一。[web/src/app/product-workspace.js:125](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L125)。
5. 不把ready/delivering的本地计时态当真实硬件到站，新增动画只响应已有输入。

## 推荐实施顺序与验收

1. **接入恢复**：Git网络可用后克隆目标仓库，核对远端/干净状态与最新目标SHA；若与本报告SHA不同，先补差异审计。安全时从origin/feature/product-workspace新建feature/pet-ui-redesign。同名已存在先比较，禁止覆盖。
2. **冻结行为基线**：以API_PROTECTION/HARDWARE文档列DTO、IPC、事件、DOM id、存储键、模型/Provider、topic、计时和错误；只用合成数据录制基线，不记录真实凭据或用户地址。
3. **设计交付**：提供高保真桌面/窄屏设计与素材，覆盖loading/error/empty/offline/disabled/长文本、六态及临时mood、对话取消和确认按钮。先确认信息层次与视觉，保持API不变。
4. **布局与样式**：先CSS/素材，再逐页调整布局；保留旧绑定节点，避免body整体innerHTML替换；独立小提交，先home与导航，再chat、health/insights、desk/companion、商户弹窗。
5. **渲染升级**：替换Avatar内部，实现原mood/口型/点击/销毁接口；先固定输入场景，再多窗口和连续过渡。不得新增设备动作。
6. **认证单独工作包**：按AUTH_ARCHITECTURE，先团队确定身份后端/会话边界，不混在视觉提交；本轮不开发。
7. **离线回归后团队评审**：提交文档/改动清单、截图/短动画、契约对比；真实服务/硬件测试另行授权，由负责人联调。
8. **合并**：未来经团队批准才push个人分支、创建PR并合入团队分支。与队友明确只改UI范围；定期安全fetch后先看差异，若目标分支更新由团队选择整合方法，禁止自动merge/rebase，更不能覆盖队友远端分支。本轮无上述远端操作。

## 新旧功能回归矩阵（未来执行，本轮未运行）

| 维度 | 应保持的行为 | 安全验证方式 |
|---|---|---|
| 路由/DOM | 全虚拟页、settings、coffee弹窗、返回、焦点、键盘、窄屏 | 合成app/IPC，静态DOM与截图对比 |
| 聊天 | start/delta累计/done/error/cancelled/reset；停止、重试、长文本；动作点击才执行 | fake SSE/fetch/bridge；验证请求和事件一致，真实API请求数为0 |
| 感知 | 六态阈值、迟滞、缺失数据不显示假0、校准/暂停 | 固定snapshot回放；不自动开真实摄像头 |
| 订单 | 幂等key复用、priceCents、unknown恢复、确认/支付白名单、两类门店ID | 合成API/journal；真实下单/支付/发车次数为0 |
| 硬件 | MQTT topic+JSON不变；UDP触发条件不变 | fake mqtt/socket，不连接broker/设备；GET订单也需stub |
| 宠物 | 每个mood、临时flash恢复、点击、加载失败、图片normal回退、连续过渡 | 固定事件序列、假音频电平；不连AI |
| 多窗口/生命周期 | 面板隐藏后monitor继续、桌宠拖动/选择/退出、反复切换无泄漏 | 隔离用户目录和fake设备/网络后Electron回归 |
| 存储/兼容 | localStorage键、IndexedDB版本、pending订单、原journal不被迁移 | 临时fixture副本，绝不覆盖真实.runtime |
| 构建与源码 | CSS不丢资源、三个HTML入口、无API/固件diff | 依赖准备后build、选定单元/合成UI测试、git diff检查 |

已有测试入口：[web/package.json:15](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/package.json#L15)；算法core、coffee/brightness/luckin/shansong/companion/tts/speech单元测试，Playwright/Electron UI测试及Python网关测试均存在。
**不要一键执行所有测试**：desktop亮度会改屏幕；TTS可能回退网络；companion live开关会调用真实AI；bailu/订单测试会起服务，需先逐个检查隔离与dry-run。[web/README.md:21](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/README.md#L21)、[web/README.md:50](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/README.md#L50)、[web/README.md:73](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/README.md#L73)。
本轮没有测试执行证据，不能把历史README“通过”记录当本轮结果。

