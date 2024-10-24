@tool
extends Node3D

const GRASS_MESH_HIGH := preload('res://assets/environment/GodotGrass/grass/grass_high.obj')
const GRASS_MESH_LOW := preload('res://assets/environment/GodotGrass/grass/grass_low.obj')
const GRASS_MAT := preload('res://assets/environment/GodotGrass/grass/mat_grass.tres')
const HEIGHTMAP := preload('res://assets/environment/heightmap_grass_main.tres')

@export var player: Node3D

const TILE_SIZE := 5.0
const MAP_RADIUS := 200.0
const HEIGHTMAP_SCALE := 5.0

var grass_multimeshes : Array[Array] = []
var previous_tile_id := Vector3.ZERO
var should_render_imgui := true

# TODO: add back camera
#@onready var camera := get_viewport().get_camera_3d()
#@onready var camera_fov := [camera.fov]

#@onready var should_render_fog := [$Environment.environment.volumetric_fog_enabled]
@onready var should_render_shadows := [true]
@onready var density_modifier := [0.8 if Engine.is_editor_hint() else 1.0]
@onready var clumping_factor := [GRASS_MAT.get_shader_parameter('clumping_factor')]
@onready var wind_speed := [GRASS_MAT.get_shader_parameter('wind_speed')]

func _init() -> void:
	# TOOD: Re-enable to resize nicely? or fullscreen.
	#DisplayServer.window_set_size(DisplayServer.screen_get_size() * 0.75)
	#DisplayServer.window_set_position(DisplayServer.screen_get_size() * 0.25 / 2.0)
	RenderingServer.global_shader_parameter_set('heightmap', HEIGHTMAP)
	RenderingServer.global_shader_parameter_set('heightmap_scale', HEIGHTMAP_SCALE)
	
func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
	await get_tree().create_timer(1.0).timeout
	_setup_heightmap_collision()
	_setup_grass_instances()
	_generate_grass_multimeshes()



func set_tracker(node):
	player = node
	
func _physics_process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set('player_position', player.global_position)

	# Correct LOD by repositioning tiles when the player moves into a new tile
	var lod_target : Node3D = EditorInterface.get_editor_viewport_3d(0).get_camera_3d() if Engine.is_editor_hint() else player
	var tile_id : Vector3 = ((lod_target.global_position + Vector3.ONE*TILE_SIZE*0.5) / TILE_SIZE * Vector3(1,0,1)).floor()
	if tile_id != previous_tile_id:
		for data in grass_multimeshes:
			data[0].global_position = data[1] + Vector3(1,0,1)*TILE_SIZE*tile_id
	previous_tile_id = tile_id

## Creates a HeightMapShape3D from the provided NoiseTexture2D
func _setup_heightmap_collision() -> void:
	var heightmap := HEIGHTMAP.noise.get_image(512, 512)
	var dims := Vector2i(heightmap.get_height(), heightmap.get_width())
	var map_data : PackedFloat32Array
	for j in dims.x:
		for i in dims.y:
			map_data.push_back((heightmap.get_pixel(i, j).r - 0.5)*HEIGHTMAP_SCALE)
	
	var heightmap_shape := HeightMapShape3D.new()
	heightmap_shape.map_width = dims.x
	heightmap_shape.map_depth = dims.y
	heightmap_shape.map_data = map_data
	$NavigationRegion3D/Ground/CollisionShape3D.shape = heightmap_shape
	$NavigationRegion3D.bake_navigation_mesh()
	

## Creates initial tiled multimesh instances.
func _setup_grass_instances() -> void:
	for i in range(-MAP_RADIUS, MAP_RADIUS, TILE_SIZE):
		for j in range(-MAP_RADIUS, MAP_RADIUS, TILE_SIZE):
			var instance := MultiMeshInstance3D.new()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if should_render_shadows[0] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.material_override = GRASS_MAT
			instance.position = Vector3(i, 0.0, j)
			
			# TODO:adjust
			# AVOIDS CULLING TO SOON higher
			# THIS CAN EFFECT PERF. If you have not too many hills, you can turn it down
			
			instance.extra_cull_margin = 2.00
			add_child(instance)
			
			grass_multimeshes.append([instance, instance.position])

## Generates multimeshes for previously created multimesh instances with LOD based
## on distance to origin.
func _generate_grass_multimeshes() -> void:
	var multimesh_lods : Array[MultiMesh] = [
		create_grass_multimesh(1.0*density_modifier[0], TILE_SIZE, GRASS_MESH_HIGH),
		create_grass_multimesh(0.5*density_modifier[0], TILE_SIZE, GRASS_MESH_HIGH),
		create_grass_multimesh(0.25*density_modifier[0], TILE_SIZE, GRASS_MESH_LOW),
		create_grass_multimesh(0.1*density_modifier[0], TILE_SIZE, GRASS_MESH_LOW),
		create_grass_multimesh(0.02*(1.0 if density_modifier[0] != 0.0 else 0.0), TILE_SIZE, GRASS_MESH_LOW),
	]
	for data in grass_multimeshes:
		var distance = data[1].length() # Distance from center tile
		if distance > MAP_RADIUS: continue
		if distance < 18.0:    data[0].multimesh = multimesh_lods[0]
		elif distance < 40.0:  data[0].multimesh = multimesh_lods[1]
		elif distance < 70.0:  data[0].multimesh = multimesh_lods[2]
		elif distance < 100.0: data[0].multimesh = multimesh_lods[3]
		else:                  data[0].multimesh = multimesh_lods[4]

func create_grass_multimesh(density : float, tile_size : float, mesh : Mesh) -> MultiMesh:
	var row_size = ceil(tile_size*lerpf(0.0, 10.0, density));
	var multimesh := MultiMesh.new()
	multimesh.mesh = mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = row_size*row_size

	var jitter_offset := tile_size/float(row_size) * 0.5 * 0.9
	for i in row_size:
		for j in row_size:
			var grass_position := Vector3(i/float(row_size) - 0.5, 0, j/float(row_size) - 0.5) * tile_size
			var grass_offset := Vector3(randf_range(-jitter_offset, jitter_offset), 0, randf_range(-jitter_offset, jitter_offset))
			multimesh.set_instance_transform(i + j*row_size, Transform3D(Basis(), grass_position + grass_offset))
	return multimesh
