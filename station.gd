extends Node3D

const CELL := 4.0
const MAP_SIZE := Vector2i(15, 11)
const MORNING := [
	"###############", "#A...........O#", "#.####.########", "#G..C...R....H#",
	"#.##..#..####.#", "#...D...L.....#", "#.#..#..#...#.#", "#...#.....#...#",
	"#.###.###.###.#", "#.............#", "###############",
]
const DUSK := [
	"###############", "#A....#......O#", "#.####.######.#", "#G..C...R....H#",
	"#.##..#..####.#", "#...D...L.....#", "#.#..#..#...#.#", "#...#.....#...#",
	"#.###.###.###.#", "#.............#", "###############",
]
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const AUDIT := Vector2i(1, 1)
const OFFICE := Vector2i(13, 1)
const RELAY := Vector2i(8, 3)
const LAB := Vector2i(4, 3)
const MEDICAL := Vector2i(4, 5)
const LEDGER := Vector2i(8, 5)
const GATES := [Vector2i(1, 3), Vector2i(13, 3)]
const RETURN_MARKERS := [Vector2i(13,1), Vector2i(12,3), Vector2i(2,3), Vector2i(4,3), Vector2i(8,3), Vector2i(4,5), Vector2i(8,5), Vector2i(1,9), Vector2i(13,9)]
const AUDIT_MONITOR_SCENE := preload("res://assets/props/a01/SM_A01_Monitor.glb")

var maps: Array[Node3D] = []
var grids: Array[AStarGrid2D] = []
var palette := {}
var markers: Array[Label3D] = []
var witnesses: Array[Node3D] = []
var box_meshes: Dictionary = {}
var instruments: Array[Node3D] = []
var observation_glass: ShaderMaterial
var audit_labels: Array[Label3D] = []
var return_signs: Array[Label3D] = []
var use_audit_monitor_prop := true


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
		build_return_markers(phase)
	set_phase(0)


func return_hint(phase: int, tile: Vector2i) -> Dictionary:
	var target: Vector2i = AUDIT
	var label := "A-01 / 回调查台"
	if phase == 1:
		var west: Array[Vector2i] = path(phase, tile, GATES[0])
		var east: Array[Vector2i] = path(phase, tile, GATES[1])
		var gate := 1 if west.is_empty() or (not east.is_empty() and east.size() < west.size()) else 0
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
	return rows[tile.y][tile.x] != "#"


func point(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * CELL, 0, tile.y * CELL)


func cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))


func path(phase: int, origin: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	if not walkable(phase, origin) or not walkable(phase, destination):
		return []
	return grids[phase].get_id_path(origin, destination)


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
	var active_light := (tile.x + tile.y) % 4 != 0 or tile in [AUDIT, OFFICE, LAB, RELAY]
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
				box(layer, edge + sideways * 1.87 * sign_value + Vector3.UP * 1.49, Vector3(0.23, 2.98, 0.23), palette.frame)
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
	if tile.y == 1 and outward == Vector3.FORWARD:
		observation_window(layer, edge, sideways, wall, phase)
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
		var gate_name := "G-01" if tile == GATES[0] else "G-02"
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


func update_audit_status(text: String) -> void:
	for label in audit_labels:
		label.text = text

func build_witness(layer: Node3D, center: Vector3) -> void:
	var figure := Node3D.new()
	layer.add_child(figure)
	figure.position = center + Vector3(1.08, 0, 0.73)
	figure.rotation.y = -1.55
	box(figure, Vector3(0, 1.22, 0), Vector3(0.54, 0.62, 0.31), palette.suit)
	box(figure, Vector3(0, 1.68, 0), Vector3(0.32, 0.31, 0.29), palette.frame)
	box(figure, Vector3(0, 1.70, -0.153), Vector3(0.27, 0.14, 0.026), palette.visor)
	box(figure, Vector3(0.10, 1.32, -0.166), Vector3(0.10, 0.08, 0.026), palette.blue)
	for side in [-1, 1]:
		box(figure, Vector3(side * 0.33, 1.16, 0.03), Vector3(0.17, 0.66, 0.22), palette.suit)
		box(figure, Vector3(side * 0.145, 0.45, 0), Vector3(0.24, 0.90, 0.25), palette.suit)
	witnesses.append(figure)


func update_witness(chapter: int, seen: bool, approved: bool) -> void:
	witnesses[0].visible = chapter == 0 and not seen
	witnesses[1].visible = chapter < 2
	var alive := chapter == 1 and not approved
	witnesses[1].position = point(OFFICE) + Vector3(1.08, 0.0 if alive else 0.17, 0.42)
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
