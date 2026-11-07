extends SceneTree
# 常驻整格设施：原始地板、静态碰撞、四连通绕障、阶段切换和回程箭头回归。

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func verify_connected(station: Node3D, phase: int) -> void:
	var visited := {station.AUDIT: true}
	var pending: Array[Vector2i] = [station.AUDIT]
	var cursor := 0
	while cursor < pending.size():
		var tile: Vector2i = pending[cursor]
		cursor += 1
		for direction in station.DIRECTIONS:
			var neighbor: Vector2i = tile + direction
			if station.walkable(phase, neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	var count := 0
	for y in range(station.MAP_SIZE.y):
		for x in range(station.MAP_SIZE.x):
			var tile := Vector2i(x, y)
			var can_walk: bool = station.walkable(phase, tile)
			check(station.grids[phase].is_point_solid(tile) != can_walk, "grid/walkable agree p%d %s" % [phase, tile])
			if can_walk:
				count += 1
				check(visited.has(tile), "all remaining floor connected p%d %s" % [phase, tile])
	check(count == visited.size(), "one connected component p%d S%d" % [phase, station.map_stage])

func verify_route(station: Node3D, phase: int, origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = station.path(phase, origin, target)
	check(not route.is_empty(), "route p%d %s -> %s" % [phase, origin, target])
	if route.is_empty():
		return route
	check(route.front() == origin and route.back() == target, "route endpoints")
	for index in range(route.size()):
		check(station.walkable(phase, route[index]), "route avoids blocked tiles")
		if index > 0:
			var step: Vector2i = route[index] - route[index - 1]
			check(absi(step.x) + absi(step.y) == 1, "hunter uses four-connected steps")
	return route

func nearby_obstacles(station: Node3D, phase: int, route: Array[Vector2i]) -> int:
	var count := 0
	for tile in station.permanent[phase]:
		for step in route:
			if absi(tile.x - step.x) + absi(tile.y - step.y) <= 2:
				count += 1
				break
	return count

func obstacle_ray(station: Node3D, phase: int, origin: Vector3, target: Vector3) -> Dictionary:
	var exclude: Array[RID] = []
	for other_phase in range(2):
		if other_phase == phase:
			continue
		for node in station.maps[other_phase].find_children("*", "StaticBody3D", true, false):
			exclude.append(node.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1, exclude)
	return root.world_3d.direct_space_state.intersect_ray(query)

func run() -> void:
	var station: Node3D = load("res://station.gd").new()
	root.add_child(station)
	station.build()
	await physics_frame
	await physics_frame
	var keys: Array = [station.AUDIT, station.OFFICE, station.LAB, station.RELAY, station.MEDICAL, station.LEDGER, station.GUARD] + station.GATES
	var original_ids: Array[Dictionary] = [{}, {}]
	for phase in range(2):
		station.set_phase(phase)
		await physics_frame
		await physics_frame
		var total: int = station.permanent[phase].size()
		check(total >= 25 and total <= 45, "25-45 substantial obstacle groups p%d" % phase)
		check(total == station.permanent_nodes[phase].size(), "every occupied tile has a node")
		var nearest := INF
		for tile in station.permanent[phase]:
			nearest = minf(nearest, station.point(tile).distance_to(station.point(station.AUDIT)))
			var obstacle: Node3D = station.permanent_nodes[phase][tile]
			original_ids[phase][tile] = obstacle.get_instance_id()
			check(obstacle.name == "Obstacle_%s_%d_%d" % [station.permanent[phase][tile], tile.x, tile.y], "stable obstacle name")
			check(obstacle.position == station.point(tile), "obstacle centered in tile")
			check(station.base_walkable(phase, tile), "obstacle has original floor")
			check(not station.walkable(phase, tile), "obstacle blocks walkable")
			check(station.grids[phase].is_point_solid(tile), "obstacle blocks AStar")
			check(station.path(phase, station.AUDIT, tile).is_empty(), "path cannot target obstacle")
			check(tile not in station.RETURN_MARKERS, "preserve return marker tile")
			for key in keys:
				check(maxi(absi(tile.x - key.x), absi(tile.y - key.y)) >= 2, "key and all gate one-tile clearance")
			for entry in station.breaks_for(phase):
				check(tile not in entry.tiles, "permanent disjoint from story breaks")
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					check(station.base_walkable(phase, tile + Vector2i(dx, dz)), "island placed on wide floor")
			var body: StaticBody3D = obstacle.get_node("ObstacleBody")
			var shape: CollisionShape3D = body.get_node("Footprint")
			var bounds: BoxShape3D = shape.shape
			check(body.collision_layer == 1 and not shape.disabled, "static collision enabled")
			check(bounds.size.x >= 3.5 and bounds.size.x <= 3.8 and bounds.size.z >= 3.5 and bounds.size.z <= 3.8, "whole tile collision footprint without neighbor spill")
			check(bounds.size.y >= 1.5 and bounds.size.y <= 2.4, "substantial cover height")
			for mesh in obstacle.find_children("*", "MeshInstance3D", true, false):
				var aabb: AABB = mesh.transform * mesh.get_aabb()
				check(aabb.position.x >= -1.81 and aabb.end.x <= 1.81 and aabb.position.z >= -1.81 and aabb.end.z <= 1.81, "visual stays inside footprint")
			var center: Vector3 = station.point(tile)
			var floor_hit := obstacle_ray(station, phase, center + Vector3(1.84, 0.40, 0), center + Vector3(1.84, -0.50, 0))
			check(not floor_hit.is_empty() and absf(floor_hit.position.y) < 0.02, "real floor collision retained under occupied tile")
			for direction in station.DIRECTIONS:
				var outward := Vector3(direction.x, 0, direction.y)
				var hit := obstacle_ray(station, phase, center + outward * 2.5 + Vector3.UP * 1.2, center + Vector3.UP * 1.2)
				check(not hit.is_empty() and hit.get("collider") == body, "four sides physically block capsule height")
				var start: Vector2i = tile + direction
				var target: Vector2i = tile - direction
				var detour: Array[Vector2i] = verify_route(station, phase, start, target)
				check(detour.size() >= 5 and tile not in detour, "route bends around obstacle")
				var capsule := CapsuleShape3D.new()
				capsule.radius = 0.30
				capsule.height = 1.8
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, center + outward * 2.5 + Vector3.UP * 0.93)
				query.motion = -outward * 2.5
				var motion: PackedFloat32Array = root.world_3d.direct_space_state.cast_motion(query)
				check(motion.size() == 2 and motion[0] < 0.5, "player capsule cannot cross obstacle")
		check(nearest <= 14.0, "opening has obstacle within 14m p%d" % phase)
		print("OBSTACLES p%d: %d groups; nearest A01 %.2fm" % [phase, total, nearest])
		for target in [station.OFFICE, station.GATES[0], station.GATES[1], station.LAB, station.RELAY]:
			var route: Array[Vector2i] = verify_route(station, phase, station.AUDIT, target)
			var nearby := nearby_obstacles(station, phase, route)
			check(nearby >= 1, "common route sees obstacles within two tiles")
			print("COVERAGE p%d A01 -> %s: %d nearby groups" % [phase, target, nearby])
	for stage in [1, 2, 3, 4, 5, 1, 4, 2, 1]:
		station.set_stage(stage)
		for phase in range(2):
			verify_connected(station, phase)
			for tile in station.permanent[phase]:
				var obstacle: Node3D = station.permanent_nodes[phase][tile]
				check(obstacle.get_instance_id() == original_ids[phase][tile] and obstacle.visible, "stage preserves permanent node")
				check(obstacle.get_node("ObstacleBody").collision_layer == 1, "stage preserves permanent collision")
				check(not station.walkable(phase, tile) and station.grids[phase].is_point_solid(tile), "stage preserves permanent occupation")
			for target in keys:
				verify_route(station, phase, station.AUDIT, target)
			for tile in station.RETURN_MARKERS:
				var hint: Dictionary = station.return_hint(phase, tile)
				check(not hint.is_empty(), "every original return marker retained")
				if not hint.is_empty():
					check(station.walkable(phase, tile + hint.direction), "return arrow avoids obstacle")
		verify_route(station, 1, station.OFFICE, station.GATES[1])
		verify_route(station, 0, station.GATES[1], station.AUDIT)
	station.free()
	await process_frame
	print("MAP_OBSTACLE_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
