extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func verify_route(station: Node3D, phase: int, origin: Vector2i, target: Vector2i) -> void:
	var route: Array[Vector2i] = station.path(phase, origin, target)
	check(not route.is_empty(), "route exists %d %s -> %s" % [phase, origin, target])
	if route.is_empty(): return
	check(route[0] == origin and route[-1] == target, "route endpoints")
	for i in range(route.size()):
		check(station.walkable(phase, route[i]), "route tile walkable")
		if i > 0:
			var step: Vector2i = route[i] - route[i - 1]
			check(absi(step.x) + absi(step.y) == 1, "route steps do not cross walls")

func run() -> void:
	var station: Node3D = load("res://station.gd").new()
	root.add_child(station)
	station.build()
	for layer in station.maps:
		var monitor: Node3D = layer.get_node_or_null("A01_Monitor")
		check(monitor != null, "both phases include imported monitor")
		if monitor == null: continue
		for mesh in monitor.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			check(absf(bounds.position.y - 1.02) < 0.005, "monitor base rests on tabletop")
		var status: Label3D = layer.get_node("AuditStatus")
		check(status.position.y < 0.90, "audit status remains visible on desk front")
	for phase in range(2):
		for target in [station.OFFICE,station.LAB,station.RELAY,station.MEDICAL,station.LEDGER,station.GATES[0],station.GATES[1]]:
			verify_route(station, phase, station.AUDIT, target)
	verify_route(station, 1, station.OFFICE, station.GATES[1])
	verify_route(station, 0, station.GATES[1], station.AUDIT)
	check(station.has_method("return_hint"), "visible return guide required")
	if station.has_method("return_hint"):
		for phase in range(2):
			for tile in station.RETURN_MARKERS:
				var hint: Dictionary = station.return_hint(phase, tile)
				if not station.walkable(phase, tile): continue
				check(not hint.is_empty(), "marker has a valid next step")
				if hint.is_empty(): continue
				check(station.walkable(phase, tile + hint.direction), "arrow never points into wall")
				var route: Array[Vector2i] = station.path(phase, tile, hint.target)
				check(route.size() >= 2 and route[1] - tile == hint.direction, "arrow follows actual path")
		check(station.return_hint(1, station.OFFICE).label.contains("G-02"), "office returns through east gate")
		check(station.return_signs.size() > 8, "both phases render guide signs")
	station.free()
	await process_frame
	print("MAP_ROUTES_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
