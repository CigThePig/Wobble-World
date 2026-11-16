extends RefCounted
# Many-instance decorations drawn by a single node each, culled to the camera.
const Art = preload("res://game/art.gd")

class SeedDot extends Node2D:
	func _draw() -> void:
		Art.seed_shape(self, Vector2.ZERO, 1.0, 0.9)

class Seeds extends Node2D:
	# One static node per seed (drawn once, batched); only positions change.
	var spots := PackedVector2Array()
	var taken := PackedByteArray()
	var dots: Array = []
	var clock := 0.0
	var world: Node
	func _ready() -> void:
		z_index = 4
	func add(at: Vector2) -> void:
		spots.append(at)
		taken.append(0)
		var dot := SeedDot.new()
		dot.position = at
		add_child(dot)
		dots.append(dot)
	func _physics_process(dt: float) -> void:
		clock += dt
		if world == null:
			return
		var b: Vector2 = world.bloop.position + Vector2(0, -8)
		var cx: float = world.camera.position.x
		for i in spots.size():
			if taken[i] != 0:
				continue
			var p := spots[i]
			if absf(p.x - cx) < 1000:
				dots[i].position.y = p.y + sin(clock * 3.0 + p.x * 0.02) * 4.0
				if absf(p.x - b.x) < 52 and p.distance_to(b) < 50 and not world.bloop.frozen:
					taken[i] = 1
					dots[i].visible = false
					world.collect_seed(p)

class Flora extends Node2D:
	# Tufts and flowers that sway, and get shoved aside when Bloop passes.
	var items: Array = []
	var clock := 0.0
	var world: Node
	var front := true
	const PETALS := [Color("fff6dc"), Color("ff9fbe"), Color("ffd45e"), Color("c9b6ff")]
	func _ready() -> void:
		z_index = 6 if front else 1
		add_to_group("tinted")
	func add(at: Vector2, kind: int, rng: RandomNumberGenerator) -> void:
		items.append({"p": at, "k": kind, "h": rng.randf_range(14, 24) if kind == 0 else rng.randf_range(30, 46), "c": rng.randi() % PETALS.size(), "f": rng.randf() * TAU, "b": 0.0, "v": 0.0})
	func finish() -> void:
		items.sort_custom(func(a, b): return a.p.x < b.p.x)
	func _physics_process(dt: float) -> void:
		if world == null:
			return
		clock += dt
		var b: Vector2 = world.bloop.position
		var vx: float = world.bloop.velocity.x
		for item in items:
			var dx: float = item.p.x - b.x
			if absf(dx) > 950:
				continue
			if absf(dx) < 34 and absf(item.p.y - b.y - 27) < 30:
				item.v += clampf(vx * 0.06, -30, 30) + signf(dx) * 6.0
			item.v += (-90.0 * item.b - 6.0 * item.v) * dt
			item.b = clampf(item.b + item.v * dt, -1.3, 1.3)
		queue_redraw()
	func _draw() -> void:
		var cx: float = world.camera.position.x if world != null else 0.0
		for item in items:
			var p: Vector2 = item.p
			if absf(p.x - cx) > 950:
				continue
			var lean: float = item.b + sin(clock * 1.8 + item.f) * 0.12
			var h: float = item.h
			if item.k == 0:
				# Each blade is a single tapered triangle.
				for k in 3:
					var a := lean + (k - 1) * 0.42
					var tip := p + Vector2(sin(a), -cos(a)) * h * (1.0 if k == 1 else 0.72)
					var base := p + Vector2((k - 1) * 4.0, 3)
					Art.tri(self, base + Vector2(-2.6, 0), base + Vector2(2.6, 0), tip, Art.GRASS_LIGHT if k == 1 else Art.GRASS)
			else:
				var top := p + Vector2(sin(lean), -cos(lean)) * h
				Art.line(self, PackedVector2Array([p, p.lerp(top, 0.5) + Vector2(0, -h * 0.08), top]), Art.GRASS_DARK, 3.5, false)
				for k in 5:
					Art.fill(self, Art.ellipse_points(top + Vector2.from_angle(k * TAU / 5.0 + lean) * 6.5, Vector2(5.2, 5.2), 0.0, 8), PETALS[item.c], false)
				Art.fill(self, Art.ellipse_points(top, Vector2(4.2, 4.2), 0.0, 8), Art.ORANGE, false)
