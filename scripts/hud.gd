extends Control
const ColonyView = preload("res://scripts/colony_view.gd")
## Screen-space UI and real multi-touch controls. No DOM overlay is required.
var game: Node2D
var font: Font
var buttons: Dictionary = {}
var move_finger := -1
var aim_finger := -1
var boost_finger := -1
var move_origin := Vector2.ZERO
var aim_origin := Vector2.ZERO
var show_touch := false
var controls_selected := false
var ink := Color("d9e3df")
var muted := Color("82969a")
var amber := Color("edb965")
var cyan := Color("85d7d0")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	show_touch = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		show_touch = show_touch or JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches") == true

func _draw() -> void:
	buttons.clear()
	var screen := get_viewport_rect().size
	if screen.y > screen.x:
		draw_rect(Rect2(Vector2.ZERO, screen), Color("0b1721"))
		label_at(Vector2(30, screen.y / 2 - 20), "TURN YOUR DEVICE", 26, amber)
		label_at(Vector2(30, screen.y / 2 + 17), "BELOW plays in landscape.", 17, ink)
		return
	if game.mode == "title":
		_draw_title(screen)
	elif game.mode == "colony":
		_draw_colony(screen)
	else:
		_draw_mine(screen)
	if game.toast_time > 0 and game.mode != "title" and not game.paused and not game.map_open:
		var box := Rect2(24, 111, screen.x - 48, 38)
		draw_rect(box, Color(0.03, 0.07, 0.10, 0.93))
		draw_rect(Rect2(24, 111, 3, 38), amber)
		fit_label(Vector2(38, 135), game.toast, screen.x - 76, 14, ink)
	if not game.last_save_ok:
		label_at(Vector2(24, screen.y - 160), game.saves.last_error, 14, Color("ff8a86"))

func label_at(point: Vector2, text: String, font_size: int = 16, color: Color = Color.WHITE) -> void:
	if show_touch and font_size < 18:
		font_size = 18
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func fit_label(point: Vector2, text: String, width: float, size: int, color: Color) -> void:
	var pixels := maxi(16, size) if show_touch else size
	while pixels > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
		pixels -= 1
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, width, pixels, color)

func panel(rect: Rect2, color: Color = Color("14232d")) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color("34444e"), false, 1)

func button(id: String, rect: Rect2, text: String, primary: bool = false) -> void:
	buttons[id] = rect
	draw_rect(rect, amber if primary else Color("182b36"))
	draw_rect(rect, amber if primary else Color("4b6268"), false, 1)
	var text_size := 18 if show_touch else 15
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	while width > rect.size.x - 12 and text_size > 11:
		text_size -= 1
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_string(font, rect.position + Vector2((rect.size.x - width) * 0.5, rect.size.y * 0.5 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color("19252d") if primary else ink)

func _draw_title(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.045, 0.07, 0.78))
	var x := maxf(48, (screen.x - 850) * 0.5)
	label_at(Vector2(x, 69), "PROJECT GAUNTLET     /     PLAYABLE DEVELOPMENT BUILD", 12, amber)
	draw_line(Vector2(x, 87), Vector2(screen.x - x, 87), Color("415059"), 1)
	label_at(Vector2(x - 5, 217), "BELOW", 111, Color("f1e1c4"))
	label_at(Vector2(x + 1, 251), "WE BUILD WHAT COMES NEXT.", 19, amber)
	label_at(Vector2(x, 299), "The surface is lost. The depths are not.", 19, ink)
	label_at(Vector2(x, 328), "Drill for resources. Explore on foot. Bring your colony to life.", 16, muted)
	button("start", Rect2(x, 369, 258, 54), "CONTINUE EXPEDITION" if not game.loaded.is_empty() else "BEGIN EXPEDITION   >", true)
	label_at(Vector2(x, 454), "MOVE  WASD / arrows     BOARD  E     FIRE  mouse / F     BOOST  space", 12, muted)
	label_at(Vector2(x, 479), "Touch controls appear automatically on phones and tablets.", 12, muted)
	label_at(Vector2(screen.x - 175, screen.y - 24), "SOLO  ·  SECTOR 07", 12, amber)

func _draw_mine(screen: Vector2) -> void:
	panel(Rect2(18, 16, 169, 75))
	label_at(Vector2(31, 38), "DEPTH" if show_touch else "DEPTH / SECTOR 07", 11, muted)
	label_at(Vector2(30, 72), "%03d" % game.depth(), 30, amber)
	label_at(Vector2(101, 71), "METERS", 11, ink)
	panel(Rect2(199, 16, 270, 75))
	label_at(Vector2(213, 39), "DR-07  /  " + ("DRILL ONLINE" if game.mounted else "EXPLORER ON FOOT"), 12, ink)
	var hp: float = game.hull if game.mounted else game.health
	var maximum: float = game.max_hull() if game.mounted else game.max_health()
	draw_rect(Rect2(214, 56, 171, 7), Color("35404a"))
	draw_rect(Rect2(214, 56, 171 * clampf(hp / maximum, 0, 1), 7), cyan if hp > 30 else Color("ed7b75"))
	label_at(Vector2(397, 65), "%d%%" % int(hp / maximum * 100), 13, ink)
	var right := screen.x - 342
	panel(Rect2(right, 16, 151, 75))
	label_at(Vector2(right + 13, 38), "CARGO", 11, muted)
	label_at(Vector2(right + 13, 70), "%02d / %02d" % [game.progress.cargo_count(), game.progress.capacity()], 23, amber)
	button("map", Rect2(screen.x - 179, 16, 75, 75), "MAP")
	button("pause", Rect2(screen.x - 93, 16, 75, 75), "II")
	var objective: String = game.progress.objective()
	if not show_touch:
		panel(Rect2(18, screen.y - 63, screen.x - 36, 45))
		fit_label(Vector2(32, screen.y - 35), objective, screen.x - 64, 14, ink)
		button("interact", Rect2(screen.x - 324, screen.y - 120, 152, 43), "E  DISMOUNT" if game.mounted else "E  BOARD")
		button("return", Rect2(screen.x - 161, screen.y - 120, 143, 43), "R  COLONY", game.near_lift() and game.mounted)
		label_at(Vector2(23, screen.y - 82), "WASD move  ·  E board  ·  Space boost  ·  Tab map", 12, muted)
	else:
		_draw_touch(screen)
	if not game.mounted:
		var direction: Vector2 = game.rig_pos - game.foot_pos
		label_at(Vector2(25, 177), "RIG  %dm  %s" % [int(direction.length() / 4), ">" if direction.x > 0 else "<"], 12, amber)
		label_at(Vector2(25, 197), "BOOST  %d%%" % int(game.jet / game.max_jet() * 100), 12, cyan)
		if not show_touch:
			var reticle: Vector2 = game.foot_pos - game.camera_pos + game.camera_offset + screen * 0.5 + game.weapon_direction * 95
			var tint := Color("fff1ba") if game.hit_marker > 0 else Color(0.83, 0.91, 0.87, 0.7)
			for side in [-1, 1]:
				draw_line(reticle + Vector2(side * 4, 0), reticle + Vector2(side * 9, 0), tint, 1)
				draw_line(reticle + Vector2(0, side * 4), reticle + Vector2(0, side * 9), tint, 1)
	if game.hurt_cooldown > 0.4 and not game.reduced_motion:
		draw_rect(Rect2(Vector2(2, 2), screen - Vector2(4, 4)), Color(0.9, 0.29, 0.25, (game.hurt_cooldown - 0.4) * 1.6), false, 5)
	if game.map_open:
		_draw_map(screen)
	if game.paused:
		buttons.clear()
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.04, 0.06, 0.86))
		var center := screen * 0.5
		panel(Rect2(center + Vector2(-260, -211), Vector2(520, 422)), Color("10212b"))
		label_at(center + Vector2(-226, -168), "EXPEDITION PAUSED", 24, ink)
		label_at(center + Vector2(-226, -137), "Progress saved." if game.last_save_ok else "Save unavailable. Keep this session open.", 16, muted)
		button("resume", Rect2(center + Vector2(-226, -116), Vector2(452, 64)), "RESUME EXPEDITION", true)
		button("controls", Rect2(center + Vector2(-226, -42), Vector2(452, 64)), "CONTROLS: TOUCH" if show_touch else "CONTROLS: KEYBOARD + MOUSE")
		button("mute", Rect2(center + Vector2(-226, 32), Vector2(218, 64)), "AUDIO: OFF" if game.sounds.muted else "AUDIO: ON")
		button("motion", Rect2(center + Vector2(8, 32), Vector2(218, 64)), "MOTION: REDUCED" if game.reduced_motion else "MOTION: FULL")
		button("recover", Rect2(center + Vector2(-226, 106), Vector2(452, 64)), "RECOVER RIG / LOSE HALF CARGO")
		label_at(center + Vector2(-226, 183), "Recovery returns your rig to the colony lift.", 14, muted)

func _draw_map(screen: Vector2) -> void:
	buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.025, 0.055, 0.08, 0.98))
	label_at(Vector2(30, 44), "SECTOR 07 / GROUND SURVEY", 24, ink)
	label_at(Vector2(30, 73), "Survey grows as you explore. Expedition paused.", 15, muted)
	button("map", Rect2(screen.x - 174, 24, 144, 64), "CLOSE MAP", true)
	var scale := minf((screen.x - 340) / MineTerrain.WIDTH, (screen.y - 132) / MineTerrain.HEIGHT)
	var map_size := Vector2(MineTerrain.WIDTH, MineTerrain.HEIGHT) * scale
	var origin := Vector2((screen.x - map_size.x) * 0.5, 108)
	panel(Rect2(origin - Vector2(4, 4), map_size + Vector2(8, 8)), Color("07121b"))
	for key in game.survey:
		var id := int(key)
		var cell := Vector2i(id % MineTerrain.WIDTH, id / MineTerrain.WIDTH)
		var material: int = game.terrain.at(cell)
		var color := Color("314452")
		match material:
			MineTerrain.Tile.AIR: color = Color("111f2b")
			MineTerrain.Tile.COPPER: color = amber
			MineTerrain.Tile.CRYSTAL: color = cyan
			MineTerrain.Tile.BEDROCK: color = Color("58616d")
		draw_rect(Rect2(origin + Vector2(cell) * scale, Vector2.ONE * scale), color)
	# Survey markers never reveal undiscovered objectives or enemy positions.
	_map_marker(origin, scale, game.ENTRY, "LIFT", amber)
	if game.surveyed(game.RELIC):
		_map_marker(origin, scale, game.RELIC, "OLD STATION", cyan)
	if game.surveyed(game.ARCHIVE):
		_map_marker(origin, scale, game.ARCHIVE, "ARCHIVE", Color("c9a2ef"))
	var player: Vector2 = game.rig_pos if game.mounted else game.foot_pos
	var p := origin + player / MineTerrain.TILE * scale
	if not game.mounted:
		var rig: Vector2 = origin + game.rig_pos / MineTerrain.TILE * scale
		draw_rect(Rect2(rig - Vector2(4, 3), Vector2(8, 6)), amber)
	draw_circle(p, 5, Color("f8eee0"))
	draw_arc(p, 9, 0, TAU, 20, Color("f8eee0"), 1)
	label_at(Vector2(30, 136), "LEGEND", 13, muted)
	for i in 4:
		var colors := [amber, cyan, Color("f8eee0"), Color("314452")]
		var labels := ["Copper", "Crystal", "You", "Surveyed rock"]
		draw_rect(Rect2(30, 158 + i * 32, 8, 8), colors[i])
		label_at(Vector2(47, 167 + i * 32), labels[i], 14, ink)
	fit_label(Vector2(30, screen.y - 16), game.progress.objective(), screen.x - 60, 16, amber)
	var right := origin.x + map_size.x + 24
	label_at(Vector2(right, 137), "RETURN ROUTE", 13, amber)
	label_at(Vector2(right, 166), "Follow your tunnels", 13, ink)
	label_at(Vector2(right, 189), "to the amber lift.", 13, ink)
	label_at(Vector2(right, 226), "Bank your cargo", 13, muted)
	label_at(Vector2(right, 249), "before going deeper.", 13, muted)

func _map_marker(origin: Vector2, scale: float, point: Vector2, title: String, color: Color) -> void:
	var p := origin + point / MineTerrain.TILE * scale
	draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), color, false, 2)
	label_at(p + Vector2(11, 5), title, 11, color)

func _draw_touch(screen: Vector2) -> void:
	var left := move_origin if move_finger >= 0 else Vector2(104, screen.y - 97)
	draw_circle(left, 62, Color(0.10, 0.19, 0.23, 0.7))
	draw_arc(left, 62, 0, TAU, 36, Color("728e91"), 2)
	draw_circle(left + game.touch_move * 38, 24, Color(0.75, 0.86, 0.84, 0.5))
	label_at(left + Vector2(-21, 85), "MOVE", 11, muted)
	if not game.mounted:
		var right := aim_origin if aim_finger >= 0 else Vector2(screen.x - 103, screen.y - 100)
		draw_circle(right, 59, Color(0.30, 0.21, 0.12, 0.65))
		draw_arc(right, 59, 0, TAU, 36, amber, 2)
		draw_circle(right + game.touch_aim * 34, 18, amber)
		label_at(right + Vector2(-29, 82), "AIM / FIRE", 11, muted)
		button("boost", Rect2(screen.x - 271, screen.y - 101, 96, 68), "BOOST")
	button("interact", Rect2(screen.x - 185, screen.y - 241, 161, 64), "DISMOUNT" if game.mounted else "BOARD")
	button("return", Rect2(screen.x - 364, screen.y - 241, 161, 64), "COLONY", game.near_lift() and game.mounted)

func _draw_colony(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color("0c1821"))
	var offset := (screen.x - 960) * 0.5
	label_at(Vector2(30 + offset, 42), "OUTPOST 07", 27, Color("eedabe"))
	label_at(Vector2(31 + offset, 68), "A LITTLE FURTHER FROM THE END.", 11, muted)
	label_at(Vector2(481 + offset, 39), "COPPER   %d     CRYSTAL   %d" % [game.progress.copper, game.progress.crystal], 17, amber)
	label_at(Vector2(481 + offset, 66), "CREDITS  %d     DEEPEST  %dm" % [game.progress.credits, game.progress.deepest], 12, muted)
	# The central lift physically connects the visible room floors.
	draw_rect(Rect2(447 + offset, 170, 62, 290), Color("202e36"))
	for x in [455, 499]:
		draw_line(Vector2(x + offset, 170), Vector2(x + offset, 460), Color("69736f"), 3)
	for y in range(180, 461, 32):
		draw_line(Vector2(454 + offset, y), Vector2(500 + offset, y), Color("495961"), 2)
	draw_rect(Rect2(459 + offset, 217, 35, 42), Color("b89450"))
	_room(Rect2(30 + offset, 149, 397, 146), "DRILL BAY", "LEVEL %d  ·  CARGO %d" % [game.progress.drill_level, game.progress.capacity()], true, 0)
	_room(Rect2(529 + offset, 149, 397, 146), "WORKSHOP", "HIGH-IMPACT ROUNDS" if game.progress.workshop else "RECOVER THE REGULATOR", game.progress.workshop, 1)
	_room(Rect2(30 + offset, 312, 397, 146), "LIVING QUARTERS", "+25 MAXIMUM HEALTH" if game.progress.quarters else "ROOM FOR A TOMORROW", game.progress.quarters, 2)
	_room(Rect2(529 + offset, 312, 397, 146), "RESEARCH LAB", "HULL 150 / BOOST +50%" if game.progress.research else ("ARCHIVE RECOVERED" if game.progress.archive else "FIND THE ARCHIVE AT 350m"), game.progress.research, 3)
	button("drill", Rect2(45 + offset, 251, 225, 34), "UPGRADE  ·  %d COPPER" % (10 + game.progress.drill_level * 10) if game.progress.drill_level < 3 else "FULLY UPGRADED")
	button("workshop", Rect2(545 + offset, 251, 350, 34), "OPERATIONAL" if game.progress.workshop else "BUILD  ·  8 COPPER + REGULATOR")
	button("quarters", Rect2(45 + offset, 414, 350, 34), "INHABITED" if game.progress.quarters else "BUILD  ·  12 COPPER + 3 CRYSTAL")
	button("research", Rect2(545 + offset, 414, 350, 34), "OPERATIONAL" if game.progress.research else "BUILD / 8 CRYSTALS + 120 CREDITS")
	# Whole rooms are tap targets, including their labels and decoration.
	buttons["drill"] = Rect2(30 + offset, 149, 397, 146)
	buttons["workshop"] = Rect2(529 + offset, 149, 397, 146)
	buttons["quarters"] = Rect2(30 + offset, 312, 397, 146)
	buttons["research"] = Rect2(529 + offset, 312, 397, 146)
	button("depart", Rect2(screen.x - 292, screen.y - 69, 264, 47), "DESCEND TO THE MINE   v", true)
	label_at(Vector2(30 + offset, screen.y - 39), "Haul banked. Tunnels preserved. Equipment restored.", 13, muted)

func _room(rect: Rect2, title: String, subtitle: String, built: bool, kind: int) -> void:
	panel(rect, Color("2d2a25") if built else Color("16232b"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), amber if built else Color("45545c"))
	label_at(rect.position + Vector2(15, 24), title, 17, amber if built else muted)
	label_at(rect.position + Vector2(15, 43), subtitle, 11, ink if built else muted)
	ColonyView.draw_room(self, Rect2(rect.position + Vector2(15, 48), Vector2(367, 54)), kind, built, 0.0 if game.reduced_motion else game.elapsed, game.progress.drill_level)

func clear_touches() -> void:
	move_finger = -1
	aim_finger = -1
	boost_finger = -1

func handle_event(event: InputEvent) -> bool:
	var screen := get_viewport_rect().size
	if screen.y > screen.x:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and game.mode == "title":
			game.start_game()
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		return _click(event.position)
	if event is InputEventScreenTouch:
		if event.pressed and not controls_selected:
			show_touch = true
		if not event.pressed:
			if event.index == move_finger:
				move_finger = -1
				game.touch_move = Vector2.ZERO
			if event.index == aim_finger:
				aim_finger = -1
				game.touch_fire = false
				game.touch_aim = Vector2.ZERO
			if event.index == boost_finger:
				boost_finger = -1
				game.touch_boost = false
			return true
		if buttons.has("boost") and buttons.boost.has_point(event.position) and not game.paused:
			boost_finger = event.index
			game.touch_boost = true
			return true
		if _click(event.position):
			return true
		if game.mode == "mine" and not game.paused and not game.map_open and event.position.y > screen.y * 0.4:
			if event.position.x < screen.x * 0.45 and move_finger < 0:
				move_finger = event.index
				move_origin = event.position
			elif event.position.x > screen.x * 0.55 and aim_finger < 0 and not game.mounted:
				aim_finger = event.index
				aim_origin = event.position
				game.touch_fire = true
		return true
	if event is InputEventScreenDrag:
		if event.index == move_finger:
			game.touch_move = ((event.position - move_origin) / 48).limit_length()
		if event.index == aim_finger:
			game.touch_aim = ((event.position - aim_origin) / 44).limit_length()
		return true
	return false

func _click(point: Vector2) -> bool:
	for id in buttons:
		if not buttons[id].has_point(point):
			continue
		if game.paused and id not in ["resume", "pause", "recover", "controls", "mute", "motion"]:
			return true
		if game.map_open and not game.paused and id != "map":
			return true
		match id:
			"start": game.start_game()
			"interact": game.interact()
			"return": game.return_to_colony()
			"depart": game.depart()
			"drill", "workshop", "quarters", "research": game.build_room(id)
			"map": game.toggle_map()
			"mute":
				game.sounds.muted = not game.sounds.muted
				game.save_game()
			"motion":
				game.reduced_motion = not game.reduced_motion
				game.save_game()
			"controls":
				show_touch = not show_touch
				controls_selected = true
				game.clear_controls()
				game.save_game()
			"recover":
				game.paused = false
				game.recover()
			"pause", "resume":
				game.paused = not game.paused
				game.clear_controls()
				game.save_game()
		return true
	return false
