extends Node

const SERVER_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 9999
const MAX_PLAYERS : int = 10

var players = {}
var player_info = {
	"nick" : "host",
	"skin" : "blue"
}

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_connection_failed)
	multiplayer.connection_failed.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

func start_host():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, MAX_PLAYERS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
func join_game(nickname: String, skin_color: String, address: String = SERVER_ADDRESS):
	var peer = ENetMultiplayerPeer.new()
	var error
	if address != '':
		error = peer.create_client(address, SERVER_PORT)
	else:
		error = peer.create_client(SERVER_ADDRESS, SERVER_PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	if !nickname:
		nickname = "Player_" + str(multiplayer.get_unique_id())
	if !skin_color:
		skin_color = "blue"
	player_info["nick"] = nickname
	player_info["skin"] = skin_color
	return OK
	
func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	Hub.player_connected.emit(peer_id, player_info)
	
func _on_player_connected(id):
	#
	#if !nickname:
		#nickname = "Player_" + str(multiplayer.get_unique_id())
	player_info["nick"] = "Player_" + str(multiplayer.get_unique_id())
	_register_player.rpc_id(id, player_info)
	
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	Hub.player_connected.emit(new_player_id, new_player_info)
	print("NetworkL _register_player ", players)
	
func _on_player_disconnected(id):
	players.erase(id)
	
func _on_connection_failed():
	multiplayer.multiplayer_peer = null
	get_tree().quit()

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	Hub.server_disconnected.emit()
	
