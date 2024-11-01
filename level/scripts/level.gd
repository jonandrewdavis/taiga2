extends Node3D

@onready var skin_input: LineEdit = $Menu/MainContainer/MainMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $Menu/MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $Menu/MainContainer/MainMenu/Option3/AddressInput
@onready var players_container: Node = $PlayersContainer
@onready var menu: Control = $Menu
@export var player_scene: PackedScene

const environment_instance_root_scene = preload("res://assets/environment_instances/environment_instance_root.tscn")
const enemy_scene = preload('res://enemy/enemy_base_root_motion.tscn')
const cart_scene = preload("res://assets/interactable/medieval_carriage/cart.tscn")

const environment_arena_scene = preload("res://level/scenes/arena.tscn")


func _ready():
	# Check for -- server
	var args = OS.get_cmdline_user_args()
	for arg in args:
		var key_value = arg.rsplit("=")
		match key_value[0]:
			"server":
				print('DEBUG: SERVER STARTING `-- server` found')
				_on_host_pressed()

	# We're a client
	if not multiplayer.is_server():
		return
		
	Hub.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)
	Hub.players_container = $PlayersContainer
	Hub.enemies_container = $EnemiesContainer


func _spawn_enemy(): 
	await get_tree().create_timer(5.0).timeout
	print('DEBUG: ONE ENMEY SPAWN')
	var enemy = enemy_scene.instantiate()
	enemy.network_randi_seed = 123 + $EnemiesContainer.get_children().size()
	$EnemiesContainer.add_child(enemy, true) 

	enemy.global_position = get_spawn_point()

func _on_player_connected(peer_id, player_info):
	for id in Network.players.keys():
		var _player_data = Network.players[id]
		#if id != peer_id:
			# These are client only syncs, to set player properties.
			#rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
			#rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
				
	_add_player(peer_id, player_info)

	
func _on_host_pressed():
	menu.hide()
	Network.start_host()

	#_spawn_enemy()
	#_spawn_enemy()
	#_spawn_enemy()
	#_spawn_enemy()
	#_spawn_enemy()
	#_spawn_enemy()

	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, true)

func _on_join_pressed():
	menu.hide()
	Network.join_game(nick_input.text.strip_edges(), skin_input.text.strip_edges(), address_input.text.strip_edges())
	
func _add_player(id: int, player_info : Dictionary):
	# Skip a lot of nodes
	if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1:
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	var skin_name = player_info["skin"]
	rpc("sync_player_skin", id, skin_name)
	
	rpc("sync_player_position", id, player.position)
	
	rpc_id(id, "sync_player_client_only_nodes", id)
	
	add_server_only_nodes()


func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 5.0, spawn_point.y)
	
func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()
		
@rpc("any_peer", "call_local")
func sync_player_position(id: int, new_position: Vector3):
	var player = players_container.get_node(str(id))
	if player:
		player.position = new_position
		# TODO: Proper loading signal / bus for users to load their scenery.
		#$EnvironmentInstanceRoot.set_new_root(player)
		
@rpc("any_peer", "call_local")
func sync_player_skin(_id: int, skin_name: String):
	return skin_name
	#if id == 1: return # ignore host
	#var player = players_container.get_node(str(id))
	#if player:
		#environment_instance.environment_root_tracker = player
		#player.set_player_skin(skin_name)
	
func _on_quit_pressed() -> void:
	get_tree().quit()
	

# Prepare client only nodes.
@rpc("any_peer", "call_local")
func sync_player_client_only_nodes(peer_id):
	var prepare_environment = environment_arena_scene.instantiate()
	#var prepare_environment = environment_instance_root_scene.instantiate()
	add_child(prepare_environment)
	#prepare_environment.environment_tracker_changed.emit(Hub.get_player(peer_id)) 


func add_server_only_nodes():
	var cart = cart_scene.instantiate()
	var prepare_environment = environment_arena_scene.instantiate()
	#var prepare_environment = environment_instance_root_scene.instantiate()
	$EnvironmentContainer.add_child(cart)
	add_child(prepare_environment)
	#prepare_environment.environment_tracker_changed.emit(cart) 
	cart.get_node("CartCam").current = true
