extends "res://game.gd"

# Real gameplay and scene objects, but no profile.open(), disk writes or network.
class MemoryProfile extends Node:
	var status := "测试存档 / 内存"
	var saved: Dictionary = {}
	func save_state(state: Dictionary) -> void:
		saved = state.duplicate(true)
	func choose_tactic(_lap: int, _gates: Array, _sprint: int) -> void:
		pass

func _ready() -> void:
	station = Station.new()
	station.use_audit_monitor_prop = false
	add_child(station)
	station.build()
	build_player()
	build_boss()
	build_audio()
	profile = MemoryProfile.new()
	add_child(profile)
	var layer := CanvasLayer.new()
	add_child(layer)
	interface = Interface.new()
	interface.game = self
	layer.add_child(interface)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101820")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d5dde1")
	settings.ambient_light_energy = 0.49
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = settings
	add_child(environment)
	spawn_at_desk()
	camera.make_current()

func _process(_delta: float) -> void:
	interface.queue_redraw()

func _physics_process(_delta: float) -> void:
	pass
