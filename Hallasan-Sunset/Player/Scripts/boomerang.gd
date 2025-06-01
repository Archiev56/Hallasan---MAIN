class_name Boomerang extends Node2D

enum State { INACTIVE, THROW, RETURN }

var player : Player
var direction : Vector2
var speed : float = 0
var state

@export var acceleration : float = 500.0
@export var max_speed : float = 400.0
@export var catch_audio : AudioStream

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var fist_grab: Area2D = $Fist_Grab

func _ready() -> void:
	visible = false
	state = State.INACTIVE
	player = PlayerManager.player

func _physics_process(delta: float) -> void:
	if state == State.THROW:
		speed -= acceleration * delta
		position += direction * speed * delta
		if speed <= 0:
			state = State.RETURN
	elif state == State.RETURN:
		direction = global_position.direction_to(player.global_position)
		speed += acceleration * delta
		position += direction * speed * delta
		if global_position.distance_to(player.global_position) <= 10:
			PlayerManager.play_audio(catch_audio)
			if fist_grab.item_carried:
				fist_grab.item_carried.throwable.player_interact()
			queue_free()
	
	var speed_ratio = speed / max_speed
	audio.pitch_scale = speed_ratio * 0.75 + 0.75
	animation_player.speed_scale = 1 + (speed_ratio * 0.25)

func throw(throw_direction: Vector2) -> void:
	player.UpdateAnimation("fist")
	direction = throw_direction
	speed = max_speed
	state = State.THROW

	# Determine animation based on direction
	if abs(direction.x) > abs(direction.y):
		# Horizontal direction
		if direction.x > 0:
			scale.x = 1  # Ensure sprite is not flipped
			animation_player.play("fist_side")
		else:
			scale.x = -1  # Flip sprite horizontally
			animation_player.play("fist_side")
	else:
		# Vertical direction
		scale.x = 1  # Reset flip to default for vertical animations
		if direction.y > 0:
			animation_player.play("fist_down")
		else:
			animation_player.play("fist_up")
	
	PlayerManager.play_audio(catch_audio)
	player.UpdateAnimation("catch")
	visible = true
