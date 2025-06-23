class_name State_Attack extends State

var attacking : bool = false
var can_combo : bool = false
var combo_requested : bool = false
var combo_step : int = 0  # Tracks combo step (0 = first attack, then 1 and 2)
var stored_attack_direction : Vector2  # Store the direction when attack starts

@export var attack_sound : AudioStream
@export_range(0,1,0.05) var decelerate_speed : float = 0.1
@export var drawback_force : float = 150.0  # Force applied backward during windup
@export var thrust_force : float = 300.0    # Force applied forward during attack
@export var drawback_duration : float = 0.08  # Split second drawback
@export var thrust_duration : float = 0.12    # Forward thrust duration

@onready var idle : State = $"../Idle"
@onready var walk : State = $"../Walk"
@onready var charge_attack = $"../ChargeAttack"
@onready var attack_timer = $"../../Timers/AttackTimer"
@onready var animation_player : AnimationPlayer = $"../../AnimationPlayer"
@onready var attack_anim : AnimationPlayer = $"../../Sprite2D/AttackEffectSprite/AnimationPlayer"
@onready var audio : AudioStreamPlayer2D = $"../../Audio/AudioStreamPlayer2D"
@onready var hurt_box : HurtBox = $"../../Interactions/HurtBox"

## **🚀 What happens when the player enters this State?**
func enter() -> void:
	attacking = true
	can_combo = false
	combo_requested = false
	player.UpdateAnimation("attack")
	
	# **Store the attack direction when entering the state**
	stored_attack_direction = _determine_attack_direction()
	
	# **Play first attack if combo has not started**
	if combo_step == 0 or attack_timer.is_stopped():  
		combo_step = 0  # Ensure we start at the first attack
	else:
		combo_step += 1  # Move to the next attack in the sequence
	
	# Play attack animation based on combo step
	animation_player.play("attack_" + player.AnimDirection() + ("_" + str(combo_step) if combo_step > 0 else ""))
	attack_timer.start()
	animation_player.animation_finished.connect(_end_attack)
	
	# Apply drawback and thrust mechanics
	_apply_attack_movement()
	
	await get_tree().create_timer(0.075).timeout
	if attacking: 
		hurt_box.monitoring = true
	await get_tree().create_timer(0.1).timeout
	can_combo = true

## **🚀 Determines attack direction based on current state**
func _determine_attack_direction() -> Vector2:
	# First priority: use player's current input direction
	if player.direction != Vector2.ZERO:
		return player.direction.normalized()
	
	# Second priority: parse the animation name to get direction
	var anim_name = "attack_" + player.AnimDirection()
	
	# Check what animation is about to play
	if "up" in anim_name:
		if "right" in anim_name:
			return Vector2(1, -1).normalized()  # Up-right diagonal
		elif "left" in anim_name:
			return Vector2(-1, -1).normalized()  # Up-left diagonal
		else:
			return Vector2.UP
	elif "down" in anim_name:
		if "right" in anim_name:
			return Vector2(1, 1).normalized()  # Down-right diagonal
		elif "left" in anim_name:
			return Vector2(-1, 1).normalized()  # Down-left diagonal
		else:
			return Vector2.DOWN
	elif "side" in anim_name:
		# Check sprite flip to determine left/right
		if player.sprite.flip_h:
			return Vector2.RIGHT
		else:
			return Vector2.LEFT
	elif "left" in anim_name:
		return Vector2.LEFT
	elif "right" in anim_name:
		return Vector2.RIGHT
	
	# Final fallback
	return Vector2.DOWN

## **🚀 Applies drawback then thrust movement**
func _apply_attack_movement() -> void:
	# Use stored direction for consistent movement
	var attack_direction = stored_attack_direction
	
	# Phase 1: Quick drawback
	var drawback_tween = create_tween()
	drawback_tween.tween_method(_apply_movement_force, -attack_direction * drawback_force, Vector2.ZERO, drawback_duration)
	
	# Phase 2: Forward thrust (starts after drawback)
	await get_tree().create_timer(drawback_duration)
	var thrust_tween = create_tween()
	thrust_tween.tween_method(_apply_movement_force, attack_direction * thrust_force, Vector2.ZERO, thrust_duration)

## **🚀 Applies movement force during attack**
func _apply_movement_force(force: Vector2) -> void:
	if attacking:
		player.velocity += force * get_physics_process_delta_time()

## **🚀 Gets the direction of the attack based on player orientation**
func _get_attack_direction() -> Vector2:
	return stored_attack_direction

## **🚀 What happens when the player exits this State?**
func exit() -> void:
	animation_player.animation_finished.disconnect(_end_attack)
	attacking = false
	hurt_box.monitoring = false
	can_combo = false
	combo_requested = false

## **🚀 What happens during the _process update in this State?**
func Process(_delta : float) -> State:
	player.velocity -= player.velocity * decelerate_speed * _delta
	if not attacking:
		if player.direction == Vector2.ZERO:
			return idle
		else:
			return walk
	return null

## **🚀 What happens during the physics process update in this State?**
func Physics(_delta : float) -> State:
	return null

## **🚀 Handles attack input**
func handle_input(_event: InputEvent) -> State:
	if _event.is_action_pressed("attack"):
		combo_requested = true
	return null

## **🚀 Fix: Ensure attack resets after a full combo**
func _end_attack(_newAnimName : String) -> void:
	if can_combo and combo_requested:
		if combo_step == 0:  
			combo_step = 1  # Move to attack_x_1
			animation_player.play("attack_" + player.AnimDirection() + "_1")
			
			# Apply enhanced movement for combo attacks
			var combo_multiplier = 1.0 + combo_step * 0.3
			_apply_combo_movement(combo_multiplier)
			
			await get_tree().create_timer(0.075).timeout
			hurt_box.monitoring = true  # **Re-enable hit detection**
		elif combo_step == 1:
			combo_step = 0  # Reset combo after second attack
			state_machine.change_state(idle)
			return
		
		return  # **Ensure function doesn't reset early**
	else:
		combo_step = 0  # Reset combo if no new attack is pressed
		await get_tree().create_timer(0.1).timeout
		state_machine.change_state(idle)
	
	attacking = false
	combo_requested = false  # Reset request for next attack
	hurt_box.monitoring = false  # **Ensure monitoring is disabled when exiting**

## **🚀 Applies enhanced movement for combo attacks**
func _apply_combo_movement(multiplier: float) -> void:
	var attack_direction = _get_attack_direction()
	var enhanced_drawback = drawback_force * multiplier
	var enhanced_thrust = thrust_force * multiplier
	
	# Enhanced drawback
	var drawback_tween = create_tween()
	drawback_tween.tween_method(_apply_movement_force, -attack_direction * enhanced_drawback, Vector2.ZERO, drawback_duration * 0.8)
	
	# Enhanced thrust
	await get_tree().create_timer(drawback_duration * 0.8)
	var thrust_tween = create_tween()
	thrust_tween.tween_method(_apply_movement_force, attack_direction * enhanced_thrust, Vector2.ZERO, thrust_duration * 0.9)
