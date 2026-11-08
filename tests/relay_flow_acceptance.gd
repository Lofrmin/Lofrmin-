extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.chapter = 2
	game.evidence = [true,true,true]
	game.solved = false
	game.armed = false
	game.patched = false
	game.cleared = false
	game.update_witness()
	game.set_mode("audit")
	game.answer(0)
	check(game.solved and game.mode == "world", "real answer completes circuit verification")
	for rig in game.station.relay_rigs:
		print("AFTER_REAL_ANSWER phase=",rig.phase," label=",rig.status_label.text," rule=",game.relay_status())
		check(rig.status_label.text == "VERIFIED", "real puzzle answer updates visible verification state")
		check(rig.node.find_children("*","CollisionObject3D",true,false).is_empty(), "relay decoration adds no collision")
		var tag: Label3D = rig.node.get_node("E7_Label")
		var knob: Node3D = rig.switch_arm.get_node("Knob")
		var desk: Vector3 = game.station.point(game.station.RELAY) + Vector3(0,0,-1.21)
		print("MODEL phase=",rig.phase," tag_relative_to_old_monitor_center=",tag.global_position - (desk + Vector3.UP*1.23)," knob_relative_to_old_monitor_center=",knob.global_position - (desk + Vector3.UP*1.23))
	game.phase = 0
	game.station.set_phase(0)
	game.player.position = game.station.point(game.station.RELAY) + Vector3(0,0.05,0.6)
	game.interact()
	check(game.armed, "real relay interaction arms switch")
	for rig in game.station.relay_rigs:
		check(rig.status_label.text == "ARMED", "armed label follows real interaction")
	game.shift_cooldown = 0.0
	game.shift(game.station.GATES[0])
	game.player.position = game.station.point(game.station.RELAY) + Vector3(0,0.05,0.6)
	game.interact()
	if game.dusk_trials.active and game.dusk_trials.kind == "relay":
		for site in game.dusk_trials.sites:
			game.player.position = site.position + Vector3(-0.95,0.05,0)
			game.interact()
		game.player.position = game.station.point(game.station.RELAY) + Vector3(0,0.05,0.6)
		game.interact()
	check(game.patched, "Dusk relay interaction connects cable")
	for rig in game.station.relay_rigs:
		check(rig.status_label.text == "LINKED", "linked label follows real interaction")
	game.reset_lap("acceptance reset")
	for rig in game.station.relay_rigs:
		check(rig.status_label.text == "VERIFIED" and not rig.scan_bar.visible, "reset clears transient relay state and keeps verification")
	game.free()
	await process_frame
	print("RELAY_ACCEPTANCE: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
