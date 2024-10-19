@tool
extends Node3D

@export var environment_root_tracker: Node3D
@export var ground_chunk_mesh: NodePath
@export var heightmap : Texture2D

@onready var grass = $GrassMain

func create_editor_nodes():
	if !environment_root_tracker:
		var root_marker = Marker3D.new()
		root_marker.name = 'RootMarker'
		add_child(root_marker)
		environment_root_tracker = get_node('RootMarker')

	#if !floor:
		#var floor = StaticBody3D.new()
		#add_child(floor)		
		#var collision_shape = CollisionShape3D.new()
		#floor.add_child(collision_shape)
		#ground_chunk_mesh = floor

	#if !heightmap:
		#var noise = NoiseTexture2D.new()
		#var fast_noise = FastNoiseLite.new()
		#noise.noise = fast_noise
		#heightmap = noise
	
func signal_children():
	for child in get_children():
		if child.has_method('parent_ready'):
			child.parent_ready()

# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint(): 
		print("DEBUG: Creating EnvironmentInstance")
		create_editor_nodes()
		signal_children()

# TODO: Signals
func set_new_root(node: Node3D):
	print('NEW NODE', node)
	environment_root_tracker = node
	signal_children()
	Hub.emit_signal("_hello_world", node.name)
