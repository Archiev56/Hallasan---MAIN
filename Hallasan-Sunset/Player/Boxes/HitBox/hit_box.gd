class_name HitBox extends Area2D

signal damaged(hurt_box: HurtBox)
@export var hp : int = 1

var is_invulnerable: bool = false  # Add this property to control invulnerability.

func _ready():
	pass  # Replace with function body.

func take_damage(hurt_box: HurtBox) -> void:
	if is_invulnerable:
		print("Damage ignored: Player is invulnerable")
		return  # Skip emitting the signal if invulnerable.
	damaged.emit(hurt_box)
