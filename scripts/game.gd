extends Node2D
## Authoritative solo simulation. Rendering and touch input are separate nodes.
const Terrain = preload("res://scripts/terrain.gd")
const Progress = preload("res://scripts/progression.gd")
const Saves = preload("res://scripts/save_store.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const RIG_HALF := Vector2(42, 18)
const FOOT_HALF := Vector2(10, 18)
const RIG_GRAVITY := 620.0
const RIG_FALL_SPEED := 360.0
const RIG_ASCENT_SPEED := 185.0
const ENTRY := Vector2(448, 272)
const RELIC := Vector2(1040, 744)
const ARCHIVE := Vector2(1100, 1670)

var terrain := Terrain.new()
var progress := Progress.new()
var saves := Saves.new()
var mode := "title"
var mounted := true
var rig_pos := ENTRY
var rig_velocity := Vector2.ZERO
var foot_pos := ENTRY + Vector2(-66, 0)
var foot_velocity := Vector2.ZERO
var facing := 1
var drill_direction := Vector2.RIGHT
var drilling := false
var health := 100.0
var hull := 100.0
var jet := 1.4
var camera_pos := ENTRY
var camera_offset := Vector2.ZERO
var camera_shake := 0.0
var weapon_direction := Vector2.RIGHT
var muzzle_flash := 0.0
var hit_marker := 0.0
var reduced_motion := false
var map_open := false
var survey: Dictionary = {}
var last_survey_cell := Vector2i(-999, -999)
var elapsed := 0.0
var fire_cooldown := 0.0
var hurt_cooldown := 0.0
var save_clock := 0.0
var drill_sound_clock := 0.0
var paused := false
var aim_point := Vector2.ZERO
var mouse_aim := false
var touch_move := Vector2.ZERO
var touch_aim := Vector2.ZERO
var touch_boost := false
var mouse_fire := false
var touch_fire := false
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var toast := ""
var toast_time := 0.0
var last_save_ok := true
var loaded: Dictionary = {}
var world: Node2D
var hud: Control
var sounds: Node
var world_light: PointLight2D
var ambient: CanvasModulate

func _ready() -> void:
	_setup_input()
	terrain.generate()
	_spawn_enemies()
	loaded = saves.read()
	last_save_ok = not saves.newer_version_found
	world = WorldView.new()
	world.game = self
	add_child(world)
	ambient = CanvasModulate.new()
	ambient.color = Color(0.64, 0.70, 0.79)
	add_child(ambient)
	world_light = _make_light(Color(1.0, 0.69, 0.32), 1.35, 580)
	world.add_child(world_light)
	var crystal_light := _make_light(Color(0.12, 0.75, 1.0), 1.6, 570)
	crystal_light.position = Vector2(1480, 1110)
	world.add_child(crystal_light)
	var station_light := _make_light(Color(1.0, 0.62, 0.22), 0.85, 480)
	station_light.position = Vector2(700, 235)
	world.add_child(station_light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Hud.new()
	hud.game = self
	canvas.add_child(hud)
	sounds = Sound.new()
	add_child(sounds)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gauntletReady = true;")

func _make_light(color: Color, energy: float, diameter: int) -> PointLight2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = diameter / 128.0
	light.color = color
	light.energy = energy
	return light

func _setup_input() -> void:
	var bindings := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "boost": [KEY_SPACE],
		"interact": [KEY_E], "return": [KEY_R], "pause_game": [KEY_ESCAPE], "fire": [KEY_F], "survey_map": [KEY_TAB, KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
	if hud != null and hud.handle_event(event):
		return
	if event is InputEventMouseMotion:
		aim_point = event.position
		mouse_aim = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_fire = event.pressed
	if event.is_action_pressed("interact") and not event.is_echo():
		interact()
	if event.is_action_pressed("return") and not event.is_echo():
		return_to_colony()
	if event.is_action_pressed("survey_map") and not event.is_echo():
		toggle_map()
	if event.is_action_pressed("pause_game") and not event.is_echo():
		if mode == "mine":
			if map_open:
				map_open = false
			else:
				paused = not paused
			clear_controls()
			save_game()

func clear_controls() -> void:
	touch_move = Vector2.ZERO
	touch_aim = Vector2.ZERO
	touch_boost = false
	touch_fire = false
	mouse_fire = false
	rig_velocity = Vector2.ZERO
	camera_offset = Vector2.ZERO
	for action in ["left", "right", "up", "down", "boost", "fire"]:
		Input.action_release(action)
	if hud != null:
		hud.clear_touches()

func toggle_map() -> void:
	if mode != "mine" or paused:
		return
	map_open = not map_open
	clear_controls()
	save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_controls()
		if mode == "mine":
			map_open = false
			paused = true
			save_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and mode != "title":
		save_game()

func start_game() -> void:
	if not loaded.is_empty():
		progress.restore(loaded.get("progress", {}))
		terrain.restore(loaded.get("terrain", {}))
		var state: Dictionary = loaded.get("player", {})
		rig_pos = _read_vector(state.get("rig", []), ENTRY)
		foot_pos = _read_vector(state.get("foot", []), ENTRY + Vector2(-66, 0))
		mounted = bool(state.get("mounted", true))
		health = clampf(float(state.get("health", 100)), 1, max_health())
		hull = clampf(float(state.get("hull", 100)), 1, max_hull())
		mode = "colony" if state.get("mode", "mine") == "colony" else "mine"
		var settings: Variant = loaded.get("settings", {})
		if settings is Dictionary:
			sounds.muted = settings.get("muted") is bool and settings.muted
			reduced_motion = settings.get("reduced_motion") is bool and settings.reduced_motion
			hud.controls_selected = settings.get("manual_controls") is bool and settings.manual_controls
			if hud.controls_selected and settings.get("touch_controls") is bool:
				hud.show_touch = settings.touch_controls
		var stored_survey: Variant = loaded.get("survey", {})
		if stored_survey is Dictionary:
			for key in stored_survey:
				if str(key).is_valid_int() and int(key) >= 0 and int(key) < Terrain.WIDTH * Terrain.HEIGHT:
					survey[str(key)] = true
		if terrain.blocked(rig_pos, RIG_HALF):
			rig_pos = ENTRY
		if terrain.blocked(foot_pos, FOOT_HALF):
			foot_pos = ENTRY + Vector2(-66, 0)
		enemies.clear()
		for enemy in loaded.get("enemies", []):
			if enemy is Dictionary and float(enemy.get("hp", 0)) > 0:
				enemies.append({"pos": _read_vector(enemy.get("pos", []), Vector2(800, 730)),
					"type": clampi(int(enemy.get("type", 0)), 0, 2), "hp": float(enemy.hp),
					"vy": 0.0, "cooldown": 1.0, "flash": 0.0})
		loaded.clear()
		notify("Expedition restored. Your colony remembers.")
	else:
		mode = "mine"
		notify("Hold a direction to drill. Mine copper below the lift.")
	camera_pos = rig_pos if mounted else foot_pos
	reveal_area()
	clear_controls()
	save_game()

func _read_vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() == 2:
		if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int):
			return fallback
		var point := Vector2(float(value[0]), float(value[1]))
		if point.is_finite() and point.x >= 0 and point.y >= 0 and point.x < Terrain.WIDTH * 32 and point.y < Terrain.HEIGHT * 32:
			return point
	return fallback

func _spawn_enemies() -> void:
	enemies.clear()
	for data in [[Vector2(790, 747), 0], [Vector2(960, 746), 1],
		[Vector2(1230, 1196), 0], [Vector2(1510, 1196), 2], [Vector2(1630, 1196), 1],
		[Vector2(840, 1678), 2]]:
		enemies.append({"pos": data[0], "type": data[1], "hp": 45.0 if data[1] < 2 else 90.0,
			"vy": 0.0, "cooldown": 1.5, "flash": 0.0})

func _physics_process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if mode == "mine" and get_viewport_rect().size.y > get_viewport_rect().size.x and not paused:
		paused = true
		map_open = false
		clear_controls()
		save_game()
	elapsed += dt
	toast_time = maxf(0, toast_time - dt)
	muzzle_flash = maxf(0, muzzle_flash - dt)
	hit_marker = maxf(0, hit_marker - dt)
	camera_shake = move_toward(camera_shake, 0, dt * 18)
	if mode == "mine" and not paused and not map_open:
		_step_player(dt)
		_step_enemies(dt)
		_step_bullets(dt)
		_step_particles(dt)
		fire_cooldown = maxf(0, fire_cooldown - dt)
		hurt_cooldown = maxf(0, hurt_cooldown - dt)
		var target := rig_pos if mounted else foot_pos
		var lead := rig_velocity * 0.18 if mounted else weapon_direction * 38
		if reduced_motion:
			lead = Vector2.ZERO
		camera_pos = camera_pos.lerp(target + lead, 1.0 - exp(-8.0 * dt))
		reveal_area()
		progress.deepest = maxi(progress.deepest, depth())
		save_clock += dt
		if save_clock >= 4.0:
			save_clock = 0
			save_game()
		if health <= 0 or hull <= 0:
			recover()
	if world != null:
		sounds.set_activity(mode == "mine" and not paused and not map_open, mounted, drilling, rig_velocity.length())
		camera_offset = Vector2.ZERO if reduced_motion or paused or map_open else Vector2(sin(elapsed * 71), cos(elapsed * 83)) * camera_shake
		world.position = (get_viewport_rect().size * 0.5 - camera_pos + camera_offset).round()
		world_light.position = rig_pos if mounted else foot_pos
		world.queue_redraw()
		hud.queue_redraw()

func _step_player(dt: float) -> void:
	var move := Input.get_vector("left", "right", "up", "down")
	if touch_move.length() > 0.12:
		move = touch_move.limit_length()
	if move.length() < 0.15:
		move = Vector2.ZERO
	drilling = false
	if mounted:
		if move.length() > 0.15:
			if absf(move.x) > absf(move.y):
				drill_direction = Vector2(signf(move.x), 0)
				facing = int(signf(move.x))
			else:
				drill_direction = Vector2(0, signf(move.y))
			var front := rig_pos + drill_direction * 8
			drilling = terrain.blocked(front, RIG_HALF)
			if drilling:
				var broken := terrain.drill(rig_pos, RIG_HALF, drill_direction, dt * (1 + progress.drill_level * 0.45), progress.capacity() - progress.cargo_count())
				for hit in broken:
					camera_shake = maxf(camera_shake, 1.8)
					var color := Color("e9a95a") if hit.material == Terrain.Tile.COPPER else Color("60dbed")
					if hit.material == Terrain.Tile.ROCK:
						color = Color("827e78")
					else:
						progress.collect(hit.material)
						if progress.cargo_count() == progress.capacity():
							notify("Cargo full. Return to the lift [R] to bank your haul.")
					burst(Vector2(hit.cell * 32) + Vector2(16, 16), color, 7)
				drill_sound_clock -= dt
				if drill_sound_clock <= 0:
					sounds.play_tone(65, 0.06, 0.13, true)
					drill_sound_clock = 0.10
		_step_rig(dt, move)
		return
	_step_rig(dt, Vector2.ZERO)
	var grounded := terrain.blocked(foot_pos + Vector2(0, 2), FOOT_HALF)
	if grounded:
		jet = minf(max_jet(), jet + dt * 2.4)
	foot_velocity.x = move.x * 165
	foot_velocity.y = minf(430, foot_velocity.y + 690 * dt)
	if (Input.is_action_pressed("boost") or touch_boost or move.y < -0.6) and jet > 0:
		foot_velocity.y = -195
		jet = maxf(0, jet - dt)
		if int(elapsed * 30) % 2 == 0:
			burst(foot_pos + Vector2(0, 17), Color("76d8eb"), 1)
	if absf(move.x) > 0.1:
		facing = int(signf(move.x))
	weapon_direction = aim_direction()
	var previous := foot_pos
	foot_pos = terrain.move_body(foot_pos, FOOT_HALF, foot_velocity * dt)
	if is_equal_approx(previous.y, foot_pos.y):
		foot_velocity.y = 0
	if (mouse_fire or touch_fire or Input.is_action_pressed("fire")) and fire_cooldown <= 0:
		shoot()
	if not progress.regulator and foot_pos.distance_to(RELIC) < 45:
		progress.regulator = true
		notify("REGULATOR RECOVERED — return home to build the workshop.")
		burst(RELIC, Color("8feee0"), 26)
		sounds.play_tone(880, 0.20, 0.2)
		save_game()
	if not progress.archive and foot_pos.distance_to(ARCHIVE) < 45 and _clear_line(foot_pos, ARCHIVE):
		progress.archive = true
		notify("ARCHIVE RECOVERED — lost engineering plans unlocked. Bring them home.")
		burst(ARCHIVE, Color("c9a2ef"), 26)
		sounds.play_tone(1100, 0.28, 0.2)
		save_game()

func _step_rig(dt: float, move: Vector2) -> void:
	# Treads brake horizontally; vertical momentum remains subject to gravity.
	rig_velocity.x = move_toward(rig_velocity.x, move.x * 185, (1550.0 if absf(move.x) > 0.15 else 2200.0) * dt)
	rig_velocity.y = minf(RIG_FALL_SPEED, rig_velocity.y + RIG_GRAVITY * dt)
	if move.y < -0.15:
		# Held ascent provides lift for the return journey. Releasing it never hovers.
		rig_velocity.y = move_toward(rig_velocity.y, move.y * RIG_ASCENT_SPEED, 1550.0 * dt)
	elif move.y > 0.15:
		rig_velocity.y = minf(RIG_FALL_SPEED, rig_velocity.y + move.y * 500.0 * dt)
	var previous := rig_pos
	var displacement := rig_velocity * dt
	rig_pos = terrain.move_body(rig_pos, RIG_HALF, displacement)
	var travel := rig_pos - previous
	# Cancel vertical momentum on a floor or ceiling, including partial swept travel.
	if absf(travel.y - displacement.y) > 0.01:
		rig_velocity.y = 0
	rig_velocity.x = travel.x / maxf(dt, 0.001)

func interact() -> void:
	if mode != "mine" or paused or map_open:
		return
	if mounted:
		for offset in [Vector2(-66, 0), Vector2(66, 0), Vector2(0, -48)]:
			if not terrain.blocked(rig_pos + offset, FOOT_HALF) and _has_landing(rig_pos + offset):
				foot_pos = rig_pos + offset
				foot_velocity = Vector2.ZERO
				mounted = false
				rig_velocity.x = 0
				jet = max_jet()
				notify("On foot. Aim + fire • Space to boost • E to board.")
				save_game()
				return
		notify("No safe landing. Park beside a ledge and clear space to dismount.")
	elif foot_pos.distance_to(rig_pos) < 100:
		mounted = true
		mouse_fire = false
		notify("Rig online. Explore, extract, return.")
		save_game()
	else:
		notify("Get closer to your drill to board.")

func _has_landing(point: Vector2) -> bool:
	# An empty hatch is not sufficient: avoid dropping the pilot down an open shaft.
	for distance in range(20, 100, 8):
		if terrain.solid(point + Vector2(-7, distance)) and terrain.solid(point + Vector2(7, distance)):
			return true
	return false

func aim_direction() -> Vector2:
	var direction := Vector2(facing, 0)
	if touch_aim.length() > 0.15:
		direction = touch_aim.normalized()
	elif mouse_aim:
		direction = (aim_point + camera_pos - camera_offset - get_viewport_rect().size * 0.5 - foot_pos).normalized()
	return direction if direction.length_squared() > 0.1 else Vector2(facing, 0)

func shoot() -> void:
	var direction := aim_direction()
	# Mild aim assistance only within the intended aim cone and with line of sight.
	var best := 0.92
	for enemy in enemies:
		var toward: Vector2 = enemy.pos - foot_pos
		var alignment := direction.dot(toward.normalized())
		if toward.length() < 460 and alignment > best and _clear_line(foot_pos, enemy.pos):
			best = alignment
			direction = toward.normalized()
	weapon_direction = direction
	muzzle_flash = 0.065
	camera_shake = maxf(camera_shake, 0.9)
	bullets.append({"pos": foot_pos + direction * 23, "vel": direction * 720, "life": 0.9, "enemy": false})
	facing = 1 if direction.x >= 0 else -1
	fire_cooldown = 0.17
	burst(foot_pos + direction * 25, Color("ffe7a1"), 3)
	sounds.play_tone(160, 0.065, 0.16, true)

func _clear_line(from: Vector2, to: Vector2) -> bool:
	var count := maxi(1, ceili(from.distance_to(to) / 12))
	for i in range(1, count):
		if terrain.solid(from.lerp(to, float(i) / count)):
			return false
	return true

func _step_enemies(dt: float) -> void:
	var target := rig_pos if mounted else foot_pos
	for enemy in enemies:
		enemy.flash = maxf(0, float(enemy.flash) - dt)
		var toward: Vector2 = target - enemy.pos
		if toward.length() > 620:
			continue
		enemy.cooldown = float(enemy.cooldown) - dt
		enemy.vy = minf(400, float(enemy.vy) + 700 * dt)
		var speed := 0.0
		if toward.length() < 420 and _clear_line(enemy.pos, target):
			if int(enemy.type) == 1:
				if float(enemy.cooldown) <= 0:
					bullets.append({"pos": enemy.pos, "vel": toward.normalized() * 190, "life": 3.0, "enemy": true})
					enemy.cooldown = 1.8
			else:
				speed = 52.0 if int(enemy.type) == 0 else (155.0 if float(enemy.cooldown) < 0.7 else 10.0)
				if float(enemy.cooldown) < -0.6:
					enemy.cooldown = 1.9
		var previous: Vector2 = enemy.pos
		enemy.pos = terrain.move_body(enemy.pos, Vector2(15, 13), Vector2(signf(toward.x) * speed, float(enemy.vy)) * dt)
		if is_equal_approx(previous.y, enemy.pos.y):
			enemy.vy = 0
		if toward.length() < (62 if mounted else 30):
			if mounted and drilling:
				enemy.hp -= dt * 120
				enemy.flash = 0.12
			else:
				_take_hit(9)
	for i in range(enemies.size() - 1, -1, -1):
		if float(enemies[i].hp) <= 0:
			burst(enemies[i].pos, Color("ef6c7b"), 18)
			enemies.remove_at(i)

func _take_hit(amount: float) -> void:
	if hurt_cooldown > 0:
		return
	if mounted:
		hull -= amount
	else:
		health -= amount
	hurt_cooldown = 0.65
	camera_shake = 5.0
	sounds.play_tone(80, 0.16, 0.18, true)

func _step_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i]
		bullet.life -= dt
		var distance: Vector2 = bullet.vel * dt
		var steps := maxi(1, ceili(distance.length() / 6))
		var hit := false
		for substep in steps:
			bullet.pos += distance / steps
			if terrain.solid(bullet.pos):
				burst(bullet.pos, Color("c2b392"), 3)
				hit = true
				break
			if bullet.enemy:
				if bullet.pos.distance_to(rig_pos if mounted else foot_pos) < (43 if mounted else 18):
					_take_hit(12)
					hit = true
			else:
				for enemy in enemies:
					if bullet.pos.distance_to(enemy.pos) < 23:
						enemy.hp -= 40 if progress.workshop else 20
						enemy.flash = 0.10
						hit_marker = 0.12
						burst(bullet.pos, Color("e4a1a5"), 4)
						hit = true
						break
			if hit:
				break
		if hit or bullet.life <= 0:
			bullets.remove_at(i)

func burst(point: Vector2, color: Color, count: int) -> void:
	for i in mini(count, 200 - particles.size()):
		particles.append({"pos": point, "vel": Vector2(randf_range(-80, 80), randf_range(-100, 40)),
			"life": randf_range(0.18, 0.55), "color": color})

func _step_particles(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= dt
		particles[i].pos += particles[i].vel * dt
		particles[i].vel.y += dt * 160
		if particles[i].life <= 0:
			particles.remove_at(i)

func depth() -> int:
	return maxi(0, int(((rig_pos.y if mounted else foot_pos.y) - ENTRY.y) / 4))

func reveal_area() -> void:
	var cell := terrain.world_cell(rig_pos if mounted else foot_pos)
	if cell == last_survey_cell:
		return
	last_survey_cell = cell
	# Short-range ground survey. Hidden sectors stay unknown until actually approached.
	for y in range(maxi(0, cell.y - 7), mini(Terrain.HEIGHT, cell.y + 8)):
		for x in range(maxi(0, cell.x - 7), mini(Terrain.WIDTH, cell.x + 8)):
			if Vector2i(x, y).distance_squared_to(cell) <= 49:
				survey[str(y * Terrain.WIDTH + x)] = true

func surveyed(point: Vector2) -> bool:
	var cell := terrain.world_cell(point)
	return survey.has(str(cell.y * Terrain.WIDTH + cell.x))

func max_health() -> float:
	return 125.0 if progress.quarters else 100.0

func max_hull() -> float:
	return 150.0 if progress.research else 100.0

func max_jet() -> float:
	return 2.1 if progress.research else 1.4

func near_lift() -> bool:
	return rig_pos.distance_to(ENTRY) < 240 and rig_pos.y < 355

func return_to_colony() -> void:
	if mode != "mine" or paused or map_open:
		return
	if not mounted:
		notify("Board your rig before returning to the colony.")
		return
	if not near_lift():
		notify("Follow the open shaft up to the amber lift. Return [R] there.")
		return
	var earned := progress.deposit()
	health = max_health()
	hull = max_hull()
	mode = "colony"
	clear_controls()
	notify("Haul banked. +%d credits. Rig repaired and supplies restored." % earned)
	sounds.play_tone(660, 0.2, 0.18)
	save_game()

func depart() -> void:
	mode = "mine"
	map_open = false
	mounted = true
	rig_pos = ENTRY
	health = max_health()
	hull = max_hull()
	jet = max_jet()
	camera_pos = ENTRY
	last_survey_cell = Vector2i(-999, -999)
	reveal_area()
	clear_controls()
	notify("Expedition resumed. Your tunnels remain open.")
	save_game()

func build_room(kind: String) -> void:
	if mode != "colony":
		return
	notify(progress.purchase(kind))
	health = minf(max_health(), health + 25)
	hull = max_hull()
	jet = max_jet()
	save_game()

func recover() -> void:
	map_open = false
	clear_controls()
	progress.cargo_copper = floori(progress.cargo_copper * 0.5)
	progress.cargo_crystal = floori(progress.cargo_crystal * 0.5)
	rig_pos = ENTRY
	foot_pos = ENTRY + Vector2(-66, 0)
	mounted = true
	health = max_health()
	hull = max_hull()
	jet = max_jet()
	camera_pos = ENTRY
	bullets.clear()
	notify("Emergency recovery. Half your cargo was lost; colony progress is safe.")
	save_game()

func notify(message: String) -> void:
	toast = message
	toast_time = 5.5

func save_game() -> bool:
	if mode == "title":
		return false
	var stored_enemies: Array = []
	for enemy in enemies:
		stored_enemies.append({"pos": [enemy.pos.x, enemy.pos.y], "type": enemy.type, "hp": enemy.hp})
	last_save_ok = saves.write({"progress": progress.snapshot(), "terrain": terrain.export_state(),
		"settings": {"muted": sounds.muted, "reduced_motion": reduced_motion, "touch_controls": hud.show_touch, "manual_controls": hud.controls_selected},
		"survey": survey.duplicate(),
		"player": {"rig": [rig_pos.x, rig_pos.y], "foot": [foot_pos.x, foot_pos.y],
			"mounted": mounted, "health": health, "hull": hull, "mode": mode}, "enemies": stored_enemies})
	return last_save_ok
