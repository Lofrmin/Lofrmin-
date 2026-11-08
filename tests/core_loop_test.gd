extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	check(game.has_method("audit_status_text"), "audit state must be visible")
	if not game.has_method("audit_status_text"):
		game.free()
		quit(1)
		return
	game.chapter = 1
	game.evidence = [true, true, false]
	game.update_witness()
	check(game.audit_status_text().contains("待复核"), "before signing")
	game.set_mode("audit")
	game.handle_action("accept_commit")
	check(not game.case_accepted, "signature cannot commit without explicit preview")
	game.handle_action("accept")
	check(game.signature_pending and not game.case_accepted, "opening signature explains consequence without signing")
	check(is_zero_approx(game.station.witnesses[1].rotation.x), "preview keeps witness alive")
	game.handle_action("accept_cancel")
	check(not game.signature_pending and not game.case_accepted, "cancel returns to unsigned reading")
	game.handle_action("accept")
	game.set_mode("world")
	check(not game.signature_pending and not game.case_accepted, "leaving desk clears pending signature")
	game.set_mode("audit")
	game.handle_action("accept")
	game.handle_action("accept_commit")
	check(game.case_accepted and game.audit_status_text().contains("已复核"), "after signing")
	check(game.station.audit_labels[0].text == game.audit_status_text(), "scene screen matches rules")
	check(not is_zero_approx(game.station.witnesses[1].rotation.x), "signing changes witness outcome")
	game.reset_lap("test")
	check(not game.case_accepted and game.audit_status_text().contains("待复核"), "reset clears signature")
	check(game.evidence == [true, true, false], "banked evidence survives")
	check(is_zero_approx(game.station.witnesses[1].rotation.x), "unsigned witness remains alive")
	game.evidence = [false,false,false]
	game.interact()
	check(game.mode == "audit" and game.evidence[1] and not game.case_accepted, "reading A-42 archives process without signature")
	check(game.authorization_fields().size() == 3 and game.authorization_fields()[2].contains("关闭"), "discoverable process discloses field-check cost")
	check(not game.objective().contains("暂缓") and not game.objective().contains("未签"), "objective does not give away the signature strategy")
	game.inspect_relay()
	game.phase = 1
	game.inspect_office()
	check(game.evidence[2] and not game.case_accepted, "unsigned field check collects live testimony")
	game.phase = 0
	game.interact()
	check(game.evidence == [true,true,true] and not game.unbanked, "testimony can be archived without signature")
	game.reset_lap("isolate authorization field-check state")
	game.chapter = 0
	game.evidence = [false, false, false]
	game.interact()
	check(game.case_accepted and game.audit_status_text().contains("已签收"), "first E interaction also refreshes desk")
	check(not game.audit_status_text().contains("扣款"), "first screen does not reveal twist")
	check(game.has_method("submit_alignment"), "interactive alignment required")
	if not game.has_method("submit_alignment"):
		game.free()
		quit(1)
		return
	game.set_mode("audit")
	game.evidence = [true, false, false]
	game.submit_alignment(["device", "alarm"])
	check(game.chapter == 0, "missing evidence blocks alignment")
	game.evidence = [true, true, true]
	for fields in [["clock"], ["device"], ["alarm"], ["device","alarm","clock"], ["device","device"], ["bad"]]:
		game.submit_alignment(fields)
		check(game.chapter == 0, "wrong field selection blocked: %s" % str(fields))
	game.answer(1)
	check(game.chapter == 0, "old answer cannot bypass interaction")
	game.handle_action("choice_1")
	check(game.chapter == 0, "old mouse action cannot bypass")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_2
	game._input(key)
	check(game.chapter == 0 and game.alignment_fields == ["alarm"], "digit toggles field rather than advancing")
	game.handle_action("align_device")
	check(game.alignment_fields.has("device"), "mouse toggles device")
	game.handle_action("align_clock")
	game.handle_action("align_clock")
	check(not game.alignment_fields.has("clock"), "toggle removes selection")
	key.physical_keycode = KEY_ENTER
	game._input(key)
	check(game.chapter == 3 and game.evidence == [false,false,false], "correct identity advances to clock chapter")
	check(game.alignment_fields.is_empty(), "alignment transient state cleared")
	game.chapter = 3
	game.evidence = [true,true,true]
	game.set_mode("audit")
	game.answer(0)
	game.handle_action("choice_0")
	check(game.chapter == 3, "timeline cannot be bypassed by old multiple-choice actions")
	game.timeline_key("5")
	game.pick_timeline("filing")
	game.pick_timeline("debit")
	game.submit_timeline()
	check(game.chapter == 3, "right conversion with wrong chronology is rejected")
	game.timeline_seconds = ""
	game.timeline_order.clear()
	game.timeline_key("5")
	game.pick_timeline("debit")
	game.pick_timeline("filing")
	game.submit_timeline()
	check(game.chapter == 1, "correct event order advances to authorization case")
	game.evidence = [true,true,true]
	game.set_mode("audit")
	game.answer(2)
	check(game.chapter == 4, "authorization puzzle unchanged")
	game.mode = "keypad"
	game.keypad_entry = "7138"
	game.press_keypad("enter")
	check(game.evidence[1] and game.mode == "world", "existing keypad unchanged")
	check(game.has_method("relay_status"), "relay status is visible")
	if not game.has_method("relay_status"):
		game.free()
		quit(1)
		return
	game.chapter = 2
	game.solved = true
	game.armed = false
	game.patched = false
	game.phase = 0
	check(game.relay_status().contains("线路已核验"), "relay starts after evidence verification")
	game.inspect_relay()
	check(game.armed and game.relay_status().contains("晨区"), "morning switch is visible")
	game.phase = 1
	game.inspect_relay()
	check(game.patched and game.relay_status().contains("暮区"), "dusk relay is visible")
	game.evidence = [true,true,true]
	game.set_mode("audit")
	game.answer(1)
	check(game.chapter == 2, "ledger puzzle unchanged")
	game.evidence = [true,true,true]
	game.set_mode("audit")
	game.answer(0)
	check(game.solved, "relay conclusion unchanged")
	game.phase = 0
	game.inspect_relay()
	game.phase = 1
	game.inspect_relay()
	check(game.armed and game.patched, "cross-phase wiring unchanged")
	game.phase = 0
	game.set_mode("audit")
	game.begin_upload()
	check(game.upload == 30.0, "final upload lasts thirty seconds")
	game.free()
	await process_frame
	print("CORE_LOOP_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
