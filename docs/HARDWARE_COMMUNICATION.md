# 硬件小车通信静态审计

> 审计日期：2026-10-31（Asia/Shanghai）。固定代码基线：`Lofrmin/Lofrmin-` 的 `feature/product-workspace`，Commit `7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176`。
> 【已由代码确认】指静态代码事实，不代表服务、凭据或设备已验证；【根据代码推测】表示推断；【需要队友确认】表示外部配置或产品决策缺失；【需要实机验证】表示运行及物理结果未知。代码事实一般为高置信度；未发现实现的结论只限于本次仓库版本。
> 接入限制：工作目录最初不是 Git 仓库。正常克隆因本机代理连接失败；单次停用代理后的克隆亦无法连接 GitHub 443。只读 GitHub 连接器成功读取固定 SHA 的完整目录树（未截断，297 个文件）和主要自有源码；没有本地克隆、origin 引用或个人分支。文档暂存于 outputs/docs，不能声称已写入个人分支。未运行项目、安装依赖、导入业务模块、执行测试、访问设备、调用业务第三方 API 或修改远端。
> 下文路径行号链接均指向固定 SHA；教程、README、HANDOFF 的历史描述只作辅助，运行源码优先。不复制任何 Secret 或凭据型 Webhook URL。


## 判断：B，同时存在 C/D 路径

【已由代码确认，高】仓库存在真实发送实现和实体外设固件，不能归类为“完全没有硬件代码”或“全是Mock”。但**整个前端 → 实体车 → 前端的闭环尚未由仓库证明**，总体按 **B：有硬件通信代码，尚未验证**。新工作台配送 UI 是 C（Mock），MQTT 的设备侧及 UDP→UART桥目前相当于 D（软件端接口已有，仓库外实现缺失）。

【需要实机验证】小车当前刷入哪份固件、是否有ESP32-S3/其他桥接设备、网络/蓝牙连接及实际动作。日志“已广播”和UI“已到达”都不能视为设备确认。

## 三条不同链路

### 1. 白鹭订单 → UDP 广播（通过 Electron 和 Python）

```text
用户打开原咖啡入口、确认商品
 → Reactions.orderCoffee → bindCoffeeDialog
 → Coffee.submit（幂等key、pending保存）
 → window.neuroDesktop.order
 → preload IPC coffee-order
 → Electron main → createCoffeeGateway.order
 → HTTP POST /api/orders → FastAPI create_order（本地模拟商户）
 → renderer 每2秒 orderStatus
 → IPC coffee-order-status → HTTP GET /api/orders/{id}
 → FastAPI _public_status
 → elapsed进入delivering 且 !carTriggered
 → trigger_hardware_car → UDP broadcast CAR_RUN:<pickupCode>
 → 预期 ESP32-S3 接收端【仓库未发现】
 → UDP 转 UART/蓝牙桥【仓库未发现】
 → STM32【无法证明此链已接通】
```

证据：[web/src/app/reactions.js:41](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L41)、[web/src/desk/coffee.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/coffee.js#L23)、[web/desktop/preload.cjs:25](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/preload.cjs#L25)、[web/desktop/main.cjs:256](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L256)、[web/desktop/coffee.cjs:42](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L42)、[web/src/app/coffee-dialog.js:50](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/coffee-dialog.js#L50)、[server/bailu_coffee_adapter.py:251](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L251)、[server/bailu_coffee_adapter.py:133](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L133)。

注意：商品点击链只存在于原咖啡弹窗；新工作台“园区补给”的 checkout 不调用上述API。不能把它重画后误接成真实发车。[web/src/app/product-workspace.js:98](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L98)。

### 2. STM32 本地按键／HC-05 串口（不要求经过后端）

```text
实体 K0按键
 或 手机蓝牙串口工具 → HC-05 → USART1 RX
 或 理论上位机UART（源码未找到电脑发送实现）
 → USART1_IRQHandler 接收完整CRLF帧
 → BT_GetChar 取首字节
 → G/g → Delivery_Start("A888" 固定演示取餐码)
 → OLED → Motor_Drive(1500) → Servo_OpenHatch
 → 3秒 → Servo_CloseHatch → THANKS
```

【已由代码确认，高】固件不会解析 `CAR_RUN:<码>`，主循环只分支 G/g 与K0；取餐码是固定演示文本，不是后端取餐码。USART要求CRLF结束，文档仅写“发送G”遗漏了帧结束要求。BT_GetChar从帧取首字符后改变接收状态，不能假定支持任意连续多命令流。[firmware/bailu_car/USER/main.c:30](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L30)、[firmware/bailu_car/USER/main.c:54](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L54)、[firmware/bailu_car/USER/main.c:98](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L98)、[firmware/bailu_car/USER/main.c:116](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L116)、[firmware/bailu_car/SYSTEM/usart/usart.c:102](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/SYSTEM/usart/usart.c#L102)。

上述仅解释代码，不是本轮设备操作步骤；本轮未连接蓝牙/串口，也未发送字符。

### 3. 前端 MQTT over WebSocket（直接连接 broker）

```text
ui-desk / Light / Reactions / sense
 → web/src/desk/mqtt.js
 → mqtt.connect(ws/wss URL)
 → broker（仓库没有部署配置）
 → 工位／车设备（仓库没有MQTT消费者）
broker → message(JSON或文本)
 → handlers[topic] / mq状态
 → Reactions BOOT确认或界面连接状态
```

【已由代码确认，高】此链不经过 Python HTTP 后端。MQTT不是Socket.IO；底层是mqtt.js over WebSocket。前端可以直接连接 broker，但**未发现浏览器直接用 BLE/WebSerial/USB 驱小车**。[web/src/desk/mqtt.js:11](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L11)、[web/src/app/ui-desk.js:102](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/ui-desk.js#L102)、[web/src/app/reactions.js:20](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L20)。

| MQTT方向 / Topic | 实际消息与消费者 | 证据 |
|---|---|---|
| publish desk/cmd | {type:'light',kelvin,level}；{type:'alert'} | [web/src/desk/mqtt.js:43](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L43)、[web/src/desk/light.js:72](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/light.js#L72)、[web/src/app/reactions.js:78](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L78) |
| publish neuro/state | {state,focus,fatigue,source}，有效数据时每秒 | [web/src/app/sense.js:82](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/sense.js#L82) |
| subscribe desk/status | 字符串online判定deskOnline；close清离线 | [web/src/desk/mqtt.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L23)、[web/src/desk/mqtt.js:30](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L30) |
| subscribe desk/event | {key:'confirm'} 在咖啡offer后30秒内打开推荐；否则happy闪动；不会直接提交订单 | [web/src/app/reactions.js:20](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L20) |
| subscribe park/car/status | 有订阅，但此次应用代码中未发现针对它的on注册/UI更新；不能据此声称可显示真实车辆遥测 | [web/src/desk/mqtt.js:23](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L23) |

## 反向反馈链：未闭环

1. **UDP**：trigger_hardware_car只有sendto，没有接收socket、ACK、遥测订阅或设备身份。carTriggers是“尝试发送次数”，发送失败也已经加计数；不是成功次数。[server/bailu_coffee_adapter.py:133](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L133)。
2. **FastAPI订单状态**：按time.time()-createdAt选择accepted/preparing/delivering/ready，独立于实体车。只有GET落在delivering时间窗才会触发；跳过窗口可能不发车。发车标记在尝试前置为True，异常也不自动重试。[server/bailu_coffee_adapter.py:251](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L251)。
3. **STM32**：printf可经UART输出启动及TRIGGER文本，但仓库没有电脑接收解析/转成HTTP或MQTT状态的实现，且不是业务ACK。[firmware/bailu_car/USER/main.c:114](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L114)、[firmware/bailu_car/USER/main.c:129](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L129)。
4. **新工作台**：stageFor通过本地订单时间映射配送步骤；只有“本地体验”数据。[web/src/app/product-workspace.js:73](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L73)、[web/src/app/product-workspace.js:116](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L116)。
5. **MQTT**：有通用消息分发和desk在线标记，但park/car/status没有UI消费；不能把deskOnline当作小车在线。

结论：前端经Python取得的“配送进度”目前不是硬件状态反馈。宠物状态也未由真实小车遥测决定。

## 实际指令与固件动作

| 项目 | 已存在实现 | 能否从现有网络/串口选择调用 |
|---|---|---|
| 发车请求 | UDP UTF-8 CAR_RUN:<pickupCode> | 网关可发送，接收端缺失；无ACK |
| 一整段配送演示 | UART帧首字符G或g，或K0 | 固件可触发；网络到UART桥未知 |
| 前进及停止 | Motor_Forward / Motor_Stop；Motor_Drive内部先前进再停止 | 主配送流程使用1.5秒；不是暴露的远程独立前进/停止命令 |
| 后退、左转、右转 | Motor_Backward / Motor_TurnLeft / Motor_TurnRight函数 | 仅底层能力，main没有对应字符或网络命令路由 |
| 开舱/关舱 | Servo_OpenHatch / Servo_CloseHatch | 配送流程内部调用，非远程独立舵机协议 |
| 表情/情绪/查询 | 未发现小车表情控制协议、状态查询或独立紧急停止命令 | 前端宠物mood不是小车指令 |

证据：[firmware/bailu_car/HARDWARE/MOTOR/motor.c:26](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/HARDWARE/MOTOR/motor.c#L26)、[firmware/bailu_car/HARDWARE/MOTOR/motor.c:33](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/HARDWARE/MOTOR/motor.c#L33)、[firmware/bailu_car/HARDWARE/MOTOR/motor.c:57](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/HARDWARE/MOTOR/motor.c#L57)、[firmware/bailu_car/USER/main.c:68](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L68)、[firmware/bailu_car/USER/main.c:127](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L127)。

## 配置与可靠性

| 项目 | 代码事实 | 证据/缺口 |
|---|---|---|
| UDP | IPv4广播255.255.255.255；默认8888；BAILU_CAR_UDP_PORT可覆盖；BAILU_CAR_UDP_DRY_RUN默认关闭 | [server/bailu_coffee_adapter.py:57](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L57)、[server/bailu_coffee_adapter.py:141](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L141)；不是实际设备IP |
| 设备ID | 未找到UDP消息deviceId；订单中是pickupCode | 不得据UI“白鹭01号”推断真实设备身份 |
| MQTT地址 | nd-mqtt存于localStorage；默认ws://<当前hostname>:9001 | [web/src/desk/mqtt.js:11](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L11)；无实际broker配置证据 |
| MQTT身份与重连 | 随机web-clientId；reconnectPeriod=4000ms；connectTimeout=3000ms | [web/src/desk/mqtt.js:16](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L16)；未显式定义业务heartbeat/ACK。库默认行为不是已验证设备协议 |
| MQTT离线 | close令connected/deskOnline=false；desk/status在线仅对工位 | [web/src/desk/mqtt.js:25](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/desk/mqtt.js#L25)；无车lastSeen超时映射 |
| UART | USART1 PA9TX/PA10RX，9600、8N1、无硬件流控、CRLF帧 | [firmware/bailu_car/USER/main.c:98](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L98)、[firmware/bailu_car/SYSTEM/usart/usart.c:74](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/SYSTEM/usart/usart.c#L74) |
| 蓝牙配对 | 硬件注释HC-05，未见应用配对流程、PIN、电脑COM口配置 | [firmware/bailu_car/USER/main.c:18](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L18) |
| ACK/超时/重发 | UDP应用层均未见；UART无机器可消费的完成ACK；HTTP请求超时不等于设备超时 | [server/bailu_coffee_adapter.py:140](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L140)、[web/desktop/coffee.cjs:13](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/coffee.cjs#L13) |
| 安全停止 | main配送流程含阻塞delay；未见运动过程通信急停分支 | [firmware/bailu_car/USER/main.c:54](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/firmware/bailu_car/USER/main.c#L54)；仅记录风险，不改固件 |

搜索范围包括依赖、发送/接收/回调、启动器、固件、文档、工具。未发现ROS/ROS2、BLE GATT、浏览器Serial/USB、Socket.IO、TCP自定义车协议、Arduino/ESP-IDF工程或MQTT车端代码。HC-05是串口蓝牙，不应称BLE。厂商USART/外设库的存在不等于上位机控制已实现。

## PET 与硬件的关系

【已由代码确认】人脸指标→状态机→Reactions会同时改变宠物mood与自动灯光，drowsy会向desk/cmd发alert；desk/event confirm可触发happy或打开咖啡。这是共同状态/事件驱动的**间接工位联动**。不是宠物动画驱动电机，也不是小车遥测驱动宠物。[web/src/app/reactions.js:54](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L54)、[web/src/app/reactions.js:78](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/reactions.js#L78)。
AI回复可给工位动作建议，点击后才运行；没有远程小车工具。[web/desktop/companion.cjs:25](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/companion.cjs#L25)。

## 队友核对与未来实机联调前提

【需要队友确认】
- 实际硬件是STM32+HC-05、ESP32-S3，还是两者组合？本仓固件是否在设备上？
- UDP接收器及UDP→UART桥是否在另一个仓库/电脑？谁维护，版本与协议是什么？
- 是否有MQTT broker、设备订阅topic、状态消息schema、身份认证、离线与ACK约定？
- “到站”应表示模拟进度还是设备传感器确认？目前UI不能担保真实到达。

【需要实机验证，仅后续明确授权后】
由硬件负责人先确认物理安全、固件版本、供电接线、网络/蓝牙配对、串口帧、收包日志与停止方案；先离线contract/模拟接收测试，再单独授权受控实机测试。设备接收、实际运动、舵机、取餐码传递、回传/ACK/离线分别验收，不以HTTP 200替代。
本轮没有启动任何发送/烧录/测试工具，也没有修改IP/端口/topic/协议/固件。

