extends Node3D

@onready var spring_arm = $SpringArm3D

@export var mouse_sensitivity = 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vert_angle: float = PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vert_angle: float = PI/4


# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, min_vert_angle, max_vert_angle)
		
	if event.is_action_pressed("wheel_up"):
		spring_arm.spring_length -= 1
	if event.is_action_pressed("wheel_down"):
		spring_arm.spring_length += 1
