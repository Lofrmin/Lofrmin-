extends SceneTree

# P1 修复 3：扫描条动画驱动验证 + 正常视距截图
# 走 fixture.tick_game_physics 驱动正式 game._physics_process，验证扫描条真正移动 / 暂停不动 / 上传结束隐藏
var failed := false
var output := ""
var game: Node3D
var failures: Array[String] = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)


func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output.path_join(label + ".png")) != OK:
		check(false, "screenshot " + label)


func _initialize() -> void:
	call_deferred("run")


func view_relay_close() -> void:
	# 近景：站在 R-03 桌正前方 0.55m，略俯视
	game.player.position = game.station.point(game.station.RELAY) + Vector3(0, 0.05, 0.55)
	game.player.rotation.y = 0.0
	game.camera.rotation.x = -0.30


func view_relay_normal() -> void:
	# 正常玩家视距：站在 R-03 桌正前方约 1.0m，自然视角（交互距离内）
	game.player.position = game.station.point(game.station.RELAY) + Vector3(0, 0.05, 1.05)
	game.player.rotation.y = 0.0
	game.camera.rotation.x = -0.20


func set_state(solved: bool, armed: bool, patched: bool, upload: float, cleared: bool) -> void:
	game.chapter = 2
	game.solved = solved
	game.armed = armed
	game.patched = patched
	game.upload = upload
	game.cleared = cleared
	game.sync_relay_visual()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Usage: --script res://tests/relay_animation_check.gd -- ABSOLUTE_CAPTURE_DIRECTORY")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.mode = "world"
	game.chapter = 2
	game.phase = 0
	game.station.set_phase(0)
	view_relay_close()
	await create_timer(0.4).timeout

	# ── 扫描条动画驱动验证 ──
	# 进入上传状态（不手动 set_state.upload，改用 begin_upload 路径难以直接调，这里仍手动设 upload 字段模拟物理帧）
	game.solved = true
	game.armed = true
	game.patched = true
	game.upload = 6.0
	game.sync_relay_visual()
	var rig: Dictionary = game.station.relay_rigs[0]
	var bar: MeshInstance3D = rig.scan_bar

	# 帧 0：扫描条可见 + 初始 x
	check(bar.visible, "scan bar visible when upload starts")
	var x0: float = bar.position.x

	# 驱动正式物理帧 + 帧回调（_process 中的 animate_relay 才会跑）
	game.tick_game_physics(0.1)
	game.tick_game_process(0.1)
	var x1: float = bar.position.x
	check(absf(x1 - x0) > 0.001, "scan bar moved after one tick (%.4f -> %.4f)" % [x0, x1])

	# 再驱动几帧，位置应继续变化
	game.tick_game_physics(0.1)
	game.tick_game_process(0.1)
	game.tick_game_physics(0.1)
	game.tick_game_process(0.1)
	var x2: float = bar.position.x
	check(absf(x2 - x1) > 0.001, "scan bar keeps moving across ticks")

	# 暂停：mode = paused，animate_relay 不再被 _process 调用
	game.set_mode("paused")
	var x_paused: float = bar.position.x
	game.tick_game_physics(0.1)
	game.tick_game_process(0.1)
	game.tick_game_physics(0.1)
	game.tick_game_process(0.1)
	check(is_equal_approx(bar.position.x, x_paused), "scan bar frozen when paused")

	# 恢复 world，让 upload 跑完（6 秒，每次 0.1 tick 共 70 tick 后应 <=0）
	game.set_mode("world")
	for i in range(70):
		game.tick_game_physics(0.1)
		game.tick_game_process(0.1)
	check(game.upload <= 0.0, "upload finished after ~7s of physics ticks")
	check(game.cleared, "cleared set after upload completed")
	check(not bar.visible, "scan bar hidden after upload finished")
	for r in game.station.relay_rigs:
		check(r.status_label.text == "ACK OK", "ACK OK label after upload finished")

	# ── 正常视距截图（晨/暮 × 6 状态）──
	# 前面 upload 跑完进入了 ending，截图前回到 world
	game.set_mode("world")
	view_relay_normal()
	await create_timer(0.2).timeout

	set_state(false, false, false, 0.0, false)
	await capture("normal-morning-idle")
	set_state(true, false, false, 0.0, false)
	await capture("normal-morning-verified")
	set_state(true, true, false, 0.0, false)
	await capture("normal-morning-armed")
	set_state(true, true, true, 0.0, false)
	await capture("normal-morning-linked")
	set_state(true, true, true, 3.5, false)
	game.tick_game_physics(0.016)  # 让扫描条移动一格
	await capture("normal-morning-upload")
	set_state(true, true, true, 0.0, true)
	await capture("normal-morning-ack")

	# 暮区
	game.phase = 1
	game.station.set_phase(1)
	await create_timer(0.2).timeout
	set_state(false, false, false, 0.0, false)
	await capture("normal-dusk-idle")
	set_state(true, false, false, 0.0, false)
	await capture("normal-dusk-verified")
	set_state(true, true, false, 0.0, false)
	await capture("normal-dusk-armed")
	set_state(true, true, true, 0.0, false)
	await capture("normal-dusk-linked")
	set_state(true, true, true, 3.5, false)
	game.tick_game_physics(0.016)
	await capture("normal-dusk-upload")
	set_state(true, true, true, 0.0, true)
	await capture("normal-dusk-ack")

	# 近景截图（每个相 3 个关键状态）
	game.set_mode("world")
	game.phase = 0
	game.station.set_phase(0)
	view_relay_close()
	await create_timer(0.2).timeout
	set_state(false, false, false, 0.0, false)
	await capture("close-morning-idle")
	set_state(true, true, false, 0.0, false)
	await capture("close-morning-armed")
	set_state(true, true, true, 3.5, false)
	game.tick_game_physics(0.016)
	await capture("close-morning-upload")

	game.phase = 1
	game.station.set_phase(1)
	await create_timer(0.2).timeout
	set_state(false, false, false, 0.0, false)
	await capture("close-dusk-idle")
	set_state(true, true, false, 0.0, false)
	await capture("close-dusk-armed")
	set_state(true, true, true, 3.5, false)
	game.tick_game_physics(0.016)
	await capture("close-dusk-upload")

	print("RELAY_ANIMATION_CHECK: %d checks / %d failures / output=%s" % [checks, failures.size(), output])
	quit(0 if failures.is_empty() else 1)
