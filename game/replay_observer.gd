extends Node
var replay: Node
func _ready() -> void:
	process_physics_priority = 100
func _physics_process(_dt: float) -> void:
	replay.sample()
