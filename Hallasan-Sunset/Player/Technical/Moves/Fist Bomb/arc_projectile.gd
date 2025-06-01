extends Node2D

var initial_speed: float
var throw_angle_degrees: float
const gravity: float = 9.8
var time: float = 0.0

var initial_position: Vector2
var throw_direction: Vector2

var z_axis = 0.0 # Simulate throwing the projectile on the z-axis
var is_launch: bool = false

var time_mult: float = 6.0
var player_direction: Vector2 = Vector2(1, 0) # Default is facing right
var has_reached_peak: bool = false # Tracks if the projectile has reached its peak
var has_exploded: bool = false # Tracks if the explosion has started
var frozen_position: Vector2 # Keeps the position where the projectile freezes

# Reference to AnimationPlayer node
@onready var animation_player = $Projectile/AnimationPlayer
@onready var animation_player2 = $"../AnimationPlayer"

@onready var animation_player3 = $Sprite2D/AnimationPlayer


# Reference to the hurt box (Area2D)
@onready var hurt_box = $Projectile/HurtBox

# Reference to the CollisionShape2D inside the hurt box
@onready var hurt_box_collision_shape = $hurt_box/CollisionShape2D

# Reference to the player node
@onready var player = get_parent().get_node(".")

# Reference to the Sizzle and Explosion sound nodes
@onready var sizzle_sound: AudioStreamPlayer2D = $Sizzle
@onready var explosion_sound: AudioStreamPlayer2D = $Explosion

func _ready():
	visible = false
	set_physics_process(false)
	hurt_box_collision_shape.disabled = true

	animation_player3.connect("animation_finished", Callable(self, "_on_AnimationPlayer_animation_finished"))

func _process(delta):
	if not has_exploded:
		time += delta * time_mult

		# Check player movement direction for animation
		if Input.is_action_pressed("ui_left"):
			player_direction = Vector2(-1, 0)
			if Input.is_action_pressed("Fist Bomb"):
				animation_player2.play("BombCarrySide")
		elif Input.is_action_pressed("ui_right"):
			player_direction = Vector2(1, 0)
			if Input.is_action_pressed("Fist Bomb"):
				animation_player2.play("BombCarrySide")
		elif Input.is_action_pressed("ui_up"):
			player_direction = Vector2(0, -1)
			if Input.is_action_pressed("Fist Bomb"):
				animation_player2.play("BombCarryUp")
		elif Input.is_action_pressed("ui_down"):
			player_direction = Vector2(0, 1)
			if Input.is_action_pressed("Fist Bomb"):
				animation_player2.play("BombCarryDown")
		else:
			if Input.is_action_pressed("Fist Bomb"):
				animation_player2.stop()

		# Launch bomb when 'bomb' input is released
		if Input.is_action_just_released("Fist Bomb") and not is_launch:
			LaunchProjectile(player.global_position, player_direction, 150, 60)
		
		if is_launch and not has_exploded:
			# Simulate z-axis motion
			z_axis = initial_speed * sin(deg_to_rad(throw_angle_degrees)) * time - 0.7 * gravity * pow(time, 2)

			# Check if bomb has hit the ground
			if z_axis <= 0 and has_reached_peak:
				exploded()
			else:
				if z_axis < initial_speed * sin(deg_to_rad(throw_angle_degrees)) * 0.1:
					has_reached_peak = true

				var x_axis: float = initial_speed * cos(deg_to_rad(throw_angle_degrees)) * time
				global_position = initial_position + throw_direction * x_axis
				$Projectile.position.y = -z_axis
	else:
		global_position = frozen_position

func LaunchProjectile(initial_pos: Vector2, direction: Vector2, desired_distance: float, desired_angle_deg: float):
	visible = true
	set_physics_process(true)
	hurt_box_collision_shape.disabled = true

	initial_position = initial_pos
	throw_direction = direction.normalized()
	throw_angle_degrees = desired_angle_deg
	initial_speed = sqrt((desired_distance * gravity) / sin(2 * deg_to_rad(desired_angle_deg)))

	global_position = initial_position
	time = 0.0
	has_reached_peak = false
	has_exploded = false
	z_axis = 0
	is_launch = true

	animation_player.play("BombLive")
	sizzle_sound.play()

func _on_AnimationPlayer_animation_finished(anim_name: String):
	if anim_name == "Explode":
		reset_projectile()

func reset_projectile():
	initial_position = player.global_position
	is_launch = false
	time = 0.0
	has_reached_peak = false
	has_exploded = false
	z_axis = 0
	global_position = initial_position

	scale = Vector2(1, 1)
	visible = false
	set_physics_process(false)
	hurt_box_collision_shape.disabled = true

	animation_player.play("Idle")

func _on_hurt_box_body_entered(body):
	if body != self and hurt_box_collision_shape.disabled == false and body.has_method("take_damage"):
		body.take_damage(5, global_position)

func exploded():
	is_launch = false
	has_exploded = true
	z_axis = 0
	set_physics_process(false)
	frozen_position = global_position
	scale *= 2

	hurt_box_collision_shape.disabled = false
	animation_player3.play("Explode")
	explosion_sound.play()
