extends CharacterBody3D

@onready var camera = $camera_mount/SpringArm3D/Camera3D
@onready var camera_mount = $camera_mount
@onready var animation_player = $godot_plush_model/AnimationPlayer
@onready var state_chart = $StateChart

const SPEED = 5.0
const JUMP_VELOCITY = 8
const acceleration = 9
@export var sens_horizontal = 0.3
@export var sens_verticle = 0.3

var current_state
var old_state

var input_dir = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func _ready():
	#lock and hide mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event):
	#Handle camera movement
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_verticle))
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		state_chart.send_event("is_jumping")
		
	
func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if velocity.x == 0 and velocity.y == 0 and velocity.z == 0:
		state_chart.send_event("is_idle")

	move_and_slide()

# States

#Idle
func _on_idle_state_physics_processing(delta):
	if animation_player.current_animation != "idle":
		animation_player.play("idle")
	
	velocity.x = move_toward(velocity.x, 0, SPEED)
	velocity.z = move_toward(velocity.z, 0, SPEED)
	print("Idling")

#Run
func _on_run_state_physics_processing(delta):
	pass

#Jump
func _on_jump_state_entered():
	velocity.y = JUMP_VELOCITY
	print("Jumping")
