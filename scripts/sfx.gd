extends Node
## Tiny procedurally generated sound effects (no audio files needed).

const RATE := 22050

var players := {}


func _ready() -> void:
	_add("click", _tone(170.0, 0.07, 0.65, 55.0), -10.0)
	_add("step", _tone(330.0, 0.1, 0.3, 35.0), -12.0)
	_add("done", _chime([660.0, 990.0], 0.09, 0.35), -12.0)
	_add("buy", _chime([523.0, 659.0, 784.0], 0.08, 0.45), -9.0)
	_add("error", _tone(110.0, 0.16, 0.25, 14.0), -10.0)


func play(key: String) -> void:
	if players.has(key):
		players[key].play()


func _add(key: String, stream: AudioStream, vol: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	p.max_polyphony = 4
	add_child(p)
	players[key] = p


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tone(freq: float, dur: float, noise: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay)
		s[i] = (sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise) * env
		phase += TAU * freq / RATE
	return _wav(s)


func _chime(freqs: Array, gap: float, dur: float) -> AudioStreamWAV:
	var n := int((dur + gap * freqs.size()) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for k in freqs.size():
		var start := int(k * gap * RATE)
		var f: float = freqs[k]
		for i in range(start, n):
			var t := float(i - start) / RATE
			s[i] += sin(TAU * f * t) * exp(-t * 9.0) * 0.4
	return _wav(s)
