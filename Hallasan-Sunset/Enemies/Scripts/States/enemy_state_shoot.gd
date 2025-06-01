class_name EnemyStateShoot extends EnemyState

@export_category("AI")

@export var anim_name: String = "shoot"
@export var ENERGY_BALL_SCENE: PackedScene
@export var audio_shoot: AudioStream
@export var vision_area: VisionArea
@export var attack_area: HurtBox
@export var next_state: EnemyState
@export var shoot_cooldown: float = 1.5  # Cooldown time in seconds between shots

var _can_see_player: bool = false
var _timer: float = 0.0  # Timer for controlling shooting interval
var _animation_finished: bool = false
var boss_node: Node2D

func init() -> void:
	if vision_area:
		vision_area.player_entered.connect(_on_player_enter)
		vision_area.player_exited.connect(_on_player_exit)

func enter() -> void:
	_can_see_player = true
	_timer = 0.0  # Reset the timer on state enter
	if attack_area:
		attack_area.monitoring = true
	enemy.update_animation(anim_name)

func _ready() -> void:
	boss_node = owner  # Assuming the enemy script is the owner

func shoot_orb() -> void:
	var eb: Node2D = ENERGY_BALL_SCENE.instantiate()
	eb.global_position = boss_node.global_position + Vector2(0, -34)
	get_parent().add_child.call_deferred(eb)

func physics(_delta: float) -> EnemyState:
	return null

func exit() -> void:
	if attack_area:
		attack_area.monitoring = false
	_can_see_player = false
	enemy.animation_player.animation_finished.disconnect(_on_animation_finished)

func process(_delta: float) -> EnemyState:
	if not _can_see_player:
		_timer -= _delta
		if _timer < 0:
			return next_state
		return null

	# Shooting logic
	if _can_see_player:
		_timer -= _delta
		if _timer <= 0.0:
			shoot_orb()
			_timer = shoot_cooldown  # Reset the cooldown timer

	return null

func _on_player_enter() -> void:
	_can_see_player = true
	if state_machine.current_state in [EnemyStateStun, EnemyStateDestroy]:
		return
	state_machine.change_state(self)

func _on_player_exit() -> void:
	_can_see_player = false

func _on_animation_finished(_a: String) -> void:
	_animation_finished = true
