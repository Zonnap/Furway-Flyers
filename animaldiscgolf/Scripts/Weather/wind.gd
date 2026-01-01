extends GPUParticles3D


@onready var target = $"../../Player"
@export var follow_speed = 5.0

var enabled = self.emitting

func _ready():
	self.rotation.y = randf_range(0, TAU)
	self.amount_ratio = randf_range(0.0, 1.0)
	print("ROT", self.rotation.y)
	print("AMOUNT", self.amount_ratio)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.position, follow_speed * delta)
	
