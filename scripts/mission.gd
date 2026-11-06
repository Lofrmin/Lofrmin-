extends Node2D
## All simulation coordinates use the 1600 x 960 design canvas.
const CYAN = Color("67e8f9")
const WHITE = Color("e4f4ff")
const MUTED = Color("7896ac")
const ORANGE = Color("ffad72")
const RED = Color("ff6478")
const EARTH = Vector2(824, 466)
const RADIUS = 207.0
const START_RECT = Rect2(46, 808, 280, 56)
const CAMERA_RECT = Rect2(1290, 34, 268, 44)
const PAUSE_RECT = Rect2(1172, 34, 98, 44)
var font := SystemFont.new()
var mono: Font = SystemFont.new()
var earth_material: ShaderMaterial
var jupiter_material: ShaderMaterial
var jupiter_rect: ColorRect
var stars: Array[Vector3] = []
var engines: Array[Vector2] = []
var rocks: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var rng = RandomNumberGenerator.new()
var udp = PacketPeerUDP.new()
var time = 0.0
var mission_time = 0.0
var stage_time = 0.0
var stage = 0 # 0 standby, 1 ignition, 2 defense, 3 escape, 4 victory, 5 failed
var integrity = 100.0
var energy = 100.0
var heat = 0.0
var ignition = 0.0
var escape_progress = 0.0
var cooldown = 0.0
var spawn_clock = 0.0
var intercepted = 0
var aim = Vector2(1020, 440)
var shield = false
var thrust = 0.0
var paused = false
var muted = false
var camera_enabled = false
var camera_last = -100.0
var bridge_last = -100.0
var camera_data: Dictionary = {}
var camera_message = "尚未连接摄像头"
var toast = "指挥系统就绪。等待领航员接管。"
var toast_timer = 5.0
var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var audio_phase = 0.0
var tone = 0.0
var tone_volume = 0.0
var frame_count = 0
var test_mode = false
var capture_mode = false
var test_done = false
var bridge_test = false

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	mono.font_names = PackedStringArray(["Consolas", "Courier New"])
	rng.seed = 20750215
	for i in range(490):
		stars.append(Vector3(rng.randf_range(0, 1600), rng.randf_range(80, 960), rng.randf_range(.25, 1.8)))
	var star_mesh = MultiMesh.new()
	star_mesh.transform_format = MultiMesh.TRANSFORM_2D
	star_mesh.use_colors = true
	var quad = QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	star_mesh.mesh = quad
	star_mesh.instance_count = stars.size()
	for i in range(stars.size()):
		var star = stars[i]
		star_mesh.set_instance_transform_2d(i, Transform2D(0, Vector2.ONE * star.z, 0, Vector2(star.x, star.y)))
		star_mesh.set_instance_color(i, Color(.65, .83, 1, .2 + star.z * .2))
	var starfield = MultiMeshInstance2D.new()
	starfield.multimesh = star_mesh
	starfield.z_index = -8
	add_child(starfield)
	for i in range(36):
		var p = Vector2(rng.randf_range(-.85, .75), rng.randf_range(-.72, .75))
		if p.length() < .88:
			engines.append(p * RADIUS)
	add_planet(true, Vector2(1030, -235), Vector2(1030, 1030))
	add_planet(false, EARTH - Vector2.ONE * 252, Vector2.ONE * 504)
	var error = udp.bind(19750, "127.0.0.1")
	if error != OK:
		camera_message = "手势端口被占用，请关闭其他游戏实例"
	var bg = ColorRect.new()
	bg.size = Vector2(1600, 960)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgmat = ShaderMaterial.new()
	bgmat.shader = preload("res://shaders/space.gdshader")
	bg.material = bgmat
	add_child(bg)
	init_audio()
	var args = OS.get_cmdline_user_args()
	test_mode = "--self-test" in args
	capture_mode = "--capture" in args
	bridge_test = "--bridge-test" in args
	if bridge_test: camera_enabled = true
	if capture_mode:
		begin_mission()
		stage = 2
		ignition = 100
		announce("碎片群接近！点击目标拦截；右键 / 空格展开护盾。", 20)
		for i in range(5): spawn_rock()

func add_planet(gas: bool, pos: Vector2, dimensions: Vector2) -> void:
	var rect = ColorRect.new()
	rect.position = pos
	rect.size = dimensions
	rect.z_index = -5 if gas else -2
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/planet.gdshader")
	mat.set_shader_parameter("gas_giant", gas)
	mat.set_shader_parameter("surface_map", preload("res://assets/earth.jpg"))
	mat.set_shader_parameter("clouds", preload("res://assets/clouds.png"))
	rect.material = mat
	add_child(rect)
	if gas:
		jupiter_material = mat
		jupiter_rect = rect
	else: earth_material = mat

func init_audio() -> void:
	if DisplayServer.get_name() == "headless": return
	audio_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = .15
	audio_player.stream = generator
	audio_player.volume_db = -16
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()

func update_audio(delta: float) -> void:
	if not audio_playback: return
	var count = mini(audio_playback.get_frames_available(), 4096)
	for i in range(count):
		audio_phase += 1.0 / 22050.0
		var value = sin(audio_phase * TAU * 43) * .035 + sin(audio_phase * TAU * 65) * .015
		value += sin(audio_phase * TAU * (70 + thrust * 45)) * thrust * .07
		value += sin(audio_phase * TAU * tone) * tone_volume
		if muted or paused: value = 0
		audio_playback.push_frame(Vector2(value, value))
	tone_volume = move_toward(tone_volume, 0, delta * .8)

func signal_sound(frequency: float = 740, volume: float = .2) -> void:
	tone = frequency
	tone_volume = volume

func begin_mission() -> void:
	stage = 1
	stage_time = 0
	mission_time = 0
	integrity = 100
	energy = 100
	heat = 0
	ignition = 0
	escape_progress = 0
	intercepted = 0
	spawn_clock = 0
	paused = false
	rocks.clear()
	sparks.clear()
	beams.clear()
	announce("第一阶段 / 按住 SHIFT 或双手拉开，重启行星发动机。", 8)
	signal_sound()

func announce(message: String, duration: float = 4.0) -> void:
	toast = message
	toast_timer = duration

func transition(next_stage: int) -> void:
	stage = next_stage
	stage_time = 0
	signal_sound(980, .25)
	if stage == 2:
		energy = 100
		announce("碎片群接近！点击目标拦截；右键 / 空格展开护盾。", 8)
	elif stage == 3:
		rocks.clear()
		announce("逃逸窗口开启！光标跟随导航环，按住 SHIFT 推进。", 8)
	elif stage == 4:
		rocks.clear()
		announce("我们没有失去希望。地球，正在驶向新的黎明。", 100)
	elif stage == 5:
		announce("地球防线失守。按 R 重新执行领航任务。", 100)

func _process(delta: float) -> void:
	time += delta
	frame_count += 1
	read_camera()
	if not paused:
		cooldown = maxf(0, cooldown - delta)
		toast_timer = maxf(0, toast_timer - delta)
		update_input(delta)
		if stage > 0 and stage < 4:
			simulate(delta)
		update_effects(delta)
	update_audio(delta)
	earth_material.set_shader_parameter("rotation", .18 + time * .004)
	earth_material.set_shader_parameter("engine_power", thrust)
	jupiter_material.set_shader_parameter("rotation", time * .001)
	jupiter_rect.position.x = 1030 + escape_progress * 2.0
	queue_redraw()
	if test_mode and not test_done:
		run_self_test()
	if bridge_test and camera_active():
		assert(int(camera_data.hands) == 2 and bool(camera_data.pinch), "Native game must decode gesture packet")
		assert(float(camera_data.thrust) > .7, "Native game must receive thrust")
		print("NATIVE_BRIDGE_TEST_PASS: actual Godot UDP receiver decoded hands, pinch, thrust")
		get_tree().quit()
	elif bridge_test and time > 10:
		push_error("Native bridge test timed out")
		get_tree().quit(1)
	if capture_mode and frame_count == 90:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://preview.png")
		print("CAPTURE_SAVED")
		print("Average rendered FPS: ", frame_count / time)
		print("Process ms: ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000, " Draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		get_tree().quit()

func _exit_tree() -> void:
	if audio_player: audio_player.stop()
	audio_playback = null
	udp.close()

func read_camera() -> void:
	while udp.get_available_packet_count() > 0:
		var packet = JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if packet is Dictionary:
			udp.set_dest_address("127.0.0.1", udp.get_packet_port())
			udp.put_packet("HELIOS_ACK".to_utf8_buffer())
			camera_data = packet
			bridge_last = time
			camera_message = str(packet.get("status", "摄像头已连接"))
			if int(packet.get("hands", 0)) > 0:
				camera_last = time
	if camera_enabled and time - bridge_last > 5:
		camera_message = "等待浏览器连接 · 可继续鼠标操作"

func camera_active() -> bool:
	return camera_enabled and time - camera_last < .45 and int(camera_data.get("hands", 0)) > 0

func update_input(delta: float) -> void:
	var target = get_global_mouse_position()
	var fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var defense = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_SPACE)
	var power = 1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0
	if camera_active():
		target = Vector2(float(camera_data.get("x", .5)) * 1600, float(camera_data.get("y", .5)) * 960)
		fire = bool(camera_data.get("pinch", false))
		defense = bool(camera_data.get("open", false)) and int(camera_data.get("hands", 0)) == 1
		power = float(camera_data.get("thrust", 0))
	aim = aim.lerp(target.clamp(Vector2(350, 120), Vector2(1260, 775)), 1 - exp(-delta * 15))
	thrust = move_toward(thrust, power, delta * 2)
	shield = defense and energy > 3 and stage > 0 and stage < 4
	if fire and cooldown <= 0 and stage == 2 and not START_RECT.has_point(get_global_mouse_position()) and get_global_mouse_position().y > 100:
		shoot()

func navigation_target() -> Vector2:
	return EARTH + Vector2(cos(time * .24) * 235, -180 + sin(time * .34) * 50)

func simulate(delta: float) -> void:
	mission_time += delta
	stage_time += delta
	energy = clampf(energy + delta * (9 if not shield else -21), 0, 100)
	heat = clampf(heat + delta * (thrust * 22 - 13), 0, 100)
	if heat >= 98:
		thrust = 0
		ignition = maxf(0, ignition - 8 * delta)
		integrity -= delta * 1.8
		if toast_timer < 1: announce("反应堆过热！松开推进，等待冷却。", 2)
	if stage == 1:
		ignition = clampf(ignition + delta * thrust * (8.5 if heat < 98 else 0), 0, 100)
		if ignition >= 100: transition(2)
	elif stage == 2:
		spawn_clock -= delta
		if spawn_clock <= 0:
			spawn_rock()
			spawn_clock = maxf(.85, 2.3 - stage_time * .025)
		for rock in rocks:
			rock.pos += rock.velocity * delta
			rock.spin += delta
			if rock.pos.distance_to(EARTH) < RADIUS + 32:
				if shield and energy >= 8:
					energy -= 8
					intercepted += 1
					burst(rock.pos, CYAN, 20)
					signal_sound(390, .15)
				else:
					integrity = maxf(0, integrity - 12)
					burst(rock.pos, ORANGE, 30)
					announce("地表遭受撞击 · 结构完整度 -12%", 2)
					signal_sound(90, .35)
				rock.dead = true
		rocks = rocks.filter(func(r): return not r.dead)
		if stage_time >= 42: transition(3)
	elif stage == 3:
		var aligned = aim.distance_to(navigation_target()) < 100
		if aligned and heat < 98:
			escape_progress = minf(100, escape_progress + thrust * delta * 5.5)
		else:
			escape_progress = maxf(0, escape_progress - delta * .5)
		if escape_progress >= 100: transition(4)
	if integrity <= 0 and stage != 4: transition(5)

func spawn_rock() -> void:
	var angle = rng.randf_range(-PI, PI)
	var pos = EARTH + Vector2.from_angle(angle) * rng.randf_range(475, 620)
	var velocity = (EARTH + Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80)) - pos).normalized() * rng.randf_range(32, 55)
	rocks.append({"pos": pos, "velocity": velocity, "size": rng.randf_range(9, 18), "spin": angle, "dead": false})

func shoot() -> void:
	if energy < 5: return
	energy -= 5
	cooldown = .24
	beams.append({"end": aim, "life": .24})
	signal_sound(1140, .12)
	var nearest: Dictionary = {}
	var distance = 58.0
	for rock in rocks:
		var d = aim.distance_to(rock.pos)
		if d < distance:
			nearest = rock
			distance = d
	if not nearest.is_empty():
		nearest.dead = true
		intercepted += 1
		burst(nearest.pos, ORANGE, 22)
		rocks = rocks.filter(func(r): return not r.dead)

func burst(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		sparks.append({"pos": pos, "vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(25, 180), "life": rng.randf_range(.3, 1.1), "color": color})

func update_effects(delta: float) -> void:
	for spark in sparks:
		spark.pos += spark.vel * delta
		spark.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0)
	for beam in beams: beam.life -= delta
	beams = beams.filter(func(b): return b.life > 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER:
				if stage == 0 or stage >= 4: begin_mission()
			KEY_R: begin_mission()
			KEY_ESCAPE: paused = not paused
			KEY_C: open_camera()
			KEY_M: muted = not muted
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = get_global_mouse_position()
		if START_RECT.has_point(pos):
			if stage == 0 or stage >= 4: begin_mission()
			else: paused = not paused
		elif CAMERA_RECT.has_point(pos): open_camera()
		elif PAUSE_RECT.has_point(pos): paused = not paused

func open_camera() -> void:
	if camera_enabled:
		camera_enabled = false
		announce("已切换鼠标键盘控制。浏览器中的摄像头可随时关闭。")
		return
	var server = ProjectSettings.globalize_path("res://camera/server.cjs")
	var node = "C:/Program Files/nodejs/node.exe" if FileAccess.file_exists("C:/Program Files/nodejs/node.exe") else "node"
	var pid = OS.create_process(node, PackedStringArray([server]))
	if pid < 0:
		camera_message = "无法启动手势服务，请检查 Node.js"
		announce(camera_message, 5)
		return
	camera_enabled = true
	OS.shell_open("http://127.0.0.1:19751")
	announce("在打开的浏览器中点击「开启摄像头」，然后回到游戏。", 8)

func text_at(value: String, pos: Vector2, size: int = 16, color: Color = WHITE, use_mono: bool = false) -> void:
	draw_string(mono if use_mono else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, accent: Color = CYAN) -> void:
	draw_style_box(panel_style(), rect)
	draw_line(rect.position, rect.position + Vector2(36, 0), accent, 2, true)
	draw_line(rect.end - Vector2(36, 0), rect.end, Color(accent, .5), 2, true)

func panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(.022, .048, .071, .88)
	style.border_color = Color(.22, .48, .58, .25)
	style.set_border_width_all(1)
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	return style

func bar(pos: Vector2, width: float, value: float, color: Color = CYAN, segments: int = 25) -> void:
	for i in range(segments):
		var active = float(i) / segments < value / 100
		draw_rect(Rect2(pos + Vector2(i * width / segments, 0), Vector2(width / segments - 3, 6)), Color(color, .9 if active else .12))

func _draw() -> void:
	# Star field, orbital grid and cockpit framing.
	for i in range(3):
		draw_arc(EARTH, 266 + i * 50, 0, TAU, 150, Color(.25, .65, .8, .07), 1, true)
	for i in range(72):
		var angle = i * TAU / 72
		var normal = Vector2.from_angle(angle)
		draw_line(EARTH + normal * 260, EARTH + normal * (270 if i % 6 == 0 else 264), Color(CYAN, .5 if i % 6 == 0 else .18), 1, true)
	var orbit = PackedVector2Array()
	for i in range(181):
		var a = i * TAU / 180
		orbit.append(EARTH + Vector2(cos(a) * 365, sin(a) * 92).rotated(-.25))
	draw_polyline(orbit, Color(CYAN, .18), 1, true)
	if (stage == 3 and thrust > .3) or stage == 4:
		for i in range(28):
			var angle = i * 2.39996
			var distance = 285 + fmod(time * 95 + i * 39, 320)
			var direction = Vector2.from_angle(angle)
			var p = EARTH + direction * distance
			if p.x > 345 and p.x < 1270 and p.y > 110 and p.y < 700:
				draw_line(p, p + direction * (15 + thrust * 32), Color(CYAN, .22), 1.5, true)
	draw_arc(EARTH, 277, time * .07, time * .07 + .6, 40, Color(CYAN, .7), 2, true)
	draw_line(Vector2(30, 96), Vector2(1570, 96), Color(CYAN, .18), 1)
	draw_line(Vector2(30, 776), Vector2(1570, 776), Color(CYAN, .18), 1)
	# Surface engines and their blue exhaust.
	var engine_level = .25 + ignition / 140.0 + thrust * .6
	if stage == 4: engine_level = 1.8
	for i in range(engines.size()):
		var p = EARTH + engines[i]
		var direction = Vector2(-.6, .8)
		var length = (14 + 15 * sin(i * 2.3 + time * 4)) * engine_level
		for k in range(3):
			draw_line(p, p + direction * length, Color(.1, .65, 1, .05 + .05 * k), 9 - k * 3, true)
		draw_line(p, p + direction * length * .7, Color(.6, .94, 1, .7), 1.2, true)
		draw_circle(p, 2, CYAN)
	if shield:
		draw_circle(EARTH, 240, Color(.1, .6, 1, .045))
		draw_arc(EARTH, 240, 0, TAU, 128, Color(CYAN, .8), 2, true)
		for i in range(12):
			var a = i * TAU / 12 + time * .1
			draw_arc(EARTH, 244, a, a + .18, 12, Color(CYAN, .3), 4, true)
	# Incoming debris.
	for rock in rocks:
		var pos: Vector2 = rock.pos
		draw_line(pos - rock.velocity.normalized() * 48, pos, Color(ORANGE, .2), 2, true)
		var polygon = PackedVector2Array()
		for j in range(7): polygon.append(pos + Vector2.from_angle(j * TAU / 7 + rock.spin) * rock.size * (1 if j % 2 == 0 else .72))
		draw_colored_polygon(polygon, Color("574435"))
		polygon.append(polygon[0])
		draw_polyline(polygon, ORANGE, 1, true)
		draw_arc(pos, rock.size + 9, -.8, .8, 12, Color(ORANGE, .65), 1, true)
		text_at("!", pos + Vector2(-3, -rock.size - 15), 14, ORANGE, true)
	for beam in beams:
		var alpha = beam.life / .24
		draw_line(EARTH + Vector2(0, -30), beam.end, Color(CYAN, alpha * .15), 12, true)
		draw_line(EARTH + Vector2(0, -30), beam.end, Color(WHITE, alpha), 2, true)
	for spark in sparks:
		draw_line(spark.pos, spark.pos - spark.vel * .04, Color(spark.color, minf(1, spark.life)), 2, true)
	if stage == 3:
		var target = navigation_target()
		var aligned = target.distance_to(aim) < 100
		draw_arc(target, 48, time, time + 5, 48, CYAN if aligned else ORANGE, 3, true)
		draw_line(target - Vector2(65, 0), target + Vector2(65, 0), Color(CYAN, .3), 1, true)
		text_at("跟随导航环 / 按住 SHIFT 推进", target + Vector2(-115, -65), 14, CYAN)
	# Header and title.
	draw_circle(Vector2(51, 55), 9, Color(CYAN, .1))
	draw_arc(Vector2(51, 55), 9, -.7, 4.5, 24, CYAN, 2, true)
	text_at("UEG  /  深空领航中心", Vector2(74, 61), 19, WHITE)
	text_at("PROJECT HELIOS", Vector2(414, 60), 14, MUTED, true)
	draw_circle(Vector2(660, 55), 3, CYAN)
	text_at("地月通信链路正常", Vector2(674, 60), 13, CYAN)
	text_at("2075.02.15  /  木星引力危机", Vector2(908, 60), 13, MUTED)
	button(PAUSE_RECT, "继续" if paused else "暂停", false)
	button(CAMERA_RECT, "◉  手势已启用 / C" if camera_enabled else "启用摄像头手势  /  C", camera_enabled)
	text_at("流浪地球 · 同人概念原型", Vector2(46, 139), 14, CYAN)
	text_at("逐 光 计 划", Vector2(42, 201), 48, WHITE)
	text_at("J U P I T E R   E S C A P E", Vector2(47, 232), 15, MUTED, true)
	text_at("带着家园，驶向下一片星海。", Vector2(47, 266), 17, MUTED)
	text_at("JUPITER", Vector2(1350, 135), 14, Color(ORANGE, .8), true)
	text_at("木星 / 引力干扰源", Vector2(1350, 160), 14, MUTED)
	text_at("EARTH  /  01", Vector2(1006, 661), 14, CYAN, true)
	text_at("地球 · 行星发动机阵列", Vector2(1006, 686), 13, MUTED)
	draw_left_panel()
	draw_right_panel()
	draw_console()
	# Aim reticle is kept out of the side panels.
	if stage > 0 and stage < 4:
		var c = ORANGE if stage == 2 else CYAN
		draw_arc(aim, 18, time * 2, time * 2 + 4.5, 32, c, 1.5, true)
		draw_line(aim - Vector2(27, 0), aim - Vector2(11, 0), c, 1, true)
		draw_line(aim + Vector2(11, 0), aim + Vector2(27, 0), c, 1, true)
		draw_line(aim - Vector2(0, 27), aim - Vector2(0, 11), c, 1, true)
		draw_circle(aim, 2, c)
	if toast_timer > 0:
		var rect = Rect2(381, 710, 866, 42)
		panel(rect)
		text_at("›  " + toast, rect.position + Vector2(16, 27), 15, CYAN)
	if stage >= 4: draw_result()
	if paused:
		draw_rect(Rect2(350, 270, 920, 360), Color(.015, .035, .06, .95))
		text_at("任务已暂停", Vector2(650, 420), 40)
		text_at("按 ESC 或点击「继续」返回任务", Vector2(624, 467), 18, CYAN)
		text_at("M 静音  ·  F11 全屏  ·  R 重新开始", Vector2(622, 509), 16, MUTED)

func button(rect: Rect2, label: String, active: bool) -> void:
	var hover = rect.has_point(get_global_mouse_position())
	draw_rect(rect, Color(.1, .25, .3, .8) if hover or active else Color(.03, .075, .1, .9))
	draw_rect(rect, Color(CYAN, .65 if hover or active else .25), false, 1)
	var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	text_at(label, rect.position + Vector2((rect.size.x - width) / 2, rect.size.y / 2 + 5), 15, CYAN if active or hover else WHITE)

func draw_left_panel() -> void:
	panel(Rect2(46, 310, 280, 428))
	text_at("MISSION SEQUENCE", Vector2(64, 341), 13, MUTED, true)
	text_at("木星逃逸行动", Vector2(64, 378), 22)
	var titles = ["重启行星发动机", "穿越陨石碎片带", "进入逃逸航道"]
	var descriptions = ["稳定输出，唤醒地球推进阵列", "保护地球，等待轨道窗口", "跟随导航，完成最后的推进"]
	for i in range(3):
		var y = 420 + i * 88
		var active = stage == i + 1
		var complete = stage > i + 1 and stage != 5
		if active: draw_rect(Rect2(59, y - 22, 252, 69), Color(CYAN, .06))
		draw_circle(Vector2(78, y), 12, Color(CYAN, .12 if active or complete else .04))
		text_at("✓" if complete else str(i + 1), Vector2(73, y + 5), 14, CYAN if active or complete else MUTED)
		text_at(titles[i], Vector2(102, y + 5), 17, WHITE if active else MUTED)
		text_at(descriptions[i], Vector2(68, y + 31), 12, MUTED)
		if i < 2: draw_line(Vector2(78, y + 16), Vector2(78, y + 51), Color(CYAN, .15), 1)
	draw_line(Vector2(64, 677), Vector2(307, 677), Color(CYAN, .15))
	text_at("任务时钟", Vector2(65, 707), 13, MUTED)
	text_at("%02d:%02d" % [int(mission_time) / 60, int(mission_time) % 60], Vector2(221, 711), 23, CYAN, true)

func draw_right_panel() -> void:
	panel(Rect2(1290, 302, 268, 264))
	text_at("PLANET TELEMETRY", Vector2(1308, 333), 13, MUTED, true)
	text_at("地球结构完整度", Vector2(1308, 366), 15)
	text_at("%03d" % int(integrity), Vector2(1306, 418), 46, CYAN if integrity > 35 else RED, true)
	text_at("%", Vector2(1400, 416), 20, MUTED, true)
	bar(Vector2(1308, 436), 230, integrity, CYAN if integrity > 35 else RED)
	text_at("轨道状态", Vector2(1308, 477), 13, MUTED)
	text_at("已脱离引力井" if stage == 4 else "引力锁定中", Vector2(1435, 477), 14, CYAN if stage == 4 else ORANGE)
	text_at("已拦截目标", Vector2(1308, 511), 13, MUTED)
	text_at("%02d" % intercepted, Vector2(1494, 511), 19, WHITE, true)
	text_at("防御能量", Vector2(1308, 543), 13, MUTED)
	bar(Vector2(1400, 535), 139, energy, CYAN, 18)
	panel(Rect2(1290, 584, 268, 154))
	var online = camera_active()
	draw_circle(Vector2(1312, 610), 3, CYAN if online else ORANGE)
	text_at("GESTURE LINK", Vector2(1324, 615), 13, CYAN if online else MUTED, true)
	text_at("手势追踪中" if online else ("等待手部进入画面" if camera_enabled and time - bridge_last < 5 else "鼠标 / 键盘控制"), Vector2(1308, 649), 17)
	text_at("双手拉开推进 · 捏合拦截" if online else "点击右上角，连接你的双手", Vector2(1308, 679), 13, MUTED)
	text_at("本机识别 · 视频不上传" if camera_enabled else "无需摄像头也能完整通关", Vector2(1308, 711), 12, CYAN)

func draw_console() -> void:
	var state_names = ["接管领航系统", "发动机重启中", "碎片防御模式", "逃逸推进模式", "任务完成", "任务终止"]
	text_at("OPERATIONS  /  " + state_names[stage], Vector2(46, 797), 12, MUTED)
	button(START_RECT, "开始领航   →   ENTER" if stage == 0 else ("重新领航   →   R" if stage >= 4 else ("继续任务   /   ESC" if paused else "暂停任务   /   ESC")), true)
	text_at("F11 全屏   ·   M " + ("开启声音" if muted else "静音") + "   ·   R 重启", Vector2(47, 897), 13, MUTED)
	text_at("01 / 推进功率", Vector2(375, 816), 14, CYAN)
	text_at("%03d%%" % int(thrust * 100), Vector2(550, 816), 17, WHITE, true)
	bar(Vector2(375, 839), 262, thrust * 100)
	text_at("按住 SHIFT  /  双手拉开", Vector2(375, 881), 14, WHITE)
	text_at("热量 %02d%% · 过热时松开冷却" % int(heat), Vector2(375, 908), 12, RED if heat > 80 else MUTED)
	bar(Vector2(375, 922), 262, heat, RED if heat > 80 else ORANGE, 32)
	draw_line(Vector2(677, 807), Vector2(677, 931), Color(CYAN, .15))
	text_at("02 / 轨道防御", Vector2(716, 816), 14, CYAN)
	text_at("护盾已展开" if shield else "防御系统待命", Vector2(716, 848), 21, CYAN if shield else WHITE)
	text_at("左键 / 捏合：拦截陨石", Vector2(716, 881), 14)
	text_at("右键·空格 / 张开单手：护盾", Vector2(716, 908), 13, MUTED)
	draw_line(Vector2(1028, 807), Vector2(1028, 931), Color(CYAN, .15))
	var progress = ignition if stage <= 1 else (clampf(stage_time / 42 * 100, 0, 100) if stage == 2 else escape_progress)
	if stage == 4: progress = 100
	text_at("03 / " + ("点火进度" if stage <= 1 else ("逃逸窗口" if stage == 2 else "逃逸进度")), Vector2(1069, 816), 14, CYAN)
	text_at("%03d" % int(progress), Vector2(1064, 876), 50, WHITE, true)
	text_at("%", Vector2(1163, 874), 21, MUTED, true)
	bar(Vector2(1070, 899), 475, progress)
	var note = "等待指挥官接管" if stage == 0 else ("保持推进 · 注意反应堆温度" if stage == 1 else ("坚持防御，倒计时 %02d 秒" % maxi(0, 42 - int(stage_time)) if stage == 2 else "跟随导航环 + 推进，积累逃逸速度"))
	text_at(note, Vector2(1265, 851), 13, MUTED)
	text_at("地球，是我们唯一的家园。", Vector2(1265, 879), 13, CYAN)
	text_at("UEG  /  NAVIGATION PROTOCOL 07", Vector2(1070, 927), 11, MUTED, true)

func draw_result() -> void:
	var rect = Rect2(430, 316, 790, 300)
	draw_rect(rect, Color(.015, .035, .06, .97))
	draw_rect(rect, CYAN if stage == 4 else RED, false, 1)
	text_at("MISSION COMPLETE" if stage == 4 else "SIGNAL LOST", Vector2(477, 366), 16, CYAN if stage == 4 else RED, true)
	text_at("地球，继续前进。" if stage == 4 else "我们需要再试一次。", Vector2(477, 430), 43)
	text_at("逃逸航道已建立。下一站，是新的太阳。" if stage == 4 else "防线失守，地表结构完整度归零。", Vector2(479, 478), 19, MUTED)
	text_at("拦截 %02d 枚碎片   ·   地球完整度 %d%%" % [intercepted, int(integrity)], Vector2(479, 526), 18, CYAN)
	text_at("按 R 或 ENTER 重新领航", Vector2(479, 578), 16, WHITE)

func run_self_test() -> void:
	test_done = true
	begin_mission()
	thrust = 1
	for i in range(130):
		heat = 0
		simulate(.1)
	assert(stage == 2, "Ignition must transition to defense")
	rocks.clear()
	spawn_rock()
	aim = rocks[0].pos
	var before = intercepted
	shoot()
	assert(intercepted == before + 1, "Aimed shot must intercept")
	spawn_rock()
	rocks[0].pos = EARTH + Vector2(220, 0)
	shield = true
	energy = 100
	simulate(.01)
	assert(integrity == 100, "Shield must prevent impact damage")
	spawn_rock()
	rocks[0].pos = EARTH + Vector2(220, 0)
	shield = false
	simulate(.01)
	assert(integrity == 88, "Unshielded impact must damage Earth")
	stage_time = 42
	simulate(.01)
	assert(stage == 3, "Defense timer must open escape stage")
	thrust = 1
	for i in range(200):
		aim = navigation_target()
		heat = 0
		simulate(.1)
		if stage == 4: break
	assert(stage == 4, "Aligned thrust must win")
	begin_mission()
	integrity = 0
	simulate(.01)
	assert(stage == 5, "Zero integrity must fail")
	begin_mission()
	assert(stage == 1 and integrity == 100 and rocks.is_empty(), "Restart must reset mission")
	print("SELF_TEST_PASS: ignition, interception, shield, impact, escape, victory, failure, restart")
	get_tree().quit()
