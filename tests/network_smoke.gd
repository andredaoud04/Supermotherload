extends SceneTree
## Actual Godot WebSocket loopback plus deterministic command/authority regressions.
const Protocol = preload("res://scripts/net/command_protocol.gd")
const Authority = preload("res://scripts/net/expedition_authority.gd")
const Host = preload("res://scripts/net/loopback_host.gd")
var checks := 0
var failures := 0
var clients: Array[WebSocketPeer] = []
var messages: Array[Array] = [[], []]

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
	unit_checks()
	await loopback_checks()
	print("NETWORK CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)

func unit_checks() -> void:
	var diagonal := Protocol.decode(Protocol.input_packet(0, Vector2.ONE))
	check(diagonal.ok and is_equal_approx(diagonal.movement.length(), 1.0), "diagonal input cannot exceed movement speed")
	check(not Protocol.decode("{broken".to_utf8_buffer()).ok, "malformed JSON is rejected without a parser error")
	check(not Protocol.decode("[]".to_utf8_buffer()).ok, "non-object commands are rejected")
	check(not Protocol.decode(" ".repeat(513).to_utf8_buffer()).ok, "oversized commands are rejected before parsing")
	check(not Protocol.decode('{"v":1,"kind":"input","seq":0,"move":[0,0],"drill":false,"peer":2}'.to_utf8_buffer()).ok, "client cannot select a different peer identity")
	check(not Protocol.decode('{"v":1,"kind":"input","seq":0.5,"move":[0,0],"drill":false}'.to_utf8_buffer()).ok, "fractional command sequences are rejected")
	check(not Protocol.decode(Protocol.input_packet(0, Vector2(1000, 0))).ok, "out-of-range movement is rejected")
	check(not Protocol.decode('{"v":2,"kind":"input","seq":0,"move":[0,0],"drill":false}'.to_utf8_buffer()).ok, "incompatible protocol versions are rejected")
	var authority := Authority.new()
	check(authority.add_peer(1, 1000), "authority registers a transport-assigned peer")
	check(authority.accept(99, Protocol.input_packet(0, Vector2.RIGHT), 1000) == "unknown_peer", "unregistered connections cannot command the world")
	check(authority.accept(1, Protocol.input_packet(0, Vector2.RIGHT), 1000) == "accepted", "valid sequence is accepted")
	check(authority.accept(1, Protocol.input_packet(0, Vector2.LEFT), 1000) == "stale_sequence", "duplicate command cannot replace newer input")
	check(authority.accept(1, Protocol.input_packet(121, Vector2.LEFT), 1000) == "sequence_jump", "implausibly large sequence jumps are rejected")
	var start: Vector2 = authority.players[1].position
	for sequence in range(1, 5):
		authority.accept(1, Protocol.input_packet(sequence, Vector2.RIGHT), 1000)
	check(authority.players[1].position == start, "sending extra commands never advances simulation")
	authority.step(1000)
	check(is_equal_approx(authority.players[1].position.x - start.x, Authority.SPEED * Authority.STEP), "authority moves only one fixed step regardless of packet count")
	var before_timeout: Vector2 = authority.players[1].position
	authority.step(1251)
	check(authority.players[1].position == before_timeout, "stalled or backgrounded client stops after 250 ms")
	authority.players[1].position = Vector2(448, 328)
	for sequence in range(5, 20):
		var now := 1300 + sequence * 34
		authority.accept(1, Protocol.input_packet(sequence, Vector2.DOWN), now)
		authority.step(now)
	check(authority.players[1].position.y < 335 and authority.terrain.edits.is_empty(), "movement cannot tunnel through ore without drilling")
	var limited := Authority.new()
	limited.add_peer(1, 0)
	for sequence in 8:
		limited.accept(1, Protocol.input_packet(sequence, Vector2.ZERO), 0)
	check(limited.accept(1, Protocol.input_packet(8, Vector2.ZERO), 0) == "rate_limit", "per-peer burst cap bounds command floods")
	check(limited.accept(1, Protocol.input_packet(8, Vector2.ZERO), 100) == "accepted", "command budget refills with server elapsed time")
	for peer_id in range(2, 5):
		limited.add_peer(peer_id, 0)
	check(not limited.add_peer(5, 0), "room admits at most four players")
	limited.remove_peer(2)
	check(limited.accept(2, Protocol.input_packet(0, Vector2.ONE), 100) == "unknown_peer", "disconnected peer loses command authority")
	check(limited.add_peer(5, 100), "vacated room slot can be reused by a new transport identity")
	check(limited.players[5].slot == 1 and limited.players[5].position != limited.players[4].position, "replacement peer receives the vacated spawn slot")
	var miner := Authority.new()
	miner.add_peer(1, 0)
	miner.players[1].position = Vector2(448, 328)
	for sequence in 100:
		var now := sequence * 34
		miner.accept(1, Protocol.input_packet(sequence, Vector2.DOWN, true), now)
		miner.step(now)
	check(miner.players[1].cargo > 0 and miner.players[1].cargo <= 24 and not miner.terrain.edits.is_empty(), "server collision, drilling and cargo derive from real mine terrain")
	var snapshot := miner.snapshot()
	check(snapshot.players[0].ack == 99 and snapshot.tick == 100 and snapshot.world.edits == miner.terrain.edits, "snapshot acknowledges accepted input and includes authoritative terrain edits")

func pump(host: RefCounted) -> void:
	for client in clients:
		client.poll()
	host.poll(Time.get_ticks_msec())
	for index in clients.size():
		var client := clients[index]
		client.poll()
		while client.get_available_packet_count() > 0:
			var parser := JSON.new()
			if parser.parse(client.get_packet().get_string_from_utf8()) == OK and parser.data is Dictionary:
				messages[index].append(parser.data)

func last_message(index: int, kind: String) -> Dictionary:
	for offset in messages[index].size():
		var message: Dictionary = messages[index][messages[index].size() - offset - 1]
		if message.get("kind") == kind:
			return message
	return {}

func loopback_checks() -> void:
	var host := Host.new()
	var error: Error = host.listen()
	check(error == OK, "native host listens on an ephemeral loopback port")
	if error != OK:
		return
	for index in 2:
		var client := WebSocketPeer.new()
		clients.append(client)
		check(client.connect_to_url(host.url()) == OK, "WebSocket client %d begins connecting" % (index + 1))
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		pump(host)
		if not last_message(0, "welcome").is_empty() and not last_message(1, "welcome").is_empty():
			break
		await create_timer(0.005).timeout
	var first := last_message(0, "welcome")
	var second := last_message(1, "welcome")
	check(not first.is_empty() and not second.is_empty(), "two real WebSocket clients complete handshake and receive welcome")
	if first.is_empty() or second.is_empty():
		host.stop()
		return
	check(first.peer != second.peer and host.authority.players.size() == 2, "server assigns distinct identities to independent sockets")
	var first_id := int(first.peer)
	var second_id := int(second.peer)
	var second_start: Vector2 = host.authority.players[second_id].position
	# Exercise real socket delivery and shared mining edits at the authoritative rate.
	for sequence in 42:
		clients[0].put_packet(Protocol.input_packet(sequence, Vector2.DOWN, true))
		clients[1].put_packet(Protocol.input_packet(sequence, Vector2.ZERO))
		pump(host)
		await create_timer(Authority.STEP).timeout
		pump(host)
		host.step(Time.get_ticks_msec())
	# Replay an old input over the wire; it must not become the held movement.
	clients[0].put_packet(Protocol.input_packet(0, Vector2.UP))
	for _iteration in 10:
		pump(host)
		await create_timer(0.005).timeout
	host.broadcast()
	for _iteration in 10:
		pump(host)
		await create_timer(0.005).timeout
	check(host.authority.players[first_id].position.y > 328 and host.authority.players[first_id].cargo > 0, "commands delivered over WebSocket mine ore and move the first rig")
	check(host.authority.players[second_id].position == second_start, "one socket cannot move the other player's rig")
	check(last_message(0, "rejected").get("reason") == "stale_sequence", "replayed wire command receives a rejection")
	var first_snapshot := last_message(0, "snapshot")
	var second_snapshot := last_message(1, "snapshot")
	check(not first_snapshot.is_empty() and first_snapshot == second_snapshot, "both clients receive identical authoritative world and player snapshots")
	check(not first_snapshot.get("world", {}).get("edits", {}).is_empty(), "terrain edits actually cross the WebSocket connection")
	clients[0].close(1000, "test complete")
	deadline = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline and host.authority.players.has(first_id):
		pump(host)
		await create_timer(0.005).timeout
	check(not host.authority.players.has(first_id) and host.authority.players.has(second_id), "socket disconnection removes only its own authority state")
	clients[1].close(-1)
	host.stop()
