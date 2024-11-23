extends RigidBody3D

var shell = false
var Damage: int = 1
var Source: int

func _ready():
	if shell == true:
		$Timer.wait_time = 0.3
		$Timer.start()

func _on_body_entered(body):
	# Prevents self damage.
	if body.get_multiplayer_authority() == Source:
		return
	
	if body.has_method("hit"):
		print(body)
		# id to hit,
		# source, damage, position, rotation
		body.hit_sync.rpc(str(Source), Damage)
		if multiplayer.is_server(): 
			queue_free()
					
	if multiplayer.is_server(): 
		queue_free()
		

func _on_timer_timeout():
	if multiplayer.is_server():	
		queue_free()
