extends GPUParticles3D


# Called when the node enters the scene tree for the first time.
func _ready():
	Hub.equipment_is_using.connect(point_at_cart)

func point_at_cart(_new_value):
	if Hub.get_cart() && _new_value == true:
		var cart = Hub.get_cart()
		var particle_dir_texture: CurveXYZTexture = process_material.directional_velocity_curve
		var dir_to = get_parent().global_position.direction_to(cart.global_position)
		particle_dir_texture.curve_x.clear_points()
		particle_dir_texture.curve_z.clear_points()
		particle_dir_texture.curve_x.add_point(Vector2(dir_to.x, dir_to.x))
		particle_dir_texture.curve_z.add_point(Vector2(dir_to.z, dir_to.z))
	else:
		var particle_dir_texture: CurveXYZTexture = process_material.directional_velocity_curve
		particle_dir_texture.curve_x.clear_points()
		particle_dir_texture.curve_z.clear_points()
