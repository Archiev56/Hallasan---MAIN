class_name EnemyStateChase extends EnemyState

const PATHFINDER : PackedScene = preload("res://Hallasan-Sunset/Technical/Pathfinder/Path Finder.tscn")

@export var anim_name : String = "chase"
@export var chase_speed : float = 40.0
@export var turn_rate : float = 0.5

@export_category("AI")
@export var vision_area : VisionArea
@export var attack_area : HurtBox
@export var state_aggro_duration : float = 5
@export var next_state : EnemyState
@export var attack_state : EnemyState  # Add this export to specify attack state

var pathfinder = Pathfinder
var _timer : float = 0.0
var _direction : Vector2
var _can_see_player : bool = false

func init() -> void:
	if vision_area:
		vision_area.player_entered.connect(_on_player_enter)
		vision_area.player_exited.connect(_on_player_exit)
	if attack_area:
		attack_area.did_damage.connect(_on_attack_area_hit)
	pass

func enter() -> void:
	pathfinder = PATHFINDER.instantiate() as Pathfinder
	enemy.add_child(pathfinder)
	
	_timer = state_aggro_duration
	enemy.update_animation(anim_name)
	_can_see_player = true
	if attack_area:
		attack_area.monitoring = true
	pass

func exit() -> void:
	pathfinder.queue_free()
	if attack_area:
		attack_area.monitoring = false
	_can_see_player = false
	pass

func process(_delta : float) -> EnemyState:
	var distance_to_player = enemy.global_position.distance_to(PlayerManager.player.global_position)
	if distance_to_player <= 40:
		return next_state
	
	_direction = lerp(_direction, pathfinder.move_dir, turn_rate)
	enemy.velocity = _direction * chase_speed
	if enemy.set_direction(_direction):
		enemy.update_animation(anim_name)
	
	if _can_see_player == false:
		_timer -= _delta
		if _timer < 0:
			return next_state
	else:
		_timer = state_aggro_duration
	return null

func physics(_delta : float) -> EnemyState:
	return null

func _on_player_enter() -> void:
	_can_see_player = true
	if state_machine.current_state is EnemyStateStun or state_machine.current_state is EnemyStateDestroy:
		return
	state_machine.change_state(self)
	pass

func _on_player_exit() -> void:
	_can_see_player = false
	pass

# New signal handler for attack_area hitbox detection
func _on_attack_area_hit() -> void:
	if attack_state:
		state_machine.change_state(attack_state)
