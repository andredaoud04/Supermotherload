class_name SaveStore
extends RefCounted
## Two independently validated slots survive interrupted or corrupted writes.
const VERSION := 1
var prefix := "user://gauntlet"
var revision := 0
var last_error := ""

func write(data: Dictionary) -> bool:
	revision += 1
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"version": VERSION, "revision": revision,
		"payload": payload, "checksum": payload.sha256_text()})
	var path := "%s_%d.json" % [prefix, revision % 2]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Save unavailable (%s)" % FileAccess.get_open_error()
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	# localStorage is synchronous, so browser background/close cannot race an IDBFS sync.
	# Native builds use the same versioned file format without JavaScript.
	if OS.has_feature("web"):
		var key := "gauntlet_save_%d" % (revision % 2)
		var script := "(function(){try{localStorage.setItem(%s,%s);return true;}catch(e){return false;}})()" % [JSON.stringify(key), JSON.stringify(envelope)]
		if JavaScriptBridge.eval(script) != true:
			last_error = "Browser storage unavailable. Keep this tab open."
			return false
	last_error = ""
	return true

func read() -> Dictionary:
	var best: Dictionary = {}
	var best_revision := -1
	for slot in 2:
		var raw := ""
		if OS.has_feature("web"):
			var stored = JavaScriptBridge.eval("localStorage.getItem('gauntlet_save_%d') || ''" % slot)
			if stored is String:
				raw = stored
		var path := "%s_%d.json" % [prefix, slot]
		if raw.is_empty() and FileAccess.file_exists(path):
			raw = FileAccess.get_file_as_string(path)
		var parsed = _parse_silently(raw)
		if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION:
			continue
		var payload: String = parsed.get("payload", "")
		if payload.sha256_text() != parsed.get("checksum", ""):
			continue
		var data = _parse_silently(payload)
		if data is Dictionary and int(parsed.get("revision", -1)) > best_revision:
			best = data
			best_revision = int(parsed.revision)
	revision = maxi(0, best_revision)
	return best

func _parse_silently(raw: String) -> Variant:
	if raw.is_empty():
		return null
	var parser := JSON.new()
	return parser.data if parser.parse(raw) == OK else null
