#include "servo.h"
#include "delay.h"

/* TIM3_CH1 → PA6，复用卖家 PWM 例程的初始化方式
 * TIM3 时钟 84MHz，psc=84-1 → 计数频率 1MHz，arr=500-1 → PWM 频率 2kHz
 * 对 SG90 来说 2kHz 太快，这里改成 arr=20000-1 → 50Hz(20ms 周期)，
 * 脉宽用 CCR1 表示微秒数（1MHz 计数下 1 个计数 = 1us）。 */
void TIM3_PWM_Init(u32 arr, u32 psc)
{
    GPIO_InitTypeDef GPIO_InitStructure;
    TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
    TIM_OCInitTypeDef TIM_OCInitStructure;

    RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM3, ENABLE);
    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);

    GPIO_PinAFConfig(GPIOA, GPIO_PinSource6, GPIO_AF_TIM3);

    GPIO_InitStructure.GPIO_Pin = GPIO_Pin_6;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
    GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
    GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;
    GPIO_Init(GPIOA, &GPIO_InitStructure);

    TIM_TimeBaseStructure.TIM_Prescaler = psc;
    TIM_TimeBaseStructure.TIM_CounterMode = TIM_CounterMode_Up;
    TIM_TimeBaseStructure.TIM_Period = arr;
    TIM_TimeBaseStructure.TIM_ClockDivision = TIM_CKD_DIV1;
    TIM_TimeBaseInit(TIM3, &TIM_TimeBaseStructure);

    TIM_OCInitStructure.TIM_OCMode = TIM_OCMode_PWM1;
    TIM_OCInitStructure.TIM_OutputState = TIM_OutputState_Enable;
    TIM_OCInitStructure.TIM_OCPolarity = TIM_OCPolarity_High;
    TIM_OCInitStructure.TIM_OCNPolarity = TIM_OCNPolarity_High;
    TIM_OCInitStructure.TIM_OCIdleState = TIM_OCIdleState_Reset;
    TIM_OCInitStructure.TIM_OCNIdleState = TIM_OCNIdleState_Reset;
    TIM_OC1Init(TIM3, &TIM_OCInitStructure);

    TIM_OC1PreloadConfig(TIM3, TIM_OCPreload_Enable);
    TIM_ARRPreloadConfig(TIM3, ENABLE);
    TIM_Cmd(TIM3, ENABLE);
}

void Servo_SetUs(u32 pulse_us)
{
    if (pulse_us < 500)  pulse_us = 500;
    if (pulse_us > 2500) pulse_us = 2500;
    TIM_SetCompare1(TIM3, pulse_us);
}

void Servo_SetAngle(u8 angle)
{
    if (angle > 180) angle = 180;
    /* 500us = 0°，2500us = 180° */
    Servo_SetUs(500 + (u32)angle * (2000 / 180));
}

void Servo_OpenHatch(void)
{
    Servo_SetAngle(90);
    delay_ms(600);
}

void Servo_CloseHatch(void)
{
    Servo_SetAngle(0);
    delay_ms(600);
}
