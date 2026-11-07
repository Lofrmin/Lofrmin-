extends SceneTree

var game: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func settle() -> void:
	await physics_frame
	await physics_frame

func arm(link: Dictionary, player_pos: Vector3, hunter_pos: Vector3) -> bool:
	var laser = game.station.laser_grid
	laser.clear()
	laser.probe = 100.0
	if not laser.try_spawn(link, player_pos, hunter_pos): return false
	laser.update(0.9, 1, true, player_pos, hunter_pos)
	await settle()
	return laser.active.size() == 1 and not laser.active[0].warning

func create_game() -> Node3D:
	return load("res://tests/fixture.gd").new()

func prepare_game() -> void:
	pass

func run() -> void:
	game = create_game()
	root.add_child(game)
	await settle()
	prepare_game()
	var map = game.station
	var laser = map.laser_grid
	game.phase = 1
	game.map_phase = 1
	map.set_phase(1)
	game.dev_god = true
	await settle()
	var chosen: Dictionary = {}
	var far_hunter := Vector3.ZERO
	for link in map.laser_links:
		if not map.walkable(1, link.a) or not map.walkable(1, link.b): continue
		if game.boss_motion_fraction(map.point(link.a), map.point(link.b)) < 1.0: continue
		for gate in map.GATES:
			var remote: Vector3 = map.point(gate)
			if remote.distance_to(link.center) < 24.0: continue
			if laser.safe_after(link, link.a, remote) and laser.safe_after(link, link.b, remote):
				chosen = link
				far_hunter = remote
				break
		if not chosen.is_empty(): break
	check(not chosen.is_empty(), "real-map beam supports safe player tests from both sides")
	if not chosen.is_empty():
		var normal: Vector3 = chosen.normal
		for sign_value in [1.0, -1.0]:
			var start: Vector3 = chosen.center - normal * 2.0 * sign_value
			game.player.position = start + Vector3.UP * 0.05
			check(await arm(chosen, start, far_hunter), "safe laser activates for direction %d" % int(sign_value))
			var stayed_active := true
			for tick in range(90):
				await physics_frame
				game.player.velocity = normal * sign_value * 6.25 + Vector3.DOWN * 6.0
				game.player.move_and_slide()
				laser.update(1.0 / 60.0, 1, true, game.player.position, far_hunter)
				stayed_active = stayed_active and laser.active.size() == 1 and map.laser_edges.has(chosen.key)
			var side: float = (game.player.position - chosen.center).dot(normal) * sign_value
			check(side < -0.33 and side > -0.50, "90 real sprint move_and_slide frames stop at laser capsule margin (%d: %.3f)" % [int(sign_value), side])
			check(stayed_active, "same beam remains active throughout player collision test")
		# Warning is deliberately transparent for its entire 0.85-second duration.
		laser.clear()
		game.player.position = map.point(chosen.a) + Vector3.UP * 0.05
		check(laser.try_spawn(chosen, game.player.position, far_hunter), "warning fixture starts")
		laser.probe = 100.0
		check(laser.active[0].label.text.contains("暂不阻挡"), "warning explicitly explains no collision")
		for tick in range(35):
			await physics_frame
			game.player.velocity = normal * 6.25 + Vector3.DOWN * 6.0
			game.player.move_and_slide()
			laser.update(1.0 / 60.0, 1, true, game.player.position, far_hunter)
		check((game.player.position - chosen.center).dot(normal) > 0.35, "real sprint can pass during warning")
		check(laser.active.size() == 1 and laser.active[0].warning and map.laser_edges.is_empty(), "warning has neither physical nor player-route blockage")
		laser.clear()
		# Retraction near a hunter remains intentional escape protection, not a collision failure.
		var start: Vector3 = map.point(chosen.a)
		game.player.position = start + Vector3.UP * 0.05
		check(await arm(chosen, start, far_hunter), "safety retraction fixture activates")
		laser.update(0.21, 1, true, game.player.position, start)
		check(laser.active.is_empty() and map.laser_edges.is_empty(), "10m hunter danger still retracts a beam before trapping the player")
		# Separate expiry from danger: a safe beam survives until lifetime, then passage returns.
		check(await arm(chosen, start, far_hunter), "expiry fixture activates")
		laser.update(4.51, 1, true, game.player.position, far_hunter)
		await settle()
		for tick in range(45):
			await physics_frame
			game.player.velocity = normal * 6.25 + Vector3.DOWN * 6.0
			game.player.move_and_slide()
		check(laser.active.is_empty() and (game.player.position - chosen.center).dot(normal) > 1.0, "expiry restores real sprint passage")

	# Find a genuine safe escape layout with the player far from a hunter crossing the beam.
	# Keep the live safety update running; never freeze/rewrite its safety timer or lifetime.
	var crossing: Dictionary = {}
	var remote_player := Vector3.ZERO
	var initial_hunter := Vector3.ZERO
	for link in map.laser_links:
		if not map.walkable(1, link.a) or not map.walkable(1, link.b): continue
		if game.boss_motion_fraction(map.point(link.a), map.point(link.b)) < 1.0: continue
		for gate in map.GATES:
			var target: Vector3 = map.point(gate)
			if target.distance_to(link.center) < 20.0: continue
			if not laser.safe_after(link, gate, map.point(link.a)) or not laser.safe_after(link, gate, map.point(link.b)): continue
			for source in map.GATES:
				var origin: Vector3 = map.point(source)
				if not laser.near_plane(link, origin, 0.85) and laser.safe_after(link, gate, origin):
					crossing = link
					remote_player = target
					initial_hunter = origin
					break
			if not crossing.is_empty(): break
		if not crossing.is_empty(): break
	check(not crossing.is_empty(), "real escape graph allows hunter crossing while laser safely remains live")
	if not crossing.is_empty():
		game.player.position = remote_player + Vector3.UP * 0.05
		for extra_actor in [false, true]:
			check(await arm(crossing, remote_player, initial_hunter), "live beam armed before hunter crossing")
			game.boss_live = true
			game.boss_phase = 1
			game.boss.position = map.point(crossing.a)
			game.boss_delay = 0.0
			game.charge_recovery = 100.0
			game.tracking_time = 100.0
			game.last_known = crossing.b
			game.boss_route.clear()
			game.path_timer = 0.0
			var actor: Node3D = game.boss
			if extra_actor:
				actor = load("res://hunter_agent.gd").new()
				game.add_child(actor)
				actor.position = map.point(crossing.a)
				actor.delay = 0.0
				actor.charge_recovery = 100.0
				actor.tracking_time = 100.0
				actor.last_known = crossing.b
				actor.target_position = map.point(crossing.b)
			var remained := true
			var capsule_clear := true
			for tick in range(65):
				await physics_frame
				if extra_actor: actor.update_agent(game, 1.0 / 60.0, false)
				else: game.update_boss(1.0 / 60.0, false)
				var positions: Array[Vector3] = []
				if extra_actor: positions.append(actor.position)
				laser.update(1.0 / 60.0, 1, true, game.player.position, initial_hunter if extra_actor else actor.position, positions)
				remained = remained and laser.active.size() == 1 and map.laser_edges.has(crossing.key)
				capsule_clear = capsule_clear and game.boss_motion_fraction(actor.position, actor.position) == 1.0
			var progress: float = (actor.position - crossing.center).dot(crossing.normal)
			check(progress > 0.70, "%s actual AI crosses running beam (%.3fm beyond plane)" % ["extra" if extra_actor else "boss", progress])
			check(remained, "beam never retracted early during actual hunter crossing")
			check(capsule_clear, "hunter crossing stays clear of real walls and fixtures")
			if extra_actor: actor.free()
			laser.clear()
	game.free()
	await process_frame
	print("LASER_PLAYER_ONLY_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
