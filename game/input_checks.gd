extends SceneTree
var controls: Control
func _initialize() -> void:
	call_deferred("checks")
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
func checks() -> void:
	controls = preload("res://game/controls.gd").new()
	root.add_child(controls)
	for dimensions in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,864),Vector2i(2340,1080),Vector2i(1024,768)]:
		root.size = dimensions
		await process_frame
		controls.layout()
		check(controls.jump_center.x+64 < controls.size.x, "jump outside display")
		check(controls.jump_center.y+64 < controls.size.y, "jump outside display")
		check(controls.roll_center.distance_to(controls.jump_center)>117, "overlapping action targets")
	controls.press(6,Vector2(40,controls.size.y-80))
	check(controls.axis()==0 and controls.anchor.x==40, "edge contact must establish a neutral anchor")
	controls.release(6)
	controls.press(7,Vector2(170,controls.size.y-150))
	controls.press(8,controls.jump_center)
	check(controls.owners.size()==2 and controls.jump_held, "two finger ownership")
	controls.press(8,controls.roll_center)
	check(not controls.take_roll(), "same finger dispatched twice")
	controls.press(9,controls.roll_center)
	check(controls.take_roll() and controls.move_id==7, "roll while moving")
	controls.release(8)
	check(not controls.jump_held and controls.move_id==7, "independent action release")
	controls.release(7)
	check(controls.axis()==0 and controls.move_id==-1, "movement release")
	controls.press(8,controls.jump_center)
	controls.press(10,controls.jump_center)
	check(not controls.owners.has(10), "jump must have one owner")
	controls.set_pause(true)
	check(controls.owners.is_empty() and not controls.jump_held and not controls.take_jump(), "pause cancellation")
	controls.set_pause(false)
	controls.press(7,Vector2(170,controls.size.y-150))
	controls.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(controls.paused and controls.owners.is_empty(), "background cancellation")
	print("INPUT_CHECKS_PASSED")
	quit()
