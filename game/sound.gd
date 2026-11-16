extends Node
# Everything is synthesized locally into PCM on a worker thread: effects first,
# then a three-stem generative loop. No external sound assets.
const RATE := 22050
const SCALE := [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5]
var players: Array[AudioStreamPlayer] = []
var next := 0
var tones: Dictionary = {}
var stems: Array[AudioStreamPlayer] = []
var stem_gain := [0.0, 0.0, 0.0]
var stem_target := [1.0, 0.0, 0.0]
var music_on := true
var sfx_on := true
var with_music := true
var thread: Thread
var roller: AudioStreamPlayer
var roll_level := 0.0
var combo := 0
var combo_t := 0.0
var noise := RandomNumberGenerator.new()

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -12
		add_child(p)
		players.append(p)
	roller = AudioStreamPlayer.new()
	roller.volume_db = -60
	add_child(roller)
	thread = Thread.new()
	thread.start(build)

func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()

func wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	# A looped stream gets a tail copied from its start. The mixer reads a little
	# past loop_end when it wraps; with loop_end at the very end of the buffer that
	# read ran off the allocation and crashed the Android audio thread.
	var count := data.size()
	var tail := 256 if loop else 0
	var bytes := PackedByteArray()
	bytes.resize((count + tail) * 2)
	for i in count + tail:
		bytes.encode_s16(i * 2, int(clampf(data[i % count], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func sweep(from: float, to: float, seconds: float, gain := 0.5, grit := 0.0, wobble := 0.0, curve := 1.0) -> PackedFloat32Array:
	var total := int(seconds * RATE)
	var data := PackedFloat32Array()
	data.resize(total)
	var phase := 0.0
	var low := 0.0
	for i in total:
		var t := float(i) / total
		var envelope := pow(1.0 - t, curve) * minf(1.0, i / 60.0)
		var freq := lerpf(from, to, t) * (1.0 + wobble * sin(t * seconds * 60.0))
		phase += TAU * freq / RATE
		low += (noise.randf_range(-1, 1) - low) * 0.35
		data[i] = (sin(phase) * (1.0 - grit) + sin(phase * 2.0) * 0.15 * (1.0 - grit) + low * grit * 1.6) * envelope * gain
	return data

func pluck(freq: float, seconds: float, gain := 0.5, bright := 0.25) -> PackedFloat32Array:
	var total := int(seconds * RATE)
	var data := PackedFloat32Array()
	data.resize(total)
	for i in total:
		var t := float(i) / RATE
		var envelope := exp(-t * 7.0 / seconds * 0.6) * minf(1.0, i / 40.0) * (1.0 - float(i) / total)
		var phase := TAU * freq * t
		data[i] = (sin(phase) + sin(phase * 3.0) * bright * exp(-t * 18.0) + sin(phase * 2.0) * 0.2) * envelope * gain
	return data

func mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0) -> PackedFloat32Array:
	if a.size() < b.size() + offset:
		a.resize(b.size() + offset)
	for i in b.size():
		a[i + offset] += b[i]
	return a

func build() -> void:
	noise.seed = 11
	var made := {}
	made["jump"] = wav(sweep(360, 760, 0.15, 0.4))
	made["land"] = wav(sweep(170, 70, 0.13, 0.5, 0.25))
	made["roll"] = wav(sweep(560, 240, 0.11, 0.4))
	made["walk"] = wav(sweep(280, 620, 0.11, 0.4))
	made["bump"] = wav(sweep(230, 90, 0.13, 0.5, 0.2))
	made["kick"] = wav(sweep(520, 300, 0.07, 0.3, 0.5))
	made["thwack"] = wav(mix(sweep(300, 110, 0.14, 0.6, 0.35), sweep(900, 500, 0.05, 0.3)))
	made["spring"] = wav(sweep(260, 880, 0.34, 0.45, 0.0, 0.06))
	made["seed"] = wav(pluck(784, 0.3, 0.45))
	made["splash"] = wav(sweep(300, 90, 0.5, 0.5, 0.85, 0.0, 1.6))
	made["dive"] = wav(sweep(980, 260, 0.2, 0.3))
	made["pound"] = wav(mix(sweep(120, 42, 0.42, 0.8, 0.2, 0.0, 1.5), sweep(200, 80, 0.2, 0.4, 0.9)))
	made["boost"] = wav(sweep(260, 900, 0.22, 0.35, 0.35))
	made["crumble"] = wav(sweep(160, 60, 0.45, 0.6, 0.9))
	made["blip"] = wav(sweep(640, 720, 0.04, 0.22))
	made["gate"] = wav(sweep(90, 60, 0.9, 0.6, 0.6, 0.02, 0.6))
	made["check"] = wav(mix(pluck(659, 0.3, 0.4), pluck(988, 0.4, 0.4), int(0.11 * RATE)))
	var wake := pluck(659, 0.25, 0.4)
	wake = mix(wake, pluck(880, 0.25, 0.4), int(0.09 * RATE))
	wake = mix(wake, pluck(1319, 0.5, 0.4), int(0.18 * RATE))
	made["wake"] = wav(wake)
	var bell := PackedFloat32Array()
	for part in [[440.0, 0.5, 2.6], [1214.0, 0.25, 1.6], [2376.0, 0.16, 1.0], [3916.0, 0.08, 0.6], [220.0, 0.2, 2.2]]:
		var total := int(part[2] * RATE)
		var layer := PackedFloat32Array()
		layer.resize(total)
		for i in total:
			var t := float(i) / RATE
			layer[i] = sin(TAU * part[0] * t) * exp(-t * 3.2 / part[2]) * part[1] * minf(1.0, i / 30.0) * (1.0 - float(i) / total)
		bell = mix(bell, layer)
	made["bell"] = wav(bell)
	var fanfare := PackedFloat32Array()
	var notes := [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0]
	for i in notes.size():
		fanfare = mix(fanfare, pluck(notes[i], 0.9 if i == notes.size() - 1 else 0.4, 0.33, 0.4), int(i * 0.12 * RATE))
	made["fanfare"] = wav(fanfare)
	var rumble := PackedFloat32Array()
	rumble.resize(RATE)
	var low := 0.0
	for i in RATE:
		low += (noise.randf_range(-1, 1) - low) * 0.06
		rumble[i] = low * 2.2 * (0.7 + 0.3 * sin(TAU * 9.0 * i / RATE))
	var rumble_stream := wav(rumble, true)
	install_effects.call_deferred(made, rumble_stream)
	if with_music:
		compose()

func install_effects(made: Dictionary, rumble: AudioStreamWAV) -> void:
	tones = made
	roller.stream = rumble
	roller.play()

func compose() -> void:
	# 96 bpm, 8 bars. Stem 0: kalimba arpeggio. Stem 1: bass + shaker. Stem 2: whistle lead.
	var beat := 60.0 / 96.0
	var total := int(beat * 32 * RATE)
	var layers: Array[PackedFloat32Array] = []
	for k in 3:
		var buffer := PackedFloat32Array()
		buffer.resize(total)
		layers.append(buffer)
	var roots := [261.63, 220.0, 174.61, 196.0, 261.63, 164.81, 174.61, 196.0]
	var chords := [[1.0, 1.25, 1.5, 2.0], [1.0, 1.2, 1.5, 2.0], [1.0, 1.25, 1.5, 2.0], [1.0, 1.25, 1.5, 2.0], [1.0, 1.25, 1.5, 2.0], [1.0, 1.2, 1.5, 2.0], [1.0, 1.25, 1.5, 2.0], [1.0, 1.25, 1.5, 1.78]]
	var pattern := [0, 2, 1, 3, 2, 1, 3, 2]
	for bar in 8:
		for step in 8:
			if (bar * 8 + step) % 16 == 15:
				continue
			var freq: float = roots[bar] * 2.0 * chords[bar][pattern[step]]
			add_note(layers[0], pluck(freq, 0.55, 0.16 if step % 2 == 0 else 0.11, 0.35), (bar * 4 + step * 0.5) * beat)
		for half in 2:
			add_note(layers[1], pluck(roots[bar] * 0.5, 0.9, 0.34, 0.05), (bar * 4 + half * 2) * beat)
			add_note(layers[1], sweep(150, 50, 0.12, 0.4), (bar * 4 + half * 2) * beat)
		for off in 4:
			add_note(layers[1], sweep(5000, 4000, 0.05, 0.07, 1.0), (bar * 4 + off + 0.5) * beat)
	var melody := [[0, 4, 1.0], [1, 4, 0.5], [1.5, 5, 0.5], [2, 7, 1.5], [4, 5, 1.0], [5, 4, 0.5], [5.5, 2, 0.5], [6, 4, 1.5], [8, 5, 1.0], [9, 5, 0.5], [9.5, 7, 0.5], [10, 9, 1.0], [11, 7, 1.0], [12, 5, 0.75], [12.75, 4, 0.75], [13.5, 2, 0.5], [14, 4, 1.5], [16, 7, 1.0], [17, 9, 0.5], [17.5, 7, 0.5], [18, 4, 1.5], [20, 2, 1.0], [21, 4, 0.5], [21.5, 5, 0.5], [22, 7, 1.5], [24, 9, 1.0], [25, 7, 0.5], [25.5, 5, 0.5], [26, 7, 1.0], [27, 4, 1.0], [28, 2, 1.0], [29, 4, 1.0], [30, 0, 1.5]]
	var degrees := [1.0, 1.125, 1.25, 1.3333, 1.5, 1.6667, 1.875, 2.0, 2.25, 2.5]
	for note in melody:
		var seconds: float = note[2] * beat
		var count := int(seconds * RATE)
		var data := PackedFloat32Array()
		data.resize(count)
		var freq: float = 523.25 * degrees[note[1]]
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			phase += TAU * freq * (1.0 + 0.006 * sin(i * 0.0016 * TAU * 5.5)) / RATE
			data[i] = (sin(phase) + sin(phase * 2.0) * 0.12) * minf(1.0, t * 10.0) * minf(1.0, (1.0 - t) * 5.0) * 0.13
		add_note(layers[2], data, note[0] * beat)
	var streams: Array = []
	for layer in layers:
		streams.append(wav(layer, true))
	install_music.call_deferred(streams)

func add_note(buffer: PackedFloat32Array, note: PackedFloat32Array, at: float) -> void:
	var start := int(at * RATE)
	var size := buffer.size()
	for i in note.size():
		buffer[(start + i) % size] += note[i]

func install_music(streams: Array) -> void:
	for stream in streams:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -60
		add_child(p)
		stems.append(p)
	for p in stems:
		p.play()

func chirp(kind: String, pitch := 1.0, volume := -12.0) -> void:
	if not sfx_on or not tones.has(kind):
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = tones[kind]
	p.pitch_scale = pitch
	p.volume_db = volume
	p.play()

func seed_note() -> void:
	# Quick pickups climb a pentatonic ladder.
	combo = combo + 1 if combo_t > 0 else 0
	combo_t = 0.9
	chirp("seed", SCALE[combo % SCALE.size()] * (2.0 if combo >= SCALE.size() and combo % 16 >= 8 else 1.0), -14.0)

func _process(dt: float) -> void:
	combo_t = maxf(0, combo_t - dt)
	for i in stems.size():
		var want: float = stem_target[i] if music_on else 0.0
		stem_gain[i] = move_toward(stem_gain[i], want, dt * 0.6)
		stems[i].volume_db = linear_to_db(maxf(0.001, stem_gain[i])) - 9.0
	if roller.stream != null:
		# This node keeps running while paused (for the music), so mute the rumble then.
		var level := roll_level if sfx_on and not get_tree().paused else 0.0
		roller.volume_db = linear_to_db(maxf(0.001, level)) - 16.0
		roller.pitch_scale = 0.7 + roll_level * 0.9
