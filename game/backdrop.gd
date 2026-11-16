extends Node2D
# Screen-space sky: dawn that turns to day when the sun wakes up.
# Stars, clouds and hill layers are child nodes drawn once in white and recoloured
# with modulate, so only the sun and the sky gradient are redrawn each frame.
const Art = preload("res://game/art.gd")
var day := 0.0
var cam := Vector2.ZERO
var clock := 0.0
var stars: Node2D
var sun: Node2D
var clouds: Array = []
var hills: Array = []
var faces_awake := false
const LAYERS := [[0.06, 0.0, 78.0, "7460b0", "b4e6c8", 0.0011, 1.3], [0.13, 0.08, 62.0, "5a4f9e", "8fd8b0", 0.0019, 4.1], [0.24, 0.17, 50.0, "453f8c", "6cc99b", 0.0031, 2.2]]

class Stars extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 46:
			var at := Vector2(rng.randf() * 2600.0, rng.randf() * 600.0)
			var r := rng.randf_range(1.2, 2.4)
			Art.quad(self, at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0), Color(1, 1, 0.92, 0.85), Color(1, 1, 0.92, 0.85))

class Cloud extends Node2D:
	var size := 1.0
	var face := false
	var awake := false
	func _draw() -> void:
		for o in [Vector2(-52, 6), Vector2(-18, -14), Vector2(22, -8), Vector2(54, 8), Vector2(0, 10)]:
			Art.disc(self, o * size, 34.0 * size, Color.WHITE)
		if face:
			for ex in [-12.0, 12.0]:
				if awake:
					Art.disc(self, Vector2(ex * size, 0), 3.0 * size, Art.INK)
				else:
					Art.arc(self, Vector2(ex * size, -2), 5.0 * size, 0.2, PI - 0.2, 6, Art.INK, 2.5)

class Hill extends Node2D:
	var amp := 60.0
	var freq := 0.002
	var phase := 0.0
	var trees := 0.0
	func height(wx: float) -> float:
		return -amp * (0.62 * sin(wx * freq + phase) + 0.38 * sin(wx * freq * 2.7 + phase * 3.0))
	func _draw() -> void:
		var x := -400.0
		while x < 5400.0:
			Art.quad(self, Vector2(x, height(x)), Vector2(x + 40, height(x + 40)), Vector2(x + 40, 1400), Vector2(x, 1400), Color.WHITE, Color.WHITE)
			x += 40.0
		if trees > 0:
			# Lollipop trees stuck on the ridge.
			var shade := Color(0.92, 0.92, 0.92)
			var index := 0
			x = -200.0
			while x < 5300.0:
				var wx := x + fmod(absf(sin(index * 12.9898)) * 43758.5453, 1.0) * 160.0
				var gy := height(wx)
				var h := 60.0 + fmod(absf(sin(index * 78.233)) * 9631.7, 1.0) * 50.0
				Art.quad(self, Vector2(wx - 3.5, gy + 6), Vector2(wx + 3.5, gy + 6), Vector2(wx + 3.5, gy - h), Vector2(wx - 3.5, gy - h), shade, shade)
				Art.disc(self, Vector2(wx, gy - h), 30.0 + h * 0.12, shade)
				Art.disc(self, Vector2(wx - 22, gy - h + 16), 20.0, shade)
				Art.disc(self, Vector2(wx + 22, gy - h + 14), 22.0, shade)
				x += trees
				index += 1

class Sun extends Node2D:
	var day := 0.0
	var clock := 0.0
	func _draw() -> void:
		var radius := 74.0
		Art.glow(self, Vector2.ZERO, radius + 130.0, Color(1, 0.86, 0.55, 0.42 + 0.15 * day))
		if day > 0.05:
			for i in 12:
				var a := i * TAU / 12.0 + clock * 0.25
				var d := Vector2.from_angle(a)
				var n := Vector2(-d.y, d.x)
				var inner := d * (radius + 14.0)
				Art.tri(self, inner - n * 11.0, d * (radius + 18.0 + 34.0 * day + sin(clock * 3.0 + i) * 5.0), inner + n * 11.0, Color(1, 0.84, 0.36, day))
		Art.blob(self, Art.ellipse_points(Vector2.ZERO, Vector2(radius, radius), 0.0, 32), Color("ffb86b").lerp(Color("ffd95a"), day), Art.INK, 4.5)
		Art.disc(self, Vector2(-34, 14), 11, Color(1, 0.5, 0.45, 0.4))
		Art.disc(self, Vector2(34, 14), 11, Color(1, 0.5, 0.45, 0.4))
		for x in [-24.0, 24.0]:
			if day > 0.3:
				Art.ellipse(self, Vector2(x, -10), Vector2(10, 13), Art.CREAM, 0.0, 14)
				Art.disc(self, Vector2(x - 2, -6), 5.5, Art.INK)
			else:
				Art.arc(self, Vector2(x, -12), 10, 0.25, PI - 0.25, 8, Art.INK, 4)
		if day > 0.3:
			var grin := PackedVector2Array()
			for i in 11:
				var a := i * PI / 10.0
				grin.append(Vector2(cos(a) * 17.0, 12.0 + sin(a) * 15.0))
			Art.fill(self, grin, Art.INK)
		else:
			Art.ellipse(self, Vector2(0, 20), Vector2(5, 6 + sin(clock * 1.4) * 2.0), Art.INK, 0.0, 10)
			# Nightcap.
			var tip := Vector2(92, -120 + sin(clock * 1.4) * 4.0)
			Art.blob(self, PackedVector2Array([Vector2(-56, -48), Vector2(-20, -104), tip, Vector2(42, -62), Vector2(-6, -72)]), Art.TEAL, Art.INK, 4.0)
			Art.blob(self, Art.ellipse_points(tip, Vector2(11, 11), 0.0, 12), Art.CREAM, Art.INK, 3.5)
			for k in 3:
				var t := fmod(clock * 0.4 + k / 3.0, 1.0)
				Art.text(self, Vector2(-110 - t * 50, -70 - t * 80), "Z", int(20 + t * 22), Color(1, 1, 1, (1.0 - t) * (1.0 - day * 3.0)))

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	stars = Stars.new()
	add_child(stars)
	sun = Sun.new()
	add_child(sun)
	for i in 7:
		var cloud := Cloud.new()
		cloud.size = rng.randf_range(0.7, 1.3)
		cloud.face = i % 3 == 0
		cloud.set_meta("x", rng.randf() * 2200.0)
		cloud.set_meta("y", 0.08 + rng.randf() * 0.34)
		cloud.set_meta("v", rng.randf_range(5, 14))
		add_child(cloud)
		clouds.append(cloud)
	for k in LAYERS.size():
		var hill := Hill.new()
		hill.amp = LAYERS[k][2]
		hill.freq = LAYERS[k][5]
		hill.phase = LAYERS[k][6]
		hill.trees = 0.0 if k == 0 else (330.0 if k == 1 else 470.0)
		add_child(hill)
		hills.append(hill)

func _process(dt: float) -> void:
	clock += dt
	var size := get_viewport_rect().size
	var horizon := size.y * 0.63 - (cam.y - 500.0) * 0.03
	stars.visible = day < 0.98
	stars.modulate.a = 1.0 - day
	var e := day * day * (3.0 - 2.0 * day)
	sun.position = Vector2(size.x * 0.66 - cam.x * 0.004, lerpf(horizon - 52.0, size.y * 0.22, e))
	sun.day = day
	sun.clock = clock
	# The sleeping sun only needs a slow redraw; awake it spins its rays.
	if day > 0.05 or Engine.get_process_frames() % 4 == 0:
		sun.queue_redraw()
	var tint := Color("f4bfd0").lerp(Color.WHITE, day)
	tint.a = lerpf(0.55, 0.9, day)
	var awake := day > 0.5
	for cloud in clouds:
		cloud.position = Vector2(fposmod(cloud.get_meta("x") + clock * cloud.get_meta("v") - cam.x * 0.05, size.x + 500.0) - 250.0, cloud.get_meta("y") * size.y)
		cloud.modulate = tint
		if cloud.awake != awake:
			cloud.awake = awake
			cloud.queue_redraw()
	for k in hills.size():
		var layer: Array = LAYERS[k]
		hills[k].position = Vector2(-cam.x * layer[0], horizon + size.y * layer[1] - (cam.y - 500.0) * layer[0] * 0.25)
		hills[k].modulate = Color(layer[3]).lerp(Color(layer[4]), day)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var top := Color("2a2768").lerp(Color("4db9ec"), day)
	var mid := Color("8a66ad").lerp(Color("9fe0f2"), day)
	var low := Color("f7a98e").lerp(Color("dff7e6"), day)
	var split := size.y * 0.42
	Art.quad(self, Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, split), Vector2(0, split), top, mid)
	Art.quad(self, Vector2(0, split), Vector2(size.x, split), Vector2(size.x, size.y), Vector2(0, size.y), mid, low)
