# 白鹭湾无人车固件（STM32F407VET6）

由卖家 F407VE 库函数例程改造而来，一个工程跑齐 OLED / 舵机 / 电机 / 按键 / 蓝牙。

## 硬件接线

| 模块 | 接法 |
|---|---|
| OLED (0.96 SSD1306, 4 针 I2C) | GND / 3V3 / **PB6=SCL** / **PB7=SDA** |
| SG90 舵机 | 棕=GND、红=5V 充电宝、橙=**PA6** |
| L298N 电机 | IN1=PA0, IN2=PA1, IN3=PA2, IN4=PA3；ENA/ENB 跳线帽插上 |
| 按键 | K0=**PE4**（低电平按下），K1=PE3 |
| HC-05 底板 | VCC=5V, GND=GND, **TXD→PA10**, **RXD→PA9**（交叉） |

电源：4×AA → L298N 的 12V/地；5V 充电宝 → STM32 5V、舵机、HC-05。**所有 GND 必须共地。**

## 行为

上电后 OLED 显示 `BAILU CAR READY` / `PRESS K0 OR SEND G`。

三种触发方式等价：

1. 按 K0 键
2. 蓝牙串口助手发 `G`
3. 上位机（咖啡网关）通过串口发 `G`

触发后：小车前进 1.5 秒 → 舵机开舱 → OLED 显示取餐码 → 3 秒后合舱 → 显示 THANKS。

## 编译与下载

用 Keil 5.14 打开 `USER/LED.uvprojx`：

- Device: `STM32F407VETx`（**不要改 TargetName**，见下）
- Debug: `J-LINK / J-TRACE Cortex`，Port SW，Max Clock 4MHz
- Flash Download: `STM32F4xx 512KB Flash`，勾 `Reset and Run`
- 器件包: `Keil.STM32F4xx_DFP.2.11.0`（1.0.8 没有 512KB 算法，会 Erase Failed）

命令行（先编译再下载，两条分开）：

```powershell
E:\Keil_v5\UV4\UV4.exe -b "USER\LED.uvprojx" -t LED -j0 -o build.log
E:\Keil_v5\UV4\UV4.exe -f "USER\LED.uvprojx" -t LED -j0 -o flash.log
```

`-f` 不隐含编译，必须先 `-b`。

或绕过 Keil（更稳）：

```powershell
python hks\tools\jlink_flash.py "…\OBJ\LED.hex"
```

## 两个必须知道的坑

**1. 不要改 `<TargetName>`。**

Keil 5.14 的 `.uvoptx` 里 `<nTsel>` 与 `<TargetName>` 绑定。改了 TargetName 而不同步 nTsel，
uVision 会报 `Internal DLL Error` / `Flash Download failed - Target DLL has been cancelled`。
所以工程名叫 `LED`——名字难看但能用。

**2. 增删源文件后必须同步 `.uvoptx`。**

`.uvoptx` 里的文件记录按 `<Group>` 分组存放，记录数必须与 `.uvprojx` 的文件数完全一致
（连 readme.txt 也要有一条）。不一致同样是 Internal DLL Error。

用脚本处理：

```powershell
python hks\tools\rebuild_uvoptx.py "USER\LED.uvprojx" "USER\LED.uvoptx"
```

## 关键实现说明

- **OLED 驱动是重写的 I2C 版。** 卖家例程自带的是 4 线软件模拟 SPI
  （CS=PB12 / RST=PB14 / RS=PC5 / SCLK=PB13 / SDIN=PB15），和 4 针 I2C 模块不兼容。
  本工程用软件 I2C 时序 + PB6/PB7，任何 I2C 模块都能驱动。
  屏不亮就把 `oled.h` 里的 `OLED_I2C_ADDR` 从 `0x78` 改成 `0x7A`。
- **按键用 PE4/PE3**，不是卖家例程的 PA0——PA0 在本工程是电机 IN1。
- **舵机 PWM 是 50Hz / 20ms**（TIM3 arr=20000-1, psc=84-1），不是卖家 PWM 例程的 2kHz。
  脉宽 500us = 0°，2500us = 180°。
- **这个 F4 库是精简版**：`GPIO_Mode_AF`（不是 `GPIO_Mode_AF_PP`）、`GPIO_Mode_IN`
  （不是 `GPIO_Mode_IN_FLOATING`）、`GPIO_Speed_50MHz` 走 legacy 宏。
  直接照抄 ST 标准 HAL 代码会编译不过。
- **串口接收复用 usart.c 自带的 `USART1_IRQHandler`**，main.c 里不再重复定义中断
  （重复定义会报 `L6200E: Symbol USART1_IRQHandler multiply defined`）。
  波特率 9600 接 HC-05。

## 文件结构

```
bailu_car/
├── USER/            工程文件 + main.c + 系统文件
├── CORE/            CMSIS 内核 + 启动文件
├── FWLIB/           标准外设库（精简版）
├── SYSTEM/          delay / sys / usart
└── HARDWARE/
    ├── OLED/        oled.c/.h（I2C 重写版）+ oledfont.h 字库
    ├── SERVO/       servo.c/.h（TIM3_CH1 = PA6）
    ├── MOTOR/       motor.c/.h（L298N = PA0..PA3）
    ├── KEY/         key.c/.h（PE4 / PE3）
    └── LED/         led.c/.h（PA1）
```
