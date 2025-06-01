extends StaticBody2D
@export var item: InvItem
var player = null


func _on_interactable_area_body_entered(body):
	if body.is_in_group("player"):  # Check if the body is the player

		player = body
		playercollect()
		await get_tree().create_timer(0.1).timeout
		self.queue_free()
		
func playercollect():
	player.collect(item)
	$Pickup.play()
