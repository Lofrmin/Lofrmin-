# FRONTEND_BASELINE：改造前安全验证基线

日期：2026-10-31（Asia/Shanghai）。
仓库：C:/Users/ASUS/Documents/Codex/2026-10-31/gpt-6-1-sol-high-git/work/Lofrmin-
分支：feature/pet-ui-redesign。
基线SHA：7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176。

## 结果与适用范围

【实际验证】锁定依赖安装成功，生产构建成功，隔离的Edge浏览器完成11个页面/弹窗/尺寸场景截图。最终pageerror、console.error、资源请求失败与HTTP 4xx/5xx均为0；实际前端请求仅68次本机静态文件GET，非静态/外部HTTP尝试0、WebSocket尝试0。Live2D加载成功。不是Electron/真实AI/硬件全链路通过。

【未执行】Electron、Python网关、TTS服务、摄像头、定位、MQTT连接、真实AI、订单创建/查询/支付、设备控制、数据库迁移、项目全量测试和部署。所有服务与临时浏览器已在finally中关闭，没有留下运行中的前端服务器。

## 开发环境与依赖安装

- Windows；Node.js v24.15.0；npm 11.12.1；Git 2.53.0.windows.2。
- package.json不在仓库根目录，而在web/。最初根目录读取package.json失败是目录定位问题；已切到web执行。
- 初始web/node_modules不存在；已有五份docs审计文档为未跟踪文件，未覆盖。
- package-lock.json lockfileVersion=3；顶层无preinstall/install/postinstall/prepare业务脚本。lock中标注安装脚本的包有electron-winstaller、esbuild、fsevents。为避免执行下载器、原生安装与未知生命周期，全部使用ignore-scripts跳过；未运行npm rebuild或Electron安装器。
- 锁文件resolved使用registry.npmmirror.com和registry.npmjs.org，本轮沿用已锁URL和integrity，不切换依赖来源、不改版本。
- 安装：416个包，退出码0。npm给出旧依赖deprecated提示及npm新版提示，没有执行任何升级。
- npm ls --depth=0成功：Vite6.4.5、Playwright1.64.1、Electron42.11.18、electron-builder26.18.0、MediaPipe1.1.1、Pixi6.5.10、pixi-live2d-display0.4.0、MQTT5.16.1。它们来自现有锁文件；package.json中的范围不等于锁定的具体版本。
- package.json、package-lock.json及全部已跟踪业务文件git diff为空。

在web目录执行过：
```powershell
npm ci --ignore-scripts --no-audit --no-fund --proxy=http://127.0.0.1:7890 --cache=../../../npm-cache --fetch-retries=0 --fetch-timeout=30000
npm run build
npm ls --depth=0 --ignore-scripts
```
代理仅为命令级，未改npm/Git全局配置。ignore-scripts安装足以支持本轮Vite构建，但不保证Electron可执行文件已准备好；桌面运行需后续单独检查。

## 正确命令及启动风险

| 命令（web目录） | 行为 | 本轮 |
|---|---|---|
| npm run dev | Vite开发服务器；配置中/api代理到127.0.0.1:8001 | 未运行；不能把它当纯静态隔离 |
| npm run build | vite build，三个HTML入口 | 已运行，退出0 |
| npm run preview | Vite构建预览 | 未直接运行；本轮改用仓库外只读静态服务器，避免历史代理 |
| npm start | build后electron . | 未运行 |
| npm run desktop | electron .，读取现有dist | 未运行 |
| npm test / test:* | 单元或桌面/硬件/订单测试，安全性不同 | 没有全量执行，不能声称通过 |
| pack / pack:portable | Windows打包 | 未运行 |

启动源码证据：
- web/vite.config.js:4：index.html/pet.html/monitor.html多入口；:7：历史/api代理。
- web/desktop/main.cjs:194：Electron启动服务/窗口；:205：读取模型配置；:280：snapshot触发companion.observe；:317加载隐藏monitor窗口。
- web/src/desktop/monitor.js:64：模块自动start摄像头；不能将隐藏窗口当无副作用页面。
- web/src/app/ui-desk.js:111：若已有nd-mqtt则自动connect。
- web/src/app/reactions.js:54：状态变更同时控制宠物、自动灯光和提醒；:78可能发MQTT alert。
- server/bailu_coffee_adapter.py:251：GET订单状态会推进计时并可能发送UDP发车，因此没有测试真实订单查询。

## 本轮运行隔离方法

验证脚本在仓库外：work/frontend-baseline.cjs（相对本聊天工作目录）；结果JSON和两次诊断结果也在work/，不属于业务源码。
从仓库根目录可用 `node ../frontend-baseline.cjs` 重放；需要系统Edge和上述锁定依赖。该脚本不是项目正式测试套件。

1. 自建只读静态HTTP服务器，仅绑定127.0.0.1随机端口，根目录web/dist，无API handler、无proxy、无Python/Node业务服务。
2. Edge无头临时context，不使用用户浏览器profile；没有window.neuroDesktop/preload桥，不读取.runtime、API Key或系统浏览器凭据。
3. context.route只放行同origin、GET、确实存在于dist的文件；外部域名、非静态路径（含任何/api和订单请求）、非GET全部abort；WebSocket全部关闭，Service Worker禁用；另加connect-src self。
4. 在此临时context清空存储，nd-mqtt为空；禁用摄像头/麦克风、定位和系统语音调用，静音。只是测试上下文措施，没有修改应用接口或源文件。
5. 未点击发送聊天、下单/付款、设备连接、监测、调灯或播放按钮；示例咖啡按钮全部disabled。配送页面仅查看localStorage内置体验订单。
6. 最终测得bridge=false、mqttSaved=null、focus/fatigue都为“--”；没有把EEG回放误当实时检测值。
7. 上述限制覆盖本轮浏览器应用请求，不等于整台操作系统网络被防火墙隔离；并未为独立Electron或其他进程建立通用隔离。

## 页面、资源与基础渲染

| 场景 | 检查方式 | 结果 |
|---|---|---|
| home/supply/delivery/chat/health/insights | 当前新导航的可见按钮点击 | 成功切换并截图，无横向页面溢出 |
| desk/companion旧视图 | 在legacy可见时，程序化触发保留的data-view按钮现有click handler | 能渲染并截图；不是完整可见入口可发现性验收 |
| settings | 点击当前可见设置按钮 | dialog打开/关闭正常 |
| sample-coffee | 程序化触发隐藏的旧coffee-go点击处理 | 示例门店出现、真实下单按钮可用数0；没有订单API请求 |
| home-mobile | 420×900视口，全页截图 | document横向溢出false；存在下述既有视觉问题 |
| Live2D | 等待data-live2d=ready | 成功，Hiyori模型与canvas加载；未验证全部表情与口型 |
| 静态资源 | 收集全部response/requestfailed | 68次静态GET，未发现失败；不等于穷举所有上传/外部素材 |
| pet.html/monitor.html | 构建生成入口 | 未在浏览器直接运行；它们依赖Electron桥，monitor还会自动启动检测 |

截图在本聊天outputs/frontend-baseline/：
home.png、supply.png、delivery.png、chat.png、health.png、insights.png、desk.png、companion.png、settings.png、sample-coffee.png、home-mobile.png。

已目视检查桌面和窄屏首页：基本卡片、图片、导航及角色可见；窄屏hero顶部问候文字与角色/背景有重叠，后续可作为UI改造目标。无横向溢出不等于响应式视觉完美。动态时钟、配送计时和Live2D会使截图像素变化，未来比较需固定输入/时钟或遮罩动态区域。

## 错误、警告和未验证项

- 构建成功：Vite6.4.5，158模块，2.83秒；三个HTML及相关资源已产出。custom JS chunk约671.02kB（未gzip），触发>500kB警告。本轮不改打包配置/代码拆分。
- 第一次脚本按可见data-action=desk查找入口超时；第二次旧coffee-go真实点击因隐藏超时。均为测试定位器与新壳隐藏旧控件的结构不匹配；此前页面无JS异常。只调整仓库外验证脚本，第三次完整结束，退出码0。
- 最终运行pageerror=0、console.error=0、console.warning=0、HTTP失败=0、请求失败=0。不能据此推断聊天、摄像头、TTS、订单或硬件正常。
- 没有执行原有test:ui，它含旧导航选择器和演示触发；没有运行全部npm test或任何真实桌面/设备测试。
- 本轮未测试注册/登录，因为当前没有该功能且未授权开发；未测试实时视觉、AI流、真实TTS、桌宠窗口生命周期、支付/订单恢复、多用户数据等。
- 依赖deprecated提示只记录，未升级；npm自动audit关闭，不构成依赖安全审计通过。
- 调用层和状态契约下面来自静态源码；不是实际IPC/API调用验收。

## 必须保留的DOM、事件、状态与IPC

新壳会移动现有chat节点、旧导航与dialog（web/src/app/product-workspace.js:17）；不应整体innerHTML替换body或销毁仍被main.js保存引用的节点。main.js有大量直接querySelector，无空值保护。CSS/layout可改，但DOM身份和监听器生命周期需保持。

关键绑定：
- 感知：btn-start/btn-calib、video/overlay、state-pill/state-src、g-focus/g-fatigue、metrics、timeline；data-mode= sense/demo。
- EEG：eeg-canvas/eeg-play/eeg-seek/bands；不是实时脑电设备接口。
- 对话：chat-form/chat-input/chat-send/chat-stop/chat-clear/chat-mic、chat-name/chat-via、opt-ai-share/opt-ai-proactive、chat-voice；保留start/delta/done/error/cancelled/reset/config，delta是累计字符串，按requestId关联。
- 咖啡：coffee-dialog/coffee-status/coffee-stores/coffee-go/coffee-refresh/coffee-close/coffee-later，订单pending幂等key、忙碌状态、确认门槛/重试/unknown恢复不能改变。
- 工位：kelvin/level/presets、mqtt-url/mqtt-connect/mqtt-off/chip-mqtt、sync-screen及brightness状态；视觉滑杆不能绕过原Light服务。
- 宠物：stage/gallery、setPet/setMood/say/mount/unmount/onPoke；Avatar保持speak/lipSync/stopLip/destroy，actions为真回调，动画不能自动执行。
- 导航：data-action、data-view、data-mode、data-avatar、data-chat-tab、data-light-preset、data-mirror及body.dataset.view。
- 存储：nd-mqtt、nd-pet、nd-pending-order、nd-service-orders/profile及现有偏好；IndexedDB neurodesk-pets/custom；不可在UI升级时迁移/清除。
- 六态：normal/focused/distracted/tired/drowsy/away，StateMachine hold=3000、minDwell=5000及迟滞规则不变。
- mood映射：distracted→curious、drowsy→alert、away→away后sleepy；临时flash到期恢复当前业务态。表情不是小车控制指令。

IPC保持window.neuroDesktop原名、方法、参数、channel、返回、事件与sender权限。preload.cjs为当前完整桥接基线；不得为了UI测试将真实API改成Mock，也不把新登录鉴权塞进现有通道。模型、Provider、URL、请求/响应、环境变量与硬件协议全部受保护。详细原契约见已有API_PROTECTION.md和FRONTEND_REDESIGN_PLAN.md。

## 后续安全开发建议

以本轮独立浏览器静态构建为视觉回归入口；每次改动重建后回放固定数据、记录控制台与资源结果，再比截图。可见导航和旧程序化事件验证应分别标记；不要以隐藏节点click代替实际交互验收。

优先CSS/素材及保留宿主的局部布局，再在既有PetView/Avatar接口内更新渲染。保持Chat/Coffee/Light/StateMachine/Reactions以及preload/backend/firmware行为不变。增加交互后需在同样隔离环境补测禁用、错误、Loading、取消和重复点击；目前没有这些行为全覆盖。

Electron、真实服务和设备联调是独立后续任务；必须先设计并验证各进程隔离，不能直接执行npm start、订单状态轮询或真实测试脚本。全局Git代理仍是旧2802，本轮未修改，后续Git联网继续使用命令级7890覆盖。

## 附录：运行DOM快照与完整IPC桥接

运行时采集143个id（含SVG动态id）；下列为去除生成型p*以及gf/gt后应优先保持的宿主id。modal动态表单与瑞幸流程按需生成的元素未穷举，不能把本清单当所有未来场景的完整DOM。

```text
auto background-note bands btn-calib btn-hide-panel btn-pip btn-quit btn-settings btn-sound btn-start cam-calib cam-empty cam-fps card-cam card-demo card-desk card-eeg chat chat-clear chat-form chat-input chat-mic chat-name chat-note chat-send chat-stop chat-via chat-voice chat-voice-stop chip-cam chip-eeg chip-mqtt coffee-close coffee-dialog coffee-footer-note coffee-go coffee-heading coffee-later coffee-refresh coffee-sample coffee-src coffee-status coffee-stores coffee-text demo-auto demo-fa demo-fatigue demo-fo demo-focus demo-pomo demo-present demo-water eeg-canvas eeg-d eeg-e eeg-note eeg-play eeg-seek eeg-seg eq g-fatigue g-focus gallery kelvin kv lamp legacy-workspace level log log-clear lv metrics monitor-detail monitor-title mqtt-connect mqtt-off mqtt-url nd-active-delivery nd-brightness-panel nd-chat-tab-content nd-clock nd-companion-panel nd-eye-care nd-fatigue-value nd-focus-value nd-greeting nd-greeting-name nd-health-caption nd-health-state nd-hero-portrait nd-last-break nd-modal nd-music-status nd-music-symbol nd-order-list nd-screen-capability nd-selected-name nd-service-page nd-sync nd-timer nd-timer-toggle nd-tips-list nd-user nd-welcome-message nd-work-duration opt-ai-proactive opt-ai-share opt-autostart opt-notify opt-voice overlay pomo presets runtime-label screen-status settings stage state-pill state-src sync-screen sync-wrap timeline tint tint-on tracks video vol
```

pet.html静态id：desktop-pet, pet-speech, pet-stage, pet-open, pet-state。
monitor.html静态id：无命名id（使用video/canvas标签宿主）。

data-action运行值：break, brightness, chat, close-brightness, close-companions, coffee, companion, delivery, desk, eye, focus, health, home, insights, lunch, music, panels, profile, read-greeting, refresh-tips, reminder, settings, snack, supply, timer, timer-settings, upload, wake。只有渲染/导航被检查，包含业务动作的按钮没有执行。

以下直接摘录当前preload.cjs（无凭据值），作为UI未来必须兼容的调用与事件清单；未经实际Electron运行验证：

```javascript
const { contextBridge, ipcRenderer } = require('electron');
const listen = (channel, fn) => {
  const listener = (_, value) => fn(value);
  ipcRenderer.on(channel, listener);
  return () => ipcRenderer.removeListener(channel, listener);
};
contextBridge.exposeInMainWorld('neuroDesktop', Object.freeze({
  snapshot: () => ipcRenderer.invoke('snapshot'),
  onSnapshot: (fn) => listen('snapshot', fn),
  onCommand: (fn) => listen('monitor-command', fn),
  publish: (value) => ipcRenderer.send('monitor-snapshot', value),
  monitor: (command) => ipcRenderer.invoke('monitor-control', command),
  openPanel: () => ipcRenderer.invoke('open-panel'),
  hidePanel: () => ipcRenderer.invoke('hide-panel'),
  showPet: () => ipcRenderer.invoke('show-pet'),
  movePet: (delta) => ipcRenderer.send('move-pet', delta),
  selectPet: (id, name) => ipcRenderer.invoke('select-pet', id, name),
  onPet: (fn) => listen('select-pet', fn),
  selectedPet: () => ipcRenderer.invoke('selected-pet'),
  onCoffee: (fn) => listen('offer-coffee', fn),
  coffeeConfig: () => ipcRenderer.invoke('coffee-config'),
  nearby: (coords) => ipcRenderer.invoke('coffee-nearby', coords),
  locate: () => ipcRenderer.invoke('locate'),
  locationSettings: () => ipcRenderer.invoke('location-settings'),
  order: (order) => ipcRenderer.invoke('coffee-order', order),
  orderStatus: (orderId) => ipcRenderer.invoke('coffee-order-status', orderId),
  luckinProducts: (input) => ipcRenderer.invoke('luckin-products', input),
  luckinDetail: (input) => ipcRenderer.invoke('luckin-detail', input),
  luckinSwitch: (input) => ipcRenderer.invoke('luckin-switch', input),
  luckinPreview: (input) => ipcRenderer.invoke('luckin-preview', input),
  deliveryConfig: () => ipcRenderer.invoke('delivery-config'),
  deliveryPreview: (input) => ipcRenderer.invoke('delivery-preview', input),
  deliveryCreate: (input) => ipcRenderer.invoke('delivery-create', input),
  deliveryRecover: (input) => ipcRenderer.invoke('delivery-recover', input),
  luckinHistory: () => ipcRenderer.invoke('luckin-history'),
  luckinResolve: (input) => ipcRenderer.invoke('luckin-resolve', input),
  luckinRecover: (input) => ipcRenderer.invoke('luckin-recover', input),
  luckinPayment: (url) => ipcRenderer.invoke('luckin-payment', url),
  setAutoStart: (value) => ipcRenderer.invoke('auto-start', value),
  autoStart: () => ipcRenderer.invoke('auto-start-status'),
  setNotifications: (value) => ipcRenderer.invoke('notifications', value),
  chatStatus: () => ipcRenderer.invoke('chat-status'),
  chatSend: (input) => ipcRenderer.invoke('chat-send', input),
  chatCancel: (id) => ipcRenderer.invoke('chat-cancel', id),
  chatClear: () => ipcRenderer.invoke('chat-clear'),
  chatSettings: (input) => ipcRenderer.invoke('chat-settings', input),
  companionMode: (mode) => ipcRenderer.invoke('chat-mode', mode),
  onChat: (fn) => listen('chat-event', fn),
  onCompanionSpeech: (fn) => listen('companion-speech', fn),
  screenBrightness: () => ipcRenderer.invoke('screen-brightness'),
  setScreenBrightness: (value) => ipcRenderer.invoke('set-screen-brightness', value),
  ttsStatus: () => ipcRenderer.invoke('tts-status'),
  ttsSpeak: (input) => ipcRenderer.invoke('tts-speak', input),
  quitApp: () => ipcRenderer.invoke('quit-app'),
}));
```

## 最终Git安全检查

仅新增本报告docs/FRONTEND_BASELINE.md；此前五份审计文档原样保留。node_modules、dist由现有.gitignore忽略，测试脚本和结果位于仓库外work/，截图和本报告副本位于outputs/。git diff与git diff --cached均为空；package.json/lock和业务源码没有修改；没有stage、commit、Push、Merge或Deploy。

