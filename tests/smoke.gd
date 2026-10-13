extends SceneTree
## Behavioral regression tests run inside the real Godot runtime, without plugins.
const Terrain = preload("res://scripts/terrain.gd")
const Progress = preload("res://scripts/progression.gd")
const Saves = preload("res://scripts/save_store.gd")
const Game = preload("res://scripts/game.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func run() -> void:
	var terrain := Terrain.new()
	terrain.generate()
	check(not terrain.blocked(Game.ENTRY, Game.RIG_HALF), "spawn fits the rig")
	var blocked_start := Vector2(460, 332)
	check(terrain.move_body(blocked_start, Game.RIG_HALF, Vector2(0, 350)).y < 340, "large movement cannot tunnel through rock")
	var events: Array = []
	for i in 40:
		events.append_array(terrain.drill(Vector2(460, 328), Game.RIG_HALF, Vector2.DOWN, 1.0 / 60, 24))
	check(not events.is_empty(), "drilling destroys actual terrain")
	var copper := 0
	for hit in events:
		if hit.material == Terrain.Tile.COPPER:
			copper += 1
	check(copper > 0, "mineral seam produces copper")
	var copy := Terrain.new()
	copy.restore(terrain.export_state())
	check(copy.cells == terrain.cells, "seed and cell edits restore identical terrain")
	var wall := terrain.at(Vector2i(0, 8))
	terrain.drill(Vector2(16, 260), Game.RIG_HALF, Vector2.LEFT, 100, 99)
	check(terrain.at(Vector2i(0, 8)) == wall, "bedrock survives drilling")
	var progress := Progress.new()
	for i in 30:
		progress.collect(Terrain.Tile.COPPER)
	check(progress.cargo_count() == 24, "cargo cannot exceed capacity")
	var value := progress.deposit()
	check(value == 72 and progress.copper == 24 and progress.cargo_count() == 0, "banking transfers cargo exactly once")
	check(progress.deposit() == 0 and progress.copper == 24, "repeated banking cannot duplicate ore")
	progress.purchase("drill")
	check(progress.drill_level == 1 and progress.capacity() == 36 and progress.copper == 14, "upgrade spends resources and changes vehicle capability")
	progress.purchase("workshop")
	check(not progress.workshop and progress.copper == 14, "workshop requires a recovered regulator")
	progress.regulator = true
	progress.purchase("workshop")
	check(progress.workshop and progress.copper == 6, "discovery unlocks construction")
	progress.purchase("workshop")
	check(progress.copper == 6, "building an owned room cannot charge again")
	var store := Saves.new()
	store.prefix = "user://gauntlet_regression_%d" % Time.get_ticks_usec()
	check(store.write({"value": 1}), "first save writes successfully")
	check(store.write({"value": 2}), "second save writes successfully")
	check(int(store.read().get("value", 0)) == 2, "latest valid save wins")
	var corrupt := FileAccess.open(store.prefix + "_0.json", FileAccess.WRITE)
	corrupt.store_string("{interrupted")
	corrupt.close()
	check(int(store.read().get("value", 0)) == 1, "corrupt latest save recovers prior valid slot")
	for slot in 2:
		DirAccess.remove_absolute(store.prefix + "_%d.json" % slot)
	var game := Game.new()
	game.saves.prefix = "user://gauntlet_game_regression_%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_physics_process(false)
	game.loaded = {}
	game.start_game()
	check(game.mode == "mine", "game starts an actual expedition")
	game.interact()
	check(not game.mounted and not game.terrain.blocked(game.foot_pos, Game.FOOT_HALF), "dismount chooses a clear hatch position")
	game.interact()
	check(game.mounted, "nearby explorer can reboard")
	game.rig_pos = Vector2(300, 850)
	game.interact()
	check(game.mounted, "open shaft without a landing prevents dangerous dismount")
	# A sealed hull cannot teleport the explorer into surrounding rock.
	game.rig_pos = Vector2(64 * 32, 20 * 32)
	game.interact()
	check(game.mounted, "blocked hatches prevent unsafe dismount")
	game.return_to_colony()
	check(game.mode == "mine", "return requires reaching the lift")
	game.rig_pos = Game.ENTRY
	game.progress.collect(Terrain.Tile.COPPER)
	game.return_to_colony()
	check(game.mode == "colony" and game.progress.copper == 1, "lift return banks real mined resources")
	game.depart()
	check(game.mode == "mine" and game.mounted, "colony connects back to the expedition")
	game.mounted = false
	game.foot_pos = Vector2(800, 732)
	game.enemies = [{"pos": Vector2(885, 732), "type": 0, "hp": 45.0, "vy": 0.0, "cooldown": 2.0, "flash": 0.0}]
	game.facing = 1
	game.shoot()
	for i in 12:
		game._step_bullets(1.0 / 60)
	check(float(game.enemies[0].hp) < 45, "rifle projectile damages an enemy")
	game.foot_pos = Game.RELIC
	game._step_player(1.0 / 60)
	check(game.progress.regulator, "on-foot exploration recovers the regulator")
	game.progress.cargo_copper = 10
	game.recover()
	check(game.progress.cargo_copper == 5 and game.rig_pos == Game.ENTRY and game.progress.regulator, "defeat loses half cargo but preserves discovered progression")
	game.save_game()
	var restored := game.saves.read()
	check(bool(restored.progress.regulator) and int(restored.progress.cargo_copper) == 5, "full gameplay save persists progression")
	# Separate fingers may move and aim simultaneously; lifting one must not stop the other.
	game.mounted = false
	game.hud.buttons.clear()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(100, 450)
	touch.pressed = true
	game.hud.handle_event(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(145, 450)
	game.hud.handle_event(drag)
	check(game.touch_move.x > 0.8, "touch joystick produces directional movement")
	touch.index = 1
	touch.position = Vector2(850, 450)
	game.hud.handle_event(touch)
	drag.index = 1
	drag.position = Vector2(885, 430)
	game.hud.handle_event(drag)
	check(game.touch_fire and game.touch_aim.x > 0.5 and game.touch_move.x > 0.8, "multi-touch supports movement and aim simultaneously")
	touch.index = 0
	touch.pressed = false
	game.hud.handle_event(touch)
	check(game.touch_move == Vector2.ZERO and game.touch_fire, "releasing movement finger preserves aiming finger")
	game.clear_controls()
	check(not game.touch_fire and game.touch_aim == Vector2.ZERO, "focus/reset clears held touch controls")
	for slot in 2:
		DirAccess.remove_absolute(game.saves.prefix + "_%d.json" % slot)
	game.queue_free()
	await process_frame
	print("GAUNTLET TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
