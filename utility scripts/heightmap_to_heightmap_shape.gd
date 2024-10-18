@tool

extends StaticBody3D

@onready var col = $CollisionShape3D

var heightmap: NoiseTexture2D
var shape: HeightMapShape3D = HeightMapShape3D.new()

var test_image = Image.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	heightmap = get_parent().heightmap

	await heightmap.changed
	var h_map = heightmap.get_image()
	var size = h_map.get_width()
	
	# Generate 32-bit noise and import it with scale
	#var noise := FastNoiseLite.new()
	#noise.frequency = 0.05
	var img: Image = Image.create(size, size, false, Image.FORMAT_RF)
	for x in size:
		for y in size:
			img.set_pixel(x, y, Color(heightmap.noise.get_noise_2d(x, y) * 10.0, 0., 0., 1.))

			
	print('IMAGE READY: ', img)
	shape.map_width = img.get_width()
	shape.map_depth = img.get_height()
	shape.map_data = img.get_data().to_float32_array()
	col.shape = shape
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
