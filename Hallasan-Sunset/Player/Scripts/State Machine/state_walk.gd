class_name State_Walk extends State

@export var move_speed: float = 40.0
@export var dash_speed: float = 100.0
@export var dash_duration: float = 0.7  # Duration of the dash in seconds
@export var max_speed: float = 85.0
@export var accel: float = 1200.0
@export var friction: float = 600.0

@onready var ghost_timer = $ghost_timer

@export var player_hud_path: String = "res://Hallasan-Sunset/Player/GUI/Player_hud/player_hud.tscn"
@export var ghost_node : PackedScene = preload("res://Hallasan-Sunset/Player/Technical/Moves/Dash/DashGhost.tscn")

var dash_scene = preload("res://Hallasan-Sunset/Player/Technical/Moves/Dash/dash.tscn")
var dash_ghost = preload("res://Hallasan-Sunset/Player/Technical/Moves/Dash/DashGhost.tscn")

@onready var idle: State = $"../Idle"
@onready var attack: State = $"../Attack"
@onready var walk_left_audio: AudioStreamPlayer2D = $"../../Audio/Walk"
@onready var dust_particles: GPUParticles2D = $"../../Effects & Particles/DustParticles"
@onready var dash_particles: GPUParticles2D = $"../../DashParticles"  # Optional: for dash effect
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

func _ready() -> void:
	pass

func enter() -> void:
	player.UpdateAnimation("walk")
	sound_cooldown = 0.0
	dust_particles.emitting = true
	is_dashing = false

func exit() -> void:
	dust_particles.emitting = false
	if dash_particles:
		dash_particles.emitting = false

func Process(_delta: float) -> State:
	if player.direction == Vector2.ZERO and not is_dashing:
		return idle
	return null



func Physics(_delta: float) -> State:
	if is_dashing:
		dash_timer -= _delta
		if dash_timer <= 0.0:
			is_dashing = false
			ghost_timer.stop()  # Stop spawning ghosts when dash ends
			hit_box.is_invulnerable = false
			player.velocity = player.direction * move_speed  # Revert to walking speed after dash
			player.UpdateAnimation("walk")
			if dash_particles:
				dash_particles.emitting = false
		else:
			player.velocity = player.direction * dash_speed
	else:
		handle_walking(_delta)

	# Smoothly transition velocity to avoid staggering after a dash
	if not is_dashing and input != Vector2.ZERO:
		player.velocity = player.velocity.lerp(input * move_speed, 0.2)

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

	# Apply friction if there's no input, otherwise accelerate
	if input == Vector2.ZERO:
		if player.velocity.length() > (friction * delta):
			player.velocity -= player.velocity.normalized() * (friction * delta)
		else:
			player.velocity = Vector2.ZERO
	else:
		player.velocity += input * accel * delta
		player.velocity = player.velocity.limit_length(max_speed)

	# Update player animation
	if player.set_direction():
		player.UpdateAnimation("walk")

func get_input() -> Vector2:
	var direction = Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	)
	return direction.normalized()

func start_dashing() -> bool:
	is_dashing = true
	ghost_timer.start()  # Start spawning ghosts during the dash
	player.UpdateAnimation("dodge")
	animation_player.play("dodge_" + player.AnimDirection())
	hit_box.is_invulnerable = true
	dash_audio.play()
	dash_timer = dash_duration
	add_ghost()

	if dash_particles:
		dash_particles.emitting = true

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

func _on_ghost_timer_timeout():
	if is_dashing:  # Only spawn ghosts while dashing
		add_ghost()
