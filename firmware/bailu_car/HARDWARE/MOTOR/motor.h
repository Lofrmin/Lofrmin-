#ifndef __MOTOR_H
#define __MOTOR_H
#include "sys.h"

/* L298N 直流电机驱动 —— 纯 GPIO 开关模式（不用 PWM）
 * IN1 → PA0, IN2 → PA1  控制左侧（OUT1/OUT2）
 * IN3 → PA2, IN4 → PA3  控制右侧（OUT3/OUT4）
 * L298N 的 ENA/ENB 跳线帽必须插上（常满速）。
 * 电机供电：4×AA → L298N +12V，务必与 STM32 共地。 */

void Motor_Init(void);
void Motor_Forward(void);
void Motor_Backward(void);
void Motor_TurnLeft(void);
void Motor_TurnRight(void);
void Motor_Stop(void);
void Motor_Drive(u32 ms);      /* 前进 ms 毫秒后自动停 */

#endif
