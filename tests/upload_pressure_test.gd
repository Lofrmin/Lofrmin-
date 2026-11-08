extends SceneTree

var failures: Array[String] = []
var checks := 0
var game: Node3D

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func prepare() -> void:
	game.reset_lap("upload setup")
	game.chapter = 2
	game.evidence = [true,true,true]
	game.solved = true
	game.patched = true
	game.cleared = false
	game.update_witness()
	game.player.position = game.station.point(game.station.AUDIT) + Vector3(0.18,0.05,0.29)
	game.set_mode("audit")

func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await physics_frame
	prepare()
	await physics_frame
	game.begin_upload()
	check(is_equal_approx(game.upload, 30.0), "upload starts at thirty seconds")
	check(game.boss_live and game.boss.visible and game.boss_phase == 0, "upload deploys visible morning hunter")
	check(game.hunter_has_sight(game.boss.position), "upload hunter visible without intervening wall")
	check(game.boss.position.distance_to(game.player.position) >= 8.0, "upload gives reaction distance")
	game.shift_cooldown = 0.0
	game.shift(game.station.GATES[0])
	check(game.phase == 0 and is_equal_approx(game.upload, 30.0), "upload blocks phase travel without resetting timer")
	var first: Vector3 = game.boss.position
	game.set_mode("paused")
	game.tick_game_physics(2.0)
	check(is_equal_approx(game.upload, 30.0) and game.boss.position == first, "pause freezes upload and hunter")
	game.set_mode("world")
	game.dev_god = true
	for i in range(299):
		await physics_frame
		game.tick_game_physics(0.1)
	check(game.boss_live and game.boss_phase == 0 and game.boss.position.distance_to(first) > 1.0, "morning hunter pursues throughout upload")
	check(not game.cleared and game.upload > 0.0, "upload cannot finish before thirty seconds")
	game.tick_game_physics(0.11)
	check(game.cleared and game.mode == "epilogue", "thirty-second chase completion starts ending movie")
	check(not game.boss_live and game.extra_hunters.is_empty(), "ending movie clears encounter")
	game.epilogue.finish()
	check(game.mode == "ending", "movie returns to the completion receipt")
	# A real catch must interrupt transmission, not award the ending after reset.
	prepare()
	await physics_frame
	game.dev_god = false
	game.begin_upload()
	game.boss.position = game.player.position + Vector3(0.75,0,0)
	game.boss_delay = 0.0
	game.dusk_grace = 0.0
	var before: int = game.laps
	game.tick_game_physics(0.1)
	check(game.laps == before + 1 and game.upload == 0.0 and not game.cleared, "catch cancels upload and resets lap")
	check(game.phase == 0 and not game.boss_live, "ordinary morning safe after failure")
	prepare()
	game.boss_live = true
	game.boss_phase = 0
	game.set_mode("world")
	game.tick_game_physics(0.01)
	check(not game.boss_live, "ordinary morning removes stale hunters")
	game.free()
	await process_frame
	print("UPLOAD_PRESSURE_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
