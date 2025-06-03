extends CharacterBody2D

@export var speed: float = 40.0            # How fast the butterfly moves
@export var change_interval: float = 1.5   # How often to change direction
@export var max_angle_change: float = 1.0  # Max random turn angle (in radians)

var direction: Vector2 = Vector2.RIGHT
var time_accumulator: float = 0.0

func _ready():
	_randomize_direction()

func _physics_process(delta):
	time_accumulator += delta
	if time_accumulator >= change_interval:
		_randomize_direction()
		time_accumulator = 0.0

	velocity = direction * speed
	move_and_slide()

func _randomize_direction():
	# Random angle between -max_angle_change and +max_angle_change
	var angle = randf_range(-max_angle_change, max_angle_change)
	direction = direction.rotated(angle).normalized()
