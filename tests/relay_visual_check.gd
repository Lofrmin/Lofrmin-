extends SceneTree

# P1 R-03 / E-7 中继视觉反馈验收
# 渲染运行（不能 headless），输出晨/暮两相在 IDLE/VERIFIED/ARMED/LINKED/TX/ACK 六种状态下的真实引擎画面
var failed := false
var output := ""
var game: Node3D

func _initialize() -> void:
	call_deferred("run")


func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(output.path_join(label + ".png")) != OK:
		failed = true
		printerr("FAIL: screenshot " + label)


func view_relay() -> void:
	# 把玩家放在 R-03 桌台正前方（桌台位于 tile 中心 z-1.21），朝 -z 方向看桌台
	game.player.position = game.station.point(game.station.RELAY) + Vector3(0, 0.05, 0.55)
	game.player.rotation.y = 0.0  # 朝 -z 看（桌台方向）
	game.camera.rotation.x = -0.50  # 略俯视桌面


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
		printerr("Usage: --script res://tests/relay_visual_check.gd -- ABSOLUTE_CAPTURE_DIRECTORY")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.mode = "world"
	game.chapter = 2

	# ── 晨区（phase=0）──
	game.phase = 0
	game.station.set_phase(0)
	view_relay()
	await create_timer(0.6).timeout

	set_state(false, false, false, 0.0, false)
	await capture("morning-idle")

	set_state(true, false, false, 0.0, false)
	await capture("morning-verified")

	set_state(true, true, false, 0.0, false)
	await capture("morning-armed")

	set_state(true, true, true, 0.0, false)
	await capture("morning-linked")

	set_state(true, true, true, 3.5, false)
	await create_timer(0.2).timeout
	await capture("morning-upload")

	set_state(true, true, true, 0.0, true)
	await capture("morning-ack")

	# ── 暮区（phase=1）──
	game.phase = 1
	game.station.set_phase(1)
	view_relay()
	await create_timer(0.4).timeout

	set_state(false, false, false, 0.0, false)
	await capture("dusk-idle")

	set_state(true, false, false, 0.0, false)
	await capture("dusk-verified")

	set_state(true, true, false, 0.0, false)
	await capture("dusk-armed")

	set_state(true, true, true, 0.0, false)
	await capture("dusk-linked")

	# 检查 relay_rigs 节点确实建出来
	var rig_count: int = game.station.relay_rigs.size()
	if rig_count != 2:
		failed = true
		printerr("FAIL: expected 2 relay rigs, got %d" % rig_count)

	print("RELAY_VISUAL_CHECK: %s / rigs=%d / output=%s" % ["FAIL" if failed else "PASS", rig_count, output])
	quit(0 if not failed else 1)
