#include "motor.h"
#include "delay.h"

/* PA0=IN1, PA1=IN2, PA2=IN3, PA3=IN4 */
#define IN1   GPIO_Pin_0
#define IN2   GPIO_Pin_1
#define IN3   GPIO_Pin_2
#define IN4   GPIO_Pin_3

void Motor_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStructure;

    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);

    GPIO_InitStructure.GPIO_Pin = IN1 | IN2 | IN3 | IN4;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;
    GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
    GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;
    GPIO_Init(GPIOA, &GPIO_InitStructure);

    Motor_Stop();
}

/* 左轮 IN1=1,IN2=0 → 正转；右轮 IN3=1,IN4=0 → 正转 */
void Motor_Forward(void)
{
    GPIO_SetBits(GPIOA, IN1 | IN3);
    GPIO_ResetBits(GPIOA, IN2 | IN4);
}

void Motor_Backward(void)
{
    GPIO_ResetBits(GPIOA, IN1 | IN3);
    GPIO_SetBits(GPIOA, IN2 | IN4);
}

/* 原地左转：左轮后退、右轮前进 */
void Motor_TurnLeft(void)
{
    GPIO_ResetBits(GPIOA, IN1);
    GPIO_SetBits(GPIOA, IN2);
    GPIO_SetBits(GPIOA, IN3);
    GPIO_ResetBits(GPIOA, IN4);
}

/* 原地右转：左轮前进、右轮后退 */
void Motor_TurnRight(void)
{
    GPIO_SetBits(GPIOA, IN1);
    GPIO_ResetBits(GPIOA, IN2);
    GPIO_ResetBits(GPIOA, IN3);
    GPIO_SetBits(GPIOA, IN4);
}

void Motor_Stop(void)
{
    GPIO_ResetBits(GPIOA, IN1 | IN2 | IN3 | IN4);
}

void Motor_Drive(u32 ms)
{
    Motor_Forward();
    delay_ms(ms);
    Motor_Stop();
}
