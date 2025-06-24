class_name PlayerAbilities
extends Node

const BOOMERANG = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist.tscn")
const ARROW = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist_projectile/fist_projectile.tscn")
const SPIKE = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Spike/Fist Spike.tscn")
const AIR_STRIKE = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Air Strike/Fist Air Strike.tscn")

@onready var animation_player = $"../AnimationPlayer"

var abilities: Array[String] = [
	"BOOMERANG", "GRAPPLE", "BOW", "BOMB", "AIR_STRIKE"
]

var selected_ability: int = 0

enum ActionState { IDLE, FIRING }

var player: Player
var active_boomerangs: Array = []
var action_state: ActionState = ActionState.IDLE

@onready var hurt_box: HurtBox = $Interactions/HurtBox

var last_throw_direction: Vector2 = Vector2.RIGHT

var can_fire_arrow: bool = true  # Cooldown flag for arrow firing

func _ready() -> void:
	player = PlayerManager.player
	PlayerHud.update_arrow_count(player.arrow_count)
	PlayerHud.update_bomb_count(player.bomb_count)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability"):
		match selected_ability:
			0:
				fire_fist()
				player.UpdateAnimation("attack")
			1:
				animation_player.play("Hands_Smash")
				player.UpdateAnimation("Hands_Smash")
				player.velocity = Vector2.ZERO
			2:
				fire_arrow()
				player.UpdateAnimation("attack")
			3:
				animation_player.play("Summon")
				spawn_spike()
				player.UpdateAnimation("attack")
			4:
				animation_player.play("Summon")
				air_strike()
				player.UpdateAnimation("attack")
	elif event.is_action_pressed("switch_ability"):
		toggle_ability()

func toggle_ability() -> void:
	selected_ability = wrapi(selected_ability + 1, 0, abilities.size())
	PlayerHud.update_ability_ui(selected_ability)

func fire_fist() -> void:
	if active_boomerangs.size() >= 2:
		action_state = ActionState.IDLE
		return

	action_state = ActionState.FIRING

	var _b = BOOMERANG.instantiate() as Boomerang
	player.add_sibling(_b)

	if active_boomerangs.size() == 0:
		_b.global_position = player.global_position + Vector2(10, 0)
	elif active_boomerangs.size() == 1:
		_b.global_position = player.global_position + Vector2(-10, 0)

	var throw_direction := last_throw_direction

	if active_boomerangs.size() == 1:
		var sprite = _b.get_node("Sprite2D")
		var animation_player = _b.get_node("AnimationPlayer")

		if abs(throw_direction.y) > abs(throw_direction.x):
			if throw_direction.y < 0:
				animation_player.play("fist_up")
			else:
				animation_player.play("fist_down")
		else:
			animation_player.play("fist_side")

		sprite.scale.x = -1 if throw_direction.x < 0 else 1

	_b.throw(throw_direction)
	active_boomerangs.append(_b)
	_b.connect("tree_exited", Callable(self, "_on_boomerang_freed").bind(_b))

	action_state = ActionState.IDLE

func fire_arrow() -> void:
	if not can_fire_arrow:
		return

	can_fire_arrow = false

	var arrow = ARROW.instantiate()
	player.get_parent().add_child(arrow)
	arrow.global_position = player.global_position
	arrow.direction = last_throw_direction.normalized()
	arrow.fire()

	await get_tree().create_timer(3.0).timeout
	can_fire_arrow = true

func _on_boomerang_freed(boomerang: Boomerang) -> void:
	active_boomerangs.erase(boomerang)

func _process(_delta: float) -> void:
	var move_dir := Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		move_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		move_dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		move_dir.y += 1
	if Input.is_action_pressed("ui_up"):
		move_dir.y -= 1

	if move_dir != Vector2.ZERO:
		last_throw_direction = move_dir.normalized()

func spawn_spike() -> void:
	var closest_enemy: Node2D = null
	var min_distance := INF

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not enemy is Node2D:
			continue

		var distance = player.global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy

	var spike = SPIKE.instantiate()
	player.get_parent().add_child(spike)

	if closest_enemy:
		spike.global_position = closest_enemy.global_position
	else:
		spike.global_position = player.global_position

func air_strike() -> void:
	var closest_enemy: Node2D = null
	var min_distance := INF

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not enemy is Node2D:
			continue

		var distance = player.global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy

	var strike = AIR_STRIKE.instantiate()
	player.get_parent().add_child(strike)

	var offset = Vector2(-17, -38)

	if closest_enemy:
		strike.global_position = closest_enemy.global_position + offset
	else:
		strike.global_position = player.global_position + offset
