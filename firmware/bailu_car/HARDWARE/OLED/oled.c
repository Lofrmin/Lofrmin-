#include "oled.h"
#include "stdlib.h"
#include "oledfont.h"
#include "delay.h"

/* 0.96 寸 SSD1306 —— I2C 模式驱动（软件 I2C 时序）
 * PB6 = SCL, PB7 = SDA
 * 显示缓存：128 列 × 8 页 */
u8 OLED_GRAM[128][8];

#define OLED_I2C_DLY()  delay_us(5)

static void I2C_Start(void)
{
    OLED_SDA = 1;
    OLED_SCL = 1;
    OLED_I2C_DLY();
    OLED_SDA = 0;
    OLED_I2C_DLY();
    OLED_SCL = 0;
    OLED_I2C_DLY();
}

static void I2C_Stop(void)
{
    OLED_SDA = 0;
    OLED_SCL = 1;
    OLED_I2C_DLY();
    OLED_SDA = 1;
    OLED_I2C_DLY();
    OLED_SCL = 1;
}

static void I2C_WriteByte(u8 dat)
{
    u8 i;
    for (i = 0; i < 8; i++)
    {
        OLED_SCL = 0;
        if (dat & 0x80) OLED_SDA = 1; else OLED_SDA = 0;
        OLED_I2C_DLY();
        OLED_SCL = 1;
        OLED_I2C_DLY();
        dat <<= 1;
    }
    OLED_SCL = 0;
    /* 第 9 个时钟：ACK */
    OLED_SDA = 1;
    OLED_I2C_DLY();
    OLED_SCL = 1;
    OLED_I2C_DLY();
    OLED_SCL = 0;
    OLED_I2C_DLY();
}

/* 写命令或数据（SSD1306 控制字节：0x00 = 命令，0x40 = 数据） */
void OLED_WR_Byte(u8 dat, u8 cmd)
{
    I2C_Start();
    I2C_WriteByte(OLED_I2C_ADDR);
    I2C_WriteByte(cmd ? 0x40 : 0x00);
    I2C_WriteByte(dat);
    I2C_Stop();
}

void OLED_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStructure;

    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB, ENABLE);

    GPIO_InitStructure.GPIO_Pin = OLED_SCL_Pin | OLED_SDA_Pin;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;
    GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
    GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;
    GPIO_Init(GPIOB, &GPIO_InitStructure);

    OLED_SCL = 1;
    OLED_SDA = 1;
    delay_ms(100);

    OLED_WR_Byte(0xAE, OLED_CMD);   /* 显示关闭 */
    OLED_WR_Byte(0x20, OLED_CMD);   /* 内存寻址模式 */
    OLED_WR_Byte(0x00, OLED_CMD);   /* 水平寻址 */
    OLED_WR_Byte(0xB0, OLED_CMD);   /* 页起始地址 */
    OLED_WR_Byte(0xC8, OLED_CMD);   /* COM 扫描方向 */
    OLED_WR_Byte(0x00, OLED_CMD);   /* 低列起始地址 */
    OLED_WR_Byte(0x10, OLED_CMD);   /* 高列起始地址 */
    OLED_WR_Byte(0x40, OLED_CMD);   /* 行起始地址 */
    OLED_WR_Byte(0x81, OLED_CMD);   /* 对比度 */
    OLED_WR_Byte(0xFF, OLED_CMD);
    OLED_WR_Byte(0xA1, OLED_CMD);   /* 段重映射 */
    OLED_WR_Byte(0xA6, OLED_CMD);   /* 正常显示 */
    OLED_WR_Byte(0xA8, OLED_CMD);   /* 多路复用比 */
    OLED_WR_Byte(0x3F, OLED_CMD);
    OLED_WR_Byte(0xA4, OLED_CMD);   /* 全局显示开 */
    OLED_WR_Byte(0xD3, OLED_CMD);   /* 显示偏移 */
    OLED_WR_Byte(0x00, OLED_CMD);
    OLED_WR_Byte(0xD5, OLED_CMD);   /* 显示时钟 */
    OLED_WR_Byte(0x80, OLED_CMD);
    OLED_WR_Byte(0xD9, OLED_CMD);   /* 预充电 */
    OLED_WR_Byte(0xF1, OLED_CMD);
    OLED_WR_Byte(0xDA, OLED_CMD);   /* COM 引脚配置 */
    OLED_WR_Byte(0x12, OLED_CMD);
    OLED_WR_Byte(0xDB, OLED_CMD);   /* VCOMH */
    OLED_WR_Byte(0x40, OLED_CMD);
    OLED_WR_Byte(0x8D, OLED_CMD);   /* 电荷泵 */
    OLED_WR_Byte(0x14, OLED_CMD);
    OLED_WR_Byte(0xAF, OLED_CMD);   /* 显示开启 */

    OLED_Clear();
}

void OLED_Refresh_Gram(void)
{
    u8 i, n;
    for (i = 0; i < 8; i++)
    {
        OLED_WR_Byte(0xB0 + i, OLED_CMD);
        OLED_WR_Byte(0x00, OLED_CMD);
        OLED_WR_Byte(0x10, OLED_CMD);
        for (n = 0; n < 128; n++) OLED_WR_Byte(OLED_GRAM[n][i], OLED_DATA);
    }
}

void OLED_Display_On(void)
{
    OLED_WR_Byte(0x8D, OLED_CMD);
    OLED_WR_Byte(0x14, OLED_CMD);
    OLED_WR_Byte(0xAF, OLED_CMD);
}

void OLED_Display_Off(void)
{
    OLED_WR_Byte(0x8D, OLED_CMD);
    OLED_WR_Byte(0x10, OLED_CMD);
    OLED_WR_Byte(0xAE, OLED_CMD);
}

void OLED_Clear(void)
{
    u8 i, n;
    for (i = 0; i < 8; i++)
        for (n = 0; n < 128; n++) OLED_GRAM[n][i] = 0x00;
    OLED_Refresh_Gram();
}

void OLED_DrawPoint(u8 x, u8 y, u8 t)
{
    u8 pos, bx, temp = 0;
    if (x > 127 || y > 63) return;
    pos = 7 - y / 8;
    bx = y % 8;
    temp = 1 << (7 - bx);
    if (t) OLED_GRAM[x][pos] |= temp;
    else   OLED_GRAM[x][pos] &= ~temp;
}

void OLED_Fill(u8 x1, u8 y1, u8 x2, u8 y2, u8 dot)
{
    u8 x, y;
    for (x = x1; x <= x2; x++)
        for (y = y1; y <= y2; y++) OLED_DrawPoint(x, y, dot);
    OLED_Refresh_Gram();
}

void OLED_ShowChar(u8 x, u8 y, u8 chr, u8 size, u8 mode)
{
    u8 temp, t, t1;
    u8 y0 = y;
    u8 csize = (size / 8 + ((size % 8) ? 1 : 0)) * (size / 2);
    chr = chr - ' ';
    if (chr > 94) chr = 0;

    for (t = 0; t < csize; t++)
    {
        if (size == 12)      temp = asc2_1206[chr][t];
        else if (size == 16) temp = asc2_1608[chr][t];
        else if (size == 24) temp = asc2_2412[chr][t];
        else return;

        for (t1 = 0; t1 < 8; t1++)
        {
            if (temp & 0x80) OLED_DrawPoint(x, y, mode);
            else            OLED_DrawPoint(x, y, 1 - mode);
            temp <<= 1;
        }
        y++;
        if (y > y0 + size - 1)
        {
            y = y0;
            x += size / 2;
        }
    }
}

void OLED_ShowNum(u8 x, u8 y, u32 num, u8 len, u8 size)
{
    u8 t;
    for (t = 0; t < len; t++)
    {
        OLED_ShowChar(x + ((size / 2) + 1) * (len - t - 1), y, num / (10 ^ t) % 10 + '0', size, 1);
    }
}

void OLED_ShowString(u8 x, u8 y, const u8 *p, u8 size)
{
    OLED_ShowStringAt(x, y, p, size, 0);
}

void OLED_ShowStringAt(u8 x, u8 y, const u8 *p, u8 size, u8 mode)
{
    while (*p != '\0')
    {
        OLED_ShowChar(x, y, *p, size, mode);
        x += size / 2;
        p++;
    }
    OLED_Refresh_Gram();
}
