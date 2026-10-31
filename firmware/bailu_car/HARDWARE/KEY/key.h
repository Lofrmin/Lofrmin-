#ifndef __KEY_H
#define __KEY_H
#include "sys.h"

/* STM32F407VET6 黑板板载按键
 *   K0 → PE4（低电平按下，内部上拉）
 *   K1 → PE3（低电平按下，内部上拉）
 *   K-UP → PA0（高电平按下）—— 本工程 PA0 已被电机 IN1 占用，故不使用
 * 注意：卖家例程的 key.c 用的是 PA0(K1)，与电机 IN1 冲突，这里改为 PE4/PE3。 */

#define KEY0_Pin   GPIO_Pin_4   /* PE4 */
#define KEY1_Pin   GPIO_Pin_3   /* PE3 */
#define KEY0_READ  GPIO_ReadInputDataBit(GPIOE, KEY0_Pin)
#define KEY1_READ  GPIO_ReadInputDataBit(GPIOE, KEY1_Pin)

#define KEY0_PRES  1
#define KEY1_PRES  2

void    KEY_Init(void);
u8      KEY_Scan(u8 mode);   /* mode: 0 不连续，1 连续；返回 KEY0_PRES/KEY1_PRES/0 */

#endif
