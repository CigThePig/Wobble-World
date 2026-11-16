extends Resource
class_name BloopTuning
# Legs: precise platforming.
@export var walk_speed: float = 300.0
@export var walk_acceleration: float = 2300.0
@export var walk_brake: float = 2600.0
@export var jump_impulse: float = 620.0
@export var gravity: float = 1500.0
@export var air_control: float = 900.0
@export var coyote_time: float = 0.11
@export var jump_buffer: float = 0.13
@export var jump_cut: float = 0.42
@export var push_force: float = 1600.0
@export var kick_power: float = 560.0
# Ball: momentum. Slopes accelerate it naturally because gravity is never cancelled.
@export var roll_acceleration: float = 620.0
@export var roll_brake: float = 1100.0
@export var roll_air: float = 420.0
@export var roll_drag: float = 0.1
@export var roll_jump: float = 560.0
@export var bounce: float = 0.42
@export var bounce_min: float = 280.0
@export var max_speed: float = 1150.0
@export var boost: float = 430.0
@export var pound_speed: float = 1500.0
@export var pound_bounce: float = 760.0
@export var mass: float = 1.6
