extends Node
## Tiny synthesized feedback sounds. No downloaded audio or runtime dependency.
var muted := false
var voices: Array[AudioStreamPlayer] = []

func play_tone(frequency: float, duration: float, volume: float, noise: bool = false) -> void:
	if muted or voices.size() >= 5 or DisplayServer.get_name() == "headless":
		return
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var phase := float(i) / sample_rate
		var envelope := pow(1.0 - float(i) / count, 2.0)
		var value := sin(TAU * frequency * phase)
		if noise:
			value = value * 0.35 + randf_range(-1, 1) * 0.65
		data.encode_s16(i * 2, int(value * envelope * volume * 26000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	voices.append(player)
	player.finished.connect(func():
		voices.erase(player)
		player.queue_free())
	player.play()
