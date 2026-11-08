extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.hunter_intro_seen=true
	if not game.has_method("safe_hunter_spawn"):
		check(false,"safe randomized population API exists")
		game.free()
		quit(1)
		return
	await physics_frame
	game.set_mode("world")
	game.player.position = game.station.point(game.station.GATES[0]) + Vector3.UP*0.05
	game.options.hunter_count = 2
	game.reset_lap("test two next lap")
	game.shift(game.station.GATES[0])
	game.deploy_after_submission()
	check(game.extra_hunters.size()==1,"two-hunter encounter has exactly one independent extra")
	if game.extra_hunters.is_empty():
		game.free()
		quit(1)
		return
	var other: Node3D = game.extra_hunters[0]
	check(game.boss.position.distance_to(other.position) >= 8.0,"spawn separation")
	var positions: Dictionary = {}
	for stage in [1,3,5]:
		game.station.set_stage(stage)
		for i in range(10):
			var tile: Vector2i = game.safe_hunter_spawn([])
			positions[tile] = true
			var route: Array = game.station.path(1,game.station.cell(game.player.position),tile)
			check(route.size() >= 9,"safe reachable spawn distance")
			check(game.boss_motion_fraction(game.station.point(tile),game.station.point(tile)) == 1.0,"spawn body clearance")
	check(positions.size() > 3,"seeds produce diverse positions")
	var a: Vector3 = game.boss.position
	game.station.set_stage(1)
	var b: Vector3 = other.position
	game.boss_delay = 0
	other.delay = 0
	game.update_boss(0.1,false)
	game.update_extra_hunters(0.1,false)
	check(game.boss.position != a and other.position != b,"both independent actors move")
	game.set_mode("paused")
	check(not game.sound.chase.playing and not other.rig.animation.active,"pause stops sound and extra animation")
	game.set_mode("world")
	game.shift_cooldown = 0
	game.gate_lock = 0
	game.shift(game.station.GATES[1])
	a = game.boss.position
	game.update_boss(0.1,false)
	check(not game.boss_live and game.extra_hunters.is_empty(),"v7 Morning clears the full encounter")
	game.options.hunter_count = 1
	game.reset_lap("one hunter next lap")
	game.shift(game.station.GATES[0])
	game.deploy_after_submission()
	check(game.boss_live and game.extra_hunters.is_empty(),"next-lap preference applies standard single hunter")
	game.free()
	await process_frame
	print("HUNTER_POPULATION: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
