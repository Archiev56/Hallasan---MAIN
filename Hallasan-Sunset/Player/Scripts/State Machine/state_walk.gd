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

@onready var ghost_timer = $ghost_timer

@export var player_hud_path: String = "res://Hallasan-Sunset/Player/GUI/Player_hud/player_hud.tscn"
@export var ghost_node : PackedScene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/DashGhost.tscn")

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
var Player: CharacterBody2D
var current_effective_speed: float
var current_effective_accel: float
var current_effective_friction: float
var is_on_stairs: bool = false
var stair_transition_speed: float = 0.15

func _ready() -> void:
	current_effective_speed = move_speed
	current_effective_accel = accel
	current_effective_friction = friction

func enter() -> void:
	player.UpdateAnimation("walk")
	sound_cooldown = 0.0
	dust_particles.emitting = true
	is_dashing = false
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
	check_stair_tile()

	if is_dashing:
		dash_timer -= _delta
		if dash_timer <= 0.0:
			is_dashing = false
			ghost_timer.stop()
			hit_box.is_invulnerable = false
			player.velocity = player.direction * current_effective_speed
			player.UpdateAnimation("walk")
		else:
			player.velocity = player.direction * dash_speed
	else:
		handle_walking(_delta)

	if not is_dashing and input != Vector2.ZERO:
		player.velocity = player.velocity.lerp(input * current_effective_speed, 0.2)

	player.move_and_slide()
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

	var is_sprinting = Input.is_action_pressed("Sprint")
	var sprint_multiplier = 1.5

	var effective_friction = current_effective_friction
	var effective_accel = current_effective_accel
	var effective_speed = current_effective_speed

	if is_sprinting:
		effective_speed *= sprint_multiplier
		effective_accel *= sprint_multiplier

	if input == Vector2.ZERO:
		if player.velocity.length() > (effective_friction * delta):
			player.velocity -= player.velocity.normalized() * (effective_friction * delta)
		else:
			player.velocity = Vector2.ZERO
	else:
		player.velocity += input * effective_accel * delta
		var speed_limit = max_speed if not is_on_stairs else max_speed * stair_speed_multiplier
		speed_limit = speed_limit if not is_sprinting else speed_limit * sprint_multiplier
		player.velocity = player.velocity.limit_length(speed_limit)

	if player.set_direction():
		player.UpdateAnimation("walk")

func get_input() -> Vector2:
	var direction = Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	)
	return direction.normalized()

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
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(set_effective_speed, current_effective_speed, move_speed * stair_speed_multiplier, stair_transition_speed)
		tween.tween_method(set_effective_accel, current_effective_accel, accel * stair_accel_multiplier, stair_transition_speed)
		tween.tween_method(set_effective_friction, current_effective_friction, friction * stair_friction_multiplier, stair_transition_speed)

		if dust_particles:
			dust_particles.amount_ratio = 0.6

	elif not on_stairs and is_on_stairs:
		is_on_stairs = false
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(set_effective_speed, current_effective_speed, move_speed, stair_transition_speed)
		tween.tween_method(set_effective_accel, current_effective_accel, accel, stair_transition_speed)
		tween.tween_method(set_effective_friction, current_effective_friction, friction, stair_transition_speed)

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
	ghost_timer.start()
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
	ghost.position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.texture = sprite.texture
	get_tree().current_scene.add_child(ghost)
