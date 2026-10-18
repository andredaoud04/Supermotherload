extends Node
## Cached original synthesis: quiet machinery, cavern air, and short reactive voices.
var muted := false:
	set(value):
		muted = value
		if value:
			for player in voices:
				player.stop()
				player.queue_free()
			voices.clear()
var cache: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var motor: AudioStreamPlayer
var air: AudioStreamPlayer
var motor_target := -80.0
var air_target := -80.0
var motor_pitch := 1.0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	motor = _loop(false)
	air = _loop(true)

func _loop(cavern: bool) -> AudioStreamPlayer:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 44100
	var data := PackedByteArray()
	data.resize(88200)
	# Integer-frequency harmonics join without a discontinuity at the two-second seam.
	for i in 44100:
		var t := float(i) / 22050
		var sample := sin(TAU * 47 * t) * 0.48 + sin(TAU * 94 * t) * 0.20
		if cavern:
			sample = sin(TAU * 36 * t) * 0.35 + sin(TAU * 52.5 * t) * 0.2 + sin(TAU * 81 * t) * 0.08
		else:
			sample += sin(TAU * 188 * t) * (0.12 + sin(TAU * 8 * t) * 0.07)
		data.encode_s16(i * 2, int(sample * 12000))
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -80
	add_child(player)
	return player

func set_activity(active: bool, mounted: bool, drilling: bool, speed: float) -> void:
	air_target = -28.0 if active and not muted else -80.0
	motor_target = (-18.0 if drilling else (-24.0 if speed > 5 else -33.0)) if active and mounted and not muted else -80.0
	motor_pitch = 0.85 + clampf(speed / 185.0, 0, 1) * 0.24 + (0.19 if drilling else 0.0)
	if motor == null:
		return
	for player in [motor, air]:
		if active and not muted and not player.playing:
			player.play()
		elif (not active or muted) and player.playing:
			player.stop()

func _process(dt: float) -> void:
	if motor == null:
		return
	motor.volume_db = lerpf(motor.volume_db, motor_target, minf(1, dt * 9))
	air.volume_db = lerpf(air.volume_db, air_target, minf(1, dt * 3))
	motor.pitch_scale = lerpf(motor.pitch_scale, motor_pitch, minf(1, dt * 8))

func play_tone(frequency: float, duration: float, volume: float, noise: bool = false) -> void:
	if muted or voices.size() >= 5 or DisplayServer.get_name() == "headless":
		return
	var key := "%s/%s/%s/%s" % [frequency, duration, volume, noise]
	if not cache.has(key):
		var sample_rate := 22050
		var count := maxi(1, int(duration * sample_rate))
		var data := PackedByteArray()
		data.resize(count * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7041
		var filtered := 0.0
		for i in count:
			var phase := float(i) / sample_rate
			var envelope := minf(1, phase * 700) * pow(1.0 - float(i) / count, 2.0)
			var value := sin(TAU * frequency * phase) * 0.75 + sin(TAU * frequency * 2 * phase) * 0.15
			if noise:
				filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.42)
				value = value * 0.45 + filtered * 0.85
			data.encode_s16(i * 2, int(value * envelope * volume * 26000))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = sample_rate
		stream.data = data
		cache[key] = stream
	var player := AudioStreamPlayer.new()
	player.stream = cache[key]
	add_child(player)
	voices.append(player)
	player.finished.connect(func():
		voices.erase(player)
		player.queue_free())
	player.play()
