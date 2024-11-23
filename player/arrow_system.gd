extends Node3D

@onready var Bullet_Point = $BulletPoint
@onready var _Camera = $"../FollowCam".camera_3d
@onready var _Viewport = get_viewport().get_size()
@onready var Player_Ray = $BulletRayCast

var fire_range = 2000
var projectile_velocity = 65
var Spray = Vector2.ZERO
var damage = 1.0

@onready var BULLET_SCENE = preload("res://player/equipment_system/equipment/bullet.tscn")

## Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func shoot():
	var Ray_Origin = _Camera.project_ray_origin(_Viewport/2)
	var Ray_End = (Ray_Origin + _Camera.project_ray_normal((_Viewport/2)+Vector2i(Spray))* fire_range)
	LaunchProjectile(Ray_End)
		#
#var spread_min = 0.008
#var spread = 0.07
func LaunchProjectile(Point: Vector3):
	var Direction_To_Point = (Point - Bullet_Point.global_transform.origin).normalized()
	var Direction = Direction_To_Point * projectile_velocity
	spawn_bullet.rpc(Direction, damage, Bullet_Point.global_transform.origin, Point)


@rpc('any_peer', 'call_local')
func spawn_bullet(Direction, Damage, Position, RotationPoint):
	if multiplayer.is_server():
		var Projectile = BULLET_SCENE.instantiate()
		Projectile.position = Position
		Projectile.set_linear_velocity(Direction)
		Projectile.Damage = Damage
		Projectile.Source = multiplayer.get_remote_sender_id()
		# I learned the hard way only the server should add things the MultiplayerSpawner will handle the rest.
		Hub.environment_container.add_child(Projectile, true)
		Projectile.look_at(RotationPoint)

		#bullet = bullet_scene.instantiate()
		#bullet.position = pos
		#bullet.transform.basis = rot
		#bullet.is_burst = is_burst
		#bullet.source = multiplayer.get_remote_sender_id()

#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#pass
#
