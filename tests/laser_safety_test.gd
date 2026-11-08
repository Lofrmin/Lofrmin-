extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		printerr("FAIL: " + text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await process_frame
	var map = game.station
	var laser = map.laser_grid
	check(map.laser_links.size() > 100, "existing pillar pairs registered")
	check(map.emitter_positions[0].size() > 100 and map.emitter_positions[1].size() > 100, "uniform sleeves on both maps")
	var chosen: Dictionary = {}
	var player_pos := Vector3.ZERO
	var hunter_pos := Vector3.ZERO
	for link in map.laser_links:
		if not map.walkable(1, link.a) or not map.walkable(1, link.b): continue
		for gate in map.GATES:
			var hunter: Vector3 = map.point(gate)
			if hunter.distance_to(link.center) < 20.0: continue
			if laser.safe_after(link, link.a, hunter):
				chosen = link
				player_pos = map.point(link.a)
				hunter_pos = hunter
				break
		if not chosen.is_empty(): break
	check(not chosen.is_empty(), "real map has safe trigger candidates")
	if not chosen.is_empty():
		check(not laser.try_spawn(chosen, chosen.center, hunter_pos), "no beam materializes through player")
		check(not laser.try_spawn(chosen, player_pos, chosen.center), "no beam materializes through hunter")
		check(not laser.safe_after(chosen, chosen.a, player_pos), "hunter closes sole local escape; reject")
		check(laser.try_spawn(chosen, player_pos, hunter_pos), "safe candidate starts warning")
		check(map.laser_edges.is_empty(), "warning has no collision or route obstruction")
		check(laser.active[0].body.collision_layer == 0, "warning body inactive")
		# Test one authored barrier; random extra spawns have their own integration path.
		laser.probe = 100.0
		laser.update(0.9, 1, true, player_pos, hunter_pos)
		check(laser.active.size() == 1 and map.laser_edges.has(chosen.key), "warning becomes active grid edge")
		check(laser.active[0].body.collision_layer == 2 and laser.active[0].body.collision_mask == 0, "active beam uses player-only collision layer")
		check(game.player.collision_mask == 3, "player collides with world and active laser layers")
		var route: Array[Vector2i] = map.path(1, chosen.a, chosen.b)
		check(route.size() > 2, "player routing detours around blocked edge")
		for i in range(1, route.size()): check(not laser.blocked(route[i-1], route[i]), "player route never crosses laser")
		var hunter_route: Array[Vector2i] = map.hunter_path(1, chosen.a, chosen.b)
		check(hunter_route == [chosen.a, chosen.b], "hunter routing crosses the same active edge directly")
		await physics_frame
		await physics_frame
		game.player.position = map.point(chosen.b) + Vector3.UP * 0.05
		check(game.boss_motion_fraction(map.point(chosen.a), map.point(chosen.b)) == 1.0, "hunter capsule ignores active laser")
		check(game.hunter_has_sight(map.point(chosen.a)), "hunter sight ignores active laser")
		check(game.hunter_spawn_route(map.point(chosen.a), map.point(chosen.b)).size() == 2, "hunter spawn route ignores active laser")
		laser.update(0.21, 1, true, player_pos, player_pos)
		check(laser.active.is_empty() and map.laser_edges.is_empty(), "danger approaching escape routes retracts grid")
		check(laser.try_spawn(chosen, player_pos, hunter_pos), "respawn test barrier")
		laser.probe = 100.0
		laser.update(0.9, 1, true, player_pos, hunter_pos)
		laser.update(5.0, 1, true, player_pos, hunter_pos)
		check(laser.active.is_empty() and map.laser_edges.is_empty(), "lifetime clears physical and route state")
		laser.try_spawn(chosen, player_pos, hunter_pos)
		map.set_phase(0)
		check(laser.active.is_empty() and map.laser_edges.is_empty(), "morning clears even warning grids")
	# Explicit synthetic escape graph: connected does NOT mean safe.
	# Restrict the actual map's routes to one initial direction and ensure rejection.
	var saved_edges: Dictionary = map.laser_edges.duplicate()
	for direction in map.DIRECTIONS:
		map.laser_edges[laser.edge_key(map.AUDIT, map.AUDIT + direction)] = true
	check(not laser.safe_after({}, map.AUDIT, map.point(map.RELAY)), "trapped origin never accepted")
	map.laser_edges = saved_edges
	game.phase = 0
	game.activate_boss(map.RELAY)
	check(not game.boss_live, "morning spawn forbidden")
	game.phase = 1
	game.activate_boss(map.RELAY)
	check(game.boss_live and game.boss_phase == 1, "dusk deployment intact")
	game.gate_lock = 0.0
	game.shift(map.GATES[0])
	check(game.phase == 0 and not game.boss_live and not game.boss.visible and game.threat == 0.0, "return morning immediately removes hunter")
	game.boss_live = true
	game.boss_phase = 1
	var before: Vector3 = game.boss.position
	game.update_boss(20.0, true)
	check(not game.boss_live and game.boss.position == before, "cross-phase follow and settlement disabled")
	print("LASER_SAFETY_TEST: %d checks / %d failures" % [checks, failures.size()])
	game.free()
	quit(1 if not failures.is_empty() else 0)
