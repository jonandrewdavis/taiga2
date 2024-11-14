extends CharacterBody3D

@export var group_name :String = "targets"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var nav_agent_3d = $NavigationAgent3D
@onready var animation_tree = $AnimationTree
@onready var anim_length = .5

@export var speed :float = 4.0
@onready var direction : Vector3 = Vector3.ZERO

@export var target_sensor : Area3D 
@export var target : Node3D
## Use for pathfinding, it will return to following this default target after
## giving up a chase. Most commonly this is a pathfollow node, following a Path.
## if left blank, then the default target is simply the same locationw here this
## enemy spawns.
@export var health_system : HealthSystem

@export var default_target : Node3D
@onready var spawn_location : Marker3D = Marker3D.new()
@export var combat_range :float = 2
@onready var combat_timer : Timer = $CombatTimer
@onready var chase_timer = $ChaseTimer

@onready var hurt_cool_down = $HurtTimer
@onready var ragdoll_death :bool = false
@onready var general_skeleton = $vampire/GeneralSkeleton

signal hurt_started
signal damage_taken
signal parried_started
signal death_started
signal attack_started
signal retreat_started

# Added multiplayer for this
@export var current_state = state.FREE : set = update_current_state # Enemy states controlled by enum PlayerStates
enum state {
	FREE,
	CHASE,
	COMBAT,
	ATTACK,
	DEAD,
	CIRCLE
}
signal state_changed

func _enter_tree() -> void:
	set_multiplayer_authority(1)

@export var network_randi_seed = 1

func _ready():
	seed(network_randi_seed)

	if animation_tree:
		animation_tree.animation_measured.connect(_on_animation_measured)
	
	hurt_cool_down.one_shot = true
	
	add_to_group(group_name)
	collision_layer = 5

	set_default_target()

	if health_system:
		health_system.died.connect(death)

	
	if is_multiplayer_authority():
		combat_timer.timeout.connect(_on_combat_timer_timeout)
		chase_timer.timeout.connect(_on_chase_timer_timeout)

		if target_sensor:
			target_sensor.target_spotted.connect(_on_target_spotted)
			target_sensor.target_lost.connect(_on_target_lost)
		
		
		
		
func _process(delta):
	if not is_multiplayer_authority():
		return

	apply_gravity(delta)
	if current_state == state.DEAD:
		return
	rotate_character()
	navigation()
	free_movement(delta)
	if current_state != state.CIRCLE:
		evaluate_state()
	
func free_movement(delta):
	#set_quaternion(get_quaternion() * animation_tree.get_root_motion_rotation())
	var rate : float # imiates directional change acceleration rate
	if is_on_floor():
		rate = .5
	else:
		rate = .1
	var new_velocity = get_quaternion() * animation_tree.get_root_motion_position() / delta

	if is_on_floor():
		velocity.x = move_toward(velocity.x, new_velocity.x, rate)
		velocity.y = move_toward(velocity.y, new_velocity.y, rate)
		velocity.z = move_toward(velocity.z, new_velocity.z, rate)
	else:
		velocity.x = move_toward(velocity.x, calc_direction().x * speed, rate)
		velocity.z = move_toward(velocity.z, calc_direction().z * speed, rate)
		
	move_and_slide()
		
func calc_direction() -> Vector3 :
	var new_direction = global_transform.basis.z
	return new_direction
	
func update_current_state(_new_state):
	current_state = _new_state
	state_changed.emit(_new_state)
	
	
	
# TODO: Tons of bugs in navigation
# TODO: Painful to strip y index everywhere. The default target is always above or below the mesh	
func navigation():
	if target:
		nav_agent_3d.target_position = target.global_position * Vector3(1.0,0,1.0)
		var new_dir = (nav_agent_3d.get_next_path_position() - global_position).normalized()
		new_dir *= Vector3(1,0,1) # strip the y value so enemy stays at current level
		direction = new_dir

		
func rotate_character():
	var rate = .05
	var new_direction = global_position.direction_to(nav_agent_3d.get_next_path_position() * Vector3(1,0,1))
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	var target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), rate)
	global_transform.basis = Basis(target_rotation)

func evaluate_state(): ## depending on distance to target, run or walk
	if target:
		if target == default_target:
			current_state = state.FREE
		else:
			if target:
				var current_distance = global_position.distance_to(target.global_position)
				if current_distance > combat_range:
					current_state = state.CHASE
				elif current_distance <= combat_range && current_state != state.COMBAT:
					current_state = state.COMBAT

func _on_combat_timer_timeout():
	if current_state == state.COMBAT && is_multiplayer_authority():
		combat_randomizer()
			
func combat_randomizer():
	if multiplayer.is_server():
		var random_choice = randi_range(1,20)
		if random_choice <= 4:
			retreat.rpc()
		if random_choice <= 8:
			circle.rpc()
		else:
			attack.rpc()

# Multiplayer: changed to RPCs so the emits activate the equipment.
@rpc("authority", "call_local")
func attack():
	attack_started.emit()

@rpc("authority", "call_local")
func retreat(): # Back away for a period of time
	retreat_started.emit()

@rpc("authority", "call_local")
func circle(): 
	animation_tree.attack_count = randi_range(1, 2)
	await get_tree().create_timer(.1).timeout 
	update_current_state(state.CIRCLE)
	await get_tree().create_timer(randi_range(2, 5)).timeout
	update_current_state(state.COMBAT)
	

func set_default_target(): 
	await get_tree().create_timer(.2).timeout
	$EnemyMarkerSpawn.global_position = global_position * Vector3(1.0, 0, 1.0)
	if not default_target:
		default_target = $EnemyMarkerSpawn
	if !target:
		target = default_target
			
			
func _target_to_player_node(_spotted_target: Node3D):
	for player in Hub.players_container.get_children():
		if player.name == _spotted_target.name:
			return player

func _on_target_spotted(_spotted_target): # Updates from a TargetSensor if a target is found.
	if target.name != _spotted_target.name:
		target = _spotted_target
	chase_timer.start()
	
# NOTE: Target lost can make it spin in circles in multiplayer.
# TODO: Restore.
func _on_target_lost():
	print('TARGET LOST')
	pass

func _on_chase_timer_timeout():
	give_up()
	
func give_up():
	await get_tree().create_timer(4).timeout
	target = default_target
	
func apply_gravity(_delta):
	if !is_on_floor():
		velocity.y -= gravity * _delta
		move_and_slide()


func hit(_by_who, _by_what):
	#var get_player_targeted = _target_to_player_node(_by_who)
	#if (get_player_targeted):
		#target = get_player_targeted
		#if hurt_cool_down.is_stopped():
			#hurt_cool_down.start()
			#hurt_started.emit()
			#damage_taken.emit(_by_what)
	if (_by_who.name && _by_what.power):
		hurt_cool_down.start()
		hurt_started.emit()
		hit_sync.rpc(_by_who.name, _by_what.power)

@rpc("any_peer")
func hit_sync(_by_who_name: String, power: int):
	if multiplayer.is_server():
		# During RPC, this is an EncodedObjectAsID, so if we're host, let's  instance_from_id before:
		var get_player_targeted = Hub.get_player_by_name(_by_who_name)
		if (get_player_targeted):
			target = get_player_targeted
			if hurt_cool_down.is_stopped():
				hurt_cool_down.start()
				hurt_started.emit()
				damage_taken.emit(power)

func parried():
	if hurt_cool_down.is_stopped():
		hurt_cool_down.start()
		parried_started.emit()

func death():
	update_current_state(state.DEAD)
	hurt_cool_down.start(10)
	death_sync.rpc()
	# Note: always queue_free on the server. - AD
	await get_tree().create_timer(4).timeout
	if multiplayer.is_server():
		queue_free()
		
@rpc("any_peer", "call_local")
func death_sync():
	update_current_state(state.DEAD)
	remove_from_group(group_name)
	if ragdoll_death:
		apply_ragdoll()
	else:
		death_started.emit()

# TODO: Ragdoll on the clients
func apply_ragdoll():
	general_skeleton.physical_bones_start_simulation()
	animation_tree.active = false
	
	# if you want to stop the rag doll after a few seconds, uncomment this code.
	await get_tree().create_timer(3).timeout
	var bone_transforms = []
	var bone_count = general_skeleton.get_bone_count()
	for i in bone_count:
		bone_transforms.append(general_skeleton.get_bone_global_pose(i))
	general_skeleton.physical_bones_stop_simulation()
	for i in bone_count:
		general_skeleton.set_bone_global_pose_override(i, bone_transforms[i],1,true)

func _on_animation_measured(_new_length):
	anim_length = _new_length - .05 # offset slightly for the process frame
