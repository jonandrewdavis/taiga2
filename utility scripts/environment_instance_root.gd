@tool
extends Node3D

@export var environment_root_tracker: Node3D
@export var heightmap : Texture2D
@export var update_frequency: float = 0.2

@onready var grass = $GrassMain
@onready var timer = Timer.new()

func create_editor_nodes():
	if !environment_root_tracker:
		var root_marker = Marker3D.new()
		root_marker.name = 'RootMarker'
		add_child(root_marker)
		environment_root_tracker = get_node('RootMarker')

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
	timer.wait_time = update_frequency 
	add_child(timer)
	timer.start()
	timer.timeout.connect(_update)

	if Engine.is_editor_hint(): 
		print("DEBUG: Creating EnvironmentInstance")
		create_editor_nodes()

	if Engine.is_editor_hint() && is_inside_tree():
		signal_children()
	else:
		signal_children()


func _update():
	timer.wait_time = update_frequency 
	timer.start()


# TODO: Signals
func set_new_root(node: Node3D):
	print('NEW NODE', node)
	environment_root_tracker = node
	signal_children()
	Hub.emit_signal("_hello_world", node.name)
	$GrassMain.set_tracker(environment_root_tracker)
