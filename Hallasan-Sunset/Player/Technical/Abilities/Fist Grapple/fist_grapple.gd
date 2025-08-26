# ============================================================
# GrappleHook.gd - Save as: res://Hallasan-Sunset/Player/Technical/Abilities/GrappleHook.gd
# ============================================================

@icon("res://Hallasan-Sunset/Technical/Icons/icon_weapon.png")
class_name GrappleHook extends CharacterBody2D

signal enemy_grappled(enemy: Enemy)
signal grapple_missed()

@export var speed: float = 400.0
@export var max_range: float = 200.0
@export var hook_damage: int = 0

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0
var is_returning: bool = false
var grappled_enemy: Enemy = null
var player_ref: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	# Connect to area detection
	area.body_entered.connect(_on_body_entered)
	area.area_entered.connect(_on_area_entered)
	
	# Set up sprite rotation
	sprite.rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if is_returning:
		_return_to_player(delta)
	else:
		_travel_forward(delta)

func _travel_forward(delta: float) -> void:
	var movement = direction * speed * delta
	velocity = direction * speed
	move_and_slide()
	
	distance_traveled += movement.length()
	
	# Return if max range reached
	if distance_traveled >= max_range:
		_start_return()

func _return_to_player(delta: float) -> void:
	if not player_ref:
		queue_free()
		return
	
	# Move towards player
	var to_player = (player_ref.global_position - global_position).normalized()
	velocity = to_player * speed * 1.5  # Return faster
	move_and_slide()
	
	# Check if close enough to player to destroy
	if global_position.distance_to(player_ref.global_position) < 20.0:
		queue_free()

func _start_return() -> void:
	is_returning = true
	grapple_missed.emit()

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	if sprite:
		sprite.rotation = direction.angle()

func set_player_reference(player: Node2D) -> void:
	player_ref = player

func _on_body_entered(body: Node2D) -> void:
	# Check if it's an enemy
	if body.is_in_group("Enemy") and body is Enemy:
		_grapple_enemy(body as Enemy)
	elif body.collision_layer & (1 << 4):  # Wall layer
		_start_return()

func _on_area_entered(area: Area2D) -> void:
	# Check if it's an enemy hitbox
	var parent = area.get_parent()
	if parent and parent.is_in_group("Enemy") and parent is Enemy:
		_grapple_enemy(parent as Enemy)

func _grapple_enemy(enemy: Enemy) -> void:
	grappled_enemy = enemy
	
	# Deal damage to enemy
	if enemy.has_method("take_damage_direct"):
		enemy.take_damage_direct(hook_damage)
	
	# Signal that we grappled an enemy
	enemy_grappled.emit(enemy)
	
	# Don't return automatically - let the ability system handle it
	collision_shape.set_deferred("disabled", true)  # Disable further collisions
