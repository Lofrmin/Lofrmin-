extends SceneTree

var failures := 0
var checks := 0
var station: Node3D
var exterior: Node3D
var camera: Camera3D

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	station = load("res://station.gd").new()
	station.use_audit_monitor_prop = false
	root.add_child(station)
	station.build()
	for phase in range(2):
		var count := 0
		var orientations := {}
		var rows: Array = station.MORNING if phase == 0 else station.DUSK
		for z in range(station.MAP_SIZE.y):
			for x in range(station.MAP_SIZE.x):
				var tile := Vector2i(x, z)
				if not station.walkable(phase, tile): continue
				for direction in station.DIRECTIONS:
					var neighbor: Vector2i = tile + direction
					if station.walkable(phase, neighbor): continue
					# Independently classify the hull by an unobstructed ray to space.
					var cursor: Vector2i = neighbor
					var reaches_space := true
					while Rect2i(Vector2i.ZERO, station.MAP_SIZE).has_point(cursor):
						if rows[cursor.y][cursor.x] != "#":
							reaches_space = false
							break
						cursor += direction
					var label := "OuterWindow_%d_%d_%d_%d" % [x, z, direction.x, direction.y]
					var window: Node3D = station.maps[phase].get_node_or_null(label)
					if reaches_space:
						check(window != null, "outward-facing hull has glass " + label)
					if window == null: continue
					count += 1
					orientations[direction] = true
					var outward := Vector3(direction.x, 0, direction.y)
					check((-window.basis.z).is_equal_approx(outward), "glass faces correct direction")
					var collision_mesh: MeshInstance3D = window.get_child(0)
					check(not collision_mesh.visible and collision_mesh.get_child(0) is StaticBody3D,
						"transparent hull retains solid collision")
					var pane: MeshInstance3D = window.get_child(window.get_child_count() - 1)
					check(pane.mesh is QuadMesh and pane.material_override == station.observation_glass,
						"uses reference transparent glass")
		check(count > 100 and orientations.size() == 4, "continuous glass around all four sides")
		check(not station.exterior_cells[phase].has(Vector2i(20, 15)), "inner ring wall stays opaque")
		print("PHASE %d: %d exterior windows, %d orientations" % [phase, count, orientations.size()])
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://orbit_sky.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5dde1")
	environment.ambient_light_energy = 0.49
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	exterior = load("res://exterior.gd").new()
	root.add_child(exterior)
	exterior.build(environment)
	check(not exterior.window_moon.visible, "moon hidden during opening")
	exterior.finish()
	check(exterior.window_moon.visible and exterior.window_earth.visible, "earth and moon visible in gameplay")
	check(not exterior.opening_earth.visible and not exterior.habitat.visible, "opening geometry hidden")
	await physics_frame
	for phase in range(2):
		station.set_phase(phase)
		await physics_frame
		for entry in [[Vector2i(20,1), Vector3.FORWARD], [Vector2i(20,39), Vector3.BACK], [Vector2i(1,20), Vector3.LEFT], [Vector2i(39,20), Vector3.RIGHT]]:
			var origin: Vector3 = station.point(entry[0]) + Vector3.UP * 1.56
			var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + entry[1] * 3.0))
			check(not hit.is_empty(), "player cannot cross outer glass in either phase")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		root.size = Vector2i(1280,720)
		camera = Camera3D.new()
		camera.fov = 78
		root.add_child(camera)
		camera.make_current()
		var output := OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(output)
		for phase in range(2):
			station.set_phase(phase)
			for entry in [["north", Vector2i(22,1), Vector3(150,1.56,-360)], ["east", Vector2i(39,20), Vector3(500,1.56,80)], ["south", Vector2i(20,39), Vector3(80,1.56,500)], ["west", Vector2i(1,20), Vector3(-500,1.56,80)]]:
				camera.position = station.point(entry[1]) + Vector3.UP * 1.56
				camera.look_at(entry[2])
				await create_timer(0.4).timeout
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("outer-%s-%d.png" % [entry[0], phase])) == OK, "save screenshot")
	print("OUTER_WINDOWS_CHECK: %d checks / %d failures" % [checks, failures])
	station.free()
	exterior.free()
	quit(1 if failures else 0)
