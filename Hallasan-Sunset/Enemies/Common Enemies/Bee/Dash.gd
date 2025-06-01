extends StateBee

class_name DashState
 
@onready var timer = $Timer

 
func transition():
	if ray_cast.is_colliding():
		get_parent().change_state("Shoot")
		
		
 
func dash():
	# Check if the player is valid before trying to access position
	if is_instance_valid(player):
		var tween = get_tree().create_tween()
		tween.tween_property(owner, "position", player.position, 0.75)
	else:
		print("Player is invalid or does not exist!")
 
func _on_timer_timeout():
	dash()
 
func enter():
	super.enter()
	timer.start()
	# Check and assign the player node if not already assigned
	if not is_instance_valid(player):
		player = get_tree().current_scene.get_node("Player")
	
	if not is_instance_valid(player):
		print("Player node not found!")
	
	
 
func exit():
	super.exit()
	timer.stop()
