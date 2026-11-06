extends Node

signal loaded(data: Dictionary)
signal tactic_ready(lap: int, strategy: String, gate: int, source: String)

const SAVE_PATHS := ["user://audit-0.json", "user://audit-1.json"]
const DEFAULT_STATE := {"chapter": 0, "laps": 1, "evidence": [false, false, false], "solved": false, "cleared": false}

var status := "存档  /  正在读取审计匣"
var player_id := ""
var revision := 0
var acknowledged := -1
var sent_revision := -1
var state := DEFAULT_STATE.duplicate(true)
var base_url := "http://127.0.0.1:8765"
var read_request: HTTPRequest
var write_request: HTTPRequest
var tactics_request: HTTPRequest
var request_lap := 0


func open() -> void:
	for path in SAVE_PATHS:
		if FileAccess.file_exists(path):
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if document is Dictionary and valid_snapshot(document) and int(document.rev) >= revision:
				player_id = document.player
				revision = int(document.rev)
				state = normalize(document.state)
	if player_id.is_empty():
		player_id = Crypto.new().generate_random_bytes(16).hex_encode()
		write_local()
	loaded.emit(state.duplicate(true))
	var configured := OS.get_environment("CORRIDOR_BACKEND_URL").strip_edges()
	if not configured.is_empty():
		base_url = configured.trim_suffix("/")
	read_request = request_node(on_read)
	write_request = request_node(on_write)
	tactics_request = request_node(on_tactic)
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(sync)
	add_child(timer)
	timer.start()
	if read_request.request(save_url()) != OK:
		sync()


func request_node(handler: Callable) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = 3.2
	add_child(http)
	http.request_completed.connect(handler)
	return http


func valid_snapshot(document: Dictionary) -> bool:
	if not document.get("player") is String or document.player.length() != 32:
		return false
	for character in document.player:
		if character not in "0123456789abcdef":
			return false
	if not (document.get("rev") is float or document.get("rev") is int) or not document.get("state") is Dictionary:
		return false
	var contents: Dictionary = document.state
	if not contents.get("evidence") is Array or contents.evidence.size() != 3:
		return false
	for item in contents.evidence:
		if not item is bool:
			return false
	return int(contents.get("chapter", -1)) in [0, 1, 2, 3, 4] and int(contents.get("laps", 0)) > 0 and int(document.rev) >= 0


func normalize(contents: Dictionary) -> Dictionary:
	return {"chapter": int(contents.chapter), "laps": int(contents.laps), "evidence": contents.evidence,
		"solved": bool(contents.get("solved", false)), "cleared": bool(contents.get("cleared", false))}


func save_url() -> String:
	return base_url + "/api/players/" + player_id + "/save"


func write_local() -> void:
	var file := FileAccess.open(SAVE_PATHS[revision % 2], FileAccess.WRITE)
	if file == null:
		status = "存档  /  本地写入失败"
		return
	file.store_string(JSON.stringify({"player": player_id, "rev": revision, "state": state}))
	file.flush()
	status = "存档  /  本机已保存"


func save_state(next: Dictionary) -> void:
	if next == state:
		return
	state = next.duplicate(true)
	revision += 1
	write_local()
	sync()


func sync() -> void:
	if read_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or sent_revision >= 0 or revision <= acknowledged:
		return
	sent_revision = revision
	var body := JSON.stringify({"rev": revision, "state": state})
	if write_request.request(save_url(), ["Content-Type: application/json"], HTTPClient.METHOD_PUT, body) != OK:
		sent_revision = -1


func on_read(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code == 200:
		var remote: Variant = JSON.parse_string(body.get_string_from_utf8())
		if remote is Dictionary and valid_snapshot(remote) and remote.player == player_id:
			acknowledged = int(remote.rev)
			if acknowledged > revision:
				revision = acknowledged
				state = normalize(remote.state)
				write_local()
				loaded.emit(state.duplicate(true))
			if revision == acknowledged:
				status = "存档  /  已同步至后端"
	call_deferred("sync")


func on_write(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if code == 200:
		acknowledged = sent_revision
		if acknowledged == revision:
			status = "存档  /  已同步至后端"
	sent_revision = -1
	if code == 200:
		call_deferred("sync")


func choose_tactic(lap: int, gates: Array, running: int) -> void:
	var favored := 0 if gates[0] > gates[1] else 1
	var policy := "patrol" if gates[0] + gates[1] == 0 else "cutoff"
	tactic_ready.emit(lap, policy, favored, "rules")
	tactics_request.cancel_request()
	request_lap = lap
	var body := JSON.stringify({"lap": lap, "gates": gates, "sprint_heard": running})
	tactics_request.request(base_url + "/api/tactics", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func on_tactic(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		return
	var response: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response is Dictionary and int(response.get("lap", -1)) == request_lap and response.get("strategy") in ["patrol", "cutoff", "ambush", "guard"]:
		tactic_ready.emit(request_lap, response.strategy, int(response.get("gate", 0)), "deepseek" if response.get("source") == "deepseek" else "rules")
