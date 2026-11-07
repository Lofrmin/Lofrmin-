extends SceneTree
# v6 断点回归：每个阶段 断点格不可走、A* 不经过、碰撞开关一致、关键点互通、回程箭头不指墙

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var station: Node3D = load("res://station.gd").new()
	root.add_child(station)
	station.build()
	var keys: Array = [station.AUDIT, station.OFFICE, station.LAB, station.RELAY, station.MEDICAL, station.LEDGER, station.GUARD] + station.GATES
	for stage in range(1, 6):
		station.set_stage(stage)
		for phase in range(2):
			for key in keys:
				check(station.walkable(phase, key), "S%d p%d key %s walkable" % [stage, phase, key])
				var route: Array[Vector2i] = station.path(phase, station.AUDIT, key)
				check(key == station.AUDIT or route.size() >= 2, "S%d p%d A01 -> %s reachable" % [stage, phase, key])
				for tile in route:
					check(station.walkable(phase, tile), "S%d p%d route avoids breaks" % [stage, phase])
			var entries: Array = station.breaks_for(phase)
			for index in range(entries.size()):
				var active: bool = stage >= int(entries[index].stage)
				for tile in entries[index].tiles:
					check(station.walkable(phase, tile) != active, "S%d p%d break %s walkable state" % [stage, phase, entries[index].name])
					check(station.grids[phase].is_point_solid(tile) == active, "S%d p%d break %s solid state" % [stage, phase, entries[index].name])
					for key in keys:
						check(absi(tile.x - key.x) + absi(tile.y - key.y) >= 4, "break away from key point")
				for block in station.barriers[phase][index]:
					check(block.visible == active, "barrier visible matches stage")
					for body in block.find_children("*", "StaticBody3D", true, false):
						check((body.collision_layer != 0) == active, "barrier collision matches stage")
			for tile in station.RETURN_MARKERS:
				if not station.walkable(phase, tile): continue
				var hint: Dictionary = station.return_hint(phase, tile)
				check(not hint.is_empty(), "S%d marker hint" % stage)
				if hint.is_empty(): continue
				check(station.walkable(phase, tile + hint.direction), "S%d arrow not into wall" % stage)
		check(station.return_signs.size() > 8, "S%d guide signs rebuilt" % stage)
	var order := [0, 3, 1, 4, 2]
	for step in range(order.size()):
		station.update_witness(order[step], false, false)
		check(station.map_stage == step + 1, "story chapter %d -> stage S%d" % [step + 1, step + 1])
	station.free()
	await process_frame
	print("MAP_BREAKS_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
