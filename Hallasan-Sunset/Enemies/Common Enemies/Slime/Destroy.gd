class_name EnemyStateDestroy extends EnemyState

const PICKUP = preload("res://Hallasan-Sunset/Items/Technical/item_pickup/item_pickup.tscn")

@export var anim_name : String = "destroy"
@export var knockback_speed : float = 850.0
@export var decelerate_speed : float = 10.0
@export var rotation_speed : float = 720.0  # Degrees per second during flight
@export var flight_duration : float = 0.8  # How long to fly before exploding

@export_category("Juice Effects")
@export var screen_shake_intensity : float = 8.0
@export var screen_shake_duration : float = 0.3
@export var death_scale_duration : float = 0.4

@export_category("AI")
signal defeated

@export_category("Item Drops")
@export var drops : Array[DropData]

var damage_position : Vector2
var _direction : Vector2
var time_scale = 1
var _original_rotation : float
var _flight_timer : float = 0.0

enum DestroyPhase {
	FLYING,
	DEATH_ANIMATION
}

var _current_phase : DestroyPhase = DestroyPhase.FLYING

func init() -> void:
	enemy.enemy_destroyed.connect(on_enemy_destroyed)

func enter() -> void:
	enemy.invulnerable = true
	_direction = enemy.global_position.direction_to(damage_position)
	enemy.set_direction(_direction)
	enemy.velocity = _direction * -knockback_speed
	_original_rotation = enemy.rotation
	
	# Start flying phase with timer
	_current_phase = DestroyPhase.FLYING
	_flight_timer = 0.0
	
	disable_hurt_box()
	
	# Add screen shake for initial impact
	add_screen_shake(screen_shake_intensity * 0.5, 0.2)

func exit() -> void:
	# Reset rotation
	if enemy:
		enemy.rotation = _original_rotation

func process(delta : float) -> EnemyState:
	match _current_phase:
		DestroyPhase.FLYING:
			return process_flying_phase(delta)
		DestroyPhase.DEATH_ANIMATION:
			return process_death_phase(delta)
	
	return null

func physics(delta : float) -> EnemyState:
	match _current_phase:
		DestroyPhase.FLYING:
			return physics_flying_phase(delta)
		DestroyPhase.DEATH_ANIMATION:
			return physics_death_phase(delta)
	
	return null

func process_flying_phase(delta : float) -> EnemyState:
	_flight_timer += delta
	
	# Add rotation during flight for more dynamic feel
	enemy.rotation += deg_to_rad(rotation_speed) * delta * sign(enemy.velocity.x)
	
	# Slight deceleration over time
	enemy.velocity -= enemy.velocity * (decelerate_speed * 0.3) * delta
	
	# Check if flight time is up
	if _flight_timer >= flight_duration:
		start_death_sequence()
	
	return null

func process_death_phase(_delta : float) -> EnemyState:
	# Death animation is playing, nothing special needed
	return null

func physics_flying_phase(_delta : float) -> EnemyState:
	# Just move the enemy, no collision detection needed
	enemy.move_and_slide()
	return null

func physics_death_phase(_delta : float) -> EnemyState:
	# Enemy should be stationary during death animation
	enemy.velocity = Vector2.ZERO
	return null

func start_death_sequence() -> void:
	_current_phase = DestroyPhase.DEATH_ANIMATION
	
	# Stop movement
	enemy.velocity = Vector2.ZERO
	
	# Impact effects
	add_screen_shake(screen_shake_intensity, screen_shake_duration)
	
	# Reset rotation with a smooth tween
	var tween = create_tween()
	tween.tween_property(enemy, "rotation", _original_rotation, 0.2)
	tween.tween_callback(start_death_animation)

func start_death_animation() -> void:
	# Play death animation
	enemy.update_animation(anim_name)
	enemy.animation_player.animation_finished.connect(on_animation_finished)
	
	# Juicy death effects
	add_death_effects()
	
	# Award XP and drop items
	drop_items()
	PlayerManager.reward_xp(enemy.xp_reward)

func add_death_effects() -> void:
	# Scale effect during death
	var original_scale = enemy.scale
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pulse effect
	tween.tween_property(enemy, "scale", original_scale * 1.2, death_scale_duration * 0.3)
	tween.tween_property(enemy, "scale", original_scale * 0.8, death_scale_duration * 0.7)
	tween.chain().tween_property(enemy, "scale", Vector2.ZERO, death_scale_duration * 0.3)
	
	# Optional: Add modulate flash effect
	tween.tween_property(enemy, "modulate", Color.WHITE, 0.1)
	tween.tween_property(enemy, "modulate", Color.RED, 0.1)
	tween.chain().tween_property(enemy, "modulate", Color.WHITE, 0.1)

func add_screen_shake(intensity: float, duration: float) -> void:
	# Call screen shake through PlayerManager
	if PlayerManager.has_method("add_screen_shake"):
		PlayerManager.add_screen_shake(intensity, duration)

func on_enemy_destroyed(hurt_box : HurtBox) -> void:
	damage_position = hurt_box.global_position
	state_machine.change_state(self)
	defeated.emit()

func on_animation_finished(_a : String) -> void:
	# Final dramatic pause before cleanup
	await get_tree().create_timer(0.1).timeout
	enemy.queue_free()

func disable_hurt_box() -> void:
	var hurt_box : HurtBox = enemy.get_node_or_null("HurtBox")
	if hurt_box:
		hurt_box.monitoring = false

func drop_items() -> void:
	if drops.size() == 0:
		return
	
	for i in drops.size():
		if drops[i] == null or drops[i].item == null:
			continue
		var drop_count : int = drops[i].get_drop_count()
		for j in drop_count:
			var drop : ItemPickup = PICKUP.instantiate() as ItemPickup
			drop.item_data = drops[i].item
			enemy.get_parent().call_deferred("add_child", drop)
			drop.global_position = enemy.global_position
			
			# More dynamic item spreading
			var spread_angle = randf_range(-PI/2, PI/2)
			var spread_force = randf_range(100.0, 300.0)
			var base_velocity = _direction * -50.0  # Slight backward momentum
			drop.velocity = base_velocity + Vector2(cos(spread_angle), sin(spread_angle)) * spread_force
