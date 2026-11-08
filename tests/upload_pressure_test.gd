extends SceneTree

# v7 requirement: Morning stays safe, including the final six-second upload.
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

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
	# A stale Dusk encounter must also be removed when uploading.
	game.boss_live = true
	game.boss_chasing = true
	game.boss_phase = 1
	game.sound.update_chase(1.0, 1.0, true)
	game.begin_upload()
	check(is_equal_approx(game.upload, 6.0), "upload starts at six seconds")
	check(not game.boss_live and not game.boss.visible and not game.sound.chase.playing, "upload removes stale hunter and chase audio")
	game.shift_cooldown = 0.0
	game.shift(game.station.GATES[0])
	check(game.phase == 0 and is_equal_approx(game.upload, 6.0), "upload blocks phase travel without resetting timer")
	var before: int = game.laps
	for i in range(59):
		await physics_frame
		game.tick_game_physics(0.1)
		check(not game.boss_live and not game.boss_chasing and not game.sound.chase.playing, "Morning stays safe at tick %d" % i)
	check(not game.cleared and game.upload > 0.0, "upload cannot finish before six seconds")
	game.tick_game_physics(0.11)
	check(game.cleared and game.mode == "epilogue" and game.laps == before, "stationary player completes upload and starts ending movie")
	game.epilogue.finish()
	check(game.mode == "ending", "movie returns to the completion receipt")
	game.free()
	await process_frame
	print("UPLOAD_SAFETY_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
