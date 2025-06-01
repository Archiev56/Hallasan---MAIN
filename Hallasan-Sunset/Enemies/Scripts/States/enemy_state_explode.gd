class_name EnemyStateExplode extends EnemyState

## Stores a reference to the enemy that this state belongs to
@export var next_state : EnemyState
@onready var animation_player = $"../../AnimationPlayer"
@export_category("AI")

## What happens when we initialize this state?
func init() -> void:
	pass

## What happens when the enemy enters this State?
func enter() -> void:
	animation_player.play("explosion")
	enemy.velocity = Vector2.ZERO  # Disable movement
	pass

## What happens when the enemy exits this State?
func exit() -> void:
	pass

## What happens during the _process update in this State?
func process(_delta: float) -> EnemyState:
	return null

## What happens during the _physics_process update in this State?
func physics(_delta: float) -> EnemyState:
	return null
