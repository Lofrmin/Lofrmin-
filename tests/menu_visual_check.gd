extends "res://tests/visual_check.gd"

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Usage: --script res://tests/menu_visual_check.gd -- ABSOLUTE_CAPTURE_DIRECTORY")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		game = load("res://tests/fixture.gd").new()
		root.add_child(game)
		await capture("menu-new-%d" % resolution.x)
		if game.interface.hit_regions.has("continue"):
			failed = true
		await click("controls")
		await capture("controls-%d" % resolution.x)
		await click("controls_back")
		if game.mode != "menu": failed = true
		await click("new_case")
		await capture("intro-%d" % resolution.x)
		await click("intro_next")
		await click("intro_next")
		await click("intro_next")
		if game.mode != "world": failed = true
		await capture("first-goal-%d" % resolution.x)
		game.chapter = 4
		game.laps = 3
		game.evidence = [true,false,false]
		game.set_mode("menu")
		await capture("menu-saved-%d" % resolution.x)
		await click("new_case")
		await capture("new-confirm-%d" % resolution.x)
		await click("cancel_restart")
		if game.mode != "menu" or game.chapter != 4: failed = true
		await click("continue")
		if game.mode != "world" or game.chapter != 4 or not game.evidence[0]: failed = true
		game.set_mode("paused")
		await click("controls")
		await click("controls_back")
		if game.mode != "paused": failed = true
		game.free()
		await process_frame
	print("MENU_VISUAL_TEST: " + ("FAIL" if failed else "PASS / 1280x720 and 1920x1080"))
	quit(1 if failed else 0)
