extends Node2D
const Bloop = preload("res://game/bloop.gd")
const Controls = preload("res://game/controls.gd")
const Toy = preload("res://game/toy.gd")
var bloop: CharacterBody2D
var controls: Control
var camera: Camera2D
var sound: Node
var box: RigidBody2D
var seesaw: RigidBody2D
var spring: Area2D
var rescue_spring: Area2D
var bell: Area2D
var bell_rings := 0
var bell_flash := 0.0
var bell_cooldown := 0.0
var clock := 0.0
var source := "working-tree"
var replay: Node
var terrain: Array[PackedVector2Array] = []
var decorations := RandomNumberGenerator.new()

func _ready() -> void:
	if FileAccess.file_exists("res://game/build-source.txt"):
		source = FileAccess.get_file_as_string("res://game/build-source.txt").strip_edges()
	terrain = [PackedVector2Array([Vector2(-300,540),Vector2(570,540),Vector2(850,420),Vector2(1030,420),Vector2(1390,640),Vector2(1650,640),Vector2(1900,520),Vector2(2120,520),Vector2(2120,850),Vector2(-300,850)]), PackedVector2Array([Vector2(2250,520),Vector2(2600,520),Vector2(2820,450),Vector2(3600,450),Vector2(3600,850),Vector2(2250,850)]),PackedVector2Array([Vector2(2100,760),Vector2(2270,760),Vector2(2270,850),Vector2(2100,850)])]
	for points in terrain:
		var body := StaticBody2D.new()
		var shape := CollisionPolygon2D.new()
		shape.polygon = points
		body.add_child(shape)
		add_child(body)
	# Soft walls keep the playground finite.
	for x in [-270, 3540]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(40,1300)
		wall.position = Vector2(x,300)
		wall.add_child(shape)
		add_child(wall)
	bloop = Bloop.new()
	add_child(bloop)
	bloop.reset_at(Vector2(180,480))
	var layer := CanvasLayer.new()
	add_child(layer)
	controls = Controls.new()
	layer.add_child(controls)
	bloop.controls = controls
	controls.command.connect(on_command)
	sound = preload("res://game/sound.gd").new()
	add_child(sound)
	bloop.event.connect(sound.chirp)
	bloop.event.connect(func(kind): print("WOBBLE_EVENT ", kind))
	camera = Camera2D.new()
	camera.position = Vector2(640,350)
	add_child(camera)
	spring = area(Vector2(1510,623), Vector2(125,30))
	rescue_spring = area(Vector2(2185,743), Vector2(128,30))
	bell = area(Vector2(3130,310), Vector2(84,90))
	reset_toys()
	print("WOBBLE_READY source=", source)
	if OS.get_name() == "Android":
		print_layout.call_deferred()
	if "--layout-check" in OS.get_cmdline_user_args():
		layout_check.call_deferred()
	if "--replay" in OS.get_cmdline_user_args():
		replay = preload("res://game/replay.gd").new()
		replay.world = self
		add_child(replay)

func area(at: Vector2, dimensions: Vector2) -> Area2D:
	var node := Area2D.new()
	node.position = at
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = dimensions
	node.add_child(shape)
	add_child(node)
	return node

func reset_toys() -> void:
	if is_instance_valid(box):
		box.queue_free()
	if is_instance_valid(seesaw):
		seesaw.queue_free()
	if has_node("Fulcrum"):
		get_node("Fulcrum").free()
	box = Toy.new()
	box.position = Vector2(1960,480)
	add_child(box)
	seesaw = Toy.new()
	seesaw.kind = "seesaw"
	seesaw.position = Vector2(2480,480)
	add_child(seesaw)
	var pivot := StaticBody2D.new()
	pivot.name = "Fulcrum"
	pivot.position = seesaw.position
	add_child(pivot)
	var pin := PinJoint2D.new()
	pivot.add_child(pin)
	pin.node_a = pivot.get_path()
	pin.node_b = seesaw.get_path()
	pin.angular_limit_enabled = true
	pin.angular_limit_lower = -0.26
	pin.angular_limit_upper = 0.26
	box.freeze = controls.paused
	seesaw.freeze = controls.paused

func on_command(action: String) -> void:
	match action:
		"reset_bloop": bloop.reset_at(Vector2(180,480))
		"reset_all":
			bloop.reset_at(Vector2(180,480))
			reset_toys()
			bell_rings = 0
			controls.status = "Ring the sleepy bell. Anything with a good bonk will do!"
		"reset_experiment": reset_toys()
		"debug": bloop.debug_draw = not bloop.debug_draw
		"speed_down": bloop.tuning.walk_speed = maxf(100, bloop.tuning.walk_speed - 30)
		"speed_up": bloop.tuning.walk_speed = minf(500, bloop.tuning.walk_speed + 30)
		"jump_down": bloop.tuning.jump_impulse = maxf(300, bloop.tuning.jump_impulse - 30)
		"jump_up": bloop.tuning.jump_impulse = minf(800, bloop.tuning.jump_impulse + 30)
		"pause", "resume":
			if action == "pause":
				print("WOBBLE_PAUSED owners=%d axis=%.0f" % [controls.owners.size(),controls.axis()])
			box.freeze = controls.paused
			seesaw.freeze = controls.paused

func _physics_process(dt: float) -> void:
	if not controls.paused:
		clock += dt
		bell_flash = maxf(0, bell_flash - dt)
		bell_cooldown = maxf(0, bell_cooldown - dt)
		if (spring.overlaps_body(bloop) or rescue_spring.overlaps_body(bloop)) and bloop.velocity.y >= 0:
			bloop.launch()
		for body in bell.get_overlapping_bodies():
			var speed: float = body.velocity.length() if body is CharacterBody2D else body.linear_velocity.length() if body is RigidBody2D else 0.0
			if speed > 65 and bell_cooldown <= 0:
				bell_rings += 1
				bell_flash = 1.5
				bell_cooldown = 0.8
				sound.chirp("bell")
				controls.status = "DING! The bell is awake. Try another way to ring it!"
				print("WOBBLE_EVENT bell rings=",bell_rings)
	var view := get_viewport_rect().size
	camera.position = Vector2(clampf(bloop.position.x + 120, view.x * 0.5 - 70, 3600 - view.x * 0.5), clampf(bloop.position.y - 90, 300, 480))
	controls.debug_text = "%s · vx %.0f vy %.0f · %s · speed %.0f jump %.0f · %s" % ["ROLL" if bloop.rolling else "WALK",bloop.velocity.x,bloop.velocity.y,"ground" if bloop.is_on_floor() else "air",bloop.tuning.walk_speed,bloop.tuning.jump_impulse,source.left(8)]
	controls.queue_redraw()
	if Engine.get_physics_frames() % 60 == 0 and OS.get_name() == "Android":
		print("WOBBLE_STATE x=%.2f y=%.2f jumps=%d bounces=%d roll=%s rings=%d" % [bloop.position.x,bloop.position.y,bloop.jumps,bloop.bounces,str(bloop.rolling),bell_rings])
	queue_redraw()

func label(at: Vector2, text: String, size := 23, color := Color("285855")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	# Layered original vector scenery; all evidence comes from this production renderer.
	for i in 15:
		var x := i * 310.0 - 300
		draw_circle(Vector2(x,390), 200 + (i % 3) * 45, Color("94c8b5"))
		draw_circle(Vector2(x + 120,480), 210, Color("83bea9"))
	for x in [70,630,1770,2850,3380]:
		draw_line(Vector2(x,540),Vector2(x-15,200),Color("669c87"),22)
		for i in 4:
			draw_circle(Vector2(x-65+i*40,210+sin(i)*25),65,Color("76b69a"))
		draw_circle(Vector2(x-29,235),5,Color("467966"))
		draw_circle(Vector2(x-4,235),5,Color("467966"))
	for points in terrain:
		draw_colored_polygon(points, Color("d6a775"))
		var line := PackedVector2Array()
		for i in points.size()-2:
			line.append(points[i])
		draw_polyline(line,Color("588b69"),18,true)
		draw_polyline(line,Color("9ebc71"),6,true)
	# Dotted earth and waving flowers, fixed local seed.
	decorations.seed = 82
	for i in 110:
		var x := decorations.randf_range(-200,3500)
		var y := decorations.randf_range(670,840)
		draw_circle(Vector2(x,y),decorations.randf_range(2,5),Color("bd9269"))
	for x in [310,390,470,890,970,1450,1600,2010,2340,2870,3320]:
		var ground := 530.0
		if x > 800 and x < 1050: ground = 410
		if x > 1400 and x < 1650: ground = 630
		if x > 1900 and x < 2600: ground = 510
		if x > 2800: ground = 440
		var top := Vector2(x+sin(clock*2+x)*4,ground-35)
		draw_line(Vector2(x,ground), top, Color("588b69"),3)
		for i in 5:
			draw_circle(top+Vector2.from_angle(i*TAU/5)*7,5,Color("fff9dc"))
		draw_circle(top,4,Color("e9b75d"))
	label(Vector2(115,370), "Meet Bloop.", 40)
	label(Vector2(115,404), "Little legs. Big downhill ideas.", 21)
	label(Vector2(675,315), "LEGS UP? ROLL ON.", 23)
	label(Vector2(1380,545), "THE BOING PATCH", 23)
	label(Vector2(1840,400), "A BOX WITH PLACES TO BE", 20)
	label(Vector2(2310,375), "A LITTLE WEIGHT GOES A LONG WAY", 18)
	label(Vector2(2980,160), "WAKE THE BELL", 29)
	# Spring mushroom.
	for i in 6:
		draw_line(Vector2(1460+i*20,637),Vector2(1460+i*20,618+sin(clock*3+i)*3),Color("a36f9c"),8)
	draw_style_box(Controls.panel(Color("d99fc4")),Rect2(1445,605,130,17))
	for i in 5:
		draw_circle(Vector2(1460+i*24,610),4,Color("fff9dc"))
	# Recovery mushroom in the gap: experiment without a death pit.
	draw_style_box(Controls.panel(Color("d99fc4")),Rect2(2125,728,120,20))
	for i in 5:
		draw_circle(Vector2(2138+i*23,735),4,Color("fff9dc"))
	# Seesaw fulcrum.
	draw_colored_polygon(PackedVector2Array([Vector2(2448,518),Vector2(2480,477),Vector2(2512,518)]),Color("7b9790"))
	# Bell arch and reactive face.
	draw_polyline(PackedVector2Array([Vector2(3020,450),Vector2(3020,230),Vector2(3240,230),Vector2(3240,450)]), Color("588b69"),14,true)
	var sway := sin(clock*20)*bell_flash*9
	draw_line(Vector2(3130,230),Vector2(3130+sway,283),Color("805e59"),5)
	draw_circle(Vector2(3130+sway,302),31,Color("ffd86f"))
	draw_style_box(Controls.panel(Color("e8b85d")),Rect2(3090+sway,306,80,21))
	for x in [-11,11]:
		if bell_flash > 0:
			draw_circle(Vector2(3130+sway+x,299),3,Color("285855"))
		else:
			draw_line(Vector2(3126+sway+x,300),Vector2(3134+sway+x,300),Color("285855"),3)
	if bell_flash > 0:
		label(Vector2(3070,207),"D I N G !",25)

func print_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	controls.layout()
	var transform := get_viewport().get_screen_transform()
	var targets := {"jump": controls.jump_center,"roll":controls.roll_center,"move":Vector2(170,controls.size.y-150),"move_end":Vector2(255,controls.size.y-150),"menu":Vector2(controls.size.x-controls.inset.x-55,controls.inset.y+25)}
	var data := {}
	for key in targets:
		var point: Vector2 = transform * targets[key]
		data[key] = [roundi(point.x),roundi(point.y)]
	print("WOBBLE_LAYOUT ",JSON.stringify(data))

func layout_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	controls.layout()
	var view := get_viewport_rect().size
	if controls.jump_center.x+64 >= view.x or controls.jump_center.y+64 >= view.y:
		push_error("Control outside viewport")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var out := "build/layout"
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out+"/%dx%d.png" % [get_window().size.x,get_window().size.y])
	print("LAYOUT_PASSED ",view)
	get_tree().quit()
