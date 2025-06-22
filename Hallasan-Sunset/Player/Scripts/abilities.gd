class_name PlayerAbilities
extends Node

const BOOMERANG = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist.tscn")
@onready var animation_player = $"../AnimationPlayer"

var abilities: Array[String] = [
	"BOOMERANG", "GRAPPLE", "BOW", "BOMB"
]

var selected_ability: int = 0

enum ActionState { IDLE, FIRING }  # Removed AIMING

var player: Player
var active_boomerangs: Array = []
var action_state: ActionState = ActionState.IDLE

@onready var hurt_box: HurtBox = $Interactions/HurtBox

func _ready() -> void:
	player = PlayerManager.player
	PlayerHud.update_arrow_count(player.arrow_count)
	PlayerHud.update_bomb_count(player.bomb_count)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability"):
		match selected_ability:
			0:
				fire_fist()
			1:
				animation_player.play("Hands_Smash")
			2:
				print("Bow")
			3:
				print("Bomb")
	elif event.is_action_pressed("switch_ability"):
		toggle_ability()
	pass

func toggle_ability() -> void:
	selected_ability = wrapi(selected_ability + 1, 0, 4)
	PlayerHud.update_ability_ui(selected_ability)
	pass



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

	var throw_direction = player.cardinal_direction

	if active_boomerangs.size() == 1:
		var sprite = _b.get_node("Sprite2D")
		var animation_player = _b.get_node("AnimationPlayer")

		if abs(throw_direction.y) > abs(throw_direction.x):
			if throw_direction.y < 0:
				animation_player.play("fist_up")
			else:
				animation_player.play("fist_down")
			sprite.scale.x *= -1
		else:
			animation_player.play("fist_side")
			sprite.scale.x = 1

	_b.throw(throw_direction)
	active_boomerangs.append(_b)
	_b.connect("tree_exited", Callable(self, "_on_boomerang_freed").bind(_b))

	action_state = ActionState.IDLE

func _on_boomerang_freed(boomerang: Boomerang) -> void:
	active_boomerangs.erase(boomerang)

func _process(_delta: float) -> void:
	pass
