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
signal debug_kill_all_enemies

const HEIGHTMAP = preload('res://assets/environment/heightmap_grass_main.tres')

# Nodes for spawning
# Remember to add new Scenes to the Auto Spawn List
var environment_container: Node3D
var players_container: Node3D
var enemies_container: Node3D

var world_environment: WorldEnvironment
var forest_sun: DirectionalLight3D

const player_scene = preload("res://player/player_charbody3d.tscn")


func get_player(player_id: int):
	for player in players_container.get_children():
		if player.name == str(player_id):
			return player

func get_player_by_name(player_name: StringName):
	for player in players_container.get_children():
		if player.name == player_name:
			return player

func get_random_player():
	var count_up = 0
	var roll_for_player = randi_range(0, players_container.get_children().size() - 1)
	for player in players_container.get_children():
		if count_up == roll_for_player:
			return player
		else:
			count_up = count_up + 1

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

@rpc('any_peer')
func debug_kill_all_enemies_sync():
	if multiplayer.is_server():
		for enemy in enemies_container.get_children():
			if enemy.global_position.distance_to(enemy.target.global_position) > 120.0:
				enemy.queue_free()			

func get_environment_root() -> Node3D:
	return environment_container.get_node("EnvironmentInstanceRoot")

# TODO: Ambitious way to reset the player.... but bug prone.

#@rpc('any_peer')
#func _remove_player(id):
	#if not multiplayer.is_server() or not players_container.has_node(str(id)):
		#return
	#var player_node = players_container.get_node(str(id))
	#if player_node:
		#player_node.queue_free()
	#
	#await get_tree().create_timer(5).timeout	
	#_add_player_as_respawn.rpc(id)
#
#@rpc("any_peer", "call_local")
#func _add_player_as_respawn(id: int):
	#if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1:
		#return
	#
	#var player = player_scene.instantiate()
	#player.name = str(id)
	#players_container.add_child(player, true)
#
	#var nick = Network.players[id]["nick"]
	#player.rpc("change_nick", nick)
	#
	#player.global_position = Vector3(3.0, 3.0, 3.0)
	#
	#get_environment_root().environment_tracker_changed.emit(player)
