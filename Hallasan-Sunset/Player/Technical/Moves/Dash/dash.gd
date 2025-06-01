class_name Dash extends Node2D

const dash_delay = 0.4

@onready var duration_timer = $DurationTimer
@onready var ghost_timer = $GhostTimer
@onready var dust_trail = $DustTrail
@onready var dust_burst = $DustBurst

var ghost_scene = preload("res://Hallasan-Sunset/Player/Technical/Moves/Dash/DashGhost.tscn")
var can_dash = true
var direction = Vector2.ZERO
# Adjusted path: Assuming PlayerSprite is the name of your player sprite node
@onready var sprite : Sprite2D = $"../Sprite2D"  # Change this to the correct sprite node path

func _ready():
	# Connect the timeout signal to the method
	self.sprite = sprite
	

func instance_ghost():
	var ghost: Sprite2D = ghost_scene.instantiate()
	get_parent().get_parent().add_child(ghost)

	ghost.global_position = global_position
	ghost.global_position = global_position
	

	# Ensure sprite_node is valid before accessing texture
	if sprite:
		var current_texture = sprite.texture
		ghost.texture = current_texture  # Assign the current texture to the ghost sprite
	else:
		print("Error: sprite_node is null")  # Debugging info

func start_dash(duration):
	duration_timer.wait_time = duration
	duration_timer.start()

	# Start ghost creation timer with an interval (e.g., 0.1 seconds between ghosts)
	ghost_timer.wait_time = 0.09  # Adjust this value to control ghost frequency
	ghost_timer.start()

	instance_ghost()  # Create an initial ghost
	print("Dash started")
	dust_trail.restart()
	dust_trail.emitting = true
	
	dust_burst.rotation = (direction * -1).angle()
	dust_burst.restart() 
	dust_burst.emitting = true
	ghost_timer.start()
	instance_ghost()

func is_dashing():
	return !duration_timer.is_stopped()
	



func _on_duration_timer_timeout():
	print("Dash ended")

func _on_ghost_timer_timeout():
	instance_ghost()  # Create more ghosts at intervals while dashing
