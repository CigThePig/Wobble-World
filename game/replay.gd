extends Node
# Drives the production scene with real viewport touch events at fixed ticks.
# "--replay" runs focused scenarios; "--replay=full" plays the level start to bell
# with a small position-aware bot. No gameplay code is duplicated here.
var world: Node
var tick := 0
var scenario := -1
var local_tick := 0
var out := "build/evidence"
var trace: FileAccess
var observer: Node
var full := false
var pit_seen := false
var scenarios := [
	{"name": "walk-stop-reverse", "at": Vector2(300, 560), "ticks": 180, "shots": [40, 100]},
	{"name": "short-jump", "at": Vector2(300, 560), "ticks": 150, "shots": [44]},
	{"name": "long-jump", "at": Vector2(300, 560), "ticks": 150, "shots": [50]},
	{"name": "coyote", "at": Vector2(300, 560), "ticks": 180, "shots": []},
	{"name": "buffer", "at": Vector2(300, 500), "ticks": 120, "shots": []},
	{"name": "cancel-focus", "at": Vector2(300, 560), "ticks": 120, "shots": [36]},
	{"name": "walk-roll", "at": Vector2(0, 560), "ticks": 240, "shots": [70, 150]},
	{"name": "walk-repeat", "at": Vector2(300, 560), "ticks": 180, "shots": []},
	{"name": "boing-ledge", "at": Vector2(950, 560), "ticks": 200, "shots": [50, 75, 110]},
	{"name": "hill-leap", "at": Vector2(1560, 390), "ticks": 420, "shots": [100, 160, 215, 240, 300]},
	{"name": "pond-fall", "at": Vector2(3060, 760), "ticks": 240, "shots": [40, 70, 150]},
	{"name": "garden", "at": Vector2(4060, 810), "ticks": 520, "shots": [60, 120, 250, 400]},
	{"name": "kick-crate", "at": Vector2(5440, 340), "ticks": 600, "shots": [24, 34, 60, 300, 520]},
	{"name": "slam-floor", "at": Vector2(6490, 330), "ticks": 420, "shots": [30, 44, 52, 70, 200, 330]},
	{"name": "big-boing", "at": Vector2(6760, 340), "ticks": 240, "shots": [40, 70, 110, 180]},
	{"name": "descent", "at": Vector2(7190, 20), "ticks": 480, "shots": [80, 160, 220, 260, 330]},
	{"name": "bell", "at": Vector2(10250, 660), "ticks": 520, "shots": [50, 80, 200, 330, 500]},
]

func _ready() -> void:
	process_physics_priority = -100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg == "--replay=full":
			full = true
	DirAccess.make_dir_recursive_absolute(out)
	trace = FileAccess.open(out + "/trace.jsonl", FileAccess.WRITE)
	observer = Node.new()
	observer.set_script(preload("res://game/replay_observer.gd"))
	observer.replay = self
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child.call_deferred(observer)

func touch(id: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.position = at
	e.pressed = down
	world.get_viewport().push_input(e, true)
	Input.flush_buffered_events()

func move(value: float) -> void:
	if is_zero_approx(value):
		if world.controls.move_id >= 0:
			touch(7, Vector2.ZERO, false)
		return
	if world.controls.move_id < 0:
		touch(7, Vector2(170, world.controls.size.y - 150), true)
	var e := InputEventScreenDrag.new()
	e.index = 7
	e.position = world.controls.anchor + Vector2(value * 80, 0)
	world.get_viewport().push_input(e, true)
	Input.flush_buffered_events()

func jump(down: bool) -> void:
	if down == world.controls.jump_held:
		return
	touch(8, world.controls.jump_center, down)

func roll() -> void:
	touch(9, world.controls.roll_center, true)
	touch(9, world.controls.roll_center, false)

func action() -> void:
	touch(10, world.controls.action_center, true)
	touch(10, world.controls.action_center, false)

func want_roll(value: bool) -> void:
	if world.bloop.rolling != value:
		roll()

func finish() -> void:
	trace.close()
	print("WOBBLE_REPLAY_COMPLETE")
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	if full:
		if tick == 0:
			scenario = 0
			scenarios = [{"name": "full-run", "at": world.bloop.position, "ticks": 9000, "shots": []}]
			print("SCENARIO full-run")
		local_tick = tick
		if tick >= 9000 or world.results_shown:
			finish()
			return
		play_level()
		tick += 1
		return
	if scenario < 0 or local_tick >= scenarios[scenario].ticks:
		scenario += 1
		local_tick = 0
		if scenario >= scenarios.size():
			finish()
			return
		world.controls.set_pause(false)
		world.controls.started = true
		world.teleport(scenarios[scenario].at)
		var b = world.bloop
		b.jumps = 0
		b.bounces = 0
		b.pushes = 0
		b.kicks = 0
		b.pounds = 0
		b.boosts = 0
		world.splashes = 0
		world.bell_cooldown = 0
		print("SCENARIO ", scenarios[scenario].name)
	var t := local_tick
	var b = world.bloop
	match scenarios[scenario].name:
		"walk-stop-reverse", "walk-repeat":
			if t == 20: move(1)
			if t == 65: move(0)
			if t == 90: move(-1)
			if t == 135: move(0)
		"short-jump", "long-jump":
			if t == 20: move(1)
			if t == 35: jump(true)
			if t == (39 if scenarios[scenario].name == "short-jump" else 70): jump(false)
			if t == 95: move(0)
		"coyote":
			if t == 30:
				# Remove floor contact, then use the live coyote window four ticks later.
				b.position.y -= 30
				b.velocity.y = -1
			if t == 34: jump(true)
			if t == 60: jump(false)
			if t == 110:
				b.position.y -= 300
				b.velocity.y = -1
			if t == 124: jump(true)
			if t == 125: jump(false)
		"buffer":
			if t == 14: jump(true)
			if t == 55: jump(false)
		"cancel-focus":
			if t == 20:
				move(1)
				jump(true)
			if t == 30: world.controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			if t == 45: world.controls.set_pause(false)
		"walk-roll":
			if t == 20: move(1)
			if t == 40: roll()
			if t == 70: move(0)
			if t == 150: roll()
		"boing-ledge":
			if t == 10: move(1)
			if t == 190: move(0)
		"hill-leap":
			if t == 10:
				roll()
				move(1)
			if b.position.x > 3700: move(0)
		"pond-fall":
			if t == 10: move(1)
			if t == 100: move(0)
		"garden":
			if t == 10: move(1)
			if b.position.x > 5060: move(0)
		"kick-crate":
			if t == 20: action()
			if t == 60: move(1)
			if world.gate.open and b.position.x > 6080: move(0)
		"slam-floor":
			if t == 20: roll()
			if t == 30: jump(true)
			if t == 44:
				jump(false)
				action()
			if t > 60: leave_pit()
		"big-boing":
			if t == 10:
				move(1)
				jump(true)
			if b.position.x > 7080:
				move(0)
				jump(false)
		"descent":
			if t == 10:
				roll()
				move(1)
			if t == 40: action()
			if b.position.x > 9900: move(0)
		"bell":
			if t == 10: move(1)
			if b.position.x > 10390 and t < 200:
				move(0)
				jump(true)
			if t == 200: jump(false)
	local_tick += 1
	tick += 1

func leave_pit() -> void:
	var b = world.bloop
	if b.position.y > 500 and b.position.x > 6290 and b.position.x < 6610:
		pit_seen = true
		want_roll(false)
		# Wake the snoozle, walk onto the mushroom, then steer for the right-hand rim.
		var goal := 6370.0 if world.snoozles[1].awake else 6570.0
		move(clampf((goal - b.position.x) / 30.0, -1, 1) if b.grounded else 1.0)
	elif pit_seen:
		move(1.0 if b.position.x < 6640 else 0.0)

func play_level() -> void:
	var b = world.bloop
	var x: float = b.position.x
	if b.frozen:
		return
	if x < 1300:
		want_roll(false)
		move(1)
	elif x < 3620:
		if x > 1480:
			want_roll(true)
		move(1)
	elif x < 5060:
		want_roll(false)
		jump(false)
		move(1)
	elif not world.gate.open:
		want_roll(false)
		var crate_x: float = world.box.position.x
		if x > crate_x - 30:
			move(-1)
		else:
			move(1)
		if crate_x - x < 75 and crate_x - x > 40 and b.kick_t <= 0 and b.grounded and crate_x < 5700:
			action()
	elif x < 6480 and not pit_seen and world.crumble_t < 0:
		want_roll(false)
		move(1)
		var gap: float = world.box.position.x - x
		jump(gap > 0 and gap < 95 and b.grounded)
	elif world.crumble_t < 0 and not pit_seen:
		move(0)
		if not b.rolling:
			jump(false)
		if b.grounded and not b.rolling and absf(b.velocity.x) < 5:
			roll()
		elif b.rolling and b.grounded:
			jump(true)
		elif b.rolling and b.velocity.y > -150 and not b.pounding:
			jump(false)
			action()
	elif x < 6660 and (b.position.y > 420 or not pit_seen):
		jump(false)
		leave_pit()
	elif x < 7030 and b.position.y > 100:
		want_roll(false)
		move(1)
		jump(true)
	elif x < 9800:
		jump(false)
		if b.grounded or b.rolling:
			want_roll(true)
		move(1)
		if b.grounded and x > 7200 and x < 7500 and b.boost_cd <= 0:
			action()
	elif not world.awake:
		want_roll(false)
		if x < 10395:
			move(1)
			jump(false)
		else:
			move(0)
			jump(local_tick % 60 < 30)
	else:
		move(0)
		jump(false)

func sample() -> void:
	if trace == null or not trace.is_open() or scenario < 0 or scenario >= scenarios.size():
		return
	var b = world.bloop
	trace.store_line(JSON.stringify({"frame": tick, "scenario": scenarios[scenario].name, "tick": local_tick, "x": b.position.x, "y": b.position.y, "vx": b.velocity.x, "vy": b.velocity.y, "grounded": b.grounded, "roll": b.rolling, "axis": world.controls.axis(), "held": world.controls.jump_held, "owners": world.controls.owners.size(), "paused": world.controls.paused, "jumps": b.jumps, "bounces": b.bounces, "pushes": b.pushes, "kicks": b.kicks, "pounds": b.pounds, "boosts": b.boosts, "rings": world.bell_rings, "seeds": world.seeds_got, "snoozles": world.snoozles_got, "splashes": world.splashes, "box_x": world.box.position.x, "gate": world.gate.open, "crumbled": world.crumble_t >= 0, "awake": world.awake, "day": world.day, "results": world.results_shown, "source": world.source}))
	if DisplayServer.get_name() == "headless":
		return
	if full:
		if tick % 150 == 60:
			capture("full-%04d" % tick)
	elif (local_tick - 1) in scenarios[scenario].shots:
		capture("%02d-%s-%03d" % [scenario, scenarios[scenario].name, local_tick - 1])

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
