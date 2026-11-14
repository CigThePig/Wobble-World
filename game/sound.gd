extends Node
# Original short tones, synthesized locally into PCM; no external sound assets.
var player: AudioStreamPlayer
var tones: Dictionary = {}
func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -19
	add_child(player)
	var pitches := {"jump":520.0,"spring":760.0,"roll":260.0,"walk":390.0,"land":150.0,"bump":180.0,"bell":980.0}
	for kind in pitches:
		var total := 6000 if kind == "bell" else 2400
		var bytes := PackedByteArray()
		bytes.resize(total * 2)
		var phase := 0.0
		for i in total:
			var envelope := 1.0 - float(i) / total
			phase += TAU * pitches[kind] * (0.85 + envelope * 0.3) / 22050.0
			var value := (sin(phase) + sin(phase * 2.01) * 0.18) * minf(1, i / 120.0) * envelope * 0.5
			bytes.encode_s16(i * 2, int(value * 32767))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = bytes
		tones[kind] = stream
func chirp(kind: String) -> void:
	if tones.has(kind):
		player.stream = tones[kind]
		player.play()
