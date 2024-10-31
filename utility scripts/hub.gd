extends Node

signal player_connected(peer_id, player_info)
signal server_disconnected

var players_container: Node
var enemies_container: Node

func get_player(player_id: int):
	for player in players_container.get_children():
		if player.name == str(player_id):
			return player

func get_player_by_name(player_name: StringName):
	for player in players_container.get_children():
		if player.name == player_name:
			return player
