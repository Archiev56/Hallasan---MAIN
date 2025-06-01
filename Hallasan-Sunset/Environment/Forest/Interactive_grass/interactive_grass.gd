extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var skewValue := 15
@export var bendGrassnimationSpeed = 0.3
@export var grassReturnAnimationSpeed = 5.0

@onready var animation_player = $AnimationPlayer


func _on_body_entered(body: Node2D) -> void:
	if body == get_tree().get_first_node_in_group("player"):
		var direction = global_position.direction_to(body.global_position)
		var skew : int = -direction.x * skewValue
		
		var tween = create_tween()
		tween.tween_property(
			sprite_2d.material, 
			"shader_parameter/skew", 
			skew, 
			bendGrassnimationSpeed
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			
		tween.tween_property(
			sprite_2d.material, 
			"shader_parameter/skew", 
			0.0, 
			grassReturnAnimationSpeed
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			



func _on_hit_box_damaged(hurt_box):
	animation_player.play("destroy")
	pass # Replace with function body.
