extends CharacterBody3D

# This holds all direct player script!
# The camera is controlled by its own script!

@export var camera_pivot: Node3D                     # Set this to CameraRig in Main.tscn
@export var rotation_lerp_speed: float = 10.0        # How fast the mesh turns toward movement

# --- Disc throw settings ---
@export var disc_scene: PackedScene                  # Set this to MidRangeDisc.tscn
@export var throw_force: float = 1.5                 # Base throw power multiplier
@export var throw_offset: Vector3 = Vector3(0, 1.5, 1.5) # Spawn in front of player

const SPEED := 5.0
const JUMP_VELOCITY := 4.5

@onready var anim_player: AnimationPlayer = $godot_plush_model/AnimationPlayer


func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- Jump ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- Movement input ---
	var input_dir: Vector2 = Input.get_vector("Move_Left", "Move_Right", "Move_Backward", "Move_Forward")
	var move_direction: Vector3 = Vector3.ZERO

	if input_dir.length() > 0.0:
		# -------- CAMERA-RELATIVE MOVEMENT --------
		var forward: Vector3
		var right: Vector3

		if is_instance_valid(camera_pivot):
			forward = -camera_pivot.global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()

			right = camera_pivot.global_transform.basis.x
			right.y = 0.0
			right = right.normalized()
		else:
			# Fallback if camera_pivot isn't set
			forward = -global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()

			right = global_transform.basis.x
			right.y = 0.0
			right = right.normalized()

		move_direction = (right * input_dir.x + forward * input_dir.y).normalized()

		# Apply horizontal velocity
		velocity.x = move_direction.x * SPEED
		velocity.z = move_direction.z * SPEED

		# Running animation if not jumping
		if is_on_floor() and velocity.y <= 0.0:
			if anim_player.current_animation != "run":
				anim_player.play("run")

		# Rotate mesh toward movement direction (lerped)
		if move_direction.length_squared() > 0.0:
			var target_rot_y: float = atan2(move_direction.x, move_direction.z)
			var mesh_rot: Vector3 = $godot_plush_model.rotation
			mesh_rot.y = lerp_angle(mesh_rot.y, target_rot_y, rotation_lerp_speed * delta)
			$godot_plush_model.rotation = mesh_rot

	else:
		# No input: decelerate
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

		# Switch to idle animation when we slow down
		if anim_player.current_animation == "run" and velocity.length_squared() <= 10.0:
			anim_player.play("idle")

	# --- Throw input (E, mouse, etc.) ---
	if Input.is_action_just_pressed("throw_disc") and is_on_floor():
		_throw_disc()

	# --- Apply movement ---
	move_and_slide()


func _throw_disc() -> void:
	if disc_scene == null:
		push_warning("No disc_scene assigned on Player!")
		return

	if camera_pivot == null:
		push_warning("No camera_pivot set on Player!")
		return

	# Instance the disc and add to the scene
	var disc: Node3D = disc_scene.instantiate()
	get_tree().current_scene.add_child(disc)

	# Spawn position in front of the player, based on camera forward
	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var spawn_pos: Vector3 = global_transform.origin + forward * throw_offset.z
	spawn_pos.y += throw_offset.y
	disc.global_transform.origin = spawn_pos

	# Throw direction: camera forward
	var direction: Vector3 = -camera_pivot.global_transform.basis.z
	if disc.has_method("throw_disc"):
		disc.throw_disc(direction, throw_force)
	else:
		push_warning("Disc scene does not have a 'throw_disc' method!")

	# Connect landing signal if available
	if disc.has_signal("disc_landed"):
		disc.disc_landed.connect(_on_disc_landed)


func _on_disc_landed() -> void:
	print("Disc has landed!")
