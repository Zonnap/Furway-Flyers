extends Resource
class_name DiscData

enum DiscClass { PUTTER, MIDRANGE, DRIVER, ROLLER }

@export var disc_name: String = "Unnamed Disc"
@export var disc_class: DiscClass = DiscClass.MIDRANGE

# Disc golf-ish stats (you can interpret these however you want)
@export var speed: float = 5.0
@export var glide: float = 5.0
@export var turn: float = 0.0
@export var fade: float = 2.0

@export var mass: float = 0.175                # kg-ish (disc golf disc ~175g)
@export var drag_coeff: float = 0.015          # aerodynamic drag strength
@export var lift_coeff: float = 0.020          # aerodynamic lift strength
@export var side_coeff: float = 0.00005          # turn/fade lateral strength
@export var spin_dir: int = 1                  # +1 or -1 (handedness/spin direction)

# Physics tuning knobs
@export var base_impulse: float = 3.2     # “how hard it wants to go”
@export var drag: float = 0.98             # slows down over time
@export var lift: float = 0.15             # (optional later) upward force factor
@export var spin: float = 1.0              # (optional later) stability factor

# Visuals
@export var mesh: Mesh                     # assign a Mesh resource
@export var material: Material             # optional override
@export var icon: Texture2D                # for backpack UI
func _process(delta: float) -> void:
	pass
