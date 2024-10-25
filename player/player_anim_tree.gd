extends AnimationTree
class_name AnimationTreeSoulsBase

## A companion to the SoulsCharacterBase, expects a lot of specific signals and will react to them
## by triggering oneshot animations, switching trees, blending run types, etc. This is really 
## the meat of the souls modules since so much relies on animations and their timing.
## Most of the difficulty comes from when the movement tree changes from one weapon type to another.
## There are many ways to approach transitioning between different movement trees,
## I simply found this to be most convenient.


## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

# TODO: We may want to export all of these for Syncing, then we can
# turn off some processing probably.

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

@export var player_node: CharacterBody3D
@onready var base_state_machine : AnimationNodeStateMachinePlayback = self["parameters/MovementStates/playback"]
#@onready var ladder_state_machine = self["parameters/MovementStates/LADDER_tree/playback"]
@onready var current_weapon_tree : AnimationNodeStateMachinePlayback

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

@export var weapon_type : String = "SLASH"
@export var gadget_type : String = "SHIELD"
@export var interact_type :String = "GENERIC"
@export var current_item : ItemResource

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

@export var max_attack_count : int = 2 ## how many attacks you have in the attack tree
@onready var attack_count = 1 ## Used in the anim state tree. The oneShot for the
## ATTACK_tree, under SLASH and HEAVY each route to an animation will use this 
## variable under it's advanced expression to know which route to take.
@onready var attack_timer = Timer.new()
@onready var hurt_count = 1

@export var anim_length = 0.0

@onready var landing_type = "SOFT"
@export var last_oneshot: String = "Attack"
var lerp_movement

var guard_value :float = 0.0

signal animation_measured

## MULTIPLAYER TEMPLATE FUNCS 
## MULTIPLAYER TEMPLATE FUNCS

# NOTE: This is in the player tree, so the parent sets the authority, no need to do it again here.

#func _enter_tree():
	#set_multiplayer_authority(str(name).to_int())

## MULTIPLAYER TEMPLATE FUNCS
## MULTIPLAYER TEMPLATE FUNCS


func _ready():
	if not is_multiplayer_authority(): 
		return

	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	if !player_node:
		push_warning(str(self) + ": Player node must be set")
		
	player_node.dodge_started.connect(_on_dodge_started)
	player_node.jump_started.connect(_on_jump_started)
	player_node.sprint_started.connect(_on_sprint_started)
	player_node.landed_fall.connect(_on_landed_fall)
	
	player_node.interact_started.connect(_on_interact_started)
	player_node.climb_started.connect(_on_climb_start)
	#player_node.ladder_finished.connect(_on_ladder_finished)

	player_node.weapon_change_started.connect(_on_weapon_change_started)
	player_node.weapon_change_ended.connect(_on_weapon_change_ended)
	player_node.attack_started.connect(_on_attack_started)
	
	player_node.gadget_change_started.connect(_on_gadget_change_started)
	player_node.gadget_change_ended.connect(_on_gadget_change_ended)
	player_node.gadget_started.connect(_on_gadget_started)
	
	player_node.item_change_started.connect(_on_item_change_started)
	player_node.item_change_ended.connect(_on_item_change_ended)
	player_node.use_item_started.connect(_on_use_item_started)
		
	player_node.parry_started.connect(_on_parry_started)
	player_node.hurt_started.connect(_on_hurt_started)
	player_node.block_started.connect(_on_block_started)

	player_node.death_started.connect(_on_death_started)

	_on_weapon_change_ended(player_node.weapon_type)
	_on_gadget_change_ended(player_node.gadget_type)
	_on_item_change_ended(player_node.current_item)
	
func _process(_delta):
	## MULTIPLAYER TEMPLATE FUNCS
	# NOTE: Required for all authorities

	if player_node.strafing:
		set_strafe()
	else:
		set_free_move()
		
	if player_node.current_state == player_node.state.CLIMB:
		set_ladder()
		
	set_guarding()

# RPC THIS? 
func request_oneshot(oneshot:String):
	last_oneshot = oneshot
	set("parameters/" + oneshot + "/request", true)
	if is_multiplayer_authority():
		sync_player_one_shot.rpc(oneshot)	
	

func _on_landed_fall(_hard_or_soft = "HARD"):
	landing_type = _hard_or_soft
	request_oneshot("Landed")

func set_guarding():
	if player_node.guarding && !player_node.busy:
		guard_value = 1
	else:
		guard_value = 0
	var new_blend = lerp(get("parameters/Guarding/blend_amount"),guard_value,.2)
	set("parameters/Guarding/blend_amount", new_blend)

func _on_parry_started():
	request_oneshot("Parry")

func _on_attack_started():
	request_oneshot("Attack")
	await animation_measured
	attack_timer.start(anim_length +.2)
	attack_count +=1
	if attack_count > max_attack_count:
		attack_count = 1


func _on_block_started():
	request_oneshot("Block")

func _on_hurt_started(): ## Picks a hurt animation between "Hurt1" and "Hurt2"
	if player_node.current_state == player_node.state.CLIMB:
		hurt_count = 3
	else:
		abort_oneshot(last_oneshot)
		hurt_count = randi_range(1,2)
		request_oneshot("Hurt")
		current_weapon_tree.start("MoveStrafe")
		
func abort_oneshot(_last_oneshot:String):
	set("parameters/" + _last_oneshot + "/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

	
func _on_death_started():
	base_state_machine.travel("Death")

func _on_use_item_started():
	request_oneshot("UseItem")

func _on_gadget_started():
	request_oneshot("Gadget")

func _on_sprint_started():
	base_state_machine.travel("SPRINT_tree")
	if is_multiplayer_authority():
		sync_player_sprinting.rpc()
	
func _on_dodge_started():
	request_oneshot("Dodge")

func _on_interact_started(_new_interact_type):
	interact_type = _new_interact_type
	await get_tree().process_frame
	request_oneshot("Interacts")
			

func _on_jump_started():
	request_oneshot("Jump")

func _on_weapon_change_started():
	request_oneshot("WeaponChange")

func _on_weapon_change_ended(_new_weapon_type):
	# if a wapon tree exixts, swap to it, otherwise, just use the "SLASH_tree" for rmovements.
	var weapon_tree_exists = tree_root.get_node("MovementStates").has_node(str(_new_weapon_type)+"_tree")
	if weapon_tree_exists:
		weapon_type = _new_weapon_type
	else:
		weapon_type = "SLASH"
	current_weapon_tree = get("parameters/MovementStates/"+str(_new_weapon_type)+"_tree/playback")

func _on_gadget_change_started():
	request_oneshot("GadgetChange")

func _on_gadget_change_ended(_new_gadget_type):
	gadget_type = _new_gadget_type

func _on_item_change_started():
	request_oneshot("ItemChange")

func _on_item_change_ended(_new_item):
	current_item = _new_item

func _on_climb_start():
	#set("parameters/MovementStates/LADDER_tree/LadderBlender/blend_position",0)
	#base_state_machine.start("LADDER_tree")
	base_state_machine.travel("LADDER_tree")
	#ladder_state_machine.travel("LadderStart_" + top_or_bottom)
	
#func _on_ladder_finished(top_or_bottom):
	##ladder_state_machine.travel("LadderEnd_" + top_or_bottom)
	#pass
	
func set_ladder():
	#set("parameters/MovementStates/LADDER_tree/LadderBlend/blend_position",-player_node.input_dir.y)
	#var ladder_frame = get("parameters/MovementStates/LADDER_tree/LadderBlender/blend_position")
	#print(ladder_frame)
	#if ladder_frame > 1:
		#ladder_frame = 0
	#elif ladder_frame < 0:
		#ladder_frame = 1
	#set("parameters/MovementStates/LADDER_tree/LadderBlender/blend_position",ladder_frame - (player_node.input_dir.y * .015)) # otherwise, play the animation at the speed of player input (* a speed if climb anim is slow)
	print(player_node.input_dir.y)
	set("parameters/MovementStates/LADDER_tree/LadderTime/scale",-player_node.input_dir.y)
			
func set_strafe():
	# Strafe left and right animations run by the player's velocity cross product
	# Forward and back are acording to input, since direction changes by fixed camera orientation
	var new_blend = Vector2(player_node.strafe_cross_product,player_node.move_dot_product)
	#if player_node.current_state == player_node.state.DYNAMIC_ACTION:
	if player_node.slowed:
		new_blend *= .25 # Force a walk animiation
	else:
		# apply input as a magnatude for more natural run versus walk animation blending
		new_blend *= Vector2(abs(player_node.input_dir.x),abs(player_node.input_dir.y)) 
	lerp_movement = get("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position")
	lerp_movement = lerp(lerp_movement,new_blend,.2)
	set("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position", lerp_movement)

func set_free_move():
	# Non-strafing "free" movement, is just the forward input direction.
	var new_blend = Vector2(0,abs(player_node.input_dir.x) + abs(player_node.input_dir.y))
	if player_node.slowed:
		new_blend *= .4 # force a walk speed
	lerp_movement = get("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position")
	lerp_movement = lerp(lerp_movement,new_blend,.2)
	set("parameters/MovementStates/" + weapon_type + "_tree/MoveStrafe/blend_position",lerp_movement)


func _on_animation_started(anim_name):
	print("DEBUG Animation Started: " + str(anim_name))
	anim_length = get_node(anim_player).get_animation(anim_name).length
	animation_measured.emit(anim_length)

func _on_attack_timer_timeout():
	attack_count = 1
	
## MULTIPLAYER RPCs
## MULTIPLAYER RPCs
## MULTIPLAYER RPCs
	
@rpc("any_peer", "reliable")
func sync_player_one_shot(one_shot) -> void:
	request_oneshot(one_shot)

@rpc("any_peer", "reliable")
func sync_player_sprinting() -> void:
	base_state_machine.travel("SPRINT_tree")
