@tool
extends Node3D

# Inherit from EnvironemntInstanceRoot 
var environment_root_tracker: Node3D 
var ground_chunk_mesh: NodePath
var heightmap : Texture2D

@export var instance_amount : int = 100  # Number of instances to generate
@export var generate_colliders: bool = false
@export var collider_coverage_dist : float = 50
@export var pos_randomize : float = 0  # Amount of randomization for x and z positions
@export_range(0,50) var instance_min_scale: float = 1
@export var instance_height: float = 1
@export var instance_width: float = 1
@export var instance_spacing: int = 10
@export var terrain_height: float = 1
@export_range(0,10) var scale_randomize : float = 0.0  # Amount of randomization for uniform scale
@export_range(0,PI) var instance_Y_rot : float = 0.0  # Amount of randomization for X rotation
@export_range(0,PI) var instance_X_rot : float = 0.0  # Amount of randomization for Y rotation 
@export_range(0,PI) var instance_Z_rot : float = 0.0  # Amount of randomization for Z rotation 
@export var rot_y_randomize : float = 0.0  # Amount of randomization for Y rotation 
@export var rot_x_randomize : float = 0.0  # Amount of randomization for X rotation 
@export var rot_z_randomize : float = 0.0  # Amount of randomization for Z rotation 
@onready var hmap_img
@onready var width: int
@onready var height: int
@export var instance_mesh : Mesh   # Mesh resource for each instance
@export var instance_collision : Shape3D
@export var update_frequency: float = 0.2
@onready var instance_rows: int 
@onready var offset: float 
@onready var rand_x : float
@onready var rand_z : float
@onready var multi_mesh_instance
@onready var multi_mesh
var h_scale: float = 1
var v_scale: float = 1
@onready var timer 
@onready var collision_parent
@onready var colliders: Array
@onready var colliders_to_spawn: Array
@onready var last_pos: Vector3
@onready var first_update= true
 
func parent_ready():
	environment_root_tracker = get_parent().environment_root_tracker
	ground_chunk_mesh = get_parent().ground_chunk_mesh.get_as_property_path()
	heightmap = get_parent().heightmap

	if (environment_root_tracker && heightmap && ground_chunk_mesh): 
		global_position = Vector3(0,0,0)
		if Engine.is_editor_hint():
			if heightmap && environment_root_tracker && ground_chunk_mesh:
				print('DEBUG: Instancer: ', name)
				global_position = Vector3(0,0,0)
				create_multimesh()
			return
		else:
			global_position = Vector3(0,0,0)
			create_multimesh()
	else:
		print('DEBUG: Instancer FAILED:', name)
	
func create_multimesh():
	#grab horizontal scale on the terrain mesh so match the scale of the heightmap in case your terrain is resized
	h_scale = get_node(ground_chunk_mesh).scale.x # could be x or z, doesn not matter as they should be the same
	v_scale = get_node(ground_chunk_mesh).scale.y
	
	# Create a MultiMeshInstance3D and set its MultiMesh
	multi_mesh_instance = MultiMeshInstance3D.new()
	multi_mesh_instance.top_level = true
	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = instance_amount
	multi_mesh.mesh = instance_mesh 
	instance_rows = sqrt(instance_amount) #rounded down to integer
	offset = round(instance_amount/instance_rows) #rounded up/down to nearest integer

	# TODO: What does this do.	Stops the editor from working because it's getting from InstanceRoot
	#wait for map to load before continuing
	if !Engine.is_editor_hint():
		await heightmap.changed

	hmap_img = heightmap.get_image()
	width = hmap_img.get_width()
	height = hmap_img.get_height()
	
	print(hmap_img, width, height)
	
	# Add the MultiMeshInstance3D as a child of the instancer
	add_child(multi_mesh_instance)
	
	#Add timer for updates
	timer = Timer.new()
	$"..".add_child(timer)
	timer.timeout.connect(_update)
	timer.wait_time = update_frequency 
	_update()
 
func _update():
	#on each update, move the center to player
	self.global_position = Vector3(environment_root_tracker.global_position.x,0.0,environment_root_tracker.global_position.z).snapped(Vector3(1,0,1));
	multi_mesh_instance.multimesh = distribute_meshes()
	timer.wait_time = update_frequency
	timer.start()
 
func distribute_meshes():
	randomize()
	for i in range(instance_amount):
		# Generate positions on X and Z axes    
		var pos = global_position
		pos.z = i;
		pos.x = (int(pos.z) % instance_rows);
		pos.z = int((pos.z - pos.x) / instance_rows);
 
		#center this
		pos.x -= offset/2
		pos.z -= offset/2
 
		#apply spacing (snap to integer to keep instances in place)
		pos *= instance_spacing;
		pos.x += int(global_position.x) - (int(global_position.x) % instance_spacing);
		pos.z += int(global_position.z) - (int(global_position.z) % instance_spacing);
		
		#add randomization  
		var x
		var z
		pos.x += random(pos.x,pos.z) * pos_randomize
		pos.z += random(pos.x,pos.z) * pos_randomize
		pos.x -= pos_randomize * random(pos.x,pos.z)
		pos.z -= pos_randomize * random(pos.x,pos.z)
		
		x = pos.x 
		z = pos.z 
		
		# Sample the heightmap texture to determine the Y position
		var y = get_heightmap_y(x, z)
 
		var ori = Vector3(x, y, z)
		var sc = Vector3(   instance_min_scale+scale_randomize * random(x,z) + instance_width,
							instance_min_scale+scale_randomize * random(x,z) + instance_height,
							instance_min_scale+scale_randomize * random(x,z)+ instance_width
							)
 
		# Randomize rotations
		var rot = Vector3(0,0,0)
		rot.x += instance_X_rot + (random(x,z) * rot_x_randomize)
		rot.y += instance_Y_rot + (random(x,z) * rot_y_randomize)
		rot.z += instance_Z_rot + (random(x,z) * rot_z_randomize)
 
		var t
		t = Transform3D()
		t.origin = ori
		
		t = t.rotated_local(t.basis.x.normalized(),rot.x)
		t = t.rotated_local(t.basis.y.normalized(),rot.y)
		t = t.rotated_local(t.basis.z.normalized(),rot.z)
 
		# Set the instance data
		multi_mesh.set_instance_transform(i, t.scaled_local(sc))
 
		#Collisions
		if generate_colliders:
			if first_update:
				if i == instance_amount-1:
					first_update = false
					generate_subset()
			else:   
				if !colliders[i] == null:
					colliders[i].global_transform = t.scaled_local(sc)  
 
	last_pos = global_position
	return multi_mesh
 
func get_heightmap_y(x, z):
	# Sample the heightmap texture to get the Y position based on X and Z coordinates
	var i : float = 2.0
	var pixel_x = (width / i) + x
	var pixel_z = (height / i) + z
	
	if pixel_x > width: pixel_x -= width 
	if pixel_z > height: pixel_z -= height 
	if pixel_x < 0: pixel_x += width 
	if pixel_z < 0: pixel_z += height 
 	
	var color: Color = hmap_img.get_pixel(pixel_x, pixel_z)
	
	# NOTE: The secret key here was the scaling factor (* 300.0) for generated terrain
	# TODO: Rename terrain_height to terrain_height (negative), cause I'm using to subtract
	return (color.r * (2.0 * 1)) - terrain_height

 
func random(x,z):
	var r = fposmod(sin(Vector2(x,z).dot(Vector2(12.9898,78.233)) * 43758.5453123),1.0)
	return r
	
func spawn_colliders():
	collision_parent = StaticBody3D.new()
	add_child(collision_parent)
	collision_parent.set_as_top_level(true)
	var c_shape = instance_collision
	
	for i in range(instance_amount):
		if colliders_to_spawn.has(i):
			var collider = CollisionShape3D.new()
			collision_parent.add_child(collider)
			collider.set_shape(instance_collision)
			colliders.append(collider)
		else:
			colliders.append(null)      

# TODO: May need to highly increase Collider dist so that users can't wander too far and clip
func generate_subset():
	for i in range(instance_amount):
		var t = multi_mesh.get_instance_transform(i)
		if t.origin.distance_squared_to(environment_root_tracker.global_position) < pow(collider_coverage_dist,2):
			colliders_to_spawn.append(i)        
		if i==instance_amount-1:
			spawn_colliders()