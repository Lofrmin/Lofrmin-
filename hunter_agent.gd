extends Node3D

# Extra hunters own every transient AI/animation state; the original boss API stays intact.
const Visual := preload("res://hunter_visual.gd")
var rig: Node3D
var eye: MeshInstance3D
var lamp: OmniLight3D
var route: Array[Vector2i] = []
var live := true
var chasing := false
var delay := 1.6
var stunned := 0.0
var charge_warning := 0.0
var charge_time := 0.0
var charge_recovery := 2.0
var tracking_time := 0.0
var path_timer := 0.0
var patrol_index := 0
var last_known := Vector2i.ZERO
var target_position := Vector3.ZERO
var previous_position := Vector3.ZERO
var stall_time := 0.0

func _ready() -> void:
	rig = Visual.new()
	add_child(rig)
	eye = rig.status_marker
	lamp = OmniLight3D.new()
	lamp.light_energy = 1.55
	lamp.omni_range = 4.0
	lamp.position = Vector3(0, 1.66, -0.45)
	add_child(lamp)

func update_agent(game: Node3D, delta: float, sprint: bool) -> void:
	previous_position = position
	chasing = false
	if not live or game.phase != 1: return
	delay = maxf(0.0, delay - delta)
	stunned = maxf(0.0, stunned - delta)
	charge_recovery = maxf(0.0, charge_recovery - delta)
	tracking_time = maxf(0.0, tracking_time - delta)
	visible = delay <= 0.8
	eye.material_override = game.station.palette.blue if stunned > 0.0 else game.station.palette.red
	lamp.light_color = Color("54c9ff") if stunned > 0.0 else Color("ff2455")
	var distance := position.distance_to(game.player.position)
	var seen: bool = distance < 13.0 and game.hunter_has_sight(position)
	var locked: bool = game.gate_lock > 0.0
	if locked or seen or (sprint and distance < 10.5):
		target_position = Vector3(game.player.position.x, 0, game.player.position.z)
		var next_cell: Vector2i = game.station.cell(target_position)
		if next_cell != last_known: route.clear()
		last_known = next_cell
		tracking_time = maxf(tracking_time, 3.0)
	chasing = locked or seen or tracking_time > 0.0
	if delay > 0.0 or stunned > 0.0: return
	if game.boss_motion_fraction(position,position) < 0.001:
		var recovered: Vector3 = game.try_boss_overlap_recovery(position)
		if recovered != position:
			position = recovered
			stall_time = 0.0
			route.clear()
			return
	var direct: bool = chasing and game.boss_motion_fraction(position, target_position) >= 1.0
	if seen and direct and distance < 1.10 and game.dusk_grace <= 0.0 and not game.dev_god:
		game.reset_lap("追债人完成结算。审计匣里的记录随你回到了开场。")
		return
	if charge_warning > 0.0:
		charge_warning -= delta
		if charge_warning > 0.0: return
		charge_time = 0.57
		charge_recovery = 5.5
	elif seen and game.dusk_grace <= 0.0 and distance > 2.5 and distance < 7.8 and charge_recovery <= 0.0 and charge_time <= 0.0:
		charge_warning = 0.78
		game.focus_hunter_audio(self)
		game.sound.cue("warning")
		return
	charge_time = maxf(0.0, charge_time - delta)
	var destination := last_known
	if not chasing:
		var sweep: Array = [game.station.LAB, game.station.OFFICE, game.station.LEDGER, game.station.RELAY] + game.station.GATES
		if position.distance_to(game.station.point(sweep[patrol_index])) < 0.25:
			patrol_index = (patrol_index + 1) % sweep.size()
		destination = sweep[patrol_index]
	path_timer -= delta
	var tile: Vector2i = game.station.cell(position)
	var center: Vector3 = game.station.point(tile)
	var target := center
	if direct:
		target = target_position
		route.clear()
	else:
		if route.is_empty() or stall_time >= game.BOSS_STALL_REPLAN or (path_timer <= 0.0 and position.distance_to(center) < 0.22):
			route = game.station.hunter_path(1, tile, destination)
			if not route.is_empty() and position.distance_to(center) < 0.22: route.pop_front()
			path_timer = 0.30
			stall_time = 0.0
		if not route.is_empty(): target = game.station.point(route[0])
		if tile == destination and chasing: target = target_position
		if game.boss_motion_fraction(position, target) < 1.0:
			var detour: PackedVector3Array = game.hunter_detour_path(position, target, 1)
			if detour.size() > 1: target = detour[1]
	if position.distance_to(target) < 0.035:
		if not route.is_empty(): route.pop_front()
		return
	look_at(target, Vector3.UP)
	var speed: float = 7.2 if charge_time > 0.0 else (game.BOSS_CHASE_SPEED if seen else 3.27)
	var next := position.move_toward(target, speed * delta)
	position = position.lerp(next, game.boss_motion_fraction(position, next))
	stall_time = stall_time + delta if position.distance_to(previous_position) < 0.0005 else 0.0

func pulse_stun() -> void:
	stunned = 2.25
	charge_time = 0.0
	charge_warning = 0.0
	charge_recovery = 3.0
