extends CharacterBody3D

#This holds all direct player script!
#The camera is controlled by it own script!

@onready var camera = $SpringArmPivot/Camera3D
@onready var anim_player = $godot_plush_model/AnimationPlayer

@export var rotation_lerp_power: float = 1.0 #unused as of now. For rotation lerp

const SPEED = 5.0 #player speed
const JUMP_VELOCITY = 4.5 #player jump speed

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("Move_Left", "Move_Right", "Move_Forward", "Move_Backward")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	direction = direction.rotated(Vector3.UP, camera.global_rotation.y)
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		# Sets running animation if the players not jumping
		if is_on_floor() and velocity.y <= 0:
			if anim_player.current_animation != "up":
				anim_player.play("run")
				# Rotates the player mesh to the traveling direction (NEEDS LERPED)
				if velocity.length_squared() >= 0.1:
					var look_position := global_position + Vector3(velocity.x, 0, velocity.z)
					look_position = lerp(rotation, look_position, rotation_lerp_power)
					$godot_plush_model.look_at(look_position, Vector3.UP, true)
	else:# Stops the player if no buttons are pressed
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		# Sets the animation to idle if player stops
		if anim_player.current_animation == "run" and velocity.length_squared() <= 10.0:
			anim_player.play("idle")
			
	move_and_slide()
