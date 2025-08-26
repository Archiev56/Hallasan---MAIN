class_name EnemyStateDestroy
extends EnemyState

const PICKUP := preload("res://Hallasan-Sunset/Items/Technical/item_pickup/item_pickup.tscn")

@export var anim_name: String = "destroy"

# Kept for inspector compatibility but unused in this simple version
@export var knockback_speed: float = 0.0
@export var decelerate_speed: float = 10.0
@export var rotation_speed: float = 0.0
@export var flight_duration: float = 0.0

@export_category("Simple FX")
@export var do_screen_shake: bool = true
@export var screen_shake_intensity: float = 8.0
@export var screen_shake_duration: float = 0.22
@export var vanish_duration: float = 2.0   # kept for compatibility; not used

@export_category("AI")
signal defeated

@export_category("Item Drops")
@export var drops: Array[DropData]

var damage_position: Vector2

func init() -> void:
	if not enemy.enemy_destroyed.is_connected(on_enemy_destroyed):
		enemy.enemy_destroyed.connect(on_enemy_destroyed)

func enter() -> void:
	enemy.invulnerable = true
	enemy.velocity = Vector2.ZERO
	disable_hurt_box()

	# optional screen shake
	if do_screen_shake:
		_add_screen_shake(screen_shake_intensity, screen_shake_duration)

	# play death animation (connect BEFORE starting to avoid race conditions)
	if anim_name != "":
		if enemy.animation_player and not enemy.animation_player.animation_finished.is_connected(on_animation_finished):
			enemy.animation_player.animation_finished.connect(on_animation_finished, CONNECT_ONE_SHOT)
		if enemy.has_method("update_animation"):
			enemy.update_animation(anim_name)

	# drop rewards immediately
	_drop_items()
	PlayerManager.reward_xp(enemy.xp_reward)

	# if no animation, free right away
	if anim_name == "":
		_queue_free()

func exit() -> void:
	# Nothing to restore in the simplified version
	pass

func process(_delta: float) -> EnemyState:
	# No flight/knockback/scale/fade logic
	return null

func physics(_delta: float) -> EnemyState:
	# Ensure no movement while dying
	enemy.velocity = Vector2.ZERO
	return null

func on_enemy_destroyed(hurt_box: HurtBox) -> void:
	damage_position = hurt_box.global_position
	state_machine.change_state(self)
	defeated.emit()

func on_animation_finished(_a: StringName) -> void:
	_queue_free()

func disable_hurt_box() -> void:
	var hurt_box := enemy.get_node_or_null("HurtBox") as HurtBox
	if hurt_box:
		hurt_box.monitoring = false

func _drop_items() -> void:
	if drops.is_empty():
		return
	var parent := enemy.get_parent()
	for data in drops:
		if data == null or data.item == null:
			continue
		var count := data.get_drop_count()
		for i in count:
			var drop := PICKUP.instantiate() as ItemPickup
			drop.item_data = data.item
			parent.call_deferred("add_child", drop)
			# spawn at enemy position; no scatter physics here
			var pos := enemy.global_position
			drop.call_deferred("set", "global_position", pos)

func _add_screen_shake(intensity: float, duration: float) -> void:
	if not do_screen_shake:
		return
	if PlayerManager.has_method("add_screen_shake"):
		PlayerManager.add_screen_shake(intensity, duration)

func _queue_free() -> void:
	if enemy == null:
		return
	enemy.queue_free()
