class_name Dash extends Node2D

const dash_delay := 0.4

@onready var duration_timer: Timer = $DurationTimer
@onready var ghost_timer: Timer = $GhostTimer
@onready var dust_trail: GPUParticles2D = $DustTrail
@onready var dust_burst: GPUParticles2D = $DustBurst

@export var ghosts_per_second: float = 60.0   # raise for denser trail
@export var ghosts_per_tick: int = 1          # spawn multiple per timer tick
@export var burst_on_start: int = 1           # extra ghosts right when dash starts

var ghost_scene: PackedScene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Dash/DashGhost.tscn")
var can_dash := true
var direction := Vector2.ZERO

func _ready() -> void:
	ghost_timer.one_shot = false
	# ✅ Correct: choose physics or idle callback
	ghost_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_update_ghost_timer()

func _update_ghost_timer() -> void:
	var gps: float = max(1.0, ghosts_per_second)
	var interval: float = 1.0 / gps
	ghost_timer.wait_time = max(0.005, interval)

func instance_ghost() -> void:
	var ghost: Sprite2D = ghost_scene.instantiate()
	get_parent().get_parent().add_child(ghost)
	ghost.global_position = global_position

func start_dash(duration: float) -> void:
	duration_timer.wait_time = duration
	duration_timer.start()

	_update_ghost_timer()
	ghost_timer.start()

	# Initial burst
	for i in range(burst_on_start):
		instance_ghost()

	print("Dash started")
	dust_trail.restart()
	dust_trail.emitting = true

	dust_burst.rotation = (direction * -1.0).angle()
	dust_burst.restart()
	dust_burst.emitting = true

func is_dashing() -> bool:
	return !duration_timer.is_stopped()

func _on_duration_timer_timeout() -> void:
	print("Dash ended")
	ghost_timer.stop()
	dust_trail.emitting = false
	dust_burst.emitting = false

func _on_ghost_timer_timeout() -> void:
	for i in range(ghosts_per_tick):
		instance_ghost()
