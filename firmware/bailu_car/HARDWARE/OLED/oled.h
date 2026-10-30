#ifndef __OLED_H
#define __OLED_H
#include "sys.h"
#include "stdlib.h"

/* 0.96 寸 SSD1306 —— I2C 模式（4 针模块：GND / VCC / SCL / SDA）
 *
 * 注意：卖家例程自带的 OLED 驱动是「4 线软件模拟 SPI」，引脚为
 *   CS=PB12  RST=PB14  RS=PC5  SCLK=PB13  SDIN=PB15
 * 与 4 针 I2C 模块不兼容。本驱动为 I2C 重写版，用软件时序，不依赖
 * 芯片 I2C 外设配置。
 *
 * 引脚：PB6 = SCL, PB7 = SDA
 * 地址：0x78（7 位地址 0x3C 左移一位）；不亮就改成 0x7A（0x3D）
 */

#define OLED_I2C_ADDR   0x78

#define OLED_SCL_Pin    GPIO_Pin_6
#define OLED_SDA_Pin    GPIO_Pin_7
#define OLED_SCL        PBout(6)
#define OLED_SDA        PBout(7)

#define OLED_CMD   0
#define OLED_DATA  1

void OLED_Init(void);
void OLED_Clear(void);
void OLED_Refresh_Gram(void);
void OLED_WR_Byte(u8 dat, u8 cmd);
void OLED_Display_On(void);
void OLED_Display_Off(void);
void OLED_DrawPoint(u8 x, u8 y, u8 t);
void OLED_Fill(u8 x1, u8 y1, u8 x2, u8 y2, u8 dot);
void OLED_ShowChar(u8 x, u8 y, u8 chr, u8 size, u8 mode);
void OLED_ShowNum(u8 x, u8 y, u32 num, u8 len, u8 size);
void OLED_ShowString(u8 x, u8 y, const u8 *p, u8 size);
void OLED_ShowStringAt(u8 x, u8 y, const u8 *p, u8 size, u8 mode);

#endif
