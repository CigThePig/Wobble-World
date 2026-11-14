extends CharacterBody2D
signal event(kind: String)
var tuning = preload("res://game/tuning.tres").duplicate()
var controls: Node
var rolling := false
var coyote := 0.0
var buffer := 0.0
var spin := 0.0
var phase := 0.0
var squash := 0.0
var spring_lock := 0.0
var jumps := 0
var bounces := 0
var pushes := 0
var debug_draw := false

func _ready() -> void:
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 27.0
	add_child(shape)
	floor_snap_length = 10.0
	floor_max_angle = deg_to_rad(62)
	floor_stop_on_slope = true

func reset_at(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	rolling = false
	coyote = 0.0
	buffer = 0.0
	spring_lock = 0.0
	squash = 0.0

func _physics_process(dt: float) -> void:
	if controls == null or controls.paused:
		return
	phase += dt * (5.0 + absf(velocity.x) * 0.06)
	spring_lock = maxf(0, spring_lock - dt)
	squash = move_toward(squash, 0.0, dt * 3.5)
	if controls.take_roll():
		rolling = not rolling
		squash = 0.18
		event.emit("roll" if rolling else "walk")
	if is_on_floor():
		coyote = tuning.coyote_time
	else:
		coyote = maxf(0, coyote - dt)
	buffer = maxf(0, buffer - dt)
	if controls.take_jump():
		buffer = tuning.jump_buffer
	if buffer > 0 and coyote > 0:
		velocity.y = -tuning.jump_impulse
		coyote = 0
		buffer = 0
		jumps += 1
		squash = -0.22
		event.emit("jump")
	if not controls.jump_held and velocity.y < -tuning.jump_impulse * tuning.jump_cut and spring_lock <= 0:
		velocity.y = -tuning.jump_impulse * tuning.jump_cut
	var axis: float = controls.axis()
	if rolling:
		velocity.x += axis * tuning.roll_acceleration * dt
		if is_on_floor():
			velocity.x += get_floor_normal().x * tuning.slope_gravity * dt
			velocity.x *= maxf(0.0, 1.0 - tuning.roll_drag * dt)
	else:
		var accel: float = tuning.walk_acceleration if is_on_floor() else tuning.air_control
		if is_zero_approx(axis) and is_on_floor():
			accel = tuning.walk_brake
		velocity.x = move_toward(velocity.x, axis * tuning.walk_speed, accel * dt)
	velocity.x = clampf(velocity.x, -tuning.max_speed, tuning.max_speed)
	velocity.y += tuning.gravity * dt
	var incoming := velocity
	var was_grounded := is_on_floor()
	floor_stop_on_slope = not rolling
	move_and_slide()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider()
		if body is RigidBody2D:
			var load_y: float = tuning.gravity * dt * 1.1 if hit.get_normal().y < -0.5 else 0.0
			var push_x: float = axis * tuning.push_force * dt if absf(hit.get_normal().x) > 0.5 else incoming.x * 0.03
			body.apply_impulse(Vector2(push_x, load_y), hit.get_position() - body.global_position)
			if absf(incoming.x) > 80:
				pushes += 1
		if rolling and absf(hit.get_normal().x) > 0.8 and absf(incoming.x) > 180:
			velocity.x = -incoming.x * tuning.bounce
			squash = 0.26
			event.emit("bump")
	if is_on_floor() and not was_grounded and incoming.y > 120:
		squash = clampf(incoming.y / 1600.0, 0.1, 0.32)
		event.emit("land")
		if rolling and incoming.y > 490 and spring_lock <= 0:
			velocity.y = -incoming.y * tuning.bounce
	spin += velocity.x * dt / 27.0
	if position.y > 1050 or position.x < -150 or position.x > 3700:
		reset_at(Vector2(180, 430))
	queue_redraw()

func launch() -> void:
	if spring_lock > 0:
		return
	velocity.y = -890.0
	spring_lock = 0.65
	bounces += 1
	squash = -0.25
	event.emit("spring")

func _draw() -> void:
	var ink := Color("285855")
	if not rolling:
		for side in [-1, 1]:
			var stride := sin(phase + side * PI * 0.5) * minf(absf(velocity.x) / 30.0, 9.0)
			draw_polyline(PackedVector2Array([Vector2(side * 12, 12), Vector2(side * 15 + stride, 25), Vector2(side * 19 + stride, 28)]), ink, 5, true)
	var s := Vector2(1.0 + squash, 1.0 - squash)
	draw_set_transform(Vector2(0,0 if rolling else -12), 0, s)
	draw_circle(Vector2(2, 3), 28, Color("d97844"))
	draw_circle(Vector2.ZERO, 27, Color("ff9950"))
	draw_circle(Vector2(-10,-14), 9, Color("ffb865"))
	if rolling:
		draw_arc(Vector2.ZERO, 21, spin, spin + 2.1, 18, Color("e98442"), 3, true)
	for x in [-10, 10]:
		paint_ellipse(Vector2(x,-5), Vector2(7.5, 10.0), Color("fff9dc"))
		draw_circle(Vector2(x + clampf(velocity.x / 180, -2.5, 2.5), -4 + clampf(velocity.y / 250, -2, 3)), 3.5, ink)
	draw_arc(Vector2(1, 7), 6, 0.15, PI - 0.15, 12, ink, 2.4, true)
	draw_circle(Vector2(-18,5), 4, Color("ed7b53"))
	draw_circle(Vector2(18,5), 4, Color("ed7b53"))
	draw_set_transform(Vector2.ZERO)
	if debug_draw:
		draw_arc(Vector2.ZERO, 27, 0, TAU, 40, Color.MAGENTA, 1.5)
		draw_line(Vector2.ZERO, velocity * 0.12, Color.MAGENTA, 2)

func paint_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		points.append(center + Vector2(cos(i * TAU / 32), sin(i * TAU / 32)) * radius)
	draw_colored_polygon(points, color)
