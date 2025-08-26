class_name PlayerAbilities
extends Node
# ============================================================
#  CONSTANTS & PRELOADS
# ============================================================
const BOOMERANG  = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist.tscn")
const ARROW      = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist_projectile/fist_projectile.tscn")
const SPIKE      = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Spike/Fist Spike.tscn")
const AIR_STRIKE = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Air Strike/Fist Air Strike.tscn")
const GRAPPLE_HOOK = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Grapple/Fist_Grapple.tscn")
const FIST_SMASH = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Smash/smash_effect.tscn")

# ============================================================
#  ONREADY NODES
# ============================================================
@onready var animation_player        = $"../AnimationPlayer"
@onready var effect_animation_player = $"../EffectAnimationPlayer"

@onready var smash_animation_player  = $"../Sprite2D/Smash Effect/Smash Effect/AnimationPlayer"
@onready var hurt_box: HurtBox       = $"../Interactions/HurtBox"
@onready var player_sprite: Sprite2D = $"../Sprite2D"      # kept for reference – never rotated

# ============================================================
#  STATE
# ============================================================
var abilities := ["BOOMERANG", "GRAPPLE", "BOW", "BOMB", "AIR_STRIKE", "ROCKET", "FIST_SMASH"]
var selected_ability: int = 0

enum ActionState { IDLE, FIRING, AIMING, ROCKET_RIDING, GRAPPLING }
var action_state: ActionState = ActionState.IDLE

var player: Player
var active_boomerangs: Array = []
var last_throw_direction := Vector2.RIGHT

# Arrow
var can_fire_arrow := true
var is_aiming      := false
var aim_direction  := Vector2.RIGHT
var aim_line: Line2D
var min_aim_time   := 0.2
var max_aim_time   := 2.0
var aim_start_time := 0.0
var aim_power      := 0.0

# Grapple System
var is_grappling: bool = false
var grappled_enemy: Enemy = null
var active_grapple_hook: GrappleHook = null
var grapple_line: Line2D = null
var grapple_pull_force: float = 600.0  # Slower than 800, faster than 300
var grapple_duration: float = 2.0  # Slightly longer for better control
var grapple_safe_radius: float = 200.0  # Safe zone around player
var grapple_start_time: float = 0.0

# Rocket
@export var rocket_texture : Texture2D
var is_rocket_riding := false
var rocket_duration := 5
var rocket_speed := 250.0
var rocket_direction := Vector2.RIGHT
var rocket_start_time := 0.0
var original_sprite_texture: Texture2D
var rocket_cooldown := 3.0
var can_use_rocket := true
var rocket_trail_particles: CPUParticles2D

# Time-scale
var normal_time_scale := 1.0
var aim_time_scale    := 0.3
var time_scale_transition_speed := 3.0

# Recoil
var recoil_force    := 25.0
var recoil_duration := 0.02

# ============================================================
#  READY
# ============================================================
func _ready() -> void:
	player = PlayerManager.player

	_setup_aim_line()
	_setup_grapple_line()
	_setup_rocket()

func _setup_aim_line() -> void:
	# Try to find existing Line2D in the scene first
	aim_line = get_tree().current_scene.get_node_or_null("AimLine")
	
	if not aim_line:
		# Create one if it doesn't exist
		aim_line = Line2D.new()
		aim_line.name = "AimLine"
		aim_line.width = 4.0
		aim_line.default_color = Color.YELLOW
		aim_line.z_index = 100  # Very high to ensure visibility
		aim_line.visible = false
		get_tree().current_scene.add_child(aim_line)
		print("🎯 Aim line created and added to scene")
	else:
		print("🎯 Found existing aim line in scene")
	
	aim_line.visible = false

func _setup_grapple_line() -> void:
	grapple_line = Line2D.new()
	grapple_line.name = "GrappleLine"
	grapple_line.width = 3.0
	grapple_line.default_color = Color.BROWN
	grapple_line.z_index = 50
	grapple_line.visible = false
	get_tree().current_scene.add_child(grapple_line)

func _setup_rocket() -> void:
	# Store original player appearance
	original_sprite_texture = player_sprite.texture

# ============================================================
#  INPUT
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	# Allow switching abilities during rocket ride but not other inputs
	if is_rocket_riding:
		if event.is_action_pressed("switch_ability"):
			_toggle_ability(-1)  # Left direction
		elif event.is_action_pressed("switch_ability_right"):
			_toggle_ability(1)   # Right direction
		return
	
	# swap ability any time - both directions
	if event.is_action_pressed("switch_ability"):
		_toggle_ability(-1)  # Left direction
		return
	elif event.is_action_pressed("switch_ability_right"):
		_toggle_ability(1)   # Right direction
		return
	
	# Handle ability release for bow (ability 2)
	if selected_ability == 2 and event.is_action_released("ability") and is_aiming:
		_fire_arrow()
		return
	
	# Handle ability press for all abilities
	if event.is_action_pressed("ability"):
		match selected_ability:
			0: # BOOMERANG
				_fire_fist()
				player.UpdateAnimation("attack")
			1: # GRAPPLE
				_fire_grapple_hook()
			2: # BOW
				if can_fire_arrow:
					_start_aiming()
			3: # BOMB
				animation_player.play("Summon")
				_spawn_spike()
				player.UpdateAnimation("attack")
			4: # AIR_STRIKE
				animation_player.play("Summon")
				_air_strike()
				player.UpdateAnimation("attack")
			5: # ROCKET
				effect_animation_player.play("Transform")
				_start_rocket_ride()
			6: # FIST_SMASH
				_fist_smash()

# ============================================================
#  GRAPPLE SYSTEM
# ============================================================
func _fire_grapple_hook() -> void:
	if is_grappling or action_state != ActionState.IDLE:
		return
	
	action_state = ActionState.FIRING
	
	# Create grapple hook
	active_grapple_hook = GRAPPLE_HOOK.instantiate()
	player.get_parent().add_child(active_grapple_hook)
	active_grapple_hook.global_position = player.global_position
	active_grapple_hook.set_direction(last_throw_direction)
	active_grapple_hook.set_player_reference(player)
	
	# Connect signals
	active_grapple_hook.enemy_grappled.connect(_on_enemy_grappled)
	active_grapple_hook.grapple_missed.connect(_on_grapple_missed)
	
	# Setup grapple line if not already done
	if not grapple_line:
		_setup_grapple_line()
	
	# Play animation
	player.UpdateAnimation("attack")
	
	print("🪝 Grapple hook fired!")

func _on_enemy_grappled(enemy: Enemy) -> void:
	print("🎯 Enemy grappled: ", enemy.name)
	
	is_grappling = true
	grappled_enemy = enemy
	grapple_start_time = _get_now_seconds()
	action_state = ActionState.GRAPPLING
	
	# Set up the grappled enemy
	enemy.get_grappled_by(player)
	
	# Show grapple line
	if grapple_line:
		grapple_line.visible = true
	
	# Start pulling the ENEMY towards the player
	_start_enemy_pull()

func _on_grapple_missed() -> void:
	print("❌ Grapple missed")
	action_state = ActionState.IDLE
	active_grapple_hook = null

func _start_enemy_pull() -> void:
	# Enemy gets pulled towards the player at controlled speed
	print("🪝 Starting controlled enemy pull towards player (safe radius: ", grapple_safe_radius, ")")
	
	# Add some visual flair when grapple starts
	if PlayerManager.has_method("add_screen_shake"):
		PlayerManager.add_screen_shake(3.0, 0.2)  # Moderate shake
	
	# Make grapple line thicker for more dramatic effect
	if grapple_line:
		grapple_line.width = 4.0
		grapple_line.default_color = Color.ORANGE  # Orange for controlled pull
	
	_update_enemy_pull()

func _update_enemy_pull() -> void:
	if not is_grappling or not grappled_enemy or not is_instance_valid(grappled_enemy):
		_end_grapple()
		return
	
	# Calculate pull force for ENEMY - straight line to player
	var distance_to_player = grappled_enemy.global_position.distance_to(player.global_position)
	var direction_to_player = (player.global_position - grappled_enemy.global_position).normalized()
	
	# Apply pull force with safe zone
	if distance_to_player > grapple_safe_radius:
		# Calculate pull strength based on distance - slower as enemy approaches safe zone
		var distance_factor = clamp((distance_to_player - grapple_safe_radius) / 500.0, 0.3, 1.0)
		var pull_velocity = direction_to_player * grapple_pull_force * distance_factor
		
		# Use direct velocity setting for immediate response
		if grappled_enemy.has_method("set_grapple_velocity"):
			grappled_enemy.set_grapple_velocity(pull_velocity)
		else:
			grappled_enemy.apply_grapple_force(pull_velocity)
		
		print("🪝 Pulling enemy towards player, distance: ", distance_to_player, " safe zone: ", grapple_safe_radius)
	else:
		print("✅ Enemy reached safe zone, ending grapple")
		
		# Add a small bounce away from player when reaching safe zone
		var bounce_direction = (grappled_enemy.global_position - player.global_position).normalized()
		if grappled_enemy.has_method("set_grapple_velocity"):
			grappled_enemy.set_grapple_velocity(bounce_direction * 100.0)  # Small bounce
		
		_end_grapple()
		return
	
	# Update grapple line
	_update_grapple_line()
	
	# Check for duration timeout
	var elapsed = _get_now_seconds() - grapple_start_time
	if elapsed >= grapple_duration:
		print("⏰ Grapple duration expired")
		_end_grapple()

func _update_grapple_line() -> void:
	if not grapple_line or not grappled_enemy or not is_instance_valid(grappled_enemy):
		return
	
	grapple_line.clear_points()
	grapple_line.add_point(player.global_position)
	grapple_line.add_point(grappled_enemy.global_position)
	
	# Change line color based on distance to safe zone
	var distance_to_player = grappled_enemy.global_position.distance_to(player.global_position)
	if distance_to_player <= grapple_safe_radius + 100.0:  # Close to safe zone
		grapple_line.default_color = Color.YELLOW  # Yellow when approaching safe zone
	else:
		grapple_line.default_color = Color.ORANGE  # Orange when pulling

func _end_grapple() -> void:
	print("🔗 Grapple ended")
	
	is_grappling = false
	
	# Release the enemy with a small bounce away from player
	if grappled_enemy and is_instance_valid(grappled_enemy):
		var distance = grappled_enemy.global_position.distance_to(player.global_position)
		if distance <= grapple_safe_radius + 10.0:  # If within safe zone
			# Small bounce away from player
			var bounce_direction = (grappled_enemy.global_position - player.global_position).normalized()
			if grappled_enemy.has_method("set_grapple_velocity"):
				grappled_enemy.set_grapple_velocity(bounce_direction * 80.0)  # Small bounce
		
		grappled_enemy.release_grapple()
	
	grappled_enemy = null
	
	# Hide grapple line and reset appearance
	if grapple_line:
		grapple_line.visible = false
		grapple_line.clear_points()
		grapple_line.width = 3.0  # Reset to normal width
		grapple_line.default_color = Color.BROWN  # Reset to normal color
	
	# Clean up hook
	if active_grapple_hook and is_instance_valid(active_grapple_hook):
		active_grapple_hook.queue_free()
	active_grapple_hook = null
	
	action_state = ActionState.IDLE

# ============================================================
#  ROCKET ABILITY (scaling removed)
# ============================================================
func _start_rocket_ride() -> void:
	if not can_use_rocket or action_state != ActionState.IDLE:
		return
	
	is_rocket_riding = true
	action_state = ActionState.ROCKET_RIDING
	rocket_start_time = _get_now_seconds()
	rocket_direction = last_throw_direction.normalized()
	can_use_rocket = false
	
	# Set rocket velocity
	player.velocity = rocket_direction * rocket_speed
	
	# Make player invulnerable during rocket ride
	if player.has_method("set_invulnerable"):
		player.set_invulnerable(true)
	
	# Create rocket trail effect
	_create_rocket_effects()
	
	# Play rocket animation BEFORE transforming to rocket
	player.UpdateAnimation("rocket_ride")
	
	# Transform player into rocket AFTER animation
	await get_tree().process_frame  # Wait one frame for animation to start
	_transform_to_rocket()

func _transform_to_rocket() -> void:
	# Change sprite to rocket texture if available
	if rocket_texture:
		print("Changing player sprite to rocket texture")
		player_sprite.texture = rocket_texture
		
		# Force the sprite to update and lock the texture
		player_sprite.modulate = Color.WHITE
		
		# Disable any animation player that might interfere
		if animation_player:
			animation_player.pause()
	else:
		print("No rocket texture assigned, using color change")
		# Fallback: color change
		var rocket_color = Color(1.2, 0.8, 0.3)  # Orange/yellow rocket color
		player_sprite.modulate = rocket_color
	
	# Create rocket trail particles
	_create_rocket_trail()
	
	# NOTE: Scaling removed - no longer scaling the sprite

func _create_rocket_effects() -> void:
	# Screen shake
	if PlayerManager.has_method("add_screen_shake"):
		PlayerManager.add_screen_shake(5.0, 0.3)

func _create_rocket_trail() -> void:
	# Create trail particles behind the rocket
	rocket_trail_particles = CPUParticles2D.new()
	player.add_child(rocket_trail_particles)
	
	# Position behind the rocket (opposite direction)
	var trail_offset = -rocket_direction.normalized() * 15.0
	rocket_trail_particles.position = trail_offset
	
	# Configure trail particles
	rocket_trail_particles.emitting = true
	rocket_trail_particles.amount = 20  # Increased for better effect
	rocket_trail_particles.lifetime = 0.6  # Longer for better effect
	rocket_trail_particles.explosiveness = 0.0  # Continuous emission
	
	# Particle emission shape - emit from behind rocket
	rocket_trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	rocket_trail_particles.emission_sphere_radius = 5.0  # Slightly larger emission area
	
	# Movement - particles shoot backward
	rocket_trail_particles.direction = -rocket_direction
	rocket_trail_particles.initial_velocity_min = 800.0
	rocket_trail_particles.initial_velocity_max = 200.0
	rocket_trail_particles.angular_velocity_min = -90.0
	rocket_trail_particles.angular_velocity_max = 90.0
	rocket_trail_particles.spread = 25.0  # Slightly wider cone spread
	
	# Physics
	rocket_trail_particles.gravity = Vector2.ZERO  # No gravity for rocket exhaust
	
	# SCALING: Start big, particles will appear to shrink through alpha fading
	rocket_trail_particles.scale_amount_min = 1.0  # Start bigger
	rocket_trail_particles.scale_amount_max = 2.0  # Even bigger initial range
	
	# Enhanced color gradient with dramatic fading (creates shrinking illusion)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))      # Bright white, full opacity
	gradient.add_point(0.1, Color(1.0, 1.0, 0.8, 0.9))      # Slight yellow tint
	gradient.add_point(0.25, Color(1.0, 0.8, 0.2, 0.8))     # Yellow flame, still strong
	gradient.add_point(0.4, Color(1.0, 0.5, 0.1, 0.6))      # Orange transition
	gradient.add_point(0.6, Color(0.9, 0.3, 0.1, 0.4))      # Red, getting transparent
	gradient.add_point(0.75, Color(0.6, 0.2, 0.1, 0.2))     # Dark red, very transparent
	gradient.add_point(0.9, Color(0.3, 0.1, 0.05, 0.1))     # Almost invisible
	gradient.add_point(1.0, Color.TRANSPARENT)               # Complete fade out
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	rocket_trail_particles.color_ramp = gradient_texture

func _update_rocket_trail() -> void:
	if rocket_trail_particles and is_rocket_riding:
		# Update trail position to stay behind rocket
		var trail_offset = -rocket_direction.normalized() * 15.0
		rocket_trail_particles.position = trail_offset
		
		# Update particle direction to shoot backwards
		rocket_trail_particles.direction = -rocket_direction
		

func _update_rocket_ride(_delta: float) -> void:
	if not is_rocket_riding:
		return
	
	# Ensure rocket texture stays applied throughout the ride (but don't change flip)
	if rocket_texture:
		if player_sprite.texture != rocket_texture:
			player_sprite.texture = rocket_texture
		# Don't update flip during ride - keep the original direction's flip state
	
	# Update rocket trail particles
	_update_rocket_trail()
	
	var current_time = _get_now_seconds()
	var elapsed = current_time - rocket_start_time
	
	# Continue rocket movement
	player.velocity = rocket_direction * rocket_speed
	
	# Check for collisions with walls (TileMapLayer) and enemies
	if player.get_slide_collision_count() > 0:
		for i in player.get_slide_collision_count():
			var collision = player.get_slide_collision(i)
			var collider = collision.get_collider()
			
			if collider:
				var is_wall = false
				var is_enemy_layer = false
				var is_enemy_group = collider.is_in_group("Enemy")
				
				# Check if collider is a TileMapLayer (walls/terrain)
				if collider is TileMapLayer:
					is_wall = true
				# Check if collider is a CollisionObject2D with collision layers
				elif collider is CollisionObject2D:
					var layer = collider.collision_layer
					is_wall = (layer & (1 << 4))  # Layer 5 (bit 4)
					is_enemy_layer = (layer & (1 << 8))  # Layer 9 (bit 8)
				
				print("Rocket collision with: ", collider.name, " Type: ", collider.get_class(), " IsWall: ", is_wall, " IsEnemyLayer: ", is_enemy_layer, " IsEnemyGroup: ", is_enemy_group)
				
				# Check if collision is with walls (TileMapLayer) or enemies
				if is_wall or is_enemy_layer or is_enemy_group:
					_create_collision_particles(collision.get_position())
					_end_rocket_ride_with_impact()
					return
	
	# End rocket ride after duration
	if elapsed >= rocket_duration:
		_end_rocket_ride()

func _cleanup_rocket_trail() -> void:
	if rocket_trail_particles:
		# Stop emitting new particles
		rocket_trail_particles.emitting = false
		
		# Let existing particles fade out naturally, then cleanup
		await get_tree().create_timer(rocket_trail_particles.lifetime).timeout
		rocket_trail_particles.queue_free()
		rocket_trail_particles = null

func _end_rocket_ride() -> void:
	_restore_player_appearance()
	is_rocket_riding = false
	action_state = ActionState.IDLE
	
	# Cleanup trail particles
	_cleanup_rocket_trail()
	
	# Gradual velocity reduction
	var tween = create_tween()
	tween.tween_property(player, "velocity", player.velocity * 0.3, 0.5)
	
	# Start cooldown
	_start_rocket_cooldown()

func _end_rocket_ride_with_impact() -> void:
	# More dramatic ending with impact effects
	_create_impact_effects()
	_restore_player_appearance()
	is_rocket_riding = false
	action_state = ActionState.IDLE
	
	# Cleanup trail particles
	_cleanup_rocket_trail()
	
	# Stronger recoil
	player.velocity = -rocket_direction * 100.0
	var tween = create_tween()
	tween.tween_property(player, "velocity", Vector2.ZERO, 0.8)
	
	# Damage nearby enemies
	_damage_nearby_enemies()
	
	# Start cooldown
	_start_rocket_cooldown()

func _create_impact_effects() -> void:
	# Screen shake
	if PlayerManager.has_method("add_screen_shake"):
		PlayerManager.add_screen_shake(10.0, 0.5)
	
	# Flash effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(player_sprite, "modulate", Color.RED, 0.1)
	tween.chain().tween_property(player_sprite, "modulate", Color.WHITE, 0.1)

func _create_collision_particles(collision_pos: Vector2) -> void:
	# Create explosion particles at collision point
	var particles = CPUParticles2D.new()
	player.get_parent().add_child(particles)
	particles.global_position = collision_pos
	
	# Configure explosion particles
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	# Particle appearance
	particles.texture = null  # Use default circle
	particles.emission_rect_extents = Vector2(5.0, 5.0)
	
	# Movement - using 2D properties
	particles.direction = Vector2(0, -1)  # Vector2 for 2D particles
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.spread = 45.0  # Spread angle in degrees
	
	# Physics
	particles.gravity = Vector2(0, 98)  # Vector2 for 2D gravity
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	
	# Colors - bright explosion colors
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.YELLOW)
	gradient.add_point(0.3, Color.ORANGE)
	gradient.add_point(0.7, Color.RED)
	gradient.add_point(1.0, Color.TRANSPARENT)
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particles.color_ramp = gradient_texture
	
	# Cleanup after particles finish
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()

func _damage_nearby_enemies() -> void:
	# Find enemies within impact radius
	var impact_radius = 100.0
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy is Node2D:
			var distance = player.global_position.distance_to(enemy.global_position)
			if distance <= impact_radius:
				# Deal damage to enemy
				if enemy.has_method("take_damage"):
					enemy.take_damage(50)  # Adjust damage as needed

func _restore_player_appearance() -> void:
	# Restore original sprite texture
	print("Restoring player sprite to original texture")
	player_sprite.texture = original_sprite_texture
	
	# Resume animation player if it was paused
	if animation_player and not animation_player.is_playing():
		animation_player.play()
	
	# Restore color (no more scale restoration)
	var tween = create_tween()
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.2)
	
	# Remove invulnerability
	if player.has_method("set_invulnerable"):
		player.set_invulnerable(false)

func _start_rocket_cooldown() -> void:
	await get_tree().create_timer(rocket_cooldown).timeout
	can_use_rocket = true

# ============================================================
#  AIMING SYSTEM (keeping your existing aiming code)
# ============================================================
func _start_aiming() -> void:
	if not can_fire_arrow or action_state != ActionState.IDLE:
		return
	
	is_aiming = true
	action_state = ActionState.AIMING
	aim_start_time = _get_now_seconds()
	aim_direction = last_throw_direction.normalized()
	
	# Ensure aim line is ready and visible
	if not aim_line:
		_setup_aim_line()
	aim_line.visible = true
	
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(true)
	else:
		player.velocity = Vector2.ZERO
	
	# Slow down time for precise aiming
	create_tween().tween_method(_set_time_scale, Engine.time_scale, aim_time_scale, 0.5)
	player.UpdateAnimation("aim")
	

func _set_time_scale(v: float) -> void:
	Engine.time_scale = v

func _update_aiming() -> void:
	if not is_aiming:
		return
	
	# Keep player stationary while aiming
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(true)
	else:
		player.velocity = Vector2.ZERO
	
	# Get aiming input
	var aim_input := Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
	)
	
	# Update aim direction if input detected
	if aim_input != Vector2.ZERO:
		aim_direction = _normalize_to_8_dirs(aim_input)
	
	# Calculate aim power based on hold time
	var hold_time = _get_now_seconds() - aim_start_time
	aim_power = clamp((hold_time - min_aim_time) / (max_aim_time - min_aim_time), 0.0, 1.0)
	
	# Update the visual aiming line
	_update_aim_line()

func _normalize_to_8_dirs(v: Vector2) -> Vector2:
	# Snap to 8 directional angles for consistent aiming
	var step = PI / 4.0
	return Vector2.from_angle(round(v.angle() / step) * step)

func _update_aim_line() -> void:
	if not aim_line or not is_aiming:
		return
	
	# Clear previous points
	aim_line.clear_points()
	
	# Calculate fixed line length (doesn't change with power)
	var line_length = 80.0
	var start_position = player.global_position
	var end_position = start_position + (aim_direction * line_length)
	
	# Create straight line (just two points)
	aim_line.add_point(start_position)
	aim_line.add_point(end_position)
	
	# Dynamic color and effects based on power and time
	var time = Time.get_time_dict_from_system()["second"]
	var pulse = sin(time * 8.0) * 0.2 + 0.8  # Faster pulse for aiming
	
	# Color progression: Yellow -> Orange -> Red based on power
	var color: Color
	if aim_power < 0.3:
		color = Color(1.0, 1.0, 0.2, 0.9)  # Bright yellow
	elif aim_power < 0.7:
		color = Color(1.0, 0.7, 0.1, 0.9)  # Orange
	else:
		color = Color(1.0, 0.3, 0.1, 0.9)  # Red for max power
	
	# Apply pulsing effect
	color.a *= pulse
	aim_line.default_color = color
	
	# Dynamic width based on power and pulse
	var base_width = 3.0
	var power_width = 1.0 + aim_power * 1.0  # Less dramatic width change
	aim_line.width = base_width * power_width * pulse
	
	# Ensure visibility
	aim_line.visible = true
	
	print("🎯 Aim line updated - Power: ", aim_power, " Color: ", color, " Width: ", aim_line.width)

func _fire_arrow() -> void:
	if not is_aiming or not can_fire_arrow:
		return
	
	var hold_time = _get_now_seconds() - aim_start_time
	if hold_time < min_aim_time:
		_cancel_aiming()
		return
	
	# Set states
	can_fire_arrow = false
	is_aiming = false
	action_state = ActionState.FIRING
	
	# Hide aim line
	if aim_line:
		aim_line.visible = false
		aim_line.clear_points()
	
	# Restore player movement
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(false)
	
	# Restore normal time scale
	create_tween().tween_method(_set_time_scale, Engine.time_scale, normal_time_scale, 0.1)
	
	# Create and configure arrow
	var arrow = ARROW.instantiate()
	player.get_parent().add_child(arrow)
	arrow.global_position = player.global_position
	arrow.direction = aim_direction
	
	# Handle arrow rotation only (no flipping)
	if arrow.has_node("Sprite2D"):
		var sprite: Sprite2D = arrow.get_node("Sprite2D")
		sprite.rotation = aim_direction.angle()
	else:
		# Fallback rotation method
		arrow.rotation = aim_direction.angle()
	
	# Apply power to arrow
	if arrow.has_method("set_power"):
		arrow.set_power(1.0 + aim_power)
	elif arrow.has_method("set_speed_multiplier"):
		arrow.set_speed_multiplier(1.0 + aim_power * 0.5)
	
	# Fire the arrow
	arrow.fire()
	
	# Apply recoil to player
	_apply_recoil()
	
	# Play attack animation
	player.UpdateAnimation("attack")
	action_state = ActionState.IDLE
	
	print("🏹 Arrow fired with power: ", aim_power)
	
	# Reset ability after cooldown
	await get_tree().create_timer(3.0).timeout
	can_fire_arrow = true

func _cancel_aiming() -> void:
	is_aiming = false
	action_state = ActionState.IDLE
	
	# Hide and clear aim line
	if aim_line:
		aim_line.visible = false
		aim_line.clear_points()
	
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(false)
	
	# Restore normal time scale
	create_tween().tween_method(_set_time_scale, Engine.time_scale, normal_time_scale, 0.3)
	
	print("❌ Aiming cancelled")

func _apply_recoil() -> void:
	var recoil_direction = -aim_direction.normalized()
	var recoil_velocity = recoil_direction * recoil_force
	player.velocity += recoil_velocity
	
	var start_velocity = player.velocity
	create_tween()\
		.tween_property(player, "velocity", start_velocity * 0.2, recoil_duration)\
		.from(start_velocity)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# ============================================================
#  PROCESS
# ============================================================
func _process(delta: float) -> void:
	# Handle time scale transitions
	if Engine.time_scale != normal_time_scale and not is_aiming:
		Engine.time_scale = lerp(Engine.time_scale, normal_time_scale, time_scale_transition_speed * delta)
		if abs(Engine.time_scale - normal_time_scale) < 0.01:
			Engine.time_scale = normal_time_scale
	
	# Handle rocket riding
	if is_rocket_riding:
		_update_rocket_ride(delta)
		return
	
	# Handle grappling updates
	if is_grappling:
		_update_enemy_pull()
		return
	
	# Handle aiming updates
	if is_aiming:
		_update_aiming()
		return
	
	# Update last throw direction based on movement input
	var movement_input := Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
	)
	if movement_input != Vector2.ZERO:
		last_throw_direction = movement_input.normalized()

# ============================================================
#  OTHER ABILITIES
# ============================================================
func _toggle_ability(direction: int = 1) -> void:
	# Cancel aiming if switching away from bow
	if selected_ability == 2 and is_aiming:
		_cancel_aiming()
	
	# Cancel grappling if switching away from grapple
	if selected_ability == 1 and is_grappling:
		_end_grapple()
	
	# Cycle ability in the specified direction
	selected_ability = wrapi(selected_ability + direction, 0, abilities.size())
	PlayerHud.update_ability_ui(selected_ability)
	
	var direction_text = "right" if direction > 0 else "left"
	print("🔄 Switched ", direction_text, " to ability: ", abilities[selected_ability])

func _fire_fist() -> void:
	if active_boomerangs.size() >= 2:
		action_state = ActionState.IDLE
		return
	
	action_state = ActionState.FIRING
	var boomerang := BOOMERANG.instantiate() as Boomerang
	player.add_sibling(boomerang)
	boomerang.global_position = player.global_position + Vector2(10 if active_boomerangs.size() == 0 else -10, 0)
	
	var direction = last_throw_direction
	if active_boomerangs.size() == 1:
		var sprite = boomerang.get_node("Sprite2D")
		var anim = boomerang.get_node("AnimationPlayer")
		if abs(direction.y) > abs(direction.x):
			anim.play("fist_up" if direction.y < 0 else "fist_down")
		else:
			anim.play("fist_side")
		sprite.scale.x = -1 if direction.x < 0 else 1
	
	boomerang.throw(direction)
	active_boomerangs.append(boomerang)
	boomerang.connect("tree_exited", Callable(self, "_on_boomerang_freed").bind(boomerang))
	action_state = ActionState.IDLE

func _on_boomerang_freed(boomerang: Boomerang) -> void:
	active_boomerangs.erase(boomerang)

func _spawn_spike() -> void:
	var enemy = _closest_enemy()
	var spike = SPIKE.instantiate()
	player.get_parent().add_child(spike)
	spike.global_position = enemy.global_position if enemy else player.global_position

func _air_strike() -> void:
	var enemy = _closest_enemy()
	var strike = AIR_STRIKE.instantiate()
	player.get_parent().add_child(strike)
	var offset = Vector2(-17, -38)
	strike.global_position = (enemy.global_position if enemy else player.global_position) + offset

func _fist_smash() -> void:
	animation_player.play("Hands_Smash")
	player.UpdateAnimation("Hands_Smash")
	var smash = FIST_SMASH.instantiate()
	get_tree().current_scene.add_child(smash)
	smash.global_position = player.global_position
	
	# Make smash effect appear behind player
	smash.z_index = player.z_index - 1
	
	smash.get_node("Smash Effect/AnimationPlayer").play("Smash_effect")
	player.velocity = Vector2.ZERO

func _closest_enemy() -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance := INF
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy is Node2D:
			var distance = player.global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	return closest_enemy

# ============================================================
#  UTILITY
# ============================================================
func _get_now_seconds() -> float:
	var time_dict = Time.get_time_dict_from_system()
	return time_dict["minute"] * 60 + time_dict["second"]

# ============================================================
#  CLEANUP
# ============================================================
func _exit_tree() -> void:
	# Clean up aim line
	if aim_line and is_instance_valid(aim_line):
		aim_line.queue_free()
	
	# Clean up grapple line
	if grapple_line and is_instance_valid(grapple_line):
		grapple_line.queue_free()
	
	# Cancel any active aiming
	if is_aiming:
		_cancel_aiming()
	
	# Cleanup grapple if still active
	if is_grappling:
		_end_grapple()
	
	# Cleanup rocket trail if still active
	if rocket_trail_particles and is_instance_valid(rocket_trail_particles):
		rocket_trail_particles.queue_free()
	
	# Restore time scale
	Engine.time_scale = normal_time_scale
