#ifndef __SERVO_H
#define __SERVO_H
#include "sys.h"

/* SG90 舵机 —— TIM3_CH1 = PA6（复用 PWM 例程的引脚）
 * 周期 20ms，脉宽 500us(0°) ~ 2500us(180°)
 * 舵机供电必须 5V，且与 STM32 共地；不要从 3.3V 供电。 */

void TIM3_PWM_Init(u32 arr, u32 psc);
void Servo_SetUs(u32 pulse_us);      /* 单次设定脉宽 */
void Servo_SetAngle(u8 angle);        /* 0~180 度 */
void Servo_OpenHatch(void);           /* 开舱：转到 90 度再回来 */
void Servo_CloseHatch(void);

#endif
