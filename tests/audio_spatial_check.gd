extends SceneTree

var failed := false
var capture: AudioEffectCapture
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func measure(position: Vector3) -> Vector2:
	game.boss.position = position
	capture.clear_buffer()
	game.sound.cue("warning")
	await create_timer(0.75).timeout
	var buffer := capture.get_buffer(capture.get_frames_available())
	var energy := Vector2.ZERO
	for sample in buffer:
		energy += Vector2(sample.x * sample.x, sample.y * sample.y)
	return energy

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Requires rendering and a real audio driver")
		quit(1)
		return
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.camera.global_position = Vector3(0,1.56,0)
	game.camera.global_rotation = Vector3.ZERO
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "SpatialTest")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	# Capture before attenuation, keeping this automated test almost inaudible.
	AudioServer.set_bus_volume_db(bus, -60.0)
	game.sound.cues.warning.bus = "SpatialTest"
	await create_timer(0.2).timeout
	var left: Vector2 = await measure(Vector3(-4,0,-4))
	var right: Vector2 = await measure(Vector3(4,0,-4))
	var far: Vector2 = await measure(Vector3(0,0,-30))
	failed = left.x <= left.y * 1.1 or right.y <= right.x * 1.1 or left.length_squared() < 0.000001 or far.length_squared() > minf(left.length_squared(), right.length_squared()) * 0.001
	print("SPATIAL_ENERGY: left=%s right=%s far=%s" % [left,right,far])
	game.free()
	AudioServer.remove_bus(bus)
	await process_frame
	print("AUDIO_SPATIAL_TEST: " + ("FAIL" if failed else "PASS / left-right panning and range"))
	quit(1 if failed else 0)
