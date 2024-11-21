extends Node

signal player_connected(peer_id, player_info)
signal server_disconnected

# Scenario Manager / Encounter
signal encounter_timer_start
signal encounter_tracker_changed

# Environment Instance Root 
signal environment_ignore_add
signal environment_ignore_remove

###############
# NOTE: Keeping environment tracker changed on the parent of the instancer, not here, as they are naturally grouped.
# signal environment_tracker_changed
###############

signal equipment_is_using
signal coin
signal debug_spawn_new_enemy


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

func get_cart() -> Node3D:
	return environment_container.get_node("Cart")
	
func add_coins(amount):
	add_coins_sync.rpc(amount)
	
@rpc("authority", "call_remote")
func add_coins_sync(amount):
	coin.emit(amount)

@rpc('any_peer')
func debug_spawn_new_enemy_sync():
	debug_spawn_new_enemy.emit()
