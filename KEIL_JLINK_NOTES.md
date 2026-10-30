# Keil + J-Link 烧录排错手册（2026-10-29 实测）

本文记录的是**真实踩过的坑**，不是通用教程。目标板：STM32F407VET6（正点原子 F407VE 黑板）。

---

## 一、结论速查

| 报错 | 真实原因 | 修法 |
|---|---|---|
| `No ST-LINK detected` | 工程里 `<Driver>` 锁死了 `STLink\ST-LINKIII-KEIL_SWO.dll` | 改成 `Segger\JL2CM3.dll` |
| `Erase Failed!` / `Flash Download failed - Target DLL has been cancelled` | `JLinkSettings.ini` 里 `Device="UNSPECIFIED"`，J-Link 匹配不到 Flash 算法 | 改成真实器件名 `Device="STM32F407VE"` |
| 同上（换了 Device 还失败） | Flash 算法版本与器件包布局不匹配 | 装 `Keil.STM32F4xx_DFP.2.11.0.pack`，工程 PackID 同步 |
| `Failed to open file`（J-Link Commander） | 路径里有中文，J-Link 打不开 | 先复制到纯英文路径 |

---

## 二、为什么 `Erase Failed` 这么难查

Keil 烧录要三样东西同时对上：

1. **调试器 DLL** —— 工程 `<Driver>` 字段决定用 ST-Link 还是 J-Link
2. **Flash 算法** —— `<FlashDriverDll>` 里 `FP0($$Device:<器件名>$<算法路径>)`
3. **J-Link 自己的配置** —— `USER\JLinkSettings.ini` 的 `[FLASH] Device="..."`

第 3 项最容易漏。`Device="UNSPECIFIED"` 时 J-Link 根本不知道要找哪个器件的算法，表现为「连接成功、能识别 Cortex-M4，但一擦除就失败」——看起来像芯片坏了，其实是配置缺失。

用 J-Link Commander 单独验证可以区分：

```powershell
D:\Program Files\SEGGER\JLink_V988\JLink.exe -CommandFile cmd.txt
```

```
device STM32F407VE
si SWD
speed 4000
connect
erase
exit
```

- Commander 能 `erase` 成功 → **芯片和探头都没问题**，是 Keil 侧配置
- Commander 也失败 → 才是芯片读保护或硬件问题

---

## 三、器件包版本是隐形坑

F407VET6 有 **512KB Flash**，但不同版本的 Device Family Pack 布局不同：

| 版本 | 算法目录 | F407VE 的算法 |
|---|---|---|
| 1.0.8 | `Flash\` | 只有 `STM32F4xx_1024.FLM`（1MB），**没有 512KB** |
| 2.9.0 / 2.11.0 | `CMSIS/Flash\` | `STM32F4xx_512.FLM` ✅ |

工程里 `FP0($$Device:STM32F407VETx$CMSIS\Flash\STM32F4xx_512.FLM)` 这种写法，**只有 2.x 的包能解析**。装了 1.0.8 就永远找不到算法。

**结论**：F407VE 一律用 2.9.0 以上，本机用 2.11.0。

---

## 四、标准修复流程

```powershell
# 1. 装 J-Link 最新驱动（顺带更新 Keil 里的 DLL）
#    D:\Program Files\SEGGER\JLink_V988\JLinkDLLUpdater.exe
#    它会把 E:\Keil_v5\ARM\Segger\JLinkARM.dll 从 2015 版升级到 V9.88

# 2. 装 F4 器件包 2.11.0
E:\Keil_v5\UV4\PackInstaller.exe -i "E:\Keil\MDK5\Keil.STM32F4xx_DFP.2.11.0.pack"

# 3. 批量修工程（脚本在 hks/tools/fix_keil_jlink.py）
python tools\fix_keil_jlink.py "E:\Keil\STM32F407VE"
```

脚本会做这些事：

- `<Driver>`：`STLink\ST-LINKIII-KEIL_SWO.dll` → `Segger\JL2CM3.dll`
- `<Flash2>`：`BIN\UL2CM3.DLL` → `Segger\JL2CM3.dll`
- Flash 算法：`STM32F4xx_1024` → `STM32F4xx_512`
- Flash 长度：`-FL0100000` → `-FL0080000`
- 器件名：`F407VG` / `F407ZG` → `F407VE`
- `<PackID>`：统一到 `Keil.STM32F4xx_DFP.2.11.0`
- 算法路径分隔符：`CMSIS\Flash\` → `CMSIS/Flash/`
- J-Link 注册项里残留的 TCP 会话参数（`-JI127.0.0.1:7997`）清掉
- `JLinkSettings.ini` 的 `Device` 设为真实器件名

---

## 五、绕过 Keil 直接烧录

Keil 出问题时用这个，**已验证可用**：

```powershell
python tools\jlink_flash.py "E:\Keil\...\OBJ\LED.hex"
```

输出：

```text
Downloading file [C:\Users\w\AppData\Local\Temp\jlinkflash-xxx\LED.hex]...
J-Link: Flash download: Bank 0 @ 0x08000000: 1 range affected (16384 bytes)
J-Link: Flash download: Total: 0.659s (Prepare: 0.167s, Compare: 0.111s, Erase: 0.225s, Program: 0.057s, Verify: 0.019s, Restore: 0.078s)
O.K.
flash ok: LED.hex -> STM32F407VE
```

脚本会自动把 hex 复制到纯英文临时目录（J-Link 打不开中文路径），并把 JLink.exe 路径按优先级查找。

---

## 六、Keil 命令行下载（CI/脚本友好）

```powershell
# 只编译
E:\Keil_v5\UV4\UV4.exe -b "工程路径\LED.uvprojx" -t LED -j0 -o "E:\Keil\flash\out.log"

# 编译并下载（-f = flash）
E:\Keil_v5\UV4\UV4.exe -f "工程路径\LED.uvprojx" -t LED -j0 -o "E:\Keil\flash\out.log"
```

成功标志：

```text
Erase Done.Programming Done.Verify OK.
Application running ...
```

`-j0` 表示用命令行工具的默认输出流。`UV4.exe` 是 GUI 程序，调用后不会自动返回，需要等它自己退出或手动 kill。

---

## 七、读寄存器验证硬件

**GPIOA 在 F407 上的基址是 `0x40020000`**：

```text
GPIOA_ODR = 0x40020014   # 输出
GPIOA_IDR = 0x40020010   # 输入
```

> 教训：我一开始一直读 `0x40010814`，那是 GPIOH 之类的地址，读出来恒 0，差点误判「LED 不闪、程序死了」。

LED 例程用 PA1（`led.h`: `#define LED2 PAout(1)`），500ms 翻转、低电平点亮。验证脚本：

```text
device STM32F407VE
si SWD
speed 4000
connect
r
g
mem32 0x40020014, 1
sleep 300
mem32 0x40020014, 1
sleep 300
mem32 0x40020014, 1
exit
```

实测输出（bit1 在 0 和 1 之间跳）：

```text
40020014 = 00000000
40020014 = 00000000
40020014 = 00000002
40020014 = 00000002
```

`0x00000002` = bit1 置位 = PA1 输出高。

---

## 八、例程速查（`E:\Keil\STM32F407VE\F407V核心板例程-库函数版本`）

| 例程 | 工程文件 | 用途 |
|---|---|---|
| Template | `Template工程模板\USER\Template.uvprojx` | 空模板，器件已是 VETx |
| 例1 LED灯 | `例1 LED灯\USER\LED.uvprojx` | PA1 翻转 |
| 例2 按键输入 | `例2 按键输入\USER\KEY.uvprojx` | K0/K1 = PE4/PE3 |
| 例3 串口实验 | `例3 串口实验\USER\USART.uvprojx` | USART1 → PA9/PA10，给 HC-05 |
| 例8 PWM输出 | `例8 PWM输出\USER\PWM.uvprojx` | 改成 PA6 舵机 |
| 例10 OLED显示 | `例10  OLED显示\USER\OLED.uvprojx` | PB6=PB7 I2C |

独立 OLED 例程：`E:\Keil\STM32F407VE\F407VE核心板--  OLED显示例程\USER\OLED.uvprojx`

**所有 29 个工程都已用 `tools/fix_keil_jlink.py` 批量修好**，原文件留有 `.uvprojx.bak` / `.uvoptx.bak`。

---

## 九、硬件侧要点

- **J-Link**：4 针 `VCC / SWDIO / SWCLK / GND`。VCC 先量电压，3.3V 接 3V3，5V 别接。
- **板子供电**：J-Link 的 3.3V 只够调试，不够带舵机；舵机和电机用 5V 充电宝，**GND 必须共地**。
- **电机**：4×AA = 6V，L298N 电源口并 1000µF 防复位；舵机 5V 并 470µF。
- **L298N 接线**：左前+左后红→OUT1、左前+左后黑→OUT2、右前+右后红→OUT3、右前+右后黑→OUT4；IN1→PA0、IN2→PA1、IN3→PA2、IN4→PA3；ENA/ENB 跳线帽要插上。
- **HC-05 底板 6 针 vs 4 针**：4 针（VCC/GND/TXD/RXD）就够，6 针多的 EN/STATE 用不上。**TX/RX 必须交叉**：HC-05 TXD→PA10、RXD→PA9。

---

## 十、遗留问题

- Keil 5.14 + J-Link V9.88 组合可用，但 Keil 较老，Pack Installer 静默安装 `-i` 参数返回退出码 2（需要交互确认协议），本次是手动解压 `.pack`（本质就是 zip）到 `E:\Keil_v5\ARM\PACK\Keil\STM32F4xx_DFP\2.11.0` 完成的。
- 例程工程里 `led.c` 的注释写「LED0 是 GPIOF.9，LED2 是 GPIOF.0」，但代码实际用 PA1，注释与代码不符，以代码为准。
- `delay_us` 在 168MHz 下单次不能超过约 798ms（24 位 SysTick 计数器上限），`delay_ms(500)` 安全。

---

## 十一、Internal DLL Error（2026-10-29 深夜定位，最坑的一个）

### 症状

```
Load "..\OBJ\LED.axf"
Internal DLL Error
Error: Flash Download failed  -  Target DLL has been cancelled
```

### 根因：`<TargetName>` 与 `.uvoptx` 的 `<nTsel>` 绑定

Keil 5.14 的 `.uvoptx` 里 `<nTsel>11</nTsel>` 是**按 TargetName 算出来的索引**。
改 `.uvprojx` 的 `<TargetName>`（例如 `LED` → `BailuCar`）而不同步 `nTsel`，
uVision 就找不到对应的调试器配置，直接报 Internal DLL Error。

**证据链（全部实测）**：

| 实验 | 工程 | uvoptx | 结果 |
|---|---|---|---|
| A | LED 原样 | LED 原样 | ✅ 成功 |
| B | LED 原样改名 TargetName | LED 原样 | ❌ Internal DLL Error |
| C | LED 原样 | LED 原样（换目录） | ✅ 成功 |
| D | LED 原样（换目录） | — | ✅ 成功 |

**结论：不要改 TargetName。** 工程名保持 `LED`，名字难看但能用。

### 第二个坑：`.uvoptx` 文件索引必须与 `.uvprojx` 完全对齐

`.uvoptx` 的文件记录按 `<Group>` 分组存放：

- 分组结构（`<Group>` / `<GroupName>` / `<cbSel>`）不能破坏
- **记录数必须等于 `.uvprojx` 的文件数**——连 `readme.txt`（FileType=2）也要有一条
- 漏一条或分组结构被破坏 → 同样是 Internal DLL Error

### 工具

```powershell
# 重建 .uvoptx 的文件索引（保持 <Group> 分组结构）
python hks	oolsebuild_uvoptx.py "USER\LED.uvprojx" "USER\LED.uvoptx"

# 整工程重建（骨架 + 新文件 + 索引一次到位）
python hks	oolsuild_bailu_project.py --target "<工程目录>"

# 二分定位：逐个加文件，看哪一步开始失败
python hks	oolsisect_keil_dll.py "<可用工程.uvprojx>" "<实验目录>" "<spec.json>"
```

---

## 十二、综合工程：白鹭湾无人车

位置：`firmware/bailu_car/`（仓库内副本）、`E:\Keil\STM32F407VE\...\例26 白鹭无人车综合\`（工作副本）

一个工程跑齐 OLED / 舵机 / 电机 / 按键 / 蓝牙。

| 外设 | 引脚 | 备注 |
|---|---|---|
| OLED (0.96 I2C) | PB6=SCL, PB7=SDA | **I2C 重写版**，见下 |
| SG90 舵机 | PA6 (TIM3_CH1) | 50Hz/20ms，500–2500us |
| L298N 电机 | PA0..PA3 | ENA/ENB 跳线帽插上 |
| 按键 | K0=PE4, K1=PE3 | 低电平按下 |
| HC-05 | PA9/PA10 | USART1 9600，TX/RX 交叉 |

### 卖家 OLED 例程不能直接用

卖家自带的 OLED 驱动是 **4 线软件模拟 SPI**（CS=PB12 / RST=PB14 / RS=PC5 / SCLK=PB13 / SDIN=PB15），
和 4 针 I2C 模块完全不兼容。已重写为软件 I2C 时序 + PB6/PB7。
屏不亮就把 `oled.h` 的 `OLED_I2C_ADDR` 从 `0x78` 改成 `0x7A`。

### 这个 F4 库是精简版

| 标准 ST 库写法 | 本库写法 |
|---|---|
| `GPIO_Mode_AF_PP` | `GPIO_Mode_AF` |
| `GPIO_Mode_IN_FLOATING` | `GPIO_Mode_IN` |
| `GPIO_Speed_50MHz` | `GPIO_Speed_50MHz`（legacy 宏，可用） |
| `I2C_HandleTypeDef` / `I2C_Master_Transmit` | `I2C_InitTypeDef` / `I2C_Init`（F1 风格） |

直接照抄 ST HAL 代码会编译不过。

### 顺带修正的卖家代码问题

- 按键例程用 PA0，但 PA0 是电机 IN1 → 改为 PE4/PE3
- 串口接收复用 `usart.c` 自带的 `USART1_IRQHandler`，main.c 不再重复定义
  （重复定义报 `L6200E: Symbol USART1_IRQHandler multiply defined`）
- 舵机 PWM 从 2kHz 改 50Hz（卖家 PWM 例程是 2kHz，SG90 会抖）

### 编译状态（实测）

```
Program Size: Code=5622 RO-data=6506 RW-data=32 ZI-data=2856
"..\OBJ\LED.axf" - 0 Error(s), 0 Warning(s).
Erase Done.Programming Done.Verify OK.Application running ...
```

寄存器实测（GPIOA_MODER=0xA8282055、GPIOB_MODER=0x00005280）确认 OLED/舵机/电机初始化正确。
