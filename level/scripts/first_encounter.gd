extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var env = get_parent().get_children()
	print('Encounter: ', env)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
