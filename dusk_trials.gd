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

var active := false
var completed := false
var kind := ""
var anchor := Vector2i.ZERO
var sites: Array[Dictionary] = []
var progress := 0
var remaining := 0.0
var time_limit := 0.0
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
	else:
		var offsets: Array = [Vector2i(0, 1), Vector2i(2, 2), Vector2i(-1, 3)] if kind == "silent" else [Vector2i(-2, 0), Vector2i(1, 2), Vector2i(2, -1)]
		for offset in offsets:
			var tile := _pick_tile(anchor + offset, tiles)
			if tile == Vector2i(-1, -1):
				clear()
				message = "附近没有安全场地，未解锁终端。"
				return false
			tiles.append(tile)
	if tiles.size() != (2 if kind == "clock" else 3):
		clear()
		message = "双开关附近没有安全绕行路线，未解锁终端。"
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
		if not completed and (armed or progress > 0):
			_reset_attempt("已离开暮区；返回后可重新开始。")
		_has_position = false
		return false
	var was_complete := completed
	var elapsed := maxf(delta, 0.0)
	if not completed and elapsed > 0.0:
		if kind == "clock" and progress == 1:
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
		if index == progress:
			progress += 1
			if progress == sites.size():
				_complete()
			else:
				message = "电源 %d / 3 已重启；前往下一根闪光电源柱。" % progress
		else:
			_reset_attempt("接通顺序不对，保护器已复位。沿箭头从电源 1 重新开始。")
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
		"relay": return "暗区重启：沿发光指引，到电源柱 1 → 2 → 3 分别按 E。"
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
	return "[E] %s %d" % ["合上同步开关" if kind == "clock" else "重启电源柱", index + 1]


func guidance() -> String:
	if not active:
		return ""
	if completed:
		return "场地操作已通过 · 返回原终端按 E 取证"
	if kind == "clock" and progress == 1:
		return "绕过设备 → 开关 2 · 剩余 %.1f 秒" % remaining
	return instructions()


func objective() -> Dictionary:
	if not active:
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
	for y in range(anchor.y - 6, anchor.y + 7):
		for x in range(anchor.x - 6, anchor.x + 7):
			var tile := Vector2i(x, y)
			if forbidden.has(tile) or not station.walkable(1, tile):
				continue
			var neighbors := 0
			for direction in station.DIRECTIONS:
				if station.walkable(1, tile + direction):
					neighbors += 1
			var route: Array = station.path(1, anchor, tile)
			if neighbors >= 2 and route.size() >= 2 and route.size() <= 10:
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
	message = reason


func _complete() -> void:
	completed = true
	armed = false
	remaining = 0.0
	message = "场地操作通过。沿绿色箭头返回原终端，按 E 取得记录。"


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
		var done := completed or index < progress
		var current := not completed and index == _target_index()
		var color := Color("69cdc1") if done else (Color("ffd39b") if current else Color("79818b"))
		_lamps[index].material_override = station.palette.mint if done else (station.palette.amber if current else station.palette.frame)
		_labels[index].modulate = color
		_labels[index].text = "%s %d / %s" % ["感应线" if kind == "silent" else ("同步开关" if kind == "clock" else "电源柱"), index + 1, "通过" if done else ("到这里" if current else "待机")]
		_lights[index].light_color = color
		_lights[index].light_energy = 0.8 if done else (1.0 if current else 0.08)
	_terminal_label.text = "场地已通过 · [E] 取证" if completed else guidance()
	_terminal_label.modulate = Color("69cdc1") if completed else Color("ffd39b")


func _draw_route(origin: Vector2i) -> void:
	_last_tile = origin
	_last_target = _target_index()
	for child in route_root.get_children():
		child.free()
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
