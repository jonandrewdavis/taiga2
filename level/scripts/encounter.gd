extends Node3D

func _enter_tree():
	set_multiplayer_authority(1)

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("encounters")
		
	# Because it's at 0.0.0 when created, we wait a second before emitting, so we have the right global position
	await get_tree().create_timer(0.1).timeout 
	Hub.environment_ignore_add.emit($IgnoreZone, name)

# If there are no more nearby players, it's safe to remove this encounter
func check_for_clean_up(tracker_global_position, despawn_distance):
	var min_distance = INF
	for player in Hub.players_container.get_children():
		min_distance = min(min_distance, global_position.distance_to(player.global_position))

	min_distance = min(min_distance, global_position.distance_to(tracker_global_position))
	if min_distance > despawn_distance:
		Hub.environment_ignore_remove.emit($IgnoreZone, name)
		queue_free()
