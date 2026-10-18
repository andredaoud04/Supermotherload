extends RefCounted
## Experimental input-only wire format. Never accept client positions or inventory.

const VERSION := 1
const MAX_COMMAND_BYTES := 512
const MAX_SEQUENCE := 2147483647

static func input_packet(sequence: int, movement: Vector2, drilling: bool = false) -> PackedByteArray:
	return JSON.stringify({"v": VERSION, "kind": "input", "seq": sequence,
		"move": [movement.x, movement.y], "drill": drilling}).to_utf8_buffer()

static func decode(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_COMMAND_BYTES:
		return {"ok": false, "reason": "size"}
	var parser := JSON.new()
	if parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"ok": false, "reason": "json"}
	var data: Dictionary = parser.data
	# Reject unknown fields, including spoofed peer IDs and authoritative state.
	if data.size() != 5 or not data.has_all(["v", "kind", "seq", "move", "drill"]):
		return {"ok": false, "reason": "schema"}
	if not _integer(data.v, VERSION, VERSION) or data.kind != "input":
		return {"ok": false, "reason": "version"}
	if not _integer(data.seq, 0, MAX_SEQUENCE):
		return {"ok": false, "reason": "sequence"}
	if not data.move is Array or data.move.size() != 2 or not data.drill is bool:
		return {"ok": false, "reason": "schema"}
	for component in data.move:
		if not _number(component) or absf(float(component)) > 1.0:
			return {"ok": false, "reason": "movement"}
	var movement := Vector2(float(data.move[0]), float(data.move[1])).limit_length(1.0)
	return {"ok": true, "sequence": int(data.seq), "movement": movement, "drill": data.drill}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum
