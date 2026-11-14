extends RefCounted
# Shared palette and drawing helpers. The Compatibility renderer has no 2D MSAA,
# so filled shapes get an antialiased edge line in the same colour.

const INK := Color("2a1a3e")
const CREAM := Color("fff6dc")
const ORANGE := Color("ff9950")
const ORANGE_DARK := Color("e9743a")
const ORANGE_LIGHT := Color("ffc27a")
const GOLD := Color("ffd45e")
const GRASS := Color("3fc48a")
const GRASS_DARK := Color("249a78")
const GRASS_LIGHT := Color("9be88f")
const EARTH := Color("c98f63")
const EARTH_DARK := Color("b07a55")
const EARTH_DEEP := Color("9a6a4f")
const PINK := Color("ff7fa6")
const LILAC := Color("b9a2f2")
const TEAL := Color("3aa6b8")
const DAWN_TINT := Color(0.80, 0.82, 0.96)

static func ellipse_points(c: Vector2, r: Vector2, rot := 0.0, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := i * TAU / n
		var x := cos(a) * r.x
		var y := sin(a) * r.y
		pts[i] = c + Vector2(x * cr - y * sr, x * sr + y * cr)
	return pts

# Everything below draws with draw_primitive only. Godot batches primitives
# (across nodes too) but issues one draw call per circle, polygon or polyline,
# so this keeps a whole frame to a handful of calls. Edges are smoothed with a
# thin quad that fades to transparent, since the renderer has no 2D MSAA.
const FEATHER := 1.1
const NO_UV := []

static func tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	ci.draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([color]), PackedVector2Array())

static func quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, top: Color, bottom: Color) -> void:
	# a-b share "top", d-c share "bottom"; drawn as two triangles so any quad shape works.
	ci.draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([top, top, bottom]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([a, c, d]), PackedColorArray([top, bottom, bottom]), PackedVector2Array())

static func ring_normals(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var flip := 1.0 if area > 0 else -1.0
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var d := pts[(i + 1) % n] - pts[(i + n - 1) % n]
		out[i] = Vector2(d.y, -d.x).normalized() * flip
	return out

static func band(ci: CanvasItem, pts: PackedVector2Array, normals: PackedVector2Array, inner: float, outer: float, color_in: Color, color_out: Color, closed := true) -> void:
	var n := pts.size()
	var count := n if closed else n - 1
	for i in count:
		var j := (i + 1) % n
		quad(ci, pts[i] + normals[i] * inner, pts[j] + normals[j] * inner, pts[j] + normals[j] * outer, pts[i] + normals[i] * outer, color_in, color_out)

static func fill(ci: CanvasItem, pts: PackedVector2Array, color: Color, soft := true) -> void:
	# Fan from the centroid: correct for any shape that is star-shaped around it.
	var n := pts.size()
	if n < 3:
		return
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= n
	for i in n:
		tri(ci, mid, pts[i], pts[(i + 1) % n], color)
	if soft:
		band(ci, pts, ring_normals(pts), 0.0, FEATHER, color, Color(color, 0.0))

static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var normals := ring_normals(pts)
	var h := width * 0.5
	var clear := Color(color, 0.0)
	band(ci, pts, normals, -h, h, color, color)
	band(ci, pts, normals, h, h + FEATHER, color, clear)
	band(ci, pts, normals, -h, -h - FEATHER, color, clear)

static func blob(ci: CanvasItem, pts: PackedVector2Array, color: Color, ink: Color, width := 4.0) -> void:
	fill(ci, pts, color, false)
	outline(ci, pts, ink, width)

static func ellipse(ci: CanvasItem, c: Vector2, r: Vector2, color: Color, rot := 0.0, n := 24) -> void:
	fill(ci, ellipse_points(c, r, rot, n), color)

static var units: Dictionary = {}

static func unit(n: int) -> PackedVector2Array:
	# Cached unit circles, so discs need no trigonometry per draw.
	if not units.has(n):
		var pts := PackedVector2Array()
		for i in n + 1:
			pts.append(Vector2.from_angle(i * TAU / n))
		units[n] = pts
	return units[n]

static func disc(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var n := 8 if r < 5 else (12 if r < 14 else (20 if r < 40 else 32))
	var u := unit(n)
	for i in n:
		ci.draw_primitive(PackedVector2Array([c, c + u[i] * r, c + u[i + 1] * r]), PackedColorArray([color]), PackedVector2Array())
	if r >= 5:
		var clear := Color(color, 0.0)
		var outer := r + FEATHER
		for i in n:
			quad(ci, c + u[i] * r, c + u[i + 1] * r, c + u[i + 1] * outer, c + u[i] * outer, color, clear)

static func glow(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	# Radial fade from the centre: one cheap fan instead of stacked translucent discs.
	var clear := Color(color, 0.0)
	var u := unit(12)
	for i in 12:
		ci.draw_primitive(PackedVector2Array([c, c + u[i] * r, c + u[i + 1] * r]), PackedColorArray([color, clear, clear]), PackedVector2Array())

static func hoop(ci: CanvasItem, c: Vector2, r: float, color: Color, width: float) -> void:
	# A cheap ring with no feathering, for short-lived effects.
	var u := unit(20)
	var inner := r - width * 0.5
	var outer := r + width * 0.5
	for i in 20:
		quad(ci, c + u[i] * inner, c + u[i + 1] * inner, c + u[i + 1] * outer, c + u[i] * outer, color, color)

static func ring(ci: CanvasItem, c: Vector2, r: float, color: Color, width: float) -> void:
	outline(ci, ellipse_points(c, Vector2(r, r), 0.0, 20 if r < 40 else 36), color, width)

static func line(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, caps := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var normals := PackedVector2Array()
	normals.resize(n)
	for i in n:
		var d := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		normals[i] = Vector2(d.y, -d.x).normalized()
	var h := width * 0.5
	var clear := Color(color, 0.0)
	band(ci, pts, normals, -h, h, color, color, false)
	band(ci, pts, normals, h, h + FEATHER, color, clear, false)
	band(ci, pts, normals, -h, -h - FEATHER, color, clear, false)
	if caps and width >= 4.5:
		disc(ci, pts[0], h, color)
		disc(ci, pts[n - 1], h, color)

static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	line(ci, PackedVector2Array([a, b]), color, width)

static func arc(ci: CanvasItem, c: Vector2, r: float, from: float, to: float, steps: int, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * r)
	line(ci, pts, color, width)

static func curve(a: Vector2, c: Vector2, b: Vector2, n := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts

static func rounded_rect(rect: Rect2, radius: float, n := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r), rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	for k in 4:
		for i in n + 1:
			var a := PI + k * PI * 0.5 + i * PI * 0.5 / n
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	return pts

static func panel(ci: CanvasItem, rect: Rect2, radius: float, color: Color, ink := Color(0, 0, 0, 0), width := 0.0) -> void:
	var pts := rounded_rect(rect, radius)
	fill(ci, pts, color)
	if width > 0:
		outline(ci, pts, ink, width)

static func text(ci: CanvasItem, at: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var pos := at
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0:
		var w := ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= w * 0.5
		ci.draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	else:
		ci.draw_string(ThemeDB.fallback_font, pos, s, align, width, size, color)

static func text_outlined(ci: CanvasItem, at: Vector2, s: String, size: int, color: Color, ink: Color, thickness := 6) -> void:
	var w := ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at - Vector2(w * 0.5, 0)
	ci.draw_string_outline(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, thickness, ink)
	ci.draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func seed_shape(ci: CanvasItem, c: Vector2, s: float, glow_amount := 1.0) -> void:
	# A sunseed: glowing golden drop.
	if glow_amount > 0:
		glow(ci, c, 22 * s, Color(1, 0.88, 0.45, 0.42 * glow_amount))
	var pts := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12
		var r := 8.0 * s * (1.0 + 0.32 * maxf(0.0, -sin(a)) * maxf(0.0, -sin(a)))
		pts.append(c + Vector2(cos(a) * 7.0 * s, sin(a) * r))
	blob(ci, pts, GOLD, INK, 2.5)
	disc(ci, c + Vector2(-2.2, -1.5) * s, 2.2 * s, Color(1, 1, 0.9, 0.9))

static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, color: Color) -> void:
	match kind:
		"jump":
			line(ci, PackedVector2Array([c + Vector2(-13, 2) * s, c + Vector2(0, -13) * s, c + Vector2(13, 2) * s]), color, 6 * s)
			stroke(ci, c + Vector2(0, -11) * s, c + Vector2(0, 15) * s, color, 6 * s)
		"roll":
			arc(ci, c, 13 * s, -0.4, PI * 1.45, 24, color, 5.5 * s)
			var tip := c + Vector2(cos(-0.4), sin(-0.4)) * 13 * s
			fill(ci, PackedVector2Array([tip + Vector2(-8, -3) * s, tip + Vector2(6, -6) * s, tip + Vector2(1, 8) * s]), color, false)
		"legs":
			disc(ci, c + Vector2(0, -6) * s, 9 * s, color)
			# Bowed noodle legs and round shoes, matching Bloop.
			line(ci, curve(c + Vector2(-4, 2) * s, c + Vector2(-1, 8) * s, c + Vector2(-6, 13) * s, 6), color, 3.5 * s)
			line(ci, curve(c + Vector2(4, 2) * s, c + Vector2(7, 8) * s, c + Vector2(6, 13) * s, 6), color, 3.5 * s)
			for side in [-1.0, 1.0]:
				var shoe := PackedVector2Array()
				for k in 9:
					shoe.append(c + Vector2(side * 6 + 1.5 + cos(PI * k / 8) * 4.5, 16 - sin(PI * k / 8) * 4) * s)
				fill(ci, shoe, color, false)
		"kick":
			stroke(ci, c + Vector2(-12, -12) * s, c + Vector2(-4, 4) * s, color, 6 * s)
			stroke(ci, c + Vector2(-4, 4) * s, c + Vector2(9, 4) * s, color, 7 * s)
			for i in 3:
				var a := -0.7 + i * 0.5
				stroke(ci, c + Vector2(12, 0) * s + Vector2.from_angle(a) * 5 * s, c + Vector2(12, 0) * s + Vector2.from_angle(a) * 10 * s, color, 2.5 * s)
		"pound":
			stroke(ci, c + Vector2(0, -15) * s, c + Vector2(0, 4) * s, color, 6 * s)
			line(ci, PackedVector2Array([c + Vector2(-11, -5) * s, c + Vector2(0, 7) * s, c + Vector2(11, -5) * s]), color, 6 * s)
			stroke(ci, c + Vector2(-14, 15) * s, c + Vector2(14, 15) * s, color, 4 * s)
		"boost":
			for i in 2:
				var o := Vector2(-7 + i * 12, 0) * s
				line(ci, PackedVector2Array([c + o + Vector2(-6, -11) * s, c + o + Vector2(5, 0) * s, c + o + Vector2(-6, 11) * s]), color, 5.5 * s)
		"move":
			line(ci, PackedVector2Array([c + Vector2(-8, -9) * s, c + Vector2(-17, 0) * s, c + Vector2(-8, 9) * s]), color, 5 * s)
			line(ci, PackedVector2Array([c + Vector2(8, -9) * s, c + Vector2(17, 0) * s, c + Vector2(8, 9) * s]), color, 5 * s)
			disc(ci, c, 4 * s, color)
		"pause":
			stroke(ci, c + Vector2(-6, -9) * s, c + Vector2(-6, 9) * s, color, 6 * s)
			stroke(ci, c + Vector2(6, -9) * s, c + Vector2(6, 9) * s, color, 6 * s)
		"boing":
			arc(ci, c + Vector2(0, 6) * s, 13 * s, PI, TAU, 16, color, 6 * s)
			stroke(ci, c + Vector2(0, -12) * s, c + Vector2(0, -20) * s, color, 4 * s)
			line(ci, PackedVector2Array([c + Vector2(-6, -16) * s, c + Vector2(0, -22) * s, c + Vector2(6, -16) * s]), color, 4 * s)
