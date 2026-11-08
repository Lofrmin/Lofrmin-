extends SceneTree

# 阶段 A：柱边卡死复现 + 诊断
# 在多个柱边/内转角/起邉 overlap 场景下，驱动正式 update_boss，记录 boss_motion_fraction 命中详情
var failures: Array[String] = []
var checks := 0
var game: Node3D


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)


func _initialize() -> void:
	call_deferred("run")


# 诊断：返回 boss_motion_fraction 起点 intersect_shape 命中的碰撞体路径列表
func diagnose_origin_overlap(origin: Vector3) -> Array:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = game.boss_body
	query.transform = Transform3D(Basis(), origin + Vector3.UP * 0.86)
	query.margin = 0.005
	query.exclude = [game.player.get_rid()]
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var hits: Array = space.intersect_shape(query, 8)
	var names: Array = []
	for h in hits:
		var col = h.get("collider")
		if col:
			names.append(str(col.get_path()))
	return names


# 场景 A：boss 紧贴立柱，给一个视线可达的玩家位置
func scenario_pillar(tile: Vector2i, offset: Vector3, player_offset: Vector3, label: String) -> Dictionary:
	game.phase = 1
	game.station.set_phase(1)
	game.chapter = 0
	game.mode = "world"
	game.boss_live = true
	game.boss_phase = 1
	game.boss_delay = 0.0
	game.stunned = 0.0
	game.charge_warning = 0.0
	game.charge_time = 0.0
	game.charge_recovery = 0.0
	game.tracking_time = 0.0
	game.tactic = "pursue"
	game.dusk_grace = 0.0
	game.boss_route.clear()
	game.path_timer = 0.0

	game.player.position = game.station.point(tile) + player_offset + Vector3.UP * 0.05
	game.boss.position = game.station.point(tile) + offset
	game.last_known = tile

	var start_pos: Vector3 = game.boss.position
	var overlaps: Array = diagnose_origin_overlap(start_pos)
	var fraction: float = game.boss_motion_fraction(start_pos, start_pos + Vector3(0.1, 0, 0))

	# 驱动 60 帧 update_boss（约 1 秒）
	var positions: Array[Vector3] = [start_pos]
	for i in range(60):
		game.update_boss(1.0 / 60.0, false)
		positions.append(game.boss.position)

	var moved: float = start_pos.distance_to(game.boss.position)
	var result := {
		"label": label,
		"start": start_pos,
		"end": game.boss.position,
		"moved": moved,
		"overlap_count": overlaps.size(),
		"overlap_paths": overlaps,
		"initial_fraction": fraction,
		"route_size": game.boss_route.size(),
		"seen": game.has_sight(),
	}
	print("SCENARIO %s: moved=%.3f overlaps=%d fraction=%.3f route=%d" % [label, moved, overlaps.size(), fraction, game.boss_route.size()])
	if overlaps.size() > 0:
		print("  overlap_paths: ", overlaps)
	return result


func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await process_frame
	await process_frame

	# 找一个立柱附近的 tile：立柱在 tile 边缘 ±1.87，所以 tile 中心就是走廊
	# 选 R-03 附近：它有左右机架柱
	# 用一个开阔 tile（晨/暮都可走）
	var test_tile := Vector2i(20, 26)  # L-06

	# 场景 1：boss 在 tile 中心（正常情况）
	var r1 := scenario_pillar(test_tile, Vector3.ZERO, Vector3(2, 0, 2), "center")

	# 场景 2：boss 紧贴 tile 边缘（柱边）
	var r2 := scenario_pillar(test_tile, Vector3(1.87, 0, 0), Vector3(3, 0, 2), "pillar-edge")

	# 场景 3：boss 嵌入柱子（重叠）
	var r3 := scenario_pillar(test_tile, Vector3(1.87, 0, 0.0), Vector3(3, 0, 2), "pillar-overlap")

	# 场景 4：内转角
	var r4 := scenario_pillar(test_tile, Vector3(1.85, 0, 1.85), Vector3(3, 0, 3), "inner-corner")
	var center: Vector3 = game.station.point(Vector2i(20, 19))
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12, 3.0, 3.0)
	collider.shape = shape
	wall.add_child(collider)
	root.add_child(wall)
	wall.position = center + Vector3.UP * 1.5
	await physics_frame
	var embedded := center - Vector3(0.18, 0.0, 0.0)
	var recovered: Vector3 = game.try_boss_overlap_recovery(embedded)
	var safe_exit: bool = recovered.x < embedded.x and recovered.distance_to(embedded) <= 0.721 and game.boss_motion_fraction(recovered, recovered) == 1.0
	var passed: bool = r4.overlap_count > 0 and r4.moved > 0.75 and safe_exit
	print("OVERLAP_EXIT_SAME_SIDE: ", safe_exit)

	print("REPRO_SUMMARY: %d scenarios run" % 4)
	quit(0 if passed else 1)
