extends RefCounted
# Small world objects. Each is a self-drawing node; the world owns interactions.
const Art = preload("res://game/art.gd")

class Mushroom extends Node2D:
	var power := 900.0
	var width := 120.0
	var squish := 0.0
	var squish_v := 0.0
	var hue := Art.PINK
	func up() -> Vector2:
		return Vector2.UP.rotated(rotation)
	func check(bloop: Node) -> bool:
		var local: Vector2 = (bloop.global_position - global_position).rotated(-rotation)
		if absf(local.x) < width * 0.5 + 4 and local.y > -78 and local.y < 4 and bloop.velocity.dot(up()) < 60:
			if bloop.launch(up(), power):
				squish_v = 14.0
				return true
		return false
	func _physics_process(dt: float) -> void:
		if absf(squish) > 0.002 or absf(squish_v) > 0.02:
			squish_v += (-380.0 * squish - 9.0 * squish_v) * dt
			squish += squish_v * dt
			queue_redraw()
	func _draw() -> void:
		var s := clampf(squish, -0.5, 0.6)
		var cap_y := -40.0 + s * 22.0
		var half := width * 0.5 * (1.0 + s * 0.25)
		var stem := PackedVector2Array([Vector2(-width * 0.2, 2), Vector2(-width * 0.15, cap_y + 8), Vector2(width * 0.15, cap_y + 8), Vector2(width * 0.2, 2)])
		Art.blob(self, stem, Art.CREAM, Art.INK, 3.5)
		Art.disc(self, Vector2(-7, cap_y * 0.5 + 8), 2.4, Art.INK)
		Art.disc(self, Vector2(7, cap_y * 0.5 + 8), 2.4, Art.INK)
		var cap := PackedVector2Array()
		for i in 15:
			var a := PI + i * PI / 14.0
			cap.append(Vector2(cos(a) * half, cap_y + 10 + sin(a) * 30.0 * (1.0 - s * 0.6)))
		Art.blob(self, cap, hue, Art.INK, 4.0)
		for i in 4:
			var x := (-0.6 + i * 0.4) * half
			Art.ellipse(self, Vector2(x, cap_y - 6 - (1.0 - absf(x) / half) * 8.0), Vector2(7, 5), Art.CREAM, 0.0, 12)

class Toy extends RigidBody2D:
	var kind := "crate"
	var home := Vector2.ZERO
	var kick_radius := 34.0
	var blink := 0.0
	func _ready() -> void:
		var collision := CollisionShape2D.new()
		if kind == "ball":
			collision.shape = CircleShape2D.new()
			collision.shape.radius = 22.0
			mass = 0.5
		else:
			collision.shape = RectangleShape2D.new()
			collision.shape.size = Vector2(62, 62)
			mass = 1.2
		add_child(collision)
		collision_layer = 4
		collision_mask = 1 | 2 | 4
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = 0.6
		physics_material_override.bounce = 0.55 if kind == "ball" else 0.12
		linear_damp = 0.15
		angular_damp = 0.6
		add_to_group("kickable")
		add_to_group("tinted")
		z_index = 2
	func kicked(dir: float, power: float) -> void:
		sleeping = false
		apply_central_impulse(Vector2(dir * power, -power * 0.72) * mass * (1.25 if kind == "ball" else 1.0))
		angular_velocity += dir * 7.0
		blink = 0.5
		queue_redraw()
	func _physics_process(dt: float) -> void:
		if blink > 0:
			blink -= dt
			if blink <= 0:
				queue_redraw()
	func _draw() -> void:
		var ouch := blink > 0
		if kind == "ball":
			Art.blob(self, Art.ellipse_points(Vector2.ZERO, Vector2(22, 22)), Art.LILAC, Art.INK, 4.0)
			Art.arc(self, Vector2.ZERO, 15, 0.4, 2.2, 10, Color("9a80e0"), 4)
		else:
			Art.blob(self, Art.rounded_rect(Rect2(-31, -31, 62, 62), 9), Color("f2c26b"), Art.INK, 4.0)
			Art.stroke(self, Vector2(-31, -12), Vector2(31, -12), Color("d99c45"), 4)
			Art.stroke(self, Vector2(-31, 14), Vector2(31, 14), Color("d99c45"), 4)
		for x in [-9.0, 9.0]:
			if ouch:
				Art.stroke(self, Vector2(x - 4, -4), Vector2(x + 4, 2), Art.INK, 2.6)
				Art.stroke(self, Vector2(x - 4, 2), Vector2(x + 4, -4), Art.INK, 2.6)
			else:
				Art.disc(self, Vector2(x, -1), 3.2, Art.INK)
		if ouch:
			Art.disc(self, Vector2(0, 9), 3.5, Art.INK)
		else:
			Art.arc(self, Vector2(0, 5), 4.5, 0.3, PI - 0.3, 8, Art.INK, 2.4)

class Plate extends Node2D:
	var pressed := false
	var sink := 0.0
	func _physics_process(dt: float) -> void:
		var target := 9.0 if pressed else 0.0
		if not is_equal_approx(sink, target):
			sink = move_toward(sink, target, dt * 60.0)
			queue_redraw()
	func _draw() -> void:
		Art.blob(self, Art.rounded_rect(Rect2(-62, -4, 124, 16), 6), Color("7c6a8f"), Art.INK, 3.5)
		Art.blob(self, Art.rounded_rect(Rect2(-50, -16 + sink, 100, 16), 6), Art.GRASS_LIGHT if pressed else Art.PINK, Art.INK, 3.5)

class Gate extends StaticBody2D:
	var open := false
	var slide := 0.0
	var height := 330.0
	var base := Vector2.ZERO
	func _ready() -> void:
		var collision := CollisionShape2D.new()
		collision.shape = RectangleShape2D.new()
		collision.shape.size = Vector2(52, height)
		collision.position = Vector2(0, -height * 0.5)
		add_child(collision)
		base = position
		z_index = -1
		add_to_group("tinted")
	func _physics_process(dt: float) -> void:
		var target := height + 8.0 if open else 0.0
		if not is_equal_approx(slide, target):
			slide = move_toward(slide, target, dt * 260.0)
			position = base + Vector2(randf_range(-1.5, 1.5), slide)
	func _draw() -> void:
		Art.blob(self, Art.rounded_rect(Rect2(-26, -height, 52, height), 12), Color("8f7fb0"), Art.INK, 4.5)
		for i in 5:
			Art.stroke(self, Vector2(-26, -height + 50 + i * 58), Vector2(26, -height + 50 + i * 58), Color("7767a0"), 4)
		# A grumpy face that would rather stay shut.
		Art.stroke(self, Vector2(-14, -height + 24), Vector2(-5, -height + 28), Art.INK, 3)
		Art.stroke(self, Vector2(14, -height + 24), Vector2(5, -height + 28), Art.INK, 3)
		Art.disc(self, Vector2(-9, -height + 33), 2.6, Art.INK)
		Art.disc(self, Vector2(9, -height + 33), 2.6, Art.INK)
		Art.arc(self, Vector2(0, -height + 46), 5, PI + 0.3, TAU - 0.3, 8, Art.INK, 2.5)

class Crumble extends StaticBody2D:
	var size := 50.0
	func _ready() -> void:
		var collision := CollisionShape2D.new()
		collision.shape = RectangleShape2D.new()
		collision.shape.size = Vector2(size, size)
		add_child(collision)
		add_to_group("tinted")
	func _draw() -> void:
		var h := size * 0.5
		Art.blob(self, Art.rounded_rect(Rect2(-h + 1, -h, size - 2, size), 7), Color("d9b48a"), Art.INK, 3.5)
		Art.line(self, PackedVector2Array([Vector2(-h + 8, -6), Vector2(-6, 2), Vector2(-10, 14), Vector2(4, h - 6)]), Color("8a6a55"), 2.5)
		Art.line(self, PackedVector2Array([Vector2(-6, 2), Vector2(10, -8), Vector2(h - 7, -4)]), Color("8a6a55"), 2.5)

class Critter extends Node2D:
	var lines: Array = []
	var after := ""
	var hue := Art.LILAC
	var tall := 1.0
	var hat := 0
	var near := false
	var shown := 0.0
	var line := -1
	var clock := 0.0
	var hop := 0.0
	var hop_v := 0.0
	var ouch := 0.0
	var kick_radius := 30.0
	var world: Node
	func _ready() -> void:
		add_to_group("kickable")
		add_to_group("tinted")
		z_index = 3
	func kicked(_dir: float, _power: float) -> void:
		hop_v = -260.0
		ouch = 1.6
		shown = 0.0
		if world != null:
			world.fx.burst("star", global_position + Vector2(0, -40), 5)
	func text() -> String:
		if ouch > 0:
			return ["Ow. Rude. Fair, but rude.", "Hey! I bruise like a peach.", "I felt that in my roots."][maxi(line, 0) % 3]
		if world != null and world.awake and after != "":
			return after
		return lines[maxi(line, 0) % lines.size()]
	func _physics_process(dt: float) -> void:
		if world == null or absf(world.bloop.position.x - position.x) > 900:
			return
		clock += dt
		ouch = maxf(0, ouch - dt)
		hop_v += 1400.0 * dt
		hop = minf(0.0, hop + hop_v * dt)
		if hop >= 0:
			hop_v = 0
		var was := near
		near = world.bloop.position.distance_to(position + Vector2(0, -30)) < 190
		if near and not was:
			shown = 0.0
			line += 1
			hop_v = -170.0
		if near:
			var before := int(shown)
			shown += dt * 34.0
			if int(shown) != before and int(shown) % 3 == 0 and int(shown) < text().length():
				world.sound.chirp("blip")
		if near or hop < 0 or ouch > 0 or Engine.get_physics_frames() % 4 == 0:
			queue_redraw()
	func _draw() -> void:
		var h := 58.0 * tall
		var breathe := sin(clock * 2.2) * 2.0
		var body := PackedVector2Array()
		for i in 20:
			var a := i * TAU / 20
			var r := Vector2(27.0 + breathe * 0.5, h * 0.5 - breathe * 0.5)
			var p := Vector2(cos(a) * r.x, sin(a) * r.y)
			if p.y > 0:
				p.x *= 1.0 + p.y / h * 0.35
			body.append(p + Vector2(0, -h * 0.5 + hop))
		Art.blob(self, body, hue, Art.INK, 4.0)
		var face := Vector2(0, -h * 0.62 + hop)
		var awake: bool = near or (world != null and world.awake)
		var dir := 0.0
		if world != null:
			dir = clampf((world.bloop.position.x - position.x) / 120.0, -1, 1) * 3.0
		for x in [-9.0, 9.0]:
			if ouch > 0:
				Art.stroke(self, face + Vector2(x - 4, -3), face + Vector2(x + 4, 3), Art.INK, 2.6)
				Art.stroke(self, face + Vector2(x - 4, 3), face + Vector2(x + 4, -3), Art.INK, 2.6)
			elif awake:
				Art.ellipse(self, face + Vector2(x, 0), Vector2(5.5, 6.5), Art.CREAM, 0.0, 12)
				Art.disc(self, face + Vector2(x + dir, 0.5), 2.8, Art.INK)
			else:
				Art.arc(self, face + Vector2(x, 0), 4.5, 0.2, PI - 0.2, 8, Art.INK, 2.5)
		Art.arc(self, face + Vector2(0, 11), 4.0, 0.2, PI - 0.2, 8, Art.INK, 2.4)
		match hat:
			1:
				var top := Vector2(0, -h + hop)
				Art.line(self, Art.curve(top, top + Vector2(-4, -14), top + Vector2(8 + breathe, -22)), Art.INK, 3.5)
				Art.blob(self, Art.ellipse_points(top + Vector2(12 + breathe, -24), Vector2(8, 5), -0.5, 12), Art.GRASS_LIGHT, Art.INK, 2.5)
			2:
				var top := Vector2(0, -h + 3 + hop)
				Art.blob(self, PackedVector2Array([top + Vector2(-17, 4), top + Vector2(0, -24), top + Vector2(17, 4)]), Art.GOLD, Art.INK, 3.0)
			3:
				for k in 3:
					var top := Vector2(-10 + k * 10, -h + 2 + hop)
					Art.stroke(self, top, top + Vector2((k - 1) * 5, -12 - breathe), Art.INK, 3.0)
		if near and world != null:
			bubble(text())
	func bubble(full: String) -> void:
		var font := ThemeDB.fallback_font
		var size := 19
		var width := 300.0
		var shown_text := full.left(int(shown))
		var box: Vector2 = font.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, width, size)
		var rect := Rect2(Vector2(-box.x * 0.5 - 16, -58.0 * tall - 44 - box.y - 22), box + Vector2(32, 24))
		# Bubbles ignore the dawn tint so the text stays crisp.
		var m := modulate
		var fix := Color(1.0 / m.r, 1.0 / m.g, 1.0 / m.b)
		var pts := Art.rounded_rect(rect, 16)
		Art.blob(self, pts, Art.CREAM * fix, Art.INK, 3.5)
		var tail := PackedVector2Array([Vector2(-10, rect.end.y - 2), Vector2(0, rect.end.y + 16), Vector2(10, rect.end.y - 2)])
		Art.fill(self, tail, Art.CREAM * fix, false)
		Art.line(self, PackedVector2Array([tail[0] + Vector2(0, 2), tail[1], tail[2] + Vector2(0, 2)]), Art.INK, 3.5)
		draw_multiline_string(font, rect.position + Vector2(16, 12 + font.get_ascent(size)), shown_text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, Art.INK)

class Snoozle extends Node2D:
	var awake := false
	var order := 0
	var clock := 0.0
	var hop := 0.0
	var hue := Color("ffe9a8")
	var world: Node
	var perch := Vector2.ZERO
	var drawn_awake := false
	func _ready() -> void:
		perch = position
		z_index = 4
	func _physics_process(dt: float) -> void:
		if world == null:
			return
		clock += dt
		if awake:
			# Follow Bloop's recorded trail, a few steps behind.
			# Hopping is done by moving the node, so the awake snoozle is drawn only once.
			var target: Vector2 = world.trail_point(18 + order * 16)
			perch = perch.lerp(target, 0.16)
			hop = absf(sin(clock * 7.0 + order)) * 7.0 if perch.distance_to(target) > 6 or world.awake else 0.0
			position = perch + Vector2(0, -hop)
			if drawn_awake:
				return
			drawn_awake = true
		elif absf(world.bloop.position.x - position.x) > 950 or Engine.get_physics_frames() % 4 != 0:
			return
		queue_redraw()
	func _draw() -> void:
		if not awake:
			# Asleep on a small cloud.
			for o in [Vector2(-24, 12), Vector2(0, 16), Vector2(24, 12), Vector2(-10, 6), Vector2(12, 6)]:
				Art.disc(self, o + Vector2(0, sin(clock * 1.5) * 2.0), 15, Color(1, 1, 1, 0.92))
			for k in 3:
				var t := fmod(clock * 0.5 + k / 3.0, 1.0)
				Art.text(self, Vector2(14 + t * 26, -22 - t * 40), "z", int(13 + t * 12), Color(1, 1, 1, 1.0 - t))
		var bob := sin(clock * 1.5) * 2.0 if not awake else 0.0
		var c := Vector2(0, -8 + bob)
		Art.blob(self, Art.ellipse_points(c, Vector2(15, 13.5 + (0.0 if awake else sin(clock * 1.5))), 0.0, 18), hue, Art.INK, 3.5)
		Art.blob(self, PackedVector2Array([c + Vector2(-11, -9), c + Vector2(3, -30 + bob * 0.3), c + Vector2(12, -8)]), Art.TEAL, Art.INK, 3.0)
		Art.disc(self, c + Vector2(3, -30 + bob * 0.3), 4.5, Art.CREAM)
		for x in [-5.5, 5.5]:
			if awake:
				Art.disc(self, c + Vector2(x, -1), 2.6, Art.INK)
			else:
				Art.arc(self, c + Vector2(x, -1), 3.2, 0.2, PI - 0.2, 6, Art.INK, 2.2)
		if awake:
			Art.arc(self, c + Vector2(0, 3), 3.5, 0.3, PI - 0.3, 6, Art.INK, 2.0)

class Checkpoint extends Node2D:
	var world: Node
	var lit := false
	var bloom := 0.0
	var clock := 0.0
	func _ready() -> void:
		z_index = 1
	func _physics_process(dt: float) -> void:
		if lit and (bloom < 1.0 or (Engine.get_physics_frames() % 3 == 0 and world != null and absf(world.bloop.position.x - position.x) < 950)):
			clock += dt * (1.0 if bloom < 1.0 else 3.0)
			bloom = minf(1.0, bloom + dt * 2.5)
			queue_redraw()
	func _draw() -> void:
		var sway := sin(clock * 2.0) * 4.0 * bloom
		var top := Vector2(sway, -74)
		Art.line(self, Art.curve(Vector2.ZERO, Vector2(-6, -40), top), Art.INK, 7)
		Art.line(self, Art.curve(Vector2.ZERO, Vector2(-6, -40), top), Art.GRASS, 3.5)
		Art.blob(self, Art.ellipse_points(Vector2(-14, -30), Vector2(13, 6), 0.5, 12), Art.GRASS, Art.INK, 3.0)
		var e := bloom * bloom * (3.0 - 2.0 * bloom)
		for i in 6:
			var a := i * TAU / 6.0 + clock * 0.4
			var petal := top + Vector2.from_angle(a) * (6.0 + 12.0 * e)
			Art.blob(self, Art.ellipse_points(petal, Vector2(6.0 + 7.0 * e, 5.0 + 3.0 * e), a, 12), Art.GOLD.lerp(Art.CREAM, 0.25) if lit else Color("7f8fb5"), Art.INK, 3.0)
		Art.blob(self, Art.ellipse_points(top, Vector2(8, 8), 0.0, 14), Art.ORANGE if lit else Color("56648a"), Art.INK, 3.0)

class Bell extends Node2D:
	var swing := 0.0
	var swing_v := 0.0
	var rung := false
	var clock := 0.0
	var kick_radius := 70.0
	var world: Node
	func _ready() -> void:
		add_to_group("kickable")
		add_to_group("tinted")
	func bell_point() -> Vector2:
		return global_position + Vector2(0, -150)
	func kicked(dir: float, _power: float) -> void:
		ring(dir * 5.0)
	func ring(push: float) -> void:
		swing_v = clampf(swing_v + push, -3.2, 3.2)
		if world != null:
			world.ring_bell()
	func _physics_process(dt: float) -> void:
		clock += dt
		swing_v += (-26.0 * swing - 1.1 * swing_v) * dt
		swing = clampf(swing + swing_v * dt, -0.55, 0.55)
		if world != null and absf(world.bloop.position.x - position.x) < 1100 and (absf(swing) > 0.002 or absf(swing_v) > 0.01 or Engine.get_physics_frames() % 4 == 0):
			queue_redraw()
	func _draw() -> void:
		# Arch.
		var arch := PackedVector2Array()
		for i in 21:
			var a := PI + i * PI / 20.0
			arch.append(Vector2(cos(a) * 130, -250 + sin(a) * 90))
		var frame := PackedVector2Array([Vector2(-130, 6)])
		frame.append_array(arch)
		frame.append(Vector2(130, 6))
		Art.line(self, frame, Art.INK, 30)
		Art.line(self, frame, Color("8f7fb0"), 21)
		for x in [-130.0, 130.0]:
			Art.blob(self, Art.rounded_rect(Rect2(x - 26, -8, 52, 20), 8), Color("7767a0"), Art.INK, 4)
		# Bell hangs from the keystone and swings.
		var pivot := Vector2(0, -338)
		draw_set_transform(pivot, swing, Vector2.ONE)
		Art.stroke(self, Vector2.ZERO, Vector2(0, 120), Art.INK, 7)
		var body := PackedVector2Array([Vector2(-22, 122), Vector2(-34, 150), Vector2(-40, 196), Vector2(-64, 232), Vector2(64, 232), Vector2(40, 196), Vector2(34, 150), Vector2(22, 122)])
		Art.blob(self, body, Art.GOLD, Art.INK, 5.0)
		Art.stroke(self, Vector2(-52, 214), Vector2(52, 214), Color("f0a93c"), 6)
		Art.blob(self, Art.ellipse_points(Vector2(0, 246), Vector2(15, 15), 0.0, 16), Color("f0a93c"), Art.INK, 4.0)
		for x in [-14.0, 14.0]:
			if rung:
				Art.ellipse(self, Vector2(x, 170), Vector2(6, 7.5), Art.CREAM, 0.0, 12)
				Art.disc(self, Vector2(x, 171), 3.2, Art.INK)
			else:
				Art.arc(self, Vector2(x, 168), 6, 0.2, PI - 0.2, 8, Art.INK, 3.2)
		if rung:
			Art.arc(self, Vector2(0, 186), 9, 0.2, PI - 0.2, 10, Art.INK, 3.2)
		else:
			Art.stroke(self, Vector2(-5, 190), Vector2(5, 190), Art.INK, 3.2)
		draw_set_transform(Vector2.ZERO)
		if not rung:
			for k in 3:
				var t := fmod(clock * 0.45 + k / 3.0, 1.0)
				Art.text(self, Vector2(60 + t * 40, -200 - t * 70), "Z", int(18 + t * 18), Color(1, 1, 1, 1.0 - t))

class Sign extends Node2D:
	var icons: Array = []
	var caption := ""
	func _ready() -> void:
		add_to_group("tinted")
	func _draw() -> void:
		var w := 44.0 + icons.size() * 52.0
		if caption != "":
			w = maxf(w, ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36)
		var h := 74.0 if caption == "" else 96.0
		Art.stroke(self, Vector2(0, 0), Vector2(0, -60), Art.INK, 12)
		Art.stroke(self, Vector2(0, 0), Vector2(0, -60), Color("a9794f"), 6)
		var rect := Rect2(-w * 0.5, -58 - h, w, h)
		Art.blob(self, Art.rounded_rect(rect, 13), Color("e8c48f"), Art.INK, 4.0)
		for i in icons.size():
			var c := Vector2(rect.position.x + 48 + i * 52 - 4, rect.position.y + 38)
			if icons[i] == "+":
				Art.text(self, c + Vector2(0, 9), "+", 26, Art.INK, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				Art.icon(self, icons[i], c, 1.15, Art.INK)
		if caption != "":
			Art.text(self, Vector2(0, rect.end.y - 13), caption, 17, Art.INK, HORIZONTAL_ALIGNMENT_CENTER)

class Pond extends Node2D:
	var area := Rect2()
	var clock := 0.0
	var world: Node
	func _ready() -> void:
		z_index = 8
	func _physics_process(dt: float) -> void:
		if world != null and absf(world.bloop.position.x - area.get_center().x) < 1400:
			clock += dt
			queue_redraw()
	func _draw() -> void:
		var top := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var x := area.position.x + area.size.x * i / n
			top.append(Vector2(x, area.position.y + sin(clock * 2.2 + x * 0.03) * 5.0))
		var water := Color(0.2, 0.62, 0.78, 0.78)
		var deep := Color(0.13, 0.42, 0.68, 0.9)
		for i in n:
			var a := top[i]
			var b := top[i + 1]
			Art.quad(self, a, b, b + Vector2(0, 60), a + Vector2(0, 60), water, deep)
			Art.quad(self, a + Vector2(0, 60), b + Vector2(0, 60), Vector2(b.x, area.end.y), Vector2(a.x, area.end.y), deep, deep)
		Art.line(self, top, Color(0.85, 0.98, 1.0, 0.95), 5)
