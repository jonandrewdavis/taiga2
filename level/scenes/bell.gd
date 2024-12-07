extends RigidBody3D

var limit = 30
var most_recent_player = ''

signal ring

func _ready():
	if is_multiplayer_authority():
		%RingTimer.start()
		ring.connect(_on_ring.rpc)

func _physics_process(_delta):
	for col in get_colliding_bodies():
		if col is CharacterBody3D:
			var normal_dir = col.global_position.direction_to(self.global_position).normalized()
			apply_central_impulse(normal_dir * 1.5)
			apply_impulse(normal_dir * 0.01, get_position())
			col.velocity = col.velocity + linear_velocity
			most_recent_player = col.name

	try_ring()
		
func try_ring():
	if linear_velocity.z > 3.15 or linear_velocity.x > 3.15:
		ring.emit()	

func hit(_player, _equipment):
	ring.emit()

@rpc("any_peer", 'call_local')
func _on_ring():
	if is_multiplayer_authority() && %RingTimer.is_stopped() && limit > 0:
		limit = limit - 1
		Hub.spawn_enemy_at_location.rpc(global_position, 40.0, most_recent_player)
		%RingTimer.start(2.5)
		print("ENEMY, ", limit)
		print('LIN', linear_velocity)
	else: 
		$"../SoundFXTrigger".play()
