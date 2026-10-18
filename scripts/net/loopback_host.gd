extends RefCounted
## Local-only transport harness, deliberately inaccessible from other machines.
const Authority = preload("res://scripts/net/expedition_authority.gd")
const Protocol = preload("res://scripts/net/command_protocol.gd")
const HANDSHAKE_TIMEOUT_MS := 3000
const MAX_PACKETS_PER_POLL := 8
const MAX_PENDING_BYTES := 65536

var authority := Authority.new()
var listener := TCPServer.new()
var connections: Dictionary = {}
var next_id := 1

func listen() -> Error:
	return listener.listen(0, "127.0.0.1")

func url() -> String:
	return "ws://127.0.0.1:%d" % listener.get_local_port()

func poll(now_ms: int) -> void:
	# Bound admission work; full rooms reject extra TCP connections immediately.
	for _attempt in Authority.MAX_PLAYERS:
		if not listener.is_connection_available():
			break
		var stream := listener.take_connection()
		if connections.size() >= Authority.MAX_PLAYERS:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size = 4096
		socket.outbound_buffer_size = 131072
		socket.max_queued_packets = 16
		if socket.accept_stream(stream) != OK:
			stream.disconnect_from_host()
			continue
		connections[next_id] = {"socket": socket, "welcomed": false, "deadline": now_ms + HANDSHAKE_TIMEOUT_MS}
		next_id += 1
	for peer_id in connections.keys():
		var connection: Dictionary = connections[peer_id]
		var socket: WebSocketPeer = connection.socket
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_drop(peer_id)
			continue
		if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			if now_ms > int(connection.deadline):
				socket.close(-1)
				_drop(peer_id)
			continue
		if not connection.welcomed:
			if not authority.add_peer(peer_id, now_ms):
				socket.close(-1)
				_drop(peer_id)
				continue
			connection.welcomed = true
			socket.send_text(JSON.stringify({"v": Protocol.VERSION, "kind": "welcome", "peer": peer_id}))
			_send(socket, authority.snapshot())
		for _packet_index in MAX_PACKETS_PER_POLL:
			if socket.get_available_packet_count() == 0:
				break
			var result := authority.accept(peer_id, socket.get_packet(), now_ms)
			if result != "accepted":
				_send(socket, {"v": Protocol.VERSION, "kind": "rejected", "reason": result})

func step(now_ms: int) -> void:
	authority.step(now_ms)
	if authority.tick % 3 == 0:
		broadcast()

func broadcast() -> void:
	var snapshot := authority.snapshot()
	for connection in connections.values():
		if connection.welcomed:
			_send(connection.socket, snapshot)

func _send(socket: WebSocketPeer, message: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	# Slow readers cannot accumulate an unbounded history of obsolete snapshots.
	if socket.get_current_outbound_buffered_amount() > MAX_PENDING_BYTES:
		socket.close(-1)
		return
	if socket.send_text(JSON.stringify(message)) != OK:
		socket.close(-1)

func _drop(peer_id: int) -> void:
	authority.remove_peer(peer_id)
	connections.erase(peer_id)

func stop() -> void:
	for connection in connections.values():
		connection.socket.close(-1)
	connections.clear()
	authority.players.clear()
	listener.stop()
