extends Control
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
var ink := Color("d9e3df")
var muted := Color("82969a")
var amber := Color("edb965")
var cyan := Color("85d7d0")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	show_touch = DisplayServer.is_touchscreen_available()

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
	if game.toast_time > 0 and game.mode != "title":
		var box := Rect2(24, 111, screen.x - 48, 38)
		draw_rect(box, Color(0.03, 0.07, 0.10, 0.93))
		draw_rect(Rect2(24, 111, 3, 38), amber)
		label_at(Vector2(38, 135), game.toast, 14, ink)
	if not game.last_save_ok:
		label_at(Vector2(24, screen.y - 160), game.saves.last_error, 14, Color("ff8a86"))

func label_at(point: Vector2, text: String, font_size: int = 16, color: Color = Color.WHITE) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func panel(rect: Rect2, color: Color = Color("14232d")) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color("34444e"), false, 1)

func button(id: String, rect: Rect2, text: String, primary: bool = false) -> void:
	buttons[id] = rect
	draw_rect(rect, amber if primary else Color("182b36"))
	draw_rect(rect, amber if primary else Color("4b6268"), false, 1)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	label_at(rect.position + Vector2((rect.size.x - width) * 0.5, rect.size.y * 0.5 + 5), text, 15, Color("19252d") if primary else ink)

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
	label_at(Vector2(31, 38), "DEPTH / SECTOR 07", 11, muted)
	label_at(Vector2(30, 72), "%03d" % game.depth(), 30, amber)
	label_at(Vector2(101, 71), "METERS", 11, ink)
	panel(Rect2(199, 16, 270, 75))
	label_at(Vector2(213, 39), "DR-07  /  " + ("DRILL ONLINE" if game.mounted else "EXPLORER ON FOOT"), 12, ink)
	var hp: float = game.hull if game.mounted else game.health
	var maximum: float = 100 if game.mounted else game.max_health()
	draw_rect(Rect2(214, 56, 171, 7), Color("35404a"))
	draw_rect(Rect2(214, 56, 171 * clampf(hp / maximum, 0, 1), 7), cyan if hp > 30 else Color("ed7b75"))
	label_at(Vector2(397, 65), "%d%%" % int(hp / maximum * 100), 13, ink)
	var right := screen.x - 244
	panel(Rect2(right, 16, 151, 75))
	label_at(Vector2(right + 13, 38), "CARGO", 11, muted)
	label_at(Vector2(right + 13, 70), "%02d / %02d" % [game.progress.cargo_count(), game.progress.capacity()], 23, amber)
	button("pause", Rect2(screen.x - 79, 16, 61, 34), "II")
	button("mute", Rect2(screen.x - 79, 56, 61, 35), "SFX" if not game.sounds.muted else "MUTE")
	var objective := "Mine copper > upgrade your drill bay" if game.progress.drill_level == 0 else "Find the regulator in the old pumping station"
	if game.progress.regulator:
		objective = "Return with the regulator > construct your workshop" if not game.progress.workshop else "Explore deeper > find blue crystals for living quarters"
	if not show_touch:
		panel(Rect2(18, screen.y - 63, screen.x - 36, 45))
		label_at(Vector2(32, screen.y - 35), objective, 14, ink)
		button("interact", Rect2(screen.x - 324, screen.y - 120, 152, 43), "E  DISMOUNT" if game.mounted else "E  BOARD")
		button("return", Rect2(screen.x - 161, screen.y - 120, 143, 43), "R  COLONY", game.near_lift() and game.mounted)
		label_at(Vector2(23, screen.y - 82), "WASD move  ·  E board  ·  Space boost  ·  Aim + click fire", 12, muted)
	else:
		_draw_touch(screen)
	if not game.mounted:
		var direction: Vector2 = game.rig_pos - game.foot_pos
		label_at(Vector2(25, 177), "RIG  %dm  %s" % [int(direction.length() / 4), ">" if direction.x > 0 else "<"], 12, amber)
		label_at(Vector2(25, 197), "BOOST  %d%%" % int(game.jet / 1.4 * 100), 12, cyan)
	if game.paused:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.04, 0.06, 0.86))
		label_at(screen * 0.5 + Vector2(-89, -47), "EXPEDITION PAUSED", 20, ink)
		label_at(screen * 0.5 + Vector2(-113, -13), "Progress saved. Take your time.", 15, muted)
		button("resume", Rect2(screen * 0.5 + Vector2(-100, 18), Vector2(200, 52)), "RESUME", true)
		button("recover", Rect2(screen * 0.5 + Vector2(-164, 88), Vector2(328, 45)), "RECOVER RIG / LOSE HALF CARGO")

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
		button("boost", Rect2(screen.x - 253, screen.y - 92, 79, 58), "BOOST")
	button("interact", Rect2(screen.x - 170, screen.y - 215, 148, 48), "DISMOUNT" if game.mounted else "BOARD")
	button("return", Rect2(screen.x - 170, screen.y - 272, 148, 48), "COLONY", game.near_lift() and game.mounted)

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
	_room(Rect2(30 + offset, 169, 397, 128), "DRILL BAY", "LEVEL %d  ·  CARGO %d" % [game.progress.drill_level, game.progress.capacity()], true, 0)
	_room(Rect2(529 + offset, 169, 397, 128), "WORKSHOP", "HIGH-IMPACT ROUNDS" if game.progress.workshop else "RECOVER THE REGULATOR", game.progress.workshop, 1)
	_room(Rect2(30 + offset, 316, 397, 128), "LIVING QUARTERS", "+25 MAXIMUM HEALTH" if game.progress.quarters else "ROOM FOR A TOMORROW", game.progress.quarters, 2)
	panel(Rect2(529 + offset, 316, 397, 128), Color("111f29"))
	label_at(Vector2(550 + offset, 345), "NEXT EXPEDITION", 13, cyan)
	label_at(Vector2(550 + offset, 374), "Amber seams supply your drill bay.", 14, ink)
	label_at(Vector2(550 + offset, 400), "The old station holds a lost regulator.", 14, muted)
	label_at(Vector2(550 + offset, 426), "Blue crystals wait below 200 meters.", 14, muted)
	button("drill", Rect2(45 + offset, 251, 225, 34), "UPGRADE  ·  %d COPPER" % (10 + game.progress.drill_level * 10) if game.progress.drill_level < 3 else "FULLY UPGRADED")
	button("workshop", Rect2(545 + offset, 251, 260, 34), "OPERATIONAL" if game.progress.workshop else "BUILD  ·  8 COPPER + REGULATOR")
	button("quarters", Rect2(45 + offset, 398, 268, 34), "INHABITED" if game.progress.quarters else "BUILD  ·  12 COPPER + 3 CRYSTAL")
	button("depart", Rect2(screen.x - 292, screen.y - 69, 264, 47), "DESCEND TO THE MINE   v", true)
	label_at(Vector2(30 + offset, screen.y - 39), "Haul banked. Tunnels preserved. Equipment restored.", 13, muted)

func _room(rect: Rect2, title: String, subtitle: String, built: bool, kind: int) -> void:
	panel(rect, Color("2d2a25") if built else Color("16232b"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), amber if built else Color("45545c"))
	label_at(rect.position + Vector2(15, 28), title, 17, amber if built else muted)
	label_at(rect.position + Vector2(15, 54), subtitle, 11, ink if built else muted)
	if built:
		var x := rect.end.x - 93
		var y := rect.position.y + 46
		for i in 3:
			draw_rect(Rect2(x + i * 25, y, 18, 25), Color("5b6056"))
			draw_rect(Rect2(x + i * 25 + 3, y + 3, 12, 4), amber if kind == 0 else cyan)
		for i in 2:
			var p := Vector2(x + 17 + i * 36, y + 53)
			draw_rect(Rect2(p - Vector2(4, 14), Vector2(8, 13)), Color("c9a068"))
			draw_rect(Rect2(p - Vector2(3, 20), Vector2(6, 6)), Color("decbb1"))
			draw_line(p, p + Vector2(-3, 8), Color("6c7e84"), 3)
			draw_line(p + Vector2(3, 0), p + Vector2(5, 8), Color("6c7e84"), 3)
	else:
		for i in 5:
			var x := rect.end.x - 110 + i * 18
			draw_line(Vector2(x, rect.position.y + 20), Vector2(x - 27, rect.position.y + 73), Color("273b45"), 2)

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
		if game.mode == "mine" and not game.paused and event.position.y > screen.y * 0.4:
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
		if game.paused and id not in ["resume", "pause", "recover"]:
			return true
		match id:
			"start": game.start_game()
			"interact": game.interact()
			"return": game.return_to_colony()
			"depart": game.depart()
			"drill", "workshop", "quarters": game.build_room(id)
			"mute": game.sounds.muted = not game.sounds.muted
			"recover":
				game.paused = false
				game.recover()
			"pause", "resume":
				game.paused = not game.paused
				game.clear_controls()
				game.save_game()
		return true
	return false
