extends Node2D
# Assembles the production scene and owns every interaction between Bloop and
# the world. Tests and replays drive this exact scene through real input events.
const Art = preload("res://game/art.gd")
const Bloop = preload("res://game/bloop.gd")
const Controls = preload("res://game/controls.gd")
const Terrain = preload("res://game/terrain.gd")
const Props = preload("res://game/props.gd")
const Scatter = preload("res://game/scatter.gd")
const Level = preload("res://game/level.gd")

var bloop: CharacterBody2D
var controls: Control
var camera: Camera2D
var sound: Node
var fx: Node2D
var backdrop: Node2D
var seeds: Node2D
var flora: Node2D
var flowers: Node2D
var replay: Node
var grounds: Array = []
var mushrooms: Array = []
var checkpoints: Array = []
var snoozles: Array = []
var toys: Array = []
var crumbles: Array = []
var plate: Node2D
var gate: Node2D
var bell: Node2D
var box: RigidBody2D

var source := "working-tree"
var clock := 0.0
var play_time := 0.0
var seeds_got := 0
var snoozles_got := 0
var bell_rings := 0
var bell_cooldown := 0.0
var awake := false
var awake_t := 0.0
var day := 0.0
var results_shown := false
var respawn := Level.START
var respawn_t := 0.0
var splashes := 0
var crumble_t := -1.0
var trail: Array[Vector2] = []
var cam_pos := Vector2.ZERO
var cam_look := Vector2.ZERO
var cam_zoom := 1.15
var shake := 0.0
var dust_t := 0.0

func _ready() -> void:
	if FileAccess.file_exists("res://game/build-source.txt"):
		source = FileAccess.get_file_as_string("res://game/build-source.txt").strip_edges()
	var testing := false
	for arg in OS.get_cmdline_user_args():
		testing = testing or arg.begins_with("--replay")
	if testing:
		seed(1)
	var sky := CanvasLayer.new()
	sky.layer = -10
	add_child(sky)
	backdrop = preload("res://game/backdrop.gd").new()
	sky.add_child(backdrop)
	fx = preload("res://game/fx.gd").new()
	seeds = Scatter.Seeds.new()
	flora = Scatter.Flora.new()
	flowers = Scatter.Flora.new()
	flowers.front = false
	flowers.world = self
	bloop = Bloop.new()
	bloop.world = self
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	controls = Controls.new()
	bloop.controls = controls
	seeds.world = self
	flora.world = self
	Level.build(self)
	var pond := Props.Pond.new()
	pond.area = Level.POND
	pond.world = self
	pond.add_to_group("tinted")
	add_child(pond)
	scatter_flora()
	add_child(flowers)
	add_child(seeds)
	add_child(bloop)
	add_child(flora)
	add_child(fx)
	add_child(layer)
	layer.add_child(controls)
	bloop.reset_at(Level.START)
	controls.command.connect(on_command)
	controls.seeds_total = seeds.spots.size()
	controls.snoozles_total = snoozles.size()
	sound = preload("res://game/sound.gd").new()
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	sound.with_music = not testing
	add_child(sound)
	bloop.event.connect(on_event)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam_pos = bloop.position + Vector2(120, -110)
	camera.position = cam_pos
	camera.zoom = Vector2(cam_zoom, cam_zoom)
	add_child(camera)
	set_day(0.0)
	print("WOBBLE_READY source=", source)
	if OS.get_name() == "Android":
		print_layout.call_deferred()
	if "--layout-check" in OS.get_cmdline_user_args():
		layout_check.call_deferred()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			var shots := preload("res://game/dev_shots.gd").new()
			shots.world = self
			shots.spec = arg.trim_prefix("--shots=")
			add_child(shots)
	if testing:
		replay = preload("res://game/replay.gd").new()
		replay.world = self
		replay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(replay)

# ---- Level construction helpers used by level.gd ----

func add_ground(chunk: Array) -> void:
	var pts := Terrain.smooth(chunk)
	var first := pts[0]
	var last := pts[pts.size() - 1]
	pts.append(Vector2(last.x, Level.BOTTOM))
	pts.append(Vector2(first.x, Level.BOTTOM))
	var land := Terrain.new()
	land.poly = pts
	land.seed_value = int(first.x) + 99
	add_child(land)
	grounds.append(land)

func add_island(at: Vector2, width: float, depth: float) -> void:
	var pts := PackedVector2Array([Vector2(-width * 0.5 + 6, 0), Vector2(width * 0.5 - 6, 0)])
	for i in range(1, 12):
		var a := i * PI / 12.0
		pts.append(Vector2(cos(a) * width * 0.5, sin(a) * depth + 3))
	var land := Terrain.new()
	land.poly = pts
	land.strata = false
	land.position = at
	add_child(land)

func ground_y(x: float) -> float:
	var best := INF
	for land in grounds:
		best = minf(best, land.height_at(x))
	return best

func add_mushroom(x: float, angle: float, power: float, width: float) -> void:
	var m := Props.Mushroom.new()
	m.position = Vector2(x, ground_y(x) + 3)
	m.rotation = angle
	m.power = power
	m.width = width
	m.add_to_group("tinted")
	add_child(m)
	mushrooms.append(m)

func add_checkpoint(x: float) -> void:
	var cp := Props.Checkpoint.new()
	cp.position = Vector2(x, ground_y(x) + 2)
	cp.world = self
	cp.add_to_group("tinted")
	add_child(cp)
	checkpoints.append(cp)

func add_sign(x: float, icons: Array, caption: String) -> void:
	var sign := Props.Sign.new()
	sign.position = Vector2(x, ground_y(x) + 4)
	sign.icons = icons
	sign.caption = caption
	add_child(sign)

func add_critter(x: float, lines: Array, after: String, hue: Color, tall: float, hat: int) -> void:
	var critter := Props.Critter.new()
	critter.position = Vector2(x, ground_y(x) + 4)
	critter.lines = lines
	critter.after = after
	critter.hue = hue
	critter.tall = tall
	critter.hat = hat
	critter.world = self
	add_child(critter)

func add_toy(kind: String, at: Vector2) -> void:
	var toy := Props.Toy.new()
	toy.kind = kind
	toy.position = at
	toy.home = at
	add_child(toy)
	toys.append(toy)
	if kind == "crate":
		box = toy

func add_plate(x: float) -> void:
	plate = Props.Plate.new()
	plate.position = Vector2(x, ground_y(x))
	plate.add_to_group("tinted")
	add_child(plate)

func add_gate(x: float) -> void:
	gate = Props.Gate.new()
	gate.position = Vector2(x, ground_y(x) + 4)
	add_child(gate)

func add_crumble(at: Vector2) -> void:
	var block := Props.Crumble.new()
	block.position = at
	add_child(block)
	crumbles.append(block)

func add_bell(x: float) -> void:
	bell = Props.Bell.new()
	bell.position = Vector2(x, ground_y(x))
	bell.world = self
	add_child(bell)

func add_snoozle(at: Vector2) -> void:
	var sn := Props.Snoozle.new()
	sn.position = at
	sn.world = self
	add_child(sn)
	snoozles.append(sn)

func seed_ground(from: float, to: float, step: float) -> void:
	var x := from
	while x <= to:
		var y := ground_y(x)
		if y < INF:
			seeds.add(Vector2(x, y - 48))
		x += step

func seed_line(a: Vector2, b: Vector2, count: int) -> void:
	for i in count:
		seeds.add(a.lerp(b, float(i) / maxf(1, count - 1)))

func seed_arc(a: Vector2, apex: Vector2, b: Vector2, count: int) -> void:
	var control := apex * 2.0 - (a + b) * 0.5
	for i in count:
		var t := float(i) / (count - 1)
		seeds.add(a.lerp(control, t).lerp(control.lerp(b, t), t))

func scatter_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for land in grounds:
		for run in land.runs:
			var x: float = run[0].x + 26.0
			while x < run[run.size() - 1].x - 26.0:
				var y: float = land.height_at(x)
				if y < INF:
					if rng.randf() < 0.72:
						flora.add(Vector2(x, y), 0, rng)
					else:
						flowers.add(Vector2(x, y), 1, rng)
				x += rng.randf_range(34, 105)
	flora.finish()
	flowers.finish()

# ---- Interactions ----

func set_day(value: float) -> void:
	day = value
	backdrop.day = value
	var tint := Art.DAWN_TINT.lerp(Color.WHITE, value)
	for node in get_tree().get_nodes_in_group("tinted"):
		node.modulate = tint
	for land in get_children():
		if land is StaticBody2D:
			land.modulate = tint

func trail_point(back: int) -> Vector2:
	if trail.is_empty():
		return bloop.position + Vector2(0, 14)
	return trail[maxi(0, trail.size() - 1 - back)]

func collect_seed(at: Vector2) -> void:
	seeds_got += 1
	controls.seed_pop = 1.0
	sound.seed_note()
	fx.burst("spark", at, 5)

func kick_at(at: Vector2, dir: float) -> void:
	var hit := false
	for node in get_tree().get_nodes_in_group("kickable"):
		var point: Vector2 = node.bell_point() if node == bell else node.global_position + (Vector2(0, -30) if node is Props.Critter else Vector2.ZERO)
		if point.distance_to(at) < node.kick_radius + 30.0:
			node.kicked(dir, bloop.tuning.kick_power)
			hit = true
	if hit:
		sound.chirp("thwack")
		fx.burst("star", at, 6)
		shake = maxf(shake, 5.0)
		print("WOBBLE_EVENT thwack")

func pound_at(at: Vector2) -> void:
	fx.burst("ring", at, 1, Vector2.UP, 1.3)
	fx.burst("dust", at, 12, Vector2.UP, 1.8)
	shake = maxf(shake, 13.0)
	for toy in toys:
		var away: Vector2 = toy.global_position - at
		if away.length() < 210:
			toy.sleeping = false
			toy.apply_central_impulse(Vector2(signf(away.x) * 120.0, -430.0) * toy.mass)
	for block in crumbles:
		if is_instance_valid(block) and block.global_position.distance_to(at) < 120 and crumble_t < 0:
			crumble_t = 0.0
			sound.chirp("crumble")
			print("WOBBLE_EVENT crumble")

func ring_bell() -> void:
	if bell_cooldown > 0:
		return
	bell_cooldown = 0.7
	bell_rings += 1
	sound.chirp("bell", 1.0, -6.0)
	shake = maxf(shake, 9.0)
	fx.burst("ring", bell.bell_point(), 1, Vector2.UP, 2.0)
	fx.burst("spark", bell.bell_point(), 14, Vector2.UP, 1.5)
	print("WOBBLE_EVENT bell rings=", bell_rings)
	if not awake:
		awake = true
		bell.rung = true
		sound.chirp("fanfare", 1.0, -8.0)
		sound.stem_target[1] = 1.0
		sound.stem_target[2] = 1.0
		fx.burst("confetti", bell.bell_point() + Vector2(0, 40), 70)

func fall_in(wet: bool) -> void:
	if respawn_t > 0:
		return
	splashes += 1
	respawn_t = 0.7
	bloop.frozen = true
	bloop.visible = false
	if wet:
		fx.burst("splash", Vector2(bloop.position.x, Level.POND.position.y), 16)
	sound.chirp("splash")
	print("WOBBLE_EVENT splash")

func teleport(at: Vector2) -> void:
	bloop.reset_at(at)
	bloop.frozen = false
	bloop.visible = true
	respawn_t = 0.0
	cam_pos = at + Vector2(0, -80)
	camera.position = cam_pos
	camera.reset_physics_interpolation()
	trail.clear()

func on_event(kind: String) -> void:
	var feet: Vector2 = bloop.position + Vector2(0, Bloop.R)
	var volume := -12.0
	match kind:
		"jump":
			fx.burst("dust", feet, 4)
		"land":
			volume = clampf(-22.0 + bloop.last_impact / 60.0, -22.0, -8.0)
			fx.burst("dust", bloop.position - bloop.ground_normal * Bloop.R, 3 + int(bloop.last_impact / 220.0))
			if bloop.last_impact > 800:
				shake = maxf(shake, 5.0)
		"bump":
			fx.burst("star", bloop.position, 4)
			shake = maxf(shake, 4.0)
		"roll", "walk":
			fx.burst("ring", bloop.position, 1, Vector2.UP, 0.7)
		"boost":
			fx.burst("dust", feet, 9, Vector2(-bloop.facing, -0.3), 1.6)
		"spring":
			fx.burst("spark", feet, 7)
	sound.chirp(kind, 1.0, volume)
	print("WOBBLE_EVENT ", kind)

func on_command(action: String) -> void:
	match action:
		"reset_bloop":
			teleport(respawn)
			controls.set_pause(false)
		"reset_all":
			get_tree().paused = false
			get_tree().reload_current_scene()
		"music":
			sound.music_on = not sound.music_on
			controls.music_on = sound.music_on
		"sfx":
			sound.sfx_on = not sound.sfx_on
			controls.sfx_on = sound.sfx_on
		"debug":
			bloop.debug_draw = not bloop.debug_draw
			controls.show_debug = bloop.debug_draw
		"speed_down": bloop.tuning.walk_speed = maxf(100, bloop.tuning.walk_speed - 30)
		"speed_up": bloop.tuning.walk_speed = minf(500, bloop.tuning.walk_speed + 30)
		"jump_down": bloop.tuning.jump_impulse = maxf(300, bloop.tuning.jump_impulse - 30)
		"jump_up": bloop.tuning.jump_impulse = minf(800, bloop.tuning.jump_impulse + 30)
		"pause":
			print("WOBBLE_PAUSED owners=%d axis=%.0f" % [controls.owners.size(), controls.axis()])
			get_tree().paused = true
		"resume":
			get_tree().paused = false
	update_hud()

func update_hud() -> void:
	controls.mode_rolling = bloop.rolling
	controls.airborne = not bloop.grounded
	controls.seeds = seeds_got
	controls.snoozles = snoozles_got
	controls.debug_text = "%s  vx %.0f vy %.0f  %s  walk %.0f jump %.0f  x %.0f y %.0f  %s" % ["BALL" if bloop.rolling else "LEGS", bloop.velocity.x, bloop.velocity.y, "ground" if bloop.grounded else "air", bloop.tuning.walk_speed, bloop.tuning.jump_impulse, bloop.position.x, bloop.position.y, source.left(8)]

func _physics_process(dt: float) -> void:
	clock += dt
	bell_cooldown = maxf(0, bell_cooldown - dt)
	if controls.started and not awake:
		play_time += dt
	var speed := bloop.velocity.length()
	# Mushrooms, bell, snoozles, checkpoints.
	if not bloop.frozen:
		for m in mushrooms:
			m.check(bloop)
		if bloop.position.distance_to(bell.bell_point()) < 78 and speed > 110:
			bell.ring(clampf(bloop.velocity.x / 120.0, -6, 6))
		for sn in snoozles:
			if not sn.awake and sn.position.distance_to(bloop.position) < 62:
				sn.awake = true
				sn.order = snoozles_got
				snoozles_got += 1
				sound.chirp("wake")
				fx.burst("spark", sn.position, 12, Vector2.UP, 1.3)
				fx.burst("ring", sn.position, 1)
				print("WOBBLE_EVENT snoozle")
		for cp in checkpoints:
			if not cp.lit and bloop.position.x > cp.position.x - 30 and absf(bloop.position.y - cp.position.y) < 260:
				cp.lit = true
				respawn = cp.position + Vector2(0, -60)
				sound.chirp("check")
				sound.stem_target[1] = 1.0
				fx.burst("leaf", cp.position + Vector2(0, -70), 8)
		if (Level.POND.has_point(bloop.position) and bloop.position.y > Level.POND.position.y + 14) or bloop.position.y > Level.BOTTOM - 500:
			fall_in(bloop.position.y < Level.BOTTOM - 500)
		if speed > 2 and (trail.is_empty() or trail[trail.size() - 1].distance_to(bloop.position) > 5):
			trail.append(bloop.position + Vector2(0, 14))
			if trail.size() > 260:
				trail.remove_at(0)
		if bloop.rolling and bloop.grounded and speed > 420:
			dust_t -= dt
			if dust_t <= 0:
				dust_t = 0.07
				fx.burst("dust", bloop.position - bloop.ground_normal * Bloop.R, 1, -bloop.velocity.normalized(), 0.8)
	if respawn_t > 0:
		respawn_t -= dt
		if respawn_t <= 0:
			teleport(respawn)
			fx.burst("ring", respawn, 1)
			sound.chirp("walk")
	# Crate on the button opens the gate for good.
	if not gate.open:
		for toy in toys:
			if toy.kind == "crate" and absf(toy.position.x - plate.position.x) < 84 and absf(toy.position.y - plate.position.y) < 80 and toy.linear_velocity.length() < 260:
				gate.open = true
				plate.pressed = true
				sound.chirp("gate", 1.0, -8.0)
				sound.chirp("check")
				shake = maxf(shake, 8.0)
				print("WOBBLE_EVENT gate")
	for toy in toys:
		if toy.position.y > 520 or toy.position.x < 4960 or toy.position.x > 6560:
			toy.position = toy.home
			toy.linear_velocity = Vector2.ZERO
			toy.angular_velocity = 0.0
			toy.rotation = 0.0
			toy.reset_physics_interpolation()
			fx.burst("ring", toy.home, 1)
	# The hollow floor collapses block by block.
	if crumble_t >= 0:
		crumble_t += dt
		for i in crumbles.size():
			var block = crumbles[i]
			if is_instance_valid(block) and crumble_t > 0.04 * absf(block.position.x - bloop.position.x) / 50.0:
				fx.burst("chunk", block.position, 7)
				block.queue_free()
				crumbles[i] = null
	if awake:
		awake_t += dt
		if day < 1.0:
			set_day(minf(1.0, day + dt / 4.5))
		if awake_t < 3.0 and Engine.get_physics_frames() % 9 == 0:
			fx.burst("confetti", camera.position + Vector2(randf_range(-500, 500), 380), 6, Vector2.UP, 1.35)
		if awake_t > 5.5 and not results_shown:
			results_shown = true
			controls.show_results({"seeds": seeds_got, "seeds_total": seeds.spots.size(), "snoozles": snoozles_got, "snoozles_total": snoozles.size(), "time": play_time})
	sound.roll_level = move_toward(sound.roll_level, clampf(speed / 900.0, 0.0, 1.0) if bloop.rolling and bloop.grounded and not bloop.frozen else 0.0, dt * 5.0)
	update_camera(dt, speed)
	update_hud()
	if Engine.get_physics_frames() % 60 == 0 and OS.get_name() == "Android":
		print("WOBBLE_STATE x=%.2f y=%.2f jumps=%d bounces=%d roll=%s rings=%d" % [bloop.position.x, bloop.position.y, bloop.jumps, bloop.bounces, str(bloop.rolling), bell_rings])

func update_camera(dt: float, speed: float) -> void:
	var view := get_viewport_rect().size
	var want := Vector2(bloop.facing * 80.0 + clampf(bloop.velocity.x * 0.3, -300, 300), clampf(bloop.velocity.y * 0.16, -70, 190))
	cam_look = cam_look.lerp(want, 0.045)
	var target: Vector2 = bloop.position + Vector2(0, -80) + cam_look
	if awake and awake_t < 5.0:
		target = bell.bell_point() + Vector2(0, -90)
	cam_pos.x = lerpf(cam_pos.x, target.x, 0.14)
	cam_pos.y = lerpf(cam_pos.y, target.y, 0.1)
	var zoom_target := lerpf(1.18, 0.82, smoothstep(280.0, 1050.0, speed))
	if awake and awake_t < 5.0:
		zoom_target = 0.9
	cam_zoom = lerpf(cam_zoom, zoom_target, 0.03 if zoom_target < cam_zoom else 0.012)
	var half := view * 0.5 / cam_zoom
	cam_pos.x = clampf(cam_pos.x, Level.LEFT - 260 + half.x, Level.RIGHT + 260 - half.x)
	cam_pos.y = minf(cam_pos.y, 1330.0 - half.y)
	shake = maxf(0, shake - dt * 40.0)
	camera.position = cam_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	camera.zoom = Vector2(cam_zoom, cam_zoom)
	backdrop.cam = cam_pos

func print_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	controls.layout()
	var transform := get_viewport().get_screen_transform()
	var targets := {"jump": controls.jump_center, "roll": controls.roll_center, "action": controls.action_center, "move": Vector2(170, controls.size.y - 150), "move_end": Vector2(255, controls.size.y - 150), "menu": controls.pause_rect().get_center()}
	var data := {}
	for key in targets:
		var point: Vector2 = transform * targets[key]
		data[key] = [roundi(point.x), roundi(point.y)]
	print("WOBBLE_LAYOUT ", JSON.stringify(data))

func layout_check() -> void:
	for i in 30:
		await get_tree().physics_frame
	controls.layout()
	var view := get_viewport_rect().size
	if controls.jump_center.x + 64 >= view.x or controls.jump_center.y + 64 >= view.y or controls.action_center.y - 46 <= 0:
		push_error("Control outside viewport")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var out := "build/layout"
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out + "/%dx%d.png" % [get_window().size.x, get_window().size.y])
	print("LAYOUT_PASSED ", view)
	get_tree().quit()
