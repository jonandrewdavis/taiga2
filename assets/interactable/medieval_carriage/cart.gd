extends RigidBody3D


@export var replicated_position : Vector3
@export var replicated_rotation : Vector3
@export var replicated_linear_velocity : Vector3
@export var replicated_angular_velocity : Vector3

var speed: float = 0.1
var player_attached: CharacterBody3D = null

var cart_speed = 5.0

func _enter_tree():
	set_multiplayer_authority(1)

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("interactable")
	collision_layer = 9

func _integrate_forces(state):
	if is_multiplayer_authority():

		if not player_attached:
			return

		var target_position = player_attached.global_transform.origin

		var forward_local_axis: Vector3 = Vector3(1, 0, 0)
		var forward_dir: Vector3 = (basis * forward_local_axis).normalized()
		var target_dir: Vector3 = (target_position - transform.origin).normalized()
		var local_speed: float = clampf(speed, 0, acos(forward_dir.dot(target_dir)))
		if forward_dir.dot(target_dir) > 1e-4:
			state.angular_velocity = local_speed * forward_dir.cross(target_dir * Vector3(1.0, 0.2, 1.0)) / state.step / 2
			
		var distance_to_target = transform.origin.distance_to(target_position)
		if distance_to_target > 7.0:
			state.linear_velocity = 0.1 * target_dir / state.step
		elif distance_to_target > 5.5:
			state.linear_velocity = 0.05 * target_dir / state.step
		elif distance_to_target < 3.5:
			state.linear_velocity = 0.05 * -target_dir / state.step

		replicated_position = position
		replicated_rotation = rotation
		replicated_linear_velocity = state.linear_velocity
		replicated_angular_velocity = state.angular_velocity
	else:
		position = replicated_position
		rotation = replicated_rotation
		state.linear_velocity = replicated_linear_velocity
		state.angular_velocity = replicated_angular_velocity

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not multiplayer.is_server():
		return
	$CartCam.global_position = Vector3(global_position.x, $CartCam.global_position.y, global_position.z - 15.00)
	$CartCam.look_at(Vector3(global_position.x, 2.0,  global_position.z))
	
func activate(activated_player: CharacterBody3D):
	# Peer can request to attach.
	cart_player_sync.rpc()

	#var new_translation = global_transform.translated_local(player_offset).rotated_local(Vector3.UP,PI)
		#var tween = create_tween()
		#tween.tween_property(player,"global_transform", new_translation,.2)
		#await tween.finished
		#
		#if opened == false:
			#player.trigger_interact(interact_type)
			#await get_tree().create_timer(anim_delay).timeout
			#open_chest()
		
@rpc("any_peer", "reliable")
func cart_player_sync():
	if not is_multiplayer_authority():
		return
	var player_requesting = Hub.get_player(multiplayer.get_remote_sender_id())

	if not player_attached:
		var test_forward_local_axis: Vector3 = Vector3(1, 0, 0)
		var test_forward_dir: Vector3 = (basis * test_forward_local_axis).normalized()
		var test_dir_normal: Vector3 = (player_requesting.global_transform.origin - global_transform.origin).normalized()
		# Only allow if you are "Forward" from the front Axis
		print(test_dir_normal)
		if ((test_dir_normal.x > 0.0 && test_dir_normal.z < 0.0)  or (test_dir_normal.x > 0.0 && test_dir_normal.z > 0.0)):
			player_attached = player_requesting
			print('accepted')
	elif player_attached.name == player_requesting.name:
		player_attached = null
