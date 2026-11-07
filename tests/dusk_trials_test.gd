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

func position_at(index: int) -> Vector3:
	return trial.sites[index].position + Vector3.UP * 0.05

func approach(index: int) -> Vector3:
	# Stay beside the solid base, like a real player pressing E.
	return position_at(index) + Vector3.LEFT * 0.95

func walk_segment(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	var steps := maxi(1, ceili(distance / 0.40))
	for step in range(1, steps + 1):
		trial.update(0.1, from.lerp(to, float(step) / steps), false)

func walk_route(from: Vector2i, to: Vector2i) -> void:
	var route: Array = station.path(1, from, to)
	check(not route.is_empty(), "walk route exists")
	for index in range(1, route.size()):
		walk_segment(station.point(route[index - 1]) + Vector3.UP * 0.05, station.point(route[index]) + Vector3.UP * 0.05)

func forbidden_tiles() -> Array:
	var tiles: Array = [station.AUDIT, station.OFFICE, station.RELAY, station.LAB, station.MEDICAL, station.LEDGER, station.GUARD] + station.GATES + station.RETURN_MARKERS
	for entry in station.breaks_for(1):
		tiles.append_array(entry.tiles)
	return tiles

func verify_layout(task: String, stage: int) -> void:
	check(trial.begin(task, station), "begin %s stage%d" % [task, stage])
	check(not trial.is_complete() and trial.active, "start locked")
	var keys: Array = [station.AUDIT, station.OFFICE, station.RELAY, station.LAB, station.MEDICAL, station.LEDGER] + station.GATES
	for site in trial.sites:
		check(station.walkable(1, site.tile), "site has walkable floor")
		check(site.tile not in forbidden_tiles(), "site avoids critical, return and future break cells")
		check(not station.path(1, trial.anchor, site.tile).is_empty(), "site reachable from terminal")
		check(not station.path(1, site.tile, trial.anchor).is_empty(), "terminal remains reachable from site")
		for key in keys:
			check(not station.path(1, site.tile, key).is_empty(), "site can leave to every key")
	check(not trial.interact(station.point(trial.anchor)), "terminal cannot operate remote entities")
	check(not trial.interact(approach(0), 0), "morning interaction blocked")
	check(not trial.interact(approach(0) + Vector3.UP * 4), "cannot interact from another height")
	var node_id: int = trial.visual_root.get_instance_id()
	trial.begin(task, station)
	check(node_id == trial.visual_root.get_instance_id(), "reenter terminal preserves active layout")
	if task == "clock":
		var detour: Array = station.path(1, trial.sites[0].tile, trial.sites[1].tile)
		check(detour.size() >= 5, "switches demand a real detour")
		check(trial.time_limit >= float(detour.size() - 1) * station.CELL / 4.45 + 3.9, "timer allows walking with interaction margin")
		var middle: Vector2i = (trial.sites[0].tile + trial.sites[1].tile) / 2
		check(station.permanent[1].has(middle), "existing cover separates switches")
	print("DUSK_LAYOUT stage=%d task=%s sites=%s time=%.1f" % [stage, task, trial.sites, trial.time_limit])
	trial.clear()

func verify_silent() -> void:
	trial.begin("silent", station)
	var origin: Vector3 = position_at(0)
	check(trial.interact(origin), "start sensor handles E")
	check(trial.progress == 1 and not trial.is_complete(), "starting alone grants nothing")
	trial.update(20.0, origin, false)
	check(trial.progress == 1 and not trial.is_complete(), "waiting and holding still cannot finish")
	trial.update(0.1, origin + Vector3.RIGHT * 0.2, true)
	check(trial.progress == 0 and not trial.armed, "sprinting resets quiet route")
	trial.interact(origin)
	trial.update(0.1, position_at(1), false)
	check(trial.progress == 0, "teleport cannot skip quiet traversal")
	trial.interact(origin)
	var remote: Vector3 = station.point(station.AUDIT) + Vector3.UP * 0.05
	trial.update(0.0, remote, false)
	check(trial.active and not trial.completed, "leaving terminal does not cancel trial")
	trial.interact(origin)
	walk_route(trial.sites[0].tile, trial.sites[1].tile)
	check(trial.progress == 2, "walking through second spatial sensor advances")
	walk_route(trial.sites[1].tile, trial.sites[2].tile)
	check(trial.is_complete("silent"), "three spatial sensors finish quiet route")
	check(not trial.is_complete("clock"), "completion is task scoped")
	check(not trial.update(0.1, position_at(2), false), "completion notification is not repeated")
	check(not trial.interact(station.point(trial.anchor)), "completed trial releases terminal interaction")
	check(trial.objective().tile == trial.anchor, "completed objective points back to terminal")
	check("返回" in trial.guidance(), "completion tells player to return for evidence")
	trial.clear()

func verify_clock() -> void:
	trial.begin("clock", station)
	check(trial.interact(approach(1)), "second switch handles premature E")
	check(trial.progress == 0 and not trial.completed, "second switch cannot open alone")
	trial.interact(approach(0))
	var limit: float = trial.remaining
	trial.update(limit + 0.1, approach(0), false)
	check(trial.progress == 0 and not trial.completed, "timeout resets without completion")
	trial.interact(approach(0))
	trial.begin("clock", station)
	check(trial.progress == 1, "terminal revisit preserves running clock attempt")
	trial.update(0.0, approach(0), false)
	walk_route(trial.sites[0].tile, trial.sites[1].tile)
	check(trial.remaining > 0, "actual walk detour fits time budget")
	check(trial.interact(approach(1)) and trial.is_complete("clock"), "second switch within budget completes")
	trial.clear()

func verify_relay() -> void:
	trial.begin("relay", station)
	check(not trial.interact(station.point(station.GATES[0])), "remote E cannot activate power post")
	trial.interact(approach(1))
	check(trial.progress == 0, "wrong first post resets")
	trial.interact(approach(0))
	trial.interact(approach(2))
	check(trial.progress == 0 and not trial.completed, "wrong next post resets all")
	trial.interact(approach(0))
	trial.update(1, approach(0), false, 0)
	check(trial.progress == 0 and not trial.completed, "phase exit resets unfinished operation")
	for body in trial._bodies:
		check(body.collision_layer == 0, "morning disables dusk-only base collision")
	trial.update(0.1, approach(0), false, 1)
	for body in trial._bodies:
		check(body.collision_layer == 1, "return to dusk restores base collision")
	for index in range(3):
		check(trial.interact(approach(index)), "post E consumed")
	check(trial.is_complete("relay"), "all three physical posts unlock relay")
	trial.update(1, approach(2), true, 0)
	check(trial.is_complete(), "finished prerequisite survives phase travel until clear")
	trial.clear()

func verify_collision() -> void:
	trial.begin("clock", station)
	await physics_frame
	await physics_frame
	for index in range(trial._bodies.size()):
		var body: StaticBody3D = trial._bodies[index]
		var shape: CollisionShape3D = body.get_child(0)
		check(shape.shape.size == trial.BASE_SIZE, "switch has a real small collision footprint")
		check(shape.shape.size.x < 0.7 and shape.shape.size.z < 0.7, "no large blocking collision")
		var exclude: Array[RID] = []
		for other in station.find_children("*", "StaticBody3D", true, false):
			if other != body:
				exclude.append(other.get_rid())
		var center: Vector3 = trial.sites[index].position + Vector3.UP * 0.5
		var query := PhysicsRayQueryParameters3D.create(center + Vector3.LEFT, center + Vector3.RIGHT, 1, exclude)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider == body, "base physically blocks penetration")
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.30
		capsule.height = 1.8
		var sweep := PhysicsShapeQueryParameters3D.new()
		sweep.shape = capsule
		sweep.exclude = exclude
		sweep.transform = Transform3D(Basis.IDENTITY, station.point(trial.sites[index].tile) + Vector3(-1.8, 0.95, 0))
		sweep.motion = Vector3(3.6, 0, 0)
		var motion := root.world_3d.direct_space_state.cast_motion(sweep)
		check(motion.size() == 2 and motion[0] == 1.0, "player capsule can traverse tile center beside switch")
	var bodies: Array = trial._bodies.duplicate()
	trial.clear()
	for body in bodies:
		check(body.collision_layer == 0, "clear immediately disables pending-free collision")
	check(not trial.active and not trial.is_complete() and trial.sites.is_empty(), "clear discards all task state")
	await process_frame

func run() -> void:
	station = load("res://station.gd").new()
	root.add_child(station)
	station.use_audit_monitor_prop = false
	station.build()
	station.set_phase(1)
	trial = Trials.new()
	check(not trial.begin("silent", station, 0), "no morning trial")
	check(not trial.begin("unsupported", station), "unknown task cannot unlock")
	for stage in range(1, 6):
		station.set_stage(stage)
		for task in ["silent", "clock", "relay"]:
			verify_layout(task, stage)
	station.set_stage(1)
	verify_silent()
	verify_clock()
	verify_relay()
	await verify_collision()
	station.free()
	await process_frame
	print("DUSK_TRIALS_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
