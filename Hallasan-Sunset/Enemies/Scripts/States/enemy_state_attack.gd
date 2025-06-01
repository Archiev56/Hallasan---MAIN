class_name EnemyStateAttack extends EnemyState

@export var anim_name : String = "attack"
@export var attack_cooldown : float = 1.5
@export var attack_range : float = 40.0
@export var attack_damage : int = 10
@export var next_state : EnemyState

@export_category("AI")
@export var attack_area : HurtBox

var _timer : float = 0.0
var _can_attack : bool = true

## Initialization
func init() -> void:
	if attack_area:
		attack_area.monitoring = true
		attack_area.did_damage.connect(_on_attack_area_did_damage)
	pass

## On Entering Attack State
func enter() -> void:
	enemy.update_animation(anim_name)
	_timer = attack_cooldown
	_can_attack = true
	if attack_area:
		attack_area.monitoring = true
	pass

## On Exiting Attack State
func exit() -> void:
	if attack_area:
		attack_area.monitoring = false
	_can_attack = false
	pass

## Process (Checks player range and attacks)
func process(_delta: float) -> EnemyState:
	var distance_to_player = enemy.global_position.distance_to(PlayerManager.player.global_position)

	if distance_to_player > attack_range:
		return next_state  # Switch back to chase or other state
	
	_timer -= _delta
	
	if _can_attack and _timer <= 0:
		perform_attack()
		_timer = attack_cooldown
	
	return null

## Optional Physics (if needed)
func physics(_delta: float) -> EnemyState:
	return null

## Perform the attack animation and setup
func perform_attack() -> void:
	enemy.update_animation(anim_name)
	# The actual damage will be applied when the HurtBox emits did_damage
	pass

## Handle damage when the HurtBox detects a collision
func _on_attack_area_did_damage() -> void:
	# You can optionally call apply_damage here, or assume the HitBox handles damage
	# For example:
	# PlayerManager.player.apply_damage(attack_damage)
	pass
