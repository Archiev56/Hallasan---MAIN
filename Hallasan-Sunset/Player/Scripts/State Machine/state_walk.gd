class_name State_Walk
extends State

@export var move_speed: float = 40.0
@export var stair_speed_multiplier: float = 0.65
@export var stair_accel_multiplier: float = 0.7
@export var stair_friction_multiplier: float = 1.3
@export var dash_speed: float = 100.0
@export var dash_duration: float = 0.7
@export var max_speed: float = 85.0
@export var accel: float = 1200.0
@export var friction: float = 600.0

# New juicy parameters
@export_group("Movement Feel")
@export var movement_smoothing: float = 0.15  # How smooth direction changes are
@export var stop_snap: float = 0.8  # How quickly player stops (0-1)
@export var corner_cutting: float = 0.3  # Smooth diagonal movement
@export var momentum_preservation: float = 0.2  # Keep some velocity when changing direction

@export_group("Visual Effects")
@export var footstep_interval: float = 0.35  # Time between footsteps
@export var sprint_footstep_multiplier: float = 0.6  # Faster footsteps when sprinting
@export var camera_shake_intensity: float = 2.0
@export var sprite_bob_intensity: float = 1.5  # How much sprite bobs while walking
@export var sprite_tilt_intensity: float = 3.0  # Sprite tilting on direction changes
@export var dust_burst_threshold: float = 0.4  # Speed threshold for dust bursts

@onready var ghost_timer = $ghost_timer
@onready var camera_shake_timer = Timer.new()

@export var player_hud_path: String = "res://Hallasan-Sunset/Player/GUI/Player_hud/player_hud.tscn"
@export var ghost_node: PackedScene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/DashGhost.tscn")

var dash_scene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/dash.tscn")
var dash_ghost = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/DashGhost.tscn")

@onready var idle: State = get_node("../Idle")
@onready var attack: State = get_node("../Attack")
@onready var walk_left_audio: AudioStreamPlayer2D = get_node("../../Audio/Walk")
@onready var dust_particles: GPUParticles2D = get_node("../../Effects & Particles/DustParticles")
@onready var dash_audio = get_node("../../Audio/Dash")
@onready var hit_box = get_node("../../Interactions/HitBox")
@onready var animation_player = get_node("../../AnimationPlayer")
@onready var sprite = get_node("../../Sprite2D")
@onready var dash_node = get_node("../../Abilities/Dash")

var sound_cooldown: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var input: Vector2 = Vector2.ZERO
var direction = Vector2.ZERO
var last_direction = Vector2.ZERO
var Player: CharacterBody2D
var current_effective_speed: float
var current_effective_accel: float
var current_effective_friction: float
var is_on_stairs: bool = false
var stair_transition_speed: float = 0.15

# New juicy variables
var movement_time: float = 0.0
var last_speed: float = 0.0
var sprite_original_position: Vector2
var current_sprite_tilt: float = 0.0
var velocity_history: Array[Vector2] = []
var surface_type: String = "default"
var direction_change_intensity: float = 0.0

func _ready() -> void:
	current_effective_speed = move_speed
	current_effective_accel = accel
	current_effective_friction = friction
	
	# Setup timers
	add_child(camera_shake_timer)
	
	sprite_original_position = sprite.position
	
	# Initialize velocity history
	velocity_history.resize(5)
	velocity_history.fill(Vector2.ZERO)

func enter() -> void:
	player.UpdateAnimation("walk")
	sound_cooldown = 0.0
	dust_particles.emitting = true
	is_dashing = false
	current_effective_speed = move_speed
	current_effective_accel = accel
	current_effective_friction = friction
	movement_time = 0.0

func exit() -> void:
	dust_particles.emitting = false
	
	# Reset sprite position and rotation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", sprite_original_position, 0.2)
	tween.tween_property(sprite, "rotation", 0.0, 0.2)

func Process(_delta: float) -> State:
	if player.direction == Vector2.ZERO and not is_dashing:
		return idle
	
	movement_time += _delta
	update_visual_effects(_delta)
	return null

func Physics(_delta: float) -> State:
	check_stair_tile()
	
	# Store velocity history for momentum effects
	velocity_history.push_back(player.velocity)
	if velocity_history.size() > 5:
		velocity_history.pop_front()

	if is_dashing:
		handle_dashing(_delta)
	else:
		handle_walking(_delta)

	player.move_and_slide()
	
	# Update last direction for visual effects
	if player.direction != Vector2.ZERO:
		last_direction = player.direction
	
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

func handle_dashing(_delta: float):
	dash_timer -= _delta
	if dash_timer <= 0.0:
		is_dashing = false
		ghost_timer.stop()
		hit_box.is_invulnerable = false
		player.velocity = player.direction * current_effective_speed
		player.UpdateAnimation("walk")
		
		# Dash ending effect
		create_dash_stop_effect()
	else:
		player.velocity = player.direction * dash_speed

func handle_walking(delta: float):
	input = get_input()
	
	var is_sprinting = Input.is_action_pressed("Sprint")
	var sprint_multiplier = 1.5
	
	# Calculate direction change intensity for visual effects
	if input != Vector2.ZERO and last_direction != Vector2.ZERO:
		direction_change_intensity = input.angle_to(last_direction)
	
	var effective_friction = current_effective_friction
	var effective_accel = current_effective_accel
	var effective_speed = current_effective_speed
	
	if is_sprinting:
		effective_speed *= sprint_multiplier
		effective_accel *= sprint_multiplier

	# NO SLIDING - Instant stop when no input
	if input == Vector2.ZERO:
		player.velocity = Vector2.ZERO
		create_stop_effect()
	else:
		# Smooth acceleration with momentum preservation
		var target_velocity = input * effective_speed
		
		# Add momentum preservation for smoother direction changes
		if last_speed > 0 and player.velocity.length() > 0:
			var momentum = player.velocity.normalized() * last_speed * momentum_preservation
			target_velocity += momentum
		
		# Apply corner cutting for diagonal movement
		if input.x != 0 and input.y != 0:
			target_velocity *= (1.0 + corner_cutting)
		
		player.velocity = player.velocity.lerp(target_velocity, 1.0 - movement_smoothing)
		
		# Apply speed limits
		var speed_limit = max_speed if not is_on_stairs else max_speed * stair_speed_multiplier
		speed_limit = speed_limit if not is_sprinting else speed_limit * sprint_multiplier
		player.velocity = player.velocity.limit_length(speed_limit)
		
		# Create movement effects
		handle_movement_effects(is_sprinting)
	
	last_speed = player.velocity.length()
	
	if player.set_direction():
		player.UpdateAnimation("walk")

func get_input() -> Vector2:
	var direction = Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	)
	return direction.normalized()

func update_visual_effects(delta: float):
	# Sprite bobbing while walking
	if player.velocity.length() > 10:
		var bob_offset = sin(movement_time * 12.0) * sprite_bob_intensity
		sprite.position.y = sprite_original_position.y + bob_offset
		
		# Sprite tilting based on direction changes
		var target_tilt = direction_change_intensity * sprite_tilt_intensity
		current_sprite_tilt = lerp(current_sprite_tilt, target_tilt, 8.0 * delta)
		sprite.rotation = current_sprite_tilt * 0.1
		
		# Reduce direction change intensity over time
		direction_change_intensity = lerp(direction_change_intensity, 0.0, 5.0 * delta)

func handle_movement_effects(is_sprinting: bool):
	var current_speed = player.velocity.length()
	
	# Dust particle effects based on speed
	if dust_particles:
		var intensity = clamp(current_speed / max_speed, 0.3, 1.0)
		dust_particles.amount_ratio = intensity
		
		# Extra dust burst for sudden acceleration
		if current_speed > last_speed + dust_burst_threshold:
			create_dust_burst()
	
	# Camera shake for sprinting
	if is_sprinting and current_speed > 50:
		add_camera_shake(camera_shake_intensity * 0.1)

func create_stop_effect():
	# Small dust puff when stopping
	if last_speed > 30:
		create_dust_burst()

func create_dust_burst():
	# Enhanced dust effect for sudden movements
	if dust_particles:
		var original_amount = dust_particles.amount_ratio
		dust_particles.amount_ratio = 1.5
		
		var tween = create_tween()
		tween.tween_property(dust_particles, "amount_ratio", original_amount, 0.3)

func create_dash_stop_effect():
	# Special effect when dash ends
	add_camera_shake(camera_shake_intensity * 0.5)
	create_dust_burst()

func add_camera_shake(intensity: float):
	# Simple camera shake (you can connect this to your camera system)
	if sprite:
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		sprite.position += shake_offset
		
		# Return to normal position quickly
		var tween = create_tween()
		tween.tween_property(sprite, "position", sprite_original_position, 0.1)

func check_stair_tile():
	var stair_tilemap = get_tree().get_first_node_in_group("stair")

	if not stair_tilemap:
		update_stair_status(false)
		return

	var player_pos = player.global_position
	var local_pos = stair_tilemap.to_local(player_pos)
	var tile_pos = stair_tilemap.local_to_map(local_pos)

	var source_id = stair_tilemap.get_cell_source_id(tile_pos)
	update_stair_status(source_id != -1)

func update_stair_status(on_stairs: bool):
	if on_stairs and not is_on_stairs:
		is_on_stairs = true
		surface_type = "stairs"
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(set_effective_speed, current_effective_speed, move_speed * stair_speed_multiplier, stair_transition_speed)
		tween.tween_method(set_effective_accel, current_effective_accel, accel * stair_accel_multiplier, stair_transition_speed)
		tween.tween_method(set_effective_friction, current_effective_friction, friction * stair_friction_multiplier, stair_transition_speed)

		if dust_particles:
			dust_particles.amount_ratio = 0.6
			
		# Visual feedback for surface change
		add_camera_shake(camera_shake_intensity * 0.2)

	elif not on_stairs and is_on_stairs:
		is_on_stairs = false
		surface_type = "default"
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(set_effective_speed, current_effective_speed, move_speed, stair_transition_speed)
		tween.tween_method(set_effective_accel, current_effective_accel, accel, stair_transition_speed)
		tween.tween_method(set_effective_friction, current_effective_friction, friction, stair_transition_speed)

		if dust_particles:
			dust_particles.amount_ratio = 1.0
			
		# Visual feedback for surface change
		add_camera_shake(camera_shake_intensity * 0.2)

func set_effective_speed(value: float):
	current_effective_speed = value

func set_effective_accel(value: float):
	current_effective_accel = value

func set_effective_friction(value: float):
	current_effective_friction = value

func start_dashing() -> bool:
	is_dashing = true
	ghost_timer.start()
	player.UpdateAnimation("dodge")
	animation_player.play("dodge_" + player.AnimDirection())
	hit_box.is_invulnerable = true
	dash_audio.play()
	dash_timer = dash_duration
	add_ghost()
	
	# Extra juice for dash start
	add_camera_shake(camera_shake_intensity)
	create_dust_burst()
	
	return true

func _on_AnimationPlayer_animation_finished(animation_name: String):
	if animation_name.begins_with("dodge_"):
		if player.direction != Vector2.ZERO:
			player.UpdateAnimation("walk")
		else:
			player.UpdateAnimation("idle")

func add_ghost():
	var ghost = ghost_node.instantiate()
	ghost.position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.texture = sprite.texture
	get_tree().current_scene.add_child(ghost)
