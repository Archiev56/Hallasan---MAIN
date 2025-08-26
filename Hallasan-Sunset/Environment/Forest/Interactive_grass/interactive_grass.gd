extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var skewValue := 15
@export var bendGrassnimationSpeed = 0.3
@export var grassReturnAnimationSpeed = 5.0

@onready var animation_player = $AnimationPlayer




func _on_hit_box_damaged(_hurt_box):
	animation_player.play("destroy")
	pass # Replace with function body.
