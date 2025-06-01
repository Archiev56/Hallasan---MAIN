extends CharacterBody2D
class_name Dino

@export var max_health: int = 50
@export var move_speed: float = 100.0
@export var attack_damage: int = 5
@export var attack_range: float = 80.0
@export var detection_range: float = 200.0
@export var attack_cooldown: float = 2.0

var current_health: int
var is_attacking: bool = false
var attack_ready: bool = true
var player: Node = null  # Use Node to allow flexibility in type
var direction: Vector2 = Vector2.ZERO

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D  # Assuming there's a Sprite2D for the Dino

@export var hurtbox_offset: float = 16  # Distance offset for hurtbox position

# Example patrol points (adjust these to match your game scene)
@onready var patrol_points: Array[Vector2] = [Vector2(100, 100), Vector2(200, 200)]
var current_patrol_index: int = 0

func _ready():
	current_health = max_health

	# Connect the hurtbox's area_entered signal to detect when the player enters
	hurtbox.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))

	hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))
	attack_timer.connect("timeout", Callable(self, "_reset_attack_cooldown"))

	# Find player using the group method or direct path (adjust based on your scene setup)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]  # Assuming one player in the group
		print("Player found: ", player)
	else:
		print("Player not found!")

	set_physics_process(true)  # Ensure physics processing is enabled

func _process(delta):
	# Ensure hurtbox follows the Dino's position
	update_hurtbox_position()

	if not player:
		print("No player detected.")
		patrol(delta)
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	print("Distance to player: ", distance_to_player)

	if distance_to_player <= detection_range and not is_attacking:
		chase_player(delta)
	else:
		patrol(delta)

# Patrolling between points
func patrol(delta):
	print("Patrolling...")
	var target_point = patrol_points[current_patrol_index]
	direction = (target_point - global_position).normalized()
	velocity = direction * move_speed  # Use built-in velocity property
	move_and_slide()  # Call without arguments

	# Flip the Dino sprite horizontally based on horizontal direction (no vertical flip)
	if direction.x != 0:
		sprite.flip_h = direction.x < 0  # Face left if moving left, face right if moving right

	if global_position.distance_to(target_point) < 10:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		animation_player.play("Walk")
		print("Moving to next patrol point.")

# Chase the player
func chase_player(delta):
	print("Chasing player...")
	direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed  # Use built-in velocity property
	move_and_slide()  # Call without arguments

	# Flip the Dino sprite horizontally based on horizontal direction (no vertical flip)
	if direction.x != 0:
		sprite.flip_h = direction.x < 0  # Face left if moving left, face right if moving right

	animation_player.play("Run")

# Update the hurtbox position based on direction
func update_hurtbox_position():
	# Debugging the direction update for hurtbox
	print("Updating hurtbox position. Dino direction: ", direction)
	match direction:
		Vector2.RIGHT:
			hurtbox.position = global_position + Vector2(hurtbox_offset, 0)  # Right
		Vector2.LEFT:
			hurtbox.position = global_position + Vector2(-hurtbox_offset, 0)  # Left
		Vector2.UP:
			hurtbox.position = global_position + Vector2(0, -hurtbox_offset)  # Up
		Vector2.DOWN:
			hurtbox.position = global_position + Vector2(0, hurtbox_offset)  # Down

# Handle when the player enters Dino's hurtbox
func _on_hurt_box_area_entered(area):
	# Check if the player entered the hurtbox and trigger the attack
	if  area.get_parent() is Player:
		print("Player entered hurtbox! Starting attack.")
		attack_player()

# Handle attacking the player
func attack_player():
	if attack_ready and not is_attacking:
		print("Attacking player!")
		is_attacking = true
		attack_ready = false
		animation_player.play("Attack")
		hitbox.monitoring = true  # Enable hitbox during attack
		attack_timer.start(attack_cooldown)  # Start cooldown timer

# Reset attack cooldown
func _reset_attack_cooldown():
	print("Resetting attack cooldown.")
	attack_ready = true
	is_attacking = false
	hitbox.monitoring = false  # Disable hitbox after the attack ends

# Handle getting hit by the player's hurtbox
func _on_hit_box_area_entered(area):
	if area is HurtBox:
		print("Hit by player!")
		take_damage(damage, global_position)

# Take damage when hit by the player
func take_damage(amount: int):
	print("Taking damage: ", amount)
	current_health -= amount
	animation_player.play("Hurt")

	if current_health <= 0:
		die()

# Handle the death of the Dino
func die():
	print("Dino died!")
	animation_player.play("Die")
	queue_free()  # Remove the Dino from the scene


