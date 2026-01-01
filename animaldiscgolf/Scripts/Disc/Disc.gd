extends RigidBody3D

@export var data: DiscData
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

var has_been_thrown := false

func apply_data(d: DiscData) -> void:
	data = d
	if data == null:
		return

	# visual
	if mesh_instance:
		if data.mesh:
			mesh_instance.mesh = data.mesh
		if data.material:
			mesh_instance.material_override = data.material

	# physics
	mass = data.mass


func throw_disc(direction: Vector3, power: float) -> void:
	if data == null:
		push_warning("Disc has no DiscData assigned")
		return

	has_been_thrown = true
	apply_central_impulse(direction.normalized() * data.base_impulse * power)


func _physics_process(delta: float) -> void:
	if !has_been_thrown or data == null:
		return

	var v: Vector3 = linear_velocity
	var speed := v.length()
	if speed < 0.1:
		return

	var vel_dir := v / speed

	# --- Drag (slows along velocity) ---
	var drag_force := -vel_dir * (data.drag_coeff * speed * speed)

	# Weight (downward force from gravity)
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var weight: float = mass * g  # Newtons-ish

	# Lift (capped so it can never exceed gravity)
	var raw_lift: float = data.lift_coeff * data.glide * speed * speed
	var capped_lift: float = min(raw_lift, weight * 0.8)  # max 80% of weight
	var lift_force: Vector3 = Vector3.UP * capped_lift

	# --- Turn/Fade lateral curve ---
	# Turn happens more at high speed, fade more at low speed.
	# Normalize speed into [0..1] range for blending
	var t: float = clamp(speed / 25.0, 0.0, 1.0)
	var turn_strength: float = (-float(data.turn)) * (t * t)
	var fade_strength: float = (float(data.fade)) * ((1.0 - t) * (1.0 - t))

	# Right direction relative to flight
	var right_dir := vel_dir.cross(Vector3.UP).normalized()
	var side_force := right_dir * data.spin_dir * (turn_strength + fade_strength) * (data.side_coeff * speed * speed)

	apply_central_force(drag_force + lift_force + side_force)
	
func ignore_body_for_seconds(body: CollisionObject3D, seconds: float) -> void:
	if body == null:
		return
	add_collision_exception_with(body)
	await get_tree().create_timer(seconds).timeout
	remove_collision_exception_with(body)
