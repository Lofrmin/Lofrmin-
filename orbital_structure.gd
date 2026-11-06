extends Node3D

enum Finish { STRUCTURE, STEEL, ALLOY, CERAMIC, COPPER, GLASS, SAFETY, LAMP }

var surfaces: Array[Material] = []
var batches: Array = []
var random := RandomNumberGenerator.new()


func build() -> void:
	random.seed = 43017
	finish(Color("34393a"), 0.72, 0.53)
	finish(Color("666c6d"), 0.73, 0.39)
	finish(Color("969b98"), 0.58, 0.48)
	finish(Color("c2bdb0"), 0.26, 0.55)
	finish(Color("73604a"), 0.55, 0.50)
	finish(Color("273237"), 0.62, 0.28)
	finish(Color("a16e37"), 0.19, 0.60)
	finish(Color("afdadb"), 0.0, 0.33, 0.68)
	build_hub()
	build_ring(3.25, -0.86, 44, 0.56)
	build_ring(5.26, -0.59, 60, 0.83)
	build_ring(7.66, -0.20, 84, 1.17)
	build_ring(9.12, 0.62, 88, 0.75)
	build_conduit_arc(6.70, -0.60, -0.70, 2.06)
	build_conduit_arc(8.45, -0.33, 2.10, 5.40)
	build_conduit_arc(4.18, -0.43, 3.81, 5.90)
	for index in range(9):
		build_spoke(TAU * index / 9.0 + 0.14, index)
	build_docks(1.96, 6.68, 1.18)
	build_docks(3.91, 8.26, 0.72)
	build_docks(5.15, 6.34, 1.20)
	for angle in [0.36, 1.85, 3.55, 5.32]:
		build_array(angle)
	build_boom(0.91, 14.4, 4.6)
	build_boom(2.72, 15.7, 5.2)
	build_boom(4.58, 13.6, 2.6)
	build_boom(5.65, 16.6, 4.3)
	commit()


func build_hub() -> void:
	drum(1.95, -0.84, 1.65, Finish.STRUCTURE)
	drum(1.40, 0.07, 1.36, Finish.ALLOY)
	drum(0.88, 0.82, 0.71, Finish.STEEL)
	drum(0.63, 1.19, 0.18, Finish.STRUCTURE)
	drum(0.40, 1.31, 0.15, Finish.GLASS)
	for index in range(24):
		var angle := TAU * index / 24.0
		place(Finish.STEEL, angle, 1.74, 0.04, 0.0, Vector3(0.40, 1.15, 0.12))
		place(Finish.ALLOY, angle, 1.25, 0.80, 0.0, Vector3(0.44, 0.12, 0.14))
		if index % 4 == 0:
			place(Finish.CERAMIC, angle, 2.18, 0.20, 0.0, Vector3(0.91, 0.38, 0.59))
			place(Finish.SAFETY, angle, 2.39, 0.41, 0.0, Vector3(0.20, 0.02, 0.42))


func build_ring(radius: float, level: float, segments: int, breadth: float) -> void:
	var step := TAU / segments
	var length := radius * step
	for index in range(segments):
		var angle := index * step
		var exterior := radius > 8.0
		var unfinished := exterior and index >= 33 and index < 42
		var side_r := radius + breadth * 0.41
		for side in [-1.0, 1.0]:
			var edge_r: float = radius + side * breadth * 0.43
			var rail := Finish.ALLOY if side > 0.0 else Finish.STEEL
			for height in [-0.24, 0.31]:
				var start := polar(angle - step * 0.5, edge_r, level + height)
				var end := polar(angle + step * 0.5, edge_r, level + height)
				beam(rail, start, end, 0.063, 0.076)
			beam(Finish.STEEL, polar(angle - step * 0.5, edge_r, level - 0.23), polar(angle + step * 0.5, edge_r, level + 0.31), 0.044)
			place(Finish.ALLOY, angle - step * 0.5, edge_r, level + 0.04, 0.0, Vector3(0.082, 0.57, 0.069))
		if unfinished or index % 11 == 4:
			place(Finish.STRUCTURE, angle, radius, level - 0.23, 0.0, Vector3(breadth, 0.08, length * 0.9))
			continue
		var skin := Finish.CERAMIC if index % 9 in [0, 1, 2, 7] else (Finish.COPPER if index % 9 in [4, 5] else Finish.ALLOY)
		var height := random.randf_range(0.34, 0.57)
		place(Finish.STRUCTURE, angle, radius, level - 0.12, 0.0, Vector3(breadth * 0.86, 0.39, length * 0.91))
		place(skin, angle, radius, level + 0.03, 0.0, Vector3(breadth * 0.71, height, length * random.randf_range(0.68, 0.91)))
		for detail in range(4):
			var along := length * (-0.29 + detail * 0.19)
			place(Finish.STEEL, angle, radius, level + 0.04 + height * 0.5, along, Vector3(breadth * random.randf_range(0.18, 0.65), 0.044, 0.035))
			place(Finish.GLASS, angle, side_r, level + 0.07, along, Vector3(0.033, 0.079, 0.055))
		if index % 4 == 0:
			place(Finish.ALLOY, angle, side_r + 0.12, level + 0.33, 0.0, Vector3(0.31, 0.13, length * 0.45))
			place(Finish.LAMP, angle, side_r + 0.25, level + 0.36, 0.0, Vector3(0.07, 0.033, 0.055))
		if index % 7 == 0:
			place(Finish.STRUCTURE, angle, radius - breadth * 0.12, level + height * 0.58, length * 0.15, Vector3(0.31, 0.12, 0.24))
			place(Finish.SAFETY, angle, radius - breadth * 0.14, level + height * 0.58 + 0.064, length * 0.15, Vector3(0.16, 0.014, 0.10))
		if index % 5 == 1:
			place(Finish.GLASS, angle, radius + breadth * 0.19, level + height * 0.47 + 0.079, 0.0, Vector3(0.20, 0.055, length * 0.58))
			for rivet in range(3):
				place(Finish.ALLOY, angle, radius + breadth * 0.23, level + height * 0.47 + 0.116, (rivet - 1) * length * 0.17, Vector3(0.13, 0.028, 0.026))


func build_conduit_arc(radius: float, height: float, begin: float, end: float) -> void:
	var segments := int(ceil(radius * (end - begin) / 0.39))
	for index in range(segments):
		var start := lerpf(begin, end, float(index) / segments)
		var next := lerpf(begin, end, float(index + 1) / segments)
		for line in range(3):
			var r := radius + line * 0.107
			var level := height + line * 0.080
			beam(Finish.STEEL if line < 2 else Finish.COPPER, polar(start, r, level), polar(next, r, level), 0.079 - line * 0.011)
		if index % 3 == 0:
			place(Finish.ALLOY, start, radius + 0.11, height + 0.062, 0.0, Vector3(0.40, 0.25, 0.09))


func build_docks(angle: float, radius: float, width: float) -> void:
	place(Finish.STRUCTURE, angle, radius, 0.27, 0.0, Vector3(1.86, 0.59, width * 1.81))
	place(Finish.ALLOY, angle, radius - 0.34, 0.67, 0.0, Vector3(1.06, 0.42, width * 1.65))
	place(Finish.GLASS, angle, radius + 0.48, 0.76, 0.0, Vector3(0.61, 0.19, width * 1.31))
	for side in [-1.0, 1.0]:
		place(Finish.CERAMIC, angle, radius + 0.22, 0.75, side * width * 0.64, Vector3(1.23, 0.45, 0.39))
		place(Finish.STEEL, angle, radius - 0.24, 1.02, side * width * 0.64, Vector3(0.61, 0.16, 0.29))
		for index in range(6):
			place(Finish.STRUCTURE, angle, radius - 0.21 + index * 0.16, 1.0, side * width * 0.70, Vector3(0.033, 0.06, 0.35))
		beam(Finish.COPPER, polar(angle, radius - 0.86, 0.35, side * width * 0.94), polar(angle, radius + 0.91, 0.72, side * width * 0.94), 0.07)


func build_spoke(angle: float, index: int) -> void:
	var width := 0.54 if index % 3 == 0 else 0.31
	for section in range(12):
		var r := 1.50 + section * 0.61
		var y := -0.69 + section * 0.079
		for side in [-1.0, 1.0]:
			for height in [-0.24, 0.24]:
				beam(Finish.STEEL, polar(angle, r, y + height, width * side), polar(angle, r + 0.62, y + height + 0.08, width * side), 0.068)
			beam(Finish.ALLOY, polar(angle, r, y - 0.23, width * side), polar(angle, r + 0.62, y + 0.32, width * side), 0.045)
		beam(Finish.STEEL, polar(angle, r, y + 0.23, -width), polar(angle, r + 0.60, y + 0.32, width), 0.055)
		if section % 2 == 0:
			place(Finish.STRUCTURE, angle, r + 0.28, y, 0.0, Vector3(0.53, 0.26, width * 1.35))
		if section % 4 == 0:
			place(Finish.CERAMIC, angle, r + 0.34, y + 0.42, 0.0, Vector3(0.70, 0.30, width * 2.12))
			place(Finish.GLASS, angle, r + 0.38, y + 0.58, 0.0, Vector3(0.26, 0.02, width * 1.31))


func build_boom(angle: float, reach: float, tip_height: float) -> void:
	place(Finish.ALLOY, angle, 8.83, 0.99, 0.0, Vector3(1.43, 0.65, 1.52))
	place(Finish.STRUCTURE, angle, 8.83, 1.34, 0.0, Vector3(0.68, 0.16, 0.98))
	for segment in range(9):
		var progress := float(segment) / 9.0
		var next := float(segment + 1) / 9.0
		var r := lerpf(8.82, reach, progress)
		var r_next := lerpf(8.82, reach, next)
		var y := lerpf(1.04, tip_height, progress)
		var y_next := lerpf(1.04, tip_height, next)
		for side in [-1.0, 1.0]:
			var width: float = lerpf(0.43, 0.16, progress) * side
			var next_width: float = lerpf(0.43, 0.16, next) * side
			for height in [-0.21, 0.21]:
				beam(Finish.STEEL, polar(angle, r, y + height, width), polar(angle, r_next, y_next + height, next_width), 0.076)
			beam(Finish.ALLOY, polar(angle, r, y - 0.19, width), polar(angle, r_next, y_next + 0.21, next_width), 0.047)
		beam(Finish.STRUCTURE, polar(angle, r, y + 0.25, -0.30), polar(angle, r_next, y_next + 0.25, 0.30), 0.039)
	place(Finish.CERAMIC, angle, reach, tip_height, 0.0, Vector3(0.48, 0.52, 0.64))
	place(Finish.SAFETY, angle, reach + 0.19, tip_height + 0.27, 0.0, Vector3(0.32, 0.026, 0.47))
	beam(Finish.STRUCTURE, polar(angle, 8.81, 1.35, 0.54), polar(angle, reach, tip_height + 0.46, 0.12), 0.024)


func build_array(angle: float) -> void:
	beam(Finish.STEEL, polar(angle, 8.75, -0.41), polar(angle, 12.06, -0.51), 0.13)
	for side in [-1.0, 1.0]:
		for index in range(9):
			var r := 9.91 + index * 0.23
			place(Finish.COPPER, angle, r, -0.54, side * 0.58, Vector3(0.205, 0.045, 1.04))
			place(Finish.GLASS, angle, r, -0.509, side * 0.58, Vector3(0.171, 0.017, 0.86))
			place(Finish.STEEL, angle, r, -0.494, side * 0.90, Vector3(0.18, 0.015, 0.018))


func finish(color: Color, metallic: float, roughness: float, emission := 0.0) -> void:
	if emission > 0.0:
		var surface := StandardMaterial3D.new()
		surface.albedo_color = color
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = emission
		surfaces.append(surface)
	else:
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://orbital_finish.gdshader")
		surface.set_shader_parameter("finish_color", color)
		surface.set_shader_parameter("finish_metal", metallic)
		surface.set_shader_parameter("finish_roughness", roughness)
		surfaces.append(surface)
	batches.append([])


func polar(angle: float, radius: float, height: float, tangent := 0.0) -> Vector3:
	return Vector3(cos(angle), 0, sin(angle)) * radius + Vector3(-sin(angle), 0, cos(angle)) * tangent + Vector3.UP * height


func place(surface: int, angle: float, radius: float, height: float, tangent: float, size: Vector3) -> void:
	batches[surface].append(Transform3D(Basis(Vector3.UP, -angle).scaled_local(size), polar(angle, radius, height, tangent)))


func beam(surface: int, start: Vector3, end: Vector3, thickness: float, vertical := 0.0) -> void:
	var offset := end - start
	var basis := Basis.looking_at(offset, Vector3.UP)
	var section := Vector3(thickness, vertical if vertical > 0.0 else thickness, offset.length() + 0.018)
	batches[surface].append(Transform3D(basis.scaled_local(section), start.lerp(end, 0.5)))


func drum(radius: float, level: float, height: float, surface: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.96
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = surfaces[surface]
	add_child(piece)
	piece.position.y = level


func commit() -> void:
	var cube := BoxMesh.new()
	for surface in range(batches.size()):
		var parts: Array = batches[surface]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = cube
		batch.instance_count = parts.size()
		for index in range(parts.size()):
			batch.set_instance_transform(index, parts[index])
		var rendered := MultiMeshInstance3D.new()
		rendered.multimesh = batch
		rendered.material_override = surfaces[surface]
		add_child(rendered)
