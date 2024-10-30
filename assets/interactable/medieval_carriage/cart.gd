extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	$CartCam.global_position = Vector3(global_position.x, $CartCam.global_position.y, global_position.z - 15.00)
	$CartCam.look_at(Vector3(global_position.x, 2.0,  global_position.z))
	pass
