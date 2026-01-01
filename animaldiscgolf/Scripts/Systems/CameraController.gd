extends Node3D

@export var target: Node3D               # Player
@export var distance: float = 5.0        # How far the camera sits behind
@export var height: float = 1.0          # How high above the target's origin

@export var aim_distance: float = 3.0    # distance when aiming/throwing
@export var aim_height: float = 0.2      # height when aiming
@export var aim_side_offset: float = 1.5 # how far to the side in aim view

@export var yaw_sensitivity: float = 0.003
@export var pitch_sensitivity: float = 0.003

# Vertical angle limits (in radians)
@export var pitch_min: float = deg_to_rad(-70.0)   # can't look totally straight down
@export var pitch_max: float = deg_to_rad(30.0)    # never go *above* horizon and show under-map

var yaw: float = 0.0
var pitch: float = deg_to_rad(-30.0)     # start slightly above

var in_throw_mode: bool = false

@onready var follow_camera: Camera3D = $SpringArm3D/FollowCamera
@export var aim_focus: Node3D  # set this to Player's DiscSocket (or an AimPivot)

@export var facing_path: NodePath = NodePath("godot_plush_model")
var facing_node: Node3D = null

func _ready() -> void:
	if is_instance_valid(follow_camera):
		follow_camera.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)    # optional; locks mouse for nicer look

	if is_instance_valid(target):
		facing_node = target.get_node_or_null(facing_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Rotate around target with mouse movement
		yaw -= event.relative.x * yaw_sensitivity
		pitch = clamp(pitch - event.relative.y * pitch_sensitivity, pitch_min, pitch_max)

func _physics_process(delta: float) -> void:
	if !is_instance_valid(target):
		return

	# Choose distance/side/height by mode
	var used_distance: float = aim_distance if in_throw_mode else distance
	var used_side: float = aim_side_offset if in_throw_mode else 0.0
	var used_height: float = aim_height if in_throw_mode else height

	# Focus: aim uses socket, otherwise player
	var focus_pos: Vector3 = target.global_transform.origin
	if in_throw_mode and is_instance_valid(aim_focus):
		focus_pos = aim_focus.global_transform.origin

	# Apply vertical offset for both modes
	focus_pos.y += used_height

	# Orbit rotation
	var basis := Basis()
	basis = basis.rotated(Vector3.UP, yaw)
	basis = basis.rotated(basis.x, pitch)

	global_transform.origin = focus_pos
	global_transform.basis = basis

	# SpringArm handles collision + camera distance
	var arm: SpringArm3D = $SpringArm3D
	arm.position = Vector3(used_side, 0.0, 0.0)
	arm.spring_length = used_distance

	# Camera sits at the end of the spring arm
	arm.spring_length = used_distance

# Put the camera at the end of the arm (collision-adjusted)
	var hit_len: float = arm.get_hit_length()
	follow_camera.position = Vector3(0.0, 0.0, hit_len)

func set_throw_mode(active: bool) -> void:
	in_throw_mode = active

	if active and is_instance_valid(target):
		var face_ref: Node3D = facing_node if is_instance_valid(facing_node) else target
		var forward: Vector3 = -face_ref.global_transform.basis.z
		yaw = atan2(forward.x, forward.z)
		pitch = deg_to_rad(-10.0)
