extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual check needs a rendering driver")
		quit(1)
		return
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.mode = "world"
	game.boss_live = true
	game.boss_phase = 0
	game.boss_delay = 0.0
	game.boss.show()
	game.interface.hide()
	game.boss.position = game.station.point(game.station.AUDIT) + Vector3(0,0,2.0)
	game.player.position = game.boss.position + Vector3(0.7,0,3.5)
	game.camera.look_at(game.boss.position + Vector3(0,1.15,0), Vector3.UP)
	game.boss.look_at(Vector3(game.player.position.x,0,game.player.position.z), Vector3.UP)
	game.boss_rig.animation.active = true
	for clip in ["Idle","Walk","Run"]:
		game.boss_rig.animation.play(clip)
		game.boss_rig.animation.speed_scale = 1.0
		await create_timer(0.23).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("hunter-"+clip.to_lower()+".png"))
	game.stunned = 1.0
	game.update_boss(0.016,false)
	game.boss_rig.update_motion(0.2,0,true)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("hunter-stunned.png"))
	game.free()
	await process_frame
	print("HUNTER_VISUAL_CAPTURE_PASS")
	quit(0)
