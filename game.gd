extends Node3D

const Sound := preload("res://audio.gd")
const Station := preload("res://station.gd")
const Interface := preload("res://interface.gd")
const Profile := preload("res://profile.gd")
const Exterior := preload("res://exterior.gd")
const HunterVisual := preload("res://hunter_visual.gd")
const Prologue := preload("res://prologue.gd")
const HunterAgent := preload("res://hunter_agent.gd")
const EXTRA_HUNTER_COUNT := 2
const HUNTER_SPAWN_MIN := 8.0
const HUNTER_SPAWN_MAX := 16.0
const HUNTER_ROUTE_BUDGET := 24.0
# World geometry stays on layer 1; temporary player-only grids use layer 2.
const WORLD_GEOMETRY_MASK := 1
const PLAYER_COLLISION_MASK := WORLD_GEOMETRY_MASK | 2
var extra_hunters: Array[Node3D] = []
var hunter_spawn_report := ""
var audio_hunter: Node3D
const FieldTask := preload("res://field_task.gd")
const DUSK_LOCK_SECONDS := 12.0
var field_task := FieldTask.new()
const DuskTrials := preload("res://dusk_trials.gd")
var dusk_trials := DuskTrials.new()
var trials_chapter := -1
var task_committing := false
var gate_lock := 0.0
var deployment_gate := -1
var pending_evidence: Array[int] = []
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
var boss_lamp: OmniLight3D
var boss_body := CapsuleShape3D.new()
var mode := "menu"
var controls_return := "menu"
var restart_return := "paused"
var intro_page := 0
var fresh_investigation := false
var phase := 0
var map_phase := 0
var big_map := false   # M 打开/关闭全屏大地图；Tab 切换晨暮地图
var dev_mode := false   # F1 开关（只在调试运行时有效）
var dev_god := false
var dev_spot := -1
const STORY_ORDER := [0, 3, 1, 4, 2]   # 章节下标按剧情顺序：01 → 02 → 03 → 04 → 05
var chapter := 0
var laps := 1
var intro_time := 0.0
var note_timer := 0.0
var notice := ""
var charges := 2
var threat := 0.0
var case_accepted := false
var cleared := false
var echo_run := false
var evidence: Array = [false, false, false]
var alignment_fields: Array[String] = []
var timeline_seconds := ""
var timeline_order: Array[String] = []
var dusk_grace := 0.0
var dusk_grace_used := false
var unbanked := false
var solved := false
var armed := false
var patched := false
var upload := 0.0
var keypad_entry := ""
var shift_cooldown := 0.0
var time_in_lap := 0.0
var boss_live := false
var boss_chasing := false
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
var last_known: Vector2i = Station.LAB
var cross_gate: Vector2i = Station.GATES[0]
var gate_observed := [0, 0]   # 后端只认两扇门：北侧门记 0/1，南侧门按东西并入
var sprint_observed := 0
var tactic := "patrol"
var tactic_gate := 0
var tactic_source := "rules"
var sound: Node
var prologue: CanvasLayer
var epilogue: CanvasLayer
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
	build_audio()
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
	profile = Profile.new()
	add_child(profile)
	profile.loaded.connect(apply_profile)
	profile.tactic_ready.connect(apply_tactic)
	profile.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func build_audio() -> void:
	sound = Sound.new()
	add_child(sound)
	sound.setup(boss)


func build_player() -> void:
	player = CharacterBody3D.new()
	player.collision_mask = PLAYER_COLLISION_MASK
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
	boss_body.height = 1.67
	boss_body.radius = 0.30
	boss = Node3D.new()
	add_child(boss)
	boss_rig = HunterVisual.new()
	boss.add_child(boss_rig)
	boss_eye = boss_rig.status_marker
	boss_eye.material_override = station.palette.red
	var lamp := OmniLight3D.new()
	boss_lamp = lamp
	lamp.light_color = Color("ff2455")
	lamp.light_energy = 1.55
	lamp.omni_range = 4.0
	boss.add_child(lamp)
	lamp.position = Vector3(0, 1.66, -0.45)
	boss.hide()


func _process(delta: float) -> void:
	boss_rig.animation.active = mode == "world" and boss_live and boss.visible
	for hunter in extra_hunters:
		hunter.rig.animation.active = mode == "world" and hunter.live and hunter.visible
	var opening := mode in ["menu", "intro"] or (mode == "controls" and controls_return == "menu") or (mode == "restart_confirm" and restart_return == "menu")
	if opening:
		update_opening(delta)
	else:
		exterior.animate_window(delta)
	if note_timer > 0.0 and mode in ["audit", "world"]:
		note_timer -= delta
	if mode == "world":
		station.animate_instruments(time_in_lap)
	optics.set_shader_parameter("transition", clampf((shift_cooldown - 1.02) * 3.0, 0.0, 1.0))
	optics.set_shader_parameter("defocus", 1.0 if mode in ["audit", "keypad", "paused", "restart_confirm", "controls"] else 0.0)
	interface.queue_redraw()


func update_opening(delta: float) -> void:
	intro_time += delta
	exterior.animate(intro_time)


func has_progress() -> bool:
	return chapter > 0 or laps > 1 or evidence.has(true) or solved or cleared or echo_run


func begin_intro() -> void:
	intro_time = 0.0
	intro_page = 0
	set_mode("intro")


func begin_prologue() -> void:
	if prologue == null:
		prologue = Prologue.new()
		add_child(prologue)
		prologue.finished.connect(finish_prologue)
	set_mode("cinematic")
	if not prologue.play():
		# A missing media file must never block a new investigation.
		begin_intro()


func finish_prologue() -> void:
	if mode == "cinematic":
		begin_intro()


func begin_epilogue() -> void:
	if not cleared:
		return
	if epilogue == null:
		epilogue = Prologue.new()
		epilogue.stream_path = "res://assets/cinematics/epilogue.ogv"
		epilogue.skip_caption = "Space / Esc  跳过结尾动画"
		add_child(epilogue)
		epilogue.finished.connect(finish_epilogue)
	set_mode("epilogue")
	if not epilogue.play():
		finish_epilogue()


func finish_epilogue() -> void:
	if mode == "epilogue":
		set_mode("ending")


func begin_echo_case() -> void:
	if mode != "ending" or not cleared:
		return
	fresh_investigation = true
	echo_run = true
	chapter = 0
	laps = 0
	evidence = [false, false, false]
	cleared = false
	solved = false
	boss_live = false
	tactic = "patrol"
	tactic_source = "rules"
	reset_lap("回声调查 / 审计匣重建：回到 B-17，那封遗书是你留给自己的。")


func advance_intro() -> void:
	if mode != "intro": return
	if intro_page < 2:
		intro_page += 1
	else:
		start_game()


func _physics_process(delta: float) -> void:
	if mode != "world":
		return
	time_in_lap += delta
	shift_cooldown = maxf(0.0, shift_cooldown - delta)
	gate_lock = maxf(0.0, gate_lock - delta)
	update_field_task(delta)
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := player.basis * Vector3(move.x, 0, move.y).normalized()
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT) and move.length_squared() > 0
	var speed := 6.25 if sprint else 4.45
	player.velocity = Vector3(direction.x * speed, -6.0, direction.z * speed)
	var previous_player := player.position
	player.move_and_slide()
	if dusk_trials.update(delta, player.position, sprint, phase):
		sound.cue("success")
		say("场地操作已通过。返回原终端按 E 取证。")
	sound.player_moved(previous_player, player.position, player.is_on_floor(), sprint)
	if player.position.y < -3.0:
		reset_lap("地板重力异常。审计匣已复原。")
		return
	if phase == 0:
		stop_dusk_chase()
	station.laser_grid.update(delta, phase, any_hunter_chasing(), player.position, boss.position, extra_hunter_positions())
	var lap_before := laps
	var previous_boss := boss.position
	if boss_live:
		update_boss(delta, sprint)
		boss_rig.update_motion(delta, boss.position.distance_to(previous_boss) / maxf(delta, 0.001), stunned > 0.0 or boss_delay > 0.0 or charge_warning > 0.0)
	if laps != lap_before: return
	update_extra_hunters(delta, sprint)
	if laps != lap_before: return
	refresh_hunter_threat()
	var nearest := nearest_hunter()
	focus_hunter_audio(nearest)
	if nearest == boss:
		sound.hunter_moved(previous_boss, boss.position, boss_live and boss_phase == phase and boss_delay <= 0.0 and stunned <= 0.0)
	elif nearest != null:
		sound.hunter_moved(nearest.previous_position, nearest.position, nearest.delay <= 0.0 and nearest.stunned <= 0.0)
	sound.update_chase(delta, threat, any_hunter_chasing(true))
	if upload > 0.0:
		upload -= delta
		if upload <= 0.0 and mode == "world" and patched:
			cleared = true
			store_progress()
			begin_epilogue()


func _input(event: InputEvent) -> void:
	if mode in ["cinematic", "epilogue"]:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ESCAPE]:
			if mode == "cinematic": prologue.finish()
			else: epilogue.finish()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and mode == "world" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.00235)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.00235, -1.35, 1.35)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode != "world":
		handle_action(interface.button_at(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		if mode == "world" and field_task.active:
			if event.physical_keycode == KEY_ESCAPE:
				field_task.active = false
				say("操作已取消，现场记录尚未提交。")
				return
			if event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_E]:
				if field_task.press(event.physical_keycode):
					finish_field_task()
				return
		if event.physical_keycode == KEY_ESCAPE:
			if mode == "world" and big_map:
				big_map = false
				return
			if mode == "controls":
				set_mode(controls_return)
			elif mode == "restart_confirm":
				set_mode(restart_return)
			elif mode in ["audit", "keypad", "paused"]:
				set_mode("world")
			elif mode == "world":
				set_mode("paused")
			return
		if event.physical_keycode == KEY_H and mode in ["menu", "world", "paused"]:
			handle_action("controls")
			return
		match mode:
			"menu":
				if event.physical_keycode == KEY_ENTER:
					handle_action("continue" if has_progress() else "new_case")
				elif event.physical_keycode == KEY_N:
					handle_action("new_case")
				elif event.physical_keycode == KEY_Q:
					handle_action("quit")
			"controls":
				if event.physical_keycode in [KEY_ENTER, KEY_H]:
					set_mode(controls_return)
			"intro":
				if event.physical_keycode == KEY_ENTER:
					advance_intro()
				elif event.physical_keycode == KEY_SPACE:
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
				if chapter == 3:
					if event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_9:
						timeline_key(str(event.physical_keycode - KEY_0))
					elif event.physical_keycode == KEY_BACKSPACE:
						timeline_key("back")
					elif event.physical_keycode == KEY_ENTER:
						submit_timeline()
					elif event.physical_keycode == KEY_UP:
						pick_timeline("debit")
					elif event.physical_keycode == KEY_DOWN:
						pick_timeline("filing")
				else:
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
						big_map = not big_map
						say("大地图为实时预览，追债人仍会移动；M 关闭，Tab 预览另一时态。" if big_map else "大地图已关闭。")
					KEY_TAB:
						map_phase = 1 - map_phase
					KEY_F1:
						if OS.is_debug_build():
							dev_mode = not dev_mode
							say("开发者模式：%s" % ("开" if dev_mode else "关"))
					KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7:
						if dev_mode:
							dev_key(event.physical_keycode)
					KEY_R:
						if chapter == 1 and case_accepted:
							reset_lap("你撤销了本轮接案，回到任务广播前。")


func handle_action(action: String) -> void:
	match action:
		"start":
			if mode == "intro": start_game()
		"continue":
			if mode == "menu" and has_progress(): start_game()
		"new_case":
			if mode != "menu": return
			if has_progress():
				restart_return = "menu"
				set_mode("restart_confirm")
			else:
				fresh_investigation = true
				echo_run = false
				begin_prologue()
		"intro_next": advance_intro()
		"controls":
			if mode in ["menu", "world", "paused"]:
				controls_return = mode
				set_mode("controls")
		"controls_back":
			if mode == "controls": set_mode(controls_return)
		"resume": set_mode("world")
		"send": begin_upload()
		"align_submit": submit_alignment(alignment_fields)
		"timeline_submit": submit_timeline()
		"timeline_back": timeline_key("back")
		"timeline_clear":
			if mode == "audit" and chapter == 3:
				timeline_seconds = ""
				timeline_order.clear()
		"accept":
			if can_confirm_again():
				case_accepted = true
				update_witness()
				set_mode("world")
				say("已复核 A-42。按 R 重新进入本轮，或去暮区查看执行结果。")
		"loop": begin_echo_case()
		"replay_ending":
			if mode == "ending": begin_epilogue()
		"restart_prompt":
			restart_return = mode
			set_mode("restart_confirm")
		"cancel_restart": set_mode(restart_return)
		"restart_case":
			if mode == "restart_confirm":
				fresh_investigation = true
				echo_run = false
				chapter = 0
				laps = 0
				evidence = [false, false, false]
				cleared = false
				solved = false
				boss_live = false
				tactic = "patrol"
				tactic_source = "rules"
				reset_lap("新调查已建立。前往晨区 B-17。")
				begin_prologue()
		"quit": get_tree().quit()
		_:
			if action.begins_with("timeline_digit_"):
				timeline_key(action.trim_prefix("timeline_digit_"))
			elif action.begins_with("timeline_pick_"):
				pick_timeline(action.trim_prefix("timeline_pick_"))
			elif action.begins_with("align_"):
				toggle_alignment(action.trim_prefix("align_"))
			elif action.begins_with("choice_"):
				answer(int(action.get_slice("_", 1)))
			elif action.begins_with("key_"):
				press_keypad(action.get_slice("_", 1))


func set_mode(next: String) -> void:
	if mode == "cinematic" and next != "cinematic" and prologue != null:
		prologue.stop()
	if mode == "epilogue" and next != "epilogue" and epilogue != null:
		epilogue.stop()
	get_viewport().disable_3d = next in ["cinematic", "epilogue"]
	boss_rig.animation.active = next == "world" and boss_live and boss.visible
	for hunter in extra_hunters:
		hunter.rig.animation.active = next == "world" and hunter.live and hunter.visible
	if mode == "audit" and next != "audit":
		alignment_fields.clear()
		timeline_seconds = ""
		timeline_order.clear()
	if next != "world":
		sound.quiet()
	if next != "world": big_map = false
	mode = next
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "world" else Input.MOUSE_MODE_VISIBLE
	interface.queue_redraw()


func start_game() -> void:
	exterior.finish()
	camera.make_current()
	spawn_at_desk()
	set_mode("ending" if cleared else "world")
	if not cleared:
		if echo_run:
			say("回声调查 / 审计匣重建：回到 B-17。那封遗书，是你写给下一轮的提醒。")
		else:
			say("站内广播：林岑失联。先去晨区 B-17 核对门禁记录。" if not has_progress() else "审计匣已载入。" + objective())


func spawn_at_desk() -> void:
	stop_dusk_chase()
	phase = 0
	map_phase = phase
	station.set_phase(phase)
	player.position = station.point(station.AUDIT) + Vector3(0.18, 0.05, 0.29)
	player.rotation.y = -1.13
	camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	update_witness()


func update_witness() -> void:
	if trials_chapter != chapter:
		stop_dusk_chase()
		dusk_trials.clear()
		trials_chapter = chapter
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


func relay_status() -> String:
	if chapter != 2:
		return "E-7 / 未接通"
	if patched:
		return "E-7 / 暮区中继已接通 · 回晨区 A-01 外发"
	if armed:
		return "E-7 / 晨区开关已合上 · 前往暮区接线"
	if solved:
		return "E-7 / 两区线路已核验 · 回晨区合闸"
	return "E-7 / 未接通 · 先核对两区线路"


func nearby() -> Vector2i:
	var tile: Vector2i = station.cell(player.position)
	if player.position.distance_to(station.point(tile)) < 1.82:
		return tile
	return Vector2i(-1, -1)


func interaction_prompt() -> String:
	var spatial_prompt: String = dusk_trials.prompt(player.position, phase)
	if not spatial_prompt.is_empty():
		return spatial_prompt
	var tile := nearby()
	if tile == station.AUDIT:
		if phase != 0:
			return "暮区 A-01 离线 · 回晨区归档"
		if chapter == 0 and not case_accepted and not evidence.has(true):
			return "[E] 确认接案 / A-01    ·    也可直接前往 B-17"
		if chapter == 1 and not case_accepted and not evidence.has(true):
			return "[E] 查看任务详情 / A-01    ·    暂缓确认"
		return "[E] 打开证据工作台 / A-01"
	if tile in station.GATES:
		if phase == 1 and gate_lock > 0.0:
			return "换相门封锁中  %.1f 秒 · 先绕开追债人" % gate_lock
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
	if dusk_trials.interact(player.position, phase):
		say(dusk_trials.message)
		return
	var tile := nearby()
	if field_task.active:
		return
	if start_field_task(tile):
		return
	if tile in station.GATES:
		shift(tile)
	elif tile == station.AUDIT:
		if phase != 0:
			say("暮区调查台离线。记录须回晨区 A-01 归档。")
			return
		if boss_live and boss_phase == phase and boss.position.distance_to(player.position) < 4.0 and stunned <= 0.0:
			say("追债人太近。先把它引开，或用断相脉冲打断它。")
			return
		if chapter == 0 and not case_accepted and not evidence.has(true):
			case_accepted = true
			sound.cue("archive")
			update_witness()
			say("接案已签收。目标：晨区 B-17。按 M 打开大地图。")
			return
		if chapter == 1 and phase == 0:
			evidence[1] = true
		elif chapter in [2, 3]:
			evidence[2] = true
		if unbanked:
			unbanked = false
			pending_evidence.clear()
			say("现场记录已写入审计匣。")
		store_progress()
		map_phase = phase
		set_mode("audit")
		sound.cue("archive")
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


func start_field_task(tile: Vector2i) -> bool:
	if task_committing:
		return false
	var task := ""
	if tile == station.OFFICE:
		if chapter == 0 and phase == 0 and not evidence[0]:
			task = "circuit"
		elif phase == 1 and ((chapter == 0 and not evidence[1]) or (chapter == 1 and not case_accepted and not evidence[2])):
			task = "silent"
	elif tile == station.LAB and chapter == 3 and not evidence[phase]:
		task = "clock"
	elif tile == station.RELAY and chapter == 2 and solved and armed and not patched and phase == 1:
		task = "relay"
	if task.is_empty():
		return false
	if phase == 1 and task in ["silent", "clock", "relay"]:
		if dusk_trials.is_complete(task):
			return false
		if dusk_trials.begin(task, station, phase):
			say(dusk_trials.guidance())
		else:
			say(dusk_trials.message)
		return true
	field_task.begin(task, tile, phase)
	say(field_task.instructions() + " · Esc 取消；操作时世界不会暂停。")
	return true


func update_field_task(delta: float) -> void:
	if not field_task.active:
		return
	if phase != field_task.task_phase or player.position.distance_to(station.point(field_task.anchor)) >= 1.82:
		field_task.active = false
		say("已离开操作范围，任务尚未完成。")
		return
	var moving := false
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT]:
		moving = moving or Input.is_physical_key_pressed(key)
	if field_task.tick(delta, Input.is_physical_key_pressed(KEY_E) and not moving):
		finish_field_task()


func finish_field_task() -> void:
	if not field_task.active or phase != field_task.task_phase or nearby() != field_task.anchor:
		field_task.active = false
		return
	field_task.active = false
	task_committing = true
	interact()
	task_committing = false


# Re-deploy the existing hunter, including when it is already live in another phase.
# The closest reachable gate is chosen by world distance; gates without a path are excluded.
func deploy_after_submission() -> void:
	if phase != 1:
		return
	clear_extra_hunters()
	var best := INF
	deployment_gate = -1
	var here: Vector2i = station.cell(player.position)
	for index in range(station.GATES.size()):
		var gate: Vector2i = station.GATES[index]
		if station.hunter_path(phase, gate, here).is_empty():
			continue
		var distance := player.position.distance_squared_to(station.point(gate))
		if distance < best:
			best = distance
			deployment_gate = index
	if deployment_gate < 0:
		return
	boss_live = true
	boss_phase = phase
	boss.position = station.point(station.GATES[deployment_gate])
	boss_delay = 1.6
	boss.show()
	boss_route.clear()
	stunned = 0.0
	charge_warning = 0.0
	charge_time = 0.0
	charge_recovery = 2.0
	last_known = here
	tracking_time = DUSK_LOCK_SECONDS + 2.0
	path_timer = 0.0
	gate_lock = DUSK_LOCK_SECONDS
	deploy_extra_hunters()
	refresh_hunter_threat()
	focus_hunter_audio(nearest_hunter())
	sound.cue("deploy")
	say(notice + "\nG-%02d 与附近部署共 %d 名追债人；全体换相门封锁 %.0f 秒。%s" % [deployment_gate + 1, 1 + extra_hunters.size(), gate_lock, hunter_spawn_report])


func clear_extra_hunters() -> void:
	# Spatial voices must leave an extra actor before that actor is freed.
	if is_instance_valid(sound): focus_hunter_audio(boss)
	for hunter in extra_hunters:
		hunter.live = false
		hunter.hide()
		hunter.rig.animation.active = false
		hunter.route.clear()
		hunter.queue_free()
	extra_hunters.clear()


func extra_hunter_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for hunter in extra_hunters:
		if hunter.live: positions.append(hunter.position)
	return positions


# Four-connected grid shortest paths, followed by capsule-checked local fixture detours.
# This is not a claim of globally shortest continuous-space navigation.
func hunter_spawn_route(origin: Vector3, target: Vector3) -> PackedVector3Array:
	var tiles: Array[Vector2i] = station.hunter_path(1, station.cell(origin), station.cell(target))
	var result := PackedVector3Array([origin])
	if tiles.is_empty(): return PackedVector3Array()
	for index in range(1, tiles.size()):
		var next: Vector3 = station.point(tiles[index])
		var previous: Vector3 = result[result.size() - 1]
		if boss_motion_fraction(previous, next) >= 1.0:
			result.append(next)
		else:
			var detour := hunter_detour_path(previous, next, 1)
			if detour.size() < 2: return PackedVector3Array()
			for step in range(1, detour.size()): result.append(detour[step])
	var end := Vector3(target.x, 0, target.z)
	var previous: Vector3 = result[result.size() - 1]
	if previous.distance_to(end) > 0.05:
		if boss_motion_fraction(previous, end) >= 1.0:
			result.append(end)
		else:
			var detour := hunter_detour_path(previous, end, 1)
			if detour.size() < 2: return PackedVector3Array()
			for step in range(1, detour.size()): result.append(detour[step])
	# Pull collision-free shortcuts across the composed grid/local route; this also
	# removes backtracking introduced when a fixture obstructs a grid-center edge.
	var compact := PackedVector3Array([result[0]])
	var cursor := 0
	while cursor < result.size() - 1:
		var next := result.size() - 1
		while next > cursor + 1 and boss_motion_fraction(result[cursor], result[next]) < 1.0:
			next -= 1
		compact.append(result[next])
		cursor = next
	return compact


func route_world_length(route: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, route.size()): length += route[index - 1].distance_to(route[index])
	return length


func deploy_extra_hunters() -> void:
	var candidates: Array[Dictionary] = []
	var here: Vector2i = station.cell(player.position)
	var reserved: Array = station.GATES + [station.AUDIT, station.OFFICE, station.RELAY, station.LAB, station.MEDICAL, station.LEDGER]
	for z in range(-4, 5):
		for x in range(-4, 5):
			var tile := here + Vector2i(x, z)
			if not station.walkable(1, tile) or tile in reserved: continue
			var position: Vector3 = station.point(tile)
			var distance := position.distance_to(Vector3(player.position.x, 0, player.position.z))
			if distance < HUNTER_SPAWN_MIN or distance > HUNTER_SPAWN_MAX: continue
			if boss_motion_fraction(position, position) < 1.0: continue
			var near_device := false
			for site in dusk_trials.sites:
				if position.distance_to(site.position) < 2.0: near_device = true
			if near_device: continue
			var route := hunter_spawn_route(position, player.position)
			if route.size() < 2: continue
			var length := route_world_length(route)
			# A nearby circle across a long wall is not an encounter spawn.
			if length > HUNTER_ROUTE_BUDGET or length > distance * 1.8: continue
			var visible_route := hunter_has_sight(position)
			candidates.append({"position": position, "length": length, "visible": visible_route})
	var chosen: Array[Vector3] = []
	# Select the best compatible pair globally: greedy choice can consume the only
	# approach angle compatible with a second safe point (notably at B-17).
	var preferred: Array[int] = []
	var pair_score := INF
	for first in range(candidates.size()):
		for second in range(first + 1, candidates.size()):
			var a: Vector3 = candidates[first].position
			var b: Vector3 = candidates[second].position
			var angle := (a - player.position).angle_to(b - player.position)
			if a.distance_to(b) < 6.0 or angle < 0.65: continue
			var score: float = candidates[first].length + candidates[second].length - angle * 3.0
			if not candidates[first].visible: score += 3.0
			if not candidates[second].visible: score += 3.0
			if score < pair_score:
				pair_score = score
				preferred = [first, second]
	for count in range(EXTRA_HUNTER_COUNT):
		var best_index := -1
		var best_score := INF
		for index in range(candidates.size()):
			var candidate: Dictionary = candidates[index]
			var separation := PI
			var vector: Vector3 = candidate.position - player.position
			for previous in chosen:
				separation = minf(separation, vector.angle_to(previous - player.position))
				if candidate.position.distance_to(previous) < 6.0: separation = -1.0
			if separation < 0.65: continue
			var score: float = candidate.length + (0.0 if candidate.visible else 3.0) - separation * 3.0
			if score < best_score:
				best_score = score
				best_index = index
		if not preferred.is_empty(): best_index = preferred[count]
		if best_index < 0: break
		var position: Vector3 = candidates[best_index].position
		chosen.append(position)
		if preferred.is_empty(): candidates.remove_at(best_index)
		var hunter := HunterAgent.new()
		hunter.name = "NearbyHunter_%d" % count
		add_child(hunter)
		hunter.position = position
		hunter.last_known = here
		hunter.target_position = Vector3(player.position.x, 0, player.position.z)
		hunter.tracking_time = DUSK_LOCK_SECONDS + 2.0
		hunter.eye.material_override = station.palette.red
		extra_hunters.append(hunter)
	hunter_spawn_report = "附近安全点不足，仅部署 %d/2 名；未占用障碍或长绕路点。" % extra_hunters.size() if extra_hunters.size() < EXTRA_HUNTER_COUNT else "绕开来路，再回晨区归档。"


func update_extra_hunters(delta: float, sprint: bool) -> void:
	var lap_before := laps
	# update_agent can reset the lap; iterate a copy so lifecycle cleanup is safe.
	for hunter in extra_hunters.duplicate():
		if not hunter.live: continue
		hunter.update_agent(self, delta, sprint)
		if laps != lap_before: return
		hunter.rig.update_motion(delta, hunter.position.distance_to(hunter.previous_position) / maxf(delta, 0.001), hunter.stunned > 0.0 or hunter.delay > 0.0 or hunter.charge_warning > 0.0)


func nearest_hunter() -> Node3D:
	var nearest: Node3D = boss if boss_live and boss_phase == phase else null
	var distance := boss.position.distance_squared_to(player.position) if nearest != null else INF
	for hunter in extra_hunters:
		if not hunter.live or phase != 1: continue
		var next := hunter.position.distance_squared_to(player.position)
		if next < distance:
			distance = next
			nearest = hunter
	return nearest


func any_hunter_chasing(audible := false) -> bool:
	if boss_live and boss_phase == phase and boss_chasing and (not audible or (boss_delay <= 0.0 and stunned <= 0.0)): return true
	for hunter in extra_hunters:
		if phase == 1 and hunter.live and hunter.chasing and (not audible or (hunter.delay <= 0.0 and hunter.stunned <= 0.0)): return true
	return false


func refresh_hunter_threat() -> void:
	var nearest := nearest_hunter()
	threat = 0.0 if nearest == null else clampf(1.1 - nearest.position.distance_to(player.position) / 15.0, 0.14, 0.92)


func focus_hunter_audio(hunter: Node3D) -> void:
	if not is_instance_valid(sound) or hunter == null or audio_hunter == hunter: return
	for key in ["hunter_step", "warning", "deploy"]:
		var voice: Node3D = sound.cues[key]
		if voice.get_parent() != hunter: voice.reparent(hunter, false)
	sound.hunter_distance = 0.0
	audio_hunter = hunter


func record(index: int, message: String) -> void:
	var fresh: bool = not evidence[index]
	if fresh:
		sound.cue("collect")
	evidence[index] = true
	if fresh and phase == 1:
		pending_evidence.append(index)
		unbanked = true
	store_progress()
	say(message)
	if fresh:
		deploy_after_submission()


func press_keypad(key: String) -> void:
	if mode != "keypad":
		return
	match key:
		"back": keypad_entry = keypad_entry.left(-1)
		"enter":
			if keypad_entry == "7138":
				record(1, "配额账户：交易 X-71 / 交割增加 38 年。")
				sound.cue("success")
				set_mode("world")
			else:
				keypad_entry = ""
				say("校验失败。对照 D-09 的交易编号和扣除年数。")
				sound.cue("fail")
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
				sound.cue("collect")
			else:
				say("门框有一道撞痕。门禁机的编号是 V-17。")
		else:
			if not evidence[1]:
				evidence[1] = true
				evidence[2] = true
				unbanked = true
				sound.cue("collect")
				say("你认出了自己的笔迹：下次接到任务时，先别按确认。警告，清算外骨骼已启动。" if echo_run else "遗书：下次接到任务时，先别按确认。警告，清算外骨骼已启动。")
				pending_evidence.append_array([1, 2])
				deploy_after_submission()
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
			sound.cue("collect")
			say("林岑还活着：用事故前的求救线路。快，把授权记录送出去。")
			pending_evidence.append(2)
			deploy_after_submission()
			store_progress()
	else:
		say("B-17 门禁依旧在等待下一次复核。")


func inspect_relay() -> void:
	if chapter == 1 and phase == 0:
		record(0, "取回配额单。受益账户属于管理层。授权编号 A-42。")
	elif chapter == 2:
		if not solved:
			record(phase, "记录 E-7 开关位置。" if phase == 0 else "找到 E-7 线缆编号和站外中继。")
		elif phase == 0 and not armed:
			armed = true
			say("旧疏散广播已启动。换相后接上暮区 E-7。")
			activate_boss(station.GATES[1])
		elif phase == 1 and armed:
			if not patched:
				patched = true
				say("中继接通。回晨区调查台，外发完整账本。")
				deploy_after_submission()
			else:
				say("中继已接通，回晨区 A-01 外发。")
		else:
			say("需先在晨区合上应急开关。")
	else:
		say("R-03 应急中继。旧线路没有出现在站内网络图上。")


func objective() -> String:
	if phase == 1 and dusk_trials.active and not dusk_trials.completed:
		return dusk_trials.guidance()
	match chapter:
		0:
			if not evidence[0]: return "晨区 B-17：调查林岑的门禁记录。"
			if not evidence[1]: return "到 G 门按 E 换区，再查暮区 B-17。"
			return "回晨区 A-01：归档日志，核对事件。"
		1:
			if case_accepted: return "A-42 已签收。按 R 可撤销本轮接案。"
			if not evidence[1]: return "晨区 A-01：查看授权，暂缓签字。"
			if not evidence[0]: return "晨区 R-03：取得配额授权单。"
			if not evidence[2]: return "暮区 B-17：查看未签字的结果。"
			return "回晨区 A-01：核对授权与执行人。"
		3:
			if not evidence[0] or not evidence[1]: return "晨暮 C-04：各取一份同步记录。"
			return "回晨区 A-01：换算时间，判断先后。"
		4:
			if not evidence[0]: return "暮区 D-09：取得林岑的扣款凭证。"
			if not evidence[1] or not evidence[2]: return "晨暮 L-06：查同一交易的资金去向。"
			return "回晨区 A-01：核对 38 年的去向。"
		_:
			if upload > 0.0: return "站外传输中  //  剩余 %.1f 秒" % upload
			if patched: return "回晨区 A-01：发送完整账本。"
			if armed: return "暮区 R-03：接上 E-7 线缆。"
			if solved: return "晨区 R-03：合上 E-7 应急开关。"
			if not evidence[0] or not evidence[1]: return "晨暮 R-03：各取一份 E-7 线路记录。"
			return "回晨区 A-01：核验两份 E-7 线路记录。"


func guidance() -> String:
	if phase == 1 and dusk_trials.active and not dusk_trials.completed:
		return "沿地面发光箭头移动 · 靠近实体按 E · 世界不会暂停"
	if field_task.active:
		return "现场操作中 · 可移动躲避 · Esc 取消操作"
	if phase == 1 and gate_lock > 0.0:
		return "换相门封锁 %.1f 秒 · Shift 绕障碍 · F 断相" % gate_lock
	if map_phase != phase:
		return "Tab 只是地图预览；到 G 门按 E 才能换区。"
	if unbanked:
		return "现场记录尚未归档，先回晨区 A-01。"
	if boss_live and phase == 0 and upload <= 0.0:
		return "晨区暂时安全，可回 A-01 整理证据。"
	if boss_live:
		return "Shift 奔跑 · F 断相：需同区、无遮挡。"
	if chapter == 1 and case_accepted:
		return "R 撤销本轮签字，已归档证据不会丢失。"
	if chapter == 0 and not evidence[0]:
		return "WASD 移动 · 鼠标环视 · 靠近后按 E 调查。"
	return "Esc 暂停 · H 操作说明 · 戴耳机听脚步方向。"


func chapter_title() -> String:
	return CHAPTERS[chapter]


func evidence_lines() -> Array:
	var lines := []
	for index in range(3):
		if echo_run and chapter == 0 and index == 2 and evidence[index]:
			lines.append("你的回执背面：下次接到任务时，先别按确认。")
		else:
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
	if mode != "audit" or not puzzle_available() or chapter in [0, 3]:
		return
	if index != ANSWERS[chapter]:
		say(["对照门禁设备编号和同一次警报，两边的时钟各走各的。", "把配额单的受益人和操作日志的最后签收者分开看。", "寻找在两份记录中都出现的线路编号。", "先把暮区计时除以 1000，再与晨区记录比较。", "查找同一个交易号，并确认总账是否随站内复位。"][chapter])
		sound.cue("fail")
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
		sound.cue("fail")
		return
	complete_puzzle()


func timeline_key(key: String) -> void:
	if mode != "audit" or chapter != 3 or not puzzle_available(): return
	if key == "back":
		timeline_seconds = timeline_seconds.left(-1)
	elif key.length() == 1 and key in "0123456789" and timeline_seconds.length() < 4:
		timeline_seconds += key
	interface.queue_redraw()


func pick_timeline(event: String) -> void:
	if mode != "audit" or chapter != 3 or not puzzle_available() or event not in ["filing", "debit"]: return
	if event in timeline_order:
		timeline_order.erase(event)
	else:
		timeline_order.append(event)
	interface.queue_redraw()


func submit_timeline() -> void:
	if mode != "audit" or chapter != 3 or not puzzle_available(): return
	if not timeline_seconds.is_valid_int() or timeline_seconds.to_int() != 5 or timeline_order != ["debit", "filing"]:
		say("先用 1:1000 换成晨区秒数，再按先发生、后发生点选两张记录。")
		sound.cue("fail")
		return
	complete_puzzle()


func complete_puzzle() -> void:
	if chapter == 2:
		solved = true
		store_progress()
		set_mode("world")
		say("线路核验完成：晨区合上开关，暮区接上中继。")
		sound.cue("success")
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
	sound.cue("success")


func ready_to_send() -> bool:
	return chapter == 2 and phase == 0 and patched and upload <= 0.0


func begin_upload() -> void:
	if mode != "audit" or not ready_to_send():
		return
	stop_dusk_chase()
	upload = 6.0
	last_known = station.AUDIT
	path_timer = 0.0
	set_mode("world")
	say("站外传输中。六秒后，回执会写入审计匣。")
	sound.cue("archive")


func say(message: String) -> void:
	notice = message
	note_timer = 7.0


func shift(tile: Vector2i) -> void:
	if tile not in station.GATES:
		return
	if phase == 1 and gate_lock > 0.0:
		say("上传警报未解除：换相门还需 %.1f 秒解锁。" % gate_lock)
		return
	if upload > 0.0:
		say("上行连接尚未完成，请留在晨区等待回执。")
		return
	if shift_cooldown > 0.0:
		say("换相门正在同步，请稍候。")
		return
	if boss_live and boss_phase == phase and boss.position.distance_to(player.position) < 9.0:
		var index: int = station.GATES.find(tile)
		gate_observed[index % 2] += 1
	phase = 1 - phase
	map_phase = phase
	station.set_phase(phase)
	if phase == 0:
		stop_dusk_chase()
	player.position = station.point(tile) + Vector3.UP * 0.055
	player.velocity = Vector3.ZERO
	cross_gate = tile
	shift_cooldown = 1.35
	path_timer = 0.0
	sound.quiet()
	sound.cues.shift.pitch_scale = 0.95 if phase == 0 else 0.65
	sound.cue("shift")
	if phase == 1:
		if not boss_live: activate_boss(dusk_spawn_tile())
		if not dusk_grace_used:
			dusk_grace = 2.0
			dusk_grace_used = true
	else:
		boss.hide()
		threat = 0.0
	say("晨区暂时安全。回 A-01 归档、核验记录。" if phase == 0 else "暮区有清算单位巡逻。听脚步、绕开视线，别在门口久留。")


func dusk_spawn_tile() -> Vector2i:
	var origin: Vector2i = station.cell(player.position)
	for target in [station.LAB, station.LEDGER, station.RELAY, station.OFFICE]:
		var route: Array[Vector2i] = station.hunter_path(1, origin, target)
		if route.size() >= 9:
			return route[mini(10, route.size() - 1)]
	return station.RELAY


func activate_boss(tile: Vector2i) -> void:
	if boss_live or phase != 1:
		return
	boss_live = true
	boss_phase = 1
	boss_delay = 2.2
	boss.position = station.point(tile)
	last_known = tile
	tracking_time = 0.0
	patrol_index = 0
	path_timer = 0.0
	boss_route.clear()
	sound.cue("deploy")


func stop_dusk_chase() -> void:
	var had_hunter := boss_live or boss_chasing or not extra_hunters.is_empty()
	clear_extra_hunters()
	boss_chasing = false
	boss_live = false
	if had_hunter:
		sound.quiet()
	boss.hide()
	boss_route.clear()
	threat = 0.0
	stunned = 0.0
	charge_warning = 0.0
	charge_time = 0.0
	boss_delay = 0.0
	charge_recovery = 0.0
	tracking_time = 0.0
	path_timer = 0.0
	gate_lock = 0.0
	deployment_gate = -1
	station.laser_grid.clear()


func update_boss(delta: float, sprint: bool) -> void:
	boss_chasing = false
	if phase != 1 or boss_phase != 1:
		stop_dusk_chase()
		return
	var protected := dusk_grace > 0.0
	dusk_grace = maxf(0.0, dusk_grace - delta)
	boss_delay = maxf(0.0, boss_delay - delta)
	stunned = maxf(0.0, stunned - delta)
	charge_recovery = maxf(0.0, charge_recovery - delta)
	var distance := boss.position.distance_to(player.position)
	var same_phase := boss_phase == phase
	boss.visible = same_phase and boss_delay <= 0.8
	boss_eye.material_override = station.palette.blue if stunned > 0.0 else station.palette.red
	boss_lamp.light_color = Color("54c9ff") if stunned > 0.0 else Color("ff2455")
	threat = 0.2 if not same_phase else clampf(1.1 - distance / 15.0, 0.14, 0.92)
	if gate_lock > 0.0 and same_phase:
		var locked_cell: Vector2i = station.cell(player.position)
		if locked_cell != last_known: boss_route.clear()
		last_known = locked_cell
		tracking_time = maxf(tracking_time, 3.0)
		boss_chasing = true
	if boss_delay > 0.0 or stunned > 0.0:
		return
	var seen := same_phase and distance < 13.0 and has_sight()
	var locked := same_phase and gate_lock > 0.0
	tracking_time = maxf(0.0, tracking_time - delta)
	if locked or seen or (same_phase and sprint and distance < 10.5):
		var next_known: Vector2i = station.cell(player.position)
		if locked and next_known != last_known: boss_route.clear()
		last_known = next_known
		tracking_time = maxf(tracking_time, 3.0)
		if sprint and not seen:
			sprint_observed = 1
	boss_chasing = same_phase and (seen or tracking_time > 0.0 or upload > 0.0)
	var player_target := Vector3(player.position.x, 0, player.position.z)
	var direct_chase := (seen or locked) and boss_motion_fraction(boss.position, player_target) >= 1.0
	if direct_chase and distance < 1.10 and not protected and not dev_god:
		reset_lap("追债人完成结算。审计匣里的记录随你回到了开场。")
		return
	if charge_warning > 0.0:
		charge_warning -= delta
		if charge_warning <= 0.0:
			charge_time = 0.57
			charge_recovery = 5.5
		else:
			return
	elif same_phase and seen and not protected and distance > 2.5 and distance < 7.8 and charge_recovery <= 0.0 and charge_time <= 0.0:
		charge_warning = 0.78
		sound.cue("warning")
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
			sound.cue("deploy")
			return
	elif tactic == "cutoff" and gate_lock <= 0.0 and not seen and not sprint and upload <= 0.0:
		destination = station.GATES[tactic_gate]
	elif tactic == "guard" and gate_lock <= 0.0 and not seen and not sprint and upload <= 0.0:
		destination = station.GUARD
	elif not seen and tracking_time <= 0.0 and upload <= 0.0:
		var sweep: Array = [station.LAB, station.OFFICE, station.LEDGER, station.RELAY] + station.GATES
		if boss.position.distance_to(station.point(sweep[patrol_index])) < 0.25:
			patrol_index = (patrol_index + 1) % sweep.size()
		destination = sweep[patrol_index]
	path_timer -= delta
	var cell_at_boss: Vector2i = station.cell(boss.position)
	var center: Vector3 = station.point(cell_at_boss)
	var target := center
	if direct_chase:
		# Grid centers are only waypoints around obstacles, never the visible player's final position.
		target = player_target
		boss_route.clear()
	else:
		if boss_route.is_empty() or (path_timer <= 0.0 and boss.position.distance_to(center) < 0.22):
			boss_route = station.hunter_path(boss_phase, cell_at_boss, destination)
			if not boss_route.is_empty() and boss.position.distance_to(center) < 0.22:
				boss_route.pop_front()
			path_timer = 0.30
		if not boss_route.is_empty():
			target = station.point(boss_route[0])
		if locked and cell_at_boss == destination: target = player_target
		# Local fixtures can also obstruct an A* waypoint while the player is occluded.
		var local_target := player_target if seen else target
		if seen or boss_motion_fraction(boss.position, target) < 1.0:
			var detour := boss_detour_path(local_target)
			if detour.size() > 1: target = detour[1]
	if boss.position.distance_to(target) < 0.035:
		if not boss_route.is_empty():
			boss_route.pop_front()
		return
	boss.look_at(target, Vector3.UP)
	var speed := 7.2 if charge_time > 0.0 else (4.45 if upload > 0.0 else (3.77 if seen else 3.27))
	var next := boss.position.move_toward(target, speed * delta)
	boss.position = boss.position.lerp(next, boss_motion_fraction(boss.position, next))


func boss_motion_fraction(origin: Vector3, target: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = boss_body
	query.transform = Transform3D(Basis(), origin + Vector3.UP * 0.86)
	query.motion = target - origin
	query.margin = 0.005
	query.exclude = [player.get_rid()]
	query.collision_mask = WORLD_GEOMETRY_MASK
	var space := get_world_3d().direct_space_state
	# cast_motion ignores shapes already overlapping at the origin.
	if not space.intersect_shape(query, 1).is_empty(): return 0.0
	var safe: float = space.cast_motion(query)[0]
	return maxf(0.0, safe - 0.01 / maxf(query.motion.length(), 0.01)) if safe < 1.0 else 1.0


func boss_detour_path(target: Vector3) -> PackedVector3Array:
	return hunter_detour_path(boss.position, target, boss_phase)


func hunter_detour_path(origin: Vector3, target: Vector3, hunter_phase: int) -> PackedVector3Array:
	# Local visibility graph: shortest among these collision-checked neighboring waypoints.
	var route := AStar3D.new()
	route.add_point(0, origin)
	route.add_point(1, target)
	var tile: Vector2i = station.cell(origin)
	for z in range(-1, 2):
		for x in range(-1, 2):
			var candidate := tile + Vector2i(x, z)
			if not station.walkable(hunter_phase, candidate): continue
			var point: Vector3 = station.point(candidate)
			if point.distance_to(origin) < 0.05 or point.distance_to(target) < 0.05: continue
			route.add_point(route.get_point_count(), point)
	for first in range(route.get_point_count()):
		for second in range(first + 1, route.get_point_count()):
			if boss_motion_fraction(route.get_point_position(first), route.get_point_position(second)) >= 1.0:
				route.connect_points(first, second)
	return route.get_point_path(0, 1)


func has_sight() -> bool:
	return hunter_has_sight(boss.position)


func hunter_has_sight(origin: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 1.45, player.position + Vector3.UP * 1.32)
	query.exclude = [player.get_rid()]
	query.collision_mask = WORLD_GEOMETRY_MASK
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func pulse() -> void:
	if charges <= 0:
		say("本轮断相脉冲已用尽。")
		return
	var hits := 0
	if boss_live and boss_phase == phase and boss.visible and boss.position.distance_to(player.position) <= 7.0 and has_sight():
		stunned = 2.25
		charge_time = 0.0
		charge_warning = 0.0
		charge_recovery = 3.0
		hits += 1
	for hunter in extra_hunters:
		if phase == 1 and hunter.live and hunter.visible and hunter.position.distance_to(player.position) <= 7.0 and hunter_has_sight(hunter.position):
			hunter.pulse_stun()
			hits += 1
	if hits == 0:
		say("脉冲未锁定。需要与追债人在同一时态且无遮挡。")
		return
	# One area pulse, one charge, even when several visible hunters are affected.
	charges -= 1
	sound.cues.warning.stop()
	sound.cue("success")
	say("%d 名追债人失相。现在走。" % hits)


func threat_text() -> String:
	var nearest := nearest_hunter()
	var count := extra_hunters.size() + (1 if boss_live else 0)
	if nearest == null: return "当前时态安全"
	var prefix := "%d 名追债人 · " % count
	var active_stun: float = stunned if nearest == boss else nearest.stunned
	var warning: float = charge_warning if nearest == boss else nearest.charge_warning
	if active_stun > 0.0: return prefix + "最近失相 %.1f s" % active_stun
	if warning > 0.0: return prefix + "最近准备冲刺"
	if gate_lock > 0.0: return prefix + "警报精确追踪"
	return prefix + "最近 %.0f m" % nearest.position.distance_to(player.position)


func reset_lap(message: String) -> void:
	sound.quiet()
	clear_extra_hunters()
	station.laser_grid.clear()
	dusk_trials.clear()
	field_task.active = false
	task_committing = false
	gate_lock = 0.0
	deployment_gate = -1
	alignment_fields.clear()
	timeline_seconds = ""
	timeline_order.clear()
	dusk_grace = 0.0
	dusk_grace_used = false
	big_map = false
	laps += 1
	if boss_live:
		profile.choose_tactic(laps, gate_observed, sprint_observed)
	evidence = banked_evidence()
	pending_evidence.clear()
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
	boss_chasing = false
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
	profile.save_state({"chapter": chapter, "laps": laps, "evidence": banked_evidence(), "solved": solved, "cleared": cleared, "echo_run": echo_run})


func banked_evidence() -> Array:
	var banked := evidence.duplicate()
	if unbanked:
		for index in pending_evidence:
			banked[index] = false
		# Preserve the original office evidence rule for older callers.
		if chapter in [0, 1]:
			banked[2] = false
			if chapter == 0:
				banked[1] = false
	return banked


func apply_profile(data: Dictionary) -> void:
	# An outstanding backend read must not undo an explicitly chosen new investigation.
	if fresh_investigation:
		store_progress()
		return
	chapter = clampi(int(data.get("chapter", 0)), 0, 4)
	laps = maxi(1, int(data.get("laps", 1)))
	evidence = data.get("evidence", [false, false, false]).duplicate()
	solved = bool(data.get("solved", false))
	cleared = bool(data.get("cleared", false))
	echo_run = bool(data.get("echo_run", false))
	update_witness()
	if cleared and mode == "world" and time_in_lap < 0.3:
		set_mode("ending")


func apply_tactic(lap: int, strategy: String, gate: int, source: String) -> void:
	if lap == laps:
		tactic = strategy
		tactic_gate = clampi(gate, 0, 1)
		tactic_source = source


# ───────── 开发者模式（F1）：检验流程用 ─────────
func dev_key(code: Key) -> void:
	match code:
		KEY_F2: dev_next_chapter()
		KEY_F3: dev_teleport()
		KEY_F4:
			evidence = [true, true, true]
			unbanked = false
			store_progress()
			say("开发者：本章三条证据已取得。回 A-01 解谜。")
		KEY_F5:
			dev_god = not dev_god
			say("开发者：无敌 %s（追债人碰到不结算）" % ("开" if dev_god else "关"))
		KEY_F6:
			if boss_live or not extra_hunters.is_empty():
				stop_dusk_chase()
				say("开发者：追债人已撤回。")
			else:
				activate_boss(station.RELAY)
				say("开发者：追债人已在 R-03 部署（当前时态）。")
		KEY_F7:
			if chapter == 2 and solved:
				if not armed:
					armed = true
					say("开发者：E-7 晨区开关已合上。")
				elif not patched:
					patched = true
					say("开发者：E-7 暮区已接通。回晨区 A-01 外发。")
				else:
					cleared = true
					store_progress()
					set_mode("ending")
			else:
				evidence = [true, true, true]
				complete_puzzle()


func dev_next_chapter() -> void:
	var at := STORY_ORDER.find(chapter)
	chapter = STORY_ORDER[(at + 1) % STORY_ORDER.size()]
	evidence = [false, false, false]
	solved = false
	cleared = false
	reset_lap("开发者：跳到第 %s 章。" % chapter_title())


func dev_spots() -> Array:
	var spots := [["A-01 调查台", station.AUDIT], ["B-17 办公室", station.OFFICE], ["C-04 时钟实验室", station.LAB],
		["D-09 生命维持", station.MEDICAL], ["L-06 配额结算", station.LEDGER], ["R-03 应急中继", station.RELAY]]
	for index in range(station.GATES.size()):
		spots.append(["G-%02d 换相门" % (index + 1), station.GATES[index]])
	for entry in station.breaks_for(phase):
		if station.map_stage >= int(entry.stage):
			spots.append(["断点 %s" % entry.name, entry.tiles[entry.tiles.size() / 2]])
	return spots


func dev_teleport() -> void:
	stop_dusk_chase()
	var spots := dev_spots()
	dev_spot = (dev_spot + 1) % spots.size()
	var target: Vector2i = spots[dev_spot][1]
	var stand := target
	if not station.walkable(phase, stand):   # 断点墙本身不可走：站到旁边 3 格内最近的空地
		var best := 1 << 30
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				var spot: Vector2i = target + Vector2i(dx, dz)
				var d: int = absi(dx) + absi(dz)
				if station.walkable(phase, spot) and d >= 2 and d < best:
					best = d
					stand = spot
	player.position = station.point(stand) + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	if stand != target:
		var look: Vector3 = station.point(target)
		player.look_at(Vector3(look.x, player.position.y, look.z), Vector3.UP)
	camera.rotation.x = -0.1
	say("开发者：传送 → %s（%d/%d）" % [spots[dev_spot][0], dev_spot + 1, spots.size()])
