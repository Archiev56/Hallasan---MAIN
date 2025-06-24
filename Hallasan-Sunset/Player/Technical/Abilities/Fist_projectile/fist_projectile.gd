extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0

@onready var sprite: Sprite2D = $Sprite2D

func fire():
	set_physics_process(true)
	update_sprite_frame()

func _physics_process(delta):
	position += direction * speed * delta

func update_sprite_frame():
	if abs(direction.y) > abs(direction.x):
		# Vertical
		sprite.frame = 4 if direction.y < 0 else 0
	else:
		# Horizontal
		sprite.frame = 8

	# Flip sprite if going left
	sprite.flip_h = direction.x < 0
