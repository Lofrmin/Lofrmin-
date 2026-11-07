extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func place(game: Node3D, hunter: Vector3, target: Vector3) -> void:
	game.set_mode("world")
	game.phase = 1
	game.station.set_phase(1)
	game.boss_phase = 1
	game.boss_live = true
	game.boss.position = hunter
	game.player.position = target + Vector3.UP * 0.05
	game.boss_delay = 0.0
	game.dusk_grace = 0.0
	game.stunned = 0.0
	game.charge_warning = 0.0
	game.charge_time = 0.0
	game.charge_recovery = 100.0
	game.tracking_time = 3.0
	game.last_known = game.station.cell(target)
	game.boss_route.clear()
	game.path_timer = 0.0
	game.upload = 0.0
	game.dev_god = false

func obstacle(game: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	game.add_child(body)
	body.position = center
	return body

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	var tile := Vector2i(20, 19)
	var center: Vector3 = game.station.point(tile)
	place(game, center, center + Vector3(1.45, 0, 1.45))
	await physics_frame
	check(game.has_sight(), "off-center reproduction has line of sight")
	var before: Vector3 = game.boss.position
	var lap: int = game.laps
	game.update_boss(0.1, false)
	check(game.boss.position.x > before.x + 0.1 and game.boss.position.z > before.z + 0.1, "visible player is pursued diagonally, not via tile center")
	for i in range(15):
		await physics_frame
		if game.laps != lap: break
		game.update_boss(0.1, false)
	check(game.laps > lap, "stationary player near a tile corner can be caught")

	place(game, center, center + Vector3(1.5, 0, 1.4))
	game.dev_god = true
	game.boss_route.append(tile + Vector2i.LEFT)
	game.path_timer = 0.3
	await physics_frame
	game.update_boss(0.1, false)
	check(game.boss.position.x > center.x and game.boss.position.z > center.z, "visible target overrides a stale route")
	game.player.position = center + Vector3(-1.5, 0.05, 1.4)
	before = game.boss.position
	await physics_frame
	game.update_boss(0.1, false)
	check(game.boss.position.x < before.x, "pursuit follows movement inside the same tile")

	var wall := obstacle(game, center + Vector3(0, 1.5, 0), Vector3(0.12, 3, 3))
	place(game, center + Vector3(-0.45, 0, 0), center + Vector3(0.45, 0, 0))
	await physics_frame
	check(not game.has_sight(), "thin wall blocks sight")
	lap = game.laps
	for i in range(12):
		await physics_frame
		game.update_boss(0.1, false)
	check(game.laps == lap, "hunter never catches through a thin wall")
	check(game.boss.position.x < center.x - 0.30, "hunter body does not cross the wall")
	place(game, center + Vector3(-1.7, 0, 0.7), center + Vector3(-0.362, 0, 0.7))
	await physics_frame
	check(game.has_sight(), "wall-hugging player on the same side remains visible")
	lap = game.laps
	for i in range(15):
		await physics_frame
		if game.laps != lap: break
		game.update_boss(0.1, false)
	check(game.laps > lap, "player collision margin at a wall cannot make pursuit stop")
	wall.free()

	var desk := obstacle(game, center + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.2))
	place(game, center + Vector3(-1.6, 0, 0), center + Vector3(1.6, 0, 0))
	await physics_frame
	check(game.has_sight(), "low obstacle allows eye-level sight")
	lap = game.laps
	var penetrated := false
	for i in range(80):
		await physics_frame
		if game.laps != lap: break
		game.update_boss(0.1, false)
		if game.laps != lap: break
		var gap := Vector2(maxf(absf(game.boss.position.x - center.x) - 0.4, 0.0), maxf(absf(game.boss.position.z - center.z) - 0.6, 0.0))
		penetrated = penetrated or gap.length() < 0.29
	check(not penetrated, "direct chase respects obstacles below eye height")
	check(game.laps > lap, "hunter walks around low furniture and reaches an off-center player")
	desk.free()

	var blocked := tile + Vector2i.RIGHT
	var blocker: Vector3 = game.station.point(blocked)
	wall = obstacle(game, blocker + Vector3.UP * 1.5, Vector3(3.9, 3, 3.9))
	game.station.closed[1][blocked] = true
	game.station.grids[1].set_point_solid(blocked, true)
	place(game, center, game.station.point(tile + Vector2i(2, 0)))
	game.tracking_time = 10.0
	lap = game.laps
	penetrated = false
	var turned := false
	for i in range(100):
		await physics_frame
		if game.laps != lap: break
		game.update_boss(0.1, false)
		if game.laps != lap: break
		var gap := Vector2(maxf(absf(game.boss.position.x - blocker.x) - 1.95, 0.0), maxf(absf(game.boss.position.z - blocker.z) - 1.95, 0.0))
		penetrated = penetrated or gap.length() < 0.29
		turned = turned or absf(game.boss.position.z - center.z) > 3.0
	check(turned, "occluded target uses A-star around a blocked tile")
	check(not penetrated, "pursuit never clips the inside corner while changing back to direct chase")
	check(game.laps > lap, "hunter reaches the player after turning around a wall")
	wall.free()

	game.free()
	await process_frame
	print("HUNTER_PURSUIT_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
