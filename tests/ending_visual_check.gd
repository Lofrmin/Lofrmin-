extends "res://tests/visual_check.gd"

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Requires a capture directory and rendering; add --full for natural playback")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var natural := args.has("--full")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		game = load("res://tests/fixture.gd").new()
		root.add_child(game)
		game.chapter = 2
		game.evidence = [true,true,true]
		game.solved = true
		game.cleared = true
		game.begin_epilogue()
		await create_timer(2.0).timeout
		await capture("ending-movie-%d" % resolution.x)
		if game.mode != "epilogue" or game.epilogue.video.stream_position < 0.5: failed = true
		if natural and resolution.x == 1280:
			var deadline := Time.get_ticks_msec() + 120000
			while game.mode == "epilogue" and Time.get_ticks_msec() < deadline:
				await create_timer(1.0).timeout
		else:
			game.epilogue.skip_button.pressed.emit()
		if game.mode != "ending" or game.epilogue.playing: failed = true
		await capture("ending-receipt-%d" % resolution.x)
		await click("replay_ending")
		await create_timer(0.25).timeout
		if game.mode != "epilogue": failed = true
		game.epilogue.skip_button.pressed.emit()
		await click("loop")
		if game.mode != "world" or game.chapter != 0 or not game.echo_run: failed = true
		await capture("echo-start-%d" % resolution.x)
		game.set_mode("menu")
		await capture("echo-menu-%d" % resolution.x)
		game.free()
		await process_frame
	print("ENDING_VISUAL_TEST: " + ("FAIL" if failed else "PASS / both resolutions, replay and echo loop"))
	quit(1 if failed else 0)
