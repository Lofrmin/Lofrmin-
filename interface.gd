extends Control

const MINT := Color("a7dcd0")
const AMBER := Color("edbe87")
const WHITE := Color("eeeee7")
const DIM := Color("a7b5ba")
const INK := Color("11191e")

var game: Node3D
var font: SystemFont
var mono: SystemFont
var hit_regions: Dictionary = {}
var pointer := Vector2.ZERO


func _ready() -> void:
	font = SystemFont.new()
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "DengXian"]
	mono = SystemFont.new()
	mono.font_names = ["Cascadia Mono", "Consolas", "monospace"]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func button_at(position_in_viewport: Vector2) -> String:
	var point_on_canvas := position_in_viewport * Vector2(1280, 720) / size
	for action in hit_regions:
		if hit_regions[action].has_point(point_on_canvas):
			return action
	return ""


func _draw() -> void:
	if game == null or font == null:
		return
	hit_regions.clear()
	pointer = get_global_mouse_position() * Vector2(1280, 720) / size
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	match game.mode:
		"menu": draw_menu()
		"controls": draw_controls()
		"intro": draw_intro()
		"audit", "keypad": draw_terminal()
		"ending": draw_ending()
		"restart_confirm": draw_restart()
		_: draw_hud()


func write(at: Vector2, message: String, font_size: int, color: Color = WHITE) -> void:
	draw_string(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func text_lines(message: String, width: float, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for character in message:
		if character == "\n":
			lines.append(line)
			line = ""
		elif not line.is_empty() and font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = character
		else:
			line += character
	lines.append(line)
	return lines


func code(at: Vector2, message: String, font_size: int, color: Color = MINT) -> void:
	draw_string(mono, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func alpha(color: Color, opacity: float) -> Color:
	return Color(color, opacity)


func slab(rect: Rect2, color: Color, opacity := 0.88) -> void:
	var p := rect.position
	var end := rect.end
	var cut := 13.0
	var outline := PackedVector2Array([p, Vector2(end.x - cut, p.y), Vector2(end.x, p.y + cut), end, Vector2(p.x + cut, end.y), Vector2(p.x, end.y - cut), p])
	draw_colored_polygon(outline.slice(0, 6), Color(0.031, 0.071, 0.110, opacity))
	draw_polyline(outline, alpha(color, 0.25), 1.0, true)
	draw_line(p + Vector2(1, 1), p + Vector2(39, 1), alpha(color, 0.88), 2.0)
	draw_line(end - Vector2(1, 1), end - Vector2(23, 1), alpha(color, 0.60), 2.0)


func button(rect: Rect2, action: String, caption: String, color: Color = MINT) -> void:
	var hovered := rect.has_point(pointer)
	draw_rect(rect, alpha(color, 0.17 if hovered else 0.055))
	var border := alpha(color, 0.64 if hovered else 0.17)
	draw_rect(rect, border, false, 1.0)
	write(rect.position + Vector2(13, rect.size.y * 0.5 + 5.5), caption, 16, WHITE if hovered else color)
	hit_regions[action] = rect


func draw_menu() -> void:
	var shade := Color(0.008, 0.019, 0.027)
	var curtain := PackedVector2Array([Vector2.ZERO, Vector2(720,0), Vector2(720,720), Vector2(0,720)])
	draw_polygon(curtain, PackedColorArray([alpha(shade,0.96), alpha(shade,0.15), alpha(shade,0.15), alpha(shade,0.96)]))
	code(Vector2(64,63), "C O R R I D O R   /   CASE ARCHIVE", 13)
	code(Vector2(1065,63), "PANDA JAM / CYCLE", 11, DIM)
	write(Vector2(60,171), "回廊", 80)
	write(Vector2(65,218), "借来的明天", 26, MINT)
	draw_line(Vector2(65,246),Vector2(113,246),MINT,2.0)
	write(Vector2(65,286), "同一个任务，再走一次，答案会不同。", 20)
	write(Vector2(65,317), "寻找失联同事，对照晨暮两区的记录。", 16, DIM)
	var saved: bool = game.has_progress()
	button(Rect2(65,358,330,49), "continue" if saved else "new_case", "Enter  继续调查" if saved else "Enter  开始新调查")
	if saved:
		button(Rect2(65,420,330,45), "new_case", "N  开始新调查", DIM)
		button(Rect2(65,477,190,43), "controls", "H  操作说明", DIM)
		button(Rect2(269,477,126,43), "quit", "Q  退出", DIM)
		write(Vector2(65,561), "已归档：" + game.chapter_title(), 17)
		write(Vector2(65,590), "继续调查会回到 A-01，保留已归档证据。", 14, DIM)
	else:
		button(Rect2(65,420,330,45), "controls", "H  操作说明", DIM)
		button(Rect2(65,478,330,43), "quit", "Q  退出", DIM)
		write(Vector2(65,566), "第一步：前往晨区 B-17，核对门禁记录。", 15, DIM)
	code(Vector2(65,669), "01  EXPLORE   /   02  COMPARE   /   03  RETURN", 11, MINT)
	write(Vector2(65,694), "本机自动存档 · 建议戴耳机 · 覆盖旧调查前会再次确认", 12, DIM)


func draw_controls() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.008,0.016,0.024,0.82))
	slab(Rect2(200,83,880,560),MINT,0.98)
	code(Vector2(238,123), "FIELD MANUAL / 事故调查员操作手册", 12)
	write(Vector2(238,172), "先找记录，再回调查台核验。", 29)
	var keys := ["W A S D / 鼠标", "E", "Shift / F", "M", "Esc / H", "R（出现提示时）"]
	var descriptions := ["移动 / 环视", "调查物件；在 G 门切换晨区与暮区", "奔跑 / 断相脉冲：需同区、无遮挡，每轮两次", "切换地图预览，不会改变你所在的时态", "暂停 / 查看操作说明", "撤销本轮接案签字，保留已归档证据"]
	for i in range(keys.size()):
		var y := 226.0 + i * 45.0
		write(Vector2(241,y),keys[i],16,MINT)
		write(Vector2(465,y),descriptions[i],16,WHITE)
		draw_line(Vector2(239,y+14),Vector2(1039,y+14),alpha(DIM,0.14),1.0)
	write(Vector2(240,531), "暮区取回的现场记录，要回晨区 A-01 才能归档。", 17, AMBER)
	write(Vector2(240,561), "开局先查 B-17；不用背完所有规则，靠近物件会出现提示。", 15, DIM)
	button(Rect2(796,585,242,39),"controls_back","Esc / Enter  返回")


func draw_intro() -> void:
	code(Vector2(60,58), "CORRIDOR / INCIDENT BRIEFING", 13)
	write(Vector2(58,143), "回廊", 68)
	write(Vector2(63,183), "借来的明天", 23, DIM)
	var captions := [
		["01 / 寻人任务", "林岑失联了。事故调查处让你去晨区 B-17，核对他最后一次刷卡的记录。"],
		["02 / 两套时钟", "同一座空间站，晨暮两区的时间流速相差一千倍。两份记录上的时刻，不能直接比较。"],
		["03 / 你的第一步", "靠近物件按 E 调查。到 G 门按 E 换区；带齐现场记录，再回晨区 A-01 核验。"],
	]
	var page: int = game.intro_page
	slab(Rect2(48,476,1184,208),MINT,0.96)
	write(Vector2(74,523),captions[page][0],23)
	var lines := text_lines(captions[page][1],1100,18)
	for i in range(lines.size()):
		write(Vector2(74,560+i*27),lines[i],18,DIM)
	code(Vector2(76,652),"%02d / 03    阅读后继续，不会自动进入游戏" % (page+1),12)
	button(Rect2(694,621,210,42),"start","Space  跳过序幕",DIM)
	button(Rect2(920,621,282,42),"intro_next","Enter  进入调查" if page == 2 else "Enter  下一条")


func draw_hud() -> void:
	var accent := MINT if game.phase == 0 else AMBER
	draw_minimap()
	var objective_lines := text_lines(game.objective(),340,15)
	var hint_lines := text_lines(game.guidance(),340,12)
	var relay_lines := text_lines(game.relay_status(),340,12) if game.chapter == 2 else PackedStringArray()
	var objective_height := 33.0 + objective_lines.size() * 22.0
	var panel_height := objective_height + hint_lines.size() * 18.0 + 10.0
	if not relay_lines.is_empty(): panel_height += 6.0 + relay_lines.size() * 18.0
	draw_rect(Rect2(26,272,365,panel_height),Color(0.039,0.057,0.070,0.94))
	draw_rect(Rect2(26,272,2,panel_height),alpha(accent,0.82))
	write(Vector2(39,290),"当前目标",12,accent)
	for i in range(objective_lines.size()):
		write(Vector2(39,313+i*22),objective_lines[i],15)
	var hint_y := 289.0 + objective_height
	for i in range(hint_lines.size()):
		write(Vector2(39,hint_y+i*18),hint_lines[i],12,DIM)
	for i in range(relay_lines.size()):
		write(Vector2(39,hint_y+hint_lines.size()*18+6+i*18),relay_lines[i],12,AMBER)
	draw_rect(Rect2(1050, 28, 203, 76), Color(0.039, 0.057, 0.070, 0.78))
	write(Vector2(1064, 54), "断相脉冲", 14, WHITE)
	code(Vector2(1216, 54), "[F]", 12, accent)
	for index in range(2):
		draw_rect(Rect2(1064 + 87 * index, 68, 82, 3), alpha(accent, 0.88 if index < game.charges else 0.16))
	write(Vector2(1064, 90), game.save_label(), 11, DIM)
	if game.tactic_source == "deepseek":
		write(Vector2(1064, 120), "追债策略 / DeepSeek", 11, MINT)
	if game.threat > 0.0:
		var danger := Color(1.0, 0.13, 0.25, minf(0.75, game.threat))
		for border in [0.0, 5.0, 12.0]:
			draw_rect(Rect2(border, border, 1280 - border * 2, 720 - border * 2), alpha(danger, danger.a * (0.34 if border == 0.0 else 0.16)), false, 3.0)
		write(Vector2(1050, 147), game.threat_text(), 15, Color("f4a1a0"))
	draw_circle(Vector2(640, 360), 2.0, Color(0.06, 0.10, 0.13, 0.67))
	draw_circle(Vector2(640, 360), 1.1, WHITE)
	var prompt: String = game.interaction_prompt()
	if not prompt.is_empty():
		var prompt_width := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 42.0
		var prompt_left := 640.0 - prompt_width / 2.0
		draw_rect(Rect2(prompt_left, 544, prompt_width, 38), Color(0.035, 0.052, 0.065, 0.91))
		write(Vector2(prompt_left + 20, 569), prompt, 16)
	if game.note_timer > 0.0:
		var subtitle_lines := text_lines(game.notice,1080,17)
		var subtitle_height := 22.0 + subtitle_lines.size() * 24.0
		var subtitle_y := 687.0 - subtitle_height
		draw_rect(Rect2(79,subtitle_y,1122,subtitle_height),Color(0.033,0.046,0.054,0.93))
		for i in range(subtitle_lines.size()):
			write(Vector2(100,subtitle_y+27+i*24),subtitle_lines[i],17)
	if game.mode == "paused":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.028, 0.049, 0.65))
		slab(Rect2(491, 193, 300, 371), MINT)
		write(Vector2(519, 315), "调查暂停", 36)
		button(Rect2(520, 345, 242, 48), "resume", "Esc / Enter 继续调查")
		button(Rect2(520, 410, 242, 48), "quit", "保存后退出")
		button(Rect2(520, 474, 242, 34), "controls", "H  操作说明", DIM)
		button(Rect2(520, 520, 242, 31), "restart_prompt", "重新开始调查", DIM)


func draw_minimap() -> void:
	var focus: int = game.map_phase
	var alternate: bool = focus != game.phase
	var tint := MINT if focus == 0 else AMBER
	draw_rect(Rect2(26, 28, 233, 233), Color(0.040, 0.057, 0.068, 0.91))
	draw_line(Vector2(26, 28), Vector2(259, 28), alpha(tint, 0.62), 1.0)
	write(Vector2(40, 54), "暮区" if focus == 1 else "晨区", 17, tint)
	code(Vector2(170, 53), "CYCLE %02d" % game.laps, 11, DIM)
	draw_line(Vector2(40, 64), Vector2(244, 64), alpha(DIM, 0.22), 1.0)
	var projection := minimap_projection()
	var track := INK.lerp(tint, 0.24)
	for z in range(1, game.station.MAP_SIZE.y - 1):
		for x in range(1, game.station.MAP_SIZE.x - 1):
			var tile := Vector2i(x, z)
			if not game.station.walkable(focus, tile):
				continue
			var center := projection * Vector2(tile)
			draw_circle(center, 3.8, track, true, -1.0, true)
			for edge in [Vector2i.RIGHT, Vector2i.DOWN]:
				if game.station.walkable(focus, tile + edge):
					var step := projection.basis_xform(Vector2(edge))
					draw_line(center + step * 0.25, center + step * 0.75, track, 7.5, true)
			var mark := map_symbol(tile)
			if mark == "◇":
				draw_polyline(PackedVector2Array([center + Vector2(0, -3), center + Vector2(3, 0), center + Vector2(0, 3), center + Vector2(-3, 0), center + Vector2(0, -3)]), tint, 1.0, true)
				code(center + Vector2(5, 3), str(game.station.GATES.find(tile) + 1), 10, tint)
			elif not mark.is_empty():
				code(center + Vector2(-3, 3), mark, 10, tint)
	var position: Vector3 = game.player.position
	var player_mark := projection * (Vector2(position.x, position.z) / float(game.station.CELL))
	var tip := player_mark + Vector2(0, -7)
	var arrow := PackedVector2Array([tip, player_mark + Vector2(5, 5), player_mark + Vector2(0, 2), player_mark + Vector2(-5, 5)])
	draw_colored_polygon(arrow, WHITE)
	arrow.append(tip)
	draw_polyline(arrow, INK, 1.3, true)
	write(Vector2(40, 253), "另一时态预览" if alternate else "↑  视角朝上", 11, DIM)
	write(Vector2(174, 253), "M  切换", 11, tint)


func minimap_projection() -> Transform2D:
	var forward: Vector3 = -game.player.basis.z
	var rotation := -PI * 0.5 - Vector2(forward.x, forward.z).angle()
	var layout := Transform2D(rotation, Vector2.ZERO).scaled_local(Vector2.ONE * 11.6)
	var deck_center := (Vector2(game.station.MAP_SIZE) - Vector2.ONE) * 0.5
	layout.origin = Vector2(142.5, 153) - layout.basis_xform(deck_center)
	return layout


func map_symbol(tile: Vector2i) -> String:
	if tile in game.station.GATES:
		return "◇"
	if tile == game.station.AUDIT:
		return "A"
	if tile == game.station.OFFICE:
		return "B"
	if tile == game.station.LAB:
		return "C"
	if tile == game.station.MEDICAL:
		return "D"
	if tile == game.station.LEDGER:
		return "L"
	if tile == game.station.RELAY:
		return "R"
	return ""


func draw_terminal() -> void:
	var is_keypad: bool = game.mode == "keypad"
	var accent := AMBER if is_keypad else MINT
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.026, 0.034, 0.50))
	draw_rect(Rect2(103, 90, 1074, 564), Color(0.012, 0.018, 0.024, 0.42))
	draw_rect(Rect2(103, 77, 1074, 564), Color(0.067, 0.091, 0.106, 0.96))
	draw_rect(Rect2(103, 77, 271, 564), Color(0.042, 0.061, 0.073, 0.94))
	draw_rect(Rect2(103, 77, 1074, 564), alpha(DIM, 0.22), false, 1.0)
	draw_line(Vector2(374, 77), Vector2(374, 641), alpha(DIM, 0.20), 1.0)
	draw_line(Vector2(405, 165), Vector2(1145, 165), alpha(DIM, 0.22), 1.0)
	var terminal := "L-06  /  FINANCE" if is_keypad else "A-01  /  INCIDENT ARCHIVE"
	code(Vector2(130, 117), terminal, 12, accent)
	write(Vector2(406, 140), "终端身份核验" if is_keypad else "证据工作台", 30)
	button(Rect2(1022, 107, 123, 38), "resume", "Esc  返回", DIM)
	draw_case_index(accent, is_keypad)
	if is_keypad:
		draw_keypad(accent)
	else:
		draw_evidence(accent)
	if game.note_timer > 0.0:
		draw_line(Vector2(405, 594), Vector2(1145, 594), alpha(DIM, 0.21), 1.0)
		code(Vector2(406, 620), "SYSTEM", 11, accent)
		var notice_lines := text_lines(game.notice,650,14)
		for i in range(notice_lines.size()):
			write(Vector2(482,610+i*19),notice_lines[i],14,WHITE)


func draw_case_index(accent: Color, is_keypad: bool) -> void:
	var seal := Vector2(175, 184)
	draw_arc(seal, 35.0, 0.36, TAU - 0.32, 48, alpha(accent, 0.67), 1.4, true)
	draw_arc(seal, 26.0, 1.10, TAU + 0.67, 44, alpha(accent, 0.25), 1.0, true)
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		var ray := Vector2.from_angle(angle)
		draw_line(seal + ray * 30.0, seal + ray * 35.0, accent, 1.0, true)
	code(seal + Vector2(-10, 5), "R/A", 11, accent)
	write(Vector2(130, 258), "回廊事故调查处" if not is_keypad else "寿命配额管理局", 22)
	code(Vector2(131, 287), "CASE   /   LIN-CEN", 12, DIM)
	var chapter: String = game.chapter_title()
	var current := int(chapter.get_slice(" ", 0))
	var stages := ["同一扇门", "先发生的事", "谁签了字", "借出去的明天", "站外回执"]
	for index in range(stages.size()):
		var y := 341 + 48 * index
		var selected := index + 1 == current
		if selected:
			draw_rect(Rect2(118, y - 24, 241, 37), alpha(accent, 0.09))
			draw_rect(Rect2(118, y - 24, 2, 37), accent)
		code(Vector2(132, y), "%02d" % (index + 1), 12, accent if selected else DIM)
		write(Vector2(164, y), stages[index], 16, WHITE if selected else DIM)
	code(Vector2(131, 614), "TERMINAL   /   PRIVATE", 11, DIM)


func draw_evidence(accent: Color) -> void:
	write(Vector2(406, 575), game.audit_reflection(), 16, AMBER if game.chapter == 1 else DIM)
	var lines: Array = game.evidence_lines()
	var count := 0
	for line in lines:
		if not line.begins_with("未取得"):
			count += 1
	write(Vector2(406, 200), "现场记录", 16, DIM)
	code(Vector2(1108, 200), "%d / 3" % count, 12, accent)
	for index in range(lines.size()):
		var y := 238 + 43 * index
		var unlocked: bool = not lines[index].begins_with("未取得")
		draw_line(Vector2(406, y + 13), Vector2(1145, y + 13), alpha(DIM, 0.17), 1.0)
		code(Vector2(407, y), "%02d" % (index + 1), 12, accent if unlocked else DIM)
		write(Vector2(448, y), lines[index], 16, WHITE if unlocked else DIM)
		if unlocked:
			draw_polyline(PackedVector2Array([Vector2(1128, y - 6), Vector2(1132, y - 2), Vector2(1140, y - 10)]), accent, 1.7, true)
	if game.puzzle_available():
		if game.chapter == 0:
			draw_alignment(accent)
			return
		write(Vector2(407, 386), game.puzzle_question(), 22, WHITE)
		var choices: Array = game.puzzle_choices()
		for index in range(choices.size()):
			button(Rect2(406, 405 + index * 49, 739, 40), "choice_%d" % index, "%d    %s" % [index + 1, choices[index]], accent)
	elif game.ready_to_send():
		button(Rect2(406, 419, 350, 44), "send", "Enter  向站外发送完整账本", accent)
	else:
		write(Vector2(407, 385), "先按左上角目标取证，再回这里提交推理。", 17, DIM)
		if game.can_confirm_again():
			button(Rect2(406, 419, 350, 44), "accept", "确认接案 · 签收复核 A-42", AMBER)


func draw_alignment(accent: Color) -> void:
	write(Vector2(406, 376), "选出两项事件身份，对齐晨暮记录", 20, WHITE)
	var fields := ["device", "alarm", "clock"]
	var left := ["1  门禁  V-17", "2  警报  #043", "3  时钟  09:00:01"]
	var right := ["门禁  V-17", "警报  #043", "时钟  16:42:26"]
	for i in range(3):
		var y := 398.0 + i * 43.0
		var selected: bool = fields[i] in game.alignment_fields
		var color := accent if selected else DIM
		button(Rect2(406, y, 739, 37), "align_" + fields[i], "", color)
		write(Vector2(420, y + 25), "[√]" if selected else "[  ]", 16, color)
		code(Vector2(465, y + 25), left[i], 17, color)
		code(Vector2(875, y + 25), right[i], 17, color)
		if selected:
			draw_line(Vector2(710, y + 19), Vector2(848, y + 19), accent, 2.0, true)
	button(Rect2(406, 533, 739, 33), "align_submit", "Enter  核验关联    /    点击或按 1、2、3 选择与取消", accent)


func draw_keypad(accent: Color) -> void:
	code(Vector2(406, 206), "SETTLEMENT  /  CHALLENGE", 12, accent)
	write(Vector2(406, 246), "输入四位校验码", 24)
	write(Vector2(406, 285), "按扣款凭证输入：交易号末两位 + 扣除年数两位。", 16, DIM)
	if game.evidence[0]:
		write(Vector2(406, 322), game.evidence_lines()[0], 15)
	for index in range(4):
		var slot := Rect2(406 + 64 * index, 363, 54, 58)
		draw_rect(slot, alpha(accent, 0.065))
		draw_line(slot.end - Vector2(54, 0), slot.end, alpha(accent, 0.65), 1.0)
		var digit: String = game.keypad_entry.substr(index, 1) if index < game.keypad_entry.length() else "_"
		code(slot.position + Vector2(18, 39), digit, 26, accent)
	for index in range(9):
		var digit := str(index + 1)
		button(Rect2(920 + 70 * (index % 3), 231 + 53 * (index / 3), 60, 43), "key_" + digit, digit, accent)
	button(Rect2(920, 390, 60, 43), "key_back", "退格", DIM)
	button(Rect2(990, 390, 60, 43), "key_0", "0", accent)
	button(Rect2(1060, 390, 60, 43), "key_enter", "核验", accent)


func draw_ending() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.04, 0.07, 0.69))
	slab(Rect2(79, 110, 1122, 471), MINT)
	write(Vector2(115, 166), "R-03  /  站外回执已收到", 21, MINT)
	write(Vector2(115, 254), "收到。告诉我还有谁。", 54)
	write(Vector2(115, 340), "广播再次让你去找林岑。你还坐在调查台前。", 24, DIM)
	write(Vector2(115, 387), "你的左手握着已经传出去的那份账本的回执。", 24, DIM)
	button(Rect2(115, 495, 232, 48), "loop", "Enter  再走一圈")
	button(Rect2(369, 495, 185, 48), "quit", "保存后退出")
	button(Rect2(576, 495, 185, 48), "restart_prompt", "重新开始调查", DIM)


func draw_restart() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.04, 0.07, 0.78))
	slab(Rect2(375, 210, 530, 287), AMBER)
	write(Vector2(410, 290), "重新开始调查？", 30)
	write(Vector2(410, 340), "确认后清除本机章节与证据；取消则保留。", 18, DIM)
	button(Rect2(410, 405, 193, 45), "cancel_restart", "Esc  返回", MINT)
	button(Rect2(624, 405, 248, 45), "restart_case", "清除进度并开始新调查", AMBER)
