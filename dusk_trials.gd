extends RefCounted
# Spatial prerequisites only. The caller awards evidence at the original terminal
# AFTER is_complete(kind), never on update()'s completion notification.
# begin is idempotent for the same map/task; leaving the terminal does not cancel.
# Only update from world physics (pause must freeze timers). Clear on lap/chapter reset.

const INTERACT_RADIUS := 1.65
const SCAN_RADIUS := 0.88
const WALK_LIMIT := 5.15
const BASE_SIZE := Vector3(0.58, 0.94, 0.58)
const SITE_OFFSET := Vector3(0.90, 0, 0.90)
const KINDS := ["silent", "clock", "relay"]
# Mirrored from game.gd; relay_power_test verifies these stay in sync.
# Avoid loading game.gd here: it preloads this script and every scene asset.
const RELAY_WALK_SPEED := 4.45
const RELAY_STAMINA_MAX := 100.0
const RELAY_STAMINA_REGEN_RATE := 100.0 / 6.0
const RELAY_STAMINA_REGEN_DELAY := 1.25

var active := false
var completed := false
var kind := ""
var anchor := Vector2i.ZERO
var sites: Array[Dictionary] = []
var progress := 0
var remaining := 0.0
var time_limit := 0.0
# Zero-based site indices. The world consumes and clears this queue after E.
var relay_activation_events: Array[int] = []
var relay_timers: Array[float] = []
var message := ""
var station: Node3D
var visual_root: Node3D
var route_root: Node3D
var armed := false
var _phase := 1
var _last_position := Vector3.ZERO
var _has_position := false
var _walked := 0.0
var _last_tile := Vector2i(-999, -999)
var _last_target := -999
var _lamps: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _lights: Array[OmniLight3D] = []
var _bodies: Array[StaticBody3D] = []
var _terminal_label: Label3D
var _safe: Dictionary = {}


func begin(task: String, map: Node3D, phase: int = 1) -> bool:
	if phase != 1 or task not in KINDS or not is_instance_valid(map) or map.maps.size() < 2:
		return false
	if active and kind == task and station == map:
		return true
	clear()
	station = map
	kind = task
	anchor = {"silent": station.OFFICE, "clock": station.LAB, "relay": station.RELAY}[task]
	_collect_safe_tiles()
	var tiles: Array[Vector2i] = []
	if kind == "clock":
		tiles = _switch_pair()
	elif kind == "relay":
		tiles = _relay_sites()
	else:
		for offset in [Vector2i(0, 1), Vector2i(2, 2), Vector2i(-1, 3)]:
			var tile := _pick_tile(anchor + offset, tiles)
			if tile == Vector2i(-1, -1):
				clear()
				message = "附近没有安全场地，未解锁终端。"
				return false
			tiles.append(tile)
	if tiles.size() != (2 if kind == "clock" else 3):
		var reason := "地图中没有三处安全供电场地，未解锁终端。" if kind == "relay" else "双开关附近没有安全绕行路线，未解锁终端。"
		clear()
		message = reason
		return false
	for index in range(tiles.size()):
		var pos: Vector3 = station.point(tiles[index])
		if kind != "silent":
			pos += SITE_OFFSET
		sites.append({"tile": tiles[index], "position": pos, "index": index})
	if kind == "clock":
		var detour: Array = station.path(1, tiles[0], tiles[1])
		# Comfortable at the game's 6.25 m/s sprint, including corners and E presses.
		time_limit = maxf(9.0, float(detour.size() - 1) * station.CELL / 4.45 + 4.0)
	elif kind == "relay":
		relay_timers.assign([0.0, 0.0, 0.0])
		_budget_relay_lifetime()
	active = true
	_phase = 1
	_build_visuals()
	message = instructions()
	_refresh()
	return true


func update(delta: float, player_position: Vector3, sprinting: bool, phase: int = 1) -> bool:
	if not active or not is_instance_valid(station):
		return false
	var changed_phase := phase != _phase
	_phase = phase
	_set_enabled(phase == 1)
	if phase != 1:
		if not completed and (kind == "relay" or armed or progress > 0):
			_reset_attempt("已离开暮区；返回后可重新开始。")
		_has_position = false
		return false
	var was_complete := completed
	var elapsed := maxf(delta, 0.0)
	if not completed and elapsed > 0.0:
		if kind == "relay":
			var expired := false
			for index in range(relay_timers.size()):
				var was_lit := relay_timers[index] > 0.0
				relay_timers[index] = maxf(0.0, relay_timers[index] - elapsed)
				expired = expired or (was_lit and relay_timers[index] <= 0.0)
			_sync_relay_progress()
			if expired:
				message = "有电源柱熄灭；可重新启动。让三柱同时供电。"
		elif kind == "clock" and progress == 1:
			remaining = maxf(0.0, remaining - elapsed)
			if remaining <= 0.0:
				_reset_attempt("同步窗口超时。回到开关 1 重试；通道保持开放。")
		elif kind == "silent" and armed:
			var distance := _flat_distance(player_position, _last_position) if _has_position else 0.0
			if sprinting or distance > WALK_LIMIT * elapsed + 0.12:
				_reset_attempt("声控检测到奔跑。回到起点按 E，重新静步通过。")
			elif _has_position and _on_floor(player_position):
				_walked += distance
				if progress < sites.size() and _near(player_position, sites[progress].position, SCAN_RADIUS) and _walked >= 2.0:
					progress += 1
					_walked = 0.0
					if progress == sites.size():
						_complete()
					else:
						message = "静步检查点 %d / 3；继续沿地面箭头行走。" % progress
	_last_position = player_position
	_has_position = true
	var tile: Vector2i = station.cell(player_position)
	if tile != _last_tile or _target_index() != _last_target or changed_phase:
		_draw_route(tile)
	_refresh()
	return completed and not was_complete


# True means E was handled by a world entity, NOT that the task succeeded.
func interact(player_position: Vector3, phase: int = 1) -> bool:
	if not active or completed or phase != 1 or not _on_floor(player_position):
		return false
	var index := _nearest_site(player_position)
	if index < 0:
		return false
	if kind == "silent":
		if index == 0:
			armed = true
			progress = 1
			_walked = 0.0
			_last_position = player_position
			_has_position = true
			message = "声控通行已开始：步行穿过 2、3 号感应线；奔跑会重置。"
		else:
			message = "步行穿过感应线；先在 1 号起点按 E 启动。" if not armed else "无需按键，步行穿过下一道感应线。"
	elif kind == "clock":
		if index == 0:
			progress = 1
			remaining = time_limit
			message = "开关 1 已合上：%.0f 秒内绕过设备，到开关 2 按 E。" % time_limit
		elif progress == 1 and remaining > 0.0:
			progress = 2
			_complete()
		else:
			message = "先到开关 1 合闸，再沿箭头绕到此处。"
	else:
		if relay_timers[index] <= 0.0:
			relay_timers[index] = time_limit
			relay_activation_events.append(index)
			_sync_relay_progress()
			if progress == sites.size():
				_complete()
			else:
				message = "电源柱 %d 已供电；三柱须同时亮起。每柱供电 %.0f 秒，小地图可查看位置。" % [index + 1, time_limit]
		else:
			message = "此柱正在供电，剩余 %.1f 秒；重复按键不会延长。" % relay_timers[index]
	_last_target = -999
	_refresh()
	return true


func is_complete(task: String = "") -> bool:
	return active and completed and (task.is_empty() or kind == task)


func clear() -> void:
	# Disable immediately; deferred freeing is safe even when called during physics.
	_set_enabled(false)
	if is_instance_valid(visual_root):
		visual_root.queue_free()
	visual_root = null
	route_root = null
	_terminal_label = null
	station = null
	active = false
	completed = false
	armed = false
	kind = ""
	anchor = Vector2i.ZERO
	progress = 0
	remaining = 0.0
	time_limit = 0.0
	message = ""
	sites.clear()
	relay_timers.clear()
	relay_activation_events.clear()
	_lamps.clear()
	_labels.clear()
	_lights.clear()
	_bodies.clear()
	_safe.clear()
	_has_position = false
	_walked = 0.0
	_last_tile = Vector2i(-999, -999)
	_last_target = -999


func instructions() -> String:
	match kind:
		"silent": return "声控通行：到 1 号感应线按 E，步行通过 2、3 号线；奔跑重置。"
		"clock": return "双开关同步：开关 1 按 E，再限时绕过设备，到开关 2 按 E。"
		"relay": return "暗区供电：三柱位置见小地图，任意顺序按 E；每柱供电 %.0f 秒，须同时亮起。每次启动都会引来追债人。" % time_limit
	return ""


func prompt(position: Vector3, phase: int = 1) -> String:
	if not active or phase != 1:
		return ""
	if completed:
		return "[E] 返回终端取证" if _near(position, station.point(anchor), 1.82) else ""
	var index := _nearest_site(position)
	if index < 0 or not _on_floor(position):
		return ""
	if kind == "silent":
		return "[E] 开始 / 重试静步通行" if index == 0 else "步行穿过下一道感应线"
	if kind == "relay" and relay_timers[index] > 0.0:
		return "电源柱 %d · 剩余 %.1f 秒" % [index + 1, relay_timers[index]]
	return "[E] %s %d" % ["合上同步开关" if kind == "clock" else "重启电源柱", index + 1]


func guidance() -> String:
	if not active:
		return ""
	if completed:
		return "场地操作已通过 · 返回原终端按 E 取证"
	if kind == "clock" and progress == 1:
		return "绕过设备 → 开关 2 · 剩余 %.1f 秒" % remaining
	if kind == "relay":
		return "三柱同时供电 %d / 3 · 每柱 %.0f 秒 · 位置见小地图，顺序自选" % [progress, time_limit]
	return instructions()


func map_objectives() -> Array[Dictionary]:
	var objectives: Array[Dictionary] = []
	if not active or kind != "relay":
		return objectives
	for index in range(sites.size()):
		objectives.append({"tile": sites[index].tile, "position": sites[index].position,
			"label": "电源柱 %d" % (index + 1), "active": completed or relay_timers[index] > 0.0,
			"remaining": relay_timers[index]})
	return objectives


func objective() -> Dictionary:
	if not active or kind == "relay":
		return {}
	var index := _target_index()
	return {"task": kind, "tile": anchor if completed else sites[index].tile,
		"position": station.point(anchor) if completed else sites[index].position,
		"label": "返回终端取证" if completed else "%s %d" % ["感应线" if kind == "silent" else ("同步开关" if kind == "clock" else "电源柱"), index + 1],
		"complete": completed}


func _critical_tiles() -> Array:
	return [station.AUDIT, station.OFFICE, station.RELAY, station.LAB, station.MEDICAL, station.LEDGER, station.GUARD] + station.GATES + station.RETURN_MARKERS


func _collect_safe_tiles() -> void:
	var forbidden := {}
	for tile in _critical_tiles():
		forbidden[tile] = true
	for entry in station.breaks_for(1):
		for tile in entry.tiles:
			forbidden[tile] = true
	var y_start := 0 if kind == "relay" else anchor.y - 6
	var y_end: int = station.MAP_SIZE.y if kind == "relay" else anchor.y + 7
	var x_start := 0 if kind == "relay" else anchor.x - 6
	var x_end: int = station.MAP_SIZE.x if kind == "relay" else anchor.x + 7
	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			var tile := Vector2i(x, y)
			if forbidden.has(tile) or not station.walkable(1, tile):
				continue
			var neighbors := 0
			for direction in station.DIRECTIONS:
				if station.walkable(1, tile + direction):
					neighbors += 1
			var route: Array = station.path(1, anchor, tile)
			if neighbors >= (3 if kind == "relay" else 2) and route.size() >= 2 and (kind == "relay" or route.size() <= 10):
				_safe[tile] = true


func _pick_tile(preferred: Vector2i, used: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := INF
	for tile: Vector2i in _safe:
		var acceptable := true
		for other in used:
			var separation: Array = station.path(1, other, tile)
			if separation.size() < 3 or separation.size() > 8:
				acceptable = false
		if not acceptable:
			continue
		var score: float = tile.distance_squared_to(preferred)
		if score < best_score:
			best = tile
			best_score = score
	return best


func _switch_pair() -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_score := INF
	# Existing substantial obstacles supply the detour; this script adds no wall.
	for blocker: Vector2i in station.permanent[1]:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var first: Vector2i = blocker - direction
			var second: Vector2i = blocker + direction
			if not _safe.has(first) or not _safe.has(second):
				continue
			var detour: Array = station.path(1, first, second)
			if detour.size() < 5 or detour.size() > 10:
				continue
			var score: float = blocker.distance_squared_to(anchor) + float(detour.size())
			if score < best_score:
				best = [first, second]
				best_score = score
	return best


func _relay_distances(origin: Vector2i) -> Dictionary:
	# Same four-neighbor graph as station.path, including currently closed lasers.
	var distances := {origin: 0}
	var pending: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < pending.size():
		var at := pending[cursor]
		cursor += 1
		for direction in station.DIRECTIONS:
			var next: Vector2i = at + direction
			if distances.has(next) or not station.walkable(1, next) or station.laser_grid.blocked(at, next):
				continue
			distances[next] = int(distances[at]) + 1
			pending.append(next)
	return distances


func _relay_has_room(tile: Vector2i) -> bool:
	# The interaction circle and offset base fit inside a clear 3x3 area.
	# A straight 12 m lane on BOTH sides leaves a visible spawn side and an exit.
	for y in range(-1, 2):
		for x in range(-1, 2):
			if not station.walkable(1, tile + Vector2i(x, y)):
				return false
	for axis in [Vector2i.RIGHT, Vector2i.DOWN]:
		var clear_lane := true
		for step in [-3, -2, -1, 1, 2, 3]:
			var at: Vector2i = tile + axis * step
			if not station.walkable(1, at) or at in _critical_tiles():
				clear_lane = false
		if clear_lane:
			return true
	return false


func _relay_sites() -> Array[Vector2i]:
	# Three equal angular sectors, rather than three posts around the terminal.
	# Shortlists keep graph scoring bounded; every chosen pair is measured by BFS.
	var preferred := [Vector2i(20, 7), Vector2i(8, 29), Vector2i(32, 29)]
	var pools: Array[Array] = [[], [], []]
	for tile: Vector2i in _safe:
		if not _relay_has_room(tile):
			continue
		var sector := 0 if tile.y < 17 else (1 if tile.x < 20 else 2)
		pools[sector].append(tile)
	var distances := {}
	for sector in range(3):
		var target: Vector2i = preferred[sector]
		pools[sector].sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(target) < b.distance_squared_to(target))
		pools[sector] = pools[sector].slice(0, 8)
		for tile: Vector2i in pools[sector]:
			distances[tile] = _relay_distances(tile)
	var best: Array[Vector2i] = []
	var best_score := INF
	for first: Vector2i in pools[0]:
		for second: Vector2i in pools[1]:
			for third: Vector2i in pools[2]:
				if minf(first.distance_to(second), minf(second.distance_to(third), third.distance_to(first))) < 18.0:
					continue
				var legs := [int(distances[first].get(second, 0)), int(distances[second].get(third, 0)), int(distances[third].get(first, 0))]
				var shortest: int = legs.min()
				var longest: int = legs.max()
				if shortest < 20 or longest > shortest * 1.55:
					continue
				var placement := first.distance_squared_to(preferred[0]) + second.distance_squared_to(preferred[1]) + third.distance_squared_to(preferred[2])
				var score := float(placement) + float(longest - shortest) * 12.0
				if score < best_score:
					best_score = score
					best.assign([first, second, third])
	return best


func _budget_relay_lifetime() -> void:
	var recovery := RELAY_STAMINA_REGEN_DELAY + RELAY_STAMINA_MAX / RELAY_STAMINA_REGEN_RATE
	var legs: Array[float] = []
	for index in range(3):
		var route: Array = station.path(1, sites[index].tile, sites[(index + 1) % 3].tile)
		# Centerline path + both offset approaches is a conservative real route.
		legs.append(float(route.size() - 1) * station.CELL + 2.0 * SITE_OFFSET.length())
	legs.sort()
	# Worst two-leg order, all at WALK speed: the 4-second sprint is an escape
	# reserve, never an assumption of infinite sprint. Add corners, E and recovery.
	time_limit = ceilf((legs[1] + legs[2]) / RELAY_WALK_SPEED * 1.12 + recovery + 1.5)


func _sync_relay_progress() -> void:
	progress = 0
	remaining = 0.0
	for timer in relay_timers:
		if timer > 0.0:
			progress += 1
			remaining = timer if remaining <= 0.0 else minf(remaining, timer)


func _flat_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _near(first: Vector3, second: Vector3, radius: float) -> bool:
	return _flat_distance(first, second) <= radius and absf(first.y - second.y) < 1.20


func _on_floor(position: Vector3) -> bool:
	return position.y > -0.25 and position.y < 1.20


func _nearest_site(position: Vector3) -> int:
	var nearest := -1
	var distance := INTERACT_RADIUS
	for index in range(sites.size()):
		var candidate := _flat_distance(position, sites[index].position)
		if candidate <= distance:
			nearest = index
			distance = candidate
	return nearest


func _target_index() -> int:
	return mini(progress, sites.size() - 1) if not completed else -1


func _reset_attempt(reason: String) -> void:
	progress = 0
	remaining = 0.0
	armed = false
	_walked = 0.0
	_last_target = -999
	if kind == "relay":
		relay_timers.fill(0.0)
		relay_activation_events.clear()
	message = reason


func _complete() -> void:
	completed = true
	armed = false
	remaining = 0.0
	message = "三柱供电已锁定。返回 R-03 原终端按 E 取得记录。" if kind == "relay" else "场地操作通过。沿绿色箭头返回原终端，按 E 取得记录。"


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "DuskTrial_" + kind
	station.maps[1].add_child(visual_root)
	route_root = Node3D.new()
	route_root.name = "ObjectiveRoute"
	visual_root.add_child(route_root)
	for index in range(sites.size()):
		var site: Dictionary = sites[index]
		var marker := Node3D.new()
		marker.name = "Site_%d" % (index + 1)
		visual_root.add_child(marker)
		marker.position = site.position
		if kind == "silent":
			# A luminous line, never a physical door: the only corridor stays open.
			station.box(marker, Vector3(0, 0.045, 0), Vector3(2.6, 0.025, 0.15), station.palette.amber)
			for side in [-1, 1]:
				station.box(marker, Vector3(side * 1.30, 1.0, 0), Vector3(0.065, 2.0, 0.065), station.palette.frame)
			_lamps.append(station.box(marker, Vector3(0, 2.10, 0), Vector3(1.4, 0.12, 0.12), station.palette.amber))
		else:
			# Small real collision only under the switch. 0.61 m remains between
			# its side and the tile center line: a radius .30 capsule can pass.
			var base: MeshInstance3D = station.box(marker, Vector3.UP * BASE_SIZE.y / 2.0, BASE_SIZE, station.palette.frame, true)
			for body in base.find_children("*", "StaticBody3D", true, false):
				_bodies.append(body)
			station.box(marker, Vector3(0, 1.02, 0), Vector3(0.64, 0.14, 0.64), station.palette.ceramic)
			_lamps.append(station.box(marker, Vector3(0, 1.16, 0), Vector3(0.36, 0.16, 0.36), station.palette.amber))
		var caption: Label3D = station.sign_at(marker, Vector3(0, 2.38, 0), "", Color.WHITE)
		caption.font_size = 38
		caption.pixel_size = 0.0035
		caption.no_depth_test = false
		_labels.append(caption)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 1.6, 0)
		light.omni_range = 3.5
		light.shadow_enabled = false
		marker.add_child(light)
		_lights.append(light)
	_terminal_label = station.sign_at(visual_root, station.point(anchor) + Vector3(0, 2.30, 0.65), "", Color("ffd39b"))
	_terminal_label.font_size = 34
	_terminal_label.no_depth_test = false


func _set_enabled(enabled: bool) -> void:
	if is_instance_valid(visual_root):
		visual_root.visible = enabled
	for body in _bodies:
		if is_instance_valid(body):
			body.collision_layer = 1 if enabled else 0
			body.collision_mask = 1 if enabled else 0


func _refresh() -> void:
	if not is_instance_valid(visual_root):
		return
	for index in range(sites.size()):
		var done := completed or (relay_timers[index] > 0.0 if kind == "relay" else index < progress)
		var current := kind != "relay" and not completed and index == _target_index()
		var color := Color("69cdc1") if done else (Color("ffd39b") if current else Color("79818b"))
		_lamps[index].material_override = station.palette.mint if done else (station.palette.amber if current else station.palette.frame)
		_labels[index].modulate = color
		_labels[index].text = "%s %d / %s" % ["感应线" if kind == "silent" else ("同步开关" if kind == "clock" else "电源柱"), index + 1, "通过" if done else ("到这里" if current else "待机")]
		if kind == "relay":
			_labels[index].text = "电源柱 %d / %s" % [index + 1, "已锁定" if completed else ("供电 %.1fs" % relay_timers[index] if done else "[E] 启动")]
		_lights[index].light_color = color
		_lights[index].light_energy = 0.8 if done else (1.0 if current else 0.08)
	_terminal_label.text = "场地已通过 · [E] 取证" if completed else guidance()
	_terminal_label.modulate = Color("69cdc1") if completed else Color("ffd39b")


func _draw_route(origin: Vector2i) -> void:
	_last_tile = origin
	_last_target = _target_index()
	for child in route_root.get_children():
		child.free()
	if kind == "relay":
		return
	var destination: Vector2i = anchor if completed else sites[_target_index()].tile
	var route: Array = station.path(1, origin, destination)
	for index in range(mini(route.size() - 1, 18)):
		var arrow := Node3D.new()
		route_root.add_child(arrow)
		arrow.position = station.point(route[index]) + Vector3(0, 0.08, 0)
		var step: Vector2i = route[index + 1] - route[index]
		arrow.rotation.y = Vector3.FORWARD.signed_angle_to(Vector3(step.x, 0, step.y), Vector3.UP)
		var surface: Material = station.palette.mint if completed else station.palette.amber
		station.box(arrow, Vector3.ZERO, Vector3(0.07, 0.02, 0.70), surface)
		for side in [-1, 1]:
			var wing: MeshInstance3D = station.box(arrow, Vector3(side * 0.12, 0, -0.23), Vector3(0.06, 0.02, 0.38), surface)
			wing.rotation.y = side * PI / 4.0
