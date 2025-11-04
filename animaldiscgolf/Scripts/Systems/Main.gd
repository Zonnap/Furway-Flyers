extends Node3D

@onready var level: Node3D = $TestingDGC
@onready var player: Node3D = $Player
@onready var camera_rig: Node3D = $CameraRig

func _ready() -> void:
	_spawn_player_at_level_spawn()
	camera_rig.target = player   # you already had this, just keep it here


func _spawn_player_at_level_spawn() -> void:
	# Adjust this path if PlayerSpawn is nested (e.g. "SpawnPoints/PlayerSpawn")
	var spawn: Node3D = level.get_node_or_null("PlayerSpawn")
	if spawn == null:
		push_error("PlayerSpawn not found in Level scene!")
		return

	# Option 1: copy full transform (position + facing direction)
	player.global_transform = spawn.global_transform

	# If your player uses CharacterBody3D and you prefer setting components:
	# player.global_transform.origin = spawn.global_transform.origin
	# player.global_rotation = spawn.global_rotation
