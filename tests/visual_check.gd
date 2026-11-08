extends SceneTree

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

func click(action: String) -> void:
	await process_frame
	await process_frame
	if not game.interface.hit_regions.has(action):
		failed = true
		printerr("FAIL: missing button " + action)
		return
	var rect: Rect2 = game.interface.hit_regions[action]
	var position: Vector2 = rect.get_center() * game.interface.size / Vector2(1280,720)
	if game.interface.button_at(position) != action:
		failed = true
		printerr("FAIL: scaled hit region " + action)
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	game._input(event)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Usage: --script res://tests/visual_check.gd -- ABSOLUTE_CAPTURE_DIRECTORY (requires rendering)")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.mode = "world"
	game.player.position = game.station.point(game.station.AUDIT) + Vector3(0,0.05,0.8)
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.28
	await create_timer(0.8).timeout
	await capture("desk-first")
	game.chapter = 1
	game.evidence = [true,true,false]
	game.update_witness()
	await capture("desk-before")
	game.mode = "audit"
	game.handle_action("accept")
	await capture("signature-preview")
	game.handle_action("accept_commit")
	await capture("desk-after")
	game.reset_lap("审计匣保留证据；接案签字已复位。")
	game.player.rotation.y = 0
	game.camera.rotation.x = -0.28
	await capture("desk-reset")
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		game.chapter = 0
		game.evidence = [true,true,true]
		game.set_mode("audit")
		await capture("alignment-empty-%d" % resolution.x)
		await click("align_device")
		await click("align_alarm")
		await capture("alignment-selected-%d" % resolution.x)
		await click("align_submit")
		if game.chapter != 3:
			failed = true
			printerr("FAIL: mouse alignment progression")
		game.chapter = 3
		game.evidence = [true,true,true]
		game.timeline_seconds = ""
		game.timeline_order.clear()
		game.set_mode("audit")
		await capture("timeline-empty-%d" % resolution.x)
		await click("timeline_digit_5")
		await click("timeline_pick_debit")
		await click("timeline_pick_filing")
		await capture("timeline-selected-%d" % resolution.x)
		await click("timeline_submit")
		if game.chapter != 1:
			failed = true
			printerr("FAIL: mouse time ordering progression")
	root.size = Vector2i(1280,720)
	game.mode = "world"
	game.phase = 1
	game.map_phase = 1
	game.station.set_phase(1)
	game.player.position = game.station.point(game.station.OFFICE) + Vector3(0,0.05,0)
	game.player.rotation.y = PI
	game.camera.rotation.x = 0
	await capture("return-route")
	game.free()
	await process_frame
	print("VISUAL_INPUT_TEST: " + ("FAIL" if failed else "PASS / 1280x720 and 1920x1080"))
	quit(1 if failed else 0)
