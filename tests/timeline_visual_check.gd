extends "res://tests/visual_check.gd"

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Usage: --script res://tests/timeline_visual_check.gd -- ABSOLUTE_CAPTURE_DIRECTORY")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		game = load("res://tests/fixture.gd").new()
		root.add_child(game)
		game.chapter = 3
		game.evidence = [true,true,true]
		game.set_mode("audit")
		await capture("timeline-empty-%d" % resolution.x)
		await click("timeline_digit_5")
		await click("timeline_pick_debit")
		await click("timeline_pick_filing")
		await capture("timeline-selected-%d" % resolution.x)
		await click("timeline_submit")
		if game.chapter != 1:
			failed = true
			printerr("FAIL: timeline mouse submission")
		if resolution.x == 1280:
			game.dev_mode = true
			await capture("dev-timeline-answer")
			game.dev_mode = false
			game.mode = "world"
			game.big_map = true
			game.boss_live = true
			game.threat = 0.7
			await capture("map-live-threat")
		game.free()
		await process_frame
	print("TIMELINE_VISUAL_TEST: " + ("FAIL" if failed else "PASS / 1280x720 and 1920x1080"))
	quit(1 if failed else 0)
