extends Node2D
# Tiny pooled particle painter: dust, sparkles, splashes, confetti, rings.
const Art = preload("res://game/art.gd")
var parts: Array = []
const CONFETTI := [Color("ff7fa6"), Color("ffd45e"), Color("7fe0c0"), Color("b9a2f2"), Color("fff6dc"), Color("ff9950")]

func _ready() -> void:
	z_index = 9

func add(kind: String, at: Vector2, vel: Vector2, life: float, size: float, color: Color, gravity := 0.0) -> void:
	if parts.size() > 420:
		return
	parts.append({"k": kind, "p": at, "v": vel, "t": 0.0, "life": life, "s": size, "c": color, "g": gravity, "r": randf() * TAU, "w": randf_range(-8, 8)})

func burst(kind: String, at: Vector2, count := 6, dir := Vector2.UP, power := 1.0) -> void:
	match kind:
		"dust":
			for i in count:
				add("puff", at + Vector2(randf_range(-10, 10), randf_range(-4, 2)), (dir.rotated(randf_range(-1.2, 1.2)) * randf_range(40, 130) + Vector2(0, -20)) * power, randf_range(0.3, 0.55), randf_range(5, 10), Color(1, 0.97, 0.88, 0.7))
		"spark":
			for i in count:
				add("spark", at, Vector2.from_angle(randf() * TAU) * randf_range(70, 190) * power, randf_range(0.3, 0.55), randf_range(3, 6), Art.GOLD.lerp(Art.CREAM, randf() * 0.6), 160)
		"star":
			for i in count:
				add("star", at, Vector2.from_angle(randf() * TAU) * randf_range(120, 260) * power, randf_range(0.3, 0.5), randf_range(6, 10), Art.CREAM, 300)
		"splash":
			for i in count:
				add("drop", at + Vector2(randf_range(-18, 18), 0), Vector2(randf_range(-170, 170), randf_range(-520, -220)) * power, randf_range(0.5, 0.9), randf_range(4, 8), Color(0.75, 0.95, 1.0, 0.95), 1300)
		"chunk":
			for i in count:
				add("chunk", at + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Vector2(randf_range(-220, 220), randf_range(-380, -60)) * power, randf_range(0.6, 1.0), randf_range(6, 13), Color("d9b48a").darkened(randf() * 0.2), 1400)
		"confetti":
			for i in count:
				add("confetti", at + Vector2(randf_range(-60, 60), randf_range(-20, 20)), Vector2(randf_range(-330, 330), randf_range(-760, -260)) * power, randf_range(1.6, 2.8), randf_range(6, 11), CONFETTI[randi() % CONFETTI.size()], 520)
		"ring":
			add("ring", at, Vector2.ZERO, 0.4 * power, 26.0 * power, Color(1, 0.98, 0.9, 0.9))
		"leaf":
			for i in count:
				add("confetti", at, Vector2(randf_range(-120, 120), randf_range(-220, -60)), randf_range(0.6, 1.0), randf_range(4, 7), Art.GRASS_LIGHT.lerp(Art.GRASS, randf()), 500)

func _physics_process(dt: float) -> void:
	if parts.is_empty():
		return
	var keep: Array = []
	for p in parts:
		p.t += dt
		if p.t < p.life:
			p.v.y += p.g * dt
			if p.k == "confetti":
				p.v *= 1.0 - 1.6 * dt
				p.v.x += sin(p.t * 6.0 + p.r) * 240.0 * dt
			elif p.k == "puff":
				p.v *= 1.0 - 3.0 * dt
			p.p += p.v * dt
			p.r += p.w * dt
			keep.append(p)
	parts = keep
	queue_redraw()

func _draw() -> void:
	for p in parts:
		var f: float = p.t / p.life
		var color: Color = p.c
		match p.k:
			"puff":
				color.a *= 1.0 - f
				draw_circle(p.p, p.s * (0.6 + f * 1.3), color)
			"spark":
				var s: float = maxf(0.4, p.s * (1.0 - f))
				draw_colored_polygon(PackedVector2Array([p.p + Vector2(0, -s * 1.6), p.p + Vector2(s, 0), p.p + Vector2(0, s * 1.6), p.p + Vector2(-s, 0)]), color)
			"star":
				var s: float = p.s * (1.0 - f * 0.7)
				for k in 2:
					var d: Vector2 = Vector2.from_angle(p.r + k * PI * 0.5) * s
					draw_line(p.p - d, p.p + d, color, 3.2, true)
			"drop":
				color.a *= 1.0 - f * f
				draw_circle(p.p, p.s * (1.0 - f * 0.5), color)
			"chunk", "confetti":
				color.a *= minf(1.0, (1.0 - f) * 3.0)
				var a: Vector2 = Vector2.from_angle(p.r) * p.s
				var b: Vector2 = Vector2.from_angle(p.r + PI * 0.5) * p.s * (0.55 if p.k == "confetti" else 0.9)
				draw_colored_polygon(PackedVector2Array([p.p - a - b, p.p + a - b, p.p + a + b, p.p - a + b]), color)
			"ring":
				color.a *= 1.0 - f
				draw_arc(p.p, p.s * (0.4 + f * 3.2), 0, TAU, 36, color, 7.0 * (1.0 - f) + 1.0, true)
