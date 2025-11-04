extends RigidBody3D

signal disc_landed

@export var base_speed: float = 10.0
@export var drag: float = 0.95
@export var min_speed_to_stop: float = 1.0

var has_been_thrown: bool = false

func throw_disc(direction: Vector3, power: float) -> void:
	has_been_thrown = true
	apply_central_impulse(direction.normalized() * base_speed * power)

func _physics_process(delta: float) -> void:
	if has_been_thrown:
		# Apply drag
		linear_velocity *= drag

		# Check if it’s basically stopped
		if linear_velocity.length() < min_speed_to_stop:
			has_been_thrown = false
			emit_signal("disc_landed")
