extends Control

@onready var Z: AnimatedSprite2D = $Zkey
@onready var C: AnimatedSprite2D = $Ckey
@onready var X: AnimatedSprite2D = $Xkey
func _ready():
	# Ensure that the sprite is in the idle state initially or the desired default animation
	Z.play("IdleZ")
	C.play("IdleC")
	X.play("IdleX")  # Assuming "default" is the idle or normal state


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Check if the "attack" action is just pressed
	if Input.is_action_just_pressed("attack"):
		Z.play("PressZ")  # Play the attack animation when the key is pressed

	# Check if the "attack" action is just released
	if Input.is_action_just_released("attack"):
		Z.play("IdleZ")  # Revert to the default animation when the key is released
		
	if Input.is_action_just_pressed("ability"):
		C.play("PressC")  # Play the attack animation when the key is pressed
		
	if Input.is_action_just_released("ability"):
		C.play("IdleC") 

	# Check if the "attack" action is just released
	if Input.is_action_just_released("Fist Bomb"):
		X.play("IdleX") 
	
	if Input.is_action_just_pressed(" Fist Bomb"):
		X.play("PressX")  # Play the attack animation when the key is pressed

	# Check if the "attack" action is just released
