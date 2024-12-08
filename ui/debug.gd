extends Control

@export var player: CharacterBody3D
@onready var debug_text_node = $MarginContainer/DebugText

# Called when the node enters the scene tree for the first time.
func _ready():
	player.open_debug.connect(_open_or_close_debug)

func _open_or_close_debug():
	if visible: 
		visible = false
	else:
		visible = true
	
		var encounters_count =	0
		for object in Hub.environment_container.get_children():
			if object.is_in_group('encounters'): encounters_count = encounters_count + 1

		var out_of_bounds = 0
		for enemy in Hub.enemies_container.get_children():
			if enemy.target != null && enemy.global_position.distance_to(enemy.target.global_position) > 100.0:
				enemy.queue_free()
				out_of_bounds = out_of_bounds + 1

		var text: Array[String] = [
			"Keys: K, 0, L,  ",
			"Player: " + str(Hub.players_container.get_child_count()),
			"Enemies: " + str(Hub.enemies_container.get_child_count()), 
			"Enemies (Out of bounds): " + str(out_of_bounds),
			"Encounters: " + str(encounters_count),
		]
		
		var text_with_p = []
		for item in text:
			text_with_p.append("[p]" + item + "[p]")
		
		debug_text_node.text = "".join(text_with_p)
