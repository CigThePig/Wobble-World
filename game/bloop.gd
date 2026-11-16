extends CharacterBody2D
# Bloop: a jelly blob with two modes.
#   Legs - precise CharacterBody2D platforming with a kick.
#   Ball - a custom momentum integrator (gravity is never cancelled, so slopes,
#          ramps and bounces behave like a real ball) with a boost and a pound.
signal event(kind: String)
const Art = preload("res://game/art.gd")
const R := 27.0
const VR := 25.5
const N := 28
const KICK_TIME := 0.32
# Presentation only: the body rides above the collision circle on two legs.
const LEG_LIFT := 40.0      # how far the body rises above the collision centre
const LEG_LENGTH := 49.0    # hip to ankle; a shorter reach bends the leg instead of shrinking it
const LEG_HIP := Vector2(9.5, 17.0)
const ANKLE := 4.0          # ankle height above the ground
const STRIDE := 42.0

var tuning = preload("res://game/tuning.tres").duplicate()
var controls: Node
var world: Node
var rolling := false
var grounded := false
var ground_normal := Vector2.UP
var facing := 1.0
var coyote := 0.0
var buffer := 0.0
var spring_lock := 0.0
var jump_cut_ok := false
var pounding := false
var boost_cd := 0.0
var kick_t := 0.0
var kick_hit := true
var frozen := false
var last_impact := 0.0
var jumps := 0
var bounces := 0
var pushes := 0
var kicks := 0
var pounds := 0
var boosts := 0
var debug_draw := false

# Presentation state.
var clock := 0.0
var spin := 0.0
var face_angle := 0.0
var legs := 1.0
var squash := 0.0
var squash_v := 0.0
var squash_axis := Vector2.UP
var jig := PackedFloat32Array()
var jig_v := PackedFloat32Array()
var feet := [Vector2(-11.5, R - ANKLE), Vector2(11.5, R - ANKLE)]  # ankles, relative to the collision centre
var gait := 0.0        # 0 standing, 1 walking at full speed
var step_phase := 0.0  # walk cycle, advanced by distance covered so planted feet don't slide
var dip := 0.0
var tip := Vector2(0, -60)
var tip_v := Vector2.ZERO
var blink := 0.0
var next_blink := 2.0
var look := Vector2.ZERO
var joy := 0.0

func _ready() -> void:
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = R
	add_child(shape)
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(62)
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	platform_floor_layers = 0
	platform_wall_layers = 0
	jig.resize(N)
	jig_v.resize(N)
	z_index = 5

func reset_at(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	rolling = false
	grounded = false
	pounding = false
	coyote = 0.0
	buffer = 0.0
	spring_lock = 0.0
	kick_t = 0.0
	boost_cd = 0.0
	squash = 0.0
	squash_v = 0.0
	legs = 1.0
	face_angle = 0.0
	spin = 0.0
	feet = [Vector2(-11.5, R - ANKLE), Vector2(11.5, R - ANKLE)]
	gait = 0.0
	step_phase = 0.0
	dip = 0.0
	# Keep the sprout above the taller standing body after spawn/respawn.
	tip = body_center() + Vector2(0, -VR - 16.0)
	tip_v = Vector2.ZERO
	reset_physics_interpolation()

func set_rolling(value: bool) -> void:
	if rolling == value:
		return
	rolling = value
	pounding = false
	kick_t = 0.0
	squash_v += 3.5 if value else -3.5
	if value:
		spin = face_angle
	event.emit("roll" if rolling else "walk")

func _physics_process(dt: float) -> void:
	if controls == null or controls.paused:
		return
	clock += dt
	if not frozen:
		simulate(dt)
	animate(dt)
	queue_redraw()

func simulate(dt: float) -> void:
	spring_lock = maxf(0, spring_lock - dt)
	boost_cd = maxf(0, boost_cd - dt)
	buffer = maxf(0, buffer - dt)
	if controls.take_roll():
		set_rolling(not rolling)
	if controls.take_jump():
		buffer = tuning.jump_buffer
	coyote = tuning.coyote_time if grounded else maxf(0, coyote - dt)
	var axis: float = controls.axis()
	if absf(axis) > 0.1:
		facing = signf(axis)
	if controls.take_action():
		act(axis)
	if buffer > 0 and coyote > 0:
		jump()
	if jump_cut_ok:
		if velocity.y >= 0:
			jump_cut_ok = false
		elif not controls.jump_held and spring_lock <= 0:
			var limit: float = -tuning.jump_impulse * tuning.jump_cut
			if velocity.y < limit:
				velocity.y = limit
			jump_cut_ok = false
	if kick_t > 0:
		kick_t = maxf(0, kick_t - dt)
		if not kick_hit and kick_t < KICK_TIME - 0.08:
			kick_hit = true
			if world != null:
				world.kick_at(global_position + Vector2(facing * 40, 6), facing)
	if rolling:
		roll_step(dt, axis)
	else:
		walk_step(dt, axis)
	spin += velocity.x * dt / R

func jump() -> void:
	if rolling:
		var dir := (ground_normal * 0.55 + Vector2.UP * 0.45).normalized() if grounded else Vector2.UP
		var into := velocity.dot(dir)
		if into < 0:
			velocity -= dir * into
		velocity += dir * tuning.roll_jump
	else:
		velocity.y = -tuning.jump_impulse
	coyote = 0
	buffer = 0
	grounded = false
	jump_cut_ok = true
	jumps += 1
	squash_v -= 4.0
	event.emit("jump")

func act(axis: float) -> void:
	if rolling:
		if grounded:
			if boost_cd <= 0:
				var t := Vector2(-ground_normal.y, ground_normal.x)
				velocity += t * facing * tuning.boost
				boost_cd = 0.8
				boosts += 1
				squash_v += 3.0
				event.emit("boost")
		elif not pounding:
			pounding = true
			jump_cut_ok = false
			velocity = Vector2(velocity.x * 0.25, tuning.pound_speed)
			pounds += 1
			event.emit("dive")
	elif kick_t <= 0:
		kick_t = KICK_TIME
		kick_hit = false
		kicks += 1
		event.emit("kick")

func walk_step(dt: float, axis: float) -> void:
	var accel: float = tuning.walk_acceleration if grounded else tuning.air_control
	if grounded and (is_zero_approx(axis) or absf(velocity.x) > tuning.walk_speed + 20):
		accel = tuning.walk_brake
	if grounded or not is_zero_approx(axis) or absf(velocity.x) <= tuning.walk_speed:
		velocity.x = move_toward(velocity.x, axis * tuning.walk_speed, accel * dt)
	velocity.y = minf(velocity.y + tuning.gravity * dt, 1500.0)
	var incoming := velocity
	var was_grounded := grounded
	floor_snap_length = 12.0 if velocity.y >= 0 else 0.0
	move_and_slide()
	grounded = is_on_floor()
	if grounded:
		ground_normal = get_floor_normal()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider()
		if body is RigidBody2D:
			var normal := hit.get_normal()
			var load_y: float = tuning.gravity * dt * tuning.mass * 0.7 if normal.y < -0.5 else 0.0
			var push_x: float = axis * tuning.push_force * dt if absf(normal.x) > 0.5 else incoming.x * 0.02
			body.apply_impulse(Vector2(push_x, load_y), hit.get_position() - body.global_position)
			if absf(normal.x) > 0.5 and absf(incoming.x) > 80:
				pushes += 1
	if grounded and not was_grounded and incoming.y > 140:
		landed(incoming.y)

func roll_step(dt: float, axis: float) -> void:
	if grounded:
		var t := Vector2(-ground_normal.y, ground_normal.x)
		var along := velocity.dot(t)
		var power: float = tuning.roll_brake if along * axis < 0 else tuning.roll_acceleration
		velocity += t * axis * power * dt
		velocity -= velocity * tuning.roll_drag * dt
	elif not pounding:
		velocity.x += axis * tuning.roll_air * dt
	velocity.y += tuning.gravity * dt
	if not pounding:
		velocity = velocity.limit_length(tuning.max_speed)
	var motion := velocity * dt
	var touching := false
	for i in 4:
		var hit := move_and_collide(motion)
		if hit == null:
			break
		var normal := hit.get_normal()
		var body := hit.get_collider()
		if normal.y < -0.35:
			touching = true
			ground_normal = normal
		if body is RigidBody2D:
			var off: Vector2 = hit.get_position() - body.global_position
			var other: Vector2 = body.linear_velocity + Vector2(-body.angular_velocity * off.y, body.angular_velocity * off.x)
			var rel := (velocity - other).dot(normal)
			if rel < 0:
				var j: float = -1.25 * rel / (1.0 / tuning.mass + 1.0 / body.mass)
				velocity += normal * j / tuning.mass
				body.apply_impulse(-normal * j, off)
				if rel < -150:
					pushes += 1
					impact(-rel * 0.6, normal)
		else:
			var into := velocity.dot(normal)
			if into < 0:
				var speed := -into
				if pounding and normal.y < -0.5:
					pounding = false
					velocity -= normal * into
					velocity = velocity * 0.5 + normal * tuning.pound_bounce
					spring_lock = 0.12
					squash_v += 6.0
					last_impact = speed
					event.emit("pound")
					if world != null:
						world.pound_at(global_position + Vector2(0, R))
				else:
					var e: float = 0.0
					if speed > tuning.bounce_min and spring_lock <= 0:
						e = tuning.bounce * (0.75 + 0.35 * absf(normal.x))
					velocity -= normal * into * (1.0 + e)
					if speed > 170:
						impact(speed, normal)
		motion = hit.get_remainder().slide(normal)
		if motion.length_squared() < 0.0001:
			break
	if not touching and velocity.y > -60:
		var probe := KinematicCollision2D.new()
		if test_move(global_transform, Vector2(0, 3), probe) and probe.get_normal().y < -0.35:
			touching = true
			ground_normal = probe.get_normal()
	grounded = touching

func impact(speed: float, normal: Vector2) -> void:
	last_impact = speed
	squash_axis = normal
	squash_v += clampf(speed / 150.0, 0.0, 6.0)
	wobble(-normal, clampf(speed / 400.0, 0.2, 2.0))
	event.emit("land" if normal.y < -0.6 else "bump")

func landed(speed: float) -> void:
	last_impact = speed
	squash_axis = Vector2.UP
	squash_v += clampf(speed / 170.0, 0.0, 5.5)
	wobble(Vector2.DOWN, clampf(speed / 500.0, 0.2, 1.6))
	event.emit("land")

func launch(up: Vector2, power: float) -> bool:
	if spring_lock > 0:
		return false
	var p := power
	if pounding:
		p *= 1.45
		pounding = false
	elif controls.jump_held:
		p *= 1.2
	var t := Vector2(-up.y, up.x)
	velocity = t * velocity.dot(t) * 0.8 + up * p
	spring_lock = 0.3
	jump_cut_ok = false
	grounded = false
	coyote = 0
	bounces += 1
	squash_v -= 6.0
	squash_axis = up
	event.emit("spring")
	return true

func wobble(direction: Vector2, amount: float) -> void:
	for i in N:
		var u := Vector2.from_angle(i * TAU / N)
		var d := u.dot(direction)
		jig_v[i] += amount * (absf(d) * 0.9 - 0.55 - maxf(0.0, d) * 1.2)

func animate(dt: float) -> void:
	var speed := velocity.length()
	legs = move_toward(legs, 0.0 if rolling else 1.0, dt * 7.0)
	# Squash spring: compress along the contact normal, stretch along flight.
	var target := 0.0
	var axis_target := squash_axis
	if grounded:
		axis_target = ground_normal
		target = 0.07 * (1.0 - legs)
	elif speed > 200:
		axis_target = velocity / speed
		target = -clampf(speed / 3200.0, 0.0, 0.18)
	if pounding:
		target = -0.28
	if axis_target.dot(squash_axis) < 0:
		axis_target = -axis_target
	squash_axis = squash_axis.lerp(axis_target, 0.3).normalized()
	squash_v += (-300.0 * (squash - target) - 13.0 * squash_v) * dt
	squash = clampf(squash + squash_v * dt, -0.36, 0.46)
	# Rim jiggle: a damped wave around the outline.
	for i in N:
		var left := jig[(i + N - 1) % N]
		var right := jig[(i + 1) % N]
		jig_v[i] += (-420.0 * jig[i] + 900.0 * (left + right - 2.0 * jig[i]) - 9.0 * jig_v[i]) * dt
	for i in N:
		jig[i] = clampf(jig[i] + jig_v[i] * dt, -0.3, 0.3)
	# Face follows the roll, then eases upright on legs.
	if rolling:
		face_angle = spin
	else:
		face_angle = lerp_angle(face_angle, clampf(velocity.x * 0.0004, -0.2, 0.2), 0.25)
	var look_target := Vector2(clampf(velocity.x / 160.0, -3.0, 3.0), clampf(velocity.y / 220.0, -2.5, 3.0))
	if speed < 30:
		look_target = Vector2(facing * 1.6, 0)
	look = look.lerp(look_target, 0.2)
	joy = move_toward(joy, 1.0 if (rolling and speed > 420) or spring_lock > 0 else 0.0, dt * 4.0)
	next_blink -= dt
	if next_blink <= 0:
		next_blink = randf_range(1.6, 4.5)
		blink = 0.16
	blink = maxf(0, blink - dt)
	animate_feet(dt)
	# Sprout: a springy stalk that lags behind motion.
	var up := Vector2.UP.rotated(face_angle)
	var base := body_center() + up * (VR - 3)
	var want := base + up * 19 - (velocity * 0.014).limit_length(13)
	tip_v += ((want - tip) * 230.0 - tip_v * 9.0) * dt
	tip += tip_v * dt
	if tip.distance_to(base) > 34:
		tip = base + (tip - base).limit_length(34)

func animate_feet(dt: float) -> void:
	var n := ground_normal if grounded else Vector2.UP
	var t := Vector2(-n.y, n.x)
	var along := velocity.dot(t)
	var walking := grounded and not rolling
	gait = move_toward(gait, clampf(absf(along) / 220.0, 0.0, 1.0) if walking else 0.0, dt * 6.0)
	if walking:
		step_phase = fposmod(step_phase + along * dt / (2.0 * STRIDE), 1.0)
	# Knees give on a landing and spring back.
	dip = lerpf(dip, clampf(squash, 0.0, 0.4) * 34.0 if walking else 0.0, 0.5)
	var hip_y := body_center().y + LEG_HIP.y
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var target: Vector2
		if walking:
			# Half the cycle planted and carried back under the body, half swinging forward.
			var p := fposmod(step_phase + i * 0.5, 1.0)
			var reach: float
			var lift := 0.0
			if p < 0.5:
				reach = 0.5 - p * 2.0
			else:
				var u := smoothstep(0.0, 1.0, (p - 0.5) * 2.0)
				reach = u - 0.5
				lift = sin(PI * u) * 14.0
			var x := lerpf(side * 11.5, reach * STRIDE + side * 4.0, gait)
			target = -n * R + t * x + n * (ANKLE + lift * gait)
		else:
			# Airborne: stretched on the way up, tucked over the top, spread to brace on the way down.
			var rise := clampf(-velocity.y / 450.0, 0.0, 1.0)
			var drop := clampf(velocity.y / 600.0, 0.0, 1.0)
			var length := LEG_LENGTH * (0.74 + 0.26 * rise + 0.14 * drop)
			var spread := side * (6.0 + 6.0 * drop) - clampf(velocity.x * 0.035, -11.0, 11.0) + side * sin(clock * 9.0 + i * 2.0) * 1.5
			target = Vector2(side * LEG_HIP.x + spread, hip_y + sqrt(maxf(1.0, length * length - spread * spread)))
		feet[i] = feet[i].lerp(target, 0.55 if walking else 0.3)

func body_center() -> Vector2:
	# Rises a touch as each foot swings through, and sinks when the knees take a landing.
	var bob := -cos(step_phase * 2.0 * TAU) * 1.8 * gait + sin(clock * 2.4) * 0.8 * (1.0 - gait)
	return Vector2(0, (-LEG_LIFT + bob + dip) * legs)

func draw_leg(hip: Vector2, ankle: Vector2, bend: float, fill: Color, toe: Vector2, up: Vector2, limit := 1.06) -> void:
	# A soft two-bone leg: the further the ankle is from full reach, the deeper the knee bends.
	var length := LEG_LENGTH * legs
	var v := (ankle - hip).limit_length(length * limit)
	var d := maxf(v.length(), 0.001)
	var foot := hip + v
	var knee := sqrt(maxf(0.0, length * length - d * d)) * 0.5
	var side := Vector2(v.y, -v.x) / d
	var shape := Art.curve(hip, hip + v * 0.5 + side * knee * bend * 1.7, foot, 8)
	Art.line(self, shape, Art.INK, 9.0 * legs)
	Art.line(self, shape, fill, 4.8 * legs)
	# Boot: flat sole, rounded toe.
	var k := legs
	var boot := PackedVector2Array()
	for q in [Vector2(-6.5, 4.5), Vector2(-7.0, -1.5), Vector2(-4.5, -5.0), Vector2(1.5, -5.0), Vector2(6.0, -3.5), Vector2(10.5, 0.0), Vector2(11.0, 3.0), Vector2(9.5, 4.5)]:
		boot.append(foot + (toe * q.x - up * q.y) * k)
	Art.blob(self, boot, Art.TEAL, Art.INK, 3.2 * k)
	Art.ellipse(self, foot + (toe * 4.5 + up * 1.2) * k, Vector2(3.4, 1.7) * k, Art.TEAL.lightened(0.4), toe.angle(), 8)

func outline_points(c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(N)
	var a := squash_axis
	var b := Vector2(-a.y, a.x)
	var contact := grounded and legs < 0.5
	var centre := c
	if contact:
		centre -= ground_normal * VR * squash * 0.9
	for i in N:
		var u := Vector2.from_angle(i * TAU / N)
		var r := VR * (1.0 + jig[i])
		var p := centre + a * u.dot(a) * r * (1.0 - squash) + b * u.dot(b) * r * (1.0 + squash * 0.85)
		if contact:
			var depth := -p.dot(ground_normal) - (R - 1.0)
			if depth > 0:
				p += ground_normal * depth
		pts[i] = p
	return pts

func _draw() -> void:
	var ink := Art.INK
	var c := body_center()
	var up := Vector2.UP.rotated(face_angle)
	# Sprout behind the body.
	var base := c + up * (VR - 3)
	Art.line(self, Art.curve(base, base + up * 12, tip, 6), ink, 4.0)
	var dir := (tip - base).normalized()
	for side in [-1.0, 1.0]:
		var leaf_dir := dir.rotated(side * 0.75)
		var leaf := Art.ellipse_points(tip + leaf_dir * 8.0, Vector2(10.0, 5.0) * (1.0 if side > 0 else 0.8), leaf_dir.angle(), 12)
		Art.blob(self, leaf, Art.GRASS_LIGHT if side > 0 else Art.GRASS, ink, 2.6)
	# Legs, behind the body: the far one first and a shade darker.
	if legs > 0.03:
		var n := ground_normal if grounded else Vector2.UP
		var tangent := Vector2(-n.y, n.x)
		for pass_i in 2:
			var side := -facing if pass_i == 0 else facing
			var i := 0 if side < 0 else 1
			var hip := c + Vector2(side * LEG_HIP.x, LEG_HIP.y) * legs
			var ankle: Vector2 = hip.lerp(feet[i], legs)
			# Standing, the knees bow gently outward; walking, they bend the way Bloop is heading.
			var bend := lerpf(side * 0.6, facing, maxf(gait, 0.0 if grounded else 1.0))
			var toe := tangent * (facing if gait > 0.12 or not grounded else side)
			var foot_up := n
			var limit := 1.06
			if kick_t > 0 and side == facing:
				# Wind back, snap through, hold, and settle.
				var p := 1.0 - kick_t / KICK_TIME
				var swing: float
				if p < 0.18:
					swing = lerpf(0.0, -0.75, smoothstep(0.0, 0.18, p))
				elif p < 0.42:
					swing = lerpf(-0.75, 1.5, smoothstep(0.18, 0.42, p))
				else:
					swing = lerpf(1.5, 0.0, smoothstep(0.6, 1.0, p))
				var out := Vector2(sin(swing) * facing, cos(swing))
				var kick := hip + out * LEG_LENGTH * (1.0 + 0.16 * smoothstep(0.3, 1.5, swing))
				var blend := smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.85, 1.0, p))
				ankle = ankle.lerp(kick, blend)
				toe = toe.lerp(Vector2(out.y, -out.x) * facing, blend).normalized()
				foot_up = Vector2(toe.y, -toe.x) * facing
				bend = facing * (1.0 - blend * 0.7)
				limit = 1.2
			draw_leg(hip, ankle, bend, Art.ORANGE_DARK if pass_i == 0 else Art.ORANGE, toe, foot_up, limit)
	# Jelly body.
	var pts := outline_points(c)
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= N
	Art.blob(self, pts, Art.ORANGE_DARK, ink, 4.5)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(mid + (p - mid) * 0.86 + Vector2(-2.5, -3.5))
	Art.fill(self, inner, Art.ORANGE, false)
	Art.ellipse(self, mid + Vector2(-10, -13), Vector2(7.5, 4.5), Art.ORANGE_LIGHT, -0.6, 12)
	# Freckles make the spin readable.
	for k in 3:
		var spot := Vector2.from_angle(face_angle + 2.2 + k * 0.42) * (VR - 8.0 - k % 2 * 4.0)
		Art.disc(self, mid + spot, 2.6, Art.ORANGE_DARK)
	# Face.
	draw_set_transform(mid, face_angle, Vector2.ONE)
	var gaze := look.rotated(-face_angle)
	var lid := 1.0 - smoothstep(0.0, 0.08, blink) * 0.9
	if pounding:
		lid = 0.35
	for x in [-9.5, 9.5]:
		Art.ellipse(self, Vector2(x, -5), Vector2(7.6, 9.6 * lid), Art.CREAM, 0.0, 16)
		if lid > 0.5:
			Art.disc(self, Vector2(x, -4.5) + gaze, 3.9, ink)
			Art.disc(self, Vector2(x - 1.2, -6.0) + gaze, 1.3, Art.CREAM)
	Art.disc(self, Vector2(-18, 5), 4.2, Color(0.93, 0.36, 0.38, 0.55))
	Art.disc(self, Vector2(18, 5), 4.2, Color(0.93, 0.36, 0.38, 0.55))
	if pounding:
		Art.stroke(self, Vector2(-6, 9), Vector2(6, 9), ink, 3.0)
	elif joy > 0.4:
		var grin := PackedVector2Array()
		for i in 9:
			var a := i * PI / 8.0
			grin.append(Vector2(cos(a) * 8.0, 5.0 + sin(a) * 8.0 * joy))
		Art.fill(self, grin, ink)
		Art.disc(self, Vector2(0, 10.5), 3.0, Art.PINK)
	elif not grounded and absf(velocity.y) > 260:
		Art.ellipse(self, Vector2(0, 8), Vector2(3.6, 4.6), ink, 0.0, 12)
	else:
		Art.arc(self, Vector2(0, 5), 6.5, 0.2, PI - 0.2, 7, ink, 2.8)
	draw_set_transform(Vector2.ZERO)
	if debug_draw:
		draw_arc(Vector2.ZERO, R, 0, TAU, 40, Color.MAGENTA, 1.5)
		Art.stroke(self, Vector2.ZERO, velocity * 0.12, Color.MAGENTA, 2)
		Art.stroke(self, Vector2.ZERO, ground_normal * 40, Color.CYAN if grounded else Color.GRAY, 2)
