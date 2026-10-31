#include "key.h"
#include "delay.h"

/* PE4 = K0, PE3 = K1，均为低电平按下，板载 10K 上拉 */
void KEY_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStructure;

    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOE, ENABLE);

    GPIO_InitStructure.GPIO_Pin = KEY0_Pin | KEY1_Pin;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
    GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;
    GPIO_Init(GPIOE, &GPIO_InitStructure);
}

u8 KEY_Scan(u8 mode)
{
    static u8 key_up = 1;   /* 1=上次松开 */

    if (mode) key_up = 1;

    if (key_up && KEY0_READ == 0)
    {
        delay_ms(10);                      /* 消抖 */
        key_up = 0;
        if (KEY0_READ == 0) return KEY0_PRES;
    }
    else if (KEY0_READ == 1) key_up = 1;

    if (key_up && KEY1_READ == 0)
    {
        delay_ms(10);
        key_up = 0;
        if (KEY1_READ == 0) return KEY1_PRES;
    }
    else if (KEY1_READ == 1) key_up = 1;

    return 0;
}
