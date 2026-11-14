extends Node
var world: Node
var tick := 0
var scenario := -1
var local_tick := 0
var out := "build/evidence"
var trace: FileAccess
var names := ["walk-stop-reverse", "short-jump", "long-jump", "walk-roll", "downhill", "spring", "box", "mode-motion", "cancel-focus", "coyote", "buffer", "bell", "seesaw", "walk-repeat"]
var starts := [Vector2(250,490),Vector2(250,490),Vector2(250,490),Vector2(250,490),Vector2(980,385),Vector2(1510,480),Vector2(1810,480),Vector2(250,490),Vector2(250,490),Vector2(250,490),Vector2(250,430),Vector2(3030,400),Vector2(2330,430),Vector2(250,490)]
var observer: Node
func _ready() -> void:
	process_physics_priority = -100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	trace = FileAccess.open(out + "/trace.jsonl",FileAccess.WRITE)
	observer = Node.new()
	observer.set_script(preload("res://game/replay_observer.gd"))
	observer.replay = self
	world.add_child.call_deferred(observer)

func touch(id: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.position = at
	e.pressed = down
	world.get_viewport().push_input(e, true)
	Input.flush_buffered_events()

func move(value: float) -> void:
	if world.controls.move_id < 0:
		touch(7,Vector2(170,world.controls.size.y-150),true)
	var e := InputEventScreenDrag.new()
	e.index = 7
	e.position = world.controls.anchor + Vector2(value*85,0)
	world.get_viewport().push_input(e, true)
	Input.flush_buffered_events()

func jump(down: bool) -> void:
	touch(8,world.controls.jump_center,down)
func roll() -> void:
	touch(9,world.controls.roll_center,true)
	touch(9,world.controls.roll_center,false)

func _physics_process(_dt: float) -> void:
	if tick >= names.size()*180:
		trace.close()
		print("WOBBLE_REPLAY_COMPLETE")
		get_tree().quit()
		return
	scenario = tick / 180
	local_tick = tick % 180
	if local_tick == 0:
		world.controls.set_pause(false)
		world.bloop.reset_at(starts[scenario])
		world.reset_toys()
		world.bloop.jumps = 0
		world.bloop.bounces = 0
		world.bloop.pushes = 0
		world.bell_rings = 0
		world.bell_cooldown = 0
		print("SCENARIO ", names[scenario])
	var name: String = names[scenario]
	match name:
		"walk-stop-reverse", "walk-repeat":
			if local_tick == 20: move(1)
			if local_tick == 65: touch(7,Vector2.ZERO,false)
			if local_tick == 90: move(-1)
			if local_tick == 135: touch(7,Vector2.ZERO,false)
		"short-jump", "long-jump":
			if local_tick == 20: move(1)
			if local_tick == 35: jump(true)
			if local_tick == (39 if name == "short-jump" else 65): jump(false)
			if local_tick == 95: touch(7,Vector2.ZERO,false)
		"walk-roll":
			if local_tick == 20: move(1)
			if local_tick == 50: roll()
			if local_tick == 80: touch(7,Vector2.ZERO,false)
			if local_tick == 130: roll()
		"downhill":
			if local_tick == 20:
				roll()
				move(1)
			if local_tick == 65: touch(7,Vector2.ZERO,false)
		"spring": pass
		"box":
			if local_tick == 20: move(1)
			if local_tick == 120: touch(7,Vector2.ZERO,false)
		"mode-motion":
			if local_tick == 20: move(1)
			if local_tick == 35: jump(true)
			if local_tick == 45: roll()
			if local_tick == 60: jump(false)
			if local_tick == 85: roll()
			if local_tick == 110: touch(7,Vector2.ZERO,false)
		"cancel-focus":
			if local_tick == 20:
				move(1)
				jump(true)
			if local_tick == 30: world.controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			if local_tick == 45: world.controls.set_pause(false)
		"coyote":
			if local_tick == 30:
				# Remove floor contact, then use the live coyote window four ticks later.
				world.bloop.position.y -= 30
				world.bloop.velocity.y = -1
			if local_tick == 34: jump(true)
			if local_tick == 60: jump(false)
		"buffer":
			if local_tick == 18: jump(true)
			if local_tick == 55: jump(false)
		"bell":
			if local_tick == 20: move(1)
			if local_tick == 30: jump(true)
			if local_tick == 60: jump(false)
			if local_tick == 65: touch(7,Vector2.ZERO,false)
		"seesaw":
			if local_tick == 20: move(1)
			if local_tick == 75: touch(7,Vector2.ZERO,false)
	tick += 1

func sample() -> void:
	if trace == null or not trace.is_open() or scenario < 0:
		return
	var b = world.bloop
	trace.store_line(JSON.stringify({"frame":tick,"scenario":names[scenario],"tick":local_tick,"x":b.position.x,"y":b.position.y,"vx":b.velocity.x,"vy":b.velocity.y,"grounded":b.is_on_floor(),"roll":b.rolling,"axis":world.controls.axis(),"held":world.controls.jump_held,"owners":world.controls.owners.size(),"jumps":b.jumps,"bounces":b.bounces,"pushes":b.pushes,"rings":world.bell_rings,"box_x":world.box.position.x,"seesaw_angle":world.seesaw.rotation,"source":world.source}))
	if local_tick in [34,40,50,65,90,120] and DisplayServer.get_name() != "headless":
		capture("%02d-%s-%03d" % [scenario,names[scenario],local_tick])

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/"+label+".png")
