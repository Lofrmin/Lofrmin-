extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.set_mode("world")
	game.charges = 1
	game.shift(game.station.GATES[0])
	check(game.phase == 1, "entering any Dusk gate changes phase")
	check(game.boss_live and game.boss_phase == 1, "Dusk entry deploys one live hunter immediately")
	var gate_path: Array[Vector2i] = game.station.path(1, game.station.cell(game.boss.position), game.station.GATES[0])
	check(game.station.walkable(1, game.station.cell(game.boss.position)), "hunter spawn is on a walkable Dusk tile")
	var spawn_tile: Vector2i = game.station.cell(game.boss.position)
	var spawn_comes_from_patrol_route := false
	for anchor in [game.station.LAB, game.station.LEDGER, game.station.RELAY, game.station.OFFICE]:
		var route: Array[Vector2i] = game.station.path(1, game.station.GATES[0], anchor)
		if route.size() >= 9 and route[mini(10, route.size() - 1)] == spawn_tile:
			spawn_comes_from_patrol_route = true
	check(spawn_comes_from_patrol_route, "hunter spawn is a reachable waypoint along an authored patrol route")
	check(gate_path.size() >= 8, "first spawn is not on top of the entry gate")
	var grace_value: Variant = game.get("dusk_grace")
	var grace_used: Variant = game.get("dusk_grace_used")
	check(grace_value is float or grace_value is int, "Dusk entry exposes a short no-hit grace timer")
	check(grace_used is bool and grace_used, "first Dusk entry consumes this-loop grace")
	if not (grace_value is float or grace_value is int) or not (grace_used is bool):
		game.free()
		await process_frame
		print("DUSK_ENCOUNTER_TEST: %d checks / %d failures" % [checks, failures.size()])
		quit(1)
		return
	check(is_equal_approx(float(grace_value), 2.0), "entry grace is two seconds")

	var first_spawn: Vector3 = game.boss.position
	game.boss_delay = 0.0
	game.boss.position = game.player.position + Vector3(0.25, 0.0, 0.0)
	game.boss.visible = true
	game.dusk_grace = 1.0
	var lap_before: int = game.laps
	game.update_boss(0.01, false)
	check(game.laps == lap_before, "entry grace prevents contact reset")
	game.player.position = game.station.point(game.station.LAB) + Vector3.UP * 0.05
	game.boss_delay = 0.0
	game.charge_recovery = 0.0
	game.charge_time = 0.0
	game.charge_warning = 0.0
	await physics_frame
	var found_sight := false
	var player_tile: Vector2i = game.station.cell(game.player.position)
	for z_offset in range(-3, 4):
		for x_offset in range(-3, 4):
			var candidate: Vector2i = player_tile + Vector2i(x_offset, z_offset)
			var distance: float = game.station.point(candidate).distance_to(game.player.position)
			if distance < 2.5 or distance >= 7.8 or not game.station.walkable(1, candidate):
				continue
			game.boss.position = game.station.point(candidate)
			await physics_frame
			if game.has_sight():
				found_sight = true
				break
		if found_sight: break
	check(found_sight, "fixture has a visible charge-warning test position")
	if found_sight:
		game.dusk_grace = 0.5
		game.update_boss(0.01, false)
		check(is_zero_approx(game.charge_warning), "entry grace suppresses the dash telegraph")

	game.boss.position = first_spawn
	game.boss_delay = 0.0
	game.stunned = 0.7
	game.charge_recovery = 2.2
	game.charge_warning = 0.0
	game.charge_time = 0.0
	game.dusk_grace = 0.4
	var route_for_reset: Array[Vector2i] = []
	route_for_reset.append(game.station.RELAY)
	game.set("boss_route", route_for_reset)
	var stored_charges: int = game.charges
	game.shift_cooldown = 0.0
	game.shift(game.station.GATES[0])
	var morning_position: Vector3 = game.boss.position
	game.update_boss(0.3, false)
	check(not game.boss_live and not game.boss_chasing and not game.boss.visible and game.boss_route.is_empty(), "Morning clears the Dusk encounter under v7 safety rules")
	check(game.boss.position == morning_position, "hunter freezes instead of crossing into Morning")
	check(is_zero_approx(game.stunned) and is_zero_approx(game.charge_warning) and is_zero_approx(game.charge_time), "Morning clears active chase effects")
	check(game.charges == stored_charges, "phase travel never restores pulse charges")
	check(is_equal_approx(game.dusk_grace, 0.4) and game.dusk_grace_used, "leaving Dusk preserves the consumed grace state")
	game.shift_cooldown = 0.0
	game.shift(game.station.GATES[1])
	check(game.phase == 1 and game.boss_live and game.boss_phase == 1 and game.station.walkable(1, game.station.cell(game.boss.position)), "re-entering Dusk deploys a valid patrol after Morning safety cleanup")
	check(is_equal_approx(game.dusk_grace, 0.4), "a repeated gate crossing cannot refresh entry grace")
	check(game.charges == stored_charges, "gate toggling cannot restore pulse charges")

	var map_key := InputEventKey.new()
	map_key.pressed = true
	map_key.physical_keycode = KEY_M
	game._input(map_key)
	var time_before: float = game.time_in_lap
	game.tick_game_physics(0.1)
	check(game.big_map and game.time_in_lap > time_before, "full map keeps the world simulation running")
	map_key.physical_keycode = KEY_ESCAPE
	game._input(map_key)
	check(not game.big_map and game.mode == "world", "first Escape closes the live map")
	game._input(map_key)
	check(game.mode == "paused" and not game.sound.chase.playing, "second Escape pauses and stops chase ambience")
	game._input(map_key)
	game.reset_lap("test loop")
	check(game.phase == 0 and not game.boss_live and game.boss_route.is_empty(), "a new loop returns safely to Morning and clears the previous encounter")
	check(not game.dusk_grace_used and is_zero_approx(game.dusk_grace) and game.charges == 2, "a fresh loop starts with fresh encounter protection and pulse charges")
	game.shift(game.station.GATES[2])
	check(game.boss_live and game.phase == 1 and game.dusk_grace_used, "the next Dusk visit starts a new encounter and grants one grace")

	game.chapter = 2
	game.phase = 0
	game.map_phase = 0
	game.station.set_phase(0)
	game.player.position = game.station.point(game.station.AUDIT) + Vector3.UP * 0.05
	game.solved = true
	game.armed = true
	game.patched = true
	game.upload = 0.0
	game.set_mode("audit")
	game.boss_live = true
	game.boss_phase = 1
	game.boss.position = first_spawn
	game.begin_upload()
	check(is_equal_approx(game.upload, 6.0), "final upload still lasts six seconds")
	check(not game.boss_live and not game.boss_chasing and not game.boss.visible, "upload keeps Morning free of hunters")
	check(game.boss_route.is_empty() and is_zero_approx(game.threat), "upload clears chase routes and HUD threat")
	check(not game.sound.chase.playing, "upload does not start chase ambience")
	game.upload = 4.5
	game.set_mode("audit")
	game.begin_upload()
	check(is_equal_approx(game.upload, 4.5), "upload cannot be restarted to reset its clock")
	game.set_mode("world")
	game.shift_cooldown = 0.0
	game.shift(game.station.GATES[0])
	check(game.phase == 0, "final upload cannot move into Dusk")

	game.free()
	await process_frame
	print("DUSK_ENCOUNTER_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
