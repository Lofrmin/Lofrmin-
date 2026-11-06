# 回廊：借来的明天

Godot 4 原型。你在双时态空间站里收集记录、比对证据，躲过追债人的清算。

## 运行

Windows 上安装 Godot 4 和 Python 3 后，双击 `Play.cmd`。启动器会在首次运行时导入贴图，并启动本机 Python 存档服务。它通过桌面的 `Godot.lnk` 或系统 `PATH` 查找 Godot，也可以将 `GODOT_EXE` 环境变量设为 Godot 可执行文件的绝对路径。

也可以在 Godot 中打开 `project.godot`，按 F5 试玩。直接在编辑器内运行时，如果后端未启动，会使用本地存档。

WASD 移动，鼠标环视，Shift 奔跑，E 交互，F 眩晕。左上角的小地图随视角旋转，白色箭头标出你的位置和前进方向。M 原位切换晨区和暮区预览，Esc 返回或暂停。调查台可以用鼠标选择推理结论。六道谜题的完整解法见《谜题答案.md》。

序幕和舷窗使用参考项目《逐光计划》中的地球和云层贴图。参考项目将纹理来源标注为 [Three.js 示例](https://threejs.org/examples/textures/planets/)。

带着暮区的关键证据回到调查台，才能写入审计匣。轮回次数、章节、已保存的证据和通关状态保存在本机，联网到本机服务时同步到 `backend/data/players.sqlite3`。

## 配置 DeepSeek

在项目目录打开 PowerShell，运行下面的命令，然后在隐藏输入提示中填入新密钥。密钥使用 Windows 当前账户加密保存，之后双击 `Play.cmd` 即可。

```powershell
.\Play.cmd -ConfigureDeepSeek
```

后端在追逐后的复位阶段请求 `deepseek-flash`，仅发送追债人的门禁观测次数和奔跑听觉标记。模型返回预设战术和换相门编号。未配置密钥或调用失败时由本地规则接管。HUD 出现 `追债策略 / DeepSeek` 表示本轮已采用模型结果。
