extends Node

const enemy_scene := preload('res://enemy/enemy_base_root_motion.tscn')

# Called when the node enters the scene tree for the first time.
func _ready():
	if multiplayer.is_server():
		print('DEBUG', )
		await get_tree().create_timer(5.0).timeout
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = Vector3(5.0, 2.0, 5.0)
