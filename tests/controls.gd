extends SceneTree
## Behavioral controls, navigation and presentation-state regressions.
const Game = preload("res://scripts/game.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var game := Game.new()
	game.saves.prefix = "user://gauntlet_controls_%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_physics_process(false)
	game.loaded = {}
	game.start_game()
	game.touch_move = Vector2.RIGHT
	game._step_player(1.0 / 60)
	check(game.rig_velocity.x > 0 and game.rig_velocity.x < 185, "rig accelerates instead of jumping to cruise speed")
	for i in 12:
		game._step_player(1.0 / 60)
	check(is_equal_approx(game.rig_velocity.x, 185), "rig reaches cruise speed promptly")
	game.touch_move = Vector2.ZERO
	var released_at := game.rig_pos
	for i in 7:
		game._step_player(1.0 / 60)
	check(game.rig_velocity.length() < 0.1 and game.rig_pos.distance_to(released_at) < 10, "braking stops within ten pixels without prolonged drift")
	game.touch_move = Vector2(0.08, 0)
	game._step_player(1.0 / 60)
	check(game.rig_velocity == Vector2.ZERO, "small joystick noise cannot move the rig")
	game.touch_move = Vector2.RIGHT
	game.rig_pos = Vector2(757, 272)
	for i in 5:
		game._step_player(1.0 / 60)
	check(not game.terrain.blocked(game.rig_pos, Game.RIG_HALF), "accelerating into a wall never penetrates terrain")
	game.rig_pos = Game.ENTRY
	game.touch_move = Vector2.RIGHT
	game.toggle_map()
	check(game.map_open and game.touch_move == Vector2.ZERO and game.rig_velocity == Vector2.ZERO, "opening survey map releases movement immediately")
	var before := game.rig_pos
	game._physics_process(0.05)
	check(game.rig_pos == before, "survey map pauses the expedition")
	game.interact()
	game.return_to_colony()
	check(game.mounted and game.mode == "mine", "survey overlay cannot trigger hidden boarding or return actions")
	game.toggle_map()
	check(not game.map_open and not game.paused, "closing map returns to active exploration")
	game.toggle_map()
	game._notification(game.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and not game.map_open, "backgrounding an open map cannot trap touch users behind the pause overlay")
	game.hud.buttons = {"resume": Rect2(0, 0, 100, 100)}
	game.hud._click(Vector2(50, 50))
	check(not game.paused, "touch resume remains reachable after backgrounding the map")
	game.paused = true
	game.hud.buttons = {"controls": Rect2(0, 0, 100, 100)}
	game.hud.show_touch = true
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = Vector2(50, 50)
	touch.pressed = true
	game.hud.handle_event(touch)
	touch.pressed = false
	game.hud.handle_event(touch)
	check(not game.hud.show_touch and game.hud.controls_selected, "releasing a touch cannot undo an explicit keyboard-control choice")
	touch.pressed = true
	touch.position = Vector2(120, 120)
	game.hud.handle_event(touch)
	check(not game.hud.show_touch, "later touches respect the selected control mode")
	game.paused = false
	game.reveal_area()
	check(game.surveyed(Game.ENTRY) and not game.surveyed(Game.RELIC), "survey reveals nearby ground without spoiling remote discoveries")
	var first_survey_count := game.survey.size()
	game.rig_pos = Vector2(300, 750)
	game.reveal_area()
	check(game.survey.size() > first_survey_count and game.surveyed(Game.ENTRY), "survey retains the return route while adding deeper terrain")
	game.mounted = false
	game.foot_pos = Vector2(800, 732)
	game.camera_pos = game.foot_pos
	game.camera_offset = Vector2(3, -2)
	game.mouse_aim = true
	game.aim_point = game.get_viewport_rect().size * 0.5 + game.camera_offset + Vector2(100, -100)
	var expected := Vector2(1, -1).normalized()
	check(game.aim_direction().is_equal_approx(expected), "mouse aim compensates for camera shake")
	game.touch_aim = Vector2.LEFT
	check(game.aim_direction() == Vector2.LEFT, "touch aim overrides stale mouse position")
	game.enemies.clear()
	game.shoot()
	check(game.weapon_direction == Vector2.LEFT and game.muzzle_flash > 0, "rifle visual direction agrees with actual projectile direction")
	game.touch_aim = Vector2.ZERO
	game.paused = true
	game.camera_shake = 4
	game._physics_process(1.0 / 60)
	check(game.camera_offset == Vector2.ZERO, "pause suppresses camera shake")
	game.paused = false
	game.reduced_motion = true
	game.camera_shake = 4
	game._physics_process(1.0 / 60)
	check(game.camera_offset == Vector2.ZERO, "reduced-motion setting disables shake")
	game.sounds.muted = true
	game.hud.show_touch = true
	game.save_game()
	var restored := game.saves.read()
	check(restored.settings.muted and restored.settings.reduced_motion and restored.settings.touch_controls, "audio, motion and control preferences are durable")
	check(restored.survey == game.survey, "survey survives save round-trip")
	game.loaded = restored.duplicate(true)
	game.loaded.settings = {"muted": [], "reduced_motion": {}, "manual_controls": "true", "touch_controls": []}
	game.start_game()
	check(not game.sounds.muted and not game.reduced_motion and not game.hud.controls_selected, "malformed optional settings cannot prevent progression from loading")
	game.rig_velocity = Vector2(185, 0)
	game.map_open = true
	game.recover()
	check(not game.map_open and game.rig_velocity == Vector2.ZERO and game.mounted, "recovery clears navigation and momentum state")
	check(game._read_vector([{}, 12], Game.ENTRY) == Game.ENTRY, "invalid coordinate types safely use spawn fallback")
	var terrain := game.terrain
	terrain.restore({"seed": {}, "edits": {"bad": 0, "500": {}, "0": 0}})
	check(terrain.at(Vector2i.ZERO) == MineTerrain.Tile.BEDROCK, "malformed terrain edits cannot alter bedrock or crash restore")
	for slot in 2:
		DirAccess.remove_absolute(game.saves.prefix + "_%d.json" % slot)
	game.queue_free()
	await process_frame
	print("CONTROLS TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
