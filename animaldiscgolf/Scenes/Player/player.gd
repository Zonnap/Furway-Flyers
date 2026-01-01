extends CharacterBody3D

#STATES

enum PlayerState { EXPLORING, AIMING }
var state: PlayerState = PlayerState.EXPLORING

# This holds all direct player script!
# The camera is controlled by its own script!

@export var camera_pivot: Node3D                     # Set this to CameraRig in Main.tscn
@export var rotation_lerp_speed: float = 10.0        # How fast the mesh turns toward movement

# --- Disc throw settings ---
@export var throw_min_power: float = 0.5
@export var throw_max_power: float = 2.5
@export var charge_speed: float = 1.5

var current_power: float = 0.0
var charging: bool = false

const SPEED := 5.0
const JUMP_VELOCITY := 4.5

var held_disc: Node3D = null
var held_disc_layer: int = 0
var held_disc_mask: int = 0

@onready var anim_player: AnimationPlayer = $godot_plush_model/AnimationPlayer
@onready var disc_socket: Node3D = $godot_plush_model/DiscSocket

var held_visual: Node3D = null
@export var disc_scene: PackedScene              # Disc.tscn
@export var held_visual_scene: PackedScene       # HeldDiscVisual.tscn
@export var selected_disc: DiscData              # currently equipped (later comes from backpack)

@onready var trajectory_mesh: MeshInstance3D = $TrajectoryMesh
var trajectory_immediate := ImmediateMesh.new()
var trajectory_material := StandardMaterial3D.new()
@export var prediction_steps: int = 40
@export var prediction_dt: float = 0.05
@export var prediction_collision_mask: int = 1

@export var prediction_forward_offset: float = 0.6
@export var prediction_up_offset: float = 0.1

@onready var aim_pivot: Node3D = $AimPivot

@export var aim_yaw_sens: float = 0.003
@export var aim_pitch_sens: float = 0.003
@export var aim_pitch_min: float = deg_to_rad(-30)
@export var aim_pitch_max: float = deg_to_rad(25)

var aim_yaw: float = 0.0
var aim_pitch: float = 0.0

func _ready() -> void:
	trajectory_mesh.mesh = trajectory_immediate
	trajectory_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trajectory_material.no_depth_test = true
	trajectory_mesh.top_level = true
	trajectory_mesh.global_transform = Transform3D.IDENTITY
	trajectory_mesh.mesh = trajectory_immediate
	trajectory_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trajectory_material.no_depth_test = true

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- EXPLORING (normal movement) ---
	if state == PlayerState.EXPLORING:
		# Jump
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Movement input
		var input_dir: Vector2 = Input.get_vector("Move_Left", "Move_Right", "Move_Backward", "Move_Forward")
		var move_direction: Vector3 = Vector3.ZERO

		if input_dir.length() > 0.0:
			# Camera-relative movement
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
				forward = -global_transform.basis.z
				forward.y = 0.0
				forward = forward.normalized()

				right = global_transform.basis.x
				right.y = 0.0
				right = right.normalized()

			move_direction = (right * input_dir.x + forward * input_dir.y).normalized()

			velocity.x = move_direction.x * SPEED
			velocity.z = move_direction.z * SPEED

			# Run animation
			if is_on_floor() and velocity.y <= 0.0:
				if anim_player.current_animation != "run":
					anim_player.play("run")

			# Rotate mesh toward movement
			if move_direction.length_squared() > 0.0:
				var target_rot_y: float = atan2(move_direction.x, move_direction.z)
				
				#Root Rotation
				var rot: Vector3 = rotation
				rot.y = lerp_angle(rot.y, target_rot_y, clampf(rotation_lerp_speed * delta, 0.0, 1.0))
				rotation = rot
				
				#Mesh Rotation
				var mesh_rot: Vector3 = $godot_plush_model.rotation
				mesh_rot.y = 0.0
				$godot_plush_model.rotation = mesh_rot
		else:
			# Decelerate
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

			if anim_player.current_animation == "run" and velocity.length_squared() <= 10.0:
				anim_player.play("idle")

	# --- AIMING (throw mode) ---
	elif state == PlayerState.AIMING:
		# No horizontal movement while aiming
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

		# Keep held disc at socket
		if is_instance_valid(held_disc) and is_instance_valid(disc_socket):
			held_disc.global_transform = disc_socket.global_transform

		# Handle charge
		if charging:
			current_power = min(current_power + charge_speed * delta, throw_max_power)
	if state == PlayerState.AIMING:
		_update_trajectory_preview()
	else:
		_clear_trajectory()


	# --- Apply movement ---
	move_and_slide()

	# --- Input that doesn't depend on state ---
	_handle_throw_mode_input()
	_handle_throw_input()

func _handle_throw_mode_input() -> void:
	# E toggles throwing/aim mode
	if Input.is_action_just_pressed("throw_mode"):
		if state == PlayerState.EXPLORING:
			_enter_throw_mode()
		elif state == PlayerState.AIMING and !charging:
			_exit_throw_mode(true) # cancel if not charging/throwing

func _handle_throw_input() -> void:
	if state != PlayerState.AIMING:
		return

	# Left mouse (or whatever you bind) controls power & throw
	if Input.is_action_just_pressed("throw_disc"):
		charging = true
		current_power = throw_min_power

	elif Input.is_action_just_released("throw_disc") and charging:
		charging = false
		_perform_throw()

func _enter_throw_mode() -> void:
	if held_visual_scene == null:
		push_warning("No held_visual_scene assigned on Player!")
		return
	if disc_scene == null:
		push_warning("No disc_scene assigned on Player! (should be Disc.tscn)")
		return
	if selected_disc == null:
		push_warning("No selected_disc assigned!")
		return
	if !is_instance_valid(disc_socket):
		push_error("DiscSocket is invalid!")
		return

	state = PlayerState.AIMING
	charging = false
	current_power = 0.0

	# Spawn ghost disc in the hand (visual only)
	held_visual = held_visual_scene.instantiate()
	disc_socket.add_child(held_visual)
	held_visual.transform = Transform3D.IDENTITY

	# Apply disc visuals/stats (if your held visual supports it)
	if held_visual.has_method("apply_data"):
		held_visual.call("apply_data", selected_disc)

	# Tell camera to go aim mode + focus on the socket (if supported)
	if is_instance_valid(camera_pivot):
		if camera_pivot.has_method("set_aim_focus"):
			camera_pivot.call("set_aim_focus", disc_socket)
		if camera_pivot.has_method("set_throw_mode"):
			camera_pivot.call("set_throw_mode", true)
	
	_update_trajectory_preview()
	if state == PlayerState.AIMING:
		_update_trajectory_preview_debug()
	else:
		_clear_trajectory()

func _exit_throw_mode(cancel: bool) -> void:
	state = PlayerState.EXPLORING
	charging = false
	current_power = 0.0

	# Remove ghost disc
	if is_instance_valid(held_visual):
		held_visual.queue_free()
	held_visual = null

	# Restore camera view
	if is_instance_valid(camera_pivot) and camera_pivot.has_method("set_throw_mode"):
		camera_pivot.call("set_throw_mode", false)
	_clear_trajectory()

func _perform_throw() -> void:
	if selected_disc == null:
		push_warning("No selected_disc assigned!")
		return
	if disc_scene == null:
		push_warning("No disc_scene assigned (should be Disc.tscn)!")
		return
	if !is_instance_valid(disc_socket):
		push_warning("DiscSocket invalid on throw.")
		return
	if !is_instance_valid(camera_pivot):
		push_warning("Camera pivot missing on throw.")
		return

	# Remove held visual (ghost disc) if you have one
	if is_instance_valid(held_visual):
		held_visual.queue_free()
	held_visual = null

	var direction := _get_aim_direction()

	var disc := disc_scene.instantiate()
	get_tree().current_scene.add_child(disc)

	# Spawn slightly forward/up from socket
	var spawn_pos := disc_socket.global_position + direction * 0.6 + Vector3.UP * 0.1
	disc.global_position = spawn_pos

	# Align disc to face the throw direction (helps feel + consistency)
	disc.global_basis = Basis.looking_at(direction, Vector3.UP)

	# Safety reset
	if disc is RigidBody3D:
		disc.linear_velocity = Vector3.ZERO
		disc.angular_velocity = Vector3.ZERO

	# Apply data then throw
	disc.apply_data(selected_disc)

	# Optional self-collision ignore (guarded)
	if disc.has_method("ignore_body_for_seconds"):
		disc.call("ignore_body_for_seconds", self, 0.15)

	disc.throw_disc(direction, current_power)
	_exit_throw_mode(true)
		
	if disc is RigidBody3D:
		# ignore the player body briefly so it doesn't smack off you
		disc.call("ignore_body_for_seconds", self, 0.15)

func _on_disc_landed() -> void:
	print("Disc has landed!")

func _remove_held_visual() -> void:
	if held_visual:
		held_visual.queue_free()
		held_visual = null

func _spawn_and_throw_real_disc(power: float) -> void:
	var disc = disc_scene.instantiate() # MidRangeDisc.tscn (RigidBody3D)
	get_tree().current_scene.add_child(disc)
	disc.global_transform = disc_socket.global_transform

	var direction: Vector3 = -camera_pivot.global_transform.basis.z
	disc.call("throw_disc", direction, power)

func _clear_trajectory() -> void:
	trajectory_immediate.clear_surfaces()

func _draw_trajectory(points: PackedVector3Array) -> void:
	trajectory_immediate.clear_surfaces()
	if points.size() < 2:
		return

	trajectory_immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, trajectory_material)
	for p in points:
		trajectory_immediate.surface_add_vertex(p)
	trajectory_immediate.surface_end()

func _apply_disc_preview_forces(vel: Vector3, data: DiscData, dt: float) -> Vector3:
	var speed: float = vel.length()
	if speed < 0.1:
		return vel

	var vel_dir: Vector3 = vel / speed
	var mass: float = max(data.mass, 0.01)

	# Drag
	var drag_accel: Vector3 = (-vel_dir * (data.drag_coeff * speed * speed)) / mass

	# Lift (capped like Disc.gd)
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var weight: float = mass * g
	var raw_lift: float = data.lift_coeff * data.glide * speed * speed
	var capped_lift: float = min(raw_lift, weight * 0.8)
	var lift_accel: Vector3 = (Vector3.UP * capped_lift) / mass

	# Safe right dir (prevents NaN randomness)
	var right_raw: Vector3 = vel_dir.cross(Vector3.UP)
	if right_raw.length() < 0.0001:
		right_raw = vel_dir.cross(Vector3.FORWARD)
	var right_dir: Vector3 = right_raw.normalized()

	# Turn/Fade oppose (turn - fade)
	var t: float = clamp(speed / 25.0, 0.0, 1.0)
	var turn_component: float = (-float(data.turn)) * (t * t)
	var fade_component: float = (float(data.fade)) * ((1.0 - t) * (1.0 - t))
	var side_scalar: float = (turn_component - fade_component) * float(data.spin_dir)

	var side_accel: Vector3 = (right_dir * side_scalar * (data.side_coeff * speed * speed)) / mass

	return vel + (drag_accel + lift_accel + side_accel) * dt

func _update_trajectory_preview() -> void:
	if state != PlayerState.AIMING:
		_clear_trajectory()
		return
	if selected_disc == null:
		_clear_trajectory()
		return
	if !is_instance_valid(disc_socket):
		_clear_trajectory()
		return

	var dir: Vector3 = _get_aim_direction()

	# Use a stable preview power even before charging
	var preview_power: float = current_power
	if preview_power <= 0.0:
		preview_power = throw_min_power  # or 1.0

	# Start position must match your real throw spawn
	var pos: Vector3 = disc_socket.global_position + dir * prediction_forward_offset + Vector3.UP * prediction_up_offset

	# Match impulse-to-velocity approximation (same disc uses apply_central_impulse)
	var mass: float = max(selected_disc.mass, 0.01)
	var impulse_mag: float = selected_disc.base_impulse * preview_power
	var vel: Vector3 = dir * (impulse_mag / mass)

	# Physics-consistent dt improves match
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)

	var space_state := get_world_3d().direct_space_state
	var pts := PackedVector3Array()
	pts.append(pos)

	# Gravity
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var g_dir: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var gravity: Vector3 = g_dir * g

	for i in range(prediction_steps):
		var prev := pos

		vel += gravity * dt
		vel = _apply_disc_preview_forces(vel, selected_disc, dt)

		pos += vel * dt

		# Raycast to stop at ground hit
		var query := PhysicsRayQueryParameters3D.create(prev, pos, prediction_collision_mask, [self])
		var hit := space_state.intersect_ray(query)
		if hit.size() > 0:
			pts.append(hit.position)
			break

		pts.append(pos)

	_draw_trajectory(pts)

func _unhandled_input(event: InputEvent) -> void:
	if state != PlayerState.AIMING:
		return
	if event is InputEventMouseMotion:
		aim_yaw -= event.relative.x * aim_yaw_sens
		aim_pitch = clamp(aim_pitch - event.relative.y * aim_pitch_sens, aim_pitch_min, aim_pitch_max)

		aim_pivot.global_position = disc_socket.global_position
		aim_pivot.global_rotation = Vector3(0, aim_yaw, 0)
		aim_pivot.rotate_object_local(Vector3.RIGHT, aim_pitch)

func _get_aim_direction() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		push_warning("No active Camera3D found!")
		return -global_transform.basis.z

	var dir := -cam.global_transform.basis.z
	# Optional: clamp extreme up/down while tuning
	# dir.y = clamp(dir.y, -0.35, 0.35)
	return dir.normalized()

func _update_trajectory_preview_debug() -> void:
	var dir := _get_aim_direction()
	var start := disc_socket.global_position + dir * 0.6 + Vector3.UP * 0.1
	var end := start + dir * 20.0

	var pts := PackedVector3Array([start, end])
	_draw_trajectory(pts)
