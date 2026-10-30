#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"
#include "oled.h"
#include "servo.h"
#include "motor.h"
#include "key.h"

/* ============================================================
 * 白鹭湾无人车综合演示 —— STM32F407VET6
 *
 * 硬件：
 *   OLED  I2C（软件时序） PB6=SCL PB7=SDA   （4 针 I2C 模块，地址 0x3C）
 *   舵机   TIM3_CH1 = PA6                   （SG90，5V 供电，共地）
 *   电机   L298N  IN1..IN4 = PA0..PA3       （ENA/ENB 跳线帽插上）
 *   按键   K0 = PE4, K1 = PE3               （低电平按下）
 *   蓝牙   HC-05 底板 → PA9(TX)/PA10(RX)   （USART1，9600）
 *
 * 触发方式（效果相同）：
 *   1. 按 K0 键
 *   2. 手机蓝牙串口助手发 'G'
 *   3. 上位机（咖啡网关）通过串口发 'G'
 *
 * 串口接收复用 usart.c 自带的 USART1_IRQHandler 与接收缓冲。
 * ============================================================ */

static volatile u8 g_car_running;   /* 配送流程进行中 */

/* 从 usart.c 的接收缓冲里取一个字符；没有则返回 0 */
static char BT_GetChar(void)
{
    char c = 0;
    if (USART_RX_STA & 0x8000)          /* 收到一帧 */
    {
        u16 len = USART_RX_STA & 0x3FFF;
        if (len > 0)
        {
            c = USART_RX_BUF[0];
            u16 i;
            for (i = 1; i < len; i++) USART_RX_BUF[i - 1] = USART_RX_BUF[i];
            USART_RX_STA = (len - 1) & 0x3FFF;
        }
    }
    return c;
}

static void ShowText(u8 line, const char *s)
{
    OLED_ShowString(0, line * 16, (const u8 *)s, 16);
    OLED_Refresh_Gram();
}

/* 收到订单后的完整流程：屏幕提示 → 发车 → 开舱 → 取餐提示 */
static void Delivery_Start(const char *code)
{
    if (g_car_running) return;
    g_car_running = 1;

    OLED_Clear();
    ShowText(0, "BAILU COFFEE");
    ShowText(1, "PICKUP CODE:");
    OLED_ShowString(0, 32, (const u8 *)code, 24);
    OLED_Refresh_Gram();

    delay_ms(500);

    /* 无人车出发：四轮前进 1.5 秒 */
    Motor_Drive(1500);

    /* 到站开舱 */
    Servo_OpenHatch();
    OLED_Clear();
    ShowText(0, "ARRIVED");
    ShowText(1, "PLEASE TAKE IT");
    OLED_ShowString(0, 40, (const u8 *)code, 24);
    OLED_Refresh_Gram();

    delay_ms(3000);

    Servo_CloseHatch();
    OLED_Clear();
    ShowText(0, "THANKS");
    ShowText(1, "SEE YOU");
    OLED_Refresh_Gram();

    delay_ms(1000);
    g_car_running = 0;
}

int main(void)
{
    char ch;

    NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);

    delay_init(168);
    uart_init(9600);           /* USART1 = PA9/PA10，接 HC-05 */

    LED_Init();
    KEY_Init();
    Motor_Init();

    /* TIM3: 1MHz 计数，arr=20000-1 → 50Hz，脉宽单位 1us */
    TIM3_PWM_Init(20000 - 1, 84 - 1);
    Servo_SetAngle(0);

    OLED_Init();
    OLED_Clear();
    ShowText(0, "BAILU CAR READY");
    ShowText(1, "PRESS K0 OR SEND G");
    OLED_Refresh_Gram();

    printf("\r\n Bailu car ready. Press K0 or send 'G' over BT.\r\n");

    while (1)
    {
        /* 1. 按键触发（K0 = PE4） */
        if (KEY_Scan(0) == KEY0_PRES)
        {
            printf("\r\n[TRIGGER] key\r\n");
            Delivery_Start("A888");
        }

        /* 2. 蓝牙 / 上位机触发 */
        ch = BT_GetChar();
        if (ch == 'G' || ch == 'g')
        {
            printf("\r\n[TRIGGER] %c\r\n", ch);
            Delivery_Start("A888");
        }

        LED2 = !LED2;
        delay_ms(200);
    }
}
