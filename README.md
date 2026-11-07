# 回廊：借来的明天

Godot 4 原型。你在双时态空间站里收集记录、比对证据，躲过追债人的清算。

## 运行

Windows 上安装 Godot 4 和 Python 3 后，双击 `Play.cmd`。启动器会在首次运行时导入贴图，并启动本机 Python 存档服务。它通过桌面的 `Godot.lnk` 或系统 `PATH` 查找 Godot，也可以将 `GODOT_EXE` 环境变量设为 Godot 可执行文件的绝对路径。

也可以在 Godot 中打开 `project.godot`，按 F5 试玩。直接在编辑器内运行时，如果后端未启动，会使用本地存档。

WASD 移动，鼠标环视，Shift 奔跑，E 交互，F 眩晕。左上角的小地图随视角旋转，白色箭头标出你的位置和前进方向。M 原位切换晨区和暮区预览，Esc 返回或暂停。调查台会显示任务签收状态；第 01 章需要在证据工作台选中 V-17 与 #043 后按 Enter 核验，不能再用旧的单项选择直接跳过。地图中的 G-01/G-02 和场景箭头用于提示回程。六道谜题的完整解法见《谜题答案.md》。

序幕和舷窗使用参考项目《逐光计划》中的地球和云层贴图。参考项目将纹理来源标注为 [Three.js 示例](https://threejs.org/examples/textures/planets/)。

带着暮区的关键证据回到调查台，才能写入审计匣。轮回次数、章节、已保存的证据和通关状态保存在本机，联网到本机服务时同步到 `backend/data/players.sqlite3`。

## 配置 DeepSeek

在项目目录打开 PowerShell，运行下面的命令，然后在隐藏输入提示中填入新密钥。密钥使用 Windows 当前账户加密保存，之后双击 `Play.cmd` 即可。

```powershell
.\Play.cmd -ConfigureDeepSeek
```

后端在追逐后的复位阶段请求 `deepseek-flash`，仅发送追债人的门禁观测次数和奔跑听觉标记。模型返回预设战术和换相门编号。未配置密钥或调用失败时由本地规则接管。HUD 出现 `追债策略 / DeepSeek` 表示本轮已采用模型结果。
## 本轮核心体验更新

- A-01 调查台会随待签收、已签收、已复核状态变化，桌面增加电脑支架、键盘、A-42 授权单和审计文件夹位置。
- 第 01 章“同一扇门”改为晨暮证据身份对齐：选择门禁 V-17 与警报 #043；钟面时间是误导项。错误或缺证据不会推进章节。
- G-01/G-02、A-01 等地标在场景和小地图中保持同一编号；实际回程方向由现有网格与 A* 路径计算，不额外改变地图拓扑。
- 自动化回归：tests/core_loop_test.gd、tests/map_routes_test.gd、tests/visual_check.gd。测试使用内存存档，不读取真实玩家存档或后端。

## P0 音效

已接入本地 Sonniss GDC 素材剪辑：走路/奔跑脚步、追债人空间脚步与冲刺预警、取证/归档/核验成败、晨暮换相提示。提示音使用独立固定音源，不再每次即时生成正弦波。脚步按实际地面位移触发；顶墙、暂停、轮回复位和追债人跨时态时不会残留脚步。空间声音有距离衰减，当前不模拟墙体隔声。

音源、裁切参数与附带许可记录在 assets/audio/sources.json 和 assets/audio/SONNISS-LICENSE.pdf；未向 AI 服务上传这些录音。音乐和配音尚未加入。建议戴耳机体验方向感，并在现场电脑调整系统音量。

音效检查（Godot 4.3）：`--headless --path 项目目录 --script res://tests/audio_test.gd`；左右声道与距离衰减检查：`--path 项目目录 --rendering-method gl_compatibility --script res://tests/audio_spatial_check.gd`，后者需要真实音频驱动。
