extends Control
signal command(action: String)
var owners: Dictionary = {}
var move_id := -1
var anchor := Vector2.ZERO
var thumb := Vector2.ZERO
var analog := 0.0
var jump_held := false
var jump_pending := false
var roll_pending := false
var mode_rolling := false
var paused := false
var menu := false
var debug_text := ""
var status := "Ring the sleepy bell. Anything with a good bonk will do!"
var jump_center := Vector2.ZERO
var roll_center := Vector2.ZERO
var inset := Vector2(36, 28)
var keyboard_jump := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(layout)
	layout()

func layout() -> void:
	size = get_viewport_rect().size
	inset = Vector2(36, 28)
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var scale_factor := size / Vector2(screen)
		inset.x = maxf(36, maxf(safe.position.x, screen.x - safe.end.x) * scale_factor.x + 18)
		inset.y = maxf(28, maxf(safe.position.y, screen.y - safe.end.y) * scale_factor.y + 18)
	jump_center = size - inset - Vector2(76, 78)
	roll_center = size - inset - Vector2(222, 60)
	queue_redraw()

func cancel() -> void:
	owners.clear()
	move_id = -1
	analog = 0
	jump_held = false
	jump_pending = false
	roll_pending = false
	keyboard_jump = false
	queue_redraw()

func set_pause(value: bool) -> void:
	cancel()
	paused = value
	menu = value
	command.emit("pause" if value else "resume")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		set_pause(true)

func axis() -> float:
	if paused:
		return 0.0
	var key_axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	return analog if move_id >= 0 else key_axis

func take_jump() -> bool:
	var value := jump_pending
	jump_pending = false
	return value

func take_roll() -> bool:
	var value := roll_pending
	roll_pending = false
	return value

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			set_pause(not paused)
		if paused:
			return
		if event.keycode == KEY_SPACE:
			jump_held = event.pressed
			if event.pressed:
				jump_pending = true
		if event.keycode == KEY_R and event.pressed:
			roll_pending = true
	if event is InputEventScreenTouch:
		if event.pressed:
			press(event.index, event.position)
		else:
			release(event.index)
	if event is InputEventScreenDrag and owners.has(event.index):
		if owners[event.index] == "move":
			thumb = event.position
			analog = clampf((thumb.x - anchor.x) / 85.0, -1, 1)
			if absf(analog) < 0.08:
				analog = 0
	queue_redraw()

func press(id: int, at: Vector2) -> void:
	if owners.has(id):
		return
	if Rect2(size.x - inset.x - 110, inset.y, 110, 50).has_point(at):
		set_pause(not paused)
		return
	if paused:
		for i in 9:
			if menu_rect(i).has_point(at):
				command.emit(["reset_bloop", "reset_all", "reset_experiment", "debug", "speed_down", "speed_up", "jump_down", "jump_up", "resume"][i])
				if i == 8:
					set_pause(false)
				return
		return
	if at.distance_to(jump_center) < 64:
		if not owners.values().has("jump"):
			owners[id] = "jump"
			jump_held = true
			jump_pending = true
	elif at.distance_to(roll_center) < 53:
		owners[id] = "roll"
		roll_pending = true
	elif at.x < size.x * 0.48 and at.y > size.y * 0.42 and move_id < 0:
		owners[id] = "move"
		move_id = id
		anchor = at
		thumb = at
		analog = 0.0

func release(id: int) -> void:
	if not owners.has(id):
		return
	if owners[id] == "move":
		move_id = -1
		analog = 0
	if owners[id] == "jump":
		jump_held = false
	owners.erase(id)

func menu_rect(i: int) -> Rect2:
	return Rect2(size.x * 0.5 - 260, 125 + i * 49, 520, 42)

func text_at(at: Vector2, text: String, font_size: int, color := Color("285855")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var ink := Color("285855")
	var cream := Color("fff9dc")
	text_at(Vector2(inset.x, inset.y + 25), "WOBBLE WORLD", 26)
	text_at(Vector2(inset.x, inset.y + 53), status, 17)
	draw_style_box(panel(cream), Rect2(size.x - inset.x - 110, inset.y, 110, 50))
	text_at(Vector2(size.x - inset.x - 91, inset.y + 32), "LAB  ≡", 21)
	var stick := anchor.clamp(Vector2(inset.x + 68, size.y * 0.45), Vector2(size.x * 0.44, size.y - inset.y - 68)) if move_id >= 0 else Vector2(inset.x + 105, size.y - inset.y - 100)
	draw_circle(stick, 68, Color(0.16,0.35,0.33,0.13))
	draw_arc(stick, 68, 0, TAU, 48, Color(1,0.98,0.86,0.65), 3, true)
	draw_circle(stick + Vector2(analog * 47, 0), 28, Color(1,0.98,0.86,0.75))
	text_at(stick + Vector2(-43, 105), "DRAG TO GO", 15)
	draw_circle(jump_center + Vector2(0,4), 63, ink)
	draw_circle(jump_center, 61, Color("fff9dc") if not jump_held else Color("ffd86f"))
	text_at(jump_center + Vector2(-31,7), "JUMP", 22)
	draw_circle(roll_center + Vector2(0,4), 51, ink)
	draw_circle(roll_center, 49, Color("ffd86f"))
	text_at(roll_center + Vector2(-29,7), "LEGS" if mode_rolling else "ROLL", 20)
	text_at(Vector2(inset.x + 260, size.y - inset.y - 16), debug_text, 14)
	if menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08,0.22,0.22,0.9))
		text_at(Vector2(size.x * 0.5 - 260, 95), "BLOOP'S LITTLE LAB · paused", 28, cream)
		var labels := ["Reset Bloop", "Restart playground", "Reset box + seesaw", "Toggle collision / velocity", "Walk speed −", "Walk speed +", "Jump power −", "Jump power +", "Resume"]
		for i in labels.size():
			draw_style_box(panel(cream), menu_rect(i))
			text_at(menu_rect(i).position + Vector2(20,28), labels[i], 20)

static func panel(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	return style
