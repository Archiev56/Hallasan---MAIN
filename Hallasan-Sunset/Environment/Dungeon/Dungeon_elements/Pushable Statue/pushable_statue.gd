# Enhanced PushableStatue script
class_name PushableStatue
extends RigidBody2D

# ============================================================
#  EXPORTS
# ============================================================
@export var push_speed: float = 60.0
@export var friction_coefficient: float = 0.95  # Increased friction for less sliding
@export var min_push_threshold: float = 0.05
@export var max_push_speed: float = 150.0
@export var shove_decay: float = 0.95  # Much higher decay - less sliding

# ============================================================
#  STATE
# ============================================================
var push_direction: Vector2 = Vector2.ZERO : set = set_push
var is_being_pushed: bool = false
var push_force_magnitude: float = 0.0

# Shove system
var shove_velocity: Vector2 = Vector2.ZERO
var is_being_shoved: bool = false

# Player movement system (when grabbed by fist)
var player_ref: Node2D = null
var is_following_player: bool = false
var follow_speed: float = 80.0
var follow_distance_threshold: float = 20.0  # Minimum distance before moving

# ============================================================
#  ONREADY NODES
# ============================================================
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

# ============================================================
#  PHYSICS
# ============================================================
func _physics_process(delta: float) -> void:
	# Handle shove decay (much more aggressive)
	if is_being_shoved:
		shove_velocity *= shove_decay
		if shove_velocity.length() < 15.0:  # Higher threshold for stopping
			shove_velocity = Vector2.ZERO
			is_being_shoved = false
	
	# Combine all forces
	var total_velocity = Vector2.ZERO
	
	# Player following has highest priority
	if is_following_player and player_ref and is_instance_valid(player_ref):
		var follow_velocity = _calculate_follow_velocity()
		if follow_velocity != Vector2.ZERO:
			total_velocity = follow_velocity
		else:
			# If not moving toward player, check other forces
			total_velocity = _calculate_other_forces()
	else:
		total_velocity = _calculate_other_forces()
	
	# Apply the velocity
	if total_velocity != Vector2.ZERO:
		# Clamp to max speed
		if total_velocity.length() > max_push_speed:
			total_velocity = total_velocity.normalized() * max_push_speed
		linear_velocity = total_velocity
	else:
		# Apply strong friction when not being moved
		linear_velocity = linear_velocity.lerp(Vector2.ZERO, friction_coefficient * delta)
		
		# Stop completely if velocity is very small (higher threshold)
		if linear_velocity.length() < 8.0:
			linear_velocity = Vector2.ZERO

func _calculate_follow_velocity() -> Vector2:
	"""Calculate velocity to follow the player"""
	if not player_ref or not is_instance_valid(player_ref):
		return Vector2.ZERO
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	
	# Only move if player is far enough away
	if distance_to_player < follow_distance_threshold:
		return Vector2.ZERO
	
	# Calculate direction to player (8-directional, smooth movement)
	var direction_to_player = (player_ref.global_position - global_position).normalized()
	
	# Calculate follow velocity with distance-based speed
	var speed_multiplier = clamp(distance_to_player / 100.0, 0.5, 1.5)
	var follow_velocity = direction_to_player * follow_speed * speed_multiplier
	
	return follow_velocity

func _calculate_other_forces() -> Vector2:
	"""Calculate velocity from push forces and shoves when not following player"""
	var total_velocity = Vector2.ZERO
	
	# Add push force (traditional pushing) - keep 4-directional for push/pull
	if is_being_pushed and push_force_magnitude > min_push_threshold:
		var cardinal_push = _get_cardinal_direction(push_direction)
		total_velocity += cardinal_push * push_speed
	
	# Add shove force (smooth 8-directional)
	if is_being_shoved:
		total_velocity += shove_velocity
	
	return total_velocity

# ============================================================
#  4-DIRECTIONAL CONVERSION
# ============================================================
func _get_cardinal_direction(direction: Vector2) -> Vector2:
	if direction.length() == 0:
		return Vector2.ZERO
		
	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)
	
	if abs_x > abs_y:
		# Horizontal movement
		return Vector2(1.0 if direction.x > 0 else -1.0, 0.0)
	else:
		# Vertical movement
		return Vector2(0.0, 1.0 if direction.y > 0 else -1.0)

# ============================================================
#  PUSH/SHOVE SYSTEM
# ============================================================
func set_push(value: Vector2) -> void:
	push_direction = value
	push_force_magnitude = value.length()
	is_being_pushed = push_force_magnitude > 0.0
	
	# Handle audio
	var should_play_effects = (is_being_pushed and push_force_magnitude > min_push_threshold) or is_being_shoved or is_following_player
	
	if should_play_effects:
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()

func apply_shove(shove_force: Vector2) -> void:
	# Keep shove in 8-directional for smooth contact behavior
	var new_shove_velocity = shove_force
	
	# If already being shoved in same direction, add to it; otherwise replace
	if is_being_shoved:
		var current_dir = shove_velocity.normalized()
		var new_dir = new_shove_velocity.normalized()
		var dot_product = current_dir.dot(new_dir)
		
		if dot_product > 0.5:  # Similar direction
			# Same general direction, add forces
			shove_velocity += new_shove_velocity * 0.5  # Reduced to prevent excessive speeds
		else:
			# Different direction, replace
			shove_velocity = new_shove_velocity
	else:
		shove_velocity = new_shove_velocity
	
	is_being_shoved = true
	
	print("💥 Applied shove: ", shove_force.normalized(), " with force: ", shove_force.length())
	
	# Play audio for shove
	if not audio.playing:
		audio.play()

func stop_pushing() -> void:
	push_direction = Vector2.ZERO
	is_being_pushed = false
	
	# If not following player, stop all movement instantly
	if not is_following_player:
		linear_velocity = Vector2.ZERO

func get_push_strength() -> float:
	return push_force_magnitude

func is_moveable() -> bool:
	return true

func start_following_player(player: Node2D) -> void:
	"""Start following the player when grabbed by fist"""
	player_ref = player
	is_following_player = true
	print("🎯 Statue started following player")
	
	# Play audio
	if not audio.playing:
		audio.play()

func stop_following_player() -> void:
	"""Stop following the player"""
	player_ref = null
	is_following_player = false
	
	# Instantly stop all movement and forces
	linear_velocity = Vector2.ZERO
	shove_velocity = Vector2.ZERO
	is_being_shoved = false
	
	print("🛑 Statue stopped following player - movement halted")
