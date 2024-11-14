extends Node

signal player_connected(peer_id, player_info)
signal server_disconnected

# Scenario Manager / Encounter
signal encounter_timer_start
signal encounter_tracker_changed

# Environment Instance Root 
signal environment_ignore_add
signal environment_ignore_remove
# NOTE: Keeping environment tracker changed on the parent of the instancer, not here.
# signal environment_tracker_changed


# Nodes for spawning
# Remember to add new Scenes to the Auto Spawn List
var environment_container: Node3D
var players_container: Node3D
var enemies_container: Node3D
	
func get_player(player_id: int):
	for player in players_container.get_children():
		if player.name == str(player_id):
			return player

func get_player_by_name(player_name: StringName):
	for player in players_container.get_children():
		if player.name == player_name:
			return player

func get_cart():
	return environment_container.get_node("Cart")
