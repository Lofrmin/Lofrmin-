extends RefCounted

# Temporary barriers live on grid EDGES, never occupy an entire floor cell.
const WARNING := 0.85
const LIFETIME := 4.5
const MAX_ACTIVE := 2
const TRIGGER_CHANCE := 0.55
const PLAYER_ONLY_LAYER := 2
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var station: Node3D
var links: Array[Dictionary] = []
var active: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var random := RandomNumberGenerator.new()
var probe := 0.0
var safety_timer := 0.0
var revision := 0
var triggers := 0

func setup(map: Node3D, candidates: Array[Dictionary]) -> void:
	station = map
	links = candidates
	random.randomize()

func edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		return "%d,%d:%d,%d" % [b.x, b.y, a.x, a.y]
	return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]

func blocked(a: Vector2i, b: Vector2i) -> bool:
	return station.laser_edges.has(edge_key(a, b))

func clear() -> void:
	for entry in active:
		remove(entry)
	active.clear()
	cooldowns.clear()
	probe = 0.0

func remove(entry: Dictionary) -> void:
	station.laser_edges.erase(entry.key)
	if is_instance_valid(entry.node):
		entry.node.free()
	revision += 1

func update(delta: float, phase: int, chasing: bool, player: Vector3, hunter: Vector3, extra_positions: Array[Vector3] = []) -> void:
	if phase != 1 or not chasing:
		if not active.is_empty(): clear()
		return
	for key in cooldowns.keys():
		cooldowns[key] -= delta
		if cooldowns[key] <= 0.0: cooldowns.erase(key)
	var player_cell: Vector2i = station.cell(player)
	safety_timer -= delta
	var check_safety := safety_timer <= 0.0
	if check_safety: safety_timer = 0.20
	for index in range(active.size() - 1, -1, -1):
		var entry: Dictionary = active[index]
		entry.time -= delta
		if entry.warning:
			# Cancel rather than materialize through either actor.
			if entry.time <= 0.0:
				if near_plane(entry, player, 0.85) or any_near_plane(entry, hunter, extra_positions, 0.85) or not safe_after(entry, player_cell, hunter, extra_positions):
					remove(entry)
					active.remove_at(index)
					continue
				entry.warning = false
				entry.time = LIFETIME
				entry.label.text = "光栅运行 · 阻挡玩家"
				station.laser_edges[entry.key] = true
				entry.body.collision_layer = PLAYER_ONLY_LAYER
				entry.body.collision_mask = 0
				for beam in entry.beams: beam.material_override = station.palette.red
				for sleeve in entry.sleeves: sleeve.material_override = station.palette.red
				revision += 1
		elif entry.time <= 0.0 or (check_safety and not safe_after({}, player_cell, hunter, extra_positions)):
			remove(entry)
			active.remove_at(index)
	probe -= delta
	if probe > 0.0 or active.size() >= MAX_ACTIVE: return
	probe = 0.65
	var candidates: Array[Dictionary] = []
	for link in links:
		if cooldowns.has(link.key) or station.laser_edges.has(link.key): continue
		if not station.walkable(1, link.a) or not station.walkable(1, link.b): continue
		# Both endpoints belong to an existing pair of identically dressed pillars.
		if player.distance_to(link.center) > 6.0 or player.distance_to(link.center) < 1.3: continue
		var close_hunter := hunter.distance_to(link.center) < 3.0
		for position in extra_positions:
			close_hunter = close_hunter or position.distance_to(link.center) < 3.0
		if close_hunter: continue
		candidates.append(link)
	if candidates.is_empty(): return
	var link: Dictionary = candidates[random.randi_range(0, candidates.size() - 1)]
	cooldowns[link.key] = 9.0
	if random.randf() <= TRIGGER_CHANCE: try_spawn(link, player, hunter, extra_positions)

func near_plane(link: Dictionary, actor: Vector3, margin: float) -> bool:
	var offset: Vector3 = actor - link.center
	var normal: Vector3 = link.normal
	var tangent := Vector3(-normal.z, 0, normal.x)
	return absf(offset.dot(normal)) < margin and absf(offset.dot(tangent)) < 2.25

func any_near_plane(link: Dictionary, hunter: Vector3, extra_positions: Array[Vector3], margin: float) -> bool:
	if near_plane(link, hunter, margin): return true
	for position in extra_positions:
		if near_plane(link, position, margin): return true
	return false

func try_spawn(link: Dictionary, player: Vector3, hunter: Vector3, extra_positions: Array[Vector3] = []) -> bool:
	if active.size() >= MAX_ACTIVE or station.laser_edges.has(link.key): return false
	for entry in active:
		if entry.key == link.key: return false
	if near_plane(link, player, 0.85) or any_near_plane(link, hunter, extra_positions, 0.85): return false
	if not safe_after(link, station.cell(player), hunter, extra_positions): return false
	var node := Node3D.new()
	node.name = "TemporaryLaser_%d" % triggers
	station.maps[1].add_child(node)
	node.position = link.center
	var normal: Vector3 = link.normal
	var size: Vector3 = station.axes(normal, 0.12, 2.55, 3.78)
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	node.add_child(body)
	body.position.y = 1.30
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	var beams: Array[MeshInstance3D] = []
	for height in [0.24, 0.60, 0.96, 1.32, 1.68, 2.04, 2.40]:
		beams.append(station.box(node, Vector3.UP * height, station.axes(normal, 0.065, 0.055, 3.78), station.palette.amber))
	var label: Label3D = station.sign_at(node, Vector3.UP * 2.65, "光栅预警 · 暂不阻挡", Color("ffb575"))
	label.font_size = 28
	var sleeves: Array[MeshInstance3D] = station.build_active_emitter_glow(node, normal)
	var entry := link.duplicate()
	entry.merge({"node": node, "body": body, "beams": beams, "sleeves": sleeves, "label": label, "warning": true, "time": WARNING})
	active.append(entry)
	cooldowns[link.key] = 10.0
	triggers += 1
	return true

# A conservative hunter exclusion zone, plus two separate immediate escape
# directions which each reach a gate without returning through the player's cell.
# Rechecked during warning AND while blocking; unsafe barriers retract early.
func safe_after(candidate: Dictionary, start: Vector2i, hunter: Vector3, extra_positions: Array[Vector3] = []) -> bool:
	if not station.walkable(1, start): return false
	var forbidden: Dictionary = station.laser_edges.duplicate()
	for entry in active:
		forbidden[entry.key] = true
	if not candidate.is_empty(): forbidden[candidate.key] = true
	var danger: Dictionary = {}
	for z in range(station.MAP_SIZE.y):
		for x in range(station.MAP_SIZE.x):
			var tile := Vector2i(x, z)
			if station.point(tile).distance_to(hunter) < 10.0: danger[tile] = true
			for position in extra_positions:
				if station.point(tile).distance_to(position) < 10.0: danger[tile] = true
	if danger.has(start): return false
	var viable_directions := 0
	var gates_reached: Dictionary = {}
	for direction in DIRECTIONS:
		var first: Vector2i = start + direction
		if not station.walkable(1, first) or danger.has(first) or forbidden.has(edge_key(start, first)): continue
		var visited: Dictionary = {start: true, first: true}
		var queue: Array[Vector2i] = [first]
		var cursor := 0
		var branch_gates := 0
		while cursor < queue.size():
			var at: Vector2i = queue[cursor]
			cursor += 1
			if at in station.GATES:
				branch_gates += 1
				gates_reached[at] = true
			for step in DIRECTIONS:
				var next: Vector2i = at + step
				if visited.has(next) or danger.has(next) or not station.walkable(1, next): continue
				if forbidden.has(edge_key(at, next)): continue
				visited[next] = true
				queue.append(next)
		if branch_gates > 0 and queue.size() >= 18: viable_directions += 1
	return viable_directions >= 2 and gates_reached.size() >= 2
