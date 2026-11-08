extends "res://tests/visual_check.gd"

# Real-time playback with the in-memory profile; never opens the player's save.
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Requires rendering and an absolute capture directory")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.handle_action("new_case")
	if game.mode != "cinematic" or not game.prologue.video.is_playing():
		printerr("FAIL: new save did not start video")
		quit(1)
		return
	var before := Time.get_ticks_msec()
	await create_timer(2.5).timeout
	await capture("movie-1280")
	var texture: Texture2D = game.prologue.video.get_video_texture()
	if texture == null or texture.get_width() < 1280:
		failed = true
		printerr("FAIL: decoder did not deliver the full-size video texture")
	var first_position: float = game.prologue.video.stream_position
	root.size = Vector2i(1920, 1080)
	await create_timer(2.0).timeout
	await capture("movie-1920")
	if game.prologue.video.stream_position <= first_position:
		failed = true
		printerr("FAIL: playback did not advance")
	print("PROLOGUE_PLAYBACK: rendering, resize and advancing video verified")
	while game.mode == "cinematic" and Time.get_ticks_msec() - before < 85000:
		await create_timer(1.0).timeout
	var elapsed := (Time.get_ticks_msec() - before) / 1000.0
	if game.mode != "intro" or game.intro_page != 0 or elapsed < 70.0 or game.prologue.playing or game.get_viewport().disable_3d:
		failed = true
		printerr("FAIL: movie did not finish naturally into briefing / %.1f seconds" % elapsed)
	await capture("after-movie-briefing")
	game.free()
	await process_frame
	print("PROLOGUE_PLAYBACK: %s / %.1f seconds / natural finish, picture and resize" % ["FAIL" if failed else "PASS", elapsed])
	quit(1 if failed else 0)
