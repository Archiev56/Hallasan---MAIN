class_name PlayerAbilities extends Node

const BOOMERANG = preload("res://Hallasan-Sunset/Player/Technical/Moves/Fist.tscn")

enum abilities { BOOMERANG, GRAPPLE }
enum ActionState { IDLE, AIMING, FIRING }  # Add states for aiming and firing

var selected_ability = abilities.BOOMERANG
var player: Player
var active_boomerangs: Array = []  # To track active boomerangs
var action_state: ActionState = ActionState.IDLE  # Track the current state
var aim_direction: Vector2 = Vector2.ZERO  # Store the aiming direction

@onready var hurt_box: HurtBox = $Interactions/HurtBox

func _ready() -> void:
	player = PlayerManager.player

func _unhandled_input(event: InputEvent) -> void:
	# Start aiming when the ability key is pressed
	if event.is_action_pressed("ability") and action_state == ActionState.IDLE:
		start_aiming()

	# Fire when the ability key is released
	elif event.is_action_released("ability") and action_state == ActionState.AIMING:
		fire_fist()

func start_aiming() -> void:
	action_state = ActionState.AIMING
	print("Aiming started.")  # Debug output to confirm state
	aim_direction = Vector2.ZERO  # Reset aim direction

func fire_fist() -> void:
	if active_boomerangs.size() >= 2:
		action_state = ActionState.IDLE
		return

	action_state = ActionState.FIRING

	# Create a new boomerang instance
	var _b = BOOMERANG.instantiate() as Boomerang
	player.add_sibling(_b)

	# Offset boomerangs to the side of the player
	if active_boomerangs.size() == 0:
		_b.global_position = player.global_position + Vector2(10, 0)  # First fist (right)
	elif active_boomerangs.size() == 1:
		_b.global_position = player.global_position + Vector2(-10, 0)  # Second fist (left)

	# Determine the throw direction based on aiming
	var throw_direction = aim_direction if aim_direction != Vector2.ZERO else player.cardinal_direction

	# Flip sprites horizontally if this is the second boomerang
	if active_boomerangs.size() == 1:
		var sprite = _b.get_node("Sprite2D")  # Adjust path to your Sprite2D node
		var animation_player = _b.get_node("AnimationPlayer")  # Adjust to match your setup

		# Determine which animation is relevant
		if abs(throw_direction.y) > abs(throw_direction.x):
			# Vertical throw: 'fist_up' or 'fist_down'
			if throw_direction.y < 0:
				animation_player.play("fist_up")
			else:
				animation_player.play("fist_down")
			sprite.scale.x *= -1  # Flip horizontally
		else:
			# Horizontal throw: 'fist_side'
			animation_player.play("fist_side")
			sprite.scale.x = 1  # Ensure no flipping for 'fist_side'

	# Initialize and throw the boomerang
	_b.throw(throw_direction)

	# Add to active boomerangs list
	active_boomerangs.append(_b)

	# Use a Callable to connect the "tree_exited" signal
	_b.connect("tree_exited", Callable(self, "_on_boomerang_freed").bind(_b))

	# Reset state back to idle after firing
	action_state = ActionState.IDLE

func _on_boomerang_freed(boomerang: Boomerang) -> void:
	# Remove the boomerang from the active list when it is freed
	active_boomerangs.erase(boomerang)

func _process(_delta: float) -> void:
	# Update aiming direction based on player input
	if action_state == ActionState.AIMING:
		aim_direction = Vector2.ZERO
		if Input.is_action_pressed("ui_right"):
			aim_direction.x += 1
		if Input.is_action_pressed("ui_left"):
			aim_direction.x -= 1
		if Input.is_action_pressed("ui_down"):
			aim_direction.y += 1
		if Input.is_action_pressed("ui_up"):
			aim_direction.y -= 1
		aim_direction = aim_direction.normalized()  # Ensure consistent aiming speed
