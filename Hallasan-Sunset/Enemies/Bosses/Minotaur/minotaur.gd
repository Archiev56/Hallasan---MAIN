extends CharacterBody2D

# Exported variables to adjust the Minotaur's attributes from the editor
@export var attack_damage = 20
@export var charge_damage = 40
@export var health = 20
@export var speed = 100.0
@export var charge_speed = 300.0
@export var attack_cooldown = 2.0
@export var attack_range = 50  # How close the Minotaur needs to be to attack

# State management
var is_hurt = false
var is_attacking = false
var invulnerable = false  # Invulnerable while hurt
var attack_timer = 0.0
var is_knocked_back = false  # Tracks if the Minotaur is knocked back

# Nodes (assumes these are children of the Minotaur node)
var player_target
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $HitBox
@onready var hurtbox = $hurt_box
@onready var gpu_particles_2d = $GPUParticles2D
@onready var knockback_timer : Timer = $KnockbackTimer
@onready var invulnerability_timer : Timer = $InvulnerabilityTimer

# Called when the node enters the scene tree
func _ready() -> void:
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	hurtbox.connect("body_entered", Callable(self, "_on_hurtbox_body_entered"))
	knockback_timer.connect("timeout", Callable(self, "_end_knockback"))
	invulnerability_timer.connect("timeout", Callable(self, "_on_invulnerability_timeout"))

# Main game loop for enemy AI
func _process(delta: float) -> void:
	if health <= 0:
		return  # Don't do anything if dead

	attack_timer -= delta

	if is_knocked_back:
		move_and_slide()  # Continue applying knockback without overriding other logic
		return

	# Look for the player group to target
	player_target = get_closest_player()

	if player_target and not is_hurt:
		move_and_attack_player(delta)
	
	# Handle animations while moving
	if not is_attacking and not is_hurt:
		play_idle_or_walk_animation()

# Find the closest player in the "Player" group
func get_closest_player() -> Node:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() == 0:
		return null
	
	var closest_player = players[0]
	var closest_dist = position.distance_to(closest_player.position)
	
	for player in players:
		var dist = position.distance_to(player.position)
		if dist < closest_dist:
			closest_player = player
			closest_dist = dist
	
	return closest_player

# Move towards the player and decide when to attack
func move_and_attack_player(delta: float) -> void:
	if player_target:
		var distance_to_player = position.distance_to(player_target.position)
		
		if distance_to_player > attack_range:  # Move towards the player if not close enough
			var direction_to_player = (player_target.position - position).normalized()

			# Flip the Minotaur when moving left or right
			if direction_to_player.x < 0:
				animated_sprite.flip_h = true  # Flip horizontally for left direction
			else:
				animated_sprite.flip_h = false  # Right direction, no flip

			velocity = direction_to_player * speed
			move_and_slide()
		else:
			# Attack when in range
			if attack_timer <= 0 and not is_attacking:
				attack_player()

# Handle attack logic
func attack_player() -> void:
	if is_attacking:
		return  # Already attacking, don't restart

	print("Minotaur is attacking!")  # Debugging print to verify attack starts
	is_attacking = true
	attack_timer = attack_cooldown
	animated_sprite.play("Attack 1")  # Ensure this animation exists

	var overlapping_bodies = hitbox.get_overlapping_bodies()
	print("Bodies detected by hitbox: ", overlapping_bodies.size())  # Debug how many bodies are detected
	if overlapping_bodies.size() > 0:
		for body in overlapping_bodies:
			if body is Player:
				print("Player detected!")  # Debug print for confirming player detection
				if not body.invulnerable:  # Ensure player is not invulnerable
					
					print("Minotaur dealt damage to Player!")  # Debug message when damage is dealt
				else:
					print("Player is invulnerable, no damage dealt")
	
	# Use a timer to end the attack after 1 second
	await get_tree().create_timer(1.0).timeout  # Assuming 1 second per attack
	is_attacking = false


# Handling taking damage
func take_damage(damage: int, from: Vector2) -> void:
	if invulnerable or is_hurt or health <= 0:
		return

	health -= damage
	invulnerable = true
	is_hurt = true


	# Play hurt animation and particle effect

	animated_sprite.play("Hurt")

	# Apply knockback from the direction of the hit
	apply_knockback(from)

	# Set invulnerability and start a timer to reset it after 1.5 seconds
	invulnerability_timer.start(1.5)

	if health <= 0:
		die()

# Apply knockback effect
func apply_knockback(from: Vector2) -> void:
	if is_knocked_back:
		return  # Don't apply knockback again if already knocked back

	is_knocked_back = true
	var knockback_direction = (global_position - from).normalized()
	var knockback_strength = 50.0
	velocity = knockback_direction * knockback_strength
	knockback_timer.start(0.3)

# End knockback effect
func _end_knockback() -> void:
	is_knocked_back = false

# End invulnerability timer
func _on_invulnerability_timeout() -> void:
	invulnerable = false
	is_hurt = false

# Function to die
func die() -> void:
	animated_sprite.play("Death")
	await get_tree().create_timer(2.0).timeout  # Play death animation
	queue_free()

# Play idle or walk animation based on movement state
func play_idle_or_walk_animation() -> void:
	if velocity.length() == 0:
		animated_sprite.play("Idle")
	else:
		animated_sprite.play("Walk")

# Collision detection for attacking player
func _on_hitbox_body_entered(body: Node) -> void:
	if body is Player and not is_attacking and not is_hurt:
		attack_player()
