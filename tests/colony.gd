extends SceneTree
const Game = preload("res://scripts/game.gd")
const Progress = preload("res://scripts/progression.gd")
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
	var p := Progress.new()
	p.crystal = 8
	p.credits = 120
	p.archive = true
	p.purchase("research")
	check(not p.research and p.crystal == 8 and p.credits == 120, "research requires existing colony facilities without charging")
	p.workshop = true
	p.purchase("research")
	check(not p.research, "workshop alone cannot unlock research")
	p.quarters = true
	p.archive = false
	p.purchase("research")
	check(not p.research and p.credits == 120, "research requires the deep archive")
	p.archive = true
	p.crystal = 7
	p.purchase("research")
	check(not p.research and p.crystal == 7 and p.credits == 120, "insufficient crystals cannot partially charge credits")
	p.crystal = 8
	p.credits = 119
	p.purchase("research")
	check(not p.research and p.crystal == 8 and p.credits == 119, "insufficient credits cannot partially charge crystals")
	p.credits = 120
	p.purchase("research")
	check(p.research and p.crystal == 0 and p.credits == 0, "research consumes its exact crystal and credit costs")
	p.purchase("research")
	check(p.research and p.crystal == 0 and p.credits == 0, "owned research cannot charge twice")
	var legacy := Progress.new()
	legacy.restore({"workshop": true, "quarters": true, "regulator": true})
	check(not legacy.archive and not legacy.research, "existing version-one progress defaults new discoveries to locked")
	legacy.restore({"archive": "true", "research": 1})
	check(not legacy.archive and not legacy.research, "malformed research flags do not grant upgrades")
	legacy.drill_level = 1
	legacy.regulator = true
	legacy.workshop = true
	legacy.quarters = true
	check(legacy.objective().contains("350m"), "completed early colony directs players toward the deep chamber")
	legacy.archive = true
	check(legacy.objective().contains("research lab"), "recovered archive directs players back to research")
	var game := Game.new()
	game.saves.prefix = "user://colony_regression_%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_physics_process(false)
	game.loaded = {}
	game.start_game()
	game.rig_pos = Game.ARCHIVE
	game.foot_pos = Game.ARCHIVE
	game._step_player(1.0 / 60)
	check(not game.progress.archive, "driving over archive does not collect an on-foot discovery")
	game.mounted = false
	game._step_player(1.0 / 60)
	check(game.progress.archive and game.saves.read().progress.archive, "on-foot archive recovery is immediately durable")
	var revision: int = game.saves.revision
	game._step_player(1.0 / 60)
	check(game.saves.revision == revision, "collected archive does not repeatedly trigger saves or rewards")
	game.recover()
	check(game.progress.archive, "emergency recovery preserves the archive")
	game.progress.workshop = true
	game.progress.quarters = true
	game.progress.crystal = 8
	game.progress.credits = 120
	game.build_room("research")
	check(not game.progress.research, "research cannot be purchased while underground")
	game.return_to_colony()
	game.build_room("research")
	check(game.progress.research and game.hull == 150 and is_equal_approx(game.jet, 2.1), "colony construction immediately equips reinforced hull and extended boost")
	game.depart()
	check(game.hull == 150 and is_equal_approx(game.jet, 2.1), "departure preserves upgraded equipment limits")
	game.hull = 137
	game.save_game()
	game.loaded = game.saves.read()
	game.hull = 1
	game.start_game()
	check(game.hull == 137 and game.progress.research and game.progress.archive, "full save restoration retains research and hull above the original cap")
	game.recover()
	check(game.hull == 150 and is_equal_approx(game.jet, 2.1), "recovery refills upgraded equipment")
	# Medical supplies belong to the rig and persist, rather than refilling at every boarding.
	game.progress.quarters = false
	game.depart()
	game.health = 37
	game.mounted = false
	game.foot_pos = game.rig_pos + Vector2(66, 0)
	game.interact()
	check(game.mounted and game.health == 77 and game.field_kits == 0, "boarding uses one limited kit to restore forty health")
	check(game.saves.read().player.field_kits == 0 and game.saves.read().player.health == 77, "boarding saves kit consumption and healing together")
	game.mounted = false
	game.interact()
	check(game.health == 77 and game.field_kits == 0, "repeated boarding cannot regenerate medical supplies")
	game.loaded = game.saves.read()
	game.field_kits = 1
	game.start_game()
	check(game.field_kits == 0 and game.health == 77, "reloading cannot restore an exhausted field kit")
	game.return_to_colony()
	check(game.field_kits == 1 and game.health == 100, "colony return restocks the rig and heals the explorer")
	game.depart()
	game.mounted = false
	game.foot_pos = game.rig_pos + Vector2(66, 0)
	game.interact()
	check(game.field_kits == 1, "healthy boarding preserves the kit")
	game.health = 95
	game.mounted = false
	game.interact()
	check(game.health == 100 and game.field_kits == 0, "partial healing consumes one kit without exceeding maximum health")
	game.progress.quarters = true
	game.recover()
	check(game.field_kits == 2 and game.health == 125, "living quarters supply two kits on recovery")
	game.save_game()
	var old_save: Dictionary = game.saves.read()
	old_save.player.erase("field_kits")
	game.loaded = old_save
	game.start_game()
	check(game.field_kits == 2, "legacy saves receive their colony's medical capacity once")
	var invalid_save: Dictionary = game.saves.read()
	invalid_save.player.field_kits = "many"
	check(not game.saves.write(invalid_save), "malformed field kit counts are rejected safely")
	for slot in 2:
		DirAccess.remove_absolute(game.saves.prefix + "_%d.json" % slot)
	game.queue_free()
	await process_frame
	print("COLONY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
