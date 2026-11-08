extends SceneTree

# 直接调用真实 apply_stamina_tick，不依赖地图碰撞。
var failures: Array[String] = []
var checks := 0
var game: Node3D


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)


func _initialize() -> void:
	call_deferred("run")


func reset() -> void:
	game.stamina = 100.0
	game.stamina_regen_wait = 0.0
	game.stamina_exhausted = false
	game.actual_sprinting = false
	game.mode = "world"


func tick(seconds: float, shift: bool, moved: bool, dt: float = 1.0 / 60.0) -> void:
	var n := roundi(seconds / dt)
	for i in range(n):
		game.apply_stamina_tick(dt, shift, moved)


func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	await process_frame
	reset()

	tick(2.0, true, false)
	check(game.stamina == 100.0 and not game.actual_sprinting, "standing or wall-pinned Shift does not drain")

	reset()
	tick(4.0, true, true)
	check(game.stamina <= 0.01 and game.stamina_exhausted and not game.actual_sprinting, "four seconds of movement exhausts sprint")

	tick(1.0, true, true)
	check(is_equal_approx(game.stamina, 0.0) and not game.actual_sprinting, "held Shift after exhaustion does not flicker")
	tick(0.2, false, false)
	check(is_equal_approx(game.stamina, 0.0), "regen waits 1.25 seconds after exhaustion")
	tick(2.0, false, true)
	check(game.stamina >= 25.0 and not game.stamina_exhausted, "release at 25 percent unlocks")

	tick(0.2, true, true)
	check(game.actual_sprinting, "unlocked player sprints again")

	game.stamina = 40.0
	game.stamina_regen_wait = 0.0
	game.mode = "paused"
	var paused: float = game.stamina
	game.tick_game_physics(1.0)
	check(game.stamina == paused, "paused physics cannot update stamina")
	game.stamina = 40.0
	game.mode = "world"

	game.stamina = 30.0
	game.stamina_regen_wait = 1.0
	game.stamina_exhausted = true
	game.shift(game.station.GATES[0])
	check(game.stamina == 30.0 and game.stamina_regen_wait == 1.0 and game.stamina_exhausted, "phase shift preserves stamina and lockout")
	game.reset_lap("logic reset")
	check(game.stamina == 100.0 and not game.stamina_exhausted, "new lap refills stamina")

	reset()
	for hz in [30, 60, 120]:
		reset()
		tick(0.5, true, true, 1.0 / hz)
		check(absf(game.stamina - 87.5) < 25.0 / hz + 0.02, "drain matches duration at %d Hz (%.3f)" % [hz, game.stamina])

	print("STAMINA_LOGIC: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
