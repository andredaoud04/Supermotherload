class_name SaveStore
extends RefCounted
## Two independently validated slots survive interrupted or corrupted writes.
const VERSION := 1
const MAX_SAVE_BYTES := 2 * 1024 * 1024
const MAX_REVISION := 9_007_199_254_740_990
var prefix := "user://gauntlet"
var revision := 0
var last_error := ""
var newer_version_found := false
var browser_error := ""

func write(data: Dictionary) -> bool:
	if newer_version_found:
		last_error = "Save uses a newer game version. Reload the latest build."
		return false
	if not _valid_game_shape(data) or revision >= MAX_REVISION:
		last_error = "Save data could not be validated. Previous saves are safe."
		return false
	var payload := JSON.stringify(data)
	var next_revision := revision + 1
	var envelope := JSON.stringify({"version": VERSION, "revision": next_revision,
		"payload": payload, "checksum": payload.sha256_text()})
	if envelope.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		last_error = "Save is too large. Previous saves are safe."
		return false
	var slot := next_revision % 2
	var wrote_file := _write_file_slot(slot, envelope)
	# localStorage is synchronous, so browser background/close cannot race IDBFS.
	# A successful browser write remains durable even if its file mirror fails.
	var wrote_browser := false
	if _uses_browser_storage():
		wrote_browser = _write_browser_slot(slot, envelope)
	if wrote_file or wrote_browser:
		revision = next_revision
	if _uses_browser_storage() and not wrote_browser:
		last_error = "Browser storage unavailable%s. Keep this tab open." % (" (%s)" % browser_error if not browser_error.is_empty() else "")
		return false
	if not wrote_file and not wrote_browser:
		last_error = "Save storage unavailable. Previous saves are safe."
		return false
	last_error = ""
	return true

func read() -> Dictionary:
	var best: Dictionary = {}
	var best_revision := -1
	newer_version_found = false
	for slot in 2:
		# Validate every copy. A damaged or older browser entry must not mask a
		# valid file mirror, and a stale mirror must not roll back browser progress.
		var candidates: Array[String] = [_read_file_slot(slot)]
		if _uses_browser_storage():
			candidates.append(_read_browser_slot(slot))
		for raw in candidates:
			var decoded := _decode(raw)
			if decoded.is_empty():
				continue
			if decoded.version > VERSION:
				newer_version_found = true
				continue
			if decoded.revision > best_revision:
				best = decoded.data
				best_revision = decoded.revision
	revision = maxi(0, best_revision)
	last_error = "Save uses a newer game version. Reload the latest build." if newer_version_found else ""
	return best

func _decode(raw: String) -> Dictionary:
	if raw.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return {}
	var parsed = _parse_silently(raw)
	if not parsed is Dictionary:
		return {}
	if not _whole_number(parsed.get("version"), 1, MAX_REVISION):
		return {}
	if not _whole_number(parsed.get("revision"), 1, MAX_REVISION):
		return {}
	var payload = parsed.get("payload")
	var checksum = parsed.get("checksum")
	if not payload is String or not checksum is String or checksum.length() != 64:
		return {}
	if payload.sha256_text() != checksum:
		return {}
	var data = _parse_silently(payload)
	if not data is Dictionary:
		return {}
	# A newer schema can be inspected but never rewritten by an older game.
	if int(parsed.version) == VERSION and not _valid_game_shape(data):
		return {}
	return {"version": int(parsed.version), "revision": int(parsed.revision), "data": data}

func _valid_game_shape(data: Dictionary) -> bool:
	# Keep this store usable for small independent saves/tests. Full game saves
	# have typed sections; unknown optional fields survive unchanged for upgrades.
	if not (data.has("progress") or data.has("terrain") or data.has("player")):
		return true
	if not data.get("progress") is Dictionary or not data.get("terrain") is Dictionary:
		return false
	if not data.get("player") is Dictionary or not data.get("enemies") is Array:
		return false
	var progress: Dictionary = data.progress
	for key in ["copper", "crystal", "credits", "cargo_copper", "cargo_crystal", "drill_level", "expeditions", "deepest"]:
		if progress.has(key) and not _finite_number(progress[key]):
			return false
	for key in ["workshop", "quarters", "regulator"]:
		if progress.has(key) and not progress[key] is bool:
			return false
	var terrain: Dictionary = data.terrain
	if terrain.has("seed") and not _whole_number(terrain.seed, -MAX_REVISION, MAX_REVISION):
		return false
	if terrain.has("edits"):
		if not terrain.edits is Dictionary:
			return false
		for key in terrain.edits:
			if not key is String or not key.is_valid_int() or not _whole_number(terrain.edits[key], 0, 0):
				return false
	var player: Dictionary = data.player
	for key in ["rig", "foot"]:
		if player.has(key) and not _valid_point(player[key]):
			return false
	for key in ["health", "hull"]:
		if player.has(key) and not _finite_number(player[key]):
			return false
	if player.has("mounted") and not player.mounted is bool:
		return false
	if player.has("mode") and player.mode not in ["mine", "colony"]:
		return false
	if data.enemies.size() > 256:
		return false
	for enemy in data.enemies:
		if not enemy is Dictionary or not _valid_point(enemy.get("pos")):
			return false
		if not _finite_number(enemy.get("hp")) or not _whole_number(enemy.get("type"), 0, 2):
			return false
	return true

func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _finite_number(value[0]) and _finite_number(value[1])

func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if not _finite_number(value):
		return false
	var number := float(value)
	return number == floor(number) and number >= minimum and number <= maximum

func _write_file_slot(slot: int, raw: String) -> bool:
	var file := FileAccess.open("%s_%d.json" % [prefix, slot], FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(raw)
	file.flush()
	var succeeded := file.get_error() == OK
	file.close()
	return succeeded

func _read_file_slot(slot: int) -> String:
	var path := "%s_%d.json" % [prefix, slot]
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return ""
	return file.get_as_text()

func _uses_browser_storage() -> bool:
	return OS.has_feature("web")

func _browser_key(slot: int) -> String:
	# Preserve shipped keys; custom/test prefixes cannot overwrite the real save.
	return "%s_save_%d" % [prefix.get_file(), slot]

func _read_browser_slot(slot: int) -> String:
	var script := "(function(){try{return localStorage.getItem(%s)||'';}catch(e){return '';}})()" % JSON.stringify(_browser_key(slot))
	var stored = JavaScriptBridge.eval(script)
	return stored if stored is String else ""

func _write_browser_slot(slot: int, raw: String) -> bool:
	var script := "(function(){try{localStorage.setItem(%s,%s);return 'ok';}catch(e){return e.name||'StorageError';}})()" % [JSON.stringify(_browser_key(slot)), JSON.stringify(raw)]
	var result: Variant = JavaScriptBridge.eval(script)
	var succeeded: bool = result is String and result == "ok"
	browser_error = "" if succeeded else (str(result) if result is String else "bridge unavailable")
	return succeeded

func _parse_silently(raw: String) -> Variant:
	if raw.is_empty():
		return null
	var parser := JSON.new()
	return parser.data if parser.parse(raw) == OK else null
