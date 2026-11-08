extends RefCounted

# World-space tasks never change game mode: movement and the hunter keep running.
var active := false
var kind := ""
var anchor := Vector2i.ZERO
var task_phase := 0
var selection := 0
var switches := [false, false, false]
var dials := [0, 0, 0]
var targets := [2, 5, 7]
var sequence := [0, 2, 1]
var progress := 0
var hold := 0.0
var remaining := 3.0
var message := ""

func begin(task: String, tile: Vector2i, phase: int) -> void:
	active = true
	kind = task
	anchor = tile
	task_phase = phase
	selection = 0
	switches = [false, false, false]
	dials = [0, 0, 0]
	targets = [2, 5, 7] if phase == 0 else [6, 1, 4]
	progress = 0
	hold = 0.0
	remaining = 3.0
	message = ""

func lamps() -> Array:
	return [switches[0] != switches[1], switches[1] != switches[2], switches[0]]

func press(key: Key) -> bool:
	if not active:
		return false
	var index := int(key) - int(KEY_1)
	match kind:
		"circuit":
			if index in [0, 1, 2]:
				switches[index] = not switches[index]
			if key in [KEY_ENTER, KEY_E]:
				if not lamps().has(false):
					return true
				message = "三路指示灯必须同时亮起。支路会影响不止一盏灯。"
		"clock":
			if index in [0, 1, 2]:
				selection = index
			if key in [KEY_LEFT, KEY_RIGHT]:
				dials[selection] = posmod(dials[selection] + (1 if key == KEY_RIGHT else -1), 8)
			if key in [KEY_ENTER, KEY_E]:
				if dials == targets:
					return true
				message = "三个指针都要落在各自的空心刻度上。"
		"relay":
			if index in [0, 1, 2]:
				if index == sequence[progress]:
					progress += 1
					if progress == sequence.size():
						return true
				else:
					progress = 0
					remaining = 3.0
					message = "接线顺序错误，已断开。按晨区铭牌顺序重接。"
	return false

func tick(delta: float, quiet_hold: bool) -> bool:
	if not active:
		return false
	if kind == "silent":
		hold = minf(1.8, hold + delta) if quiet_hold else 0.0
		return hold >= 1.8
	if kind == "relay" and progress > 0:
		remaining -= delta
		if remaining <= 0.0:
			progress = 0
			remaining = 3.0
			message = "接线窗口超时。重新开始三步接线。"
	return false

func title() -> String:
	match kind:
		"circuit": return "B-17 / 门禁旁路"
		"clock": return "C-04 / 同步时钟校准"
		"silent": return "B-17 / 静音读取"
		_: return "E-7 / 限时接线"

func instructions() -> String:
	match kind:
		"circuit": return "1 / 2 / 3 切换支路 · 三灯全亮后 Enter 提交"
		"clock": return "1 / 2 / 3 选指针 · ← / → 转动 · Enter 提交"
		"silent": return "站稳，持续按住 E 1.8 秒；移动或奔跑会清空进度"
		_: return "晨区铭牌：① → ③ → ②；三步须在 3 秒内完成"
