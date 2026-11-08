extends Node3D

const Sound := preload("res://audio.gd")
const Station := preload("res://station.gd")
const Interface := preload("res://interface.gd")
const Profile := preload("res://profile.gd")
const Exterior := preload("res://exterior.gd")
const HunterVisual := preload("res://hunter_visual.gd")
const Preferences := preload("res://preferences.gd")
var options := Preferences.new()
var settings_return := "menu"
var settings_notice := ""
var lap_hunter_count := 1
var hunter_intro_seen := false
const Prologue := preload("res://prologue.gd")
const HunterAgent := preload("res://hunter_agent.gd")
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
	["晨区 R-03  批准：管理层 / 受益：管理层 / A-42", "A-42 流程栏  接案确认 → 第三方复核 → 执行队列", "暮区 B-17  林岑在场证词 / 取证时 A-42 尚未复核"],
	["晨区 R-03  开关标记 E-7 / 线路图到此中断", "暮区 R-03  墙内线缆 E-7 / 指向站外中继", "审计匣  死亡凭证与扣款授权已核验。"],
	["晨区 C-04  寻人立案 / 脉冲后 6 晨秒", "暮区 C-04  扣款名单预登记 / 脉冲后 5000 暮秒", "同步规程  同一脉冲两表归零 / 1 晨秒 = 1000 暮秒"],
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
var evidence: Array = [false, false, false]
var alignment_fields: Array[String] = []
var timeline_seconds := ""
var timeline_order: Array[String] = []
var signature_pending := false
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
# 阶段 A：卡死诊断与有界恢复（保留调试观察，不是 Release F1 入口）
var boss_stall_time := 0.0          # 连续无进展时长（秒）
const BOSS_STALL_REPLAN := 1.2      # 持续 1.2s 无进展强制重规划
const BOSS_RECOVER_STEP := 0.18     # 起点重叠时单次推出步长（米）
const BOSS_RECOVER_MAX := 0.72      # 累计最大推出距离（米），超过放弃避免传送
var boss_route: Array[Vector2i] = []
var last_known: Vector2i = Station.LAB
var cross_gate: Vector2i = Station.GATES[0]
var gate_observed := [0, 0]   # 后端只认两扇门：北侧门记 0/1，南侧门按东西并入
var sprint_observed := 0
# 阶段 B：仅本轮运行时的体力，不写入 profile/数据库；重启与新轮回恢复满值
const STAMINA_MAX := 100.0
const STAMINA_DRAIN_RATE := 25.0
const STAMINA_REGEN_RATE := 100.0 / 6.0
const STAMINA_REGEN_DELAY := 1.25
const STAMINA_RESTART_THRESHOLD := 25.0
const PLAYER_WALK_SPEED := 4.45
const PLAYER_SPRINT_SPEED := 6.25
const BOSS_CHASE_SPEED := 5.2  # 候选实测值：使耗尽后的步行有压力；速度完整记录于交付参数表
var stamina := STAMINA_MAX
var stamina_regen_wait := 0.0
var stamina_exhausted := false
var actual_sprinting := false  # 唯一供脚步/敌人听觉/观测使用的有效冲刺状态
var tactic := "patrol"
var tactic_gate := 0
var tactic_source := "rules"
var sound: Node
var prologue: CanvasLayer
var optics: ShaderMaterial


func _ready() -> void:
	options.load_settings()
	lap_hunter_count = options.hunter_count
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
	sound.set_audio_levels(options.master_volume, options.effects_volume, options.alert_volume, options.ambience_volume)


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
	sound.update_music(delta,mode in ["menu","intro","world"],mode=="world" and (threat>0.35 or any_hunter_chasing()))
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
		station.animate_relay(delta)
	optics.set_shader_parameter("transition", clampf((shift_cooldown - 1.02) * 3.0, 0.0, 1.0))
	optics.set_shader_parameter("defocus", 1.0 if mode in ["audit", "keypad", "paused", "restart_confirm", "controls"] else 0.0)
	interface.queue_redraw()


func update_opening(delta: float) -> void:
	intro_time += delta
	exterior.animate(intro_time)


func has_progress() -> bool:
	return chapter > 0 or laps > 1 or evidence.has(true) or solved or cleared


func begin_intro() -> void:
	intro_time = 0.0
	intro_page = 0
	set_mode("intro")


func begin_prologue() -> void:
	if prologue == null:
		prologue = Prologue.new()
		add_child(prologue)
		prologue.video.bus = "CorrAmbience"
		prologue.video.volume_db = -8.0
		prologue.finished.connect(finish_prologue)
	set_mode("cinematic")
	if not prologue.play():
		# A missing media file must never block a new investigation.
		begin_intro()


func finish_prologue() -> void:
	if mode == "cinematic":
		begin_intro()


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
	if mode != "world": return
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := player.basis * Vector3(move.x, 0, move.y).normalized()
	var shift_held := Input.is_physical_key_pressed(KEY_SHIFT)
	var wants_sprint := shift_held and move.length_squared() > 0
	# 耗尽后必须松开 Shift 且恢复至 25%，禁止长按/连点在零附近闪烁冲刺。
	var sprint_intent := wants_sprint and not stamina_exhausted and stamina > 0.00001
	var speed := PLAYER_SPRINT_SPEED if sprint_intent else PLAYER_WALK_SPEED
	player.velocity = Vector3(direction.x * speed, -6.0, direction.z * speed)
	var previous_player := player.position
	player.move_and_slide()
	# 有效冲刺 = Shift + 有移动意图 + 真实地面位移；顶墙/原地按 Shift 不扣体力、不传奔跑听觉。
	var ground_distance := Vector2(player.position.x - previous_player.x, player.position.z - previous_player.z).length()
	var moved := player.is_on_floor() and move.length_squared() > 0 and ground_distance > 0.001
	apply_stamina_tick(delta, shift_held, moved)
	sound.player_moved(previous_player, player.position, player.is_on_floor(), actual_sprinting)
	if dusk_trials.update(delta, player.position, actual_sprinting, phase):
		sound.cue("success")
		say("场地操作已通过。返回原终端按 E 取证。")
	if player.position.y < -3.0:
		reset_lap("地板重力异常。审计匣已复原。")
		return
	if phase == 0 and upload <= 0.0:
		stop_dusk_chase()
	station.laser_grid.update(delta, phase, any_hunter_chasing(), player.position, boss.position, extra_hunter_positions())
	var lap_before := laps
	var previous_boss := boss.position
	if boss_live:
		update_boss(delta, actual_sprinting)
		boss_rig.update_motion(delta, boss.position.distance_to(previous_boss) / maxf(delta, 0.001), stunned > 0.0 or boss_delay > 0.0 or charge_warning > 0.0)
	if laps != lap_before: return
	update_extra_hunters(delta, actual_sprinting)
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
		# P1：上传中持续刷新中继面板倒计时
		for rig in station.relay_rigs:
			var lbl: Label3D = rig.status_label
			lbl.text = "TX %.1fs" % maxf(upload, 0.0)
		if upload <= 0.0 and mode == "world" and patched:
			stop_dusk_chase()
			cleared = true
			store_progress()
			set_mode("ending")
			sound.cue("success")
			sync_relay_visual()


func _input(event: InputEvent) -> void:
	if mode == "hunter_intro":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]:
			acknowledge_hunters()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if interface.button_at(event.position) == "ack_hunters": acknowledge_hunters()
		return
	if mode == "cinematic":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ESCAPE]:
			prologue.finish()
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
			if mode == "settings":
				handle_action("settings_back")
				return
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
			"settings":
				if event.physical_keycode == KEY_ENTER: handle_action("settings_back")
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
						pick_timeline("filing")
					elif event.physical_keycode == KEY_DOWN:
						pick_timeline("debit")
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
	if action.begins_with("setting_"):
		if mode != "settings": return
		var field := action.get_slice("_", 1)
		if field == "hunters":
			options.hunter_count = clampi(int(action.get_slice("_",2)),1,3)
		elif field in ["master","effects","alert","ambience"]:
			var property := field + "_volume"
			var change := 0.1 if action.get_slice("_",2) == "up" else -0.1
			options.set(property,clampf(float(options.get(property))+change,0.0,1.0))
		else: return
		sound.set_audio_levels(options.master_volume,options.effects_volume,options.alert_volume,options.ambience_volume)
		settings_notice = "已保存 · 人数从下一轮开始生效" if options.save_settings() == OK else "设置写入失败：当前会话有效，请检查目录权限"
		return
	match action:
		"settings":
			if mode not in ["menu","paused"]: return
			settings_return = mode
			settings_notice = ""
			set_mode("settings")
		"settings_back":
			if mode == "settings": set_mode(settings_return)
		"ack_hunters": acknowledge_hunters()
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
				hunter_intro_seen = false
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
				signature_pending = true
				interface.queue_redraw()
		"accept_cancel":
			if mode == "audit":
				signature_pending = false
				interface.queue_redraw()
		"accept_commit":
			if signature_pending and can_confirm_again():
				case_accepted = true
				update_witness()
				set_mode("world")
				say("A-42 复核回执已送入执行队列。可去暮区核对回执；R 返回本轮开始。")
		"loop": reset_lap("站外：收到。告诉我还有谁。")
		"restart_prompt":
			restart_return = mode
			set_mode("restart_confirm")
		"cancel_restart": set_mode(restart_return)
		"restart_case":
			if mode == "restart_confirm":
				hunter_intro_seen = false
				fresh_investigation = true
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
	get_viewport().disable_3d = next == "cinematic"
	boss_rig.animation.active = next == "world" and boss_live and boss.visible
	for hunter in extra_hunters:
		hunter.rig.animation.active = next == "world" and hunter.live and hunter.visible
	if mode == "audit" and next != "audit":
		signature_pending = false
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
	lap_hunter_count = options.hunter_count
	exterior.finish()
	camera.make_current()
	spawn_at_desk()
	set_mode("ending" if cleared else "world")
	if not cleared:
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
	sync_relay_visual()


# P1：同步 R-03 / E-7 中继装饰节点的视觉，与 game.relay_status 阶段一致
func sync_relay_visual() -> void:
	if is_instance_valid(station) and station.has_method("update_relay_state"):
		station.update_relay_state(solved, armed, patched, upload, cleared)


func audit_status_text() -> String:
	if cleared:
		return "站外回执 / 已收讫\n审计匣：记录保留"
	if chapter == 1:
		return "A-42 / 已复核\n回执已提交执行队列" if case_accepted else "A-42 / 待复核\n查看档案不产生签收回执"
	if chapter in [4, 2]:
		return "A-42 / 授权已核验\n审计匣：记录保留"
	return "任务 / 已签收\n前往 B-17 核对记录" if case_accepted else "任务 / 待签收\n寻找失联同事 林岑"


func audit_reflection() -> String:
	if chapter == 1:
		return "本轮签收已送执行；R 可返回本轮开始，已归档证据保留。" if case_accepted else "阅览与归档不产生复核回执。签收状态以本轮为准。"
	if chapter == 3:
		return "使用同一脉冲起点，将两份记录统一为晨秒再比较。"
	if chapter in [4, 2]:
		return "站内可以复位；已经交割的账目，却留在站外。"
	return "把两份记录带回来。审计匣会保留你已经核验的证据。"


func authorization_fields() -> Array[String]:
	if chapter != 1 or not evidence[1]:
		return []
	return [
		"复核岗位：接案调查员  /  回执来源：确认接案",
		"当前回执：已送执行队列" if case_accepted else "当前回执：待签收  /  阅览不改变流程状态",
		"现场核验窗口：暮区 B-17  /  执行队列处理后关闭",
	]


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
			return "[E] 阅览授权档案 / A-01"
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
		consume_relay_activations()
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
			record(phase, "C-04 本地记录已取回。记录用本区秒数；同步规程可在 A-01 查阅。")
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
	var safe_tile := safe_hunter_spawn([])
	if not station.walkable(1,safe_tile):
		boss_live = false
		return
	boss.position = station.point(safe_tile)
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
	say(notice + "\n安全点部署共 %d 名追债人；换相门封锁 %.0f 秒。%s" % [1 + extra_hunters.size(), gate_lock, hunter_spawn_report])
	show_hunter_intro()

func show_hunter_intro() -> void:
	if mode != "world" or hunter_intro_seen or not boss_live or extra_hunters.is_empty(): return
	hunter_intro_seen = true
	set_mode("hunter_intro")

func acknowledge_hunters() -> void:
	if mode != "hunter_intro": return
	set_mode("world")
	sound.cue("deploy")


# Relay restarts create one local encounter each; active lamps cannot be refreshed.
# Retire the oldest relay encounter on retry so expired lamps cannot grow an army.
func consume_relay_activations() -> void:
	var events: Array[int] = dusk_trials.relay_activation_events.duplicate()
	dusk_trials.relay_activation_events.clear()
	if phase != 1: return
	for index in events:
		if spawn_relay_hunter():
			continue
		# Deployment is part of activation: roll back the lamp if no safe actor can spawn.
		if index >= 0 and index < dusk_trials.relay_timers.size():
			dusk_trials.relay_timers[index] = 0.0
			dusk_trials._sync_relay_progress()
		dusk_trials.completed = false
		dusk_trials._refresh()
		dusk_trials.message = "当前位置没有安全部署点，电源柱已关闭；重新启动会重试追债信号。"
		say(dusk_trials.message)
	show_hunter_intro()


func relay_hunter_spawn() -> Vector3:
	var here := Vector3(player.position.x, 0, player.position.z)
	var relay_hunters: Array[Node3D] = []
	var occupied_positions: Array[Vector3] = []
	for other in extra_hunters:
		if other.has_meta("relay_power") and other.live:
			relay_hunters.append(other)
	var replace_oldest: Node3D = relay_hunters[0] if relay_hunters.size() >= 3 else null
	if boss_live and boss_phase == 1:
		occupied_positions.append(boss.position)
	for other in extra_hunters:
		if other.live and other != replace_oldest:
			occupied_positions.append(other.position)
	# Sweep the player's actual collision mask: player-only lasers also block escape.
	var escapes: Array[Vector3] = []
	for step in range(16):
		var direction := Vector3(cos(float(step) * TAU / 16.0), 0, sin(float(step) * TAU / 16.0))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = boss_body
		query.transform = Transform3D(Basis.IDENTITY, here + Vector3.UP * 0.86)
		query.motion = direction * 5.0
		query.margin = 0.005
		query.exclude = [player.get_rid()]
		query.collision_mask = PLAYER_COLLISION_MASK
		var space := get_world_3d().direct_space_state
		if not space.intersect_shape(query, 1).is_empty() or space.cast_motion(query)[0] < 1.0:
			continue
		var occupied := false
		for other in occupied_positions:
			var along := clampf((other - here).dot(direction), 0.0, 5.0)
			if other.distance_to(here + direction * along) < 1.15:
				occupied = true
		if not occupied:
			escapes.append(direction)
	if escapes.is_empty():
		return Vector3.INF
	var candidates: Array[Dictionary] = []
	# Dense annular sampling avoids the old 2 m lattice missing narrow clear lanes.
	for z in range(-12, 13):
		for x in range(-12, 13):
			var position := here + Vector3(x, 0, z)
			var distance := position.distance_to(here)
			if distance < 7.0 or distance > 12.0: continue
			if not station.walkable(1, station.cell(position)): continue
			var occupied := false
			for other in occupied_positions:
				if other.distance_to(position) < 4.0:
					occupied = true
			if occupied: continue
			var escape := false
			for direction in escapes:
				if direction.dot((here - position).normalized()) >= 0.15:
					escape = true
					break
			if not escape: continue
			var in_view := camera.is_position_in_frustum(position + Vector3.UP * 1.3)
			candidates.append({"position": position, "score": absf(distance - 9.0) + (0.0 if in_view else 1000.0)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	for candidate in candidates:
		var position: Vector3 = candidate.position
		if boss_motion_fraction(position, position) < 1.0 or not hunter_has_sight(position): continue
		# Direct unobstructed capsule travel is already a valid bounded pursuit route.
		if boss_motion_fraction(position, here) >= 1.0:
			return position
		var route := hunter_spawn_route(position, here)
		if route.size() >= 2 and route_world_length(route) <= 18.0:
			return position
	return Vector3.INF


func spawn_relay_hunter() -> bool:
	var position := relay_hunter_spawn()
	if position == Vector3.INF:
		return false
	var relay_hunters: Array[Node3D] = []
	for other in extra_hunters:
		if other.has_meta("relay_power") and other.live: relay_hunters.append(other)
	if relay_hunters.size() >= 3:
		var oldest := relay_hunters[0]
		focus_hunter_audio(boss)
		oldest.live = false
		oldest.hide()
		extra_hunters.erase(oldest)
		oldest.queue_free()
	var hunter := HunterAgent.new()
	hunter.name = "RelayHunter"
	hunter.set_meta("relay_power", true)
	add_child(hunter)
	hunter.position = position
	hunter.delay = 0.8
	hunter.charge_recovery = 3.0
	hunter.last_known = station.cell(player.position)
	hunter.target_position = Vector3(player.position.x, 0, player.position.z)
	hunter.tracking_time = 12.0
	hunter.eye.material_override = station.palette.red
	extra_hunters.append(hunter)
	focus_hunter_audio(hunter)
	sound.cue("deploy")
	refresh_hunter_threat()
	if not camera.is_position_in_frustum(position + Vector3.UP * 1.3):
		var local: Vector3 = camera.global_basis.inverse() * (hunter.global_position - camera.global_position)
		var direction := "右侧" if local.x >= 0.0 else "左侧"
		if local.z > 0.0:
			direction += "后方"
		say(notice + "\n追债人已在%s接入；已响起方位警报。" % direction)
	return true


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
	if lap_hunter_count <= 1:
		hunter_spawn_report = "标准模式：一名追债人"
		return
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
	for count in range(lap_hunter_count - 1):
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
	hunter_spawn_report = "附近没有额外安全点，保留一名。" if extra_hunters.size() < lap_hunter_count - 1 else "绕开来路，再回晨区归档。"


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
				say("遗书：下次接到任务时，先别按确认。警告，清算外骨骼已启动。")
				pending_evidence.append_array([1, 2])
				deploy_after_submission()
			else:
				say("遗书是你的笔迹。两份日志里的警报声完全一样。")
		store_progress()
	elif chapter == 1 and phase == 1:
		if case_accepted:
			say("暮区 B-17：林岑的生命维持已被扣款中止。本轮没有取得在场证词；R 返回本轮开始。")
			activate_boss(station.RELAY)
			return
		if not evidence[2]:
			evidence[2] = true
			unbanked = true
			sound.cue("collect")
			say("在场证词已记录。林岑：他们还没收到复核回执。用事故前的求救线路，调度台网络归他们管。")
			pending_evidence.append(2)
			deploy_after_submission()
			store_progress()
	else:
		say("B-17 门禁依旧在等待下一次复核。")


func inspect_relay() -> void:
	if chapter == 1 and phase == 0:
		record(0, "A-42 配额单：批准栏为管理层，受益账户为管理层；执行栏等待第三方复核。")
	elif chapter == 2:
		if not solved:
			record(phase, "记录 E-7 开关位置。" if phase == 0 else "找到 E-7 线缆编号和站外中继。")
		elif phase == 0 and not armed:
			armed = true
			say("旧疏散广播已启动。换相后接上暮区 E-7。")
			activate_boss(station.GATES[1])
			sync_relay_visual()
		elif phase == 1 and armed:
			if not patched:
				patched = true
				say("中继接通。回晨区调查台，外发完整账本。")
				deploy_after_submission()
				sync_relay_visual()
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
			if case_accepted: return "A-42 已送执行。可在暮区 B-17 核对现场回执。"
			if not evidence[1]: return "晨区 A-01：阅览 A-42 授权流程。"
			if not evidence[0]: return "晨区 R-03：取得配额授权单。"
			if not evidence[2]: return "暮区 B-17：补充现场记录。"
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
		if dusk_trials.kind == "relay":
			return "三柱位置见小地图 · E 启动 · Shift 短冲刺 · F 断相"
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
		return "Shift 短冲刺消耗体力 · F 断相：需同区、无遮挡。"
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
		lines.append(RECORDS[chapter][index] if evidence[index] else "未取得 · 记录 %02d" % (index + 1))
	return lines


func puzzle_available() -> bool:
	return not solved and not evidence.has(false)


func puzzle_question() -> String:
	return QUESTIONS[chapter]


func puzzle_choices() -> Array:
	return CHOICES[chapter]


func can_confirm_again() -> bool:
	return mode == "audit" and chapter == 1 and evidence[1] and not case_accepted and not evidence[2]


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
	if timeline_seconds.is_empty():
		say("换算栏尚未填写。请填写暮区记录对应的晨秒数。")
		sound.cue("fail")
		return
	if timeline_order.size() != 2:
		say("排序尚未完成。按先后各点选一张事件卡；再次点选可撤回。")
		sound.cue("fail")
		return
	if not timeline_seconds.is_valid_int() or timeline_seconds.to_int() != 5 or timeline_order != ["debit", "filing"]:
		say("两份记录尚未对齐。核对同步规程、填写单位和所选顺序。")
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
		sync_relay_visual()
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
	upload = 30.0
	last_known = station.cell(player.position)
	path_timer = 0.0
	set_mode("world")
	deploy_upload_hunter()
	say("上行警报已触发晨区清算单位。保持移动，撑过三十秒传输；换相暂不可用。")
	sound.cue("archive")
	sync_relay_visual()


func deploy_upload_hunter() -> void:
	var best := Vector3.INF
	var best_score := INF
	var here: Vector2i = station.cell(player.position)
	for y in range(here.y - 4, here.y + 5):
		for x in range(here.x - 4, here.x + 5):
			var tile := Vector2i(x, y)
			if not station.walkable(0, tile): continue
			var point: Vector3 = station.point(tile)
			var distance := point.distance_to(player.position)
			if distance < 8.0 or distance > 16.0: continue
			if boss_motion_fraction(point, point) < 1.0: continue
			var route: Array = station.hunter_path(0, tile, here)
			if route.is_empty() or route.size() > 7: continue
			var score := absf(distance - 10.0) + (0.0 if hunter_has_sight(point) else 20.0)
			if score < best_score:
				best = point
				best_score = score
	if best == Vector3.INF:
		# The authored A-01 corridor supplies these candidates; never force an overlap.
		return
	boss.position = best
	boss_phase = 0
	boss_live = true
	boss_chasing = true
	boss_delay = 0.8
	dusk_grace = 0.8
	charge_recovery = 1.5
	tracking_time = 31.0
	boss_route.clear()
	boss_stall_time = 0.0
	boss.show()
	focus_hunter_audio(boss)
	sound.cue("deploy")


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
	say("晨区暂时安全。回 A-01 归档、核验记录。" if phase == 0 else "暮区已部署 %d/%d 名追债人。%s 听脚步与警报，别在门口久留。" % [(1 if boss_live else 0)+extra_hunters.size(),lap_hunter_count,hunter_spawn_report])


var previous_spawn := Vector2i(-1,-1)
var spawn_rng := RandomNumberGenerator.new()

func safe_hunter_spawn(reserved: Array) -> Vector2i:
	var origin: Vector2i = station.cell(player.position)
	var candidates: Array[Vector2i] = []
	for z in range(1,station.MAP_SIZE.y-1):
		for x in range(1,station.MAP_SIZE.x-1):
			var tile := Vector2i(x,z)
			if not station.walkable(1,tile) or tile == previous_spawn or tile in reserved: continue
			var point: Vector3 = station.point(tile)
			if point.distance_to(player.position) < 28.0 or point.distance_to(player.position) > 64.0: continue
			var blocked := false
			for gate in station.GATES:
				if point.distance_to(station.point(gate)) < 8.0: blocked = true
			for other in reserved:
				if point.distance_to(station.point(other)) < 8.0: blocked = true
			if not blocked: candidates.append(tile)
	spawn_rng.randomize()
	while not candidates.is_empty():
		var index := spawn_rng.randi_range(0,candidates.size()-1)
		var tile: Vector2i = candidates[index]
		candidates.remove_at(index)
		if boss_motion_fraction(station.point(tile),station.point(tile)) < 1.0: continue
		var route: Array = station.hunter_path(1,origin,tile)
		if route.size() < 9 or route.size() > 25: continue
		previous_spawn = tile
		return tile
	# Fall back to a reachable authored point only when random candidates are exhausted.
	for target in [station.LAB, station.LEDGER, station.RELAY, station.OFFICE]:
		var route: Array[Vector2i] = station.hunter_path(1, origin, target)
		if route.size() >= 9:
			var tile: Vector2i = route[mini(10,route.size()-1)]
			if boss_motion_fraction(station.point(tile),station.point(tile)) == 1.0: return tile
	return Vector2i(-1,-1)

func dusk_spawn_tile() -> Vector2i:
	return safe_hunter_spawn([])


func activate_boss(tile: Vector2i) -> void:
	if boss_live or phase != 1 or not station.walkable(1,tile):
		return
	boss_live = true
	boss_phase = 1
	boss_delay = 2.2
	boss.position = station.point(tile)
	last_known = tile
	tracking_time = 0.0
	patrol_index = 0
	path_timer = 0.0
	boss_stall_time = 0.0
	boss_route.clear()
	deploy_extra_hunters()
	sound.cue("deploy")
	show_hunter_intro()


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
	if boss_phase != phase or (phase != 1 and not (phase == 0 and upload > 0.0)):
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
	if same_phase and boss_motion_fraction(boss.position, boss.position) < 0.001:
		var recovered := try_boss_overlap_recovery(boss.position)
		if recovered != boss.position:
			boss.position = recovered
			boss_stall_time = 0.0
			boss_route.clear()
			return
	var seen := same_phase and distance < 13.0 and has_sight()
	var locked := same_phase and (gate_lock > 0.0 or upload > 0.0)
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
		# 阶段 A：持续无进展时无视格心距离强制重规划
		var stalled_replan := boss_stall_time >= BOSS_STALL_REPLAN
		if boss_route.is_empty() or stalled_replan or (path_timer <= 0.0 and boss.position.distance_to(center) < 0.22):
			boss_route = station.hunter_path(boss_phase, cell_at_boss, destination)
			if not boss_route.is_empty() and boss.position.distance_to(center) < 0.22:
				boss_route.pop_front()
			path_timer = 0.30
			if stalled_replan:
				boss_stall_time = 0.0  # 重规划后清零，避免每帧都重算
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
	var speed := 7.2 if charge_time > 0.0 else (4.45 if upload > 0.0 else (BOSS_CHASE_SPEED if seen else 3.27))
	var next := boss.position.move_toward(target, speed * delta)
	var prev_pos := boss.position
	boss.position = boss.position.lerp(next, boss_motion_fraction(boss.position, next))
	# 阶段 A：跟踪"应该移动但无进展"
	var progressed := prev_pos.distance_to(boss.position) > 0.0005
	if progressed:
		boss_stall_time = 0.0
	else:
		boss_stall_time += delta


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


# 阶段 A：起点胶囊轻微重叠时的有界安全恢复
# 沿 8 个水平方向尝试小步推出，找到第一个不重叠的位置
# 不传送：单次推出 ≤ BOSS_RECOVER_MAX（0.72m），且只在 capsule 不再 overlap 时接受
# 不修改碰撞体、不关闭碰撞检查、不穿越墙体
func try_boss_overlap_recovery(origin: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = boss_body
	var start := origin + Vector3.UP * 0.86
	query.transform = Transform3D(Basis(), start)
	query.margin = 0.005
	query.exclude = [player.get_rid()]
	var ignored: Array[RID] = [player.get_rid()]
	for hit in space.intersect_shape(query):
		if not ignored.has(hit.rid): ignored.append(hit.rid)
	# 8 个水平方向 + 优先朝当前 tile 中心（更可能回到走廊）
	var tile_center: Vector3 = station.point(station.cell(origin))
	var to_center := (tile_center - origin)
	to_center.y = 0.0
	var directions: Array[Vector3] = []
	if to_center.length() > 0.01:
		directions.append(to_center.normalized())
	for angle in [0.0, PI/4, PI/2, PI*3/4, PI, PI*5/4, PI*3/2, PI*7/4]:
		directions.append(Vector3(cos(angle), 0, sin(angle)))
	for step in range(1, int(BOSS_RECOVER_MAX / BOSS_RECOVER_STEP) + 1):
		for dir in directions:
			var offset := dir * (step * BOSS_RECOVER_STEP)
			var candidate := origin + offset
			if not station.walkable(boss_phase, station.cell(candidate)): continue
			query.transform.origin = start + offset
			query.exclude = [player.get_rid()]
			if not space.intersect_shape(query, 1).is_empty(): continue
			# Ignore only initial contacts in the sweep, but never cross a wall with the body center.
			var ray := PhysicsRayQueryParameters3D.create(start, start + offset, 1, [player.get_rid()])
			if not space.intersect_ray(ray).is_empty(): continue
			query.transform.origin = start
			query.exclude = ignored
			query.motion = offset
			var safe := space.cast_motion(query)[0]
			query.motion = Vector3.ZERO
			if safe >= 1.0: return candidate
	return origin  # 有界尝试失败：放弃，不强行传送


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


func apply_stamina_tick(delta: float, shift_held: bool, moved: bool) -> void:
	# 测试与物理循环共用：只有 Shift+有效位移才扣；耗尽后必须松开才解锁。
	var wants := shift_held and moved
	if wants and not stamina_exhausted and stamina > 0.0:
		var sprint_time := minf(delta, stamina / STAMINA_DRAIN_RATE)
		stamina = maxf(0.0, stamina - STAMINA_DRAIN_RATE * sprint_time)
		stamina_regen_wait = STAMINA_REGEN_DELAY
		if stamina <= 0.00001:
			stamina = 0.0
			stamina_exhausted = true
			actual_sprinting = false
			stamina_regen_wait = STAMINA_REGEN_DELAY
		else:
			actual_sprinting = true
		return
	else:
		actual_sprinting = false
		var regen_time := maxf(0.0, delta - stamina_regen_wait)
		stamina_regen_wait = maxf(0.0, stamina_regen_wait - delta)
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN_RATE * regen_time)
		if stamina_exhausted and stamina >= STAMINA_RESTART_THRESHOLD and not shift_held:
			stamina_exhausted = false


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
	if active_stun > 0.0: return prefix + "已失相 %.1f s" % active_stun
	if warning > 0.0: return prefix + "准备冲刺"
	if gate_lock > 0.0: return prefix + "警报精确追踪"
	return prefix + "注意脚步与警报"


func reset_lap(message: String) -> void:
	lap_hunter_count = options.hunter_count
	sound.quiet()
	clear_extra_hunters()
	station.laser_grid.clear()
	dusk_trials.clear()
	field_task.active = false
	task_committing = false
	gate_lock = 0.0
	deployment_gate = -1
	signature_pending = false
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
	boss_stall_time = 0.0
	stunned = 0.0
	charge_warning = 0.0
	charge_time = 0.0
	charge_recovery = 0.0
	gate_observed = [0, 0]
	sprint_observed = 0
	stamina = STAMINA_MAX
	stamina_regen_wait = 0.0
	stamina_exhausted = false
	actual_sprinting = false
	spawn_at_desk()
	set_mode("world")
	store_progress()
	say(message)
	sync_relay_visual()


func save_label() -> String:
	return profile.status if is_instance_valid(profile) else "正在读取审计匣"


func store_progress() -> void:
	profile.save_state({"chapter": chapter, "laps": laps, "evidence": banked_evidence(), "solved": solved, "cleared": cleared})


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
