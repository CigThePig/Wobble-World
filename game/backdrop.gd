extends Node2D
# Screen-space sky: dawn that turns to day when the sun wakes up.
const Art = preload("res://game/art.gd")
var day := 0.0
var cam := Vector2.ZERO
var clock := 0.0
var stars: Array = []
var clouds: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		stars.append(Vector3(rng.randf(), rng.randf() * 0.55, rng.randf() * TAU))
	for i in 7:
		clouds.append({"x": rng.randf() * 2200.0, "y": 0.08 + rng.randf() * 0.34, "s": rng.randf_range(0.7, 1.3), "v": rng.randf_range(5, 14), "face": i % 3 == 0})

func _process(dt: float) -> void:
	clock += dt
	queue_redraw()

func mix(dawn: String, noon: String) -> Color:
	return Color(dawn).lerp(Color(noon), day)

func _draw() -> void:
	var size := get_viewport_rect().size
	var top := mix("2a2768", "4db9ec")
	var mid := mix("8a66ad", "9fe0f2")
	var low := mix("f7a98e", "dff7e6")
	var split := size.y * 0.42
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, split), Vector2(0, split)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, split), Vector2(size.x, split), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([mid, mid, low, low]))
	if day < 0.98:
		for s in stars:
			var a := (0.45 + 0.4 * sin(clock * 1.7 + s.z)) * (1.0 - day)
			draw_circle(Vector2(s.x * size.x, s.y * size.y), 1.6 + sin(s.z) * 0.6, Color(1, 1, 0.92, a))
	var horizon := size.y * 0.63 - (cam.y - 500.0) * 0.03
	# The sun: asleep behind the hills at dawn, high and beaming once woken.
	var e := day * day * (3.0 - 2.0 * day)
	var sun := Vector2(size.x * 0.66 - cam.x * 0.004, lerpf(horizon - 52.0, size.y * 0.22, e))
	var radius := 74.0
	for k in 3:
		draw_circle(sun, radius + 30.0 + k * 34.0, Color(1, 0.86, 0.55, 0.10 + 0.05 * day))
	if day > 0.05:
		for i in 12:
			var a := i * TAU / 12.0 + clock * 0.25
			var d := Vector2.from_angle(a)
			var n := Vector2(-d.y, d.x)
			var inner := sun + d * (radius + 14.0)
			draw_colored_polygon(PackedVector2Array([inner - n * 11.0, sun + d * (radius + 18.0 + 34.0 * day + sin(clock * 3.0 + i) * 5.0), inner + n * 11.0]), Color(1, 0.84, 0.36, day))
	Art.blob(self, Art.ellipse_points(sun, Vector2(radius, radius), 0.0, 40), mix("ffb86b", "ffd95a"), Art.INK, 4.5)
	draw_circle(sun + Vector2(-34, 14), 11, Color(1, 0.5, 0.45, 0.4))
	draw_circle(sun + Vector2(34, 14), 11, Color(1, 0.5, 0.45, 0.4))
	for x in [-24.0, 24.0]:
		if day > 0.3:
			Art.ellipse(self, sun + Vector2(x, -10), Vector2(10, 13), Art.CREAM, 0.0, 16)
			draw_circle(sun + Vector2(x - 2, -6), 5.5, Art.INK)
		else:
			draw_arc(sun + Vector2(x, -12), 10, 0.25, PI - 0.25, 10, Art.INK, 4, true)
	if day > 0.3:
		var grin := PackedVector2Array()
		for i in 11:
			var a := i * PI / 10.0
			grin.append(sun + Vector2(cos(a) * 17.0, 12.0 + sin(a) * 15.0))
		Art.fill(self, grin, Art.INK)
	else:
		Art.ellipse(self, sun + Vector2(0, 20), Vector2(5, 6 + sin(clock * 1.4) * 2.0), Art.INK, 0.0, 12)
		# Nightcap.
		var cap := PackedVector2Array([sun + Vector2(-56, -48), sun + Vector2(-6, -72), sun + Vector2(42, -62), sun + Vector2(92, -120 + sin(clock * 1.4) * 4.0)])
		var tipc := cap[3]
		Art.blob(self, PackedVector2Array([cap[0], sun + Vector2(-20, -104), tipc, cap[2], cap[1]]), Art.TEAL, Art.INK, 4.0)
		Art.blob(self, Art.ellipse_points(tipc, Vector2(11, 11), 0.0, 14), Art.CREAM, Art.INK, 3.5)
		for k in 3:
			var t := fmod(clock * 0.4 + k / 3.0, 1.0)
			Art.text(self, sun + Vector2(-110 - t * 50, -70 - t * 80), "Z", int(20 + t * 22), Color(1, 1, 1, (1.0 - t) * (1.0 - day * 3.0)))
	# Clouds.
	for c in clouds:
		var x := fposmod(c.x + clock * c.v - cam.x * 0.05, size.x + 500.0) - 250.0
		var y: float = c.y * size.y
		var s: float = c.s
		var tint := mix("f4bfd0", "ffffff")
		tint.a = lerpf(0.55, 0.9, day)
		for o in [Vector2(-52, 6), Vector2(-18, -14), Vector2(22, -8), Vector2(54, 8), Vector2(0, 10)]:
			draw_circle(Vector2(x, y) + o * s, 34.0 * s, tint)
		if c.face:
			for ex in [-12.0, 12.0]:
				if day > 0.5:
					draw_circle(Vector2(x + ex * s, y), 3.0 * s, Art.INK)
				else:
					draw_arc(Vector2(x + ex * s, y - 2), 5.0 * s, 0.2, PI - 0.2, 8, Art.INK, 2.5, true)
	# Parallax hills.
	var layers := [[0.06, 0.0, 78.0, mix("7460b0", "b4e6c8"), 0.0011, 1.3], [0.13, 0.08, 62.0, mix("5a4f9e", "8fd8b0"), 0.0019, 4.1], [0.24, 0.17, 50.0, mix("453f8c", "6cc99b"), 0.0031, 2.2]]
	for k in layers.size():
		var layer: Array = layers[k]
		var base: float = horizon + size.y * layer[1] - (cam.y - 500.0) * layer[0] * 0.25
		var pts := PackedVector2Array()
		var x := -20.0
		while x <= size.x + 40.0:
			var wx: float = x + cam.x * layer[0]
			pts.append(Vector2(x, base - layer[2] * (0.62 * sin(wx * layer[4] + layer[5]) + 0.38 * sin(wx * layer[4] * 2.7 + layer[5] * 3.0))))
			x += 36.0
		pts.append(Vector2(size.x + 40, size.y + 10))
		pts.append(Vector2(-20, size.y + 10))
		draw_colored_polygon(pts, layer[3])
		if k > 0:
			# Lollipop trees stuck on the ridge.
			var spacing := 330.0 if k == 1 else 470.0
			var first := floorf((cam.x * layer[0] - 100.0) / spacing)
			for i in int(size.x / spacing) + 3:
				var wx: float = (first + i) * spacing + fmod(absf(sin((first + i) * 12.9898)) * 43758.5453, 1.0) * 160.0
				var sx: float = wx - cam.x * layer[0]
				var gy: float = base - layer[2] * (0.62 * sin(wx * layer[4] + layer[5]) + 0.38 * sin(wx * layer[4] * 2.7 + layer[5] * 3.0))
				var h := 60.0 + fmod(absf(sin((first + i) * 78.233)) * 9631.7, 1.0) * 50.0
				var shade: Color = layer[3].darkened(0.08)
				draw_line(Vector2(sx, gy + 6), Vector2(sx, gy - h), shade, 7.0)
				draw_circle(Vector2(sx, gy - h), 30.0 + h * 0.12, shade)
				draw_circle(Vector2(sx - 22, gy - h + 16), 20.0, shade)
				draw_circle(Vector2(sx + 22, gy - h + 14), 22.0, shade)
