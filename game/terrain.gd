extends StaticBody2D
# One solid piece of land: collision polygon plus a cached paper-cut drawing.
const Art = preload("res://game/art.gd")
var poly := PackedVector2Array()
var strata := true
var runs: Array[PackedVector2Array] = []
var seed_value := 1

static func smooth(ctrl: Array, step := 26.0) -> PackedVector2Array:
	# Vector3(x, y, corner). Corners stay sharp; everything else is a spline.
	var out := PackedVector2Array()
	var count := ctrl.size()
	for i in count - 1:
		var a: Vector3 = ctrl[i]
		var b: Vector3 = ctrl[i + 1]
		var p0 := Vector2(a.x, a.y)
		var p1 := Vector2(b.x, b.y)
		if a.z > 0 and b.z > 0:
			out.append(p0)
			continue
		var length := p0.distance_to(p1)
		var m0 := p1 - p0
		var m1 := p1 - p0
		if a.z <= 0 and i > 0:
			m0 = (p1 - Vector2(ctrl[i - 1].x, ctrl[i - 1].y)).normalized() * length
		if b.z <= 0 and i < count - 2:
			m1 = (Vector2(ctrl[i + 2].x, ctrl[i + 2].y) - p0).normalized() * length
		var n := maxi(2, int(ceil(length / step)))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(p0 * (2 * t3 - 3 * t2 + 1) + m0 * (t3 - 2 * t2 + t) + p1 * (-2 * t3 + 3 * t2) + m1 * (t3 - t2))
	out.append(Vector2(ctrl[count - 1].x, ctrl[count - 1].y))
	return out

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = poly
	add_child(shape)
	var run := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var d := b - a
		if d.x > 0.01 and absf(d.y) / d.x < 1.9:
			if run.is_empty():
				run.append(a)
			run.append(b)
		elif not run.is_empty():
			runs.append(run)
			run = PackedVector2Array()
	if not run.is_empty():
		runs.append(run)

func height_at(x: float) -> float:
	var best := INF
	for run in runs:
		if x < run[0].x or x > run[run.size() - 1].x:
			continue
		for i in run.size() - 1:
			if x >= run[i].x and x <= run[i + 1].x:
				var t := (x - run[i].x) / maxf(0.001, run[i + 1].x - run[i].x)
				best = minf(best, lerpf(run[i].y, run[i + 1].y, t))
				break
	return best

func shifted(run: PackedVector2Array, dy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in run:
		out.append(p + Vector2(0, dy))
	return out

func _draw() -> void:
	# Drawn once and cached; everything is a batched primitive.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var indices := Geometry2D.triangulate_polygon(poly)
	for i in range(0, indices.size(), 3):
		Art.tri(self, poly[indices[i]], poly[indices[i + 1]], poly[indices[i + 2]], Art.EARTH)
	if strata:
		# Bands that follow the surface, like layers of cut paper.
		for band in [[34.0, 78.0, Art.EARTH_DARK], [150.0, 235.0, Art.EARTH_DARK], [330.0, 2400.0, Art.EARTH_DEEP]]:
			for run in runs:
				for i in run.size() - 1:
					var a := run[i]
					var b := run[i + 1]
					var wa := sin(a.x * 0.011) * 9.0
					var wb := sin(b.x * 0.011) * 9.0
					Art.quad(self, a + Vector2(0, band[0] + wa), b + Vector2(0, band[0] + wb), b + Vector2(0, band[1] + wb * 1.6), a + Vector2(0, band[1] + wa * 1.6), band[2], band[2])
		for run in runs:
			var span := run[run.size() - 1].x - run[0].x
			for i in int(span / 60.0):
				var x := rng.randf_range(run[0].x + 14, run[run.size() - 1].x - 14)
				var y := height_at(x) + rng.randf_range(95, 140)
				Art.fill(self, Art.ellipse_points(Vector2(x, y), Vector2(rng.randf_range(4, 10), rng.randf_range(3, 6)), rng.randf_range(-0.4, 0.4), 8), Art.EARTH_DARK, false)
	for run in runs:
		Art.line(self, shifted(run, 7), Art.GRASS_DARK, 22)
		Art.line(self, shifted(run, 1), Art.GRASS, 13)
		Art.line(self, shifted(run, -3.5), Art.GRASS_LIGHT, 3.5, false)
