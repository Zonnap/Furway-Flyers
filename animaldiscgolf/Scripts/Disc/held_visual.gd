extends Node3D
@export var data: DiscData
@onready var disc_mesh: MeshInstance3D = $DiscMesh

func apply_data(d: DiscData) -> void:
	if d == null:
		return
	if d.mesh:
		disc_mesh.mesh = d.mesh
	if d.material:
		disc_mesh.material_override = d.materialaterial
