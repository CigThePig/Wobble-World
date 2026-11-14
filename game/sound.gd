extends Node
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var samples_left := 0
var total := 0
var pitch := 400.0
var phase := 0.0
func _ready() -> void:
	player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.12
	player.stream = generator
	player.volume_db = -19
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
func chirp(kind: String) -> void:
	pitch = {"jump": 520.0,"spring": 760.0,"roll": 260.0,"walk": 390.0,"land": 150.0,"bump": 180.0,"bell": 980.0}.get(kind, 300.0)
	total = 6000 if kind == "bell" else 2400
	samples_left = total
func _process(_dt: float) -> void:
	if playback == null:
		return
	for i in playback.get_frames_available():
		var value := 0.0
		if samples_left > 0:
			var envelope := float(samples_left) / total
			phase += TAU * pitch * (0.85 + envelope * 0.3) / 22050.0
			value = (sin(phase) + sin(phase * 2.01) * 0.18) * minf(1, (total - samples_left) / 120.0) * envelope * 0.5
			samples_left -= 1
		playback.push_frame(Vector2(value,value))

func _exit_tree() -> void:
	player.stop()
	playback = null
