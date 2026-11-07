extends Node3D

const Station := preload("res://station.gd")
const Interface := preload("res://interface.gd")
const Profile := preload("res://profile.gd")
const Exterior := preload("res://exterior.gd")
const CHAPTERS := ["01 / 同一扇门", "03 / 谁签了字", "05 / 站外回执", "02 / 先发生的事", "04 / 借出去的明天"]
const NEXT_CHAPTER := [3, 4, -1, 1, 2]
const RECORDS := [
	["晨区 B-17  门禁 V-17 / 警报 #043 / 09:00:01", "暮区 B-17  门禁 V-17 / 警报 #043 / 16:42:26", "遗书：下次接到任务时，先别按确认。"],
	["晨区中继  管理层受益账户 / 授权 A-42", "调查台  确认接案 → 第三方复核 / 授权 A-42", "林岑：用事故前的求救线路。调度台网络归他们管。"],
	["晨区 R-03  开关标记 E-7 / 线路图到此中断", "暮区 R-03  墙内线缆 E-7 / 指向站外中继", "审计匣  死亡凭证与扣款授权已核验。"],
	["晨区 C-04  寻人立案 / 同步脉冲后 6 秒", "暮区 C-04  扣款名单预登记 / 同步脉冲后 5000 秒", "同步规程  脉冲时两边计时归零 / 晨暮 1:1000"],
	["暮区 D-09  林岑寿命账户 / X-71 / -38 年", "晨区 L-06  管理层受益账户 / X-71 / +38 年", "暮区 L-06  总账存于站外镜像 / 已交割历史不会复位"],
]
const QUESTIONS := ["两次记录如何对齐？", "谁批准拨付，谁触发了执行？", "哪条线路能把账本送到站外？", "换成晨区时间，哪件事先发生？", "复位之后，X-71 的 38 年去哪了？"]
const CHOICES := [
	["以显示的时刻排序。两份记录相隔七小时。", "以门禁 V-17 的警报 #043 对齐。两处是同一间办公室。", "以区名分开存档。两个 B-17 毫无关联。"],
	["调查员批准拨付，林岑亲手触发执行。", "林岑自己申请拨付，管理层只负责找人。", "管理层批准拨付，调查员的接案操作触发执行。"],
	["晨区开启 E-7，暮区接上同编号线缆。", "从晨区调度网络直接上传。", "仅在暮区使用损坏的开关。"],
	["扣款名单先登记。暮区 5000 秒相当于晨区 5 秒。", "寻人先立案。6 小于 5000。", "两件事同时发生，因为都由同一次脉冲触发。"],
	["回到林岑账户，因为站内人员已复位。", "仍归管理层账户。站外总账保留了同一笔交易。", "从两边账户一起消失，因为两份账相加为零。"],
]
const ANSWERS := [1, 2, 0, 0, 1]

var station: Node3D
var player: CharacterBody3D
var camera: Camera3D
var interface: Control
var profile: Node
var exterior: Node3D
var boss: Node3D
var boss_rig: Node3D
var boss_eye: MeshInstance3D
var mode := "intro"
var phase := 0
var map_phase := 0
var chapter := 0
var laps := 1
var intro_time := 0.0
var note_timer := 0.0
var notice := ""
var charges := 2
var threat := 0.0
var case_accepted := false
var cleared := false
var evidence: Array = [false, false, false]
var alignment_fields: Array[String] = []
var unbanked := false
var solved := false
var armed := false
var patched := false
var upload := 0.0
var keypad_entry := ""
var shift_cooldown := 0.0
var time_in_lap := 0.0
var boss_live := false
var boss_phase := 0
var boss_delay := 0.0
var stunned := 0.0
var charge_warning := 0.0
var charge_time := 0.0
var charge_recovery := 0.0
var path_timer := 0.0
var tracking_time := 0.0
var patrol_index := 0
var boss_route: Array[Vector2i] = []
var last_known := Vector2i(4, 3)
var cross_gate := Vector2i(1, 3)
var gate_observed := [0, 0]
var sprint_observed := 0
var tactic := "patrol"
var tactic_gate := 0
var tactic_source := "rules"
var audio: AudioStreamPlayer
var optics: ShaderMaterial


func _ready() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://orbit_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5dde1")
	env.ambient_light_energy = 0.49
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.12
	env.ssao_intensity = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.24
	env.glow_bloom = 0.02
	env_node.environment = env
	add_child(env_node)
	station = Station.new()
	add_child(station)
	station.build()
	exterior = Exterior.new()
	add_child(exterior)
	exterior.build(env)
	build_player()
	build_boss()
	var post_layer := CanvasLayer.new()
	post_layer.layer = 0
	add_child(post_layer)
	var post := ColorRect.new()
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	optics = ShaderMaterial.new()
	optics.shader = preload("res://optics.gdshader")
	post.material = optics
	post_layer.add_child(post)
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	interface = Interface.new()
	interface.game = self
	canvas.add_child(interface)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -13
	add_child(audio)
	profile = Profile.new()
	add_child(profile)
	profile.loaded.connect(apply_profile)
	profile.tactic_ready.connect(apply_tactic)
	profile.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func build_player() -> void:
	player = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.67
	capsule.radius = 0.30
	shape.shape = capsule
	shape.position.y = 0.86
	player.add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.56
	camera.fov = 78
	camera.near = 0.035
	player.add_child(camera)
	add_child(player)
	player.position = station.point(station.AUDIT) + Vector3.UP * 0.05


func build_boss() -> void:
	boss = Node3D.new()
	add_child(boss)
	boss_rig = Node3D.new()
	boss.add_child(boss_rig)
	var shell: Material = station.palette.frame
	var armor: Material = station.palette.wall
	station.box(boss_rig, Vector3(0, 1.50, 0), Vector3(0.66, 0.75, 0.43), armor)
	station.box(boss_rig, Vector3(0, 2.03, 0), Vector3(0.44, 0.32, 0.36), shell)
	boss_eye = station.box(boss_rig, Vector3(0, 2.04, -0.19), Vector3(0.37, 0.055, 0.04), station.palette.red)
	for side in [-1, 1]:
		station.box(boss_rig, Vector3(side * 0.45, 1.64, 0), Vector3(0.27, 0.28, 0.37), shell)
		station.box(boss_rig, Vector3(side * 0.53, 1.23, 0), Vector3(0.16, 0.64, 0.20), armor)
		station.box(boss_rig, Vector3(side * 0.20, 0.48, 0), Vector3(0.22, 1.03, 0.27), shell)
		station.box(boss_rig, Vector3(side * 0.21, 0.83, -0.145), Vector3(0.12, 0.22, 0.04), station.palette.red)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ff2455")
	lamp.light_energy = 1.55
	lamp.omni_range = 4.0
	boss.add_child(lamp)
	lamp.position = Vector3(0, 1.66, -0.45)
	boss.hide()


func _process(delta: float) -> void:
	if mode == "intro":
		intro_time += delta
		exterior.animate(intro_time)
		if intro_time >= 27.0:
			start_game()
	elif note_timer > 0.0 and mode in ["audit", "world"]:
		note_timer -= delta
	if mode == "world":
		station.animate_instruments(time_in_lap)
	if mode != "intro":
		exterior.animate_window(delta)
	optics.set_shader_parameter("transition", clampf((shift_cooldown - 1.02) * 3.0, 0.0, 1.0))
	optics.set_shader_parameter("defocus", 1.0 if mode in ["audit", "keypad", "paused", "restart_confirm"] else 0.0)
	interface.queue_redraw()


func _physics_process(delta: float) -> void:
	if mode != "world":
		return
	time_in_lap += delta
	shift_cooldown = maxf(0.0, shift_cooldown - delta)
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := player.basis * Vector3(move.x, 0, move.y).normalized()
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT) and move.length_squared() > 0
	var speed := 6.25 if sprint else 4.45
	player.velocity = Vector3(direction.x * speed, -6.0, direction.z * speed)
	player.move_and_slide()
	if player.position.y < -3.0:
		reset_lap("地板重力异常。审计匣已复原。")
		return
	if boss_live:
		update_boss(delta, sprint)
	if upload > 0.0:
		upload -= delta
		if upload <= 0.0 and mode == "world" and patched:
			cleared = true
			store_progress()
			set_mode("ending")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mode == "world" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.00235)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.00235, -1.35, 1.35)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode != "world":
		handle_action(interface.button_at(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if mode == "restart_confirm":
				set_mode("paused")
			elif mode in ["audit", "keypad", "paused"]:
				set_mode("world")
			elif mode == "world":
				set_mode("paused")
			return
		match mode:
			"intro":
				if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
					start_game()
			"keypad":
				if event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_9:
					press_keypad(str(event.physical_keycode - KEY_0))
				elif event.physical_keycode == KEY_BACKSPACE:
					press_keypad("back")
				elif event.physical_keycode == KEY_ENTER:
					press_keypad("enter")
			"ending", "paused":
				if event.physical_keycode == KEY_ENTER:
					handle_action("loop" if mode == "ending" else "resume")
			"audit":
				if event.physical_keycode in [KEY_1, KEY_2, KEY_3] and mode == "audit" and puzzle_available():
					if chapter == 0:
						toggle_alignment(["device", "alarm", "clock"][event.physical_keycode - KEY_1])
					else:
						answer(event.physical_keycode - KEY_1)
				elif event.physical_keycode == KEY_ENTER and chapter == 0:
					submit_alignment(alignment_fields)
				elif event.physical_keycode == KEY_ENTER and ready_to_send():
					begin_upload()
			"world":
				match event.physical_keycode:
					KEY_E: interact()
					KEY_F: pulse()
					KEY_M:
						map_phase = 1 - map_phase
					KEY_R:
						if chapter == 1 and case_accepted:
							reset_lap("你撤销了本轮接案，回到任务广播前。")


func handle_action(action: String) -> void:
	match action:
		"start": start_game()
		"resume": set_mode("world")
		"send": begin_upload()
		"align_submit": submit_alignment(alignment_fields)
		"accept":
			if can_confirm_again():
				case_accepted = true
				update_witness()
				set_mode("world")
				say("已复核 A-42。按 R 重新进入本轮，或去暮区查看执行结果。")
		"loop": reset_lap("站外：收到。告诉我还有谁。")
		"restart_prompt": set_mode("restart_confirm")
		"cancel_restart": set_mode("paused")
		"restart_case":
			if mode == "restart_confirm":
				chapter = 0
				laps = 0
				evidence = [false, false, false]
				cleared = false
				solved = false
				boss_live = false
				tactic = "patrol"
				tactic_source = "rules"
				reset_lap("新调查已建立。前往晨区 B-17。")
		"quit": get_tree().quit()
		_:
			if action.begins_with("align_"):
				toggle_alignment(action.trim_prefix("align_"))
			elif action.begins_with("choice_"):
				answer(int(action.get_slice("_", 1)))
			elif action.begins_with("key_"):
				press_keypad(action.get_slice("_", 1))


func set_mode(next: String) -> void:
	if mode == "audit" and next != "audit":
		alignment_fields.clear()
	mode = next
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "world" else Input.MOUSE_MODE_VISIBLE
	interface.queue_redraw()


func start_game() -> void:
	exterior.finish()
	camera.make_current()
	spawn_at_desk()
	set_mode("ending" if cleared else "world")
	say("站内广播：调查员，请确认接案。林岑最后一次刷卡，就在刚才。")


func spawn_at_desk() -> void:
	phase = 0
	map_phase = phase
	station.set_phase(phase)
	player.position = station.point(station.AUDIT) + Vector3(0.18, 0.05, 0.29)
	player.rotation.y = -1.13
	camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	update_witness()


func update_witness() -> void:
	station.update_witness(chapter, evidence[0], case_accepted)
	station.update_audit_status(audit_status_text())


func audit_status_text() -> String:
	if cleared:
		return "站外回执 / 已收讫\n审计匣：记录保留"
	if chapter == 1:
		return "A-42 / 已复核\n执行已触发 · R 返回确认前" if case_accepted else "A-42 / 待复核\n这一次，可以暂缓签字"
	if chapter in [4, 2]:
		return "A-42 / 授权已核验\n审计匣：记录保留"
	return "任务 / 已签收\n前往 B-17 核对记录" if case_accepted else "任务 / 待签收\n寻找失联同事 林岑"


func audit_reflection() -> String:
	if chapter == 1:
		return "同一个签字，暮区仍有人付出代价。按 R 返回确认前。" if case_accepted else "桌上的授权没有变。这次，先去暮区看看未签字的结果。"
	if chapter in [4, 2]:
		return "站内可以复位；已经交割的账目，却留在站外。"
	return "把两份记录带回来。审计匣会保留你已经核验的证据。"


func nearby() -> Vector2i:
	var tile: Vector2i = station.cell(player.position)
	if player.position.distance_to(station.point(tile)) < 1.82:
		return tile
	return Vector2i(-1, -1)


func interaction_prompt() -> String:
	var tile := nearby()
	if tile == station.AUDIT:
		if chapter == 0 and not case_accepted and not evidence.has(true):
			return "[E] 确认接案 / A-01    ·    也可直接前往 B-17"
		if chapter == 1 and not case_accepted and not evidence.has(true):
			return "[E] 查看任务详情 / A-01    ·    暂缓确认"
		return "[E] 打开 2D 调查台 / A-01"
	if tile in station.GATES:
		return "[E] 穿过换相门  →  %s" % ("暮区" if phase == 0 else "晨区")
	if tile == station.OFFICE:
		return "[E] 调查办公室 / B-17"
	if tile == station.RELAY:
		return "[E] 检查应急中继 / R-03"
	if tile == station.LAB:
		return "[E] 查看同步时钟 / C-04"
	if tile == station.MEDICAL:
		return "[E] 核对生命维持记录 / D-09"
	if tile == station.LEDGER:
		return "[E] 读取借时账本 / L-06"
	return ""


func interact() -> void:
	var tile := nearby()
	if tile in station.GATES:
		shift(tile)
	elif tile == station.AUDIT:
		if boss_live and boss_phase == phase and boss.position.distance_to(player.position) < 4.0 and stunned <= 0.0:
			say("追债人太近。先把它引开，或用断相脉冲打断它。")
			return
		if chapter == 0 and not case_accepted and not evidence.has(true):
			case_accepted = true
			update_witness()
			say("接案已签收。目标：晨区 B-17。按 M 查看地图。")
			return
		if chapter == 1 and phase == 0:
			evidence[1] = true
		elif chapter in [2, 3]:
			evidence[2] = true
		if unbanked:
			unbanked = false
			say("现场记录已写入审计匣。")
		store_progress()
		map_phase = phase
		set_mode("audit")
	elif tile == station.OFFICE:
		inspect_office()
	elif tile == station.RELAY:
		inspect_relay()
	elif tile == station.LAB:
		if chapter == 3:
			record(phase, "调出本地计时记录。两边的时钟都从同一次脉冲开始。")
		else:
			say("C-04 同步实验室。两面墙上的时钟从来对不准。")
	elif tile == station.MEDICAL:
		if chapter == 4 and phase == 1:
			record(0, "D-09：林岑 / 交易 X-71 / 剩余寿命扣减 38 年。")
		else:
			say("生命维持舱的床位表已冻结。留在暮区的名单仍在更新。")
	elif tile == station.LEDGER:
		if chapter == 4 and phase == 0:
			if evidence[1]:
				say("配额账户：交易 X-71 / 交割增加 38 年。")
			else:
				keypad_entry = ""
				map_phase = phase
				set_mode("keypad")
		elif chapter == 4:
			record(2, "已交割记录保存在站外。站内复位之后，余额没有恢复。")
		else:
			say("配额终端要求提供已核验的扣款授权。")


func record(index: int, message: String) -> void:
	evidence[index] = true
	store_progress()
	say(message)


func press_keypad(key: String) -> void:
	if mode != "keypad":
		return
	match key:
		"back": keypad_entry = keypad_entry.left(-1)
		"enter":
			if keypad_entry == "7138":
				record(1, "配额账户：交易 X-71 / 交割增加 38 年。")
				beep(820.0, 0.22)
				set_mode("world")
			else:
				keypad_entry = ""
				say("校验失败。对照 D-09 的交易编号和扣除年数。")
				beep(155.0, 0.22)
		_:
			if keypad_entry.length() < 4:
				keypad_entry += key


func inspect_office() -> void:
	if chapter == 0:
		if phase == 0:
			if not evidence[0]:
				evidence[0] = true
				update_witness()
				say("门禁响了一声。林岑的椅子还在转。已取回晨区日志 #043。")
				beep(640.0, 0.24)
			else:
				say("门框有一道撞痕。门禁机的编号是 V-17。")
		else:
			if not evidence[1]:
				evidence[1] = true
				evidence[2] = true
				unbanked = true
				say("遗书：下次接到任务时，先别按确认。警告，清算外骨骼已启动。")
				activate_boss(station.RELAY)
			else:
				say("遗书是你的笔迹。两份日志里的警报声完全一样。")
		store_progress()
	elif chapter == 1 and phase == 1:
		if case_accepted:
			say("同一笔扣款已经执行。林岑死了。按 R 回到确认之前。")
			activate_boss(station.RELAY)
			return
		if not evidence[2]:
			evidence[2] = true
			unbanked = true
			say("林岑还活着：用事故前的求救线路。快，把授权记录送出去。")
			activate_boss(station.RELAY)
			store_progress()
	else:
		say("B-17 门禁依旧在等待下一次复核。")


func inspect_relay() -> void:
	if chapter == 1 and phase == 0:
		evidence[0] = true
		say("取回配额单。受益账户属于管理层。授权编号 A-42。")
		store_progress()
	elif chapter == 2:
		if not solved:
			evidence[phase] = true
			say("记录 E-7 开关位置。" if phase == 0 else "找到 E-7 线缆编号和站外中继。")
			store_progress()
		elif phase == 0 and not armed:
			armed = true
			say("旧疏散广播已启动。换相后接上暮区 E-7。")
			activate_boss(station.GATES[1])
		elif phase == 1 and armed:
			patched = true
			say("中继接通。回晨区调查台，外发完整账本。")
		else:
			say("需先在晨区合上应急开关。")
	else:
		say("R-03 应急中继。旧线路没有出现在站内网络图上。")


func objective() -> String:
	match chapter:
		0:
			if not evidence[0]: return "前往晨区 B-17，调查林岑的门禁记录。"
			if not evidence[1]: return "从换相门进入暮区，找另一份 B-17 记录。"
			return "带着日志回到调查台 A-01，核对警报编号。"
		1:
			if case_accepted: return "A-42 已签收。按 R 可撤销本轮接案。"
			if not evidence[1]: return "在晨区调查台查看任务授权，暂缓确认。"
			if not evidence[0]: return "查阅晨区 R-03 的配额单。"
			if not evidence[2]: return "去暮区 B-17，看看林岑是否还活着。"
			return "回到调查台 A-01，查清是谁授权扣款。"
		3:
			if not evidence[0] or not evidence[1]: return "查阅晨、暮两区 C-04 的同步记录。"
			return "回到调查台 A-01，换算两条记录的发生顺序。"
		4:
			if not evidence[0]: return "前往暮区 D-09，找林岑的寿命扣款。"
			if not evidence[1] or not evidence[2]: return "比对晨、暮两区 L-06 的交易流水。"
			return "回到调查台 A-01，追踪被拨走的 38 年。"
		_:
			if upload > 0.0: return "站外传输中  //  剩余 %.1f 秒" % upload
			if patched: return "回到晨区 A-01，从调查台外发证据。"
			if armed: return "换相到暮区，接上 R-03 的 E-7 线缆。"
			if solved: return "去晨区 R-03，打开 E-7 应急开关。"
			if not evidence[0] or not evidence[1]: return "比对晨、暮两区 R-03 的应急线路。"
			return "回到 A-01，把两份线路记录接起来。"


func chapter_title() -> String:
	return CHAPTERS[chapter]


func evidence_lines() -> Array:
	var lines := []
	for index in range(3):
		lines.append(RECORDS[chapter][index] if evidence[index] else "未取得 · 记录 %02d" % (index + 1))
	return lines


func puzzle_available() -> bool:
	return not solved and not evidence.has(false)


func puzzle_question() -> String:
	return QUESTIONS[chapter]


func puzzle_choices() -> Array:
	return CHOICES[chapter]


func can_confirm_again() -> bool:
	return chapter == 1 and not case_accepted and not evidence[2]


func answer(index: int) -> void:
	if mode != "audit" or not puzzle_available() or chapter == 0:
		return
	if index != ANSWERS[chapter]:
		say(["对照门禁设备编号和同一次警报，两边的时钟各走各的。", "把配额单的受益人和操作日志的最后签收者分开看。", "寻找在两份记录中都出现的线路编号。", "先把暮区计时除以 1000，再与晨区记录比较。", "查找同一个交易号，并确认总账是否随站内复位。"][chapter])
		beep(155.0, 0.24)
		return
	complete_puzzle()


func toggle_alignment(field: String) -> void:
	if mode != "audit" or chapter != 0 or not puzzle_available() or field not in ["device", "alarm", "clock"]:
		return
	if field in alignment_fields:
		alignment_fields.erase(field)
	else:
		alignment_fields.append(field)
	interface.queue_redraw()


func submit_alignment(fields: Array) -> void:
	if mode != "audit" or chapter != 0 or not puzzle_available():
		return
	if fields.size() != 2 or not fields.has("device") or not fields.has("alarm"):
		say("需要两项事件身份；不同步的钟面不是同一次事件的凭证。")
		beep(155.0, 0.24)
		return
	complete_puzzle()


func complete_puzzle() -> void:
	beep(820.0, 0.26)
	if chapter == 2:
		solved = true
		store_progress()
		set_mode("world")
		say("线路核验完成：晨区合上开关，暮区接上中继。")
		return
	var conclusion: String = [
		"同一间办公室。去时钟实验室查一查，这份任务究竟什么时候被建立。",
		"授权已核验。林岑：去生命维持舱，找我的名字和 X-71。",
		"",
		"名单先于寻人任务。他们已经选好了林岑，才派你去找他。",
		"每次回廊复位，管理层的余额照常累加。去找一条能越过站内网络的线。",
	][chapter]
	chapter = NEXT_CHAPTER[chapter]
	evidence = [false, false, false]
	reset_lap(conclusion)


func ready_to_send() -> bool:
	return chapter == 2 and phase == 0 and patched and upload <= 0.0


func begin_upload() -> void:
	if mode != "audit" or not ready_to_send():
		return
	upload = 6.0
	last_known = station.AUDIT
	path_timer = 0.0
	set_mode("world")
	say("上行信号已暴露。撑过六秒，回执会写入审计匣。")
	beep(740.0, 0.36)


func say(message: String) -> void:
	notice = message
	note_timer = 7.0


func shift(tile: Vector2i) -> void:
	if shift_cooldown > 0.0:
		say("换相门正在同步，请稍候。")
		return
	if boss_live and boss_phase == phase and boss.position.distance_to(player.position) < 9.0:
		var index: int = station.GATES.find(tile)
		gate_observed[index] += 1
	phase = 1 - phase
	map_phase = phase
	station.set_phase(phase)
	player.position = station.point(tile) + Vector3.UP * 0.055
	player.velocity = Vector3.ZERO
	cross_gate = tile
	last_known = tile
	shift_cooldown = 1.35
	path_timer = 0.0
	beep(385.0 if phase == 0 else 258.0, 0.32)
	say("时态同步完成：%s。" % ("晨区" if phase == 0 else "暮区"))


func activate_boss(tile: Vector2i) -> void:
	if boss_live:
		return
	boss_live = true
	boss_phase = phase
	boss_delay = 2.2
	var spawn := tile
	if tactic == "ambush" and chapter != 2:
		var gate: Vector2i = station.GATES[tactic_gate]
		var route: Array = station.path(phase, station.cell(player.position), gate)
		if route.size() >= 4:
			spawn = gate
	boss.position = station.point(spawn)
	last_known = station.cell(player.position)
	tracking_time = 3.0
	patrol_index = 0
	path_timer = 0.0
	beep(108.0, 0.70)


func update_boss(delta: float, sprint: bool) -> void:
	boss_delay = maxf(0.0, boss_delay - delta)
	stunned = maxf(0.0, stunned - delta)
	charge_recovery = maxf(0.0, charge_recovery - delta)
	var distance := boss.position.distance_to(player.position)
	var same_phase := boss_phase == phase
	boss.visible = same_phase and boss_delay <= 0.8
	boss_eye.material_override = station.palette.blue if stunned > 0.0 else station.palette.red
	boss_rig.position.y = 0.05 * sin(time_in_lap * 14.0) if stunned <= 0.0 else 0.0
	threat = 0.2 if not same_phase else clampf(1.1 - distance / 15.0, 0.14, 0.92)
	if boss_delay > 0.0 or stunned > 0.0:
		return
	var seen := same_phase and distance < 13.0 and has_sight()
	tracking_time = maxf(0.0, tracking_time - delta)
	if seen or (same_phase and sprint and distance < 10.5):
		last_known = station.cell(player.position)
		tracking_time = 3.0
		if sprint and not seen:
			sprint_observed = 1
	if same_phase and distance < 1.10:
		reset_lap("追债人完成结算。审计匣里的记录随你回到了开场。")
		return
	if charge_warning > 0.0:
		charge_warning -= delta
		if charge_warning <= 0.0:
			charge_time = 0.57
			charge_recovery = 5.5
		else:
			return
	elif same_phase and seen and distance > 2.5 and distance < 7.8 and charge_recovery <= 0.0 and charge_time <= 0.0:
		charge_warning = 0.78
		beep(180.0, 0.42)
		return
	charge_time = maxf(0.0, charge_time - delta)
	var destination := last_known
	if not same_phase:
		destination = cross_gate
		if boss.position.distance_to(station.point(destination)) < 0.27:
			boss_phase = phase
			boss_delay = 2.15
			boss_route.clear()
			charge_warning = 0.0
			charge_time = 0.0
			beep(145.0, 0.30)
			return
	elif tactic == "cutoff" and not seen and not sprint and upload <= 0.0:
		destination = station.GATES[tactic_gate]
	elif tactic == "guard" and not seen and not sprint and upload <= 0.0:
		destination = Vector2i(2, 1)
	elif not seen and tracking_time <= 0.0 and upload <= 0.0:
		var sweep := [station.RELAY, station.GATES[1], station.OFFICE, station.GATES[0]]
		if boss.position.distance_to(station.point(sweep[patrol_index])) < 0.25:
			patrol_index = (patrol_index + 1) % sweep.size()
		destination = sweep[patrol_index]
	path_timer -= delta
	var cell_at_boss: Vector2i = station.cell(boss.position)
	var center: Vector3 = station.point(cell_at_boss)
	if boss_route.is_empty() or (path_timer <= 0.0 and boss.position.distance_to(center) < 0.22):
		boss_route = station.path(boss_phase, cell_at_boss, destination)
		if not boss_route.is_empty() and boss.position.distance_to(center) < 0.22:
			boss_route.pop_front()
		path_timer = 0.30
	var target := center
	if not boss_route.is_empty():
		target = station.point(boss_route[0])
	elif seen and cell_at_boss == station.cell(player.position):
		target = Vector3(player.position.x, 0, player.position.z)
	if boss.position.distance_to(target) < 0.035:
		if not boss_route.is_empty():
			boss_route.pop_front()
		return
	boss.look_at(target, Vector3.UP)
	var speed := 7.2 if charge_time > 0.0 else (3.77 if seen else 3.27)
	boss.position = boss.position.move_toward(target, speed * delta)


func has_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(boss.position + Vector3.UP * 1.45, player.position + Vector3.UP * 1.32)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func pulse() -> void:
	if charges <= 0:
		say("本轮断相脉冲已用尽。")
		return
	if not boss_live or boss_phase != phase or not boss.visible or boss.position.distance_to(player.position) > 7.0 or not has_sight():
		say("脉冲未锁定。需要与追债人在同一时态且无遮挡。")
		return
	charges -= 1
	stunned = 2.25
	charge_time = 0.0
	charge_warning = 0.0
	charge_recovery = 3.0
	beep(970.0, 0.24)
	say("追债人失相。现在走。")


func threat_text() -> String:
	if stunned > 0.0: return "追债人失相  %.1f s" % stunned
	if charge_warning > 0.0: return "警告  //  追债人准备冲刺"
	if boss_phase != phase: return "追债人正在另一时态搜索"
	return "结算警告  //  追债人已部署"


func reset_lap(message: String) -> void:
	alignment_fields.clear()
	laps += 1
	if boss_live:
		profile.choose_tactic(laps, gate_observed, sprint_observed)
	evidence = banked_evidence()
	unbanked = false
	case_accepted = false
	armed = false
	patched = false
	upload = 0.0
	shift_cooldown = 0.0
	time_in_lap = 0.0
	charges = 2
	threat = 0.0
	boss_live = false
	boss.hide()
	boss_route.clear()
	stunned = 0.0
	charge_warning = 0.0
	charge_time = 0.0
	charge_recovery = 0.0
	gate_observed = [0, 0]
	sprint_observed = 0
	spawn_at_desk()
	set_mode("world")
	store_progress()
	say(message)


func save_label() -> String:
	return profile.status if is_instance_valid(profile) else "正在读取审计匣"


func store_progress() -> void:
	profile.save_state({"chapter": chapter, "laps": laps, "evidence": banked_evidence(), "solved": solved, "cleared": cleared})


func banked_evidence() -> Array:
	var banked := evidence.duplicate()
	if unbanked:
		banked[2] = false
		if chapter == 0:
			banked[1] = false
	return banked


func apply_profile(data: Dictionary) -> void:
	chapter = clampi(int(data.get("chapter", 0)), 0, 4)
	laps = maxi(1, int(data.get("laps", 1)))
	evidence = data.get("evidence", [false, false, false]).duplicate()
	solved = bool(data.get("solved", false))
	cleared = bool(data.get("cleared", false))
	update_witness()
	if cleared and mode == "world" and time_in_lap < 0.3:
		set_mode("ending")


func apply_tactic(lap: int, strategy: String, gate: int, source: String) -> void:
	if lap == laps:
		tactic = strategy
		tactic_gate = clampi(gate, 0, 1)
		tactic_source = source


func beep(frequency: float, seconds: float) -> void:
	var sample_rate := 22050
	var count := int(seconds * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var ratio := float(index) / count
		var envelope := minf(ratio * 28.0, 1.0) * pow(1.0 - ratio, 1.8)
		var sample := sin(TAU * frequency * index / sample_rate) * envelope
		bytes.encode_s16(index * 2, int(sample * 12200.0))
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = sample_rate
	tone.data = bytes
	audio.stream = tone
	audio.play()
