extends RigidBody3D

var shell = false
var Damage: int = 0
var Source: int

func _ready():
	if shell == true:
		$Timer.wait_time = 0.3
		$Timer.start()

func _on_body_entered(body):
	if body.get_multiplayer_authority() == Source:
		return
	
	if body.has_method("Hit_Successful"):
		# id to hit,
		# source, damage, position, rotation
		#body.Hit_Successful.rpc_id(hit_player, Source, Damage, null, null)
		if multiplayer.is_server(): 
			queue_free()
					
	if multiplayer.is_server(): 
		queue_free()
		

func _on_timer_timeout():
	if multiplayer.is_server():	
		queue_free()
