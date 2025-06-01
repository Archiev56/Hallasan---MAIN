extends CharacterBody2D

const MOVE_SPEED = 25
const MOVE_INTERVAL_MIN = 1.0
const MOVE_INTERVAL_MAX = 3.0
const MAX_HEALTH = 4

var camera2D : Camera2D
var cameraShakeNoise : FastNoiseLite
var move_timer = 0.0
var move_interval = 0.0
var move_direction = Vector2.ZERO
var z_position = 0.0  # For Z-axis height simulation
var health: int = MAX_HEALTH
var is_hurt = false  # New variable to prevent interruption of hurt animation

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Slime
@onready var hitbox : Area2D = $HitBox
@onready var player : Player = get_node("/root/playground/Player")
@onready var progress_bar = $ProgressBar # Make sure this path is correct!
@onready var gpu_particles_2d = $GPUParticles2D
func _ready():
	choose_new_direction()
	# Connect the player's Hurt_box signal to detect when the bee enters

	progress_bar.value = health  # Set the initial health
	camera2D = get_node("/root/playground/Player/Camera2D")
	cameraShakeNoise = FastNoiseLite.new()
	$HitBox.damaged.connect(Callable(self, "take_damage"))

# Setter for health to automatically handle damage and death
func set_health(value: int):
	health = value
	progress_bar.value = value
	if health <= 0:
		_die()

# Choose a new random direction and set a timer for how long to move in that direction
func choose_new_direction():
	move_interval = randf_range(MOVE_INTERVAL_MIN, MOVE_INTERVAL_MAX)
	move_timer = move_interval
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

# Handle enemy movement and collision logic
func _physics_process(delta):
	if is_hurt:
		return  # Skip movement while hurt

	move_timer -= delta
	if move_timer <= 0.0:
		choose_new_direction()

	var motion = move_direction * MOVE_SPEED * delta
	var collision = move_and_collide(motion)

	# Play animation based on movement
	update_animation(motion)

	# If there's a collision, choose a new direction
	if collision:
		choose_new_direction()

# Function to handle animations based on movement and direction, with sprite flipping for left/right
func update_animation(motion: Vector2) -> void:
	if is_hurt:
		return  # Don't interrupt hurt animation

	if motion.length() > 0:  # If the slime is moving
		if abs(motion.y) > abs(motion.x):  # Moving up or down
			if motion.y > 0:
				animation_player.play("walk_down")
			else:
				animation_player.play("walk_up")
		else:  # Moving sideways
			animation_player.play("walk_side")
			if sprite != null:
				if motion.x > 0:
					sprite.flip_h = false  # Moving right, no flip
				elif motion.x < 0:
					sprite.flip_h = true  # Moving left, flip the sprite horizontally
	else:  # Slime is idle
		if abs(move_direction.y) > abs(move_direction.x):  # Idle facing up or down
			if move_direction.y > 0:
				animation_player.play("idle_down")
			else:
				animation_player.play("idle_up")
		else:  # Idle facing sideways
			animation_player.play("idle_side")
			if sprite != null:
				if move_direction.x > 0:
					sprite.flip_h = false  # Last direction was right
				elif move_direction.x < 0:
					sprite.flip_h = true  # Last direction was left

# Simulate taking damage on the Z-axis (or general damage from hits)
func _on_hurt_box_entered(body: Node):
	# Check if the slime enters the player's Hurt_box and the player is actively attacking
	if body == self and player.is_attacking:
		_on_hitbox_damaged(1)

# Function to handle damage to the slime
func _on_hitbox_damaged(damage: int):
	if is_hurt:
		_on_hitbox_damaged(1)
		return  # Ignore if already in the hurt state

	is_hurt = true
	health -= damage
	$Slime2.play()
	update_health(health)
	
	var tween = get_tree().create_tween()
	tween.tween_method(SetShader_BlinkIntensity, 1.0, 0.0, 0.5)
	

	
	gpu_particles_2d.restart()
	gpu_particles_2d.emitting = true

	# Play the hurt animation based on the direction the slime is facing
	play_hurt_animation()

	# Wait for the hurt animation to complete before allowing movement again
	await animation_player.animation_finished
	is_hurt = false

	if health <= 0:
		_die()
		
func take_damage(damage: int) -> void:
	cameraShakeNoise = FastNoiseLite.new()
	var camera_tween = get_tree().create_tween()

	health -= damage  # Deduct health by the given damage amount
	update_health(health)  # Update any health-related UI or logic

	# If health is 0 or less, call the death function
	if health <= 0:
		_die()


# Play the correct hurt animation based on slime's facing direction
func play_hurt_animation():
	if abs(move_direction.y) > abs(move_direction.x):  # Facing up or down
		if move_direction.y > 0:
			animation_player.play("hurt_down")
		else:
			animation_player.play("hurt_up")
	else:  # Facing sideways
		if move_direction.x > 0:
			sprite.flip_h = false
			animation_player.play("hurt_side")
		elif move_direction.x < 0:
			sprite.flip_h = true
			animation_player.play("hurt_side")
		
func _on_hurt_box_body_entered(body):
	if body is Player:
		body.take_damage(1, global_position)  # Apply damage to the player

func SetShader_BlinkIntensity(newValue: float):
	sprite.material.set_shader_parameter("blink_intensity", newValue)
			

# Update health progress bar
func update_health(new_health: int):
	progress_bar.value = new_health

# Die function that removes the enemy from the scene when health is 0
func _die():
	queue_free()




