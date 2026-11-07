extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.chapter = 2
	game.evidence = [true,true,true]
	game.solved = true
	game.patched = true
	game.phase = 0
	game.station.set_phase(0)
	game.update_witness()
	game.player.position = game.station.point(game.station.AUDIT) + Vector3(0.18,0.05,0.29)
	game.set_mode("audit")
	await physics_frame
	game.begin_upload()
	var before: int = game.laps
	var ticks := 0
	var music_started := false
	while ticks < 60 and game.mode == "world" and game.laps == before:
		await physics_frame
		game.tick_game_physics(0.1)
		music_started = music_started or game.sound.chase.playing
		ticks += 1
	var caught: bool = game.laps > before and not game.cleared and music_started
	print("UPLOAD_PRESSURE_TEST: %s / stationary player caught in %.1fs; upload remains six seconds" % ["PASS" if caught else "FAIL", ticks * 0.1])
	game.free()
	await process_frame
	quit(0 if caught else 1)
