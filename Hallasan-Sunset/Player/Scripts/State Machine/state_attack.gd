class_name State_Attack extends State

var attacking : bool = false
var can_combo : bool = false
var combo_requested : bool = false
var combo_step : int = 0  # Tracks combo step (0 = first attack, then 1 and 2)

@export var attack_sound : AudioStream
@export_range(0,1,5) var decelerate_speed : float = 3

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

	# **Play first attack if combo has not started**
	if combo_step == 0 or attack_timer.is_stopped():  
		combo_step = 0  # Ensure we start at the first attack
	else:
		combo_step += 1  # Move to the next attack in the sequence

	# Play attack animation based on combo step
	animation_player.play("attack_" + player.AnimDirection() + ("_" + str(combo_step) if combo_step > 0 else ""))

	attack_timer.start()
	animation_player.animation_finished.connect(_end_attack)

	await get_tree().create_timer(0.075).timeout
	if attacking: 
		hurt_box.monitoring = true

	await get_tree().create_timer(0.2).timeout
	can_combo = true
	
	


## **🚀 What happens when the player exits this State?**
func exit() -> void:
	animation_player.animation_finished.disconnect(_end_attack)
	attacking = false
	hurt_box.monitoring = false
	can_combo = false
	combo_requested = false

## **🚀 What happens during the _process update in this State?**
func Process(_delta : float) -> State:
	player.velocity -= player.velocity *  _delta
	if not attacking:
		if player.direction == Vector2.ZERO:
			return idle
		else:
			return walk
	return null

## **🚀 What happens during the _physics_process update in this State?**
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
			await get_tree().create_timer(0.075).timeout
			hurt_box.monitoring = true  # **Re-enable hit detection**
		elif combo_step == 1:
			combo_step = 2  # Move to attack_x_2
			animation_player.play("attack_" + player.AnimDirection() + "_2")
			await get_tree().create_timer(0.075).timeout
			hurt_box.monitoring = true
			combo_step = 0  # Reset combo after the third attack  # **Re-enable hit detection**
			state_machine.change_state(idle)
		
			
		return  # **Ensure function doesn't reset early**
	else:
		combo_step = 0  # Reset combo if no new attack is pressed
		await get_tree().create_timer(0.1).timeout
		state_machine.change_state(idle)

	attacking = false
	combo_requested = false  # Reset request for next attack
	hurt_box.monitoring = false  # **Ensure monitoring is disabled when exiting**
