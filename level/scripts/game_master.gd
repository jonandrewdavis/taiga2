extends Node3D


var previous_encounter_location = Vector3.ZERO
var encounter_tracker = Node3D
var distance_interval = 5.0
var despawn_distance = 15.0

var recent_directions = {}

var first_encounter_scene = preload("res://level/scenes/first_encounter.tscn")

@onready var encounter_timer = $EncounterTimer
@onready var encounter_direction_timer = $RecentDirectionTimer

func _enter_tree():
	set_multiplayer_authority(1)

# TODO: possible to have this node be instantiated only on the server. Probably not much benefit to that, but nonetheless

func _ready():
	# Only the server is listening to these.
	if is_multiplayer_authority():
		Hub.encounter_timer_start.connect(_on_begin_encounters)
		Hub.encounter_tracker_changed.connect(_on_encounter_tracker_changed)

func _on_begin_encounters():
	# Start up our timers, as we now have a monitorable subject
	encounter_timer.timeout.connect(check_for_encounter)
	encounter_direction_timer.timeout.connect(_record_recent_dir)

	encounter_timer.start()
	encounter_direction_timer.start()

# TODO: If someone deviates too far... we could theoretically create encounters on them!
# May need to figure out server / client responsibilites for that...
func _on_encounter_tracker_changed(new_encounter_tracker):
	encounter_tracker = new_encounter_tracker

# TODO: SLOW DOWN, REFACTOR. AND FULLY UNDERSTAND HOW AUTHORITY & SPAWNING AND MULTIPLER SPANWER WORK
# WHY DOES THIS NEED TO BE RPC'd TO BE SEEN ON OTHER CLIENTS???
# They are spawning infinitly on the servber now, so i I think the game master only needs to be 
# a node in the server......
@rpc("any_peer")
func prepare_encounter_sync(new_encounter_position):
	if is_multiplayer_authority():
		var first_encounter = first_encounter_scene.instantiate()
		Hub.environment_container.add_child(first_encounter, true)	
		first_encounter.global_position = new_encounter_position
		previous_encounter_location = new_encounter_position
		pass
		
func check_surrounding_area(new_encounter_position) -> bool:
	var min_dist = INF
	for node in Hub.environment_container.get_children():
		if node.is_in_group("encounters"):
			min_dist = min(min_dist, node.global_position.distance_to(new_encounter_position))
	
	for player in Hub.players_container.get_children():
		min_dist = min(min_dist, player.global_position.distance_to(new_encounter_position))
	
	return min_dist > distance_interval

var dir_index = 0

func _record_recent_dir():
	recent_directions[dir_index] = encounter_tracker.transform.basis.z
	if dir_index < 9:
		dir_index = dir_index + 1
	else:
		dir_index = 0


func check_for_encounter():
	print('CHECKING FOR ENCOUNTER...')
	if encounter_tracker:
		var average_recent_directions =  recent_directions.values().reduce(func(a, b): return a + b, Vector3.ZERO) / recent_directions.size()
		var new_encounter_position = encounter_tracker.global_position + (average_recent_directions * Vector3(10.0, 0.0, 10.0))
		if check_surrounding_area(new_encounter_position):
			print("encounter allowed")
			prepare_encounter_sync.rpc(new_encounter_position)

		await get_tree().create_timer(1).timeout 
		clean_up_encounters()

func clean_up_encounters():
	get_tree().call_group("encounters", "check_for_clean_up", encounter_tracker.global_position, despawn_distance)
