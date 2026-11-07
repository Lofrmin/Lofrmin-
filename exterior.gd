extends Node3D

const OrbitalStructure := preload("res://orbital_structure.gd")
const ORIGIN := Vector3(210, 0, 0)
const SUN := Vector3(0.80, 0.47, 0.37)

var orbit: Camera3D
var habitat: Node3D
var opening_earth: MeshInstance3D
var window_earth: MeshInstance3D
var window_moon: MeshInstance3D
var key_light: DirectionalLight3D


func build(environment: Environment) -> void:
	var assembly := Node3D.new()
	add_child(assembly)
	assembly.position = ORIGIN
	assembly.rotation_degrees = Vector3(32, 0, -18)
	habitat = OrbitalStructure.new()
	assembly.add_child(habitat)
	habitat.build()

	var surface := ShaderMaterial.new()
	surface.shader = preload("res://earth.gdshader")
	surface.set_shader_parameter("surface_map", preload("res://assets/orbit/earth.jpg"))
	surface.set_shader_parameter("cloud_map", preload("res://assets/orbit/clouds.png"))
	var opening_surface := surface.duplicate() as ShaderMaterial
	opening_surface.set_shader_parameter("sun_direction", SUN)
	opening_earth = planet(ORIGIN + Vector3(-4.4, -13.0, -27.0), 22.5, opening_surface)
	# Center the orbital backdrop on the expanded 41x41 station.
	window_earth = planet(Vector3(80, -112, -360), 180.0, surface)
	window_earth.hide()
	var lunar_surface := ShaderMaterial.new()
	lunar_surface.shader = preload("res://moon.gdshader")
	window_moon = planet(Vector3(260, 38, -310), 24.0, lunar_surface)
	window_moon.hide()

	key_light = DirectionalLight3D.new()
	key_light.light_color = Color("f9efe0")
	key_light.light_energy = 2.24
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.018
	key_light.directional_shadow_max_distance = 63.0
	add_child(key_light)
	key_light.look_at_from_position(ORIGIN + SUN * 30.0, ORIGIN)

	orbit = Camera3D.new()
	orbit.fov = 43
	var cinematic := environment.duplicate() as Environment
	# A little reflected earthlight retains detail in the station's shadow side.
	cinematic.ambient_light_color = Color("afc1cc")
	cinematic.ambient_light_energy = 0.22
	cinematic.ssao_radius = 0.68
	cinematic.ssao_intensity = 1.42
	orbit.environment = cinematic
	add_child(orbit)
	orbit.make_current()
	animate(0.0)


func planet(at: Vector3, radius: float, surface: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 144
	sphere.rings = 72
	var body := MeshInstance3D.new()
	body.mesh = sphere
	body.material_override = surface
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	body.position = at
	body.rotation.z = -0.22
	return body


func animate(seconds: float) -> void:
	var angle := 0.29 + seconds * 0.0065
	var radius := 25.2 - minf(seconds, 27.0) * 0.068
	orbit.position = ORIGIN + Vector3(radius * sin(angle), 13.9, radius * cos(angle))
	orbit.look_at(ORIGIN + Vector3(-3.60, -0.05, 0.0), Vector3.UP)
	habitat.rotation.y = -0.16 + seconds * 0.019
	opening_earth.rotation.y = -0.90 + seconds * 0.035


func animate_window(delta: float) -> void:
	window_earth.rotation.y = fposmod(window_earth.rotation.y + delta * 0.021, TAU)


func finish() -> void:
	habitat.hide()
	opening_earth.hide()
	key_light.hide()
	window_earth.rotation.y = opening_earth.rotation.y
	window_earth.show()
	window_moon.show()
