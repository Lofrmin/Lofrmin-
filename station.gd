extends Node3D

const CELL := 4.0
# v6 环形地图（2026-11-07）：41×41，外环/中环/内环/中心四层；数据由 03_资产/R01_环形地图/layout/export_station.py 生成
const MAP_SIZE := Vector2i(41, 41)
const MORNING := [
	"#########################################",
	"################.........################",
	"##.....######..#.........#..######.....##",
	"##.....####...................####.....##",
	"##.....##.......#########.......##.....##",
	"##.....#.........#######.........#.....##",
	"##.........###...#######...###.........##",
	"######....####.............####....######",
	"#####...#######...........#######...#####",
	"####....#####....##...##....#####....####",
	"####...#####...####...####...#####...####",
	"###...#####..######...######..#####...###",
	"###...####..#######...#######..####...###",
	"##....###..#######.....#######..###....##",
	"##......#..#####.........#####..#......##",
	"###.......#####...#####...#####.......###",
	"#...#.....####.....###.....####.....#...#",
	"#...###..#####.............#####..###...#",
	"#...###..####..#.........#..####..###...#",
	"#...###........##.......##........###...#",
	"#...###........##.......##........###...#",
	"#...###........##.......##........###...#",
	"#...###..####..#.........#..####..###...#",
	"#...###..#####.............#####..###...#",
	"#...#.....####.....###.....####.....#...#",
	"###.......#####...#####...#####.......###",
	"##......#..#####.........#####..#......##",
	"##....###..#######.....#######..###....##",
	"###...####..#######...#######..####...###",
	"###...#####..######...######..#####...###",
	"####...#####...####...####...#####...####",
	"####....#####....##...##....#####....####",
	"#####...#######...........#######...#####",
	"######....####.............####....######",
	"##.........###...#######...###.........##",
	"##.....#.........#######.........#.....##",
	"##.....##.......#########.......##.....##",
	"##.....####...................####.....##",
	"##.....######..#.........#..######.....##",
	"################.........################",
	"#########################################",
]
const DUSK := [
	"#########################################",
	"################.........################",
	"##.....######...............######.....##",
	"##.....####...................####.....##",
	"##.....##.......#########.......##.....##",
	"##.....#.....#...#######...#.....#.....##",
	"##..........##...#.....#...##..........##",
	"######....####.............####....######",
	"#####......##...............##......#####",
	"####.................................####",
	"####...#........###...###........#...####",
	"###.....#.....#####...#####.....#.....###",
	"###..........######...######..........###",
	"##....#.....######.....######.....#....##",
	"##....#....#####.........#####....#....##",
	"##...#.....####...#####...####.....#...##",
	"#.........####.....###.....####.........#",
	"#.........####.............####.........#",
	"#...##....###..#.........#..###....##...#",
	"#..............##.......##..............#",
	"#..............##.......##..............#",
	"#..............##.......##..............#",
	"#...##....###..#.........#..###....##...#",
	"#.........####.............####.........#",
	"#.........####.....###.....####.........#",
	"##...#.....#......#####......#.....#...##",
	"##....#...........................#....##",
	"##....#......#..##.....##..#......#....##",
	"###.............###...###.............###",
	"###.....#......####...####......#.....###",
	"####...#........###...###........#...####",
	"####.................................####",
	"#####......##...............##......#####",
	"######....#####...........#####....######",
	"##..........######.....######..........##",
	"##.....#.....######...######.....#.....##",
	"##.....##.......###...###.......##.....##",
	"##.....####...................####.....##",
	"##.....######...............######.....##",
	"################.........################",
	"#########################################",
]
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const AUDIT := Vector2i(15, 6)
const OFFICE := Vector2i(25, 6)
const RELAY := Vector2i(20, 31)
const LAB := Vector2i(20, 20)
const MEDICAL := Vector2i(20, 14)
const LEDGER := Vector2i(20, 26)
# 4 扇换相门：北 2（贴 A-01/B-17，与 demo 一致）＋南 2（贴 R-03/L-06 一侧）。到最近门平均 14 格，demo 是 6 格
const GATES := [Vector2i(11, 4), Vector2i(29, 4), Vector2i(11, 36), Vector2i(29, 36)]
# 追债人 guard 战术的守点（原 game.gd 写死 Vector2i(2, 1)，即 A-01 旁一格）
const GUARD := Vector2i(16, 7)
const BREAKS_MORNING := [
	{"name": "C1", "stage": 2, "tiles": [Vector2i(35, 28), Vector2i(36, 26), Vector2i(36, 27), Vector2i(36, 28), Vector2i(36, 29), Vector2i(37, 27), Vector2i(37, 28), Vector2i(37, 29), Vector2i(38, 27)]},
	{"name": "C2", "stage": 2, "tiles": [Vector2i(2, 13), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13), Vector2i(4, 11), Vector2i(4, 12), Vector2i(4, 13), Vector2i(4, 14), Vector2i(5, 12)]},
	{"name": "B1", "stage": 3, "tiles": [Vector2i(8, 25), Vector2i(9, 25), Vector2i(9, 26)]},
	{"name": "B2", "stage": 3, "tiles": [Vector2i(31, 14), Vector2i(31, 15), Vector2i(32, 15)]},
	{"name": "A1", "stage": 4, "tiles": [Vector2i(26, 20), Vector2i(27, 20)]},
	{"name": "A2", "stage": 4, "tiles": [Vector2i(13, 20), Vector2i(14, 20)]},
]
const BREAKS_DUSK := [
	{"name": "C1", "stage": 2, "tiles": [Vector2i(19, 37), Vector2i(19, 38), Vector2i(19, 39), Vector2i(20, 37), Vector2i(20, 38), Vector2i(20, 39), Vector2i(21, 37), Vector2i(21, 38), Vector2i(21, 39)]},
	{"name": "C2", "stage": 2, "tiles": [Vector2i(19, 1), Vector2i(19, 2), Vector2i(19, 3), Vector2i(20, 1), Vector2i(20, 2), Vector2i(20, 3), Vector2i(21, 1), Vector2i(21, 2), Vector2i(21, 3)]},
	{"name": "B1", "stage": 3, "tiles": [Vector2i(25, 30), Vector2i(25, 31), Vector2i(25, 32), Vector2i(25, 33), Vector2i(26, 31), Vector2i(26, 32)]},
	{"name": "B2", "stage": 3, "tiles": [Vector2i(12, 30), Vector2i(12, 31), Vector2i(13, 29), Vector2i(13, 30), Vector2i(13, 31), Vector2i(13, 32), Vector2i(14, 30)]},
	{"name": "A1", "stage": 4, "tiles": [Vector2i(26, 20), Vector2i(27, 20)]},
	{"name": "A2", "stage": 4, "tiles": [Vector2i(13, 20), Vector2i(14, 20)]},
]
const RETURN_MARKERS := [Vector2i(38, 20), Vector2i(33, 33), Vector2i(18, 38), Vector2i(7, 33), Vector2i(2, 20), Vector2i(7, 7), Vector2i(18, 2), Vector2i(33, 7), Vector2i(32, 25), Vector2i(15, 32), Vector2i(8, 15), Vector2i(25, 8), Vector2i(25, 25), Vector2i(15, 25), Vector2i(15, 15), Vector2i(25, 15)]
const AUDIT_MONITOR_SCENE := preload("res://assets/props/a01/SM_A01_Monitor.glb")
const AUDIT_KEYBOARD := preload("res://assets/props/a01/SM_A01_Keyboard.glb")
const AUDIT_FILE := preload("res://assets/props/a01/SM_A01_File.glb")
const AUDIT_STAMP := preload("res://assets/props/a01/SM_A01_Stamp.glb")
const OFFICIAL_MASCOTS := preload("res://assets/props/panda_jam/official_mascots_front.png")

var maps: Array[Node3D] = []
var grids: Array[AStarGrid2D] = []
var palette := {}
var markers: Array[Label3D] = []
var witnesses: Array[Node3D] = []
var box_meshes: Dictionary = {}
var instruments: Array[Node3D] = []
var observation_glass: ShaderMaterial
# Solid cells connected to space, excluding enclosed interior wall islands.
var exterior_cells: Array[Dictionary] = [{}, {}]
var audit_labels: Array[Label3D] = []
var return_signs: Array[Label3D] = []
var use_audit_monitor_prop := true
# 断点：随章节逐段封闭（S2~S4 ＝ 第 1~3 章）。封闭的格子 walkable=false、A* solid、有碰撞墙
var map_stage := 1
# game.gd 的章节下标不是剧情顺序（NEXT_CHAPTER = 0→3→1→4→2），断点阶段按剧情第几章算
const STORY_STEP := {0: 1, 3: 2, 1: 3, 4: 4, 2: 5}
var closed: Array[Dictionary] = [{}, {}]
var barriers: Array[Array] = [[], []]
var return_arrows: Array[Node3D] = []
# P1 R-03 / E-7 中继视觉反馈：每相一份，键 = 子节点引用，值由 update_relay_state 驱动
# 子节点纯装饰（不新增碰撞、不改交互范围、不改谜题与时长），复用 game.relay_status 的阶段语义
var relay_rigs: Array[Dictionary] = []


func build() -> void:
	observation_glass = ShaderMaterial.new()
	observation_glass.shader = preload("res://observation_glass.gdshader")
	palette = {
		"floor": material(Color("30363d"), 0.28), "wall": material(Color("515e62"), 0.32),
		"frame": material(Color("22292d"), 0.48), "ink": material(Color("10171d")),
		"ceramic": alloy(Color("8a9290")), "ivory": material(Color("edebe1"), 0.0, 1.4),
		"mint": material(Color("69cdc1"), 0.0, 0.85), "amber": material(Color("e79a4c"), 0.0, 0.90),
		"blue": material(Color("54c9ff"), 0.0, 1.3), "red": material(Color("ff315f"), 0.0, 2.3),
		"white": material(Color("b0cfda"), 0.1, 0.3), "dark": alloy(Color("5d4d44")),
		"suit": material(Color("537285"), 0.2), "visor": material(Color("839dab"), 0.0, 0.30),
		"alloy": alloy(Color("454d51")), "alloy_warm": alloy(Color("433933")),
		"display": display_surface(Color("6df9d8")), "display_warm": display_surface(Color("f5ab63")),
	}
	for phase in range(2):
		find_exterior_cells(phase)
		var layer := Node3D.new()
		layer.name = ["Morning", "Dusk"][phase]
		add_child(layer)
		maps.append(layer)
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.update()
		grids.append(grid)
		for z in range(MAP_SIZE.y):
			for x in range(MAP_SIZE.x):
				var tile := Vector2i(x, z)
				if walkable(phase, tile):
					build_tile(layer, phase, tile)
				else:
					grid.set_point_solid(tile)
	for phase in range(2):
		build_breaks(phase)
		build_return_markers(phase)
	set_phase(0)


func return_hint(phase: int, tile: Vector2i) -> Dictionary:
	var target: Vector2i = AUDIT
	var label := "A-01 / 回调查台"
	if phase == 1:
		var gate := -1
		var best := 1 << 30
		for index in range(GATES.size()):
			var route_to: Array[Vector2i] = path(phase, tile, GATES[index])
			if not route_to.is_empty() and route_to.size() < best:
				best = route_to.size()
				gate = index
		if gate < 0:
			return {}
		target = GATES[gate]
		label = "G-0%d / 换回晨区" % (gate + 1)
	var route: Array[Vector2i] = path(phase, tile, target)
	if route.size() < 2:
		return {}
	return {"target": target, "direction": route[1] - tile, "label": label}


func build_return_markers(phase: int) -> void:
	var accent: StandardMaterial3D = palette.mint if phase == 0 else palette.amber
	for tile in RETURN_MARKERS:
		var hint: Dictionary = return_hint(phase, tile)
		if hint.is_empty(): continue
		var arrow := Node3D.new()
		maps[phase].add_child(arrow)
		return_arrows.append(arrow)
		arrow.position = point(tile) + Vector3(0, 0.055, 0.7)
		var direction: Vector3 = Vector3(hint.direction.x, 0, hint.direction.y)
		arrow.rotation.y = Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
		box(arrow, Vector3.ZERO, Vector3(0.065, 0.012, 0.52), accent)
		for side in [-1, 1]:
			var wing: MeshInstance3D = box(arrow, Vector3(side * 0.10, 0, -0.19), Vector3(0.055, 0.012, 0.28), accent)
			wing.rotation.y = side * PI / 4.0
		var label: Label3D = sign_at(maps[phase], point(tile) + Vector3(0, 2.35, 0.7), hint.label, accent.albedo_color)
		label.font_size = 30
		label.pixel_size = 0.0025
		return_signs.append(label)


func animate_instruments(seconds: float) -> void:
	for instrument in instruments:
		instrument.rotation.y = seconds * 0.63


func set_phase(phase: int) -> void:
	for index in range(maps.size()):
		maps[index].visible = index == phase
		maps[index].process_mode = Node.PROCESS_MODE_INHERIT if index == phase else Node.PROCESS_MODE_DISABLED


func walkable(phase: int, tile: Vector2i) -> bool:
	if not Rect2i(Vector2i.ZERO, MAP_SIZE).has_point(tile):
		return false
	var rows: Array = MORNING if phase == 0 else DUSK
	if closed[phase].has(tile):
		return false
	return rows[tile.y][tile.x] != "#"


func point(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * CELL, 0, tile.y * CELL)


func cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))


func path(phase: int, origin: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	if not walkable(phase, origin) or not walkable(phase, destination):
		return []
	return grids[phase].get_id_path(origin, destination)


func find_exterior_cells(phase: int) -> void:
	var rows: Array = MORNING if phase == 0 else DUSK
	var outside: Dictionary = exterior_cells[phase]
	outside.clear()
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	outside[Vector2i.ZERO] = true
	var cursor := 0
	while cursor < pending.size():
		var tile: Vector2i = pending[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var neighbor: Vector2i = tile + direction
			if not Rect2i(Vector2i.ZERO, MAP_SIZE).has_point(neighbor):
				continue
			if rows[neighbor.y][neighbor.x] != "#" or outside.has(neighbor):
				continue
			outside[neighbor] = true
			pending.append(neighbor)


func build_tile(layer: Node3D, phase: int, tile: Vector2i) -> void:
	var center := point(tile)
	var accent: StandardMaterial3D = palette.mint if phase == 0 else palette.amber
	var wall: Material = palette.ceramic if phase == 0 else palette.dark
	box(layer, center + Vector3(0, -0.12, 0), Vector3(4, 0.24, 4), palette.floor, true)
	box(layer, center + Vector3(0, 3.04, 0), Vector3(4, 0.18, 4), palette.frame)
	box(layer, center + Vector3(0, 0.006, 0), Vector3(3.77, 0.014, 3.77), palette.alloy if phase == 0 else palette.alloy_warm)
	box(layer, center + Vector3(0, 0.025, 1.92), Vector3(3.65, 0.018, 0.035), palette.frame)
	box(layer, center + Vector3(1.92, 0.025, 0), Vector3(0.035, 0.018, 3.65), palette.frame)
	for offset in [-1.6, 1.6]:
		box(layer, center + Vector3(offset, 0.026, 0), Vector3(0.032, 0.024, 2.90), palette.frame)
		box(layer, center + Vector3(offset, 0.039, 0.55), Vector3(0.027, 0.016, 0.62), accent)
	box(layer, center + Vector3(0, 2.89, 0), Vector3(0.77, 0.12, 2.10), palette.ink)
	var active_light := (tile.x + 2 * tile.y) % 3 == 0 or tile in [AUDIT, OFFICE, LAB, RELAY, MEDICAL, LEDGER]
	for offset in [-0.21, 0.21]:
		box(layer, center + Vector3(offset, 2.815, 0), Vector3(0.085, 0.04, 1.82), (palette.ivory if phase == 0 else palette.amber) if active_light else palette.wall)
	if active_light:
		add_fixture_light(layer, phase, center, tile)
	for direction in DIRECTIONS:
		var outward := point(direction).normalized()
		var sideways := Vector3(-outward.z, 0, outward.x)
		var edge := center + outward * 1.97
		if not walkable(phase, tile + direction):
			wall_panel(layer, edge, outward, sideways, wall, accent, tile, phase)
		elif direction == Vector2i.RIGHT or direction == Vector2i.DOWN:
			for sign_value in [-1, 1]:
				# 柱子带碰撞（v6 宽场地里柱子立在空地中间，原来没碰撞，玩家会穿过去）
				box(layer, edge + sideways * 1.87 * sign_value + Vector3.UP * 1.49, Vector3(0.23, 2.98, 0.23), palette.frame, true)
				var brace := box(layer, edge + sideways * 1.63 * sign_value + Vector3.UP * 2.62, axes(outward, 0.26, 0.57, 0.14), wall)
				if absf(outward.z) > 0.5:
					brace.rotation.z = sign_value * 0.69
				else:
					brace.rotation.x = sign_value * 0.69
			box(layer, edge + Vector3.UP * 2.84, axes(outward, 0.30, 0.22, 3.8), palette.frame)
	if tile in [AUDIT, OFFICE, RELAY, LAB, MEDICAL, LEDGER] or tile in GATES:
		fixture(layer, tile, phase, accent)


func add_fixture_light(layer: Node3D, phase: int, center: Vector3, tile: Vector2i) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("f5f5ec") if phase == 0 else Color("ffb575")
	lamp.light_energy = 1.62 if phase == 0 else 1.27
	lamp.light_specular = 0.42
	lamp.omni_range = 5.4
	lamp.shadow_enabled = tile in [AUDIT, OFFICE, LAB, MEDICAL, RELAY, LEDGER]
	layer.add_child(lamp)
	lamp.position = center + Vector3(0, 2.53, 0)


func wall_panel(layer: Node3D, edge: Vector3, outward: Vector3, sideways: Vector3, wall: Material, accent: Material, tile: Vector2i, phase: int) -> void:
	var neighbor := tile + Vector2i(roundi(outward.x), roundi(outward.z))
	if exterior_cells[phase].has(neighbor):
		var window := Node3D.new()
		window.name = "OuterWindow_%d_%d_%d_%d" % [tile.x, tile.y, roundi(outward.x), roundi(outward.z)]
		layer.add_child(window)
		window.position = edge
		# The reference window is built facing north. Rotate its entire frame,
		# glass and collision together for each edge of the stepped outer hull.
		window.rotation.y = atan2(-outward.x, -outward.z)
		observation_window(window, Vector3.ZERO, Vector3.RIGHT, wall, phase)
		return
	box(layer, edge + Vector3.UP * 1.51, axes(outward, 0.15, 3.02, 4), wall, true)
	box(layer, edge - outward * 0.10 + Vector3.UP * 1.53, axes(outward, 0.09, 1.63, 3.37), palette.frame)
	box(layer, edge - outward * 0.16 + Vector3.UP * 1.53, axes(outward, 0.05, 1.40, 3.07), palette.alloy if phase == 0 else palette.alloy_warm)
	for side in [-1, 1]:
		box(layer, edge + sideways * 1.83 * side - outward * 0.06 + Vector3.UP * 1.49, axes(outward, 0.24, 2.98, 0.21), palette.frame)
	box(layer, edge - outward * 0.11 + Vector3.UP * 2.47, axes(outward, 0.07, 0.045, 3.39), palette.frame)
	box(layer, edge - outward * 0.15 + sideways * 1.25 + Vector3.UP * 2.47, axes(outward, 0.043, 0.035, 0.73), accent)
	box(layer, edge - outward * 0.11 + Vector3.UP * 0.32, axes(outward, 0.11, 0.13, 3.49), palette.frame)


func observation_window(layer: Node3D, edge: Vector3, sideways: Vector3, wall: Material, phase: int) -> void:
	box(layer, edge + Vector3.UP * 1.51, Vector3(4, 3.02, 0.16), wall, true).hide()
	var framing: Material = palette.ceramic if phase == 0 else palette.dark
	box(layer, edge + Vector3(0, 0.34, 0), Vector3(4.02, 0.72, 0.32), framing)
	box(layer, edge + Vector3(0, 2.77, 0), Vector3(4.02, 0.56, 0.32), framing)
	box(layer, edge + Vector3(0, 0.74, 0.11), Vector3(3.83, 0.11, 0.45), palette.frame)
	box(layer, edge + Vector3(0, 2.44, 0.10), Vector3(3.83, 0.13, 0.40), palette.frame)
	for side in [-1, 1]:
		box(layer, edge + sideways * 1.87 * side + Vector3.UP * 1.51, Vector3(0.31, 3.01, 0.36), framing)
		box(layer, edge + sideways * 1.69 * side + Vector3(0, 1.59, 0.11), Vector3(0.08, 1.70, 0.19), palette.frame)
	var pane := QuadMesh.new()
	pane.size = Vector2(3.40, 1.71)
	var glass := MeshInstance3D.new()
	glass.mesh = pane
	glass.material_override = observation_glass
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.add_child(glass)
	glass.position = edge + Vector3(0, 1.59, 0.035)


func fixture(layer: Node3D, tile: Vector2i, phase: int, accent: Material) -> void:
	var center := point(tile)
	if tile in GATES:
		for offset in [-1.25, 1.25]:
			box(layer, center + Vector3(offset, 1.35, 0), Vector3(0.20, 2.70, 0.35), palette.frame)
			box(layer, center + Vector3(offset, 1.45, 0.20), Vector3(0.07, 2.24, 0.06), accent)
		box(layer, center + Vector3(0, 2.61, 0), Vector3(2.53, 0.19, 0.37), palette.frame)
		box(layer, center + Vector3(0, 0.031, 0), Vector3(2.25, 0.035, 0.22), accent)
		var gate_name := "G-%02d" % (GATES.find(tile) + 1)
		markers.append(sign_at(layer, center + Vector3(0, 2.39, 0), gate_name + " / PHASE GATE", accent.albedo_color))
		return
	var heading := "B-17 / LIN CEN"
	if tile == AUDIT:
		heading = "A-01 / AUDIT DESK"
	elif tile == RELAY:
		heading = "R-03 / EMERGENCY RELAY"
	elif tile == LAB:
		heading = "C-04 / CLOCK LAB"
	elif tile == MEDICAL:
		heading = "D-09 / LIFE SUPPORT"
	elif tile == LEDGER:
		heading = "L-06 / SETTLEMENT"
	var desk := center + Vector3(0, 0, -1.21)
	box(layer, desk + Vector3.UP * 0.45, Vector3(1.68, 0.90, 0.54), palette.frame, true)
	box(layer, desk + Vector3.UP * 0.95, Vector3(1.85, 0.14, 0.68), palette.wall)
	var monitor_shell := box(layer, desk + Vector3.UP * 1.23, Vector3(1.22, 0.45, 0.12), palette.ink)
	var monitor := QuadMesh.new()
	monitor.size = Vector2(1.10, 0.34)
	var screen := MeshInstance3D.new()
	screen.mesh = monitor
	screen.material_override = palette.display if phase == 0 else palette.display_warm
	layer.add_child(screen)
	screen.position = desk + Vector3(0, 1.23, 0.068)
	if tile == AUDIT:
		build_audit_details(layer, desk, screen, monitor_shell)
	elif tile == RELAY:
		# P1：R-03 的旧显示器由新中继模块替代，避免几何重叠遮挡
		monitor_shell.visible = false
		screen.visible = false
	var plate := sign_at(layer, desk + Vector3(0, 1.86, 0.12), heading, accent.albedo_color)
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.pixel_size = 0.00165
	plate.outline_size = 3
	if tile == OFFICE:
		box(layer, center + Vector3(-1.53, 0.42, 0.57), Vector3(0.59, 0.83, 0.63), palette.frame)
		box(layer, center + Vector3(-1.53, 0.76, 0.57), Vector3(0.63, 0.12, 0.68), accent)
		build_witness(layer, center)
	elif tile == LAB:
		var projector := Node3D.new()
		layer.add_child(projector)
		projector.position = center + Vector3(0.76, 1.44, -0.51)
		instruments.append(projector)
		for radius in [0.35, 0.52]:
			var ring := TorusMesh.new()
			ring.inner_radius = radius - 0.012
			ring.outer_radius = radius + 0.012
			ring.rings = 40
			ring.ring_segments = 6
			var clock_face := MeshInstance3D.new()
			clock_face.mesh = ring
			clock_face.material_override = accent
			projector.add_child(clock_face)
			clock_face.rotation_degrees.z = 78.0 if radius < 0.5 else 31.0
	elif tile == MEDICAL:
		var pod := center + Vector3(-1.32, 0, 0.45)
		box(layer, pod + Vector3.UP * 0.39, Vector3(0.86, 0.78, 1.79), palette.frame)
		box(layer, pod + Vector3.UP * 0.84, Vector3(0.80, 0.20, 1.68), palette.wall)
		for offset in [-0.38, 0.38]:
			box(layer, pod + Vector3(offset, 0.91, 0), Vector3(0.035, 0.025, 1.50), accent)
		box(layer, pod + Vector3(0, 1.07, -0.75), Vector3(0.69, 0.30, 0.08), palette.visor)
	elif tile in [LEDGER, RELAY]:
		for side in [-1, 1]:
			var rack := center + Vector3(side * 1.52, 1.29, -1.14)
			box(layer, rack, Vector3(0.53, 2.58, 0.49), palette.frame)
			for row in range(5):
				var height := 0.36 * row - 0.72
				box(layer, rack + Vector3(0, height, 0.253), Vector3(0.36, 0.19, 0.07), palette.wall)
				box(layer, rack + Vector3(0.11, height, 0.301), Vector3(0.07, 0.036, 0.024), accent)
	if tile == RELAY:
		build_relay_rig(layer, center, phase, accent)


func build_audit_details(layer: Node3D, desk: Vector3, screen: MeshInstance3D, monitor_shell: MeshInstance3D) -> void:
	# Decoration stays inside the existing desk footprint or its tabletop wings.
	if use_audit_monitor_prop:
		monitor_shell.visible = false
		screen.visible = false
		var monitor: Node3D = AUDIT_MONITOR_SCENE.instantiate()
		monitor.name = "A01_Monitor"
		layer.add_child(monitor)
		monitor.position = desk + Vector3(0, 1.02, -0.04)
	box(layer, desk + Vector3(0, 0.95, 0), Vector3(2.65, 0.12, 0.78), palette.wall)
	if not use_audit_monitor_prop:
		box(layer, desk + Vector3(0, 1.04, -0.04), Vector3(0.13, 0.19, 0.10), palette.frame)
	if use_audit_monitor_prop:
		for item in [
			[AUDIT_KEYBOARD, "A01_Keyboard", Vector3(0, 1.02, 0.27), Vector3(0.57, 0.24, 0.40), 0.0],
			[AUDIT_FILE, "A01_File", Vector3(-1.01, 1.02, -0.29), Vector3.ONE * 0.27, -0.16],
			[AUDIT_STAMP, "A01_Stamp", Vector3(0.80, 1.02, -0.26), Vector3.ONE * 0.22, 0.23],
		]:
			var prop: Node3D = item[0].instantiate()
			prop.name = item[1]
			prop.position = desk + item[2]
			prop.scale = item[3]
			prop.rotation.y = item[4]
			layer.add_child(prop)
	else:
		box(layer, desk + Vector3(0, 1.015, 0.30), Vector3(0.65, 0.035, 0.18), palette.frame)
		for row in range(3):
			for col in range(10):
				box(layer, desk + Vector3(-0.27 + col * 0.06, 1.038, 0.245 + row * 0.05), Vector3(0.045, 0.009, 0.035), palette.wall)
	box(layer, desk + Vector3(0.48, 1.035, 0.23), Vector3(0.13, 0.05, 0.20), palette.frame)
	for side in [-1, 1]:
		box(layer, desk + Vector3(side * 0.94, 1.025, 0.03), Vector3(0.53, 0.025, 0.62), palette.frame)
		box(layer, desk + Vector3(side * 0.94, 1.043, 0.03), Vector3(0.47, 0.009, 0.56), palette.white)
		box(layer, desk + Vector3(side * 0.94, 1.052, -0.22), Vector3(0.15, 0.02, 0.04), palette.frame)
		var paper: Label3D = sign_at(layer, desk + Vector3(side * 0.94, 1.052, 0.03), "授权单\nA-42\n复核人：____" if side < 0 else "审计匣\n现场记录\n入库待核验", Color("17252a"))
		paper.name = "AuthorizationPaper" if side < 0 else "EvidenceFolder"
		paper.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		paper.rotation.x = -PI / 2.0
		paper.font_size = 30
		paper.pixel_size = 0.0022
		paper.outline_size = 0
		paper.no_depth_test = false
	screen.material_override = palette.ink
	var status_position := desk + Vector3(0, 1.23, 0.077)
	if use_audit_monitor_prop:
		status_position = desk + Vector3(0, 0.72, 0.405)
		box(layer, status_position - Vector3(0, 0, 0.02), Vector3(1.40, 0.30, 0.035), palette.ink)
	var status: Label3D = sign_at(layer, status_position, "", Color("a7dcd0"))
	status.name = "AuditStatus"
	status.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	status.font_size = 30
	status.pixel_size = 0.0016
	status.outline_size = 0
	audit_labels.append(status)
	var placard := desk + Vector3(0, 2.36, 0.07)
	box(layer, placard + Vector3(0, 0, -0.03), Vector3(1.16, 0.79, 0.05), palette.frame)
	box(layer, placard + Vector3(0, 0.42, -0.03), Vector3(0.08, 0.32, 0.08), palette.frame)
	var mascots := Sprite3D.new()
	mascots.name = "A01_PandaJamMascots"
	mascots.texture = OFFICIAL_MASCOTS
	mascots.region_enabled = true
	# The original sheet includes Padding on the right; only Xiaomiao and Duoji are featured.
	mascots.region_rect = Rect2(64, 213, 932, 587)
	mascots.pixel_size = 0.00115
	layer.add_child(mascots)
	mascots.position = placard + Vector3.UP * 0.027
	var caption := sign_at(layer, placard + Vector3(0, -0.348, 0.005), "PANDA JAM / 多吉与小咪", Color("e0eee7"))
	caption.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	caption.pixel_size = 0.00091
	caption.outline_size = 0


func update_audit_status(text: String) -> void:
	for label in audit_labels:
		label.text = text


# ── P1 R-03 / E-7 中继视觉反馈 ────────────────────────────────────────
# 复古工业中继模块：机箱 + 刀开关 + E-7 端口组 + 状态灯 + 上传扫描条
# 纯装饰（无碰撞、无新交互、无新增时长），全部由 game.relay_status 阶段驱动
func build_relay_rig(layer: Node3D, center: Vector3, phase: int, accent: Material) -> void:
	var rig := Node3D.new()
	rig.name = "RelayRig_%d" % phase
	layer.add_child(rig)
	# 安装位置：继电器桌上，桌顶 Y=0.95+0.14/2=1.02（之前误用 0.95 让底座沉入桌面）
	var desk := center + Vector3(0, 0, -1.21)
	rig.position = desk + Vector3(0, 1.02, 0)

	# ── 机箱底座：复古工业风格，宽扁盒 ──
	box(rig, Vector3(0, 0.055, 0), Vector3(1.30, 0.11, 0.46), palette.frame)
	# 机箱侧裙
	box(rig, Vector3(0, 0.16, -0.20), Vector3(1.30, 0.10, 0.04), palette.wall)
	# 前面板（略带倾角的斜面）
	var face := box(rig, Vector3(0, 0.16, 0.10), Vector3(1.24, 0.18, 0.30), palette.alloy if phase == 0 else palette.alloy_warm)
	face.rotation.x = -0.18

	# ── 状态灯（多形态：颜色 + 位置亮灭 + 文字）──
	# 三盏小灯：核验（左）、合闸（中）、外发（右）
	var lamp_mats: Array[StandardMaterial3D] = []
	var lamp_positions := [Vector3(-0.42, 0.265, 0.235), Vector3(0.0, 0.265, 0.235), Vector3(0.42, 0.265, 0.235)]
	for i in range(3):
		var lamp_mat := StandardMaterial3D.new()
		lamp_mat.albedo_color = Color("3a4148")
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color("101418")
		lamp_mat.emission_energy_multiplier = 0.0
		lamp_mat.roughness = 0.35
		lamp_mats.append(lamp_mat)
		var socket := box(rig, lamp_positions[i] - Vector3(0, 0, 0.005), Vector3(0.10, 0.025, 0.05), palette.ink)
		socket.name = "LampSocket_%d" % i
		var bulb := MeshInstance3D.new()
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.028
		bulb_mesh.height = 0.056
		bulb_mesh.radial_segments = 12
		bulb_mesh.rings = 6
		bulb.mesh = bulb_mesh
		bulb.material_override = lamp_mat
		rig.add_child(bulb)
		bulb.position = lamp_positions[i] + Vector3(0, 0.018, 0.018)
		bulb.name = "Lamp_%d" % i

	# ── 刀开关：会转动的手柄（合闸时从竖直到水平）──
	var switch_base := box(rig, Vector3(-0.50, 0.21, -0.02), Vector3(0.16, 0.06, 0.16), palette.ink)
	switch_base.name = "SwitchBase"
	var switch_arm := Node3D.new()
	switch_arm.name = "SwitchArm"
	rig.add_child(switch_arm)
	switch_arm.position = Vector3(-0.50, 0.24, -0.02)
	var arm_mesh := box(switch_arm, Vector3(0, 0.10, 0), Vector3(0.025, 0.20, 0.025), palette.ivory)
	arm_mesh.name = "Arm"
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.030
	knob_mesh.height = 0.060
	knob_mesh.radial_segments = 10
	knob_mesh.rings = 5
	knob.mesh = knob_mesh
	knob.material_override = palette.red
	switch_arm.add_child(knob)
	knob.position = Vector3(0, 0.205, 0)
	knob.name = "Knob"
	# 初始：断开（竖起）
	switch_arm.rotation.x = 0.0

	# ── E-7 同编号端口组（4 个，靠近面板前沿）──
	var port_mats: Array[StandardMaterial3D] = []
	for i in range(4):
		var px := -0.12 + i * 0.16
		# 端口金属环
		box(rig, Vector3(px, 0.17, 0.20), Vector3(0.10, 0.06, 0.10), palette.frame)
		var port_mat := StandardMaterial3D.new()
		port_mat.albedo_color = Color("2a3036")
		port_mat.emission_enabled = true
		port_mat.emission = Color("0a0d10")
		port_mat.emission_energy_multiplier = 0.0
		port_mats.append(port_mat)
		var core := box(rig, Vector3(px, 0.175, 0.21), Vector3(0.055, 0.04, 0.055), port_mat)
		core.name = "Port_%d" % i

	# ── E-7 标签（永远显示，与 puzzle 中编号一致）──
	# 放在机箱顶面后方，竖直朝 +z（玩家从桌正前方能直接读到）
	var label := sign_at(rig, Vector3(0, 0.30, -0.12), "E-7 / RELAY", Color("e79a4c") if phase == 1 else Color("69cdc1"))
	label.name = "E7_Label"
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.font_size = 48
	label.pixel_size = 0.0035
	label.outline_size = 6
	# 默认 sign_at 是 billboard，禁用后 Label3D 的 +Z 面朝向父节点 +Z，玩家从 +z 看过来正好读到
	label.rotation = Vector3.ZERO

	# ── 状态短文字（在机箱前面板，竖直朝 +z，玩家正常站位即可读到）──
	# 关键：之前 rotation.x = -PI/2+0.18 是平铺在桌面上，正常站立看不到；改成竖直朝前
	var status_label := sign_at(rig, Vector3(0, 0.20, 0.27), "IDLE", Color("a7dcd0"))
	status_label.name = "StatusLabel"
	status_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	status_label.font_size = 44
	status_label.pixel_size = 0.0032
	status_label.outline_size = 6
	status_label.rotation = Vector3.ZERO  # 竖直朝 +z，与机箱前面板同向

	# ── 上传扫描条（upload 时亮起的一道光带，沿面板前缘水平扫动）──
	var scan_mat := StandardMaterial3D.new()
	scan_mat.albedo_color = Color("54c9ff")
	scan_mat.emission_enabled = true
	scan_mat.emission = Color("54c9ff")
	scan_mat.emission_energy_multiplier = 2.0
	var scan_bar := box(rig, Vector3(-0.55, 0.245, 0.24), Vector3(0.08, 0.018, 0.02), scan_mat)
	scan_bar.name = "ScanBar"
	scan_bar.visible = false

	relay_rigs.append({
		"node": rig,
		"phase": phase,
		"lamp_mats": lamp_mats,
		"switch_arm": switch_arm,
		"port_mats": port_mats,
		"status_label": status_label,
		"scan_bar": scan_bar,
		"scan_active": false,
		"scan_time": 0.0,
	})


# game.gd 在状态变化时调用：solved/armed/patched/upload/cleared 与 game.relay_status 同语义
func update_relay_state(solved: bool, armed: bool, patched: bool, upload: float, cleared: bool) -> void:
	# 颜色常量：绿=已核验 黄=已合闸 青=已外发 蓝=上传中
	var col_idle := Color("3a4148")
	var col_solved := Color("69cdc1")   # 晨区主色
	var col_armed := Color("e79a4c")    # 暖黄
	var col_patched := Color("6df9d8")  # 亮青
	var col_upload := Color("54c9ff")   # 蓝
	for rig in relay_rigs:
		# 三盏灯：solved / armed / patched
		var targets := [col_solved if solved else col_idle, col_armed if armed else col_idle, col_patched if patched else col_idle]
		for i in range(3):
			var mat: StandardMaterial3D = rig.lamp_mats[i]
			mat.albedo_color = targets[i]
			mat.emission = targets[i]
			mat.emission_energy_multiplier = 1.6 if targets[i] != col_idle else 0.0
		# 刀开关：armed 后合闸（手柄转到水平）
		var arm: Node3D = rig.switch_arm
		arm.rotation.x = -PI / 2.2 if armed else 0.0
		# 端口：patched 后四个端口亮起
		for pm in rig.port_mats:
			var m: StandardMaterial3D = pm
			if patched:
				m.albedo_color = col_patched
				m.emission = col_patched
				m.emission_energy_multiplier = 1.2
			elif armed:
				m.albedo_color = col_armed
				m.emission = col_armed
				m.emission_energy_multiplier = 0.5
			else:
				m.albedo_color = Color("2a3036")
				m.emission = Color("0a0d10")
				m.emission_energy_multiplier = 0.0
		# 文字：复用 game.relay_status 的语义（精简版）
		var label: Label3D = rig.status_label
		if cleared:
			label.text = "ACK OK"
			label.modulate = col_patched
		elif upload > 0.0:
			label.text = "TX %.1fs" % upload
			label.modulate = col_upload
		elif patched:
			label.text = "LINKED"
			label.modulate = col_patched
		elif armed:
			label.text = "ARMED"
			label.modulate = col_armed
		elif solved:
			label.text = "VERIFIED"
			label.modulate = col_solved
		else:
			label.text = "IDLE"
			label.modulate = Color("a7dcd0")
		# 上传扫描条
		rig.scan_active = upload > 0.0
		rig.scan_bar.visible = rig.scan_active
		rig.scan_time = 0.0


# 由 game._physics_process 调用，驱动上传扫描条扫动
func animate_relay(delta: float) -> void:
	for rig in relay_rigs:
		if rig.scan_active:
			rig.scan_time += delta
			var t: float = fmod(rig.scan_time * 1.6, 1.0)
			rig.scan_bar.position.x = -0.55 + t * 1.10


func build_witness(layer: Node3D, center: Vector3) -> void:
	var figure := Node3D.new()
	layer.add_child(figure)
	figure.position = center + Vector3(1.08, 0, 0.73)
	figure.rotation.y = -1.55
	var model: Node3D = preload("res://assets/characters/lin_cen/lincen.glb").instantiate()
	model.name = "LinCenModel"
	model.rotation.y = PI
	figure.add_child(model)
	witnesses.append(figure)


func update_witness(chapter: int, seen: bool, approved: bool) -> void:
	set_stage(STORY_STEP.get(chapter, 1))
	witnesses[0].visible = chapter == 0 and not seen
	witnesses[1].visible = chapter < 2
	var alive := chapter == 1 and not approved
	# The baked mesh extends 0.1945 m forward, which becomes its lowest point when prone.
	witnesses[1].position = point(OFFICE) + Vector3(1.08, 0.0 if alive else 0.20, 0.42)
	witnesses[1].rotation = Vector3(0.0 if alive else -PI / 2.0, -1.55 if alive else 0.0, 0.0)


func axes(outward: Vector3, depth: float, height: float, width: float) -> Vector3:
	return Vector3(depth, height, width) if absf(outward.x) > 0.5 else Vector3(width, height, depth)


func material(color: Color, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.metallic = metallic
	surface.roughness = 0.47
	if emission > 0:
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = emission
	return surface


func alloy(color: Color) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://station_alloy.gdshader")
	surface.set_shader_parameter("finish", color)
	return surface


func display_surface(color: Color) -> ShaderMaterial:
	var screen := ShaderMaterial.new()
	screen.shader = preload("res://instrument_display.gdshader")
	screen.set_shader_parameter("phosphor", color)
	return screen


func box(parent: Node3D, pos: Vector3, size: Vector3, surface: Material, collision := false) -> MeshInstance3D:
	if not box_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		box_meshes[size] = mesh
	var instance := MeshInstance3D.new()
	instance.mesh = box_meshes[size]
	instance.material_override = surface
	parent.add_child(instance)
	instance.position = pos
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		body.add_child(shape)
		instance.add_child(body)
	return instance


func sign_at(parent: Node3D, pos: Vector3, caption: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 46
	label.pixel_size = 0.0032
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position = pos
	return label


func breaks_for(phase: int) -> Array:
	return BREAKS_MORNING if phase == 0 else BREAKS_DUSK


func build_breaks(phase: int) -> void:
	var wall: Material = palette.ceramic if phase == 0 else palette.dark
	var accent: StandardMaterial3D = palette.red
	for entry in breaks_for(phase):
		var group: Array[Node3D] = []
		for tile in entry.tiles:
			var center := point(tile)
			var block := Node3D.new()
			block.name = "Break_%s_%d_%d" % [entry.name, tile.x, tile.y]
			maps[phase].add_child(block)
			block.position = center
			box(block, Vector3(0, 1.51, 0), Vector3(3.9, 3.02, 3.9), wall, true)
			box(block, Vector3(0, 1.51, 1.96), Vector3(3.2, 0.06, 0.02), accent)
			box(block, Vector3(0, 1.51, -1.96), Vector3(3.2, 0.06, 0.02), accent)
			box(block, Vector3(1.96, 1.51, 0), Vector3(0.02, 0.06, 3.2), accent)
			box(block, Vector3(-1.96, 1.51, 0), Vector3(0.02, 0.06, 3.2), accent)
			group.append(block)
		barriers[phase].append(group)
	apply_breaks(phase)


func set_stage(stage: int) -> void:
	if stage == map_stage:
		return
	map_stage = stage
	for phase in range(maps.size()):
		apply_breaks(phase)
	for arrow in return_arrows:
		arrow.queue_free()
	for label in return_signs:
		label.queue_free()
	return_arrows.clear()
	return_signs.clear()
	for phase in range(maps.size()):
		build_return_markers(phase)


func apply_breaks(phase: int) -> void:
	var entries: Array = breaks_for(phase)
	for index in range(entries.size()):
		var active: bool = map_stage >= int(entries[index].stage)
		for tile in entries[index].tiles:
			if active:
				closed[phase][tile] = true
			else:
				closed[phase].erase(tile)
			grids[phase].set_point_solid(tile, active)
		for block in barriers[phase][index]:
			block.visible = active
			for body in block.find_children("*", "StaticBody3D", true, false):
				body.collision_layer = 1 if active else 0
