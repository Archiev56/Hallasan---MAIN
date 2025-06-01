class_name State_Stun extends State

@export var knockback_speed : float = 200.0
@export var decelerate_speed : float = 10.0
@export var invulnerable_duration : float = 1.0

var hurt_box : HurtBox
var direction : Vector2
var time_scale = 1
var next_state : State = null

@onready var idle : State = $"../Idle"
@onready var death: State_Death = $"../Death"
@onready var hurt_animation_player = $"../../Effects & Particles/PlayerHurt/CanvasLayer/HurtAnimationPlayer"

func init() -> void:
	player.player_damaged.connect( _player_damaged )

func enter() -> void:
	player.UpdateAnimation("stun")
	player.animation_player.animation_finished.connect( _animation_finished )
	direction = player.global_position.direction_to( hurt_box.global_position )
	frameFreeze(0.1, 0.05)
	player.velocity = direction * -knockback_speed
	player.set_direction()
	player.make_invulnerable( invulnerable_duration )
	player.effect_animation_player.play("damaged")
	PlayerManager.shake_camera()
	hurt_animation_player.play("player_hurt")
	pass


## What happens when the player exits this State?
func exit() -> void:
	next_state = null
	player.animation_player.animation_finished.disconnect( _animation_finished )
	
	pass
	

func Process( _delta : float ) -> State:
	player.velocity -= player.velocity * decelerate_speed * _delta
	return next_state
	
func Physics( _delta : float ) -> State:
	return null

func handle_input(_event: InputEvent) -> State:
	# Check for the 'test_stun' input action
	if Input.is_action_just_pressed("test_stun"):
		# Manually trigger the stun state
		hurt_box = HurtBox.new()  # You can set this to a dummy HurtBox or handle accordingly
		state_machine.change_state(self)
	return null
	
func _player_damaged( _hurt_box : HurtBox ) -> void:
	hurt_box = _hurt_box
	if state_machine.current_state != death:
		state_machine.change_state( self )
	pass
	
	
	

func _animation_finished( _a: String ) -> void:
	next_state = idle
	if player.hp <= 0:
		next_state = death

func frameFreeze(timeScale, duration):
	Engine.time_scale = timeScale  # Set the game's time scale (e.g., freeze with 0.0 or slow down with < 1.0)
	await(get_tree().create_timer(duration * time_scale).timeout)  # Wait for the duration scaled by timeScale
	Engine.time_scale = 1.0  # Reset the time scale back to normal
