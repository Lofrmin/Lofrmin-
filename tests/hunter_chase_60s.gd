extends SceneTree

# 阶段 A 验收 4：60 秒连续追逐 + 三场景覆盖
# 场景：轻微起点重叠 / 柱边内转角受阻 / 缓存路线不再可走
# 断言：可达且应该移动的条件下不能无限站定
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


# 让 boss 处于追踪状态、玩家在远处（牵引 boss 持续移动）
func setup_chase(tile: Vector2i, boss_offset: Vector3, player_offset: Vector3) -> void:
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
	game.charge_recovery = 99.0  # 禁用冲刺，专测持续追踪
	game.tracking_time = 0.0
	game.tactic = "pursue"
	game.dusk_grace = 0.0
	game.boss_route.clear()
	game.path_timer = 0.0
	game.boss_stall_time = 0.0
	game.dev_god = true  # 避免抓取 reset_lap 干扰
	game.player.position = game.station.point(tile) + player_offset + Vector3.UP * 0.05
	game.boss.position = game.station.point(tile) + boss_offset
	game.last_known = tile


# 模拟玩家持续移动：每 0.5s 移动到下一个 tile（牵引 boss 一直追）
func simulate_chase(duration: float, label: String) -> Dictionary:
	var ticks := int(duration * 60.0)
	# 逃跑玩家沿真实 A* 路径连续移动（不传送），保持 boss 视线/追踪语义成立
	# 环形路线：L-06 → RELAY → G-04 → L-06 往返，全部暮区可达
	var loop_tiles: Array[Vector2i] = [Vector2i(20, 26), Vector2i(20, 31), Vector2i(29, 36)]
	for tile in loop_tiles:
		assert(game.station.walkable(1, tile), "loop tile must be dusk-walkable: " + str(tile))
	# 展平航点队列：直接拼接正反两段路径（跳过段首避免重复）
	var waypoints: Array[Vector2i] = []
	for a in range(loop_tiles.size()):
		var b := (a + 1) % loop_tiles.size()
		var route: Array[Vector2i] = game.station.path(1, loop_tiles[a], loop_tiles[b])
		assert(not route.is_empty(), "loop segment must be walkable")
		for j in range(1, route.size()):
			waypoints.append(route[j])
		var back: Array[Vector2i] = game.station.path(1, loop_tiles[b], loop_tiles[a])
		assert(not back.is_empty(), "loop return must be walkable")
		for j in range(1, back.size()):
			waypoints.append(back[j])
	assert(waypoints.size() > 4, "chase loop needs waypoints")
	var wp_index := 0
	var wp_target: Vector3 = game.station.point(waypoints[0]) + Vector3.UP * 0.05
	var player_speed := 5.0  # 快于 boss 普通追踪 3.27/3.77，确保 boss 永远追不上、必须持续移动
	game.player.position = game.station.point(loop_tiles[0]) + Vector3.UP * 0.05
	var stall_events := 0
	var max_stall := 0.0
	var last_pos: Vector3 = game.boss.position
	var no_progress_time := 0.0
	var total_distance := 0.0
	var position_samples: Array = []
	var dt := 1.0 / 60.0
	for i in range(ticks):
		# 玩家连续跑向当前航点，到达即换下一个（模拟真实逃跑，不是传送）
		var to_wp: Vector3 = wp_target - game.player.position
		to_wp.y = 0.0
		if to_wp.length() < 0.25:
			wp_index = (wp_index + 1) % waypoints.size()
			wp_target = game.station.point(waypoints[wp_index]) + Vector3.UP * 0.05
		else:
			game.player.position += to_wp.normalized() * player_speed * dt
		game.update_boss(dt, false)
		var new_pos: Vector3 = game.boss.position
		var step := new_pos.distance_to(last_pos)
		total_distance += step
		# 只在 boss 距离玩家 > 2.0m（攻击距离外）时，才把不动算作 stall
		var dist_to_player := new_pos.distance_to(game.player.position)
		if step < 0.0005 and dist_to_player > 2.0:
			no_progress_time += dt
			if absf(no_progress_time - 1.0) < dt * 0.5:
				stall_events += 1
			max_stall = maxf(max_stall, no_progress_time)
		else:
			no_progress_time = 0.0
		last_pos = new_pos
		if i % 60 == 0:
			position_samples.append({"t": i / 60.0, "pos": new_pos, "stall": no_progress_time, "dist": dist_to_player})
	return {
		"label": label,
		"total_distance": total_distance,
		"stall_events": stall_events,
		"max_stall": max_stall,
		"samples": position_samples,
	}


func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await process_frame
	await process_frame

	# 场景 1：轻微起点重叠（boss 嵌入柱边 0.05m）
	setup_chase(Vector2i(20, 26), Vector3(1.85, 0, 1.85), Vector3(2, 0, 2))
	var r1 := simulate_chase(60.0, "overlap-recovery")
	print("CHASE overlap-recovery: dist=%.1f stalls=%d max_stall=%.2fs" % [r1.total_distance, r1.stall_events, r1.max_stall])
	check(r1.total_distance > 30.0, "overlap-recovery: boss moves > 30m over 60s")
	check(r1.max_stall < 3.0, "overlap-recovery: no stall > 3s")

	# 场景 2：柱边/内转角受阻
	setup_chase(Vector2i(20, 26), Vector3(1.87, 0, 0.0), Vector3(3, 0, 2))
	var r2 := simulate_chase(60.0, "pillar-corner")
	print("CHASE pillar-corner: dist=%.1f stalls=%d max_stall=%.2fs" % [r2.total_distance, r2.stall_events, r2.max_stall])
	check(r2.total_distance > 30.0, "pillar-corner: boss moves > 30m over 60s")
	check(r2.max_stall < 3.0, "pillar-corner: no stall > 3s")

	# 场景 3：缓存路线不再可走（章节切换触发断点封闭）
	setup_chase(Vector2i(20, 26), Vector3(0, 0, 0), Vector3(2, 0, 2))
	# 让 boss 走出一段，然后封闭当前路径
	for i in range(30):
		game.update_boss(1.0/60.0, false)
	# 模拟断点封闭：把 boss 当前目标 tile 设为不可走
	var boss_tile: Vector2i = game.station.cell(game.boss.position)
	var next_tile := boss_tile + Vector2i(1, 0)
	if game.station.walkable(1, next_tile):
		game.station.closed[1][next_tile] = true
		game.station.grids[1].set_point_solid(next_tile)
	var r3 := simulate_chase(60.0, "stale-route")
	print("CHASE stale-route: dist=%.1f stalls=%d max_stall=%.2fs" % [r3.total_distance, r3.stall_events, r3.max_stall])
	check(r3.total_distance > 30.0, "stale-route: boss moves > 30m over 60s")
	check(r3.max_stall < 3.0, "stale-route: no stall > 3s")

	print("CHASE_60S: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
