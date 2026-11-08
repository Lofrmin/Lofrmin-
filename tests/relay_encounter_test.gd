extends SceneTree

var game: Node3D
var checks := 0
var failures := 0
var sampled := 0
var visible_spawns := 0
var offscreen_spawns := 0

func validate_spawn(position: Vector3, label: String) -> void:
	var here := Vector3(game.player.position.x, 0, game.player.position.z)
	var distance := position.distance_to(here)
	check(distance >= 7.0 and distance <= 12.0, label + " distance7–12")
	check(game.hunter_has_sight(position), label + " LOS")
	check(game.boss_motion_fraction(position, position) >= 1.0, label + " static capsule clearance")
	var escape := false
	for step in range(16):
		var direction := Vector3(cos(float(step) * TAU / 16.0), 0, sin(float(step) * TAU / 16.0))
		if direction.dot((here - position).normalized()) < 0.15: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = game.boss_body
		query.transform = Transform3D(Basis.IDENTITY, here + Vector3.UP * 0.86)
		query.motion = direction * 5.0
		query.margin = 0.005
		query.exclude = [game.player.get_rid()]
		query.collision_mask = game.PLAYER_COLLISION_MASK
		if root.world_3d.direct_space_state.intersect_shape(query, 1).is_empty() and root.world_3d.direct_space_state.cast_motion(query)[0] == 1.0:
			escape = true
	check(escape, label + " player has actual5m retreat")

func verify_matrix() -> void:
	for stage in range(1, 6):
		game.clear_extra_hunters()
		game.boss_live = false
		game.dusk_trials.clear()
		game.station.set_stage(stage)
		check(game.dusk_trials.begin("relay", game.station, 1), "matrix stage starts")
		await physics_frame
		for index in range(3):
			var site: Dictionary = game.dusk_trials.sites[index]
			var positions: Array[Vector3] = [game.station.point(site.tile) + Vector3.UP * 0.05]
			for step in range(8):
				var angle := float(step) * TAU / 8.0
				positions.append(site.position + Vector3(cos(angle) * 1.62, 0.05, sin(angle) * 1.62))
			for at in positions:
				game.player.position = at
				if game.boss_motion_fraction(Vector3(at.x, 0, at.z), Vector3(at.x, 0, at.z)) < 1.0:
					continue
				check(game.dusk_trials._nearest_site(at) == index, "sample within actual E circle")
				for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
					for pitch in [0.0, -1.35, 1.35]:
						game.player.rotation.y = yaw
						game.camera.rotation.x = pitch
						var position: Vector3 = game.relay_hunter_spawn()
						sampled += 1
						check(position != Vector3.INF, "matrix stage%d pillar%d at%s yaw%.2f pitch%.2f has safe deployment" % [stage, index, at, yaw, pitch])
						if position == Vector3.INF: continue
						validate_spawn(position, "matrix")
						if game.camera.is_position_in_frustum(position + Vector3.UP * 1.3):
							visible_spawns += 1
						else:
							offscreen_spawns += 1
		print("RELAY_MATRIX stage=", stage, " sampled=", sampled, " screen_visible=", visible_spawns, " offscreen=", offscreen_spawns)
	game.dusk_trials.clear()
	game.station.set_stage(5)
	game.dusk_trials.begin("relay", game.station, 1)
	await physics_frame

func verify_atomic_failure() -> void:
	game.clear_extra_hunters()
	game.boss_live = false
	game.dusk_trials._reset_attempt("test")
	game.dusk_trials.interact(game.dusk_trials.sites[0].position + Vector3.LEFT)
	game.dusk_trials.relay_activation_events.clear()
	game.dusk_trials.interact(game.dusk_trials.sites[1].position + Vector3.LEFT)
	game.dusk_trials.relay_activation_events.clear()
	game.dusk_trials.interact(game.dusk_trials.sites[2].position + Vector3.LEFT)
	check(game.dusk_trials.completed, "fixture reaches tentative completion before consume")
	var position: Vector3 = game.dusk_trials.sites[2].position + Vector3.LEFT
	game.player.position = position + Vector3.UP * 0.05
	for count in range(3):
		check(game.spawn_relay_hunter(), "rollback fixture has three old encounters")
	var old_hunters: Array = game.extra_hunters.duplicate()
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 3, 30)
	shape.shape = box
	blocker.add_child(shape)
	game.add_child(blocker)
	blocker.position = Vector3(position.x, 1, position.z)
	await physics_frame
	game.consume_relay_activations()
	check(not game.dusk_trials.completed and game.dusk_trials.progress == 2, "failed deployment rolls back completion atomically")
	check(game.dusk_trials.relay_timers[2] == 0.0 and game.dusk_trials.relay_timers[0] > 0.0, "rollback only affects failed lamp")
	check(game.extra_hunters == old_hunters and game.dusk_trials.relay_activation_events.is_empty(), "failed deployment preserves every old actor and leaves no stale event")
	check("关闭" in game.notice, "failed deployment explicitly reported")
	blocker.queue_free()
	await physics_frame
	check(game.dusk_trials.interact(game.player.position), "rolled-back final lamp can retry")
	game.consume_relay_activations()
	check(game.dusk_trials.completed and game.extra_hunters.size() == 3 and not game.extra_hunters.has(old_hunters[0]), "successful retry atomically locks lamp and replaces oldest only after safe spawn")
	game.clear_extra_hunters()
	game.dusk_trials.completed = false
	game.dusk_trials._reset_attempt("test")
	game.camera.rotation.x = 1.35
	game.interact()
	check(game.extra_hunters.size() == 1 and game.dusk_trials.progress == 1, "extreme-pitch real activation still spawns exactly one")
	check("米" in game.notice and "方位警报" in game.notice, "offscreen spawn explicitly gives direction and distance")
	check(not game.extra_hunters.is_empty() and game.audio_hunter == game.extra_hunters.back() and game.sound.cues.deploy.get_parent() == game.extra_hunters.back(), "deployment audio comes from newly spawned hunter")
	game.camera.rotation.x = 0.0
	game.clear_extra_hunters()
	game.dusk_trials._reset_attempt("test")

func verify_crowding() -> void:
	for stage in range(1, 6):
		game.clear_extra_hunters()
		game.boss_live = false
		game.dusk_trials.clear()
		game.station.set_stage(stage)
		game.dusk_trials.begin("relay", game.station, 1)
		await physics_frame
		for site in game.dusk_trials.sites:
			game.clear_extra_hunters()
			game.boss_live = false
			game.player.position = site.position + Vector3(-1.0, 0.05, 0)
			game.camera.rotation.x = 0.0
			game.player.rotation.y = 0.0
			# The ordinary hunter occupies the originally preferred spawn point.
			var occupied: Vector3 = game.relay_hunter_spawn()
			check(occupied != Vector3.INF, "ordinary-hunter occupancy setup")
			game.boss.position = occupied
			game.boss_live = true
			game.boss_phase = 1
			for retry in range(7):
				check(game.spawn_relay_hunter(), "crowded retry always replaces or adds safely stage%d" % stage)
				check(game.extra_hunters.size() == mini(retry + 1, 3), "relay encounter cap3 maintained")
				if not game.extra_hunters.is_empty():
					validate_spawn(game.extra_hunters.back().position, "crowded retry")
					check(game.extra_hunters.back().position.distance_to(game.boss.position) >= 4.0, "ordinary hunter keeps safe separation")
					for other in game.extra_hunters:
						if other != game.extra_hunters.back():
							check(other.position.distance_to(game.extra_hunters.back().position) >= 4.0, "new hunter separated from retained old encounters")
	game.clear_extra_hunters()
	game.boss_live = false
	game.dusk_trials.clear()
	game.station.set_stage(5)
	game.dusk_trials.begin("relay", game.station, 1)
	await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await physics_frame
	game.chapter = 2
	game.trials_chapter = 2
	game.station.set_stage(5)
	game.phase = 1
	game.map_phase = 1
	game.station.set_phase(1)
	game.set_mode("world")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.interface.hide()
	game.interface.set_process(false)
	await verify_matrix()
	await verify_atomic_failure()
	await verify_crowding()
	game.dusk_trials.clear()
	check(game.dusk_trials.begin("relay", game.station, 1), "relay starts")
	await physics_frame
	for index in range(3):
		var site: Dictionary = game.dusk_trials.sites[index]
		game.player.position = site.position + Vector3(0.0, 0.05, -1.0)
		await physics_frame
		var before: int = game.extra_hunters.size()
		game.interact()
		check(game.extra_hunters.size() == before + 1, "each column creates one hunter: %d" % index)
		check(game.dusk_trials.relay_activation_events.is_empty(), "activation consumed once")
		if game.extra_hunters.size() == before: continue
		var hunter: Node3D = game.extra_hunters.back()
		var distance: float = hunter.position.distance_to(Vector3(game.player.position.x, 0, game.player.position.z))
		check(distance >= 7.0 and distance <= 12.0, "near encounter distance")
		check(game.hunter_has_sight(hunter.position), "spawn unobstructed")
		check(game.boss_motion_fraction(hunter.position, hunter.position) >= 1.0, "spawn capsule clear")
		check(hunter.delay >= 0.8 and hunter.charge_recovery >= 3.0, "reaction window before pursuit and charge")
		var position: Vector3 = hunter.position
		game.update_extra_hunters(0.2, false)
		check(hunter.position == position and hunter.visible, "visible before it starts moving")
		game.interact()
		check(game.extra_hunters.size() == before + 1, "repeat lit column cannot spawn more")
		print("RELAY_SPAWN ", index, " pos=", position, " distance=", distance, " in_view=", game.camera.is_position_in_frustum(position + Vector3.UP * 1.3))
	# Pause freezes clocks and pursuers through the public physics entry point.
	game.dusk_trials.completed = false
	var timers: Array = game.dusk_trials.relay_timers.duplicate()
	game.set_mode("paused")
	game.tick_game_physics(10.0)
	check(game.dusk_trials.relay_timers == timers, "pause freezes column timers")
	game.set_mode("world")
	game.shift_cooldown = 0.0
	game.gate_lock = 0.0
	game.shift(game.station.GATES[0])
	check(game.phase == 0 and game.extra_hunters.is_empty(), "morning removes relay hunters")
	game.dusk_trials.update(0.01, game.player.position, false, 0)
	check(game.dusk_trials.progress == 0, "leaving dusk resets unfinished attempt")
	game.dusk_trials.clear()
	check(game.dusk_trials.relay_activation_events.is_empty(), "clear discards pending spawns")
	print("RELAY_ENCOUNTER_TEST: %d checks / %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
