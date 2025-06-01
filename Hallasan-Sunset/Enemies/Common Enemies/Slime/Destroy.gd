class_name EnemyStateDestroy extends EnemyState

const PICKUP = preload("res://Hallasan-Sunset/Items/Technical/item_pickup/item_pickup.tscn")

@export var anim_name : String = "destroy"
@export var knockback_speed : float = 850.0
@export var decelerate_speed : float = 10.0

@export_category("AI")

signal defeated

@export_category("Item Drops")
@export var drops : Array[ DropData ]

var _damage_position : Vector2
var _direction : Vector2
var time_scale = 1

## What happens when we initialize this state?
func init() -> void:
	enemy.enemy_destroyed.connect( _on_enemy_destroyed )
	pass


## What happens when the enemy enters this State?
func enter() -> void:
	enemy.invulnerable = true
	_direction = enemy.global_position.direction_to( _damage_position )
	enemy.set_direction( _direction )
	enemy.velocity = _direction * -knockback_speed
	enemy.update_animation( anim_name )
	enemy.animation_player.animation_finished.connect( _on_animation_finished )
	disable_hurt_box()
	frameFreeze(0.1, 0.03)
	drop_items()
	PlayerManager.reward_xp(enemy.xp_reward)

	pass


## What happens when the enemy exits this State?
func exit() -> void:
	pass


## What happens during the _process update in this State?
func process( _delta : float ) -> EnemyState:
	enemy.velocity -= enemy.velocity * decelerate_speed * _delta
	return null


## What happens during the _physics_process update in this State?
func physics( _delta : float ) -> EnemyState:
	return null


func _on_enemy_destroyed( hurt_box : HurtBox ) -> void:
	_damage_position = hurt_box.global_position
	state_machine.change_state( self )
	defeated.emit()
	


func _on_animation_finished( _a : String ) -> void:
	enemy.queue_free()



func disable_hurt_box() -> void:
	var hurt_box : HurtBox = enemy.get_node_or_null("HurtBox")
	if hurt_box:
		hurt_box.monitoring = false


func drop_items() -> void:
	if drops.size() == 0:
		return
	
	for i in drops.size():
		if drops[ i ] == null or drops[ i ].item == null:
			continue
		var drop_count : int = drops[ i ].get_drop_count()
		for j in drop_count:
			var drop : ItemPickup = PICKUP.instantiate() as ItemPickup
			drop.item_data = drops[ i ].item
			enemy.get_parent().call_deferred( "add_child", drop )
			drop.global_position = enemy.global_position
			drop.velocity = enemy.velocity.rotated( randf_range( -1, 2.5 ) ) * randf_range( 0.9 , 1.5 )
	pass

func frameFreeze(timeScale, duration):
	Engine.time_scale = timeScale  # Set the game's time scale (e.g., freeze with 0.0 or slow down with < 1.0)
	await(get_tree().create_timer(duration * time_scale).timeout)  # Wait for the duration scaled by timeScale
	Engine.time_scale = 1.0  # Reset the time scale back to normal
