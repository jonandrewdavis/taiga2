extends Node3D

@export var custom_ignore_mesh: MeshInstance3D 

@onready var ignore_zone = MeshInstance3D.new()
@onready var ignore_zone_mesh = CylinderMesh.new()

const HEIGHTMAP := preload('res://assets/environment/heightmap_grass_main.tres')
const HEIGHTMAP_SCALE = 5.0

const ignore_zone_radius = 22.0

@onready var scenery_container: Node3D = $SceneryContainer

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("encounters")
		
	# Because it's at 0.0.0 when created, we wait a second before emitting, so we have the right global position
	await get_tree().create_timer(0.1).timeout
	
	# TODO: This code doesn't work probably because it needs a spawner, but it should work on each client?
	if custom_ignore_mesh: 
		Hub.environment_ignore_add.emit(custom_ignore_mesh, name)
	else:
		ignore_zone_mesh.bottom_radius = ignore_zone_radius
		ignore_zone_mesh.top_radius = ignore_zone_radius
		ignore_zone_mesh.height = 15.0
		ignore_zone.mesh = ignore_zone_mesh
		ignore_zone.visible = false
		add_child(ignore_zone)
		Hub.environment_ignore_add.emit(ignore_zone, name)

	if is_multiplayer_authority():
		height_map_check.rpc()	

# TODO: This could possibly be a local only check!
@rpc
func height_map_check():
	if scenery_container:
		for object in scenery_container.get_children():
			object.global_position.y = get_heightmap_y(object.global_position.x, object.global_position.z) + 1.0
			
# If there are no more nearby players, it's safe to remove this encounter
func check_for_clean_up(tracker_global_position, despawn_distance):
	var min_distance = INF
	for player in Hub.players_container.get_children():
		min_distance = min(min_distance, global_position.distance_to(player.global_position))

	min_distance = min(min_distance, global_position.distance_to(tracker_global_position))
	if min_distance > despawn_distance:
		Hub.environment_ignore_remove.emit(ignore_zone_mesh, name)
		queue_free()

func get_heightmap_y(x, z):
	var hmap_img = HEIGHTMAP.noise.get_image(1024, 1024)
	var width = hmap_img.get_width()
	var height = hmap_img.get_height()

	# Sample the heightmap texture to get the Y position based on X and Z coordinates
	@warning_ignore("integer_division")
	var pixel_x = (width / 2) + x / HEIGHTMAP_SCALE 
	@warning_ignore("integer_division")
	var pixel_z = (height / 2) + z / HEIGHTMAP_SCALE 
	
	if pixel_x > width: pixel_x -= width 
	if pixel_z > height: pixel_z -= height 
	if pixel_x < 0: pixel_x += width 
	if pixel_z < 0: pixel_z += height 
 
	#var color = hmap_img.get_pixel(pixel_x, pixel_z)
	var color = (hmap_img.get_pixel(pixel_x, pixel_z).r - 0.5)* HEIGHTMAP_SCALE
	#return color.r * terrain_height * v_scale
	return color
 
