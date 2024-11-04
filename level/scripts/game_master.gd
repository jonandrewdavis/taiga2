extends Node3D


var previous_encounter_location = Vector3.ZERO
var encounter_tracker = Node3D
var distance_interval = 10.0

var first_encounter_scene = preload("res://level/scenes/first_encounter.tscn")

@onready var encounter_timer = $EncounterTimer

func _ready():
	# Only the server is listening to these.
	if multiplayer.is_server():
		Hub.encounter_timer_start.connect(_on_begin_encounters)
		Hub.encounter_tracker_changed.connect(_on_encounter_tracker_changed)

func _on_begin_encounters():
	encounter_timer.timeout.connect(check_for_encounter)
	encounter_timer.start()

# TODO: If someone deviates too far... we could theoretically create encounters on them!
# May need to figure out server / client responsibilites for that...
func _on_encounter_tracker_changed(new_encounter_tracker):
	encounter_tracker = new_encounter_tracker

func prepare_encounter():	
	print('preparing encounter')
	var first_encounter = first_encounter_scene.instantiate()
	Hub.environment_container.add_child(first_encounter, true)
	first_encounter.global_position = Vector3(10.0, 0.0, 10.0)
	pass

func check_for_encounter():
	print('CHECKING FOR ENCOUNTER...')
	if encounter_tracker:
		if encounter_tracker.global_position.distance_to(previous_encounter_location) > distance_interval:
			previous_encounter_location = encounter_tracker.global_position
			prepare_encounter()
		else:
			print('no enc')
