extends CharacterBody3D

# MULTIPLAYER TEMPLATE VARS
# MULTIPLAYER TEMPLATE VARS
@export var coins: int = 100

@onready var nickname: Label3D = $PlayerNick/Nickname

@export_category("Objects")
#@export var _body: Node3D = null
#@export var _spring_arm_offset: Node3D = null

# MULTIPLAYER TEMPLATE VARS
# MULTIPLAYER TEMPLATE VARS

@onready var sensor_cast : ShapeCast3D
@export var animation_tree : AnimationTree

# Mutliplayer : Exported - AD. for combo attacks
@export var anim_length = .5 # updates as new animnations start
signal event_finished
## default/1st camera is a follow cam.
@onready var current_camera = get_viewport().get_camera_3d()

## Aids strafe rotation when alternating between cameras. I found it best to keep
## track of whatever the starting camera was, rather than update it if camera's change.
@onready var orientation_target = current_camera

## Interactables that update based on entering a Ladder Area or, the sensor_cast
## colliding with an interactable.
@onready var interactable : Node3D

# Added this... -AD
@onready var interactable_custom : Node3D

@onready var ladder
signal climb_started
signal interact_started(interact_type)

## A generic EquipmentSystem class, used to manage moving Weapons 
## between a hand and sheathed location as well as activating collision hitbox 
## monitoring and reporting hits have happened. Very handy.
@export var weapon_system : EquipmentSystem

## A helper variable, tracks the current weapon type for easier referencing from
## the animation_tree and anywhere else that may want to know what weapon type is held.
var weapon_type :String = "SLASH"
signal weapon_change_started ## to start the animation
signal weapon_change_ended(weapon_type:String) ## informing the change is complete
signal attack_started ## to start the animation
signal attack_requested


## New stuff - AD
signal eyeline_check


## A helper variable for keyboard events across 2 key inputs "shift+ attack", etc.
## there may be a better way to capture combo key presses across multiple device types,
## but this worked for me in a pinch.
var secondary_action

## Gadgets and guarding equipment system that manages moving nodes from the 
## off-hand, to their hip location, the same EquipmentSystem as the weapon system.
@export var gadget_system : EquipmentSystem
## A helper variable, tracks the current gadget type for easier referencing from
## the AnimationStateTree or anywhere else that may need to know what gadget type is held.
@export var gadget_type :String = "SHIELD"
signal gadget_change_started ## to start the animation
signal gadget_change_ended(gadget_type:String) ## to end the animation
signal gadget_started ## when the gadget attack starts

@export var gadget_power = 0

## When guarding this substate is true. Drives animation and hitbox logic for blocking.
## The first moments of guarding, the parry window is active, allowing to parry()
## attacks and avoid damage


## Turns on when the perfect parry window is active, making regular blocks turn into parries.
@onready var parry_active = false
## How brief the perfect parry window is in seconds.
@export var parry_window = .3
signal parry_started
signal block_started

## The HealthSystem node that will take in information about damage and healing received.
@export var health_system : HealthSystem
@onready var hurt_cool_down = Timer.new() # while running, player can't be hurt
signal hurt_started # to start the animation
signal damage_taken(by_what:EquipmentObject) # to indicate the damage value
signal health_received(by_what:ItemObject) # CHANGED to just be power - AD
signal death_started
@export var is_dead :bool = false

@export var inventory_system : InventorySystem
var current_item : ItemResource
signal item_change_started
signal item_change_ended(current_item:ItemObject)
signal use_item_started
signal item_used

# Jump and Gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var jump_velocity = 7
@onready var last_altitude = global_position
@export var hard_landing_height :float = 4 # how far they can fall before 'hard landing'
signal landed_fall(hard_or_soft:String)
signal jump_started

## Dodge and Sprint Mechanics.
@onready var sprint_timer :Timer = Timer.new()
signal dodge_started
signal sprint_started

# Movement Mechanics
@export var input_dir : Vector2
@export var default_speed = 4.0
@onready var speed = default_speed

@export_category("PLAYER NETWORK EXPORTS")

# Strafing
@export var strafing :bool = false # substate - EXPORTED FOR MULTIPLAYER
@onready var strafe_cross_product = 0.0
@onready var move_dot_product = 0.0
signal strafe_toggled(toggle:bool)

# Laddering
signal ladder_started(top_or_bottom:String)
signal ladder_finished(top_or_bottom:String)

# State management
enum state {FREE,STATIC,CLIMB} 

#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER
#  EXPORTED FOR MULTIPLAYER

@export var busy : bool = false # substate: to prevent input spamming 
@export var guarding = false # substate
@export var sprinting : bool = false # substate
@export var dodging : bool = false # substate
@export var slowed : bool = false # substate:  force a slower walking speed

@export var current_state = state.FREE : set = change_state
signal changed_state(new_state: state)



# TODO: Enum? ADDED - AD 11/21/2024
var combo_enabled_weapons = ['SLASH', 'HEAVY']
var two_handed_weapons = ['HEAVY', 'BOW']

signal store_error
signal store_success

## MULTIPLAYER TEMPLATE FUNCS
## MULTIPLAYER TEMPLATE FUNCS

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

## MULTIPLAYER TEMPLATE FUNCS
## MULTIPLAYER TEMPLATE FUNCS


func _ready():
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: Replicated vars + rpc on `request_oneshot` should cover ALL cases.
	# NOTE: That means we can disable any signals if we're not authority.
	if not is_multiplayer_authority(): 
		return
	
	$GUI.hide()
		
	if animation_tree:
		animation_tree.animation_measured.connect(_on_animation_measured)
		
	if weapon_system:
		weapon_system.equipment_changed.connect(_on_weapon_equipment_changed)
		
	if gadget_system:
		gadget_system.equipment_changed.connect(_on_gadget_equipment_changed)
		
	if inventory_system:
		inventory_system.item_used.connect(_on_inventory_item_used)
			
	if health_system:
		health_system.died.connect(death)
		
	climb_started.connect(_on_climb_started)
	weapon_change_ended.connect(_hide_or_show_bow)
		
	nickname.visible = false

	$FollowCam.eyeline_enter.connect(_on_eyeline_enter)
	$FollowCam.eyeline_exit.connect(_on_eyeline_leave)

	add_child(sprint_timer)
	sprint_timer.one_shot = true
	
	hurt_cool_down.one_shot = true
	hurt_cool_down.wait_time = .5
	add_child(hurt_cool_down)

	if animation_tree:
		await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	current_state = state.FREE
	
	#weapon_change_ended.emit(weapon_type)
	
	Hub.coin.connect(get_coin)
	store_error.connect(_on_update_coin)
	store_success.connect(_on_update_coin)
	_on_update_coin()
	
	# TODO: Remove before launch
	DebugMenu.style = DebugMenu.Style.VISIBLE_COMPACT
	
	
	
## Makes variable changes for each state, primiarily used for updating movement speeds
func change_state(new_state):
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: Not required for basinc functioning, BUT: probably doesn't ever leave FREE.	
	if not is_multiplayer_authority():
		return

	current_state = new_state
	changed_state.emit(current_state)
	
	match current_state:
		state.FREE:
			speed = default_speed

		state.STATIC:
			speed = 0.0
			velocity = Vector3.ZERO
	
	# TODO: Add back ladders........................ - AD
	# Currently, we're disabling another way, on weapon change, to enforce a disadvantage on 2 handers.
	
	#if current_state == state.CLIMB:
		#system_visible(weapon_system,false)
		#system_visible(gadget_system,false)
	#else:
		#system_visible(weapon_system,true)
		#system_visible(gadget_system,true)
			
func _physics_process(_delta):
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: All 3 Required for all authorities because of "flying" bug.
	# TODO: Adding Ladders may just need everything here.
	if not is_multiplayer_authority():
		apply_gravity(_delta)
		fall_check()
		move_and_slide()
		return

	match current_state:
		state.FREE:
			rotate_player()
			
		state.CLIMB:
			set_root_climb(_delta)
			
	set_root_move(_delta)
	move_and_slide()
	apply_gravity(_delta)
	fall_check()
	out_of_bounds_check()
	
func out_of_bounds_check():
	if global_position.x > 500.0:
		global_position.x = -250.0
	elif global_position.x < -500.0:
		global_position.x = 250.0
	
func _input(_event:InputEvent):
	if not is_multiplayer_authority():
		return
	
		# Update current orientation to camera when nothing pressed
	if !Input.is_anything_pressed():
		current_camera = get_viewport().get_camera_3d()
	
	if _event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if is_dead:
		return

	## strafe toggle on/off
	if _event.is_action_pressed("strafe_target"):
		set_strafe_targeting()
		
	# a helper for keyboard controls, not really used for joypad
	if Input.is_action_pressed("secondary_action"):
		secondary_action = true
	else:
		secondary_action = false

	if _event.is_action_pressed("use_weapon_light"):
		emit_signal("attack_requested")
	
	if current_state == state.FREE:
		if _event.is_action_pressed("debug"):
			Hub.debug_spawn_new_enemy_sync.rpc()

		if _event.is_action_pressed("use_weapon_light"):
			attack()
		elif _event.is_action_pressed("use_weapon_strong"):
			attack_strong()
		if is_on_floor():
			# if interactable exists, activate its action
			if _event.is_action_pressed("interact"):
				interact()
			
			elif _event.is_action_pressed("jump"):
				jump()
				
			#elif _event.is_action_pressed("sprint"):
				#sprint()
				
			elif _event.is_action_pressed("dodge"):
				dodge()
			
			elif _event.is_action_pressed("change_primary"):
				weapon_change()
			elif _event.is_action_pressed("change_secondary"):
				gadget_change()

			elif _event.is_action_pressed("use_gadget_strong"):
				use_gadget()
					
			elif _event.is_action_pressed("use_gadget_light"):
				if two_handed_weapons.has(weapon_system.current_equipment.equipment_info.object_type):
					if weapon_type == "BOW":
						start_guard()
						return
				if secondary_action:
					use_gadget()
				elif gadget_type == "SHIELD":
					start_guard()
								
			elif _event.is_action_pressed("change_item"):
				item_change()
			elif _event.is_action_pressed("use_item"):
				use_item()
	
	elif current_state == state.CLIMB:
			#aiming = false
		if _event.is_action_pressed("interact"):
			abort_climb()
	
	if sprinting:
		if !input_dir:
			end_sprint()
		
		if _event.is_action_released("sprint"):
			end_sprint()
				
	if _event.is_action_released("use_gadget_light"):
		if not secondary_action:
			end_guard()

func apply_gravity(_delta):
	if !is_on_floor() \
	&& current_state != state.CLIMB:
		velocity.y -= gravity * _delta
		
func rotate_player():
	if busy && not dodging:
		return
	var rate = .15
	
	var target_rotation
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	# FreeCam rotation code, slerps to input oriented to the camera perspective, and only calculates when input is given
	if strafing:
		rate = .4
		# StrafeCam code - Look at target, slerping current rotation to the camera's rotation.
		target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, orientation_target.global_rotation.y + PI), rate)
		global_transform.basis = Basis(target_rotation)
		var new_direction = calc_direction().normalized()
		
		var forward_vector = global_transform.basis.z.normalized()
		strafe_cross_product = -forward_vector.cross(new_direction).y
		move_dot_product = forward_vector.dot(new_direction)
		return
	
	if input_dir:
		var new_direction = calc_direction().normalized()
		# Rotate the player per the perspective of the camera
		target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), rate)
		global_transform.basis = Basis(target_rotation)

func set_strafe_targeting():
	strafing = !strafing
	strafe_toggled.emit(strafing)
	
func _on_target_cleared():
	strafing = false

func attack_face_forward():
	var rate = 1.0
	var target_rotation
	var current_rotation = global_transform.basis.get_rotation_quaternion()
	var new_direction = calc_direction_based_on_camera().normalized()
	
	# Rotate the player per the perspective of the camera
	target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, orientation_target.global_rotation.y + PI), rate)
	global_transform.basis = Basis(target_rotation)
	
	var forward_vector = global_transform.basis.z.normalized()
	strafe_cross_product = -forward_vector.cross(new_direction).y
	move_dot_product = forward_vector.dot(new_direction)




# AD Notes:
# Lots of changes to attacking to enable combos and face forward on start.
# Signals still used to emit effects & enable weapons
func attack():
	if dodging or weapon_type == "OTHER":
		return
	attack_face_forward()
	if busy == true:
		return
	
	# Special case, bow can only be fired while a
	if weapon_type == "BOW":
		if guarding == true:
			busy = true
			animation_tree.request_oneshot("Attack")
			animation_tree.attack_once()
			$ArrowSystem.shoot()
			return	
		else:
			return	

	busy = true
	if not is_on_floor():
		animation_tree.request_oneshot("Attack")
		animation_tree.attack_air()
		return

	if sprinting:
		animation_tree.request_oneshot("Attack")
		animation_tree.attack_once()
		return

	if combo_enabled_weapons.has(weapon_type):
		animation_tree.attack_count = 1
		animation_tree.attack_chain()
	else:
		animation_tree.request_oneshot("Attack")
		animation_tree.attack_once()


# TODO: Implement
func attack_strong():
	pass
	#attack_face_forward()
	#if busy or dodging:
		#return
	#secondary_action = true
	#trigger_event("attack_started")
	#await attack_started
	#secondary_action = false


func fall_check():
	## If you leave the floor, store last position.
	## When you land again, compare the distances of both location y values, if greater
	## than the hard_landing_height, then trigger a hard landing. Otherwise, 
	## clear the last_altitude variable.

	if !is_on_floor() && last_altitude == null:
		last_altitude = global_position
	if is_on_floor() && last_altitude != null:
		var fall_distance = abs(last_altitude.y - global_position.y)
		if fall_distance > hard_landing_height:
			trigger_event("landed_fall")
		last_altitude = null
		# Helps air attacks "land"
		if busy:
			busy = false
			
			
func sprint():
	if sprint_timer.is_stopped():
		sprint_timer.start(.3)
		await sprint_timer.timeout
		if !dodging && input_dir:
			sprinting = true
			sprint_started.emit() # triggers the change in anim tree
		
func end_sprint():
	sprinting = false
		
			
var guard_local
var strafe_local

func dodge():
	if dodging or busy:
		return
	# While dodging, save out theese locals	
	guard_local = guarding
	strafe_local = strafing
	busy = true

	guarding = false
	strafing = false
	dodging = true
	dodge_started.emit()
	
	# Stop the weapon from being active during dodge since we allow dodge interrupts
	# to attacks - AD 10/30/2024
	if weapon_system:
		weapon_system.deactivate.emit()
	
	if animation_tree:
		await animation_tree.animation_measured
	hurt_cool_down.start(anim_length)
	await get_tree().create_timer(anim_length).timeout
	guarding = guard_local
	strafing = strafe_local
	dodging = false
	busy = false
 
func _on_animation_measured(_new_length ):
	anim_length = _new_length - .05

func interact():
	if is_on_floor() && !busy:
		# ADDED: For shopping... - AD
		if interactable_custom && interactable_custom.get_parent().has_method("activate"):
			interactable_custom.get_parent().activate(self, interactable_custom.name)
			
		if interactable && interactable.has_method("activate"):
			interactable.activate(self)
		elif ladder:
			ladder.activate(self)

func _on_climb_started():
	#interactable = null
	current_state = state.CLIMB
	
func abort_climb():
	if current_state == state.CLIMB:
		last_altitude = global_position
		current_state = state.FREE

func weapon_change():
	slowed = true
	if weapon_type == 'BOW':
		$WeaponSystem/LeftHand.hide()
	trigger_event("weapon_change_started")
	await event_finished
	if two_handed_weapons.has(weapon_type):
		system_visible(gadget_system,false)
	else:
		system_visible(gadget_system,true)
	weapon_change_ended.emit(weapon_type)
	slowed = false
	
	
func _on_weapon_equipment_changed(_new_weapon:EquipmentObject):
	weapon_type = _new_weapon.equipment_info.object_type

func _on_gadget_equipment_changed(_new_gadget:EquipmentObject):
	if _new_gadget:
		gadget_power = _new_gadget.equipment_info.power
		gadget_type = _new_gadget.equipment_info.object_type

func _on_inventory_item_used(_item):
	current_item = _item
	
func gadget_change():
	slowed = true
	trigger_event("gadget_change_started")
	await event_finished
	gadget_change_ended.emit(gadget_type)
	await get_tree().create_timer(anim_length *.5).timeout
	slowed = false

# TODO: We're just using health potion for now.
func item_change():
	return
	
	#slowed = true
	#trigger_event("item_change_started")
	#await event_finished
	#item_change_ended.emit(current_item)
	#slowed = false
	
func start_guard(): # Guarding, and for a short window, parring is possible
	set_strafe_targeting()
	slowed = true
	guard_local = true
	guarding = true
	parry_active = true
	Hub.equipment_is_using.emit(true)
	await get_tree().create_timer(parry_window).timeout
	parry_active = false

func end_guard():
	guarding = false
	guard_local = false

	parry_active = false
	slowed = false

	strafing = false
	strafe_local = false
	strafe_toggled.emit(false)
	Hub.equipment_is_using.emit(false)


func use_gadget(): # emits to start the gadget, and runs some timers before stopping the gadget
	trigger_event("gadget_started")

func hit(_who, _by_what):
	if is_dead:
		return
	# only get hit by things on your client.
	if is_multiplayer_authority(): 
		if hurt_cool_down.time_left > 0:
			return
		if parry_active:
			parry()
			if _who.has_method("parried"):
				_who.parried()
			return
		elif guarding && gadget_power != 0:
			block()
		else:
			damage_taken.emit(_by_what.power)
			hurt()

func heal(_by_what):
	print(_by_what)
	health_received.emit(_by_what.power)

func block():
	block_started.emit()

func parry():
	parry_started.emit()
	if animation_tree:
		await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	hurt_cool_down.start(anim_length)

func hurt():
	if not is_multiplayer_authority():
		return
	hurt_started.emit() # before state change in case on ladder,etc
	if animation_tree:
		await animation_tree.animation_measured
	hurt_cool_down.start(anim_length)
	await get_tree().create_timer(anim_length).timeout

func use_item():
	if inventory_system.current_item.count == 0:
		return
	if not busy or dodging:
		busy = true
		slowed = true
		use_item_started.emit()
		await animation_tree.animation_measured
		await get_tree().create_timer(anim_length * .5).timeout
		item_used.emit()
		await get_tree().create_timer(anim_length * .5).timeout
		slowed = false
		busy = false

# TODO: Death is messy.
# TODO: Reset their weapons somehow.................
# TODO: Would be nice to do anyway so they can drop something. 
func death():
	if not is_multiplayer_authority(): 
		return
	if is_dead == true:
		return
	#$CollisionShape3D.disabled = true
	hurt_cool_down.start(8.0)
	current_state = state.STATIC
	is_dead = true
	# TODO: Death is hacky. Don't call directly perhaps?	
	animation_tree._on_death_started()
	await get_tree().create_timer(3).timeout
	visible = false
	await get_tree().create_timer(5).timeout
	restore()

# TODO: Needs to take all your weapons away.
# Could also orbit the Cart cam for a hot second... 
# Could... also. QUEUE Free the player for a bit. LOL.

func restore():
	# I'm kind of a genius 0_0. i just reversed the Store shopping logic (after like 2hours) lol.
	replace_loot_on_system.rpc('WeaponSystem', "empty_scene")
	replace_loot_on_system.rpc('GadgetSystem', "empty_scene")
	coins = 70
	_on_update_coin()
	health_received.emit(health_system.total_health)
	global_position = get_spawn_point() + Hub.get_cart().global_position
	is_dead = false
	visible = true
	current_state = state.FREE
	animation_tree._on_weapon_change_ended('')
	_hide_or_show_bow('')
	animation_tree._on_spawn_started()


func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 5.0, spawn_point.y)

func system_visible(_system_node,_new_toggle):
		if _system_node:
			_system_node.visible = _new_toggle

func trigger_interact(interact_type:String):
	if busy:
		return
	busy = true
	interact_started.emit(interact_type)
	await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	busy = false

func trigger_event(signal_name:String):
	if busy or dodging:
		return
	if is_multiplayer_authority(): 
		trigger_event_sync.rpc(signal_name)
	busy = true
	emit_signal(signal_name)
	await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	event_finished.emit()
	busy = false

@rpc("call_remote")
func trigger_event_sync(signal_name):
	emit_signal(signal_name)
	await animation_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	event_finished.emit()

func jump():
	# Handle jump.
	# Added some extra checks to prevent nonsense - AD.
	if is_on_floor() && busy == false && dodging == false && guarding == false:
		jump_started.emit()
		await get_tree().create_timer(.1).timeout # for the windup
		velocity.y = jump_velocity

func set_root_move(delta):
	input_dir = Input.get_vector("move_left","move_right","move_up","move_down")
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

	
func set_root_climb(delta):
	input_dir = Input.get_vector("move_left","move_right","move_up","move_down")
	
	var rate = 2
	var new_velocity = get_quaternion() * animation_tree.get_root_motion_rotation() * animation_tree.get_root_motion_position() / delta
	
	#velocity = lerp (velocity,new_velocity,rate) #buggier than move_toward
	velocity.x = move_toward(velocity.x, new_velocity.x, rate)
	velocity.y = move_toward(velocity.y, new_velocity.y, rate)
	velocity.z = move_toward(velocity.z, new_velocity.z, rate)
	# dismount logic
	if !sensor_cast.is_colliding():
		#print("cast not colliding")
		current_state = state.FREE
		last_altitude = global_position
		var dismount_pos = to_global(Vector3.BACK)
		dismount_pos.y += .5
		var tween = create_tween()

		tween.tween_property(self,"global_position",dismount_pos,.3)
	if is_on_floor():
		current_state = state.FREE
		#free_started.emit()
		
func calc_direction() -> Vector3 :
	var new_direction = (current_camera.global_transform.basis.z * input_dir.y + \
	current_camera.global_transform.basis.x * input_dir.x)
	return new_direction

# New: - AD
func calc_direction_based_on_camera() -> Vector3: 
	var new_camera_direction = current_camera.global_transform.basis.z + current_camera.global_transform.basis.x
	return new_camera_direction
	
	
	
# MULTIPLAYER TEMPLATE RPCS
# MULTIPLAYER TEMPLATE RPCS

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick
		
#@rpc("any_peer", "reliable")
#func set_player_skin(skin_name: String) -> void:
	#var texture = get_texture_from_name(skin_name)
	#var bottom: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
	#var chest: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
	#var face: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
	#var limbs_head: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
	#
	#set_mesh_texture(bottom, texture)
	#set_mesh_texture(chest, texture)
	#set_mesh_texture(face, texture)
	#set_mesh_texture(limbs_head, texture)
	
# MULTIPLAYER TEMPLATE RPCS
# MULTIPLAYER TEMPLATE RPCS


# So that we're not in falling state during engine hint
func prevent_engine():
	return not Engine.is_editor_hint()

func get_coin(amount):
	coins = coins + amount
	_on_update_coin()

func _on_update_coin():
	$GUI/GUIFullRect/MarginContainer/ItemSlot/CoinCount.text = str(coins)
	

func _on_eyeline_enter(_interactable):
	if _interactable && _interactable.is_in_group("interactable"):
		$GUI/GUIFullRect/InteractTooltip.text = str(_interactable.name)
		interactable_custom = _interactable
	
func _on_eyeline_leave(_interactable):
	$GUI/GUIFullRect/InteractTooltip.text = ''
	interactable_custom = null


## EQUIPMENT
var shield_scene = preload("res://player/equipment_system/equipment/shield.tscn")
var axe_scene = preload("res://player/equipment_system/equipment/Ax.tscn")
var bow_scene = preload("res://player/equipment_system/equipment/Bow.tscn")
var empty_scene = preload("res://player/equipment_system/equipment/EmptyEquipment.tscn")

## EQUIPMENT

var new_packed_scene = { 
	"shield_scene": shield_scene,
	"axe_scene": axe_scene,
	"bow_scene": bow_scene,
	"empty_scene": empty_scene
}

# NOTE: This is an RPC because we are spawning items (see mulitplayer spawner in player).
@rpc("authority", "call_local")
func replace_empty_on_system(system_name, scene_name, cost: int):
		if coins < cost:
			store_error.emit()
			return
		var system = get_node_or_null(system_name)
		if system != null: 
			var mount_string = system._find_empty_pivot()
			if mount_string != null:
				var mount_point = system[mount_string]
				var free_eq = mount_point.get_child(0)
				mount_point.remove_child(free_eq)
				var new_scene = new_packed_scene[scene_name].instantiate()
				system[mount_string].add_child(new_scene)
				if mount_string == "held_mount_point":
					system.current_equipment = new_scene
					system._on_stop_signal()
					if (system.name == 'GadgetSystem'):
						_on_gadget_equipment_changed(system.current_equipment)
					else:
						_on_weapon_equipment_changed(system.current_equipment)
				else:
					system.stored_equipment = new_scene
					system.stored_equipment.equipped = false
					system.stored_equipment.monitoring = false
				# Remove the empty equipment
				coins = coins - cost
				store_success.emit()
				await get_tree().create_timer(.1).timeout
				free_eq.queue_free()
			else:
				store_error.emit()

@rpc("authority", "call_local")
func replace_loot_on_system(system_name, scene_name):
		var system = get_node_or_null(system_name)
		if system != null: 
			var mount_string = system._find_loot_pivot(["Ax", "Bow", "Shield"])
			if mount_string != null:
				var mount_point = system[mount_string]
				var free_eq = mount_point.get_child(0)
				mount_point.remove_child(free_eq)
				var new_scene = new_packed_scene[scene_name].instantiate()
				system[mount_string].add_child(new_scene)
				if mount_string == "held_mount_point":
					system.current_equipment = new_scene
					system._on_stop_signal()
					if (system.name == 'GadgetSystem'):
						_on_gadget_equipment_changed(system.current_equipment)
					else:
						if system.current_equipment.equipment_info.object_type == "BOW":
							weapon_change()
						else:
							_on_weapon_equipment_changed(system.current_equipment)
				else:
					system.stored_equipment = new_scene
					system.stored_equipment.equipped = false
					system.stored_equipment.monitoring = false
				# Remove the empty equipment
				await get_tree().create_timer(.1).timeout
				free_eq.queue_free()
				
# TODO: make this a lot more robust
func spawn():
	$GUI.show()
	#animation_tree.abort_oneshot(animation_tree.last_oneshot)
	#animation_tree.request_oneshot("Spawn")
	
func add_new_potion(_cost):
	if coins >= _cost:	
		$InventorySystem.add_potion()
		coins = coins - _cost
		store_success.emit()
	else:
		store_error.emit()


func _hide_or_show_bow(_new_weapon):
	if _new_weapon == "BOW":
		$WeaponSystem/LeftHand.visible = true
		$WeaponSystem/RightHand.visible = false
	else:
		$WeaponSystem/RightHand.visible = true
		$WeaponSystem/LeftHand.visible = false
