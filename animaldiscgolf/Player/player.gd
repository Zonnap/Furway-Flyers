extends CharacterBody3D

@onready var camera_mount = $camera_mount
@onready var animation_player = $godot_plush_model/AnimationPlayer

const SPEED = 5.0
const JUMP_VELOCITY = 8

@export var sens_horizontal = 0.3
@export var sens_verticle = 0.3

func _ready():
	#lock and hide mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event):
	#Handle camera movement
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_verticle))

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if animation_player.current_animation != "run":
				animation_player.play("run")
				
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if animation_player.current_animation != "idle":
				animation_player.play("idle")
				
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	var is_jumping = false
	if velocity.y > 0 and not is_on_floor():
		is_jumping = true
	if velocity.y <= 0 and not is_on_floor():
		is_jumping = false
	if is_jumping == true:
		animation_player.play("up")
	elif is_jumping == false and not is_on_floor():
		animation_player.play("fall")
		
	move_and_slide()
