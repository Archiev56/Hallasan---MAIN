extends State
class_name State_boomerang

var boomerang : bool = false

enum State { INACTIVE, THROW, RETURN }

var direction : Vector2 = Vector2.ZERO
var speed : float = 0.0
var state

@export var acceleration : float = 500.0
@export var max_speed : float = 400.0
@export var catch_audio : AudioStream
@export var attack_sound : AudioStream
@export_range(1, 20, 0.5) var decelerate_speed : float = 5.0

@onready var idle : State = $"../Idle"
@onready var walk : State = $"../Walk"
@onready var animation_player : AnimationPlayer = $"../../AnimationPlayer"
@onready var audio : AudioStreamPlayer2D = $"../../Audio/AudioStreamPlayer2D"
@onready var hurt_box : HurtBox = $"../../Interactions/HurtBox"



func _ready():
	# Initialize player reference (adjust path if needed)
	player = get_parent().get_parent()
	if not player:
		print("Error: Player reference not found")

# Method called when entering the boomerang state
func enter() -> void:
	player.UpdateAnimation("boomerang")
	animation_player.animation_finished.connect(_end_boomerang)
	boomerang = true

	pass

# Method called when exiting the boomerang state
func exit() -> void:
	animation_player.animation_finished.disconnect(_end_boomerang)
	boomerang = false
	hurt_box.monitoring = false

	pass

# Process method for general updates
func Process(_delta: float) -> State:
	player.velocity -= player.velocity * decelerate_speed * _delta
	if not boomerang:
		if player.direction == Vector2.ZERO:
			return idle
		else:
			return walk
	return null

# Physics update for handling boomerang movement
func Physics(_delta: float) -> State:
	return null

# Main physics processing for the boomerang state
func _physics_process(delta: float) -> void:
	if state == State.THROW:
		speed -= acceleration * delta
		player.global_position += direction * speed * delta
		if speed <= 0:
			state = State.RETURN
	elif state == State.RETURN:
		player.direction = player.global_position.direction_to(player.global_position)
		speed += acceleration * delta
		player.global_position += direction * speed * delta
		if player.global_position.distance_to(player.global_position) <= 10:
			PlayerManager.play_audio(catch_audio)
			queue_free()

	# Adjust audio and animation speed based on current speed
	var speed_ratio = speed / max_speed
	audio.pitch_scale = speed_ratio * 0.75 + 0.75
	animation_player.speed_scale = 1 + (speed_ratio * 0.25)

# Method to handle the boomerang throw
func throw(throw_direction: Vector2) -> void:
	direction = throw_direction
	speed = max_speed
	state = State.THROW
	animation_player.play("boomerang")
	PlayerManager.play_audio(attack_sound)
	boomerang = true


# Input handling method (currently not used in this state)
func handle_input(_event: InputEvent) -> State:
	return null

# Callback method when the boomerang animation ends
func _end_boomerang(_newAnimName: String) -> void:
	boomerang = false
	pass
