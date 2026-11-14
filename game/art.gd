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

static func fill(ci: CanvasItem, pts: PackedVector2Array, color: Color, soft := true) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, color)
	if soft:
		outline(ci, pts, color, 1.3)

static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	closed.append(pts[1])
	ci.draw_polyline(closed, color, width, true)

static func blob(ci: CanvasItem, pts: PackedVector2Array, color: Color, ink: Color, width := 4.0) -> void:
	ci.draw_colored_polygon(pts, color)
	outline(ci, pts, ink, width)

static func ellipse(ci: CanvasItem, c: Vector2, r: Vector2, color: Color, rot := 0.0, n := 24) -> void:
	fill(ci, ellipse_points(c, r, rot, n), color)

static func disc(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	fill(ci, ellipse_points(c, Vector2(r, r), 0.0, 14 if r < 8 else 28), color)

static func ring(ci: CanvasItem, c: Vector2, r: float, color: Color, width: float) -> void:
	ci.draw_arc(c, r, 0, TAU, 40, color, width, true)

static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# A line with round caps.
	ci.draw_line(a, b, color, width, true)
	ci.draw_circle(a, width * 0.5, color)
	ci.draw_circle(b, width * 0.5, color)

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

static func seed_shape(ci: CanvasItem, c: Vector2, s: float, glow := 1.0) -> void:
	# A sunseed: glowing golden drop.
	ci.draw_circle(c, 17 * s, Color(1, 0.86, 0.4, 0.16 * glow))
	ci.draw_circle(c, 12 * s, Color(1, 0.9, 0.5, 0.2 * glow))
	var pts := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16
		var r := 8.0 * s * (1.0 + 0.32 * maxf(0.0, -sin(a)) * maxf(0.0, -sin(a)))
		pts.append(c + Vector2(cos(a) * 7.0 * s, sin(a) * r))
	blob(ci, pts, GOLD, INK, 2.5)
	ci.draw_circle(c + Vector2(-2.2, -1.5) * s, 2.2 * s, Color(1, 1, 0.9, 0.9))

static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, color: Color) -> void:
	match kind:
		"jump":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-13, 2) * s, c + Vector2(0, -13) * s, c + Vector2(13, 2) * s]), color, 6 * s, true)
			stroke(ci, c + Vector2(0, -11) * s, c + Vector2(0, 15) * s, color, 6 * s)
		"roll":
			ci.draw_arc(c, 13 * s, -0.4, PI * 1.45, 24, color, 5.5 * s, true)
			var tip := c + Vector2(cos(-0.4), sin(-0.4)) * 13 * s
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, -3) * s, tip + Vector2(6, -6) * s, tip + Vector2(1, 8) * s]), color)
		"legs":
			ci.draw_circle(c + Vector2(0, -6) * s, 9 * s, color)
			stroke(ci, c + Vector2(-5, 2) * s, c + Vector2(-7, 14) * s, color, 4.5 * s)
			stroke(ci, c + Vector2(5, 2) * s, c + Vector2(7, 14) * s, color, 4.5 * s)
			stroke(ci, c + Vector2(-7, 14) * s, c + Vector2(-12, 14) * s, color, 4.5 * s)
			stroke(ci, c + Vector2(7, 14) * s, c + Vector2(12, 14) * s, color, 4.5 * s)
		"kick":
			stroke(ci, c + Vector2(-12, -12) * s, c + Vector2(-4, 4) * s, color, 6 * s)
			stroke(ci, c + Vector2(-4, 4) * s, c + Vector2(9, 4) * s, color, 7 * s)
			for i in 3:
				var a := -0.7 + i * 0.5
				stroke(ci, c + Vector2(12, 0) * s + Vector2.from_angle(a) * 5 * s, c + Vector2(12, 0) * s + Vector2.from_angle(a) * 10 * s, color, 2.5 * s)
		"pound":
			stroke(ci, c + Vector2(0, -15) * s, c + Vector2(0, 4) * s, color, 6 * s)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-11, -5) * s, c + Vector2(0, 7) * s, c + Vector2(11, -5) * s]), color, 6 * s, true)
			stroke(ci, c + Vector2(-14, 15) * s, c + Vector2(14, 15) * s, color, 4 * s)
		"boost":
			for i in 2:
				var o := Vector2(-7 + i * 12, 0) * s
				ci.draw_polyline(PackedVector2Array([c + o + Vector2(-6, -11) * s, c + o + Vector2(5, 0) * s, c + o + Vector2(-6, 11) * s]), color, 5.5 * s, true)
		"move":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-8, -9) * s, c + Vector2(-17, 0) * s, c + Vector2(-8, 9) * s]), color, 5 * s, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(8, -9) * s, c + Vector2(17, 0) * s, c + Vector2(8, 9) * s]), color, 5 * s, true)
			ci.draw_circle(c, 4 * s, color)
		"pause":
			stroke(ci, c + Vector2(-6, -9) * s, c + Vector2(-6, 9) * s, color, 6 * s)
			stroke(ci, c + Vector2(6, -9) * s, c + Vector2(6, 9) * s, color, 6 * s)
		"boing":
			ci.draw_arc(c + Vector2(0, 6) * s, 13 * s, PI, TAU, 16, color, 6 * s, true)
			stroke(ci, c + Vector2(0, -12) * s, c + Vector2(0, -20) * s, color, 4 * s)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-6, -16) * s, c + Vector2(0, -22) * s, c + Vector2(6, -16) * s]), color, 4 * s, true)
