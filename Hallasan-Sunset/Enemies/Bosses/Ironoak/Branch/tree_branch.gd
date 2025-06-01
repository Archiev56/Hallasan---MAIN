extends CharacterBody2D
 
 



func _on_hurt_box_did_damage(body):
	body.take_damage()
