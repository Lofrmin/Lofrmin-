extends SceneTree

var checks := 0
var failures: Array[String] = []
var game: Node3D

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		printerr("FAIL: " + text)

func _initialize() -> void:
	call_deferred("run")

func dusk(tile: Vector2i) -> void:
	game.stop_dusk_chase()
	game.phase = 1
	game.map_phase = 1
	game.station.set_phase(1)
	game.player.position = game.station.point(tile) + Vector3.UP * 0.05
	game.dusk_grace = 0.0
	game.dev_god = true
	game.set_mode("world")

func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await physics_frame
	var map = game.station
	# Every evidence terminal in every authored break stage, not a radius-only sample.
	for stage in range(1, 6):
		map.set_stage(stage)
		for terminal in [map.OFFICE, map.LAB, map.MEDICAL, map.LEDGER, map.RELAY]:
			dusk(terminal)
			await physics_frame
			game.deploy_after_submission()
			check(game.boss_live and game.boss_phase == 1, "S%d %s original gate hunter retained" % [stage, terminal])
			check(game.extra_hunters.size() == 2, "S%d %s two safe nearby hunters: %s" % [stage, terminal, game.hunter_spawn_report])
			check(game.gate_lock == 12.0 and game.tracking_time >= 14.0, "lock and initial tracking remain")
			var positions: Array[Vector3] = []
			for hunter in game.extra_hunters:
				var distance: float = hunter.position.distance_to(Vector3(game.player.position.x, 0, game.player.position.z))
				check(distance >= 8.0 and distance <= 16.0, "nearby spawn in 8-16m ring")
				check(map.walkable(1, map.cell(hunter.position)) and game.boss_motion_fraction(hunter.position, hunter.position) == 1.0, "spawn capsule clear of walls and fixtures")
				check(map.cell(hunter.position) not in map.GATES + [map.AUDIT, map.OFFICE, map.LAB, map.MEDICAL, map.LEDGER, map.RELAY], "spawn avoids doors and terminals")
				var route: PackedVector3Array = game.hunter_spawn_route(hunter.position, game.player.position)
				var length: float = game.route_world_length(route)
				check(route.size() > 1 and length <= 24.01 and length <= distance * 1.8 + 0.01, "full physical route within encounter budget")
				for i in range(1, route.size()):
					check(game.boss_motion_fraction(route[i - 1], route[i]) >= 1.0, "planned route contains no wall crossing")
				positions.append(hunter.position)
			if positions.size() == 2:
				check(positions[0].distance_to(positions[1]) >= 6.0 and (positions[0] - game.player.position).angle_to(positions[1] - game.player.position) >= 0.65, "spawn comes from separated directions")
			# Repeated explicit deployment replaces nodes, never accumulates a third extra.
			var previous: Array = game.extra_hunters.duplicate()
			game.deploy_after_submission()
			check(game.extra_hunters.size() == 2, "repeat submission keeps fixed-size pool")
			for hunter in previous: check(hunter.is_queued_for_deletion() and not hunter.live, "old deployment retired")
			# Alarm tracks within-cell player movement even while actors are delayed/stunned.
			game.player.position += Vector3(0.41, 0, 0.33)
			game.update_boss(0.01, false)
			game.update_extra_hunters(0.01, false)
			check(game.last_known == map.cell(game.player.position) and game.tracking_time > 13.0, "gate hunter does not shorten long tracking")
			for hunter in game.extra_hunters:
				check(hunter.target_position.distance_to(Vector3(game.player.position.x, 0, game.player.position.z)) < 0.01 and hunter.tracking_time > 13.0, "extra alarm locks exact current coordinates")
			# An accepted short route must also be followed by the actual independent AI.
			var met := false
			var motion_safe := true
			for tick in range(80):
				game.update_extra_hunters(0.1, false)
				for extra in game.extra_hunters:
					if extra.position.distance_to(game.player.position) < 3.0: met = true
					motion_safe = motion_safe and game.boss_motion_fraction(extra.position, extra.position) >= 1.0
			check(met, "S%d %s actual nearby AI arrives within eight seconds" % [stage, terminal])
			check(motion_safe, "S%d %s actual motion remains outside physics geometry" % [stage, terminal])
			game.stop_dusk_chase()
			await physics_frame

	# Real two-actor capsule movement to a stationary off-center player.
	map.set_stage(1)
	dusk(map.LAB)
	await physics_frame
	game.deploy_after_submission()
	var hunter = game.extra_hunters[0]
	var center: Vector3 = map.point(map.LAB + Vector2i(0, -1))
	game.player.position = center + Vector3(1.3, 0.05, 1.3)
	hunter.position = center
	hunter.delay = 0.0
	hunter.charge_recovery = 100.0
	hunter.visible = true
	game.dev_god = false
	var lap: int = game.laps
	await physics_frame
	for i in range(30):
		if game.laps != lap: break
		game.update_extra_hunters(0.1, false)
		await physics_frame
	check(game.laps > lap and game.extra_hunters.is_empty() and not game.boss_live and game.phase == 0, "extra catches stationary player and death clears entire pool")

	# Pulse affects multiple visible extras but spends one charge; hidden actors stay immune.
	dusk(map.LAB)
	await physics_frame
	game.deploy_after_submission()
	game.player.position = center + Vector3(0.8, 0.05, 0.8)
	game.boss.position = map.point(map.GATES[0])
	for i in range(game.extra_hunters.size()):
		game.extra_hunters[i].position = center + Vector3(-1.1 - i, 0, 0.7)
		game.extra_hunters[i].visible = true
		game.extra_hunters[i].delay = 0.0
	game.charges = 2
	await physics_frame
	game.pulse()
	check(game.charges == 1, "area pulse spends exactly one charge")
	for extra in game.extra_hunters: check(extra.stunned == 2.25, "extra actor actually stunned")
	check(game.nearest_hunter() != game.boss and game.threat_text().contains("失相"), "HUD chooses nearby extra over distant original")
	game.focus_hunter_audio(game.nearest_hunter())
	check(game.sound.hunter_step.get_parent() == game.nearest_hunter(), "spatial audio follows nearest danger")
	game.set_mode("paused")
	for extra in game.extra_hunters: check(not extra.rig.animation.active, "pause freezes extra animation")
	var before: Vector3 = game.extra_hunters[0].position
	game.tick_game_physics(1.0)
	check(game.extra_hunters[0].position == before, "pause freezes extra movement")
	game.set_mode("world")
	game.gate_lock = 0.0
	game.shift_cooldown = 0.0
	game.boss_delay = 1.3
	game.charge_recovery = 2.1
	game.tracking_time = 9.0
	game.path_timer = 0.2
	game.shift(map.GATES[0])
	check(game.phase == 0 and game.extra_hunters.is_empty() and not game.boss_live and game.threat == 0.0, "Morning shift clears pool immediately")
	check(game.boss_delay == 0.0 and game.charge_recovery == 0.0 and game.tracking_time == 0.0 and game.path_timer == 0.0, "Morning clears every original hunter timer")

	# No through-wall settlement or pulse, including an actor only 0.9m away.
	dusk(map.LAB)
	await physics_frame
	game.deploy_after_submission()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, 3.0, 3.0)
	shape.shape = box
	body.add_child(shape)
	game.add_child(body)
	body.position = center + Vector3.UP * 1.5
	hunter = game.extra_hunters[0]
	hunter.position = center + Vector3(-0.45, 0, 0)
	hunter.delay = 0.0
	hunter.visible = true
	hunter.stunned = 0.0
	game.extra_hunters[1].position = map.point(map.RELAY)
	game.player.position = center + Vector3(0.45, 0.05, 0)
	game.boss.position = map.point(map.GATES[0])
	game.charges = 1
	game.dev_god = false
	lap = game.laps
	await physics_frame
	game.pulse()
	check(game.charges == 1 and hunter.stunned == 0.0, "wall blocks pulse against extra actor")
	for i in range(10):
		game.update_extra_hunters(0.1, false)
		await physics_frame
	check(game.laps == lap and hunter.position.x < center.x - 0.29, "extra cannot cross thin wall or settle through it")
	body.free()

	# Chapter/reset/dev lifecycle removes all extras, including queued rig animation.
	game.dev_god = true
	game.chapter = 3
	game.update_witness()
	check(game.extra_hunters.is_empty() and not game.boss_live, "chapter change clears actors")
	dusk(map.LAB)
	await physics_frame
	game.deploy_after_submission()
	game.dev_teleport()
	check(game.extra_hunters.is_empty() and not game.boss_live, "developer relocation clears actors")

	# Dynamic lasers must reject extras at the plane and on escape branches.
	var laser = map.laser_grid
	var chosen: Dictionary = {}
	var player_position := Vector3.ZERO
	var boss_position := Vector3.ZERO
	for link in map.laser_links:
		if not map.walkable(1, link.a) or not map.walkable(1, link.b): continue
		for gate in map.GATES:
			var origin: Vector3 = map.point(gate)
			if origin.distance_to(link.center) > 20.0 and laser.safe_after(link, link.a, origin):
				chosen = link
				player_position = map.point(link.a)
				boss_position = origin
				break
		if not chosen.is_empty(): break
	check(not chosen.is_empty(), "real map laser safety fixture found")
	if not chosen.is_empty():
		var extras: Array[Vector3] = [chosen.center]
		check(not laser.try_spawn(chosen, player_position, boss_position, extras), "new laser cannot intersect extra actor")
		extras = [player_position]
		check(not laser.safe_after(chosen, chosen.a, boss_position, extras), "extra danger included across entire escape graph")
		check(laser.try_spawn(chosen, player_position, boss_position), "warning accepted before extra approaches")
		laser.probe = 100.0
		extras = [chosen.center]
		laser.update(0.9, 1, true, player_position, boss_position, extras)
		check(laser.active.is_empty() and map.laser_edges.is_empty(), "warning retracts instead of materializing through extra")
		check(laser.try_spawn(chosen, player_position, boss_position), "second laser fixture starts")
		laser.update(0.9, 1, true, player_position, boss_position)
		extras = [player_position]
		laser.update(0.21, 1, true, player_position, boss_position, extras)
		check(laser.active.is_empty() and map.laser_edges.is_empty(), "active barrier retracts when extra makes routes unsafe")
	game.free()
	await process_frame
	print("HUNTER_GROUP_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
