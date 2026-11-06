extends Node

const PORT = 19754
const SEATS = ["舰队队长", "小医生武器官", "游隼编队", "玄武编队"]
const COLORS = [Color("6ee9ff"), Color("d0a7ff"), Color("ffd18c"), Color("7affce")]
const CHAPTERS = ["01 / 静默回声", "02 / 失去应答", "03 / 终末授权"]
const SIGNALS = ["林队长 · 求救信号来自木星阴影区。先护住领航员，游隼查明来袭方向。", "玄武 · 信号不是求救，是它们在学习我们的通信。重型单位正在逼近。", "武器官 · 找到母舰。游隼标记核心，玄武压制屏障，等队长授权后发射。"]

var game: Node3D
var awake = false
var wake_time = -20.0
var seat = 0
var room_open = false
var room_status = "同一局域网内，队长创建房间，其余三席输入队长地址。"
var roster: Dictionary = {}
var session: ENetMultiplayerPeer
var sync_timer = 0.0
var power = 0
var authorization = false
var charging = false
var charge = 0.0
var weapon_target = -1
var scan = 0.0
var jam = 0.0
var scanning = false
var jamming = false
var fired = false
var story = "领航员 · 这里是领航员空间站。我们在木星阴影区收到一段重复的求救信号。"
var boost = [0.0, 0.0]
var cooldown = [0.0, 0.0]
var visual_events: Array = []

func _ready() -> void:
	multiplayer.peer_connected.connect(peer_arrived)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(func(): room_status = "已接入指挥网络，等待队长部署。")
	multiplayer.connection_failed.connect(func(): leave_room("连接失败，请确认房主地址和局域网端口。"))
	multiplayer.server_disconnected.connect(func(): leave_room("队长已离线，已返回待命。"))

func wake() -> void:
	if awake: return
	awake = true
	wake_time = game.time
	game.input_guard = 0.65
	game.sound("confirm")

func switch_seat(next: int) -> void:
	if next < 0 or next >= SEATS.size(): return
	if session:
		if is_client(): claim_seat.rpc_id(1, next)
		return
	assign_seat(next)

func assign_seat(next: int) -> void:
	if next == seat: return
	seat = next
	game.cancel_drag()
	game.radial_open = false
	game.selected.clear()
	if seat >= 2: game.selected.append(seat - 2)
	game.sound("confirm")

func is_client() -> bool:
	return session != null and not multiplayer.is_server()

func host_room() -> void:
	if session: return
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 3) != OK:
		room_status = "无法创建房间，端口可能已被占用。"
		return
	session = peer
	roster = {1: 0}
	assign_seat(0)
	multiplayer.multiplayer_peer = peer
	var addresses = Array(IP.get_local_addresses()).filter(func(address): return address.is_valid_ip_address() and not ":" in address and not address.begins_with("127."))
	room_status = "房间地址 %s  ·  UDP %d" % [", ".join(addresses), PORT]

func join_room(address: String) -> void:
	if session: return
	address = address.strip_edges()
	if not address.is_valid_ip_address():
		room_status = "请输入队长电脑的 IP 地址。"
		return
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(address, PORT) != OK:
		room_status = "无法连接房间。"
		return
	session = peer
	multiplayer.multiplayer_peer = peer
	room_status = "正在连接队长…"

func leave_room(message: String = "已退出局域网，恢复单机切换。") -> void:
	if not session: return
	var was_client = is_client()
	session.close()
	session = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()
	room_status = message
	if was_client:
		for enemy in game.enemies: enemy.node.queue_free()
		game.enemies.clear()
		game.phase = 0
		game.wave = 0
		game.paused = false

func peer_arrived(id: int) -> void:
	if not session or is_client(): return
	for available in range(1, 4):
		if not available in roster.values():
			roster[id] = available
			set_roster.rpc(roster)
			return

func peer_left(id: int) -> void:
	if not session or is_client(): return
	roster.erase(id)
	set_roster.rpc(roster)

@rpc("any_peer", "call_remote", "reliable")
func claim_seat(next: int) -> void:
	if not session or is_client() or next < 1 or next > 3 or next in roster.values(): return
	var sender = multiplayer.get_remote_sender_id()
	if not roster.has(sender): return
	roster[sender] = next
	set_roster.rpc(roster)

@rpc("authority", "call_remote", "reliable")
func set_roster(value: Dictionary) -> void:
	roster = value
	assign_seat(int(roster.get(multiplayer.get_unique_id(), 0)))

func request(action: String, data: Dictionary = {}) -> void:
	if is_client():
		if session.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: receive_action.rpc_id(1, action, data)
	else: execute(seat, action, data)

@rpc("any_peer", "call_remote", "reliable")
func receive_action(action: String, data: Dictionary) -> void:
	if not session or is_client(): return
	var sender = multiplayer.get_remote_sender_id()
	if roster.has(sender): execute(roster[sender], action, data)

func execute(role: int, action: String, data: Dictionary = {}) -> void:
	if role == 0 and action == "start" and game.phase != 1:
		if session and roster.size() < 4:
			game.announce("等待其他席位接入 / %d / 4" % roster.size(), 5)
			return
		game.start_battle()
		return
	if role == 0 and action == "restart":
		game.start_battle()
		return
	if role == 0 and action == "pause" and game.phase == 1:
		game.paused = not game.paused
		return
	if game.phase != 1 or game.paused: return
	match role:
		0: captain_action(action, data)
		1: weapon_action(action)
		2, 3: drone_action(role - 2, action, data)

func captain_action(action: String, data: Dictionary) -> void:
	match action:
		"power":
			power = clampi(int(data.get("mode", 0)), 0, 2)
			game.announce("队长 / 能源转接至" + ["空间站防御", "小医生充能", "无人机推进"][power])
		"authorize":
			if game.wave < 3 or fired: return
			authorization = not authorization
			game.announce("队长 / 发射授权已签发" if authorization else "队长 / 发射授权已撤回")
		"repair":
			var prior: Array[int] = game.selected.duplicate()
			game.selected.assign([0, 1])
			game.repair()
			game.selected.assign(prior)

func core() -> Dictionary:
	for enemy in game.enemies:
		if enemy.get("core", false) and not enemy.dead: return enemy
	return {}

func weapon_action(action: String) -> void:
	var target = core()
	match action:
		"lock":
			if not target.is_empty():
				weapon_target = target.id
				game.announce("武器官 / 母舰反应堆已锁定")
		"charge":
			if not fired:
				charging = not charging
				game.announce("小医生 / 充能开始" if charging else "小医生 / 充能暂停")
		"fire":
			var reason = interlock()
			if not reason.is_empty():
				game.announce("发射闭锁 / " + reason)
				return
			fired = true
			charging = false
			charge = 0.0
			authorization = false
			for enemy in game.enemies:
				if enemy.pos.distance_to(target.pos) < 25.0: enemy.hp = 0.0
			for offset in [-.38, -.16, 0.0, .16, .38]:
				game.spawn_bolt(game.STATION_POS + Vector3(offset,1.5,0), target.pos + Vector3(offset,0,0), COLORS[1] if offset != 0 else Color.WHITE, 1.35)
			game.spawn_pulse(target.pos, COLORS[1], 25)
			game.sound("salvo")
			story = "武器官 · 链式反应已开始。母舰信号归零。领航员，撤出阴影区。"
			game.announce("小医生已发射 / 母舰结构瓦解", 6)

func interlock() -> String:
	if fired: return "本次任务的武器已发射"
	if core().is_empty() or weapon_target < 0: return "武器官尚未锁定母舰"
	if scan < 100: return "等待游隼测绘核心"
	if jam < 100: return "等待玄武解除屏障"
	if charge < 100: return "小医生尚未充满"
	if not authorization: return "等待队长授权"
	return ""

func drone_action(id: int, action: String, data: Dictionary) -> void:
	if game.fleet[id].hp <= 0: return
	var prior: Array[int] = game.selected.duplicate()
	var old_path: Array[Vector3] = game.drag_path.duplicate()
	game.selected.assign([id])
	match action:
		"order":
			var point = data.get("point")
			if point is Vector3 and point.is_finite():
				point = point.clamp(Vector3(-32,-5,-60), Vector3(32,12,25))
				var target = -1
				for index in range(game.enemies.size()):
					if game.enemies[index].id == data.get("target", -1): target = index
				game.drag_path.clear()
				var path = data.get("path", [])
				if path is Array:
					for i in range(mini(path.size(), 80)):
						if path[i] is Vector3 and path[i].is_finite(): game.drag_path.append(path[i].clamp(Vector3(-32,-5,-60),Vector3(32,12,25)))
				game.issue_order(point, target)
		"mode": game.set_mode(clampi(int(data.get("mode", 0)),0,2))
		"altitude": game.change_altitude(2.0 if data.get("up", true) else -2.0)
		"signal":
			if game.wave >= 3:
				if id == 0: scanning = not scanning
				else: jamming = not jamming
				game.announce("协同链路 / 进入母舰 42 km 内执行" + ("核心测绘" if id == 0 else "屏障压制"))
		"boost":
			if cooldown[id] <= 0:
				boost[id] = 6.0
				cooldown[id] = 18.0
				game.announce("游隼 / 超频推进" if id == 0 else "玄武 / 偏转护盾")
	game.drag_path.assign(old_path)
	game.selected.assign(prior)

func reset_mission() -> void:
	power = 0
	authorization = false
	charging = false
	charge = 0.0
	weapon_target = -1
	scan = 0.0
	jam = 0.0
	scanning = false
	jamming = false
	fired = false
	boost = [0.0,0.0]
	cooldown = [0.0,0.0]

func tick(delta: float) -> void:
	if game.phase != 1: return
	for i in range(2):
		boost[i] = maxf(0, boost[i] - delta)
		cooldown[i] = maxf(0, cooldown[i] - delta)
	if charging: charge = minf(100,charge + delta * (10.0 if power == 1 else 2.5))
	var target = core()
	if target.is_empty(): return
	if scanning and in_signal_range(0, target): scan = minf(100, scan + delta * 21)
	if jamming and in_signal_range(1, target): jam = minf(100, jam + delta * 17)

func in_signal_range(id: int, target: Dictionary) -> bool:
	return not target.is_empty() and game.fleet[id].hp > 0 and game.fleet[id].pos.distance_to(target.pos) <= 42

func sync(delta: float) -> void:
	if not session or is_client(): return
	if multiplayer.get_peers().is_empty():
		visual_events.clear()
		return
	sync_timer += delta
	if sync_timer < 0.1: return
	sync_timer = 0.0
	var groups: Array = []
	for group in game.fleet: groups.append([group.pos, group.goal, group.hp, group.mode, group.node.rotation.y, group.path.duplicate()])
	var contacts: Array = []
	for enemy in game.enemies: contacts.append([enemy.id, enemy.pos, enemy.hp, enemy.max_hp, enemy.capital, enemy.get("core", false)])
	var match_state = [game.phase, game.wave, game.hull, game.energy, game.kills, game.mission_time, game.paused, game.cooldown_repair]
	var role_state = [power, authorization, charging, charge, weapon_target, scan, jam, scanning, jamming, fired, boost, cooldown, story]
	load_snapshot.rpc(groups, contacts, match_state, role_state, game.toast, game.toast_timer, visual_events)
	visual_events.clear()

@rpc("authority", "call_remote", "unreliable_ordered")
func load_snapshot(groups: Array, contacts: Array, state: Array, roles: Array, notice: String, notice_time: float, shots: Array) -> void:
	for i in range(groups.size()):
		var group = game.fleet[i]
		var entry = groups[i]
		group.pos = entry[0]
		group.goal = entry[1]
		group.hp = entry[2]
		group.mode = entry[3]
		group.node.rotation.y = entry[4]
		group.path = entry[5]
	var previous: Dictionary = {}
	for enemy in game.enemies: previous[enemy.id] = enemy
	game.enemies.clear()
	for contact in contacts:
		var enemy: Dictionary = previous.get(contact[0], {})
		if enemy.is_empty():
			game.spawn_enemy(contact[1], contact[4], contact[5])
			enemy = game.enemies.pop_back()
			if contact[5]: enemy.node.scale *= 1.5
		previous.erase(contact[0])
		enemy.id = contact[0]
		enemy.pos = contact[1]
		enemy.hp = contact[2]
		enemy.max_hp = contact[3]
		enemy.node.position = contact[1]
		game.enemies.append(enemy)
	for old in previous.values(): old.node.queue_free()
	game.phase = state[0]
	game.wave = state[1]
	game.hull = state[2]
	game.energy = state[3]
	game.kills = state[4]
	game.mission_time = state[5]
	game.paused = state[6]
	game.cooldown_repair = state[7]
	power = roles[0]
	authorization = roles[1]
	charging = roles[2]
	charge = roles[3]
	weapon_target = roles[4]
	scan = roles[5]
	jam = roles[6]
	scanning = roles[7]
	jamming = roles[8]
	fired = roles[9]
	boost = roles[10]
	cooldown = roles[11]
	story = roles[12]
	game.toast = notice
	game.toast_timer = notice_time
	for shot in shots:
		if shot[1] == null: game.spawn_pulse(shot[0],shot[2],shot[3])
		else: game.spawn_bolt(shot[0],shot[1],shot[2],shot[3])
