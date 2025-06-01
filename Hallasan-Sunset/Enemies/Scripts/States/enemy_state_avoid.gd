class_name EnemyStateAvoid extends EnemyState

const PATHFINDER : PackedScene = preload("res://Technical/Pathfinder/Path Finder.tscn")

@export var anim_name : String = "avoid"
@export var avoid_speed : float = 40.0
@export var turn_rate : float = 0.5

@export_category("AI")
@export var vision_area : VisionArea
@export var state_aggro_duration : float = 0.5
@export var next_state : EnemyState

var pathfinder = Pathfinder

var _timer : float = 0.0
var _direction : Vector2
var _can_see_player : bool = false

## Initialize this state
func init() -> void:
	if vision_area:
		vision_area.player_entered.connect(_on_player_enter)
		vision_area.player_exited.connect(_on_player_exit)
	pass

## Enter this state
func enter() -> void:
	pathfinder = PATHFINDER.instantiate() as Pathfinder
	enemy.add_child(pathfinder)

	_timer = state_aggro_duration
	enemy.update_animation(anim_name)
	_can_see_player = true
	pass

## Exit this state
func exit() -> void:
	pathfinder.queue_free()
	_can_see_player = false
	pass

## Process during update
func process(_delta : float) -> EnemyState:
	if PlayerManager.player.hp <= 0:
		return next_state

	if _can_see_player:
		# Calculate direction away from the player
		var player_position = PlayerManager.player.global_position
		_direction = lerp(_direction, enemy.global_position.direction_to(player_position) * -1, turn_rate)
		enemy.velocity = _direction * avoid_speed

		if enemy.set_direction(_direction):
			enemy.update_animation(anim_name)
		
		_timer = state_aggro_duration
	else:
		_timer -= _delta
		if _timer < 0:
			return next_state
	
	return null

## Handle physics updates
func physics(_delta : float) -> EnemyState:
	return null

## Event for when the player enters the vision area
func _on_player_enter() -> void:
	_can_see_player = true
	pass

## Event for when the player exits the vision area
func _on_player_exit() -> void:
	_can_see_player = false
	pass
