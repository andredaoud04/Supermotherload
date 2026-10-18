extends SceneTree
## Persistence regressions use real files and a deterministic browser adapter.
const Saves = preload("res://scripts/save_store.gd")
const Progress = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0

class BrowserStore extends "res://scripts/save_store.gd":
	var browser_slots := ["", ""]
	var browser_available := true
	var file_available := true

	func _uses_browser_storage() -> bool:
		return true

	func _read_browser_slot(slot: int) -> String:
		return browser_slots[slot] if browser_available else ""

	func _write_browser_slot(slot: int, raw: String) -> bool:
		if not browser_available:
			return false
		browser_slots[slot] = raw
		return true

	func _write_file_slot(slot: int, raw: String) -> bool:
		return super._write_file_slot(slot, raw) if file_available else false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func envelope(data: Dictionary, save_revision: int, version: int = 1) -> String:
	var payload := JSON.stringify(data)
	return JSON.stringify({"version": version, "revision": save_revision,
		"payload": payload, "checksum": payload.sha256_text()})

func sample_game() -> Dictionary:
	return {"progress": {"copper": 23, "regulator": true},
		"terrain": {"seed": 17041, "edits": {"1024": 0}},
		"player": {"rig": [448, 272], "foot": [382, 272], "mounted": true,
			"health": 100, "hull": 100, "mode": "mine"},
		"enemies": [{"pos": [790, 747], "type": 0, "hp": 45}],
		"settings": {"muted": true}, "survey": {"1024": true}}

func cleanup(store: SaveStore) -> void:
	for slot in 2:
		DirAccess.remove_absolute("%s_%d.json" % [store.prefix, slot])

func run() -> void:
	var store := Saves.new()
	store.prefix = "user://persistence_native_%d" % Time.get_ticks_usec()
	check(store.read().is_empty() and store.revision == 0, "missing slots start with no save")
	check(store.write({"value": 1}) and store.write({"value": 2}), "legacy generic payloads write both slots")
	check(store.read().get("value") == 2, "most recent native revision restores")
	var original: Dictionary = JSON.parse_string(store._read_file_slot(0))
	var invalid_envelopes := [
		{"version": "1"}, {"version": []}, {"version": 0},
		{"revision": "99"}, {"revision": -3}, {"revision": 2.5}, {"revision": 1e30},
		{"payload": {}}, {"checksum": []}, {"checksum": "f".repeat(64)}]
	for mutation in invalid_envelopes:
		var malformed := original.duplicate(true)
		malformed.merge(mutation, true)
		store._write_file_slot(0, JSON.stringify(malformed))
		check(store.read().get("value") == 1, "malformed envelope falls back safely: %s" % str(mutation.keys()[0]))
	store._write_file_slot(0, "{interrupted")
	check(store.read().get("value") == 1, "interrupted JSON recovers the other slot")
	var game_data := sample_game()
	store._write_file_slot(0, envelope(game_data, 2))
	var loaded := store.read()
	check(loaded.get("settings") == game_data.settings and loaded.get("survey") == game_data.survey,
		"optional settings and survey data survive a version-one restore")
	var malformed_game := game_data.duplicate(true)
	malformed_game.player.rig = [{}, 272]
	store._write_file_slot(0, envelope(malformed_game, 3))
	check(store.read().get("value") == 1, "checksummed invalid coordinates cannot replace a valid save")
	malformed_game = game_data.duplicate(true)
	malformed_game.progress = []
	store._write_file_slot(0, envelope(malformed_game, 3))
	check(store.read().get("value") == 1, "invalid progress section cannot crash game restoration")
	malformed_game = game_data.duplicate(true)
	malformed_game.enemies = [{"pos": [790, 747], "hp": {}, "type": 0}]
	store._write_file_slot(0, envelope(malformed_game, 3))
	check(store.read().get("value") == 1, "invalid enemy health cannot crash game restoration")
	malformed_game = game_data.duplicate(true)
	malformed_game.terrain.edits = []
	store._write_file_slot(0, envelope(malformed_game, 3))
	check(store.read().get("value") == 1, "invalid terrain edits cannot crash game restoration")
	var before := store._read_file_slot(1)
	check(not store.write(malformed_game) and store._read_file_slot(1) == before and store.revision == 1,
		"rejected writes preserve the last valid slot and revision")
	check(not store.write({"value": "é".repeat(Saves.MAX_SAVE_BYTES / 2 + 1)}) and store.revision == 1,
		"oversized Unicode payload cannot exhaust storage or overwrite a backup")
	store._write_file_slot(0, envelope({"future_progress": 999}, 4, 2))
	check(store.read().get("value") == 1 and store.newer_version_found,
		"an older game recognizes a newer save format and retains compatible backup")
	var newer_raw := store._read_file_slot(0)
	check(not store.write({"value": 5}) and store._read_file_slot(0) == newer_raw,
		"an older cached build cannot overwrite a newer-format save")
	cleanup(store)

	var browser := BrowserStore.new()
	browser.prefix = "user://persistence_browser_%d" % Time.get_ticks_usec()
	check(browser.write({"value": 1}) and browser.write({"value": 2}), "browser and file mirrors write successfully")
	browser.browser_slots[0] = "{interrupted"
	check(browser.read().get("value") == 2, "corrupt localStorage cannot mask its valid file mirror")
	browser.browser_slots[1] = envelope({"value": 5}, 5)
	check(browser.read().get("value") == 5 and browser.revision == 5, "a newer browser copy wins over stale files")
	browser.browser_available = false
	check(browser.read().get("value") == 2, "denied browser storage still recovers a valid file")
	check(not browser.write({"value": 3}) and not browser.last_error.is_empty(),
		"blocked browser writes explicitly report that durability is unavailable")
	browser.browser_available = true
	browser.file_available = false
	check(browser.write({"value": 6}) and browser.last_error.is_empty(),
		"browser storage remains usable when the file mirror is unavailable")
	# The previous test supplied a higher external revision; start from read state
	# before verifying a subsequent write so that ordering matches normal startup.
	browser.read()
	check(browser.write({"value": 7}) and browser.read().get("value") == 7,
		"browser-only save survives a fresh read after file failure")
	var previous_revision := browser.revision
	var previous_browser: Array = browser.browser_slots.duplicate()
	browser.browser_available = false
	check(not browser.write({"value": 8}) and browser.revision == previous_revision and browser.browser_slots == previous_browser,
		"complete storage failure leaves the last durable revision intact")
	browser.revision = Saves.MAX_REVISION
	check(not browser.write({"value": 9}) and browser.browser_slots == previous_browser,
		"revision exhaustion cannot wrap around and replace a newer save")
	check(Saves.new()._browser_key(0) == "gauntlet_save_0" and browser._browser_key(0) != "gauntlet_save_0",
		"shipped browser keys stay compatible and test prefixes remain isolated")
	cleanup(browser)

	var progress := Progress.new()
	progress.restore({"copper": {}, "crystal": [], "credits": "500", "cargo_copper": false,
		"drill_level": "3", "workshop": "false", "quarters": 1, "regulator": {},
		"expeditions": NAN, "deepest": INF})
	check(progress.copper == 0 and progress.crystal == 0 and progress.credits == 0 and progress.cargo_count() == 0,
		"unsafe balance types restore to safe values without casts")
	check(not progress.workshop and not progress.quarters and not progress.regulator and progress.drill_level == 0,
		"truthy strings or collections cannot unlock colony progression")
	check(progress.expeditions == 0 and progress.deepest == 0, "nonfinite counters cannot poison progression")
	progress.restore({"copper": 1e100, "crystal": -23, "drill_level": 99,
		"cargo_copper": 30, "cargo_crystal": 80, "credits": 3.5})
	check(progress.copper == Progress.MAX_TOTAL and progress.crystal == 0 and progress.credits == 0,
		"huge, negative, and fractional balances are bounded safely")
	check(progress.drill_level == 3 and progress.cargo_count() == progress.capacity() and progress.cargo_copper == 30,
		"restored cargo respects upgraded capacity across both mineral types")
	var valid := {"copper": 23, "crystal": 7, "credits": 98, "cargo_copper": 4, "cargo_crystal": 2,
		"drill_level": 2, "workshop": true, "quarters": true, "regulator": true, "expeditions": 11, "deepest": 233}
	progress.restore(JSON.parse_string(JSON.stringify(valid)))
	check(progress.snapshot() == valid, "existing valid progression restores without changes")
	print("PERSISTENCE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
