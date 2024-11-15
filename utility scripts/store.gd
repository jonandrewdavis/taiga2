extends Area3D


## EQUIPMENT
var shield_scene = preload("res://player/equipment_system/equipment/shield.tscn")
## EQUIPMENT


func _ready():
	add_to_group("interactable")
	collision_layer = 9


func activate(_activated_player: CharacterBody3D):
	var gadgets: EquipmentSystem = _activated_player.get_node("GadgetSystem")
	var SHIELD = shield_scene.instantiate()
	gadgets.held_mount_point.add_child(SHIELD)
	gadgets.current_equipment = SHIELD
	print('_activated_player', _activated_player)
