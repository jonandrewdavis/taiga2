@tool
extends Node3D

@export var environment_root_tracker: Node3D
@export var heightmap : Texture2D

var environment_ignore = []

signal environment_tracker_changed
signal environment_ignore_changed

func _ready():
	if !environment_root_tracker:
		var root_marker = Marker3D.new()
		root_marker.name = 'TEMP_ROOT_TRACKER'
		add_child(root_marker)
		environment_root_tracker = root_marker

	environment_tracker_changed.connect(set_new_root)
	environment_ignore_changed.connect(set_new_ignore)

	# This helps the instancer_custom children have a little buffer
	# to set up before creating the meshes.	
	if environment_root_tracker && Engine.is_editor_hint():
		environment_tracker_changed.emit(environment_root_tracker)

# TODO: (optional) Rebake nav mesh for smarter enemies.
# Could just use a flat plane. To do so, use a group & target grass.
#func _rebake_root():
	#bake_navigation_mesh()

# Once past initialization, this shouldn't need to be here.
# All children scripts now connect to "environment_tracker_changed"
# Nothing is consuming this, so let's just add a debug statement
func set_new_root(node: Node3D):
	print("DEBUG: environment_root_tracker changed: ", node)
	environment_root_tracker = node

func set_new_ignore(node: Node3D):
	# AABB it.
	environment_ignore.append(node.get_aabb())
