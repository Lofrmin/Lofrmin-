# P0 sound effects

Selected and locally edited from the team-provided Sonniss GDC 2026 bundle. Original library is untouched. See sources.json for supplier paths, source SHA-256, offsets and filters; SONNISS-LICENSE.pdf is the included source license.

TheWorkRoom / Flip Flops supplies two edited dry footfalls (not a boot recording); InMotionAudio / Instrument Case supplies the hunter impact, pitched down in engine. Cinematic Sound Design supplies UI cues, Federico Soler supplies the short charge warning, Epic Stock Media supplies the deployment servo.

No recordings were uploaded to generation services or used as AI training/reference material. These are game-incorporated effects, not a sound library for redistribution. Keep supplier rights and the included license when distributing the game. Suno music is out of this P0 scope.

Runtime: fixed separate UI players; hunter step/deployment/warning originate at the hunter. Mono spatial clips use a maximum audible range of 18m. There is distance attenuation but no wall occlusion in this jam build. Headphones are recommended for tuning direction, distance and loudness.


## 追击循环音（原创合成）

`chase_loop.wav` 是本项目原创程序合成的低频双心跳、柔和短击与极轻空气噪声循环，约 9.6 秒；不包含采样、重制或仿制任何商业游戏音轨，也未上传到外部生成服务。它由独立循环播放器按威胁值缓入、缓出，不与单次提示音抢播。一次性提示（警告、脚步、确认）仍优先清晰可闻。
