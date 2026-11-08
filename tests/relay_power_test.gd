extends SceneTree

const Trials := preload("res://dusk_trials.gd")
var checks := 0
var failures: Array[String] = []
var station: Node3D
var trial: RefCounted

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func approach(index: int) -> Vector3:
	return trial.sites[index].position + Vector3(-0.95, 0.05, 0)

func movement_constants() -> Dictionary:
	# Compile only the upstream numeric movement declarations, not game/assets.
	var source := "extends RefCounted\n"
	for line in FileAccess.get_file_as_string("res://game.gd").split("\n"):
		if line.begins_with("const PLAYER_WALK_SPEED ") or line.begins_with("const STAMINA_"):
			source += line + "\n"
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "upstream numeric movement constants compile")
	return script.get_script_constant_map()

func start_fresh() -> void:
	trial.clear()
	check(trial.begin("relay", station), "relay begins")

func verify_layout(stage: int) -> void:
	station.set_stage(stage)
	start_fresh()
	check(trial.sites.size() == 3 and trial.relay_timers.size() == 3, "three posts and independent timers")
	var forbidden: Array = trial._critical_tiles()
	for entry in station.breaks_for(1):
		forbidden.append_array(entry.tiles)
	var legs: Array[float] = []
	var movement: Dictionary = movement_constants()
	for index in range(3):
		var tile: Vector2i = trial.sites[index].tile
		var other: Vector2i = trial.sites[(index + 1) % 3].tile
		check(tile not in forbidden, "post avoids terminals, gates, return markers and every future break")
		check(not station.path(1, trial.anchor, tile).is_empty(), "post reachable from terminal")
		check(trial._relay_has_room(tile), "post has clear approaches and opposite spawn/exit lanes")
		var route: Array = station.path(1, tile, other)
		check(route.size() >= 21, "posts have substantial route separation")
		check(tile.distance_to(other) >= 18.0, "posts cover distinct map regions")
		legs.append(float(route.size() - 1) * station.CELL)
	legs.sort()
	check(legs[2] / legs[0] <= 1.55, "three route legs balanced")
	var worst_walk: float = (legs[1] + legs[2] + 4.0 * trial.SITE_OFFSET.length()) / movement.PLAYER_WALK_SPEED
	var recovery: float = movement.STAMINA_REGEN_DELAY + movement.STAMINA_MAX / movement.STAMINA_REGEN_RATE
	check(trial.time_limit >= worst_walk * 1.12 + recovery + 1.5, "all-walk budget covers worst order, bends, input and full stamina recovery")
	check(trial.time_limit > 35.0 and trial.time_limit < 110.0, "lifetime in playable range, not hundreds of seconds")
	trial.update(0.0, approach(0), false)
	check(trial.route_root.get_child_count() == 0 and trial.objective().is_empty(), "no ground arrows or ordered single target")
	for index in range(3):
		check("到这里" not in trial._labels[index].text, "no highlighted next post")
	var objectives: Array[Dictionary] = trial.map_objectives()
	check(objectives.size() == 3, "minimap receives all three posts")
	for index in range(objectives.size()):
		var objective: Dictionary = objectives[index]
		check(objective.has_all(["tile", "position", "label", "active", "remaining"]), "minimap schema complete")
		check(objective.tile == trial.sites[index].tile and objective.position == trial.sites[index].position, "minimap matches world")
		check(not objective.active and objective.remaining == 0.0, "minimap starts unpowered")
	print("RELAY_LAYOUT stage=%d sites=%s pair_distances_m=%s lifetime=%.0fs" % [stage, trial.sites, legs, trial.time_limit])

func verify_state() -> void:
	start_fresh()
	check(not trial.interact(station.point(station.RELAY)), "terminal cannot remotely start posts")
	check(not trial.interact(approach(1), 0), "morning cannot activate")
	check(not trial.interact(approach(1) + Vector3.UP * 3.0), "other floor cannot activate")
	check(trial.interact(approach(2)), "arbitrary first post handled")
	check(trial.relay_activation_events == [2] and trial.progress == 1, "first valid start emits exact index")
	trial.update(2.0, approach(2), false)
	var before: float = trial.relay_timers[2]
	check(trial.interact(approach(2)), "lit repeated E is consumed")
	check(is_equal_approx(before, trial.relay_timers[2]) and trial.relay_activation_events == [2], "repeat never refreshes nor emits")
	trial.relay_activation_events.clear()
	trial.interact(approach(0))
	check(trial.relay_activation_events == [0], "consumer can clear queue between valid starts")
	check(trial.relay_timers[0] > trial.relay_timers[2] and trial.progress == 2, "timers start independently")
	trial.update(trial.time_limit - 1.0, approach(0), false)
	check(trial.relay_timers[2] == 0.0 and trial.relay_timers[0] > 0.0 and trial.progress == 1, "only expired post goes dark")
	check(not trial.map_objectives()[2].active and trial.map_objectives()[0].active, "minimap reflects independent expiry")
	trial.interact(approach(2))
	check(trial.relay_activation_events == [0, 2], "expired post restart emits new event")
	check(trial.relay_timers[2] == trial.time_limit, "restart gets full own lifetime")
	var first_remaining: float = trial.relay_timers[0]
	var visual_id: int = trial.visual_root.get_instance_id()
	trial.begin("relay", station)
	check(trial.visual_root.get_instance_id() == visual_id and trial.relay_timers[0] == first_remaining, "terminal revisit preserves attempt")
	trial.update(-50.0, approach(0), false)
	check(trial.relay_timers[0] == first_remaining, "negative delta cannot increase timers")
	trial.interact(approach(1))
	check(trial.is_complete("relay") and trial.progress == 3, "all simultaneously powered locks completion")
	var locked: Array = trial.relay_timers.duplicate()
	trial.update(trial.time_limit * 2.0, approach(1), true)
	check(trial.is_complete() and trial.relay_timers == locked, "locked power does not expire")
	check(not trial.interact(approach(1)), "completed trial releases E")
	trial.update(0.1, station.point(trial.anchor), false)
	check(trial.route_root.get_child_count() == 0 and trial.objective().is_empty(), "completed relay still has no return arrow")
	check("返回" in trial.guidance() and "箭头" not in trial.message, "return guidance is text without promised arrows")
	trial.update(0.1, approach(1), false, 0)
	check(trial.completed, "completed prerequisite survives leaving dusk")
	start_fresh()
	trial.interact(approach(1))
	trial.update(0.0, approach(1), false, 0)
	check(trial.progress == 0 and trial.relay_timers == [0.0, 0.0, 0.0] and trial.relay_activation_events.is_empty(), "phase exit clears unfinished power and pending events")
	trial.update(0.0, approach(1), false, 1)
	trial.interact(approach(1))
	trial._reset_attempt("test reset")
	check(trial.relay_timers == [0.0, 0.0, 0.0] and trial.relay_activation_events.is_empty(), "attempt reset clears all independent state")
	trial.interact(approach(2))
	trial.clear()
	check(not trial.active and trial.relay_timers.is_empty() and trial.relay_activation_events.is_empty() and trial.map_objectives().is_empty(), "clear discards all public relay state")

func verify_orders() -> void:
	var movement: Dictionary = movement_constants()
	for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		start_fresh()
		trial.interact(approach(order[0]))
		for step in range(1, 3):
			var first: int = order[step - 1]
			var second: int = order[step]
			var route: Array = station.path(1, trial.sites[first].tile, trial.sites[second].tile)
			var distance: float = float(route.size() - 1) * station.CELL + 2.0 * trial.SITE_OFFSET.length()
			trial.update(distance / movement.PLAYER_WALK_SPEED + 0.75, approach(second), false)
			check(trial.relay_timers[order[0]] > 0.0, "first post survives actual walking route for order %s" % [order])
			trial.interact(approach(second))
		check(trial.completed and trial.relay_activation_events == order, "arbitrary walking order completes and emits once per post %s" % [order])

func verify_physical_clearance() -> void:
	start_fresh()
	await physics_frame
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.80
	for site in trial.sites:
		for axis in [Vector3.RIGHT, Vector3.BACK]:
			var sweep := PhysicsShapeQueryParameters3D.new()
			sweep.shape = capsule
			sweep.collision_mask = 1
			sweep.transform = Transform3D(Basis.IDENTITY, station.point(site.tile) + Vector3.UP * 0.95 - axis * 1.80)
			sweep.motion = axis * 3.60
			var motion := root.world_3d.direct_space_state.cast_motion(sweep)
			check(motion.size() == 2 and motion[0] == 1.0, "post leaves both centerline traversal directions open")
		# Inspect real static sight lanes from center and a reachable E approach.
		for player_position in [station.point(site.tile) + Vector3.UP * 0.05, site.position + Vector3(-0.95, 0.05, 0)]:
			var available_axis := false
			for axis in [Vector3.RIGHT, Vector3.BACK]:
				var both_clear := true
				for side in [-1, 1]:
					var target: Vector3 = player_position + axis * 9.0 * side
					var ray := PhysicsRayQueryParameters3D.create(player_position + Vector3.UP * 1.32, target + Vector3.UP * 1.32, 1)
					if not root.world_3d.direct_space_state.intersect_ray(ray).is_empty() or not station.walkable(1, station.cell(target)):
						both_clear = false
				if both_clear:
					available_axis = true
			check(available_axis, "center/offset interaction has visible 9m spawn and opposite exit")

func run() -> void:
	station = load("res://station.gd").new()
	root.add_child(station)
	station.use_audit_monitor_prop = false
	station.build()
	station.set_phase(1)
	trial = Trials.new()
	var movement: Dictionary = movement_constants()
	check(is_equal_approx(Trials.RELAY_WALK_SPEED, movement.PLAYER_WALK_SPEED), "budget walk speed matches upstream")
	check(is_equal_approx(Trials.RELAY_STAMINA_MAX, movement.STAMINA_MAX), "budget stamina capacity matches upstream")
	check(is_equal_approx(Trials.RELAY_STAMINA_REGEN_RATE, movement.STAMINA_REGEN_RATE), "budget stamina regeneration matches upstream")
	check(is_equal_approx(Trials.RELAY_STAMINA_REGEN_DELAY, movement.STAMINA_REGEN_DELAY), "budget recovery delay matches upstream")
	for stage in range(1, 6):
		verify_layout(stage)
		await verify_physical_clearance()
	station.set_stage(1)
	verify_state()
	verify_orders()
	trial.clear()
	station.free()
	await process_frame
	print("RELAY_POWER_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
