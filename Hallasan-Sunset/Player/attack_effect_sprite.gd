extends Sprite2D
@onready var animation_player = $AnimationPlayer

var DIR_8 = []

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO

func UpdateAnimation(state: String) -> void:
	animation_player.play(state + "_" + AnimDirection())

func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	elif cardinal_direction == Vector2.RIGHT:
		return "side"  # Right movement (sprite flipped for left)
	elif cardinal_direction == Vector2.LEFT:
		return "side"  # Left movement (normal sprite)
	elif cardinal_direction == Vector2(1, 1).normalized():
		return "diagonal_down_right"
	elif cardinal_direction == Vector2(-1, 1).normalized():
		return "diagonal_down_left"
	elif cardinal_direction == Vector2(1, -1).normalized():
		return "diagonal_up_right"
	elif cardinal_direction == Vector2(-1, -1).normalized():
		return "diagonal_up_left"
	else:
		return "side"  # Default to side if undefined
