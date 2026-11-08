extends SceneTree

const START := Vector3(-100, 0.05, -100)
const DT := 1.0 / 60.0
var game: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func box_at(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.position = center
	return body

func tick(count: int) -> void:
	for i in range(count):
		await physics_frame
		game.tick_game_physics(DT)

func place_player() -> void:
	game.reset_lap("test arena")
	game.player.position = START
	game.player.rotation.y = 0.0
	await tick(12)

func chase(sprint: bool) -> Vector2:
	await place_player()
	game.phase = 1
	game.station.set_phase(1)
	game.boss_phase = 1
	game.boss_live = true
	game.boss.position = Vector3(START.x, 0, START.z + 4.0)
	game.boss_delay = 0.0
	var lap: int = game.laps
	key(KEY_W, true)
	key(KEY_SHIFT, sprint)
	var t := 0.0
	var gap_at_four := 0.0
	for i in range(540):
		await tick(1)
		t += DT
		if i == 239: gap_at_four = game.boss.position.distance_to(game.player.position)
		if game.laps != lap: break
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	print("CHASE_MOVEMENT sprint=", sprint, " t=", t, " caught=", game.laps != lap, " gap_at_4s=", gap_at_four)
	return Vector2(t, gap_at_four)

func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	# Isolated corridor uses the actual player body, keyboard input and game physics.
	var floor_body := box_at(START + Vector3(0,-0.55,-45), Vector3(20,1,150))
	await place_player()
	key(KEY_SHIFT, true)
	await tick(30)
	check(game.stamina == 100.0 and not game.actual_sprinting, "standing Shift does not drain")
	key(KEY_W, true)
	var start: Vector3 = game.player.position
	await tick(60)
	check(absf(start.distance_to(game.player.position) - 6.25) < 0.10, "physical sprint speed")
	check(absf(game.stamina - 75.0) < 0.5 and game.actual_sprinting, "one second of physical sprint drains 25")
	await tick(180)
	check(game.stamina <= 0.01 and game.stamina_exhausted, "physical sprint exhausts after four seconds")
	start = game.player.position
	await tick(60)
	check(absf(start.distance_to(game.player.position) - 4.45) < 0.10, "exhaustion physically reduces speed")
	check(is_zero_approx(game.stamina) and not game.actual_sprinting, "held Shift cannot bypass delay or emit sprint")
	await tick(120)
	check(game.stamina >= 25.0 and game.stamina_exhausted, "held Shift cannot auto-unlock")
	key(KEY_SHIFT, false)
	await tick(1)
	key(KEY_SHIFT, true)
	await tick(2)
	check(game.actual_sprinting, "release and press re-enables sprint above threshold")
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	await place_player()
	var wall := box_at(START + Vector3(0,0.9,-0.9), Vector3(6,2,0.25))
	await tick(2)
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await tick(20)
	var before: float = game.stamina
	await tick(30)
	check(game.stamina == before and not game.actual_sprinting, "sustained wall contact does not consume stamina")
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	wall.free()
	var walk := await chase(false)
	var sprint := await chase(true)
	check(walk.x < 8.0, "uninterrupted walking is caught in a straight corridor")
	check(sprint.x > walk.x and sprint.y > 4.0, "short sprint provides a real escape window")
	floor_body.free()
	game.free()
	await process_frame
	print("STAMINA_RUNTIME: %d checks / %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
