extends RigidBody2D
var kind := "box"
var flash := 0.0
func _ready() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(360, 18) if kind == "seesaw" else Vector2(64, 64)
	collision.shape = shape
	add_child(collision)
	mass = 3.0 if kind == "seesaw" else 1.3
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.65
	physics_material_override.bounce = 0.15
	if kind == "seesaw":
		gravity_scale = 0.0
		lock_rotation = false
	queue_redraw()
func _draw() -> void:
	var rect := Rect2(-180,-9,360,18) if kind == "seesaw" else Rect2(-32,-32,64,64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d77d79") if kind == "seesaw" else Color("e4b467")
	style.set_corner_radius_all(7)
	style.border_color = Color("805e59")
	style.set_border_width_all(3)
	draw_style_box(style, rect)
	if kind == "box":
		draw_line(Vector2(-22,-22),Vector2(22,22),Color("b78851"),4)
		draw_line(Vector2(22,-22),Vector2(-22,22),Color("b78851"),4)
		draw_circle(Vector2(-11,-5), 3, Color("285855"))
		draw_circle(Vector2(11,-5), 3, Color("285855"))
