extends RefCounted
## Isolated networking spike; the shipped single-player game does not use this yet.
const Protocol = preload("res://scripts/net/command_protocol.gd")
const Terrain = preload("res://scripts/terrain.gd")
const MAX_PLAYERS := 4
const TICK_RATE := 30
const STEP := 1.0 / TICK_RATE
const SPEED := 185.0
const HALF := Vector2(42, 18)
const INPUT_TIMEOUT_MS := 250
const COMMANDS_PER_SECOND := 60.0
const COMMAND_BURST := 8.0

var terrain := Terrain.new()
var players: Dictionary = {}
var tick := 0

func _init() -> void:
	terrain.generate()

func add_peer(peer_id: int, now_ms: int) -> bool:
	if peer_id <= 0 or players.has(peer_id) or players.size() >= MAX_PLAYERS:
		return false
	var occupied_slots: Array = []
	for existing in players.values():
		occupied_slots.append(existing.slot)
	var slot := 0
	while slot in occupied_slots:
		slot += 1
	players[peer_id] = {"position": Vector2(448 + slot * 96, 272), "slot": slot,
		"movement": Vector2.ZERO, "drill": false, "cargo": 0,
		"sequence": -1, "last_input": now_ms, "tokens": COMMAND_BURST, "token_time": now_ms}
	return true

func remove_peer(peer_id: int) -> void:
	players.erase(peer_id)

func accept(peer_id: int, packet: PackedByteArray, now_ms: int) -> String:
	if not players.has(peer_id):
		return "unknown_peer"
	var player: Dictionary = players[peer_id]
	var elapsed := maxi(0, now_ms - int(player.token_time)) / 1000.0
	player.tokens = minf(COMMAND_BURST, float(player.tokens) + elapsed * COMMANDS_PER_SECOND)
	player.token_time = maxi(now_ms, int(player.token_time))
	if float(player.tokens) < 1.0:
		return "rate_limit"
	# Invalid and replayed packets also spend the per-connection budget.
	player.tokens -= 1.0
	var command := Protocol.decode(packet)
	if not command.ok:
		return command.reason
	if int(command.sequence) <= int(player.sequence):
		return "stale_sequence"
	if int(command.sequence) > int(player.sequence) + 120:
		return "sequence_jump"
	player.sequence = command.sequence
	player.movement = command.movement
	player.drill = command.drill
	player.last_input = now_ms
	return "accepted"

func step(now_ms: int) -> void:
	# One authoritative fixed tick. Callers must drive this at TICK_RATE.
	# Packet count, client frame rate and client-supplied time never advance the world.
	tick += 1
	for peer_id in players:
		var player: Dictionary = players[peer_id]
		var movement: Vector2 = player.movement
		if now_ms - int(player.last_input) > INPUT_TIMEOUT_MS:
			movement = Vector2.ZERO
		var position: Vector2 = player.position
		if player.drill and movement != Vector2.ZERO:
			var drill_direction := Vector2(signf(movement.x), 0) if absf(movement.x) > absf(movement.y) else Vector2(0, signf(movement.y))
			for hit in terrain.drill(position, HALF, drill_direction, STEP, 24 - int(player.cargo)):
				if hit.material in [Terrain.Tile.COPPER, Terrain.Tile.CRYSTAL]:
					player.cargo += 1
		player.position = terrain.move_body(position, HALF, movement * SPEED * STEP)

func snapshot() -> Dictionary:
	var actors: Array = []
	var ids := players.keys()
	ids.sort()
	for peer_id in ids:
		var player: Dictionary = players[peer_id]
		var position: Vector2 = player.position
		actors.append({"id": peer_id, "position": [position.x, position.y],
			"ack": player.sequence, "cargo": player.cargo})
	# Full edits keep this spike inspectable. Production must use bounded chunk deltas.
	return {"v": Protocol.VERSION, "kind": "snapshot", "tick": tick,
		"players": actors, "world": terrain.export_state()}
