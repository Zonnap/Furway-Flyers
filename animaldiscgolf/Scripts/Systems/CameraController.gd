extends Node3D

@export var target: Node3D               # Player
@export var distance: float = 5.0        # How far the camera sits behind
@export var height: float = 1.0          # How high above the target's origin
@export var yaw_sensitivity: float = 0.003
@export var pitch_sensitivity: float = 0.003

# Vertical angle limits (in radians)
@export var pitch_min: float = deg_to_rad(-60.0)   # can't look totally straight down
@export var pitch_max: float = deg_to_rad(-5.0)    # never go *above* horizon and show under-map

var yaw: float = 0.0
var pitch: float = deg_to_rad(-30.0)     # start slightly above

@onready var follow_camera: Camera3D = $FollowCamera


func _ready() -> void:
	if is_instance_valid(follow_camera):
		follow_camera.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)    # optional; locks mouse for nicer look


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Rotate around target with mouse movement
		yaw -= event.relative.x * yaw_sensitivity
		pitch = clamp(pitch - event.relative.y * pitch_sensitivity, pitch_min, pitch_max)


func _process(delta: float) -> void:
	if !is_instance_valid(target):
		return

	# Get the point we want to look at (slightly above the player's origin)
	var target_origin: Vector3 = target.global_transform.origin
	target_origin.y += height

	# Build rotation basis from yaw and pitch
	var basis := Basis()
	basis = basis.rotated(Vector3.UP, yaw)          # yaw around world up
	basis = basis.rotated(basis.x, pitch)           # pitch around camera's local X

	# Place rig at the target, then move the camera back along -Z
	global_transform.origin = target_origin
	global_transform.basis = basis

	# Camera sits behind the pivot along its local -Z axis
	follow_camera.transform.origin = Vector3(0, 0, distance)
