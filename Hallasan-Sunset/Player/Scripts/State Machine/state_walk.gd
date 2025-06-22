class_name State_Walk extends State

@export var move_speed: float = 40.0
@export var stair_speed_multiplier: float = 0.65  # Speed reduction on stairs (65% of normal speed)
@export var stair_accel_multiplier: float = 0.7  # Acceleration reduction on stairs
@export var stair_friction_multiplier: float = 1.3  # Increased friction on stairs for more control
@export var dash_speed: float = 100.0
@export var dash_duration: float = 0.7  # Duration of the dash in seconds
@export var max_speed: float = 85.0
@export var accel: float = 1200.0
@export var friction: float = 600.0

@onready var ghost_timer = $ghost_timer

@export var player_hud_path: String = "res://Hallasan-Sunset/Player/GUI/Player_hud/player_hud.tscn"
@export var ghost_node : PackedScene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/DashGhost.tscn")

var dash_scene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/dash.tscn")
var dash_ghost = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/DashGhost.tscn")

@onready var idle: State = $"../Idle"
@onready var attack: State = $"../Attack"
@onready var walk_left_audio: AudioStreamPlayer2D = $"../../Audio/Walk"
@onready var dust_particles: GPUParticles2D = $"../../Effects & Particles/DustParticles"
@onready var dash_audio = $"../../Audio/Dash"
@onready var hit_box = $"../../Interactions/HitBox"
@onready var animation_player = $"../../AnimationPlayer"
@onready var sprite = $"../../Sprite2D"
@onready var dash_node = $"../../Abilities/Dash"

var sound_cooldown: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var input: Vector2 = Vector2.ZERO
var direction = Vector2.ZERO
var Player: CharacterBody2D
var current_effective_speed: float
var current_effective_accel: float
var current_effective_friction: float
var is_on_stairs: bool = false
var stair_transition_speed: float = 0.15  # How quickly to transition between speeds

func _ready() -> void:
	current_effective_speed = move_speed
	current_effective_accel = accel
	current_effective_friction = friction

func enter() -> void:
	player.UpdateAnimation("walk")
	sound_cooldown = 0.0
	dust_particles.emitting = true
	is_dashing = false
	# Initialize effective values
	current_effective_speed = move_speed
	current_effective_accel = accel
	current_effective_friction = friction

func exit() -> void:
	dust_particles.emitting = false

func Process(_delta: float) -> State:
	if player.direction == Vector2.ZERO and not is_dashing:
		return idle
	return null

func Physics(_delta: float) -> State:
	# Check if player is on stairs
	check_stair_tile()
	
	if is_dashing:
		dash_timer -= _delta
		if dash_timer <= 0.0:
			is_dashing = false
			ghost_timer.stop()  # Stop spawning ghosts when dash ends
			hit_box.is_invulnerable = false
			player.velocity = player.direction * current_effective_speed  # Use current effective speed
			player.UpdateAnimation("walk")
		else:
			player.velocity = player.direction * dash_speed
	else:
		handle_walking(_delta)

	# Smoothly transition velocity to avoid staggering after a dash
	if not is_dashing and input != Vector2.ZERO:
		player.velocity = player.velocity.lerp(input * current_effective_speed, 0.2)

	player.move_and_slide()  # Ensure this uses calculated velocity
	return null

func handle_input(_event: InputEvent) -> State:
	if _event.is_action_pressed("attack"):
		return attack
	if _event.is_action_pressed("dash"):
		if player.current_energy > 0:
			player.current_energy -= 1
			PlayerManager.energy_changed.emit()
			start_dashing()
	return null

func handle_walking(delta: float):
	input = get_input()

	# Use current effective values (which change based on stairs)
	var effective_friction = current_effective_friction
	var effective_accel = current_effective_accel

	# Apply friction if there's no input, otherwise accelerate
	if input == Vector2.ZERO:
		if player.velocity.length() > (effective_friction * delta):
			player.velocity -= player.velocity.normalized() * (effective_friction * delta)
		else:
			player.velocity = Vector2.ZERO
	else:
		player.velocity += input * effective_accel * delta
		# Use current effective speed for limit_length
		var speed_limit = max_speed if not is_on_stairs else max_speed * stair_speed_multiplier
		player.velocity = player.velocity.limit_length(speed_limit)

	# Update player animation
	if player.set_direction():
		player.UpdateAnimation("walk")

func get_input() -> Vector2:
	var direction = Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	)
	return direction.normalized()

func check_stair_tile():
	# Find the stair TileMapLayer using the "stair" group
	var stair_tilemap = get_tree().get_first_node_in_group("stair")
	
	if not stair_tilemap:
		update_stair_status(false)
		return
	
	# Convert player position to tile coordinates
	var player_pos = player.global_position
	var local_pos = stair_tilemap.to_local(player_pos)
	var tile_pos = stair_tilemap.local_to_map(local_pos)
	
	# Check if there's a tile at this position in the stair layer
	var source_id = stair_tilemap.get_cell_source_id(tile_pos)
	
	# Update stair status based on tile presence
	update_stair_status(source_id != -1)

func update_stair_status(on_stairs: bool):
	if on_stairs and not is_on_stairs:
		# Just stepped onto stairs
		is_on_stairs = true
		# Smoothly transition to stair movement values
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(set_effective_speed, current_effective_speed, move_speed * stair_speed_multiplier, stair_transition_speed)
		tween.tween_method(set_effective_accel, current_effective_accel, accel * stair_accel_multiplier, stair_transition_speed)
		tween.tween_method(set_effective_friction, current_effective_friction, friction * stair_friction_multiplier, stair_transition_speed)
		
		# Reduce dust particles on stairs (more controlled movement)
		if dust_particles:
			dust_particles.amount_ratio = 0.6
		
	elif not on_stairs and is_on_stairs:
		# Just stepped off stairs
		is_on_stairs = false
		# Smoothly transition back to normal movement values
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(set_effective_speed, current_effective_speed, move_speed, stair_transition_speed)
		tween.tween_method(set_effective_accel, current_effective_accel, accel, stair_transition_speed)
		tween.tween_method(set_effective_friction, current_effective_friction, friction, stair_transition_speed)
		
		# Restore full dust particles
		if dust_particles:
			dust_particles.amount_ratio = 1.0

func set_effective_speed(value: float):
	current_effective_speed = value

func set_effective_accel(value: float):
	current_effective_accel = value

func set_effective_friction(value: float):
	current_effective_friction = value

func start_dashing() -> bool:
	is_dashing = true
	ghost_timer.start()  # Start spawning ghosts during the dash
	player.UpdateAnimation("dodge")
	animation_player.play("dodge_" + player.AnimDirection())
	hit_box.is_invulnerable = true
	dash_audio.play()
	dash_timer = dash_duration
	add_ghost()
	return true

func _on_AnimationPlayer_animation_finished(animation_name: String):
	if animation_name.begins_with("dodge_"):
		if player.direction != Vector2.ZERO:
			player.UpdateAnimation("walk")
		else:
			player.UpdateAnimation("idle")

func add_ghost():
	var ghost = ghost_node.instantiate()
	ghost.position = sprite.global_position  # Use the Sprite2D's global position
	ghost.scale = sprite.scale  # Set the scale to match the player's sprite
	ghost.texture = sprite.texture  # Update ghost texture to match player's
	get_tree().current_scene.add_child(ghost)
