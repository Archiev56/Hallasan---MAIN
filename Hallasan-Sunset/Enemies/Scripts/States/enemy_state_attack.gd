class_name EnemyStateAttack
extends EnemyState

@export var anim_name : String = "Attack"
@export var attack_cooldown : float = 1.5
@export var attack_range : float = 40.0
@export var attack_damage : int = 10
@export var next_state : EnemyState

@export_category("AI")
@export var attack_area : HurtBox

# --- Teleport (post-attack) options (no animations/tweens used) ---
@export_category("Teleport (Post-Attack)")
@export var enable_post_attack_teleport: bool = false
@export var teleport_min_distance: float = 96.0
@export var teleport_max_distance: float = 160.0
@export var teleport_retries: int = 8
@export var face_player_on_arrival: bool = true
@export var disable_hurtbox_during_teleport: bool = true

var _timer : float = 0.0

## Initialization
func init() -> void:
	if attack_area:
		attack_area.monitoring = true
		if attack_area.has_signal("did_damage") and not attack_area.did_damage.is_connected(_on_attack_area_did_damage):
			attack_area.did_damage.connect(_on_attack_area_did_damage)

## On Entering Attack State
func enter() -> void:
	enemy.update_animation(anim_name) # harmless if you don't use animations
	_timer = attack_cooldown
	if attack_area:
		attack_area.monitoring = true

## On Exiting Attack State
func exit() -> void:
	if attack_area:
		attack_area.monitoring = false

## Process (Checks player range and attacks)
func process(_delta: float) -> EnemyState:
	var player := PlayerManager.player
	if player == null:
		return null

	var distance_to_player := enemy.global_position.distance_to(player.global_position)
	if distance_to_player > attack_range:
		return next_state  # Switch back to chase or other state
	
	_timer -= _delta
	
	if _timer <= 0.0:
		perform_attack()
		_timer = attack_cooldown
	
	return null

## Optional Physics (if needed)
func physics(_delta: float) -> EnemyState:
	return null

## Perform the attack and (optionally) instant-teleport
func perform_attack() -> void:
	# Start/refresh attack anim if you eventually add it; otherwise this is a no-op
	enemy.update_animation(anim_name)

	# Damage application is still driven by the HurtBox (collision)
	# If you want to gate teleport on *successful* hit only, move _do_post_attack_teleport()
	# into _on_attack_area_did_damage() instead.
	if enable_post_attack_teleport:
		_do_post_attack_teleport()

## Handle damage when the HurtBox detects a collision
func _on_attack_area_did_damage() -> void:
	# Optional: if you want teleport only after landing a hit, call _do_post_attack_teleport() here
	# if enable_post_attack_teleport:
	#     _do_post_attack_teleport()
	pass

# --- Teleport helpers (instant; no tweens/animations) ---

func _do_post_attack_teleport() -> void:
	var player := PlayerManager.player
	if player == null:
		return

	# Optionally disable our attack area during the blink to avoid phantom hits
	var prev_monitoring := false
	if attack_area and disable_hurtbox_during_teleport:
		prev_monitoring = attack_area.monitoring
		attack_area.monitoring = false

	# Stop moving during the blink
	if "velocity" in enemy:
		enemy.velocity = Vector2.ZERO

	# Pick a destination and teleport instantly
	var dest := _pick_teleport_destination(player.global_position)
	enemy.global_position = dest

	# Face the player on arrival (if your enemy supports it)
	if face_player_on_arrival and enemy.has_method("set_direction"):
		var to_player := enemy.global_position.direction_to(player.global_position)
		enemy.set_direction(to_player)

	# Restore hurtbox state
	if attack_area and disable_hurtbox_during_teleport:
		attack_area.monitoring = prev_monitoring

func _pick_teleport_destination(center: Vector2) -> Vector2:
	var last_valid := enemy.global_position
	for i in teleport_retries:
		var ang := randf() * TAU
		var dist := randf_range(teleport_min_distance, teleport_max_distance)
		var candidate := center + Vector2(cos(ang), sin(ang)) * dist
		# If you have Navigation/physics checks, do them here and set last_valid accordingly
		last_valid = candidate
		break
	return last_valid
