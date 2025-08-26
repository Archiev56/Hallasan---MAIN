class_name Player extends CharacterBody2D

signal direction_changed(new_direction: Vector2)
signal player_damaged(hurt_box: HurtBox)

const dash_speed = 150
const dash_duration = 0.3

@export var fist_chain: Skill
@export var max_speed: float = 50.0

@onready var actionable_finder: Area2D = $Interactions/Direction/ActionableFinder
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer2D = $Audio/AudioStreamPlayer2D
@onready var effect_animation_player: AnimationPlayer = $EffectAnimationPlayer
@onready var behind_sprite = $Sprite2D/BehindObjectSprite
@onready var hit_box: HitBox = $Interactions/HitBox
@onready var sprite: Sprite2D = $Sprite2D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var lift: State_Lift = $StateMachine/Lift
@onready var held_item: Node2D = $Sprite2D/HeldItem
@onready var carry: State_Carry = $StateMachine/Carry
@onready var camera_2d: PlayerCamera = $Camera2D

var DIR_8 = []

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var invulnerable: bool = false
var hp: int = 6
var max_hp: int = 6
var level: int = 1
var xp: int = 0
var max_energy: int = 3
var current_energy: int = max_energy 
var energy_deduction_per_dodge: int = 1
var attack: int = 1:
	set(v):
		attack = v
		update_damage_values()
var defense: int = 1
var defense_bonus: int = 0
var arrow_count : int = 2
var bomb_count : int = 10


func _ready():
	PlayerManager.player = self
	state_machine.Initialize(self)
	hit_box.damaged.connect(_take_damage)
	update_hp(99)
	update_damage_values()
	PlayerManager.player_leveled_up.connect(_on_player_leveled_up)
	PlayerManager.INVENTORY_DATA.equipment_changed.connect(_on_equipment_changed)

	# Initialize diagonal movement directions
	DIR_8 = [
		Vector2.RIGHT, 
		Vector2(-1, 1).normalized(),    # DOWN_RIGHT
		Vector2.DOWN, 
		Vector2(1, 1).normalized(),   # DOWN_LEFT
		Vector2.LEFT, 
		Vector2(1, -1).normalized(),  # UP_LEFT
		Vector2.UP, 
		Vector2(-1, -1).normalized()    # UP_RIGHT
	]

func _process(_delta):
	direction = Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	).normalized()

	behind_sprite.position = sprite.position
	behind_sprite.texture = sprite.texture

# Handles the physics processing of the character.
func _physics_process(_delta):
	move_and_slide()

func set_direction() -> bool:
	if direction == Vector2.ZERO:
		return false

	var direction_id: int = int(round((direction + cardinal_direction * 0.1).angle() / TAU * DIR_8.size())) % DIR_8.size()
	var new_dir = DIR_8[direction_id]

	if new_dir == cardinal_direction:
		return false

	cardinal_direction = new_dir
	direction_changed.emit(new_dir)

	# Correct sprite flipping for diagonal movement
	if cardinal_direction == Vector2.LEFT or cardinal_direction == Vector2(-1, 1).normalized() or cardinal_direction == Vector2(-1, -1).normalized():
		sprite.scale.x = 1  # Face left
	elif cardinal_direction == Vector2.RIGHT or cardinal_direction == Vector2(1, 1).normalized() or cardinal_direction == Vector2(1, -1).normalized():
		sprite.scale.x = -1  # Face right

	return true

func UpdateAnimation(state: String) -> void:
	animation_player.play(state + "_" + AnimDirection())

func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	elif cardinal_direction == Vector2.RIGHT:
		return "side"  # Right movement (sprite flipped for left)
	elif cardinal_direction == Vector2.LEFT:
		return "side"  # Left movement (normal sprite)
	elif cardinal_direction == Vector2(1, 1).normalized():
		return "diagonal_down_right"
	elif cardinal_direction == Vector2(-1, 1).normalized():
		return "diagonal_down_left"
	elif cardinal_direction == Vector2(1, -1).normalized():
		return "diagonal_up_right"
	elif cardinal_direction == Vector2(-1, -1).normalized():
		return "diagonal_up_left"
	else:
		return "side"  # Default to side if undefined

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()

		if _event.is_action_pressed("interact"):
			PlayerManager.interact_pressed.emit()
			return
		return

func change_sprite() -> void:
	sprite.texture = load("res://Hallasan-Sunset/Player/Animations/Idle/IdleDown/Untitled_Artwork-1.png")

func _take_damage(hurt_box: HurtBox) -> void:
	if invulnerable == true:
		return

	if hp > 0:
		var dmg: int = hurt_box.damage

		if dmg > 0:
			dmg = clampi(dmg - defense - defense_bonus, 1, dmg)

		update_hp(-dmg)
		player_damaged.emit(hurt_box)

func update_hp(delta: int) -> void:
	hp = clampi(hp + delta, 0, max_hp)
	PlayerHud.update_hp(hp, max_hp)

func make_invulnerable(_duration: float = 1.0) -> void:
	invulnerable = true
	hit_box.monitoring = false

	await get_tree().create_timer(_duration).timeout

	invulnerable = false
	hit_box.monitoring = true

func pickup_item(_t: Throwable) -> void:
	state_machine.change_state(lift)
	carry.throwable = _t

func revive_player() -> void:
	update_hp(99)
	state_machine.change_state($StateMachine/Idle)

func update_damage_values() -> void:
	var damage_value: int = attack + PlayerManager.INVENTORY_DATA.get_attack_bonus()
	$Interactions/HurtBox.damage = damage_value
	$Interactions/ChargeSpinHurtBox.damage = damage_value * 2
	$Abilities/Fist2/HurtBox.damage = damage_value

func _on_player_leveled_up() -> void:
	effect_animation_player.play("level_up")
	update_hp(max_hp)

func _input(event):

		var input_direction = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		).normalized()


func _on_equipment_changed() -> void:
	update_damage_values()
	defense_bonus = PlayerManager.INVENTORY_DATA.get_defense_bonus()
