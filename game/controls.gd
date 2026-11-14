extends Control
# Two-thumb touch controls and HUD. Movement, jump, roll and action each have an
# independent touch owner; an existing touch never changes ownership.
signal command(action: String)
const Art = preload("res://game/art.gd")
const MENU := ["resume", "reset_bloop", "reset_all", "music", "sfx", "debug", "speed_down", "speed_up", "jump_down", "jump_up"]

var owners: Dictionary = {}
var move_id := -1
var anchor := Vector2.ZERO
var thumb := Vector2.ZERO
var analog := 0.0
var jump_held := false
var jump_pending := false
var roll_pending := false
var action_pending := false
var action_flash := 0.0
var roll_flash := 0.0
var paused := false
var menu := false
var jump_center := Vector2.ZERO
var roll_center := Vector2.ZERO
var action_center := Vector2.ZERO
var inset := Vector2(36, 28)

# HUD state supplied by the world.
var mode_rolling := false
var airborne := false
var seeds := 0
var seeds_total := 0
var snoozles := 0
var snoozles_total := 3
var seed_pop := 0.0
var debug_text := ""
var show_debug := false
var music_on := true
var sfx_on := true
var title := 1.0
var started := false
var clock := 0.0
var results: Dictionary = {}
var results_t := 0.0
var last_state: Array = []
var was_animating := false

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
	jump_center = size - inset - Vector2(78, 80)
	roll_center = jump_center + Vector2(-150, 24)
	action_center = jump_center + Vector2(-104, -112)
	queue_redraw()

func cancel() -> void:
	owners.clear()
	move_id = -1
	analog = 0
	jump_held = false
	jump_pending = false
	roll_pending = false
	action_pending = false
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

func take_action() -> bool:
	var value := action_pending
	action_pending = false
	return value

func show_results(data: Dictionary) -> void:
	results = data
	results_t = 0.0
	cancel()

func _process(dt: float) -> void:
	clock += dt
	action_flash = maxf(0, action_flash - dt * 4.0)
	roll_flash = maxf(0, roll_flash - dt * 4.0)
	seed_pop = maxf(0, seed_pop - dt * 4.0)
	if started:
		title = maxf(0, title - dt * 1.4)
	var animating := title > 0 or action_flash > 0 or roll_flash > 0
	if not results.is_empty() and results_t < 1.0:
		results_t = minf(1.0, results_t + dt * 2.2)
		animating = true
	# The HUD is only redrawn when something on it changed.
	var state := [seeds, snoozles, mode_rolling, airborne and mode_rolling, jump_held, move_id, snappedf(analog, 0.02), anchor, paused, menu, show_debug, music_on, sfx_on, results.is_empty(), size, debug_text if show_debug or menu else ""]
	if animating or was_animating or state != last_state:
		last_state = state
		queue_redraw()
	was_animating = animating

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			set_pause(not paused)
		if paused:
			return
		started = true
		if event.keycode == KEY_SPACE or event.keycode == KEY_UP or event.keycode == KEY_W:
			jump_held = event.pressed
			if event.pressed:
				jump_pending = true
		if (event.keycode == KEY_R or event.keycode == KEY_SHIFT or event.keycode == KEY_DOWN or event.keycode == KEY_S) and event.pressed:
			roll_pending = true
			roll_flash = 1.0
		if (event.keycode == KEY_E or event.keycode == KEY_X or event.keycode == KEY_J) and event.pressed:
			action_pending = true
			action_flash = 1.0
	if event is InputEventScreenTouch:
		if event.pressed:
			press(event.index, event.position)
		else:
			release(event.index)
	if event is InputEventScreenDrag and owners.has(event.index):
		if owners[event.index] == "move":
			thumb = event.position
			analog = clampf((thumb.x - anchor.x) / 80.0, -1, 1)
			if absf(analog) < 0.1:
				analog = 0
			elif absf(analog) > 0.55:
				analog = signf(analog)

func pause_rect() -> Rect2:
	return Rect2(size.x - inset.x - 64, inset.y, 64, 56)

func results_rect(i: int) -> Rect2:
	return Rect2(size.x * 0.5 - 250 + i * 260, size.y * 0.5 + 118, 240, 58)

func press(id: int, at: Vector2) -> void:
	if owners.has(id):
		return
	if pause_rect().grow(8).has_point(at):
		set_pause(not paused)
		return
	if paused:
		# The pause menu sits above everything, including the results card.
		for i in MENU.size():
			if menu_rect(i).has_point(at):
				if i == 0:
					set_pause(false)
				else:
					command.emit(MENU[i])
				return
		return
	if not results.is_empty():
		if results_t >= 1.0:
			if results_rect(0).has_point(at):
				command.emit("reset_all")
			elif results_rect(1).has_point(at):
				results = {}
		return
	started = true
	if at.distance_to(jump_center) < 68:
		if not owners.values().has("jump"):
			owners[id] = "jump"
			jump_held = true
			jump_pending = true
	elif at.distance_to(roll_center) < 56:
		owners[id] = "roll"
		roll_pending = true
		roll_flash = 1.0
	elif at.distance_to(action_center) < 54:
		owners[id] = "action"
		action_pending = true
		action_flash = 1.0
	elif at.x < size.x * 0.48 and at.y > size.y * 0.3 and move_id < 0:
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
	return Rect2(size.x * 0.5 - 330 + (i % 2) * 340, 190 + (i / 2) * 68, 320, 56)

func button(center: Vector2, radius: float, icon: String, lit: float, held: bool) -> void:
	var grow := 1.0 + lit * 0.12 - (0.05 if held else 0.0)
	Art.disc(self, center + Vector2(0, 5), radius * grow, Color(0.16, 0.1, 0.24, 0.35))
	Art.disc(self, center, radius * grow, Color(1, 0.965, 0.86, 0.9 if held or lit > 0 else 0.62))
	Art.arc(self, center, radius * grow, 0, TAU, 48, Color(Art.INK, 0.85), 3.5)
	Art.icon(self, icon, center, radius / 30.0, Color(Art.INK, 0.9))

func _draw() -> void:
	var ink := Art.INK
	var cream := Art.CREAM
	# Seed and snoozle counters.
	var chip := Rect2(inset.x, inset.y, 150 + (30 if seeds_total >= 100 else 0), 50)
	Art.panel(self, chip, 25, Color(1, 0.965, 0.86, 0.88), Color(ink, 0.85), 3)
	Art.seed_shape(self, chip.position + Vector2(28, 25), 1.15, 0.0)
	Art.text(self, chip.position + Vector2(52, 34), "%d / %d" % [seeds, seeds_total], 24, ink)
	for i in snoozles_total:
		var c := Vector2(chip.end.x + 34 + i * 44, inset.y + 27)
		var got := i < snoozles
		Art.blob(self, Art.ellipse_points(c, Vector2(15, 14), 0.0, 16), Color("ffe9a8") if got else Color(1, 1, 1, 0.25), Color(ink, 0.85 if got else 0.4), 3)
		Art.blob(self, PackedVector2Array([c + Vector2(-10, -9), c + Vector2(4, -27), c + Vector2(11, -8)]), Art.TEAL if got else Color(1, 1, 1, 0.25), Color(ink, 0.85 if got else 0.4), 2.5)
		if got:
			Art.disc(self, c + Vector2(-5, 0), 2.2, ink)
			Art.disc(self, c + Vector2(5, 0), 2.2, ink)
	# Pause.
	var pr := pause_rect()
	Art.panel(self, pr, 20, Color(1, 0.965, 0.86, 0.75), Color(ink, 0.85), 3)
	Art.icon(self, "pause", pr.get_center(), 1.0, ink)
	# Stick.
	var stick := anchor.clamp(Vector2(inset.x + 70, size.y * 0.35), Vector2(size.x * 0.44, size.y - inset.y - 70)) if move_id >= 0 else Vector2(inset.x + 110, size.y - inset.y - 104)
	Art.disc(self, stick, 70, Color(0.16, 0.1, 0.24, 0.2))
	Art.arc(self, stick, 70, 0, TAU, 48, Color(1, 0.965, 0.86, 0.7), 3.5)
	Art.disc(self, stick + Vector2(analog * 46, 0), 30, Color(1, 0.965, 0.86, 0.9 if move_id >= 0 else 0.6))
	Art.arc(self, stick + Vector2(analog * 46, 0), 30, 0, TAU, 32, Color(ink, 0.8), 3)
	Art.icon(self, "move", stick + Vector2(analog * 46, 0), 0.9, Color(ink, 0.8))
	# Action buttons.
	button(jump_center, 64, "jump", 0.0, jump_held)
	button(roll_center, 50, "legs" if mode_rolling else "roll", roll_flash, false)
	var act := "kick"
	if mode_rolling:
		act = "pound" if airborne else "boost"
	button(action_center, 46, act, action_flash, false)
	if show_debug:
		Art.text(self, Vector2(inset.x + 250, size.y - inset.y - 8), debug_text, 14, cream)
	# Title card: the game is already live underneath.
	if title > 0:
		var a := title
		var word := "WOBBLE WORLD"
		var font := ThemeDB.fallback_font
		var fsize := 84
		var total := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var x := size.x * 0.5 - total * 0.5
		for i in word.length():
			var ch := word[i]
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			var y := size.y * 0.3 + sin(clock * 2.6 + i * 0.7) * 9.0 - (1.0 - a) * 60.0
			draw_set_transform(Vector2(x + w * 0.5, y), sin(clock * 2.0 + i) * 0.07, Vector2.ONE)
			draw_string_outline(font, Vector2(-w * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 16, Color(ink, a))
			draw_string(font, Vector2(-w * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(Art.GOLD if i % 2 == 0 else Art.CREAM, a))
			x += w
		draw_set_transform(Vector2.ZERO)
		Art.text_outlined(self, Vector2(size.x * 0.5, size.y * 0.3 + 52 - (1.0 - a) * 60.0), "the sun slept in. go wake it up.", 25, Color(cream, a), Color(ink, a), 8)
	if not results.is_empty():
		draw_results()
	if menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.08, 0.22, 0.82))
		Art.text_outlined(self, Vector2(size.x * 0.5, 120), "PAUSED", 56, Art.GOLD, ink, 14)
		Art.text(self, Vector2(size.x * 0.5, 160), "Bloop is having a little sit.", 20, cream, HORIZONTAL_ALIGNMENT_CENTER)
		var labels := ["Resume", "Back to checkpoint", "Restart from the top", "Music: %s" % ("on" if music_on else "off"), "Sound: %s" % ("on" if sfx_on else "off"), "Lab overlay: %s" % ("on" if show_debug else "off"), "Walk speed  -", "Walk speed  +", "Jump power  -", "Jump power  +"]
		for i in labels.size():
			Art.panel(self, menu_rect(i), 18, Art.GOLD if i == 0 else cream, ink, 3.5)
			Art.text(self, menu_rect(i).get_center() + Vector2(0, 8), labels[i], 22, ink, HORIZONTAL_ALIGNMENT_CENTER)
		Art.text(self, Vector2(size.x * 0.5, size.y - 40), debug_text, 14, Color(cream, 0.7), HORIZONTAL_ALIGNMENT_CENTER)

func draw_results() -> void:
	var ink := Art.INK
	var e := results_t * results_t * (3.0 - 2.0 * results_t)
	var rect := Rect2(size.x * 0.5 - 300, size.y * 0.5 - 200 + (1.0 - e) * 80.0, 600, 400)
	Art.panel(self, rect, 34, Color(Art.CREAM, 0.96 * e), Color(ink, e), 5)
	if e < 0.95:
		return
	Art.text_outlined(self, Vector2(size.x * 0.5, rect.position.y + 78), "GOOD MORNING!", 52, Art.GOLD, ink, 14)
	Art.text(self, Vector2(size.x * 0.5, rect.position.y + 118), "The sun is up. It is furious. Well done.", 20, ink, HORIZONTAL_ALIGNMENT_CENTER)
	var row := rect.position.y + 178
	Art.seed_shape(self, Vector2(rect.position.x + 95, row - 9), 1.3, 0.0)
	Art.text(self, Vector2(rect.position.x + 130, row), "Sunseeds", 24, ink)
	Art.text(self, Vector2(rect.end.x - 175, row), "%d / %d" % [results.seeds, results.seeds_total], 24, ink)
	row += 46
	Art.blob(self, Art.ellipse_points(Vector2(rect.position.x + 95, row - 8), Vector2(13, 12), 0.0, 14), Color("ffe9a8"), ink, 3)
	Art.text(self, Vector2(rect.position.x + 130, row), "Snoozles woken", 24, ink)
	Art.text(self, Vector2(rect.end.x - 175, row), "%d / %d" % [results.snoozles, results.snoozles_total], 24, ink)
	row += 46
	Art.text(self, Vector2(rect.position.x + 130, row), "Time", 24, ink)
	Art.text(self, Vector2(rect.end.x - 175, row), "%d:%02d" % [int(results.time) / 60, int(results.time) % 60], 24, ink)
	var labels := ["Play again", "Keep wobbling"]
	for i in 2:
		Art.panel(self, results_rect(i), 20, Art.GOLD if i == 0 else Color("e9dcc0"), ink, 3.5)
		Art.text(self, results_rect(i).get_center() + Vector2(0, 8), labels[i], 23, ink, HORIZONTAL_ALIGNMENT_CENTER)
