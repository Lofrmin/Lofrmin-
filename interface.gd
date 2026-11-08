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
		"settings": draw_settings()
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
		button(Rect2(65,477,146,43), "controls", "H 操作说明", DIM)
		button(Rect2(225,477,86,43), "settings", "设置", DIM)
		button(Rect2(325,477,70,43), "quit", "退出", DIM)
		write(Vector2(65,561), "已归档：" + game.chapter_title(), 17)
		write(Vector2(65,590), "继续调查会回到 A-01，保留已归档证据。", 14, DIM)
	else:
		button(Rect2(65,420,330,45), "controls", "H  操作说明", DIM)
		button(Rect2(65,478,190,43), "settings", "音量与难度设置", DIM)
		button(Rect2(269,478,126,43), "quit", "Q  退出", DIM)
		write(Vector2(65,566), "第一步：前往晨区 B-17，核对门禁记录。", 15, DIM)
	code(Vector2(65,669), "01  EXPLORE   /   02  COMPARE   /   03  RETURN", 11, MINT)
	write(Vector2(65,694), "本机自动存档 · 建议戴耳机 · 覆盖旧调查前会再次确认", 12, DIM)


func draw_settings() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.008,0.016,0.024,0.86))
	slab(Rect2(240,75,800,575),MINT,0.98)
	code(Vector2(278,117), "PREFERENCES / 本机设置", 12)
	write(Vector2(278,163), "音量与调查难度", 30)
	write(Vector2(278,195), "音量即时生效 · 每次调整 10% · 0% 静音", 15, DIM)
	var rows := [["master", "总音量", game.options.master_volume], ["effects", "音效 / 脚步", game.options.effects_volume], ["alert", "追债人警报", game.options.alert_volume], ["ambience", "追逐氛围", game.options.ambience_volume]]
	for i in range(rows.size()):
		var row: Array = rows[i]
		var y := 229.0 + i * 57.0
		write(Vector2(280,y+26),row[1],18)
		draw_rect(Rect2(452,y+15,250,9),alpha(DIM,0.18))
		draw_rect(Rect2(452,y+15,250*float(row[2]),9),alpha(MINT,0.8))
		code(Vector2(722,y+26),"%3d%%" % roundi(float(row[2])*100),17)
		button(Rect2(812,y,72,38),"setting_"+row[0]+"_down","−",MINT)
		button(Rect2(902,y,72,38),"setting_"+row[0]+"_up","+",MINT)
	write(Vector2(280,505), "追债人数量", 18)
	for count in [1,2,3]:
		button(Rect2(452+(count-1)*176,477,164,40),"setting_hunters_%d" % count,("[选中] " if game.options.hunter_count == count else "")+"%d 名" % count,MINT if game.options.hunter_count == count else DIM)
	var active_count: Variant = game.get("lap_hunter_count")
	write(Vector2(280,548), "本轮 %d 名 / 下轮 %d 名 · 安全位置不足时少部署" % [int(active_count) if active_count!=null else 1,game.options.hunter_count], 15, DIM)
	var settings_notice: Variant = game.get("settings_notice")
	write(Vector2(280,575), str(settings_notice) if settings_notice != null and not str(settings_notice).is_empty() else "设置独立保存，不会清除章节与证据。", 14, AMBER if settings_notice != null and not str(settings_notice).is_empty() else DIM)
	button(Rect2(732,596,242,38),"settings_back","Esc / Enter  返回")


func draw_controls() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.008,0.016,0.024,0.82))
	slab(Rect2(200,83,880,560),MINT,0.98)
	code(Vector2(238,123), "FIELD MANUAL / 事故调查员操作手册", 12)
	write(Vector2(238,172), "先找记录，再回调查台核验。", 29)
	var keys := ["W A S D / 鼠标", "E", "Shift / F", "M / Tab", "Esc / H", "R（出现提示时）"]
	var descriptions := ["移动 / 环视", "调查物件；在 G 门切换晨区与暮区", "按住 Shift 短冲刺消耗体力，步行可恢复 / F 断相脉冲每轮两次", "大地图 / 预览另一时态，不会改变你所在的时态", "暂停 / 查看操作说明", "撤销本轮接案签字，保留已归档证据"]
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
	if game.field_task.active and game.mode == "world":
		draw_field_task()
	if game.phase == 1 and game.gate_lock > 0.0:
		draw_rect(Rect2(434, 26, 412, 40), Color("492831"))
		write(Vector2(450, 53), "换相门封锁 %.1f 秒  /  清算单位正在逼近" % game.gate_lock, 16, WHITE)
	if game.big_map and game.mode == "world":
		draw_big_map()
		return
	draw_minimap()
	if game.dev_mode:
		draw_dev_panel()
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
	draw_rect(Rect2(1050, 28, 203, 132 if game.tactic_source == "deepseek" else 120), Color(0.039, 0.057, 0.070, 0.88))
	write(Vector2(1064, 50), "断相脉冲", 13, WHITE)
	code(Vector2(1216, 50), "[F]", 11, accent)
	for index in range(2):
		draw_rect(Rect2(1064 + 87 * index, 61, 82, 3), alpha(accent, 0.88 if index < game.charges else 0.16))
	write(Vector2(1064, 84), game.save_label(), 10, DIM)
	# 体力：填充 + 数值 + 文字状态；低体力/耗尽不只靠颜色
	write(Vector2(1064, 106), "体力 %d%%" % roundi(game.stamina), 12, WHITE)
	code(Vector2(1216, 106), "SHIFT", 10, accent)
	draw_rect(Rect2(1064, 114, 174, 5), alpha(DIM, 0.25))
	draw_rect(Rect2(1064, 114, 174.0 * game.stamina / game.STAMINA_MAX, 5), alpha(AMBER if game.stamina < 25.0 else accent, 0.94))
	var stamina_hint := "步行恢复" if game.stamina < game.STAMINA_MAX else "可短冲刺"
	if game.stamina_regen_wait > 0.0 and not game.stamina_exhausted:
		stamina_hint = "恢复准备"
	if game.stamina_exhausted:
		stamina_hint = "耗尽 · 松开 Shift 至 25%" if game.stamina < game.STAMINA_RESTART_THRESHOLD else "已达 25% · 松开 Shift 解锁"
	write(Vector2(1064, 136), stamina_hint, 11, AMBER if game.stamina_exhausted else DIM)
	if game.tactic_source == "deepseek":
		write(Vector2(1064, 152), "追债策略 / DeepSeek", 11, MINT)
	if game.threat > 0.0:
		var danger := Color(1.0, 0.13, 0.25, minf(0.75, game.threat))
		for border in [0.0, 5.0, 12.0]:
			draw_rect(Rect2(border, border, 1280 - border * 2, 720 - border * 2), alpha(danger, danger.a * (0.34 if border == 0.0 else 0.16)), false, 3.0)
		write(Vector2(1050, 182), game.threat_text(), 15, Color("f4a1a0"))
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
		slab(Rect2(491, 193, 300, 407), MINT)
		write(Vector2(519, 315), "调查暂停", 36)
		button(Rect2(520, 345, 242, 48), "resume", "Esc / Enter 继续调查")
		button(Rect2(520, 410, 242, 48), "quit", "保存后退出")
		button(Rect2(520, 474, 242, 34), "controls", "H  操作说明", DIM)
		button(Rect2(520, 520, 242, 31), "settings", "音量与难度设置", DIM)
		button(Rect2(520, 563, 242, 26), "restart_prompt", "重新开始调查", DIM)


func draw_field_task() -> void:
	var task = game.field_task
	var tint := MINT if game.phase == 0 else AMBER
	draw_rect(Rect2(416, 312, 610, 214), Color(0.025, 0.045, 0.055, 0.94))
	draw_rect(Rect2(416, 312, 3, 214), tint)
	write(Vector2(435, 340), task.title(), 20, tint)
	write(Vector2(435, 367), task.instructions(), 14, WHITE)
	match task.kind:
		"circuit":
			var lights: Array = task.lamps()
			for index in range(3):
				var x := 500.0 + index * 160.0
				draw_circle(Vector2(x, 408), 14, MINT if lights[index] else Color("34464c"))
				code(Vector2(x - 22, 449), "[%d] %s" % [index + 1, "ON" if task.switches[index] else "OFF"], 14, tint)
			write(Vector2(435, 476), "线路图：① → 灯 A/C    ② → 灯 A/B    ③ → 灯 B", 14, DIM)
		"clock":
			for index in range(3):
				var center := Vector2(516 + index * 165, 422)
				draw_arc(center, 33, 0, TAU, 40, tint, 1.5, true)
				for tick in range(8):
					var direction := Vector2.from_angle(tick * TAU / 8.0 - PI / 2.0)
					draw_line(center + direction * 27, center + direction * 32, DIM, 1.0, true)
				var goal := Vector2.from_angle(task.targets[index] * TAU / 8.0 - PI / 2.0)
				draw_circle(center + goal * 33, 5, WHITE, false, 1.5, true)
				var pointer := Vector2.from_angle(task.dials[index] * TAU / 8.0 - PI / 2.0)
				draw_line(center, center + pointer * 25, tint, 3.0, true)
				code(center + Vector2(-28, 55), "[%d] %s" % [index + 1, "< >" if task.selection == index else ""], 14, WHITE)
		"silent":
			write(Vector2(435, 413), "静音读取  %.1f / 1.8 秒" % task.hold, 22, tint)
			write(Vector2(435, 452), "按住 E 保持读取；WASD / Shift 会打断", 16, DIM)
		"relay":
			for index in range(3):
				var x := 480.0 + index * 170.0
				draw_rect(Rect2(x, 396, 110, 54), alpha(tint, 0.3 if index < task.progress else 0.07))
				code(Vector2(x + 15, 430), "[%d] %s" % [index + 1, ["E-7", "OUT", "SYNC"][index]], 17, tint)
			write(Vector2(435, 478), "已接 %d / 3   ·   接线窗口 %.1f 秒" % [task.progress, task.remaining], 16, WHITE)
	if not task.message.is_empty():
		write(Vector2(435, 512), task.message, 13, AMBER)


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
			if not Rect2(34, 70, 217, 170).has_point(center):
				continue
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
	write(Vector2(150, 253), "M 大地图 · Tab 晨暮", 11, tint)


func minimap_projection() -> Transform2D:
	var forward: Vector3 = -game.player.basis.z
	var rotation := -PI * 0.5 - Vector2(forward.x, forward.z).angle()
	var layout := Transform2D(rotation, Vector2.ZERO).scaled_local(Vector2.ONE * 11.6)
	# 大地图：小地图以玩家为中心滚动（原来以整张地图中心为准，41×41 会画出框外）
	var deck_center := Vector2(game.player.position.x, game.player.position.z) / float(game.station.CELL)
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
		if game.chapter == 3:
			draw_timeline(accent)
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


func draw_timeline(accent: Color) -> void:
	write(Vector2(406,376),"共同起点是脉冲 0 秒。先换算，再依先后点选。",17,WHITE)
	write(Vector2(406,407),"暮区5000秒÷1000→晨区?秒｜↑扣款 ↓立案",15,DIM)
	draw_rect(Rect2(406,420,105,38),alpha(accent,0.09))
	draw_rect(Rect2(406,420,105,38),alpha(accent,0.58),false,1.0)
	code(Vector2(421,447),game.timeline_seconds if not game.timeline_seconds.is_empty() else "___",20,accent)
	for digit in range(1,10):
		var x := 535 + ((digit - 1) % 3) * 48
		var y := 422 + ((digit - 1) / 3) * 35
		button(Rect2(x,y,42,29),"timeline_digit_%d" % digit,str(digit),accent)
	button(Rect2(583,527,42,29),"timeline_digit_0","0",accent)
	button(Rect2(631,527,90,29),"timeline_back","退格",DIM)
	for id in ["debit","filing"]:
		var rank: int = game.timeline_order.find(id)
		var y := 426.0 if id == "debit" else 480.0
		var text := "暮区扣款名单5000s" if id == "debit" else "晨区寻人立案6s"
		var label := "%d｜%s" % [rank + 1,text] if rank >= 0 else "点选排序｜%s" % text
		button(Rect2(778,y,365,43),"timeline_pick_"+id,label,accent if rank >= 0 else DIM)
	button(Rect2(778,532,227,33),"timeline_submit","Enter  核验换算与顺序",accent)
	button(Rect2(1014,532,129,33),"timeline_clear","清空本题",DIM)


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


func draw_big_map() -> void:
	# 全屏大地图：北朝上、整张图，Tab 切晨暮，M 关闭
	var focus: int = game.map_phase
	var tint := MINT if focus == 0 else AMBER
	var station = game.station
	var cell_px := 14.0
	var side: float = cell_px * station.MAP_SIZE.x
	var origin := Vector2(640 - side * 0.5, 372 - side * 0.5)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.024, 0.031, 0.88))
	draw_rect(Rect2(origin - Vector2(14, 14), Vector2(side + 28, side + 28)), Color(0.040, 0.057, 0.068, 0.95))
	draw_rect(Rect2(origin - Vector2(14, 14), Vector2(side + 28, side + 28)), alpha(tint, 0.55), false, 1.0)
	var track := INK.lerp(tint, 0.30)
	for z in range(station.MAP_SIZE.y):
		for x in range(station.MAP_SIZE.x):
			var tile := Vector2i(x, z)
			var rect := Rect2(origin + Vector2(x, z) * cell_px, Vector2.ONE * (cell_px - 1.0))
			if station.walkable(focus, tile):
				draw_rect(rect, track)
	for tile in [station.AUDIT, station.OFFICE, station.LAB, station.RELAY, station.MEDICAL, station.LEDGER]:
		var at: Vector2 = origin + (Vector2(tile) + Vector2(0.5, 0.5)) * cell_px
		draw_circle(at, 8.0, tint, true, -1.0, true)
		code(at + Vector2(-4, 4), map_symbol(tile), 11, INK)
	for index in range(station.GATES.size()):
		var at: Vector2 = origin + (Vector2(station.GATES[index]) + Vector2(0.5, 0.5)) * cell_px
		draw_rect(Rect2(at - Vector2(8, 8), Vector2(16, 16)), WHITE)
		code(at + Vector2(-8, 4), "G%d" % (index + 1), 10, INK)
	var hunter_positions: Array[Vector3] = game.extra_hunter_positions() if focus == 1 else []
	if game.boss_live and game.boss_phase == focus: hunter_positions.append(game.boss.position)
	for hunter_position in hunter_positions:
		var hunter_mark := origin + (Vector2(hunter_position.x, hunter_position.z) / float(station.CELL) + Vector2(0.5, 0.5)) * cell_px
		draw_circle(hunter_mark, 6.0, Color("ff667b"), true, -1.0, true)
		code(hunter_mark + Vector2(-4, 4), "!", 11, INK)
	var position: Vector3 = game.player.position
	var mark: Vector2 = origin + (Vector2(position.x, position.z) / float(station.CELL) + Vector2(0.5, 0.5)) * cell_px
	var forward: Vector3 = -game.player.basis.z
	var turn := Transform2D(Vector2(forward.x, forward.z).angle() + PI * 0.5, mark)
	var arrow := PackedVector2Array([turn * Vector2(0, -9), turn * Vector2(6, 6), turn * Vector2(0, 3), turn * Vector2(-6, 6)])
	draw_colored_polygon(arrow, WHITE)
	arrow.append(arrow[0])
	draw_polyline(arrow, INK, 1.4, true)
	write(Vector2(origin.x - 14, origin.y - 26), ("暮区" if focus == 1 else "晨区") + " · 全图", 18, tint)
	if focus != game.phase:
		write(Vector2(origin.x + 120, origin.y - 26), "（另一时态，你的位置是同坐标）", 12, DIM)
	write(Vector2(origin.x + side - 210, origin.y - 26), "M 关闭 · Tab 切晨暮", 13, tint)
	write(Vector2(origin.x - 14, origin.y + side + 34), "A 调查台  B 办公室  C 时钟实验室  D 生命维持  L 结算  R 中继  G 换相门", 12, DIM)
	draw_rect(Rect2(25,130,300,112),Color(0.025,0.039,0.047,0.94))
	draw_rect(Rect2(25,130,2,112),Color("ff9a91") if game.boss_live else tint)
	write(Vector2(39,153),"实时地图：世界未暂停",14,WHITE)
	write(Vector2(39,177),"当前位置：" + ("暮区" if game.phase == 1 else "晨区"),13,tint)
	if game.boss_live:
		write(Vector2(39,199),game.threat_text(),13,Color("ff9a91"))
	write(Vector2(39,226),"M / Esc 收起，再按 Esc 暂停",12,DIM)



func draw_dev_panel() -> void:
	var story: int = game.STORY_ORDER.find(game.chapter) + 1
	var answer := "—"
	if game.chapter == 0:
		answer = "选 1 设备 + 2 警报，Enter"
	elif game.chapter == 3:
		answer = "5秒；扣款→立案"
	elif not game.solved:
		answer = "选 %d" % (game.ANSWERS[game.chapter] + 1)
	elif game.chapter == 2:
		answer = "已核验：开关→接线→外发"
	var lines := [
		"第 %d 步 / 章节 %s  ·  断点阶段 S%d  ·  %s" % [story, game.chapter_title(), game.station.map_stage, "晨区" if game.phase == 0 else "暮区"],
		"证据 %d/3  ·  追债人 %s  ·  无敌 %s" % [game.evidence.count(true), ("在场" if game.boss_live else "未部署"), ("开" if game.dev_god else "关")],
		"本章答案：%s" % answer,
		"F2 下一章   F3 传送(房间/门/断点)   F4 拿齐证据   F5 无敌",
		"F6 召唤/撤回追债人   F7 直接过本章（第 05 章逐步推进）   F1 关",
	]
	draw_rect(Rect2(820, 120, 434, 24 + 20 * lines.size()), Color(0.22, 0.03, 0.07, 0.88))
	draw_rect(Rect2(820, 120, 2, 24 + 20 * lines.size()), Color("ff315f"))
	for index in range(lines.size()):
		write(Vector2(834, 142 + 20 * index), lines[index], 12, WHITE if index < 3 else DIM)
